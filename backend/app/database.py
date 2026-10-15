"""Engine, sesión y Base declarativa de SQLAlchemy 2.0."""

from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import get_settings

settings = get_settings()

engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,
    future=True,
)

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
    class_=Session,
)


class Base(DeclarativeBase):
    """Base declarativa de todos los modelos."""


def get_db() -> Iterator[Session]:
    """Dependencia de FastAPI: una sesión por request, siempre cerrada al salir."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
