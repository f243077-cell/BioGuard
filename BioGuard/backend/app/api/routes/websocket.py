"""
BioGuard Backend — WebSocket Route
Pushes new/resolved alerts to connected clients in real time.
"""

import asyncio
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.api.deps import get_db, resolve_user_from_flexible_token

router = APIRouter(tags=["websocket"])


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
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
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


@router.websocket("/ws/alerts")
async def alerts_websocket(websocket: WebSocket, db: Session = Depends(get_db)):
    try:
        resolve_user_from_flexible_token(
            websocket.query_params.get("token"),
            websocket.headers.get("authorization"),
            db,
        )
    except HTTPException:
        await websocket.accept()
        await websocket.close(code=4401, reason="Invalid or missing token")
        return

    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)