"""
BioGuard Backend — Report Routes
Generates and serves a PDF summary report for a device.
"""

import re

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_flexible, get_db
from app.models.user import User
from app.services.report_service import generate_device_report

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/pdf/{device_id}")
def get_device_report(
    device_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_flexible),
):
    try:
        pdf_bytes = generate_device_report(db, device_id)
    except Exception as exc:
        print(f"[BioGuard Backend] Report generation failed for {device_id}: {exc}")
        pdf_bytes = None
    if not pdf_bytes:
        raise HTTPException(status_code=500, detail="Failed to generate report")

    # Headers must be latin-1 and must not contain quotes, so the raw id
    # can't go into the filename.
    safe_id = re.sub(r"[^A-Za-z0-9._-]", "_", device_id)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="bioguard_{safe_id}_report.pdf"'},
    )