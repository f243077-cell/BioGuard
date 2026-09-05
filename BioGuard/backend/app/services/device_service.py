"""
BioGuard Backend — Device Service
Auto-registers a Device row the first time a reading arrives for a
device_id we haven't seen before, seeded with the global default
thresholds. Existing devices are returned as-is.
"""

from sqlalchemy.orm import Session

from app.config import TEMP_ALERT_MAX_C, TEMP_ALERT_MIN_C
from app.models.device import Device


def get_or_create_device(db: Session, device_id: str) -> Device:
    device = db.query(Device).filter(Device.device_id == device_id).first()
    if device is not None:
        return device

    device = Device(
        device_id=device_id,
        threshold_min=TEMP_ALERT_MIN_C,
        threshold_max=TEMP_ALERT_MAX_C,
    )
    db.add(device)
    db.commit()
    db.refresh(device)
    print(f"[BioGuard Backend] Auto-registered new device: {device_id}")
    return device