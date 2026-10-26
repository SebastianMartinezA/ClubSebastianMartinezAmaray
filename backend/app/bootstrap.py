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


def ensure_catalog_indexes(engine: Engine) -> bool:
    """Adapta la unicidad del catálogo a la baja lógica en una base que ya existe.

    Las tablas se crearon con `name UNIQUE` en sedes y espacios, y con un `UNIQUE (venue_id,
    space_type, number)` que no mira `is_active`. Con esas restricciones, una sede dada de baja
    bloqueaba para siempre su nombre. La regla pasa a ser: el nombre (o el slot) se reserva sólo
    mientras está activo, y eso lo garantiza un índice único parcial.

    `create_all` no toca restricciones de tablas existentes, así que el cambio se aplica acá.
    Es idempotente: mira qué hay y sólo hace falta cuando falta. Devuelve True si cambió algo.
    """
    if engine.dialect.name != "postgresql":
        # En SQLite las restricciones no se pueden quitar sin reconstruir la tabla. Una base
        # SQLite creada con esta versión ya nace con los índices parciales correctos.
        return False

    inspector = inspect(engine)
    tablas = set(inspector.get_table_names())
    if not {"venues", "sport_spaces"} <= tablas:
        return False

    obsoletas = [
        ("venues", "venues_name_key"),
        ("sport_spaces", "sport_spaces_name_key"),
        ("sport_spaces", "uq_space_per_venue_type_number"),
    ]
    faltantes = [
        (
            "venues",
            "uq_venue_active_name_lower",
            "ON venues (lower(name)) WHERE is_active",
        ),
        (
            "sport_spaces",
            "uq_space_active_slot",
            "ON sport_spaces (venue_id, space_type, number) WHERE is_active",
        ),
    ]

    existentes: dict[str, set[str]] = {}
    for tabla in ("venues", "sport_spaces"):
        nombres = {c["name"] for c in inspector.get_unique_constraints(tabla)}
        nombres |= {i["name"] for i in inspector.get_indexes(tabla)}
        existentes[tabla] = nombres

    cambios = False
    with engine.begin() as connection:
        for tabla, restriccion in obsoletas:
            if restriccion not in existentes[tabla]:
                continue
            try:
                connection.execute(
                    text(f"ALTER TABLE {tabla} DROP CONSTRAINT IF EXISTS {restriccion}")
                )
                cambios = True
            except Exception as error:  # noqa: BLE001 - no se puede tumbar el arranque por esto
                logger.warning("No se pudo quitar %s.%s: %s", tabla, restriccion, error)
            # Si la unicidad venía como índice suelto y no como constraint, cae por acá.
            try:
                connection.execute(text(f"DROP INDEX IF EXISTS {restriccion}"))
            except Exception:  # noqa: BLE001 - el índice pertenece a la constraint que ya se fue
                pass
        for tabla, indice, definicion in faltantes:
            if indice in existentes[tabla]:
                continue
            try:
                connection.execute(
                    text(f"CREATE UNIQUE INDEX IF NOT EXISTS {indice} {definicion}")
                )
                cambios = True
            except Exception as error:  # noqa: BLE001
                logger.warning("No se pudo crear el índice %s: %s", indice, error)

    if cambios:
        logger.info("Esquema actualizado: unicidad del catálogo limitada a los registros activos.")
    return cambios


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
