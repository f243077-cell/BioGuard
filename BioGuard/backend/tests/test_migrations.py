from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext

from app.db.base import Base
from app.db.session import engine, init_db


def test_fresh_database_matches_models():
    with engine.connect() as conn:
        diff = compare_metadata(MigrationContext.configure(conn), Base.metadata)
    assert diff == []


def test_init_db_is_idempotent():
    init_db()
    init_db()
