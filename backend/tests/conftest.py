"""Fixtures de la suite: app de test, base de test, cliente y usuario autenticado.

La base apunta por defecto al Postgres de prueba (contenedor tp-pg-test en el puerto 55432).
"""

import os
from datetime import datetime, timedelta

os.environ.setdefault("DATABASE_URL", "postgresql+psycopg2://test:test@localhost:55432/club_test")
os.environ.setdefault("JWT_SECRET_KEY", "clave-de-test-suficientemente-larga-para-hs256")
os.environ.setdefault("DEBUG", "false")
os.environ.setdefault("AUTH_PROVIDER", "local")
os.environ.setdefault("AUTO_CREATE_TABLES", "true")
os.environ.setdefault("SEED_ON_STARTUP", "false")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import select  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.database import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models import SportSpace, Venue  # noqa: E402
from app.seed import DEMO_EMAIL, DEMO_PASSWORD, seed_demo_data  # noqa: E402


def _assert_dedicated_test_database() -> None:
    """Aborta si la base apuntada por DATABASE_URL no es exclusiva de pruebas.

    La suite hace `drop_all`/`create_all` y borra filas en cada test: si se corre contra una base
    compartida (o de producción) se lleva puesta la de otro proceso. Exigimos que el nombre de la
    base contenga 'test' o 'verify' para que sea evidente que es una base descartable.
    """
    name = (engine.url.database or "").lower()
    if "test" not in name and "verify" not in name:
        pytest.exit(
            f"La suite corre contra la base '{engine.url.database}', que no parece exclusiva de "
            "pruebas. pytest hace drop_all/create_all y borra filas: DESTRUYE los datos de la base "
            "que le indiques. Creá una base aparte cuyo nombre contenga 'test' o 'verify' "
            "(por ejemplo `CREATE DATABASE club_test`) y apuntá DATABASE_URL ahí.",
            returncode=2,
        )


@pytest.fixture(scope="session", autouse=True)
def _tables():
    """Crea el esquema de test al arrancar y lo borra al terminar."""
    _assert_dedicated_test_database()
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(autouse=True)
def _clean_database(_tables):
    """Cada test arranca con la base limpia y los datos demo cargados."""
    with engine.begin() as conn:
        for table in reversed(Base.metadata.sorted_tables):
            conn.execute(table.delete())
    with SessionLocal() as session:
        seed_demo_data(session)
    yield


@pytest.fixture
def db() -> Session:
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client() -> TestClient:
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def demo_credentials() -> dict:
    return {"email": DEMO_EMAIL, "password": DEMO_PASSWORD}


@pytest.fixture
def auth_headers(client: TestClient, demo_credentials: dict) -> dict:
    response = client.post("/auth/login", json=demo_credentials)
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.fixture
def future_date():
    """Devuelve YYYY-MM-DD a N días de hoy (por defecto 2, siempre futuro)."""

    def _make(days: int = 2) -> str:
        return (datetime.now().date() + timedelta(days=days)).isoformat()

    return _make


@pytest.fixture
def past_date():
    def _make(days: int = 1) -> str:
        return (datetime.now().date() - timedelta(days=days)).isoformat()

    return _make


@pytest.fixture
def moron_venue(db: Session) -> Venue:
    return db.execute(select(Venue).where(Venue.name == "Moron")).scalar_one()


@pytest.fixture
def paddle_space(db: Session, moron_venue: Venue) -> SportSpace:
    return db.execute(
        select(SportSpace)
        .where(SportSpace.venue_id == moron_venue.id, SportSpace.space_type == "Paddle")
        .order_by(SportSpace.number)
    ).scalars().first()
