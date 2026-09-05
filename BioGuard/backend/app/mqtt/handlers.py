"""
BioGuard Backend — MQTT Message Handlers
Parses incoming MQTT payloads and persists them as Reading rows.
"""

import json

from app.api.routes.websocket import broadcast_alert_sync
from app.db.session import SessionLocal
from app.models.reading import Reading
from app.services.alert_service import evaluate_and_record
from app.services.device_service import get_or_create_device


def handle_temperature_message(topic: str, payload: bytes) -> None:
    _store_reading(topic, payload, reading_type="temperature")


def handle_lock_message(topic: str, payload: bytes) -> None:
    _store_reading(topic, payload, reading_type="lock")


def _store_reading(topic: str, payload: bytes, reading_type: str) -> None:
    try:
        data = json.loads(payload.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        print(f"[BioGuard Backend] Bad payload on {topic}: {exc}")
        return

    device_id = data.get("device_id", "unknown")
    value = data.get("value")
    anomalous = bool(data.get("anomalous", False))

    reading = Reading(
        device_id=device_id,
        reading_type=reading_type,
        anomalous=anomalous,
    )

    if reading_type == "temperature":
        reading.numeric_value = value
    else:
        reading.status_value = value

    db = SessionLocal()
    try:
        device = get_or_create_device(db, device_id)

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
            threshold_min=device.threshold_min,
            threshold_max=device.threshold_max,
        )
        for alert in alerts:
            broadcast_alert_sync(
                {
                    "id": alert.id,
                    "device_id": alert.device_id,
                    "alert_type": alert.alert_type,
                    "message": alert.message,
                    "severity": alert.severity,
                    "resolved": alert.resolved,
                    "created_at": alert.created_at.isoformat() if alert.created_at else None,
                    "resolved_at": alert.resolved_at.isoformat() if alert.resolved_at else None,
                }
            )
    except Exception as exc:
        db.rollback()
        print(f"[BioGuard Backend] Failed to store reading: {exc}")
    finally:
        db.close()