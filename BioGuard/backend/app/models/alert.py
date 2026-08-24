"""
BioGuard Backend — Alert Model
Stores threshold-breach alerts generated from readings.
"""

from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String

from app.db.base import Base


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String, index=True, nullable=False)
    reading_id = Column(Integer, ForeignKey("readings.id"), nullable=True)
    alert_type = Column(String, nullable=False)    # "temperature_out_of_range" | "lock_open"
    message = Column(String, nullable=False)
    severity = Column(String, default="warning", nullable=False)  # "warning" | "critical"
    resolved = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    resolved_at = Column(DateTime, nullable=True)

    def __repr__(self) -> str:
        return f"<Alert {self.device_id} {self.alert_type} severity={self.severity} resolved={self.resolved}>"