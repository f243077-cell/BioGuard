"""
BioGuard Backend — Alert Service
Checks each reading against every applicable condition for its type and
opens, escalates or resolves the matching alert.
"""

from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy.orm import Session

from app.models.alert import Alert
from app.services.fcm import send_alert_push
from app.services.threshold import (
    lock_breached,
    temperature_breached,
    temperature_rate_of_change_breached,
    temperature_severity,
)

_SEVERITY_RANK = {"warning": 1, "critical": 2}


def evaluate_and_record(
    db: Session,
    *,
    device_id: str,
    reading_id: int,
    reading_type: str,
    value,
    previous_value: Optional[float] = None,
    threshold_min: float = None,
    threshold_max: float = None,
) -> List[Alert]:
    """
    Check a reading against all applicable conditions for its type. Each
    condition is tracked independently (its own create/resolve lifecycle),
    since a single reading can trigger or resolve more than one alert type
    at once — e.g. a temperature reading can resolve a rapid-change alert
    while simultaneously triggering an out-of-range one.
    Returns every Alert that changed state (created, escalated or resolved).

    threshold_min/threshold_max are the device's configured safe range and
    previous_value is the device's prior temperature — both required for
    temperature readings, unused for lock readings.
    """
    changed: List[Alert] = []

    if reading_type == "temperature":
        changed.append(
            _check_and_apply(
                db,
                device_id=device_id,
                reading_id=reading_id,
                alert_type="temperature_out_of_range",
                breached=temperature_breached(value, threshold_min, threshold_max),
                severity=temperature_severity(value, threshold_min, threshold_max),
                message=f"Temperature {value}°C is outside the safe range",
            )
        )
        changed.append(
            _check_and_apply(
                db,
                device_id=device_id,
                reading_id=reading_id,
                alert_type="temperature_rapid_change",
                breached=temperature_rate_of_change_breached(previous_value, value),
                severity="warning",
                message=f"Temperature changed rapidly to {value}°C",
            )
        )
    elif reading_type == "lock":
        changed.append(
            _check_and_apply(
                db,
                device_id=device_id,
                reading_id=reading_id,
                alert_type="lock_open",
                breached=lock_breached(value),
                severity="critical",
                message=f"Lock status is '{value}', expected 'locked'",
            )
        )

    return [alert for alert in changed if alert is not None]


def _check_and_apply(
    db: Session,
    *,
    device_id: str,
    reading_id: int,
    alert_type: str,
    breached: bool,
    severity: str,
    message: str,
) -> Optional[Alert]:
    """Create a new alert if breached and none is open, escalate the open one
    if the condition got worse, or resolve it once back to normal. Returns
    the Alert that changed, or None."""
    open_alert = (
        db.query(Alert)
        .filter(Alert.device_id == device_id, Alert.alert_type == alert_type, Alert.resolved.is_(False))
        .first()
    )

    if breached and open_alert is None:
        alert = Alert(
            device_id=device_id,
            reading_id=reading_id,
            alert_type=alert_type,
            message=message,
            severity=severity,
        )
        db.add(alert)
        db.commit()
        db.refresh(alert)
        send_alert_push(device_id=device_id, message=message, severity=severity)
        return alert

    if breached and _SEVERITY_RANK.get(severity, 0) > _SEVERITY_RANK.get(open_alert.severity, 0):
        # A gradual drift opens the alert as a warning just past the limit;
        # without escalation it would stay a warning (and never sound the
        # app's critical alarm) however far the temperature went.
        open_alert.severity = severity
        open_alert.message = message
        open_alert.reading_id = reading_id
        db.commit()
        db.refresh(open_alert)
        send_alert_push(device_id=device_id, message=message, severity=severity)
        return open_alert

    if not breached and open_alert is not None:
        open_alert.resolved = True
        open_alert.resolved_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(open_alert)
        return open_alert

    return None
