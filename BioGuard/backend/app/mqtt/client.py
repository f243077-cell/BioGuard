"""
BioGuard Backend — MQTT Subscriber Client
Connects to the broker and routes incoming messages to their handlers.

Uses a persistent session (clean_session=False) with QoS 1 subscriptions,
so the broker queues readings published while the backend is restarting
and delivers them on reconnect instead of dropping them.
"""

import traceback

import paho.mqtt.client as mqtt

from app.config import (
    MQTT_BROKER_HOST,
    MQTT_BROKER_PORT,
    MQTT_CLIENT_ID,
    MQTT_TOPIC_LOCK,
    MQTT_TOPIC_TEMPERATURE,
)
from app.mqtt.handlers import handle_lock_message, handle_temperature_message

_QOS = 1

_client = None


def _on_connect(client, userdata, flags, reason_code, properties=None):
    if reason_code == 0:
        print(f"[BioGuard Backend] Connected to broker at {MQTT_BROKER_HOST}:{MQTT_BROKER_PORT}")
        client.subscribe([(MQTT_TOPIC_TEMPERATURE, _QOS), (MQTT_TOPIC_LOCK, _QOS)])
    else:
        print(f"[BioGuard Backend] Connection failed, reason code: {reason_code}")


def _on_disconnect(client, userdata, flags, reason_code, properties=None):
    if reason_code != 0:
        print(f"[BioGuard Backend] Lost broker connection ({reason_code}); reconnecting…")


def _on_message(client, userdata, msg):
    # paho re-raises callback exceptions, which kills the network thread and
    # silently stops all ingestion — never let one message do that.
    try:
        if msg.topic.endswith("/temperature"):
            handle_temperature_message(msg.topic, msg.payload)
        elif msg.topic.endswith("/lock"):
            handle_lock_message(msg.topic, msg.payload)
        else:
            print(f"[BioGuard Backend] Unrecognized topic: {msg.topic}")
    except Exception:
        print(f"[BioGuard Backend] Error handling message on {msg.topic}:")
        traceback.print_exc()


def start_mqtt_client():
    """Start connecting to the broker in a background thread.

    Doesn't block or raise if the broker is down: the network thread keeps
    retrying (including the first connection) with backoff, so the API can
    start and serve history while the broker comes up.
    """
    global _client
    _client = mqtt.Client(
        client_id=MQTT_CLIENT_ID,
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
        clean_session=False,
    )
    _client.on_connect = _on_connect
    _client.on_disconnect = _on_disconnect
    _client.on_message = _on_message
    _client.reconnect_delay_set(min_delay=1, max_delay=30)
    _client.connect_async(MQTT_BROKER_HOST, MQTT_BROKER_PORT, keepalive=30)
    _client.loop_start()
    return _client


def stop_mqtt_client():
    """Disconnect the client, if running."""
    if _client is not None:
        _client.disconnect()
        _client.loop_stop()
