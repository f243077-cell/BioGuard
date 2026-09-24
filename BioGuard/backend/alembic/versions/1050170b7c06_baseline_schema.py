"""baseline schema

Revision ID: 1050170b7c06
Revises:
Create Date: 2026-08-28 08:02:52.638185

Creates the original readings / alerts / users tables. This revision was
first generated empty (the tables already existed via create_all), which
meant a fresh database could never be built from migrations alone.
Databases already stamped past this revision are unaffected.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '1050170b7c06'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'readings',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('device_id', sa.String(), nullable=False),
        sa.Column('reading_type', sa.String(), nullable=False),
        sa.Column('numeric_value', sa.Float(), nullable=True),
        sa.Column('status_value', sa.String(), nullable=True),
        sa.Column('anomalous', sa.Boolean(), nullable=False),
        sa.Column('timestamp', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_readings_id', 'readings', ['id'])
    op.create_index('ix_readings_device_id', 'readings', ['device_id'])
    op.create_index('ix_readings_timestamp', 'readings', ['timestamp'])

    # notes column is added by 69a1e994dfef.
    op.create_table(
        'alerts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('device_id', sa.String(), nullable=False),
        sa.Column('reading_id', sa.Integer(), nullable=True),
        sa.Column('alert_type', sa.String(), nullable=False),
        sa.Column('message', sa.String(), nullable=False),
        sa.Column('severity', sa.String(), nullable=False),
        sa.Column('resolved', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('resolved_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['reading_id'], ['readings.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_alerts_id', 'alerts', ['id'])
    op.create_index('ix_alerts_device_id', 'alerts', ['device_id'])
    op.create_index('ix_alerts_created_at', 'alerts', ['created_at'])

    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('username', sa.String(), nullable=False),
        sa.Column('hashed_password', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_users_id', 'users', ['id'])
    op.create_index('ix_users_username', 'users', ['username'], unique=True)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_users_username', table_name='users')
    op.drop_index('ix_users_id', table_name='users')
    op.drop_table('users')

    op.drop_index('ix_alerts_created_at', table_name='alerts')
    op.drop_index('ix_alerts_device_id', table_name='alerts')
    op.drop_index('ix_alerts_id', table_name='alerts')
    op.drop_table('alerts')

    op.drop_index('ix_readings_timestamp', table_name='readings')
    op.drop_index('ix_readings_device_id', table_name='readings')
    op.drop_index('ix_readings_id', table_name='readings')
    op.drop_table('readings')
