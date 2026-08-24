"""
BioGuard Backend — Configuration
Central settings: database URL, MQTT broker connection, and alert thresholds.
"""

import os

# Database
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./bioguard.db")

# MQTT broker connection (same broker the simulator publishes to)
MQTT_BROKER_HOST = os.getenv("MQTT_BROKER_HOST", "localhost")
MQTT_BROKER_PORT = int(os.getenv("MQTT_BROKER_PORT", 1883))
MQTT_CLIENT_ID = os.getenv("MQTT_CLIENT_ID", "bioguard-backend")

# Wildcard subscriptions — matches any device publishing under bioguard/<device_id>/...
MQTT_TOPIC_TEMPERATURE = "bioguard/+/temperature"
MQTT_TOPIC_LOCK = "bioguard/+/lock"

# Alert thresholds (used from Phase 3 onward)
TEMP_ALERT_MIN_C = 2.0
TEMP_ALERT_MAX_C = 8.0

# Firebase Cloud Messaging (used from Phase 4 onward)
FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY", "")

# Auth / JWT (used from Phase 6 onward)
# IMPORTANT: the default below is for local dev only — set a real
# JWT_SECRET_KEY env var before deploying anywhere it matters.
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dev-secret-change-me-before-deploying-anywhere-real")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", 60 * 24))  # 24 hours