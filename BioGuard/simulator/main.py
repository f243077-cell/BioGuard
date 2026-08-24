"""
BioGuard Simulator — Entry Point
Generates temperature + lock readings on an interval and publishes them to MQTT.
"""

import json
import time
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

from config import (
    DEVICE_ID,
    MQTT_BROKER_HOST,
    MQTT_BROKER_PORT,
    MQTT_CLIENT_ID,
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


def run():
    client = mqtt.Client(
        client_id=MQTT_CLIENT_ID,
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
    )
    client.on_connect = on_connect
    client.connect(MQTT_BROKER_HOST, MQTT_BROKER_PORT)
    client.loop_start()

    print(f"[BioGuard Simulator] Publishing every {PUBLISH_INTERVAL_SECONDS}s for {DEVICE_ID}. Ctrl+C to stop.")

    try:
        while True:
            temp = generate_temperature()
            lock_status = generate_lock_status()

            client.publish(TOPIC_TEMPERATURE, build_payload(temp, is_temperature_anomalous(temp)))
            client.publish(TOPIC_LOCK, build_payload(lock_status))

            print(f"[{datetime.now(timezone.utc).isoformat()}] temp={temp}°C lock={lock_status}")

            time.sleep(PUBLISH_INTERVAL_SECONDS)
    except KeyboardInterrupt:
        print("\n[BioGuard Simulator] Stopped.")
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    run()