import json

import pytest
from starlette.websockets import WebSocketDisconnect

from app.models.alert import Alert
from app.mqtt.handlers import handle_lock_message, handle_temperature_message


@pytest.mark.parametrize(
    "username, password",
    [("ab", "secret123"), ("nurse", "123"), ("nurse", "x" * 73), ("nurse", "é" * 40)],
)
def test_register_rejects_invalid_input_with_readable_message(client, username, password):
    response = client.post("/auth/register", json={"username": username, "password": password})
    assert response.status_code == 400
    assert isinstance(response.json()["detail"], str)


def test_register_duplicate_username(client):
    body = {"username": "nurse", "password": "secret123"}
    assert client.post("/auth/register", json=body).status_code == 201
    assert client.post("/auth/register", json=body).status_code == 400


def test_login_with_overlong_password_is_401_not_500(client):
    client.post("/auth/register", json={"username": "nurse", "password": "secret123"})
    response = client.post("/auth/login", json={"username": "nurse", "password": "x" * 200})
    assert response.status_code == 401


def test_api_timestamps_carry_utc_offset(client, auth_headers):
    handle_temperature_message("bioguard/fridge-1/temperature", b'{"value": 20.0}')

    device = client.get("/devices", headers=auth_headers).json()[0]
    assert device["temperature"]["timestamp"].endswith(("Z", "+00:00"))

    alert = client.get("/alerts", headers=auth_headers).json()[0]
    assert alert["created_at"].endswith(("Z", "+00:00"))


@pytest.mark.parametrize("path", ["/alerts?limit=0", "/alerts?limit=-1", "/devices/fridge-1/history?limit=-1"])
def test_non_positive_limits_are_rejected(client, auth_headers, path):
    assert client.get(path, headers=auth_headers).status_code == 422


def test_report_survives_markup_characters(client, auth_headers, db):
    handle_lock_message("bioguard/fridge-1/lock", b'{"value": "unlocked"}')
    alert = db.query(Alert).one()
    alert.message = "Door <b>open & unlocked"
    db.commit()

    response = client.get("/reports/pdf/fridge-1", headers=auth_headers)
    assert response.status_code == 200
    assert response.content.startswith(b"%PDF")


def test_report_filename_is_sanitized(client, auth_headers):
    response = client.get('/reports/pdf/we"irdéid', headers=auth_headers)
    assert response.status_code == 200
    assert response.headers["content-disposition"] == 'inline; filename="bioguard_we_ird_id_report.pdf"'


def test_websocket_rejects_bad_token(client):
    with client.websocket_connect("/ws/alerts?token=nope") as ws:
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_text()
    assert exc.value.code == 4401


def test_websocket_tolerates_binary_frames(client, auth_headers):
    token = auth_headers["Authorization"].split()[1]
    with client.websocket_connect(f"/ws/alerts?token={token}") as ws:
        ws.send_bytes(b"\x00\x01")
        ws.send_text(json.dumps({"ping": True}))
    # Reaching here without the server erroring is the assertion.
