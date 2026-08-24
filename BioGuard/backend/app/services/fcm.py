"""
BioGuard Backend — FCM Push Service
Sends push notifications for alerts via Firebase Cloud Messaging.
Requires a Firebase service account JSON — see FIREBASE_CREDENTIALS_PATH.
"""

import os

import firebase_admin
from firebase_admin import credentials, messaging

_FCM_TOPIC = "bioguard_alerts"
_initialized = False


def _ensure_initialized() -> bool:
    """Lazily initialize the Firebase Admin app. Returns False if not configured."""
    global _initialized
    if _initialized:
        return True

    cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
    if not cred_path or not os.path.exists(cred_path):
        print("[BioGuard Backend] FCM disabled: FIREBASE_CREDENTIALS_PATH not set or file missing.")
        return False

    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
    _initialized = True
    return True


def send_alert_push(*, device_id: str, message: str, severity: str) -> None:
    """Publish a push notification to the shared alerts topic. No-op if FCM isn't configured."""
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