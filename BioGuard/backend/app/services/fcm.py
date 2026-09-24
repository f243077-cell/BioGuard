"""
BioGuard Backend — FCM Push Service
Sends push notifications for alerts via Firebase Cloud Messaging.
Requires a Firebase service account JSON — see FIREBASE_CREDENTIALS_PATH.
"""

import os
import threading
from concurrent.futures import ThreadPoolExecutor
from typing import Optional

import firebase_admin
from firebase_admin import credentials, messaging

from app.config import FIREBASE_CREDENTIALS_PATH

_FCM_TOPIC = "bioguard_alerts"

# Pushes are sent off the MQTT thread: a slow or unreachable Firebase must
# never stall reading ingestion or delay the WebSocket alert broadcast.
_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="bioguard-fcm")
_init_lock = threading.Lock()
_enabled: Optional[bool] = None  # None until the first push attempt


def _ensure_initialized() -> bool:
    """Lazily initialize the Firebase Admin app once. Returns False (and
    logs why, once) if FCM isn't configured or the credentials are unusable."""
    global _enabled
    with _init_lock:
        if _enabled is not None:
            return _enabled

        cred_path = FIREBASE_CREDENTIALS_PATH
        if not cred_path or not os.path.exists(cred_path):
            print("[BioGuard Backend] FCM disabled: FIREBASE_CREDENTIALS_PATH not set or file missing.")
            _enabled = False
            return False

        try:
            firebase_admin.initialize_app(credentials.Certificate(cred_path))
        except Exception as exc:
            print(f"[BioGuard Backend] FCM disabled: could not load credentials ({exc}).")
            _enabled = False
            return False

        _enabled = True
        return True


def send_alert_push(*, device_id: str, message: str, severity: str) -> None:
    """Queue a push notification to the shared alerts topic and return
    immediately. No-op if FCM isn't configured."""
    _executor.submit(_send, device_id, message, severity)


def _send(device_id: str, message: str, severity: str) -> None:
    if not _ensure_initialized():
        return

    notification = messaging.Notification(
        title=f"BioGuard — {device_id}",
        body=message,
    )
    data = {"device_id": device_id, "severity": severity}
    msg = messaging.Message(notification=notification, data=data, topic=_FCM_TOPIC)

    try:
        response = messaging.send(msg)
        print(f"[BioGuard Backend] FCM push sent: {response}")
    except Exception as exc:
        print(f"[BioGuard Backend] FCM push failed: {exc}")
