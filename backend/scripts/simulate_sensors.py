#!/usr/bin/env python3
"""Stream CSV biometric readings to the NeuroSense backend via WebSocket."""
import argparse
import asyncio
import json
from pathlib import Path

import pandas as pd
import websockets

DATA_DIR = Path(__file__).parent.parent / "data"
HR_CSV = DATA_DIR / "heart Rate Data.csv"
EDA_CSV = DATA_DIR / "eda.csv"
CALIBRATION_SAMPLES = 60


async def _drain(ws) -> None:
    """Consume incoming broadcasts so the receive buffer doesn't stall."""
    try:
        async for raw in ws:
            try:
                msg = json.loads(raw)
                if msg.get("type") == "update" and msg.get("insight"):
                    print(f"  insight: {msg['insight'][:80]}")
            except Exception:
                pass
    except Exception:
        pass


async def run(patient_id: str, host: str, delay: float) -> None:
    hr_df = pd.read_csv(HR_CSV)[["HR"]].dropna()
    eda_df = pd.read_csv(EDA_CSV)[["MEAN"]].dropna()

    n = min(len(hr_df), len(eda_df))
    hrs = hr_df["HR"].values[:n].tolist()
    edas = eda_df["MEAN"].values[:n].tolist()

    # Scale EDA from the normalized CSV range (~0.25–0.30) to a clinically
    # plausible range (1–20 µS) so the HMM sees meaningful variance.
    eda_min, eda_max = min(edas), max(edas)
    eda_range = eda_max - eda_min or 1.0
    edas = [1.0 + (v - eda_min) / eda_range * 19.0 for v in edas]

    rows = [{"eda": edas[i], "hr": hrs[i]} for i in range(n)]

    uri = f"ws://{host}/ws/monitor/{patient_id}"
    print(f"Connecting to {uri}  ({n} readings, {delay}s interval)")

    async with websockets.connect(uri) as ws:
        # Send calibration batch and wait for acknowledgement
        await ws.send(json.dumps({
            "type": "calibration",
            "samples": rows[:CALIBRATION_SAMPLES],
        }))
        ack = json.loads(await ws.recv())
        print(f"Calibration: {ack}")

        # Drain incoming broadcasts in the background
        drain_task = asyncio.create_task(_drain(ws))

        try:
            for i, row in enumerate(rows, 1):
                await ws.send(json.dumps({
                    "type": "reading",
                    "eda": row["eda"],
                    "hr": row["hr"],
                }))
                if i % 10 == 0:
                    print(f"[{i}/{n}]  EDA={row['eda']:.2f} µS  HR={row['hr']:.1f} bpm")
                await asyncio.sleep(delay)
        finally:
            drain_task.cancel()

    print("Simulation complete.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="NeuroSense sensor simulator")
    parser.add_argument("--patient", default="P001", help="Patient ID (default: P001)")
    parser.add_argument("--host", default="localhost:8000", help="Backend host:port")
    parser.add_argument("--delay", type=float, default=1.0, help="Seconds between readings")
    args = parser.parse_args()
    asyncio.run(run(args.patient, args.host, args.delay))
