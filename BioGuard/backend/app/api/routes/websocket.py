"""
BioGuard Backend — WebSocket Route
Pushes new/escalated/resolved alerts to connected clients in real time.
"""

import asyncio
from typing import List, Optional

from fastapi import APIRouter, HTTPException, WebSocket
from starlette.concurrency import run_in_threadpool

from app.api.deps import resolve_user_from_flexible_token
from app.db.session import SessionLocal

router = APIRouter(tags=["websocket"])

# A client that stops reading must not stall the broadcast for everyone else.
_SEND_TIMEOUT_SECONDS = 5


class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        stale = []
        # Iterate over a snapshot: clients can connect/disconnect while a
        # send is awaiting.
        for connection in list(self.active_connections):
            try:
                await asyncio.wait_for(connection.send_json(message), _SEND_TIMEOUT_SECONDS)
            except Exception:
                stale.append(connection)
        for conn in stale:
            self.disconnect(conn)


manager = ConnectionManager()
_loop: Optional[asyncio.AbstractEventLoop] = None


def set_event_loop(loop: asyncio.AbstractEventLoop) -> None:
    """Called once at startup so sync code (the MQTT thread) can schedule broadcasts."""
    global _loop
    _loop = loop


def broadcast_alert_sync(alert_dict: dict) -> None:
    """Call from synchronous code (e.g. the MQTT callback thread) to push an alert."""
    if _loop is not None:
        asyncio.run_coroutine_threadsafe(manager.broadcast(alert_dict), _loop)


def _authenticate(token: Optional[str], authorization_header: Optional[str]) -> None:
    # Short-lived session: holding one open for the life of the socket would
    # pin a pooled DB connection per connected client.
    db = SessionLocal()
    try:
        resolve_user_from_flexible_token(token, authorization_header, db)
    finally:
        db.close()


@router.websocket("/ws/alerts")
async def alerts_websocket(websocket: WebSocket):
    try:
        await run_in_threadpool(
            _authenticate,
            websocket.query_params.get("token"),
            websocket.headers.get("authorization"),
        )
    except HTTPException:
        await websocket.accept()
        await websocket.close(code=4401, reason="Invalid or missing token")
        return

    await manager.connect(websocket)
    try:
        # Push-only channel: drain anything the client sends (text or
        # binary) until it disconnects.
        while True:
            message = await websocket.receive()
            if message["type"] == "websocket.disconnect":
                break
    finally:
        manager.disconnect(websocket)
