Product Requirements Document (PRD)
BioGuard — Cold-Chain Medicine Safety & Compliance System
Version: 1.0 Author: Tanzeel Status: Draft

1. Overview
   BioGuard is an IoT-based monitoring and compliance system that protects temperature-sensitive medical supplies (insulin, vaccines, IVF eggs, oncology drugs) from spoilage, theft, and regulatory non-compliance. It combines a simulated smart storage safe, a real-time backend, and a Flutter clinical dashboard into a single end-to-end system.
2. Problem Statement
   Clinics and hospitals storing temperature-sensitive medicine face three recurring failures:
3. Cold-chain spoilage — Fridges lose power or doors are left open, and nobody notices until the medicine has already spoiled, causing financial loss and patient risk.
4. Manual, error-prone compliance logging — Staff log fridge temperatures on paper, which is often forgotten, incomplete, or falsified, making regulatory audits difficult.
5. Theft of high-value medication — Narcotics and biologics are theft targets, and unusual access (e.g. after-hours openings) often goes undetected.
6. Goals
   • Detect temperature excursions and lock-status anomalies in near real time
   • Alert clinical staff immediately when a threshold is breached
   • Maintain an automatic, auditable log of all readings and events
   • Generate on-demand compliance reports for regulators
   • Demonstrate a complete IoT-to-mobile data pipeline (sensor simulation → messaging → backend → app)
7. Non-Goals
   • Building or sourcing physical hardware (sensors are simulated in software for this version)
   • Multi-tenant SaaS billing or clinic onboarding flows
   • Legal certification as an actual regulatory compliance tool
8. Target Users
   • Clinic nurses/staff — log-free, passive monitoring of storage conditions
   • Doctors/clinicians — real-time alerts on their phone for spoilage or security events
   • Compliance officers/inspectors — one-tap access to historical, tamper-evident audit reports
9. System Architecture
   CLINIC SAFE BROKER & BACKEND CLINICIAN INTERFACE
   ───────────── ───────────────── ───────────────────
   Python Script Mosquitto Broker Flutter App
   [Temp Sensor Sim] ──MQTT──► (pub/sub message relay) (live dials + alerts)
   [Lock Sensor Sim] │
   ▼
   FastAPI Backend + Database
   │
   ├── REST API ──► historical data, PDF reports
   └── WebSocket ──► real-time push to app

6.1 Components
Component Technology Responsibility
Sensor Simulator Python + paho-mqtt Generates fake temperature/lock readings on an interval, publishes to MQTT
Message Broker Mosquitto (MQTT) Relays messages between simulator and backend; no logic
Backend FastAPI + paho-mqtt client + DB (PostgreSQL/SQLite) Subscribes to MQTT, persists readings, evaluates thresholds, serves REST/WebSocket APIs, generates PDF reports
Frontend Flutter Live dashboard, real-time alerts, alarm sounds, PDF report access
Notifications Firebase Cloud Messaging Background push alerts when app is not in foreground

7. End-to-End Workflow
1. Data Generation — Python script generates a simulated reading (temperature, lock status, timestamp, device ID) every 5–10 seconds, occasionally injecting anomalies (spikes, unexpected unlocks) for demo purposes.
1. Publish — Script publishes the reading as JSON to an MQTT topic (e.g. clinic/safe_01/telemetry) via the Mosquitto broker.
1. Subscribe & Ingest — FastAPI's background MQTT client, subscribed on startup, receives each message and:
   • Writes it to the database
   • Evaluates it against thresholds (e.g. temp outside 2–8°C, lock opened outside allowed hours)
   • If violated, creates an alert record
1. Real-Time Delivery — On each new reading or alert, FastAPI pushes the update to connected clients via a WebSocket endpoint (/ws/alerts), so the Flutter dashboard updates without polling.
1. Alerting — On threshold violation:
   • If the app is in the foreground: instant WebSocket-driven in-app alarm (sound + red banner)
   • If backgrounded: FCM push notification triggers a local notification and alarm sound
1. Historical Access — Flutter app calls REST endpoints (/devices/{id}/history) to show trend charts and past events.
1. Compliance Reporting — On demand, Flutter calls /reports/pdf?device_id=&range=; FastAPI queries historical data and generates a PDF (via reportlab or weasyprint) documenting readings and any violations for that period; Flutter displays/downloads/shares it.
1. Functional Requirements
   ID Requirement
   FR1 System shall simulate temperature and lock-status readings at a configurable interval
   FR2 System shall transmit readings via MQTT publish/subscribe
   FR3 Backend shall persist every reading with device ID and timestamp
   FR4 Backend shall evaluate each reading against configurable thresholds
   FR5 Backend shall create an alert record when a threshold is violated
   FR6 Backend shall push real-time updates to connected clients via WebSocket
   FR7 Backend shall send push notifications via FCM when the app is backgrounded
   FR8 Flutter app shall display live temperature and lock status per device
   FR9 Flutter app shall trigger an audible alarm on receiving a critical alert
   FR10 Flutter app shall display historical trends (temperature over time)
   FR11 Backend shall generate a PDF report of readings/violations for a given device and date range
   FR12 Flutter app shall allow viewing/downloading/sharing the generated PDF report

1. Non-Functional Requirements
   • Latency: Alerts should reach the app within a few seconds of a threshold violation (near real-time, not literal milliseconds)
   • Reliability: MQTT broker and backend should handle reconnects gracefully if the simulator or app disconnects
   • Auditability: Logged readings should be immutable/append-only at the database level to support the "tamper-evident" claim
   • Scalability (stretch): Design should support multiple devices per clinic via topic wildcards (clinic/+/telemetry)
1. Data Model (Draft)
   Reading
   • id, device_id, temperature, lock_status, timestamp
   Alert
   • id, device_id, type (temp_excursion / unusual_unlock), reading_id (FK), created_at, resolved (bool)
   Device
   • id, name, location, threshold_min, threshold_max
1. Milestones / Phased Build Plan
   Phase Scope
   Phase 1 Python simulator + MQTT broker + FastAPI subscriber storing readings in DB
   Phase 2 REST APIs + Flutter dashboard showing live/historical data (polling)
   Phase 3 WebSocket real-time push replacing polling; threshold-based alerts
   Phase 4 FCM push notifications + in-app alarm sound
   Phase 5 PDF compliance report generation and in-app access
   Phase 6 (stretch) Multi-device support, authentication/user roles, anomaly detection refinement

1. Risks / Open Questions
   • "Tamper-proof" claim needs a concrete mechanism (e.g. append-only writes, hash-chained records) to hold up under scrutiny — otherwise should be softened to "tamper-evident" or "auto-logged"
   • Need to decide DB choice (SQLite for demo simplicity vs PostgreSQL for realism)
   • Need to decide authentication approach for the Flutter app (single clinic vs multi-user roles)
   • Real hardware integration is out of scope for v1 — should be clearly stated as "simulated" in any presentation/interview context
