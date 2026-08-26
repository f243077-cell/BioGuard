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

__all__ = ["get_db", "get_current_user", "get_current_user_flexible", "resolve_user_from_flexible_token"]

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


def _extract_bearer_token(authorization_header: Optional[str]) -> Optional[str]:
    if authorization_header and authorization_header.lower().startswith("bearer "):
        return authorization_header[7:]
    return None


def resolve_user_from_flexible_token(
    token: Optional[str],
    authorization_header: Optional[str],
    db: Session,
) -> User:
    """Accept token via ?token= query param OR Authorization: Bearer header."""
    return _resolve_user(token or _extract_bearer_token(authorization_header), db)


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
    return resolve_user_from_flexible_token(
        token,
        f"Bearer {credentials.credentials}" if credentials else None,
        db,
    )