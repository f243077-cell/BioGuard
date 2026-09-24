"""
Test setup: point the app at a throwaway SQLite file and an unused broker
before anything imports app.config, so tests never touch a real database
or knock a running backend off the broker by reusing its client id.
"""

import os
import sys
import tempfile
from pathlib import Path

import pytest

_TMP_DIR = Path(tempfile.mkdtemp(prefix="bioguard-tests-"))
os.environ["DATABASE_URL"] = f"sqlite:///{(_TMP_DIR / 'test.db').as_posix()}"
os.environ["MQTT_BROKER_PORT"] = "1"
os.environ["MQTT_CLIENT_ID"] = "bioguard-backend-tests"
os.environ["FIREBASE_CREDENTIALS_PATH"] = ""

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db.session import SessionLocal, init_db  # noqa: E402
from app.models.alert import Alert  # noqa: E402
from app.models.device import Device  # noqa: E402
from app.models.reading import Reading  # noqa: E402
from app.models.user import User  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def _schema():
    # Builds the schema through the real migrations, so every test run also
    # proves a fresh database can be created from scratch.
    init_db()


@pytest.fixture(autouse=True)
def _clean_tables():
    yield
    db = SessionLocal()
    try:
        for model in (Alert, Reading, Device, User):
            db.query(model).delete()
        db.commit()
    finally:
        db.close()


@pytest.fixture
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client():
    from fastapi.testclient import TestClient

    from app.main import app

    # No `with` block: skips the lifespan, so no MQTT client is started.
    return TestClient(app)


@pytest.fixture
def auth_headers(client):
    client.post("/auth/register", json={"username": "nurse", "password": "secret123"})
    token = client.post("/auth/login", json={"username": "nurse", "password": "secret123"}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
