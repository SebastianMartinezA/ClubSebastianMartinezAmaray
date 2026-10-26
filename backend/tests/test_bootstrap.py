"""Ajuste de esquema al arrancar y promoción del administrador.

La suite principal corre contra PostgreSQL, pero estas dos funciones son las que corren en el
arranque de producción sobre una base que ya existe. Se prueban sobre SQLite en un archivo temporal
para simular una base "vieja" (sin la columna `is_admin`) sin tocar la base de test compartida.
"""

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import Session

from app.bootstrap import ensure_admin_column, promote_admin
from app.database import Base
from app.models import User
from app.security import hash_password


def _engine_sin_columna(tmp_path):
    """Base con el esquema completo, pero sin `users.is_admin` (como una base ya desplegada)."""
    engine = create_engine(f"sqlite:///{tmp_path}/legacy.db")
    Base.metadata.create_all(bind=engine)
    with engine.begin() as connection:
        connection.execute(text("ALTER TABLE users DROP COLUMN is_admin"))
    return engine


def test_agrega_la_columna_que_falta(tmp_path):
    engine = _engine_sin_columna(tmp_path)
    assert not any(c["name"] == "is_admin" for c in inspect(engine).get_columns("users"))

    assert ensure_admin_column(engine) is True
    assert any(c["name"] == "is_admin" for c in inspect(engine).get_columns("users"))


def test_es_idempotente(tmp_path):
    engine = _engine_sin_columna(tmp_path)

    assert ensure_admin_column(engine) is True
    assert ensure_admin_column(engine) is False


def test_no_falla_si_la_tabla_no_existe(tmp_path):
    engine = create_engine(f"sqlite:///{tmp_path}/vacia.db")
    assert ensure_admin_column(engine) is False


def test_promueve_al_usuario_existente(tmp_path):
    engine = _engine_sin_columna(tmp_path)
    ensure_admin_column(engine)

    with Session(engine) as session:
        session.add(
            User(
                email="admin@club.com",
                password_hash=hash_password("Clave1234!"),
                first_name="Ada",
                last_name="Admin",
            )
        )
        session.commit()

        assert promote_admin(session, "admin@club.com") is True
        session.expire_all()
        assert session.query(User).filter_by(email="admin@club.com").one().is_admin is True
        # segunda vez: no hay nada que cambiar
        assert promote_admin(session, "admin@club.com") is False


def test_no_promueve_si_el_correo_no_existe(tmp_path):
    engine = _engine_sin_columna(tmp_path)
    ensure_admin_column(engine)

    with Session(engine) as session:
        assert promote_admin(session, "nadie@club.com") is False


def test_sin_correo_configurado_no_hace_nada(tmp_path):
    engine = _engine_sin_columna(tmp_path)
    ensure_admin_column(engine)

    with Session(engine) as session:
        assert promote_admin(session, "") is False
