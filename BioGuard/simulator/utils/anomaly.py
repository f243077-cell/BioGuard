"""
BioGuard Simulator — Anomaly Injection
Anomalies run as stateful "episodes": once triggered, a value drifts
gradually toward an anomalous target over several readings and drifts
back afterward, instead of teleporting to a random value on a single
reading. This mimics real equipment failure (e.g. a fridge losing
cooling over minutes) rather than sensor noise.
"""

import random

from config import (
    ANOMALY_EPISODE_MAX_READINGS,
    ANOMALY_EPISODE_MIN_READINGS,
    ANOMALY_INJECTION_ENABLED,
    ANOMALY_PROBABILITY,
    LOCK_ANOMALY_PROBABILITY,
    TEMP_ANOMALY_MAX_C,
    TEMP_ANOMALY_MIN_C,
    TEMP_DRIFT_STEP_C,
    TEMP_NOISE_STD_C,
    TEMP_NORMAL_MAX_C,
    TEMP_NORMAL_MIN_C,
)

_TEMP_MIDPOINT = (TEMP_NORMAL_MIN_C + TEMP_NORMAL_MAX_C) / 2

_temp_episode = {"active": False, "readings_left": 0, "target": None}
_lock_episode = {"active": False, "readings_left": 0}
_last_temp = _TEMP_MIDPOINT


def _drift_toward(current: float, target: float) -> float:
    step = max(-TEMP_DRIFT_STEP_C, min(TEMP_DRIFT_STEP_C, target - current))
    return current + step + random.gauss(0, TEMP_NOISE_STD_C)


def generate_temperature() -> float:
    """Return a temperature reading. Occasionally starts a multi-reading
    anomaly episode that drifts toward an anomalous value and back."""
    global _last_temp

    if not _temp_episode["active"] and ANOMALY_INJECTION_ENABLED and random.random() < ANOMALY_PROBABILITY:
        _temp_episode["active"] = True
        _temp_episode["readings_left"] = random.randint(ANOMALY_EPISODE_MIN_READINGS, ANOMALY_EPISODE_MAX_READINGS)
        _temp_episode["target"] = round(random.uniform(TEMP_ANOMALY_MIN_C, TEMP_ANOMALY_MAX_C), 2)

    if _temp_episode["active"]:
        target = _temp_episode["target"]
        _temp_episode["readings_left"] -= 1
        if _temp_episode["readings_left"] <= 0:
            _temp_episode["active"] = False
            _temp_episode["target"] = None
    else:
        target = _TEMP_MIDPOINT

    _last_temp = _drift_toward(_last_temp, target)
    return round(_last_temp, 2)


def generate_lock_status() -> str:
    """Return 'locked' normally. Occasionally starts a multi-reading
    'unlocked' episode instead of flickering on a single reading."""
    if not _lock_episode["active"] and ANOMALY_INJECTION_ENABLED and random.random() < LOCK_ANOMALY_PROBABILITY:
        _lock_episode["active"] = True
        _lock_episode["readings_left"] = random.randint(2, 5)

    if _lock_episode["active"]:
        _lock_episode["readings_left"] -= 1
        if _lock_episode["readings_left"] <= 0:
            _lock_episode["active"] = False
        return "unlocked"

    return "locked"


def is_temperature_anomalous(temp_c: float) -> bool:
    """Flag whether a temperature reading falls outside the normal range."""
    return not (TEMP_NORMAL_MIN_C <= temp_c <= TEMP_NORMAL_MAX_C)