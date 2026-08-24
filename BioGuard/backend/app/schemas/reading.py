"""
BioGuard Backend — Reading Schemas
Pydantic models for API responses built from the Reading ORM model.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class ReadingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    device_id: str
    reading_type: str
    numeric_value: Optional[float] = None
    status_value: Optional[str] = None
    anomalous: bool
    timestamp: datetime


class DeviceStatus(BaseModel):
    device_id: str
    temperature: Optional[ReadingOut] = None
    lock: Optional[ReadingOut] = None