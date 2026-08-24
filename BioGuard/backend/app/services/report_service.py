"""
BioGuard Backend — PDF Report Service
Generates a PDF summary report for a device: recent readings and alerts.
"""

import io
from datetime import datetime, timezone

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
from sqlalchemy.orm import Session

from app.models.alert import Alert
from app.models.reading import Reading


def generate_device_report(
    db: Session, device_id: str, *, reading_limit: int = 50, alert_limit: int = 20
) -> bytes:
    """Build a PDF report for a device and return the raw PDF bytes."""
    readings = (
        db.query(Reading)
        .filter(Reading.device_id == device_id)
        .order_by(Reading.timestamp.desc())
        .limit(reading_limit)
        .all()
    )
    alerts = (
        db.query(Alert)
        .filter(Alert.device_id == device_id)
        .order_by(Alert.created_at.desc())
        .limit(alert_limit)
        .all()
    )

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, topMargin=2 * cm, bottomMargin=2 * cm)
    styles = getSampleStyleSheet()
    elements = []

    elements.append(Paragraph(f"BioGuard Report — {device_id}", styles["Title"]))
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    elements.append(Paragraph(f"Generated {generated_at}", styles["Normal"]))
    elements.append(Spacer(1, 0.5 * cm))

    open_alerts = sum(1 for a in alerts if not a.resolved)
    summary = (
        f"Readings shown: {len(readings)} &nbsp;&nbsp; "
        f"Alerts shown: {len(alerts)} &nbsp;&nbsp; "
        f"Currently open: {open_alerts}"
    )
    elements.append(Paragraph(summary, styles["Normal"]))
    elements.append(Spacer(1, 0.7 * cm))

    elements.append(Paragraph("Recent Readings", styles["Heading2"]))
    reading_data = [["Type", "Value", "Anomalous", "Timestamp"]]
    for r in readings:
        value = r.numeric_value if r.numeric_value is not None else r.status_value
        reading_data.append(
            [
                r.reading_type,
                str(value),
                "Yes" if r.anomalous else "No",
                r.timestamp.strftime("%Y-%m-%d %H:%M:%S") if r.timestamp else "",
            ]
        )
    reading_table = Table(reading_data, hAlign="LEFT", colWidths=[3 * cm, 3 * cm, 3 * cm, 5 * cm])
    reading_table.setStyle(_table_style())
    elements.append(reading_table)
    elements.append(Spacer(1, 0.7 * cm))

    elements.append(Paragraph("Recent Alerts", styles["Heading2"]))
    cell_style = styles["Normal"].clone("cell")
    cell_style.fontSize = 8
    cell_style.leading = 10

    alert_data = [["Type", "Severity", "Message", "Resolved", "Created"]]
    for a in alerts:
        alert_data.append(
            [
                Paragraph(a.alert_type, cell_style),
                a.severity,
                Paragraph(a.message, cell_style),
                "Yes" if a.resolved else "No",
                a.created_at.strftime("%Y-%m-%d %H:%M:%S") if a.created_at else "",
            ]
        )
    alert_table = Table(alert_data, hAlign="LEFT", colWidths=[3 * cm, 2 * cm, 6 * cm, 2 * cm, 3 * cm])
    alert_table.setStyle(_table_style())
    elements.append(alert_table)

    doc.build(elements)
    return buffer.getvalue()


def _table_style() -> TableStyle:
    return TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2575FC")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTSIZE", (0, 0), (-1, -1), 8),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F0F0F0")]),
        ]
    )