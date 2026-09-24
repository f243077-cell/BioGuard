"""
BioGuard Simulator — Entry Point
Generates temperature + lock readings on an interval and publishes them to MQTT.
"""

import json
import signal
import time
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

from config import (
    DEVICE_ID,
    MQTT_BROKER_HOST,
    MQTT_BROKER_PORT,
    MQTT_CLIENT_ID,
    MQTT_MAX_QUEUED,
    MQTT_QOS,
    PUBLISH_INTERVAL_SECONDS,
    TOPIC_LOCK,
    TOPIC_TEMPERATURE,
)
from utils.anomaly import generate_lock_status, generate_temperature, is_temperature_anomalous


def build_payload(value, anomalous: bool = None) -> str:
    payload = {
        "device_id": DEVICE_ID,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "value": value,
    }
    if anomalous is not None:
        payload["anomalous"] = anomalous
    return json.dumps(payload)


def on_connect(client, userdata, flags, reason_code, properties=None):
    if reason_code == 0:
        print(f"[BioGuard Simulator] Connected to broker at {MQTT_BROKER_HOST}:{MQTT_BROKER_PORT}")
    else:
        print(f"[BioGuard Simulator] Connection failed, reason code: {reason_code}")


def on_disconnect(client, userdata, flags, reason_code, properties=None):
    if reason_code != 0:
        print(f"[BioGuard Simulator] Lost broker connection ({reason_code}); buffering readings and reconnecting…")


def publish(client, topic: str, payload: str) -> None:
    info = client.publish(topic, payload, qos=MQTT_QOS)
    # NO_CONN is expected while reconnecting: QoS 1 messages stay queued and
    # are sent once the connection is back.
    if info.rc not in (mqtt.MQTT_ERR_SUCCESS, mqtt.MQTT_ERR_NO_CONN):
        print(f"[BioGuard Simulator] Dropped reading on {topic}: {mqtt.error_string(info.rc)}")


def _stop_on_sigterm(signum, frame):
    # `docker stop` sends SIGTERM — shut down the same way as Ctrl+C.
    raise KeyboardInterrupt


def run():
    signal.signal(signal.SIGTERM, _stop_on_sigterm)

    client = mqtt.Client(
        client_id=MQTT_CLIENT_ID,
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
    )
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.reconnect_delay_set(min_delay=1, max_delay=30)
    client.max_queued_messages_set(MQTT_MAX_QUEUED)
    # connect_async + loop_start retries the first connection too, so the
    # simulator can start before the broker is up instead of crashing.
    client.connect_async(MQTT_BROKER_HOST, MQTT_BROKER_PORT, keepalive=30)
    client.loop_start()

    print(f"[BioGuard Simulator] Publishing every {PUBLISH_INTERVAL_SECONDS}s for {DEVICE_ID}. Ctrl+C to stop.")

    try:
        while True:
            temp = generate_temperature()
            lock_status = generate_lock_status()

            publish(client, TOPIC_TEMPERATURE, build_payload(temp, is_temperature_anomalous(temp)))
            publish(client, TOPIC_LOCK, build_payload(lock_status))

            print(f"[{datetime.now(timezone.utc).isoformat()}] temp={temp}°C lock={lock_status}")

            time.sleep(PUBLISH_INTERVAL_SECONDS)
    except KeyboardInterrupt:
        print("\n[BioGuard Simulator] Stopped.")
    finally:
        client.disconnect()
        client.loop_stop()


if __name__ == "__main__":
    run()
