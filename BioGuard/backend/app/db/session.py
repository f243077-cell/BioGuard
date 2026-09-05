"""
BioGuard Backend — Database Session
Creates the SQLAlchemy engine and provides a session dependency for FastAPI routes.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.config import DATABASE_URL
from app.db.base import Base

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, connect_args=connect_args)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def init_db() -> None:
    """Create all tables that don't exist yet.

    NOTE: schema creation is now owned by Alembic migrations. This function
    intentionally does nothing — kept as a no-op so main.py's lifespan
    doesn't need restructuring. Run `alembic upgrade head` to apply schema
    changes instead of relying on this.
    """
    pass

def get_db():
    """FastAPI dependency that yields a DB session and closes it after the request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()