"""
BioGuard Backend — MQTT Subscriber Client
Connects to the broker and routes incoming messages to their handlers.
"""

import paho.mqtt.client as mqtt

from app.config import (
    MQTT_BROKER_HOST,
    MQTT_BROKER_PORT,
    MQTT_CLIENT_ID,
    MQTT_TOPIC_LOCK,
    MQTT_TOPIC_TEMPERATURE,
)
from app.mqtt.handlers import handle_lock_message, handle_temperature_message

_client = None


def _on_connect(client, userdata, flags, reason_code, properties=None):
    if reason_code == 0:
        print(f"[BioGuard Backend] Connected to broker at {MQTT_BROKER_HOST}:{MQTT_BROKER_PORT}")
        client.subscribe(MQTT_TOPIC_TEMPERATURE)
        client.subscribe(MQTT_TOPIC_LOCK)
    else:
        print(f"[BioGuard Backend] Connection failed, reason code: {reason_code}")


def _on_message(client, userdata, msg):
    if msg.topic.endswith("/temperature"):
        handle_temperature_message(msg.topic, msg.payload)
    elif msg.topic.endswith("/lock"):
        handle_lock_message(msg.topic, msg.payload)
    else:
        print(f"[BioGuard Backend] Unrecognized topic: {msg.topic}")


def start_mqtt_client():
    """Connect to the broker and start listening in a background thread."""
    global _client
    _client = mqtt.Client(
        client_id=MQTT_CLIENT_ID,
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
    )
    _client.on_connect = _on_connect
    _client.on_message = _on_message
    _client.connect(MQTT_BROKER_HOST, MQTT_BROKER_PORT)
    _client.loop_start()
    return _client


def stop_mqtt_client():
    """Disconnect the client, if running."""
    if _client is not None:
        _client.loop_stop()
        _client.disconnect()