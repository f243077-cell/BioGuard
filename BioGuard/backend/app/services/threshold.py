"""
BioGuard Backend — Threshold Evaluation
Pure functions that decide whether a reading breaches an alert-worthy condition.
"""

from typing import Dict

from app.config import TEMP_ALERT_MAX_C, TEMP_ALERT_MIN_C

# Max allowed change between two consecutive readings for the same device
# before it's flagged as a rapid change, even if still inside the safe range.
TEMP_RATE_OF_CHANGE_LIMIT_C = 3.0

_last_temp_by_device: Dict[str, float] = {}


def temperature_breached(temp_c: float) -> bool:
    """True if temperature falls outside the safe range."""
    return temp_c < TEMP_ALERT_MIN_C or temp_c > TEMP_ALERT_MAX_C


def lock_breached(status: str) -> bool:
    """True if the lock is not in the expected 'locked' state."""
    return status != "locked"


def temperature_severity(temp_c: float) -> str:
    """'critical' if far outside range, otherwise 'warning'."""
    margin = 5.0
    if temp_c < TEMP_ALERT_MIN_C - margin or temp_c > TEMP_ALERT_MAX_C + margin:
        return "critical"
    return "warning"


def temperature_rate_of_change_breached(device_id: str, temp_c: float) -> bool:
    """
    True if this device's temperature moved more than the allowed limit
    since its last reading — an early-warning signal even when still
    within the normal range. First reading for a device never triggers
    (nothing to compare against yet).
    """
    previous = _last_temp_by_device.get(device_id)
    _last_temp_by_device[device_id] = temp_c
    if previous is None:
        return False
    return abs(temp_c - previous) > TEMP_RATE_OF_CHANGE_LIMIT_C