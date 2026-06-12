# NeuroSense

Real-time biofeedback monitoring system. A FastAPI backend runs a Gaussian HMM to classify patient stress states from EDA and heart rate data, streams results over WebSocket, and uses Claude to generate brief clinical insights on state transitions. A Flutter frontend visualises the live feed.

---

## Architecture

```
Flutter app  ──WebSocket──▶  FastAPI backend  ──▶  HMM (hmmlearn)
                                    │
                                    └──▶  Claude API (state-change insights)
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Python | 3.10+ |
| Flutter | 3.x |
| Anthropic API key | — |

---

## Backend

### Setup

```bash
cd backend
python -m venv .venv
# Windows
.venv\Scripts\activate
# macOS/Linux
source .venv/bin/activate

pip install -r requirements.txt
```

### Configure

```bash
cp .env.example .env
# Edit .env and set your key:
# ANTHROPIC_API_KEY=sk-ant-...
```

### Run

```bash
uvicorn main:app --reload --port 8000
```

The API will be available at `http://localhost:8000`. Check `GET /health` to confirm the key is loaded.

### Simulate sensor data

Place your CSV files in `backend/data/`:
- `heart Rate Data.csv` — column `HR`
- `eda.csv` — column `MEAN`

Then stream them to the backend:

```bash
python scripts/simulate_sensors.py --patient P001 --delay 1.0
```

Alternatively, use the built-in random simulator via the REST API:

```bash
curl -X POST http://localhost:8000/simulate/P001/start
curl -X POST http://localhost:8000/simulate/P001/stop
```

---

## Frontend

### Setup & run

```bash
cd frontend
flutter pub get
flutter run
```

Target a specific platform:

```bash
flutter run -d windows   # or macos, linux, chrome
```

The app connects to `ws://localhost:8000/ws/monitor/{patientId}` by default.

---

## WebSocket protocol

**Client → Server**

| Type | Payload | Description |
|------|---------|-------------|
| `calibration` | `{ samples: [{eda, hr}, ...] }` | Send 60 samples to fit the HMM |
| `reading` | `{ eda: float, hr: float }` | Single biometric tick |

**Server → Client**

| Type | Payload | Description |
|------|---------|-------------|
| `calibration_ack` | `{ status: "ok" }` | HMM fitted successfully |
| `update` | `{ patient_id, eda, hr, state, insight }` | Live reading with HMM state (0–2) and optional Claude insight |
| `alert` | `{ patient_id }` | Manual alert broadcast |

HMM states: `0` = calm/baseline, `1` = moderate arousal, `2` = high stress.

---

## Project structure

```
neurosense/
├── backend/
│   ├── main.py              # FastAPI app, BioEngine, WebSocket handler
│   ├── requirements.txt
│   ├── .env.example
│   └── scripts/
│       └── simulate_sensors.py
└── frontend/
    ├── lib/
    │   ├── main.dart
    │   ├── models/
    │   ├── screens/
    │   ├── services/
    │   └── widgets/
    └── pubspec.yaml
```
