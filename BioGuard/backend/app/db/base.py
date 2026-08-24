"""
BioGuard Backend — SQLAlchemy Declarative Base
All models inherit from this Base so metadata is shared for table creation/migrations.
"""

from sqlalchemy.orm import declarative_base

Base = declarative_base()