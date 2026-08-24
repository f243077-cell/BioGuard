"""
BioGuard Simulator — Configuration
Central place for MQTT connection, publish interval, and anomaly settings.
"""

import os

# MQTT broker connection
MQTT_BROKER_HOST = os.getenv("MQTT_BROKER_HOST", "localhost")
MQTT_BROKER_PORT = int(os.getenv("MQTT_BROKER_PORT", 1883))
MQTT_CLIENT_ID = os.getenv("MQTT_CLIENT_ID", "bioguard-simulator")

# Device identity
DEVICE_ID = os.getenv("DEVICE_ID", "device-001")

# MQTT topics (per device)
TOPIC_TEMPERATURE = f"bioguard/{DEVICE_ID}/temperature"
TOPIC_LOCK = f"bioguard/{DEVICE_ID}/lock"

# Publish interval (seconds)
PUBLISH_INTERVAL_SECONDS = int(os.getenv("PUBLISH_INTERVAL_SECONDS", 5))

# Normal operating ranges
TEMP_NORMAL_MIN_C = 2.0
TEMP_NORMAL_MAX_C = 8.0   # e.g. vaccine / biological sample storage range

# Anomaly injection
ANOMALY_INJECTION_ENABLED = True
ANOMALY_PROBABILITY = 0.08          # 8% chance an anomaly episode starts on a given reading
TEMP_ANOMALY_MIN_C = -5.0
TEMP_ANOMALY_MAX_C = 15.0
LOCK_ANOMALY_PROBABILITY = 0.03     # 3% chance a lock-open episode starts

# Anomaly episode behavior — anomalies drift in/out over several readings
# instead of teleporting to a random value on a single reading.
ANOMALY_EPISODE_MIN_READINGS = 3
ANOMALY_EPISODE_MAX_READINGS = 8
TEMP_DRIFT_STEP_C = 1.5             # max change per reading while drifting toward a target
TEMP_NOISE_STD_C = 0.15             # small random jitter applied every reading