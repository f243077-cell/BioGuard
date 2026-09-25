"""
BioGuard Backend — Reading Schemas
Pydantic models for API responses built from the Reading ORM model.
"""

from typing import Optional

from pydantic import BaseModel, ConfigDict

from app.schemas.types import UTCDateTime


class ReadingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    device_id: str
    reading_type: str
    numeric_value: Optional[float] = None
    status_value: Optional[str] = None
    anomalous: bool
    timestamp: UTCDateTime


class DeviceStatus(BaseModel):
    device_id: str
    # Set only once a Device row exists for this id (e.g. via
    # scripts/seed_devices.py) — null for an auto-registered device that
    # has never been named.
    name: Optional[str] = None
    location: Optional[str] = None
    temperature: Optional[ReadingOut] = None
    lock: Optional[ReadingOut] = None