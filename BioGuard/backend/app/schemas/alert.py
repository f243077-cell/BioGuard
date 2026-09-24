"""
BioGuard Backend — Alert Schemas
Pydantic models for API responses built from the Alert ORM model.
"""

from typing import Optional

from pydantic import BaseModel, ConfigDict

from app.schemas.types import UTCDateTime


class AlertOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    device_id: str
    reading_id: Optional[int] = None
    alert_type: str
    message: str
    severity: str
    resolved: bool
    created_at: UTCDateTime
    resolved_at: Optional[UTCDateTime] = None
    notes: Optional[str] = None