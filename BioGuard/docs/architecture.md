# BioGuard — Architecture (as built)

This describes the system as it actually runs today. For the original
product goals and phased plan, see `../../PRD.md` (repo root, one level
above the `BioGuard/` project folder this file lives in) — this document
only covers what's implemented and how, not what's planned.

## Components

```
 Simulator(s)                Broker              Backend                  Clinician App
 ─────────────           ─────────────        ───────────────           ──────────────────
 python main.py   ─MQTT──▶ Mosquitto    ─MQTT──▶ FastAPI + MQTT   ─REST/WS──▶ Flutter (glass UI)
 (1 per device)             (pub/sub,             subscriber
                             no logic)            + SQLite
```

- **Simulator** (`simulator/`) — generates temperature + lock readings on
  an interval and publishes them as JSON to
  `bioguard/<device_id>/temperature` and `bioguard/<device_id>/lock`.
  Anomalies run as multi-reading "episodes" that drift toward an abnormal
  value and back (`simulator/utils/anomaly.py`), rather than a single
  random spike, to look like real equipment drift. One process = one
  device; `docker-compose.yml` runs three (`device-001/002/003`).

- **Broker** (`broker/mosquitto.conf`) — plain Mosquitto, no auth
  (development only — see Known Limitations). Configured with
  `persistence true` so QoS 1 messages queued for a disconnected client
  survive a broker restart, not just a client reconnect.

- **Backend** (`backend/`) — FastAPI app plus a paho-mqtt client running
  in a background thread (`app/mqtt/client.py`), both started from the
  same process via FastAPI's lifespan hook. SQLite by default
  (`DATABASE_URL` swaps it for Postgres/etc. — nothing else assumes
  SQLite except the WAL pragma below). Alembic migrations run
  automatically on startup (`app/db/session.py::init_db`), so a fresh
  database needs no manual `alembic upgrade head`.

- **Frontend** (`frontend/`) — Flutter, Riverpod for state, `flutter_secure_storage`
  for the JWT. REST for devices/alerts/reports, a WebSocket for live
  alerts, local notification sound for critical alerts in the foreground.

## Data flow: a reading landing

1. Simulator publishes `{"device_id", "timestamp", "value", "anomalous"}`
   (QoS 1) to its topic.
2. Backend's MQTT thread receives it (`app/mqtt/handlers.py`) and:
   - Takes `device_id` **from the topic**, not the payload — a spoofed or
     mismatched `device_id` in the JSON is logged and ignored.
   - Validates the value's shape (finite number for temperature, a known
     string for lock) and the timestamp's plausibility (within a day in
     the past, 5 minutes in the future); anything else is rejected and
     logged, never raised — a network hiccup or a single bad reading
     can't take down ingestion for every other device.
   - Recomputes `anomalous` itself from the *device's own configured
     thresholds* — the simulator's own opinion in the payload is ignored,
     so a per-device threshold change (or a lock reading, which the
     simulator doesn't self-flag at all) is still reflected correctly.
   - Writes the `Reading` row, then runs it through
     `app/services/alert_service.py`.
3. `alert_service` checks each applicable condition
   (`app/services/threshold.py`) and opens, **escalates**, or resolves the
   matching `Alert`:
   - A temperature reading just past the safe range opens a `warning`.
   - If a later reading is more than 5°C past the range, the *same* alert
     (same id) is escalated to `critical` in place, rather than staying a
     warning however far it drifts — this is what actually triggers the
     app's audible alarm, so a gradual drift needs to reach the app as
     critical, not stay silently classified as a warning forever.
   - A lock reading that isn't `"locked"` is always `critical` immediately
     — there's no gradual case for a door.
   - Back to normal resolves the open alert.
4. Any alert that changed state is broadcast to every connected
   `/ws/alerts` client and (if configured) pushed via FCM.

## Why polling for devices but pushing for alerts

`GET /devices` is polled by the app every 5 seconds; only alerts go over
the WebSocket. This is a real asymmetry, not an oversight: alerts are rare
state-change events where latency matters (an alarm should sound within
seconds), while live temperature readings are a continuous stream where a
5-second-old value is fine for a dashboard glance. Pushing every reading
would mean a WebSocket message every few seconds per device even when
nothing is wrong, for a value the user is looking at, not reacting to.

## Concurrency and durability choices

- **SQLite in WAL mode** (`app/db/session.py`) — enabled on every
  connection. Without it, the API's reads and the MQTT thread's writes
  would contend for the same file lock; a poll landing mid-write would
  occasionally see "database is locked" instead of a response.
- **MQTT reconnection is unconditional and doesn't crash the process** —
  both the backend and every simulator use `connect_async` + `loop_start`
  with backoff, so a broker that isn't up yet (or drops) is retried
  forever rather than raising at startup. Combined with the broker's own
  persistence and QoS 1 + `clean_session=False` on the backend's
  subscription, a reading published while the backend (or the broker) is
  down is still delivered once everything's back, not lost. This is
  covered by an end-to-end test that kills each component in turn while
  the others keep running.
- **A bad MQTT message never stops ingestion** — `_on_message` in
  `app/mqtt/client.py` catches and logs; paho re-raises callback
  exceptions by default, which would otherwise kill the whole network
  thread (silently stopping ingestion for every device) on the very first
  malformed payload.

## Docker topology

`docker-compose.yml` runs broker + backend + 3 simulators. Two design
choices worth calling out:

- **No explicit health-gating between services.** `depends_on` only
  controls container start *order*; nothing waits for the backend to be
  "ready" before the broker is, because nothing needs to — the retry
  behavior above means startup order genuinely doesn't matter.
- **SQLite lives in a named volume (`backend-data`), not the image or a
  bind mount to `backend/`** — so `docker compose down && up` (even a full
  recreate, not just a restart) doesn't lose data, and the image never
  accidentally ships a snapshot of whatever's in your local
  `backend/bioguard.db`.

## Known limitations (deliberately out of scope so far)

These are real gaps, not overlooked — each would be its own small project:

- **No MQTT auth.** `allow_anonymous true` in `broker/mosquitto.conf` — on
  a shared network, anything can publish fake readings. Fine for a laptop
  demo, not for anything beyond it.
- **No after-hours lock rule.** The PRD's "unusual access" idea (an unlock
  is only suspicious outside a scheduled window) isn't implemented — every
  unlock is currently `critical`, regardless of time.
- **No device-offline detection.** A device that stops publishing entirely
  just goes quiet — its dashboard card keeps showing its last reading as
  current, with no "no data in N minutes" alert.
- **No alert acknowledgment workflow.** `Alert.notes` exists in the schema
  for this but nothing writes it — there's no way for staff to record who
  handled an alert.
- **No user roles.** Every account can do everything; the PRD's
  nurse/doctor/compliance-officer distinction doesn't exist.
- **No tamper-evidence mechanism.** Readings are ordinary mutable rows —
  the PRD's own risk section already flags this as needing a concrete
  answer (e.g. hash-chained records) before "tamper-evident" is a fair
  claim.
- **Report has no date range** — always the most recent 50 readings / 20
  alerts for a device, not a requested period.
