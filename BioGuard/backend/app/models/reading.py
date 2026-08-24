"""
BioGuard Backend — Reading Model
Stores each temperature/lock reading published by a device.
"""

from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Float, Integer, String

from app.db.base import Base


class Reading(Base):
    __tablename__ = "readings"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String, index=True, nullable=False)
    reading_type = Column(String, nullable=False)        # "temperature" or "lock"
    numeric_value = Column(Float, nullable=True)          # set for temperature readings
    status_value = Column(String, nullable=True)          # set for lock readings ("locked"/"unlocked")
    anomalous = Column(Boolean, default=False, nullable=False)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)

    def __repr__(self) -> str:
        return f"<Reading {self.device_id} {self.reading_type}={self.numeric_value or self.status_value} @ {self.timestamp}>"