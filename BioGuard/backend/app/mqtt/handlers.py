"""
BioGuard Backend — MQTT Message Handlers
Validates incoming MQTT payloads and persists them as Reading rows.

Expected topic:   bioguard/<device_id>/<temperature|lock>
Expected payload: {"value": <float | "locked" | "unlocked">, "timestamp": <ISO 8601>}

The device id is taken from the topic (what the broker routed on), and
`anomalous` is computed here from the device's configured thresholds — a
device's own opinion of what counts as anomalous is ignored.
"""

import json
import math
from datetime import datetime, timedelta, timezone
from typing import Optional, Union

from app.api.routes.websocket import broadcast_alert_sync
from app.db.session import SessionLocal
from app.models.reading import Reading
from app.schemas.alert import AlertOut
from app.services.alert_service import evaluate_and_record
from app.services.device_service import get_or_create_device
from app.services.threshold import LOCK_STATES, lock_breached, temperature_breached

# Device clocks are trusted within this window; outside it (unset clock,
# wrong year) the server's receive time is used instead.
_MAX_FUTURE_SKEW = timedelta(minutes=5)
_MAX_AGE = timedelta(hours=24)


def handle_temperature_message(topic: str, payload: bytes) -> None:
    _store_reading(topic, payload, reading_type="temperature")


def handle_lock_message(topic: str, payload: bytes) -> None:
    _store_reading(topic, payload, reading_type="lock")


def _device_id_from_topic(topic: str) -> Optional[str]:
    parts = topic.split("/")
    if len(parts) != 3 or not parts[1]:
        return None
    return parts[1]


def _parse_value(reading_type: str, raw) -> Optional[Union[float, str]]:
    """Return a clean value, or None if the payload's value is unusable."""
    if reading_type == "temperature":
        # bool is a subclass of int — reject it explicitly.
        if isinstance(raw, bool) or not isinstance(raw, (int, float)):
            return None
        value = float(raw)
        return value if math.isfinite(value) else None

    if isinstance(raw, str) and raw.strip().lower() in LOCK_STATES:
        return raw.strip().lower()
    return None


def _parse_timestamp(raw, now: datetime) -> Optional[datetime]:
    """Device-reported time as naive UTC, or None if missing or implausible."""
    if not isinstance(raw, str):
        return None
    try:
        ts = datetime.fromisoformat(raw)
    except ValueError:
        return None
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    ts = ts.astimezone(timezone.utc)
    if not now - _MAX_AGE <= ts <= now + _MAX_FUTURE_SKEW:
        return None
    return ts.replace(tzinfo=None)


def _store_reading(topic: str, payload: bytes, reading_type: str) -> None:
    device_id = _device_id_from_topic(topic)
    if device_id is None:
        print(f"[BioGuard Backend] Ignoring message on malformed topic: {topic}")
        return

    try:
        data = json.loads(payload.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        print(f"[BioGuard Backend] Bad payload on {topic}: {exc}")
        return
    if not isinstance(data, dict):
        print(f"[BioGuard Backend] Bad payload on {topic}: expected a JSON object")
        return

    value = _parse_value(reading_type, data.get("value"))
    if value is None:
        print(f"[BioGuard Backend] Rejected {reading_type} reading from {device_id}: invalid value {data.get('value')!r}")
        return

    payload_device_id = data.get("device_id")
    if payload_device_id is not None and payload_device_id != device_id:
        print(f"[BioGuard Backend] Payload device_id {payload_device_id!r} does not match topic; using {device_id!r}")

    now = datetime.now(timezone.utc)
    timestamp = _parse_timestamp(data.get("timestamp"), now) or now.replace(tzinfo=None)

    db = SessionLocal()
    try:
        device = get_or_create_device(db, device_id)

        previous_temp = None
        if reading_type == "temperature":
            anomalous = temperature_breached(value, device.threshold_min, device.threshold_max)
            previous = (
                db.query(Reading.numeric_value)
                .filter(
                    Reading.device_id == device_id,
                    Reading.reading_type == "temperature",
                    Reading.timestamp <= timestamp,
                )
                .order_by(Reading.timestamp.desc())
                .first()
            )
            previous_temp = previous[0] if previous else None
        else:
            anomalous = lock_breached(value)

        reading = Reading(
            device_id=device_id,
            reading_type=reading_type,
            numeric_value=value if reading_type == "temperature" else None,
            status_value=value if reading_type == "lock" else None,
            anomalous=anomalous,
            timestamp=timestamp,
        )
        db.add(reading)
        db.commit()
        db.refresh(reading)
        print(f"[BioGuard Backend] Stored {reading_type} reading from {device_id}: {value}")

        alerts = evaluate_and_record(
            db,
            device_id=device_id,
            reading_id=reading.id,
            reading_type=reading_type,
            value=value,
            previous_value=previous_temp,
            threshold_min=device.threshold_min,
            threshold_max=device.threshold_max,
        )
        for alert in alerts:
            broadcast_alert_sync(AlertOut.model_validate(alert).model_dump(mode="json"))
    except Exception as exc:
        db.rollback()
        print(f"[BioGuard Backend] Failed to store reading: {exc}")
    finally:
        db.close()
