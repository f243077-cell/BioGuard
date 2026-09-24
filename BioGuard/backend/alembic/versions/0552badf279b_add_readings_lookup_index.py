"""add readings lookup index

Revision ID: 0552badf279b
Revises: 6cb38b60bf59
Create Date: 2026-09-24 12:00:00.000000

The dashboard polls /devices every few seconds, which looks up the latest
reading per (device, type), and /devices/{id}/history filters the same
way. Without a composite index those queries scan every reading for the
device, and the table grows by tens of thousands of rows per device per day.
"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = '0552badf279b'
down_revision: Union[str, Sequence[str], None] = '6cb38b60bf59'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_index(
        'ix_readings_device_type_timestamp',
        'readings',
        ['device_id', 'reading_type', 'timestamp'],
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_readings_device_type_timestamp', table_name='readings')
