"""
BioGuard Backend — Alert Schemas
Pydantic models for API responses built from the Alert ORM model.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class AlertOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    device_id: str
    reading_id: Optional[int] = None
    alert_type: str
    message: str
    severity: str
    resolved: bool
    created_at: datetime
    resolved_at: Optional[datetime] = None