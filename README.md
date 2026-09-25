# BioGuard

Cold-chain monitoring for temperature-sensitive medical storage (vaccines,
insulin, biologics). A simulated smart-safe sensor publishes readings over
MQTT; a FastAPI backend ingests them, evaluates thresholds, and serves a
Flutter app that shows live status, sounds an alarm on a critical alert,
and generates a PDF compliance report.

This is a demonstration/portfolio build: the sensors are simulated in
software, not real hardware — see `PRD.md` for the original goals and
`BioGuard/docs/architecture.md` for what's actually implemented, including
an honest list of what's deliberately still missing.

```
 Simulator(s)  ──MQTT──▶  Broker  ──MQTT──▶  Backend (FastAPI + SQLite)  ──REST/WS──▶  Flutter app
```

All the code lives under `BioGuard/` (backend, simulator, broker,
frontend) — this file and `PRD.md`/`File_Structure.md` sit one level up.
Every command below starts from this repo root.

## Quick start (Docker — recommended)

Needs [Docker](https://docs.docker.com/get-docker/) with Compose v2.

```bash
cd BioGuard
./scripts/start_dev.sh
```

This builds and starts the broker, backend, and three simulated devices
(`device-001/002/003`). First run creates `BioGuard/.env` from
`.env.example` automatically. Once it's up:

- Backend: http://localhost:8000 (interactive API docs at `/docs`)
- MQTT broker: `localhost:1883`

Stop everything with `./scripts/start_dev.sh down` (run from `BioGuard/`).
See the comments at the top of `BioGuard/docker-compose.yml` for what each
service does, and `BioGuard/.env.example` for what's configurable (ports,
JWT secret, Firebase).

Give the three demo devices friendly names instead of blank auto-registered
ones (optional, safe to re-run):

```bash
cd BioGuard
python scripts/seed_devices.py
```

## Quick start (without Docker)

Three terminals, all starting from this repo root:

```bash
# 1. Broker
cd BioGuard
docker run -p 1883:1883 -v "$PWD/broker/mosquitto.conf:/mosquitto/config/mosquitto.conf" eclipse-mosquitto
```

```bash
# 2. Backend
cd BioGuard/backend
pip install -r requirements.txt
uvicorn app.main:app --reload
# migrations run automatically on startup — no manual alembic step needed
```

```bash
# 3. Simulator (one process per device; repeat with a different DEVICE_ID for more)
cd BioGuard/simulator
pip install -r requirements.txt
DEVICE_ID=device-001 python main.py
```

## Running the app

```bash
cd BioGuard/frontend
flutter pub get
flutter run
```

The default backend address (`http://10.0.2.2:8000`) only works from the
**Android emulator** — it's a special address the emulator maps to your
own machine. For a physical device, iOS simulator, desktop, or web, point
it at your machine's real LAN IP or hostname instead:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000
```

On first launch, register an account from the login screen — there's no
seeded user.

## Testing

```bash
cd BioGuard/backend
pip install -r requirements-dev.txt
pytest
```

```bash
cd BioGuard/frontend
flutter analyze
```

## Project layout

- `BioGuard/backend/` — FastAPI app, SQLAlchemy models, Alembic
  migrations, tests
- `BioGuard/simulator/` — publishes simulated readings over MQTT
- `BioGuard/broker/` — Mosquitto config
- `BioGuard/frontend/` — the Flutter app
- `BioGuard/scripts/` — `start_dev.sh` (Docker Compose wrapper),
  `seed_devices.py`
- `BioGuard/docs/` — `architecture.md` (as-built system + known
  limitations), `api.md` (endpoint reference)
- `PRD.md` — the original product requirements doc
- `File_Structure.md` — full repo tree

## Further reading

- **`BioGuard/docs/architecture.md`** — how it actually works, the
  reasoning behind a handful of non-obvious decisions (WAL mode, alert
  escalation, polling vs. pushing), and a direct list of what's not built
  yet.
- **`BioGuard/docs/api.md`** — every REST endpoint and the WebSocket, with
  example responses.
