"""
BioGuard Backend — API Dependencies
Shared FastAPI dependencies for route handlers.
"""

from typing import Optional

from fastapi import Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.user import User
from app.services.auth import decode_access_token

__all__ = ["get_db", "get_current_user", "get_current_user_flexible"]

_bearer_scheme = HTTPBearer()
_optional_bearer_scheme = HTTPBearer(auto_error=False)


def _resolve_user(token: Optional[str], db: Session) -> User:
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing authentication token")

    username = decode_access_token(token)
    if username is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")

    user = db.query(User).filter(User.username == username).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return user


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Standard auth: requires an Authorization: Bearer header. Use for normal API calls."""
    return _resolve_user(credentials.credentials, db)


def get_current_user_flexible(
    token: Optional[str] = Query(default=None),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_optional_bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Accepts the token via header OR ?token= query param. Use only for routes opened
    as direct links (e.g. a PDF opened in an external browser), where a client can't
    attach a custom Authorization header."""
    return _resolve_user(credentials.credentials if credentials else token, db)