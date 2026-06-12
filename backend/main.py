import asyncio
import json
import logging
import os
import time
from contextlib import asynccontextmanager
from typing import Optional

import anthropic
import numpy as np
import pandas as pd
import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from hmmlearn.hmm import GaussianHMM
from sklearn.preprocessing import StandardScaler

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# Verify API key is loaded — never log the key itself
_api_key = os.getenv("ANTHROPIC_API_KEY", "")
if not _api_key:
    logger.warning("ANTHROPIC_API_KEY not set — Claude insights will use fallback message")

anthropic_client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY from env

# ── Rate-limit state (per-patient) ───────────────────────────────────────────
# Claude is called only on HMM state changes AND at most once per MIN_CALL_INTERVAL seconds.
MIN_CALL_INTERVAL = 10  # seconds between API calls per patient
_last_call_time: dict[str, float] = {}
_last_state: dict[str, int] = {}


# ── BioEngine ─────────────────────────────────────────────────────────────────
class BioEngine:
    """GaussianHMM wrapper: calibrate on 60-sample batch, then predict state per tick."""

    N_STATES = 3
    CALIBRATION_SAMPLES = 60

    def __init__(self):
        self.model = GaussianHMM(
            n_components=self.N_STATES,
            covariance_type="full",
            n_iter=200,
            random_state=42,
        )
        self.scaler = StandardScaler()
        self.calibrated = False

    def calibrate(self, samples: list[dict]) -> None:
        """Fit scaler + HMM on the first CALIBRATION_SAMPLES readings."""
        df = pd.DataFrame(samples)[["eda", "hr"]].dropna()
        if len(df) < self.CALIBRATION_SAMPLES:
            logger.warning("Calibration batch smaller than expected (%d samples)", len(df))
        X = self.scaler.fit_transform(df.values)
        self.model.fit(X)
        self.calibrated = True
        logger.info("BioEngine calibrated on %d samples", len(df))

    def predict(self, eda: float, hr: float) -> int:
        """Return HMM state index (0-2) for a single reading."""
        if not self.calibrated:
            return 0
        X = self.scaler.transform([[eda, hr]])
        return int(self.model.predict(X)[0])


# ── Claude insight ─────────────────────────────────────────────────────────────
async def get_claude_insight(patient_id: str, state: int, eda: float, hr: float) -> str:
    """
    Call Claude API only when the HMM state changes and the per-patient
    rate-limit interval has elapsed. Returns a JSON string with key 'summary'.
    """
    now = time.monotonic()
    last_call = _last_call_time.get(patient_id, 0.0)
    last_st = _last_state.get(patient_id, -1)

    # Skip if state unchanged or called too recently
    if state == last_st:
        return ""
    if (now - last_call) < MIN_CALL_INTERVAL:
        return ""

    _last_call_time[patient_id] = now
    _last_state[patient_id] = state

    state_labels = {0: "calm/baseline", 1: "moderate arousal", 2: "high stress/arousal"}
    label = state_labels.get(state, f"state {state}")

    try:
        response = anthropic_client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=100,
            system=(
                "You are a clinical assistant monitoring biofeedback data. "
                "Respond ONLY with valid JSON containing a single key 'summary' "
                "whose value is one concise clinical sentence (max 20 words)."
            ),
            messages=[
                {
                    "role": "user",
                    "content": (
                        f"Patient {patient_id} transitioned to HMM state: {label}. "
                        f"EDA={eda:.2f} µS, HR={hr:.1f} bpm. "
                        "Provide a brief clinical insight."
                    ),
                }
            ],
        )
        text = response.content[0].text.strip()
        # Validate JSON before returning
        json.loads(text)
        return text
    except anthropic.RateLimitError:
        logger.warning("Claude rate limit hit for patient %s", patient_id)
    except anthropic.APITimeoutError:
        logger.warning("Claude API timeout for patient %s", patient_id)
    except anthropic.APIConnectionError:
        logger.warning("Claude connection error for patient %s", patient_id)
    except (anthropic.APIStatusError, json.JSONDecodeError) as exc:
        logger.warning("Claude API error for patient %s: %s", patient_id, exc)

    return json.dumps({"summary": "Monitoring continues — AI insight temporarily unavailable."})


