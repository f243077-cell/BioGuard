"""
BioGuard Backend — Alert Routes
Exposes the persisted alert history, so past events remain visible
even after the live WebSocket session that raised them has ended.
"""

from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.alert import Alert
from app.models.user import User
from app.schemas.alert import AlertOut

router = APIRouter(prefix="/alerts", tags=["alerts"])


@router.get("", response_model=List[AlertOut])
def list_alerts(
    device_id: Optional[str] = Query(default=None),
    resolved: Optional[bool] = Query(default=None),
    limit: int = Query(default=100, le=1000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Alert history, most recent first. Optionally filter by device and/or resolved status."""
    query = db.query(Alert)
    if device_id:
        query = query.filter(Alert.device_id == device_id)
    if resolved is not None:
        query = query.filter(Alert.resolved == resolved)

    return query.order_by(Alert.created_at.desc()).limit(limit).all()