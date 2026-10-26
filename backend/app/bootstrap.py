"""Arranque: ajustes mínimos de esquema y promoción del administrador.

El TP no usa Alembic: el esquema se crea con `Base.metadata.create_all` al arrancar. Ese mecanismo
crea tablas nuevas, pero **no agrega columnas a una tabla que ya existe**, así que una columna nueva
en el código no aparecería en la base de producción. `ensure_admin_column` cubre ese único caso con
un `ALTER TABLE` idempotente; si la columna ya está, no hace nada.
"""

import logging

from sqlalchemy import inspect, select, text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session

from .models import User

logger = logging.getLogger(__name__)


def ensure_admin_column(engine: Engine) -> bool:
    """Agrega `users.is_admin` si la tabla existe sin esa columna. Devuelve True si la agregó."""
    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return False
    if any(column["name"] == "is_admin" for column in inspector.get_columns("users")):
        return False

    # PostgreSQL acepta `false`, SQLite (la base de test alternativa) necesita 0.
    default = "false" if engine.dialect.name == "postgresql" else "0"
    with engine.begin() as connection:
        connection.execute(
            text(f"ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT {default}")
        )
    logger.info("Esquema actualizado: se agregó la columna users.is_admin.")
    return True


def promote_admin(db: Session, email: str) -> bool:
    """Marca como administrador al usuario con ese correo. Devuelve True si lo cambió.

    Se llama al arrancar con `ADMIN_EMAIL`. Es idempotente y no falla si el correo todavía no
    está registrado: en ese caso avisa por log y el usuario queda como administrador en el
    siguiente arranque, una vez que se registre.
    """
    email = (email or "").strip().lower()
    if not email:
        return False

    user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
    if user is None:
        logger.warning(
            "ADMIN_EMAIL=%s configurado pero no hay usuario con ese correo: nadie queda como "
            "administrador. Registralo con POST /auth/register y reiniciá el servicio.",
            email,
        )
        return False
    if user.is_admin:
        return False

    user.is_admin = True
    db.commit()
    logger.info("Usuario %s promovido a administrador (puede gestionar sedes y espacios).", email)
    return True
