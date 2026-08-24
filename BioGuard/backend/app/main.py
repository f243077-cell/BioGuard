"""
BioGuard Backend — FastAPI Entry Point
Starts the MQTT subscriber alongside the API and initializes the database.
"""

import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes.auth import router as auth_router
from app.api.routes.devices import router as devices_router
from app.api.routes.reports import router as reports_router
from app.api.routes.websocket import router as websocket_router
from app.api.routes.websocket import set_event_loop
from app.db.session import init_db
from app.mqtt.client import start_mqtt_client, stop_mqtt_client


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    set_event_loop(asyncio.get_running_loop())
    start_mqtt_client()
    print("[BioGuard Backend] Startup complete — DB ready, MQTT subscriber running.")
    yield
    stop_mqtt_client()
    print("[BioGuard Backend] Shutdown complete.")


app = FastAPI(title="BioGuard Backend", lifespan=lifespan)
app.include_router(auth_router)
app.include_router(devices_router)
app.include_router(websocket_router)
app.include_router(reports_router)


@app.get("/")
def health_check():
    return {"status": "ok", "service": "BioGuard Backend"}