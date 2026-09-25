"""
BioGuard — Seed Demo Devices
Gives the three demo devices used elsewhere in this project (device-001/
002/003 — matching docker-compose.yml's simulator-1/2/3, and the default
DEVICE_ID a standalone `python main.py` simulator run uses) a friendly
name and location, instead of the blank ones auto-registered on their
first reading.

Deliberately leaves thresholds untouched: every simulator instance only
ever generates readings in the 2-8°C range (TEMP_NORMAL_MIN_C/MAX_C in
simulator/config.py), so giving a seeded device a different safe range
here — e.g. a freezer's -15 to -25°C — would make it show as anomalous
forever, since nothing would ever actually publish a reading inside that
range. A device only gets a different range once its simulator does too.

Run against whichever DATABASE_URL is active — defaults to the same
backend/bioguard.db a locally-run `uvicorn app.main:app` uses:

    cd BioGuard
    python scripts/seed_devices.py

Safe to run before the backend has ever started (it runs migrations
first) and safe to re-run any time — it only ever sets name/location.

NOTE: the /devices API doesn't return name/location yet — it lists
devices from their readings, not the devices table — so this currently
only affects direct database/report access, not the running app.
"""

import sys
from pathlib import Path

# Reuse the backend's own config/models, the same way alembic/env.py does,
# so this always targets whatever DATABASE_URL the backend itself would use.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.config import TEMP_ALERT_MAX_C, TEMP_ALERT_MIN_C  # noqa: E402
from app.db.session import SessionLocal, init_db  # noqa: E402
from app.models.device import Device  # noqa: E402

DEMO_DEVICES = [
    {
        "device_id": "device-001",
        "name": "Vaccine Fridge — Ward A",
        "location": "Ward A, Level 2",
    },
    {
        "device_id": "device-002",
        "name": "Insulin Fridge — Pharmacy",
        "location": "Pharmacy Store Room",
    },
    {
        "device_id": "device-003",
        "name": "Biologics Fridge — Lab",
        "location": "Pathology Lab",
    },
]


def main() -> None:
    init_db()
    db = SessionLocal()
    try:
        for entry in DEMO_DEVICES:
            device = db.query(Device).filter(Device.device_id == entry["device_id"]).first()
            if device is None:
                device = Device(
                    device_id=entry["device_id"],
                    threshold_min=TEMP_ALERT_MIN_C,
                    threshold_max=TEMP_ALERT_MAX_C,
                )
                db.add(device)
                action = "created"
            else:
                action = "updated"

            device.name = entry["name"]
            device.location = entry["location"]
            db.commit()
            print(f"[seed_devices] {action}: {entry['device_id']} — {entry['name']} ({entry['location']})")
    finally:
        db.close()


if __name__ == "__main__":
    main()
