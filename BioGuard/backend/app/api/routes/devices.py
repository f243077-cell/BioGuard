"""
BioGuard Backend — Device Routes
Exposes latest status and historical readings per device.
"""

from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.device import Device
from app.models.reading import Reading
from app.models.user import User
from app.schemas.reading import DeviceStatus, ReadingOut

router = APIRouter(prefix="/devices", tags=["devices"])


@router.get("", response_model=List[DeviceStatus])
def list_devices(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Latest temperature + lock reading for every device seen so far, plus
    its name/location if set (e.g. via scripts/seed_devices.py) — a device
    with no readings yet still doesn't appear, same as before."""
    device_ids = [row[0] for row in db.query(Reading.device_id).distinct().all()]
    if not device_ids:
        return []

    devices_by_id = {
        device.device_id: device
        for device in db.query(Device).filter(Device.device_id.in_(device_ids)).all()
    }

    results = []
    for device_id in device_ids:
        latest_temp = (
            db.query(Reading)
            .filter(Reading.device_id == device_id, Reading.reading_type == "temperature")
            .order_by(Reading.timestamp.desc())
            .first()
        )
        latest_lock = (
            db.query(Reading)
            .filter(Reading.device_id == device_id, Reading.reading_type == "lock")
            .order_by(Reading.timestamp.desc())
            .first()
        )
        meta = devices_by_id.get(device_id)
        results.append(
            DeviceStatus(
                device_id=device_id,
                name=meta.name if meta else None,
                location=meta.location if meta else None,
                temperature=latest_temp,
                lock=latest_lock,
            )
        )

    return results


@router.get("/{device_id}/history", response_model=List[ReadingOut])
def device_history(
    device_id: str,
    reading_type: Optional[str] = Query(default=None, pattern="^(temperature|lock)$"),
    limit: int = Query(default=100, ge=1, le=1000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Historical readings for a single device, most recent first."""
    query = db.query(Reading).filter(Reading.device_id == device_id)
    if reading_type:
        query = query.filter(Reading.reading_type == reading_type)

    return query.order_by(Reading.timestamp.desc()).limit(limit).all()