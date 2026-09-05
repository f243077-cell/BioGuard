"""
BioGuard Backend — Threshold Evaluation
Pure functions that decide whether a reading breaches an alert-worthy condition.
"""

from typing import Dict

# Max allowed change between two consecutive readings for the same device
# before it's flagged as a rapid change, even if still inside the safe range.
TEMP_RATE_OF_CHANGE_LIMIT_C = 3.0

_last_temp_by_device: Dict[str, float] = {}


def temperature_breached(temp_c: float, threshold_min: float, threshold_max: float) -> bool:
    """True if temperature falls outside this device's safe range."""
    return temp_c < threshold_min or temp_c > threshold_max


def lock_breached(status: str) -> bool:
    """True if the lock is not in the expected 'locked' state."""
    return status != "locked"


def temperature_severity(temp_c: float, threshold_min: float, threshold_max: float) -> str:
    """'critical' if far outside range, otherwise 'warning'."""
    margin = 5.0
    if temp_c < threshold_min - margin or temp_c > threshold_max + margin:
        return "critical"
    return "warning"


def temperature_rate_of_change_breached(device_id: str, temp_c: float) -> bool:
    """
    True if this device's temperature moved more than the allowed limit
    since its last reading. Unaffected by per-device thresholds — this is
    about rate of change, not absolute range.
    """
    previous = _last_temp_by_device.get(device_id)
    _last_temp_by_device[device_id] = temp_c
    if previous is None:
        return False
    return abs(temp_c - previous) > TEMP_RATE_OF_CHANGE_LIMIT_C