# ── WebSocket connection manager ───────────────────────────────────────────────
class ConnectionManager:
    def __init__(self):
        self._connections: dict[str, list[WebSocket]] = {}

    async def connect(self, patient_id: str, ws: WebSocket) -> None:
        await ws.accept()
        self._connections.setdefault(patient_id, []).append(ws)
        logger.info("WebSocket connected: patient=%s", patient_id)

    def disconnect(self, patient_id: str, ws: WebSocket) -> None:
        conns = self._connections.get(patient_id, [])
        if ws in conns:
            conns.remove(ws)
        logger.info("WebSocket disconnected: patient=%s", patient_id)

    async def broadcast(self, patient_id: str, message: dict) -> None:
        dead: list[WebSocket] = []
        for ws in list(self._connections.get(patient_id, [])):
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(patient_id, ws)


manager = ConnectionManager()

# ── Per-patient simulation state ───────────────────────────────────────────────
engines: dict[str, BioEngine] = {}
sim_tasks: dict[str, asyncio.Task] = {}


# ── FastAPI app ────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("NeuroSense backend starting (ANTHROPIC_API_KEY loaded: %s)", bool(_api_key))
    yield
    # Cancel all running simulation tasks on shutdown
    for task in sim_tasks.values():
        task.cancel()
    logger.info("NeuroSense backend stopped")


app = FastAPI(title="NeuroSense", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── WebSocket endpoint ─────────────────────────────────────────────────────────
@app.websocket("/ws/monitor/{patient_id}")
async def websocket_endpoint(websocket: WebSocket, patient_id: str):
    await manager.connect(patient_id, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            msg = json.loads(data)

            if msg.get("type") == "calibration":
                # Simulator sends a batch of 60 samples for HMM fitting
                samples = msg.get("samples", [])
                engine = BioEngine()
                engine.calibrate(samples)
                engines[patient_id] = engine
                await websocket.send_json({"type": "calibration_ack", "status": "ok"})

            elif msg.get("type") == "reading":
                eda = float(msg.get("eda", 0))
                hr = float(msg.get("hr", 0))
                engine = engines.get(patient_id)
                state = engine.predict(eda, hr) if engine else 0

                insight_json = await get_claude_insight(patient_id, state, eda, hr)
                insight = json.loads(insight_json).get("summary", "") if insight_json else ""

                payload = {
                    "type": "update",
                    "patient_id": patient_id,
                    "eda": eda,
                    "hr": hr,
                    "state": state,
                    "insight": insight,
                }
                await manager.broadcast(patient_id, payload)

    except WebSocketDisconnect:
        manager.disconnect(patient_id, websocket)
    except Exception as exc:
        logger.error("WebSocket error for patient %s: %s", patient_id, exc)
        manager.disconnect(patient_id, websocket)


# ── REST endpoints ─────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "claude_key_set": bool(_api_key)}


@app.post("/alert/{patient_id}")
async def alert(patient_id: str):
    await manager.broadcast(patient_id, {"type": "alert", "patient_id": patient_id})
    return {"status": "alert_sent", "patient_id": patient_id}


@app.post("/simulate/{patient_id}/start")
async def start_simulation(patient_id: str):
    if patient_id in sim_tasks and not sim_tasks[patient_id].done():
        raise HTTPException(status_code=409, detail="Simulation already running")
    task = asyncio.create_task(_run_simulation(patient_id))
    sim_tasks[patient_id] = task
    return {"status": "started", "patient_id": patient_id}


@app.post("/simulate/{patient_id}/stop")
async def stop_simulation(patient_id: str):
    task = sim_tasks.get(patient_id)
    if not task or task.done():
        raise HTTPException(status_code=404, detail="No active simulation")
    task.cancel()
    return {"status": "stopped", "patient_id": patient_id}


async def _run_simulation(patient_id: str):
    """Internal demo simulation loop (used when simulate_sensors.py is not running)."""
    rng = np.random.default_rng(42)
    while True:
        eda = float(rng.uniform(0.5, 20.0))
        hr = float(rng.uniform(55, 110))
        engine = engines.get(patient_id)
        state = engine.predict(eda, hr) if engine else 0
        insight_json = await get_claude_insight(patient_id, state, eda, hr)
        insight = json.loads(insight_json).get("summary", "") if insight_json else ""
        await manager.broadcast(
            patient_id,
            {"type": "update", "patient_id": patient_id, "eda": eda, "hr": hr,
             "state": state, "insight": insight},
        )
        await asyncio.sleep(1)


# ── Entry point ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
