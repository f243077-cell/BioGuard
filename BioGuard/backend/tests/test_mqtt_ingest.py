import json
import time
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.models.alert import Alert
from app.models.device import Device
from app.models.reading import Reading
from app.mqtt import client as mqtt_client
from app.mqtt.handlers import handle_lock_message, handle_temperature_message


def _send_temp(device_id, value, **extra):
    handle_temperature_message(
        f"bioguard/{device_id}/temperature",
        json.dumps({"device_id": device_id, "value": value, **extra}).encode(),
    )


def _send_lock(device_id, value):
    handle_lock_message(f"bioguard/{device_id}/lock", json.dumps({"value": value}).encode())


def test_valid_reading_is_stored(db):
    _send_temp("fridge-1", 5.0)
    reading = db.query(Reading).one()
    assert (reading.device_id, reading.numeric_value, reading.anomalous) == ("fridge-1", 5.0, False)


@pytest.mark.parametrize(
    "topic, payload",
    [
        ("bioguard/fridge-1/temperature", b"not json"),
        ("bioguard/fridge-1/temperature", b"\xff\xfe"),
        ("bioguard/fridge-1/temperature", b"[1, 2]"),
        ("bioguard/fridge-1/temperature", b"42"),
        ("bioguard/fridge-1/temperature", b'{"device_id": "fridge-1"}'),
        ("bioguard/fridge-1/temperature", b'{"value": "hot"}'),
        ("bioguard/fridge-1/temperature", b'{"value": true}'),
        ("bioguard/fridge-1/temperature", b'{"value": NaN}'),
        ("bioguard/fridge-1/temperature", b'{"value": Infinity}'),
        ("bioguard/fridge-1/lock", b'{"value": "ajar"}'),
        ("bioguard/fridge-1/lock", b'{"value": 1}'),
        ("bioguard/temperature", b'{"value": 5.0}'),
    ],
)
def test_malformed_messages_are_rejected_without_raising(db, topic, payload):
    handler = handle_lock_message if topic.endswith("/lock") else handle_temperature_message
    handler(topic, payload)
    assert db.query(Reading).count() == 0
    assert db.query(Alert).count() == 0


def test_device_id_comes_from_topic(db):
    handle_temperature_message("bioguard/fridge-1/temperature", b'{"device_id": "spoofed", "value": 5.0}')
    assert db.query(Reading).one().device_id == "fridge-1"


def test_anomalous_uses_device_thresholds_not_device_flag(db):
    db.add(Device(device_id="fridge-1", threshold_min=4.0, threshold_max=6.0))
    db.commit()
    _send_temp("fridge-1", 7.0, anomalous=False)
    assert db.query(Reading).one().anomalous is True


def test_unlocked_reading_is_anomalous(db):
    _send_lock("fridge-1", "UNLOCKED")
    reading = db.query(Reading).one()
    assert (reading.status_value, reading.anomalous) == ("unlocked", True)


def test_plausible_device_timestamp_is_used(db):
    sent_at = datetime.now(timezone.utc) - timedelta(minutes=10)
    _send_temp("fridge-1", 5.0, timestamp=sent_at.isoformat())
    assert db.query(Reading).one().timestamp == sent_at.replace(tzinfo=None)


@pytest.mark.parametrize("bad", ["1970-01-01T00:00:00+00:00", "2999-01-01T00:00:00+00:00", "yesterday", 12345])
def test_implausible_device_timestamp_falls_back_to_server_time(db, bad):
    _send_temp("fridge-1", 5.0, timestamp=bad)
    stored = db.query(Reading).one().timestamp
    assert abs(datetime.now(timezone.utc).replace(tzinfo=None) - stored) < timedelta(seconds=30)


def test_gradual_drift_escalates_warning_to_critical(db):
    _send_temp("fridge-1", 5.0)
    _send_temp("fridge-1", 9.0)  # just past the 8°C limit
    alert = db.query(Alert).filter_by(alert_type="temperature_out_of_range").one()
    assert alert.severity == "warning"

    _send_temp("fridge-1", 11.0)
    _send_temp("fridge-1", 14.0)  # more than 5°C past the limit
    db.expire_all()
    alerts = db.query(Alert).filter_by(alert_type="temperature_out_of_range").all()
    assert len(alerts) == 1
    assert (alerts[0].severity, alerts[0].resolved) == ("critical", False)

    _send_temp("fridge-1", 5.0)
    db.expire_all()
    assert db.query(Alert).filter_by(alert_type="temperature_out_of_range").one().resolved is True


def test_rate_of_change_uses_stored_history(db):
    # The previous value is read from the database, so it still works after
    # a restart — nothing is kept in module state.
    _send_temp("fridge-1", 3.0)
    _send_temp("fridge-1", 7.5)
    rapid = db.query(Alert).filter_by(alert_type="temperature_rapid_change").one()
    assert rapid.severity == "warning"


def test_alert_changes_are_broadcast_with_utc_timestamps(monkeypatch):
    sent = []
    monkeypatch.setattr("app.mqtt.handlers.broadcast_alert_sync", sent.append)
    _send_lock("fridge-1", "unlocked")
    assert len(sent) == 1
    assert sent[0]["alert_type"] == "lock_open"
    assert sent[0]["created_at"].endswith(("Z", "+00:00"))


def test_handler_exception_does_not_escape_mqtt_callback(monkeypatch):
    def boom(topic, payload):
        raise RuntimeError("handler bug")

    monkeypatch.setattr(mqtt_client, "handle_temperature_message", boom)
    msg = SimpleNamespace(topic="bioguard/fridge-1/temperature", payload=b"{}")
    mqtt_client._on_message(None, None, msg)  # must not raise


def test_bad_fcm_credentials_do_not_block_alerts(db, monkeypatch, tmp_path):
    from app.services import fcm

    bad_creds = tmp_path / "creds.json"
    bad_creds.write_text("not a service account")
    monkeypatch.setattr(fcm, "FIREBASE_CREDENTIALS_PATH", str(bad_creds))
    monkeypatch.setattr(fcm, "_enabled", None)

    _send_lock("fridge-1", "unlocked")
    deadline = time.monotonic() + 10  # pushes run on a background pool
    while fcm._enabled is None and time.monotonic() < deadline:
        time.sleep(0.05)

    assert db.query(Alert).filter_by(alert_type="lock_open").count() == 1
    assert fcm._enabled is False
