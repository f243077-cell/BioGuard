"""
BioGuard Backend — Database Session
Creates the SQLAlchemy engine and provides a session dependency for FastAPI routes.
"""

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

from app.config import BACKEND_DIR, DATABASE_URL

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, connect_args=connect_args, pool_pre_ping=True)

if engine.dialect.name == "sqlite":

    @event.listens_for(engine, "connect")
    def _enable_sqlite_wal(dbapi_connection, _record):
        # WAL lets API reads run while the MQTT thread is writing, instead of
        # failing with "database is locked" under concurrent load.
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.close()


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def init_db() -> None:
    """Bring the schema up to date by running Alembic migrations.

    A no-op when the database is already at head, so a fresh checkout works
    without a manual `alembic upgrade head`, and an existing database picks
    up new migrations on the next start.
    """
    alembic_cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    # Keep uvicorn's logging intact — see alembic/env.py.
    alembic_cfg.attributes["configure_logger"] = False
    command.upgrade(alembic_cfg, "head")


def get_db():
    """FastAPI dependency that yields a DB session and closes it after the request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
