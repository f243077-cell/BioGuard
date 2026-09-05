"""
BioGuard Backend — Device Model
Represents a physical (simulated) storage unit. Auto-registered on first
reading from a new device_id, with default thresholds from config.
"""

from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Float, String

from app.db.base import Base


class Device(Base):
    __tablename__ = "devices"

    # device_id doubles as the primary key — matches the string already
    # used everywhere (Reading.device_id, Alert.device_id, MQTT topics),
    # so no new foreign key reconciliation is needed.
    device_id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=True)
    location = Column(String, nullable=True)
    threshold_min = Column(Float, nullable=False)
    threshold_max = Column(Float, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    def __repr__(self) -> str:
        return f"<Device {self.device_id} range=({self.threshold_min}, {self.threshold_max})>"