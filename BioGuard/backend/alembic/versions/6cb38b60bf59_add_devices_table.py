"""add devices table

Revision ID: 6cb38b60bf59
Revises: 69a1e994dfef
Create Date: 2026-09-05 01:33:50.585195

Like the baseline, this was first generated empty because the table was
created via create_all; it now creates the table so fresh databases get it.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '6cb38b60bf59'
down_revision: Union[str, Sequence[str], None] = '69a1e994dfef'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'devices',
        sa.Column('device_id', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=True),
        sa.Column('location', sa.String(), nullable=True),
        sa.Column('threshold_min', sa.Float(), nullable=False),
        sa.Column('threshold_max', sa.Float(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('device_id'),
    )
    op.create_index('ix_devices_device_id', 'devices', ['device_id'])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_devices_device_id', table_name='devices')
    op.drop_table('devices')
