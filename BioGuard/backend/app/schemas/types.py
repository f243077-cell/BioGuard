"""
BioGuard Backend — Shared Schema Types
"""

from datetime import datetime, timezone
from typing import Annotated

from pydantic import AfterValidator


def as_utc(value: datetime) -> datetime:
    """Timestamps are stored as naive UTC. Mark them as UTC so the API
    serializes an explicit offset instead of a bare time that clients
    would misread as their own local time."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


UTCDateTime = Annotated[datetime, AfterValidator(as_utc)]
