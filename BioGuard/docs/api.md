# BioGuard Backend — API Reference

Base URL: `http://<backend-host>:8000` (`http://localhost:8000` for a local
run; `http://10.0.2.2:8000` from the Android emulator — see the frontend
README section for physical devices).

Interactive, always-current docs are also served by the running backend at
`/docs` (Swagger UI) and `/redoc`.

All endpoints except `/`, `/auth/register` and `/auth/login` require a JWT:

```
Authorization: Bearer <token>
```

Timestamps are always returned as UTC with an explicit offset (e.g.
`2026-09-24T11:45:02.462663Z`) — never a bare local-looking time.

---

## Auth

### `POST /auth/register`
Create an account. Does **not** log you in — call `/auth/login` after.

Body: `{"username": "nurse", "password": "secret123"}`
- `username`: 3–50 characters
- `password`: 6–72 bytes (bcrypt's own limit; a longer password is rejected
  with 400, not a server error)

201 → `{"id": 1, "username": "nurse"}`
400 → username taken, or either field fails validation

### `POST /auth/login`
Body: `{"username": "nurse", "password": "secret123"}`

200 → `{"access_token": "<jwt>", "token_type": "bearer"}`
401 → wrong username/password

Tokens expire after `JWT_EXPIRE_MINUTES` (default 1440 = 24h).

---

## Devices

### `GET /devices`
Latest temperature + lock reading for every device that has ever sent one,
plus its name/location if set (see `scripts/seed_devices.py`). A device
that's never published a reading doesn't appear, even if it has a `Device`
row (e.g. freshly seeded but not yet running).

```json
[
  {
    "device_id": "device-001",
    "name": "Vaccine Fridge — Ward A",
    "location": "Ward A, Level 2",
    "temperature": {
      "id": 42, "device_id": "device-001", "reading_type": "temperature",
      "numeric_value": 4.2, "status_value": null, "anomalous": false,
      "timestamp": "2026-09-24T11:45:02.462663Z"
    },
    "lock": {
      "id": 43, "device_id": "device-001", "reading_type": "lock",
      "numeric_value": null, "status_value": "locked", "anomalous": false,
      "timestamp": "2026-09-24T11:45:02.462874Z"
    }
  }
]
```

`name`/`location` are `null` for an auto-registered device that's never
been named.

### `GET /devices/{device_id}/history`
Historical readings for one device, most recent first.

Query params:
- `reading_type`: `temperature` or `lock` (omit for both, interleaved)
- `limit`: 1–1000, default 100

Returns a list of the same reading shape shown above.

---

## Alerts

### `GET /alerts`
Alert history, most recent first.

Query params:
- `device_id`: filter to one device
- `resolved`: `true`/`false`
- `limit`: 1–1000, default 100

```json
[
  {
    "id": 7, "device_id": "device-002", "reading_id": 401,
    "alert_type": "temperature_out_of_range",
    "message": "Temperature 9.8°C is outside the safe range",
    "severity": "critical", "resolved": false,
    "created_at": "2026-09-24T11:45:02.938758Z", "resolved_at": null,
    "notes": null
  }
]
```

`alert_type` is one of `temperature_out_of_range`, `temperature_rapid_change`,
`lock_open`. `severity` is `warning` or `critical` — a temperature alert
that starts as a warning escalates to critical in place (same `id`) if the
reading drifts more than 5°C past the threshold, rather than staying a
warning indefinitely; a lock alert is always `critical`. `notes` exists in
the schema for a future acknowledgment workflow but nothing writes it yet.

---

## Reports

### `GET /reports/pdf/{device_id}`
Generates a PDF summary (last 50 readings, last 20 alerts) for one device
and returns it as `application/pdf`.

Also accepts the token as a query parameter (`?token=<jwt>`) instead of the
`Authorization` header, since a PDF is typically opened directly in a
browser/viewer that can't attach custom headers:

```
GET /reports/pdf/device-001?token=<jwt>
```

500 if generation fails (logged server-side with the underlying reason).

---

## WebSocket

### `WS /ws/alerts`
Push channel for alert create/escalate/resolve events — the same JSON
shape as one item from `GET /alerts` above, sent the moment the backend's
MQTT ingestion evaluates a reading that changes an alert's state.

Auth: `?token=<jwt>` query param, or an `Authorization: Bearer` header if
your WebSocket client supports one.

- Invalid/missing token → the connection is accepted then immediately
  closed with code **4401** (not a handshake rejection — connect first,
  then check the close code).
- The server never expects anything from the client after connecting; it's
  push-only. Send whatever keepalive your client needs, or nothing.
- Readings themselves are **not** pushed here, only alerts — `GET /devices`
  is still polled for live temperature/lock values (see
  `docs/architecture.md` for why).

---

## Health

### `GET /`
No auth required. `{"status": "ok", "service": "BioGuard Backend"}` —
used as the Docker healthcheck.
