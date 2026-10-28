"""Administración del catálogo: alta, edición y baja de sedes y espacios deportivos.

Todo el módulo exige perfil de administrador (`is_admin`), que se resuelve contra la base en cada
request. Las rutas públicas de `/venues` y `/spaces` no cambian: siguen mostrando sólo lo activo.

Criterio de borrado: las sedes y los espacios **no se borran**, se dan de baja (`is_active=false`).
Una reserva histórica apunta al espacio, así que borrar la fila rompería el historial y las
estadísticas. Si el espacio o la sede tienen reservas activas de hoy en adelante, la baja se
rechaza con 409 para no dejar reservas huérfanas de un lugar que ya no existe.
"""

import logging

from fastapi import APIRouter, Depends, status
from sqlalchemy import and_, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..clock import now_local
from ..database import get_db
from ..errors import ConflictError, NotFoundError, ValidationError, documented_errors
from ..models import Reservation, ReservationStatus, SportSpace, User, Venue
from ..schemas import (
    SportSpaceAdminOut,
    SportSpaceCreate,
    SportSpaceUpdate,
    UserAdminOut,
    VenueAdminOut,
    VenueCreate,
    VenueUpdate,
)
from ..security import require_admin
from ..services import firebase_admin
from ..seed import build_space_name

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/admin",
    tags=["Administración"],
    dependencies=[Depends(require_admin)],
    responses=documented_errors(401, 403),
)


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
def _venue_out(venue: Venue) -> VenueAdminOut:
    return VenueAdminOut(
        id=venue.id,
        name=venue.name,
        address=venue.address,
        opening_time=venue.opening_time,
        closing_time=venue.closing_time,
        is_active=venue.is_active,
        spaces_count=len(venue.spaces),
    )


def _space_out(space: SportSpace) -> SportSpaceAdminOut:
    return SportSpaceAdminOut(
        id=space.id,
        venue_id=space.venue_id,
        venue_name=space.venue.name if space.venue else "",
        name=space.name,
        space_type=space.space_type,
        number=space.number,
        is_active=space.is_active,
    )


def _get_venue(db: Session, venue_id: int) -> Venue:
    """Devuelve la sede exista o no esté activa: el administrador la tiene que poder reactivar."""
    venue = db.get(Venue, venue_id)
    if venue is None:
        raise NotFoundError("La sede no existe.", code="venue_not_found")
    return venue


def _get_space(db: Session, space_id: int) -> SportSpace:
    space = db.get(SportSpace, space_id)
    if space is None:
        raise NotFoundError("El espacio deportivo no existe.", code="space_not_found")
    return space


def _assert_venue_name_free(db: Session, name: str, exclude_id: int | None = None) -> None:
    """El nombre de sede es único entre las sedes activas. Se compara sin distinguir mayúsculas:
    'Moron' y 'moron' son la misma sede para cualquiera que la busque, así que crear la segunda sólo
    genera duplicados.

    Las sedes dadas de baja no reservan el nombre: si la sede se cerró, el club tiene que poder
    volver a crearla con el mismo nombre."""
    stmt = select(Venue.id).where(
        func.lower(Venue.name) == name.lower(), Venue.is_active.is_(True)
    )
    if exclude_id is not None:
        stmt = stmt.where(Venue.id != exclude_id)
    if db.execute(stmt).first() is not None:
        raise ConflictError("Ya existe una sede con ese nombre.", code="venue_already_exists")


def _assert_space_slot_free(
    db: Session, venue_id: int, space_type: str, number: int, exclude_id: int | None = None
) -> None:
    """El slot (sede, tipo, número) es único entre los espacios activos: un espacio dado de baja no
    bloquea volver a crear el mismo."""
    stmt = select(SportSpace.id).where(
        SportSpace.venue_id == venue_id,
        SportSpace.space_type == space_type,
        SportSpace.number == number,
        SportSpace.is_active.is_(True),
    )
    if exclude_id is not None:
        stmt = stmt.where(SportSpace.id != exclude_id)
    if db.execute(stmt).first() is not None:
        raise ConflictError(
            "Esa sede ya tiene un espacio de ese tipo con ese número.",
            code="space_already_exists",
        )


def _has_future_reservations(db: Session, space_ids: list[int]) -> bool:
    """True si alguno de esos espacios tiene reservas activas de hoy en adelante."""
    if not space_ids:
        return False
    ahora = now_local()
    hoy, hora = ahora.date(), ahora.replace(tzinfo=None).time()
    stmt = (
        select(func.count())
        .select_from(Reservation)
        .where(
            Reservation.sport_space_id.in_(space_ids),
            Reservation.status == ReservationStatus.active,
            or_(
                Reservation.date > hoy,
                and_(Reservation.date == hoy, Reservation.end_time > hora),
            ),
        )
    )
    return bool(db.execute(stmt).scalar_one())


def _commit(db: Session, *, detail: str, code: str) -> None:
    """Commit con traducción de la violación de unicidad a un 409 del dominio."""
    try:
        db.commit()
    except IntegrityError as exc:  # pragma: no cover - red de seguridad, los chequeos van arriba
        db.rollback()
        raise ConflictError(detail, code=code) from exc


def _recompute_space_names(venue: Venue) -> None:
    """El nombre del espacio se compone con sede, dirección, tipo y número: si cambia la sede,
    cambia el nombre de todos sus espacios."""
    for space in venue.spaces:
        space.name = build_space_name(venue, space.space_type, space.number)


# --------------------------------------------------------------------------- #
# Sedes
# --------------------------------------------------------------------------- #
@router.get(
    "/venues",
    response_model=list[VenueAdminOut],
    summary="Listar todas las sedes, incluidas las dadas de baja",
)
def list_venues_admin(db: Session = Depends(get_db)) -> list[VenueAdminOut]:
    venues = db.execute(select(Venue).order_by(Venue.name)).scalars().all()
    return [_venue_out(venue) for venue in venues]


@router.post(
    "/venues",
    response_model=VenueAdminOut,
    status_code=status.HTTP_201_CREATED,
    responses=documented_errors(400, 409),
    summary="Crear una sede",
)
def create_venue(payload: VenueCreate, db: Session = Depends(get_db)) -> VenueAdminOut:
    _assert_venue_name_free(db, payload.name)
    venue = Venue(
        name=payload.name,
        address=payload.address,
        opening_time=payload.opening_time,
        closing_time=payload.closing_time,
    )
    db.add(venue)
    _commit(db, detail="Ya existe una sede con ese nombre.", code="venue_already_exists")
    db.refresh(venue)
    logger.info("Sede creada: %s (id %s)", venue.name, venue.id)
    return _venue_out(venue)


@router.patch(
    "/venues/{venue_id}",
    response_model=VenueAdminOut,
    responses=documented_errors(400, 404, 409),
    summary="Editar una sede (parcial)",
)
def update_venue(venue_id: int, payload: VenueUpdate, db: Session = Depends(get_db)) -> VenueAdminOut:
    venue = _get_venue(db, venue_id)
    cambios = payload.model_dump(exclude_unset=True)
    if not cambios:
        return _venue_out(venue)

    if "name" in cambios and cambios["name"] != venue.name:
        _assert_venue_name_free(db, cambios["name"], exclude_id=venue.id)

    for campo, valor in cambios.items():
        setattr(venue, campo, valor)

    if venue.opening_time >= venue.closing_time:
        raise ValidationError(
            "La hora de apertura debe ser anterior a la de cierre.", code="invalid_opening_hours"
        )

    if "name" in cambios or "address" in cambios:
        _recompute_space_names(venue)

    _commit(db, detail="Ya existe una sede con ese nombre.", code="venue_already_exists")
    db.refresh(venue)
    logger.info("Sede actualizada: %s (id %s)", venue.name, venue.id)
    return _venue_out(venue)


@router.delete(
    "/venues/{venue_id}",
    response_model=VenueAdminOut,
    responses=documented_errors(404, 409),
    summary="Dar de baja una sede (baja lógica)",
)
def deactivate_venue(venue_id: int, db: Session = Depends(get_db)) -> VenueAdminOut:
    venue = _get_venue(db, venue_id)
    if not venue.is_active:
        return _venue_out(venue)

    if _has_future_reservations(db, [space.id for space in venue.spaces]):
        raise ConflictError(
            "La sede tiene reservas activas de hoy en adelante: cancelalas antes de darla de baja.",
            code="venue_has_future_reservations",
        )

    venue.is_active = False
    db.commit()
    db.refresh(venue)
    logger.info("Sede dada de baja: %s (id %s)", venue.name, venue.id)
    return _venue_out(venue)


# --------------------------------------------------------------------------- #
# Espacios deportivos
# --------------------------------------------------------------------------- #
@router.get(
    "/spaces",
    response_model=list[SportSpaceAdminOut],
    summary="Listar todos los espacios, incluidos los dados de baja",
)
def list_spaces_admin(
    venue_id: int | None = None, db: Session = Depends(get_db)
) -> list[SportSpaceAdminOut]:
    stmt = select(SportSpace).order_by(SportSpace.venue_id, SportSpace.space_type, SportSpace.number)
    if venue_id is not None:
        stmt = stmt.where(SportSpace.venue_id == venue_id)
    return [_space_out(space) for space in db.execute(stmt).scalars().all()]


@router.post(
    "/spaces",
    response_model=SportSpaceAdminOut,
    status_code=status.HTTP_201_CREATED,
    responses=documented_errors(400, 404, 409),
    summary="Crear un espacio deportivo en una sede",
)
def create_space(payload: SportSpaceCreate, db: Session = Depends(get_db)) -> SportSpaceAdminOut:
    venue = _get_venue(db, payload.venue_id)
    if not venue.is_active:
        raise ConflictError(
            "La sede está dada de baja: reactivala antes de agregarle espacios.",
            code="venue_inactive",
        )
    _assert_space_slot_free(db, venue.id, payload.space_type, payload.number)

    space = SportSpace(
        venue_id=venue.id,
        space_type=payload.space_type,
        number=payload.number,
        name=build_space_name(venue, payload.space_type, payload.number),
    )
    db.add(space)
    _commit(
        db,
        detail="Esa sede ya tiene un espacio de ese tipo con ese número.",
        code="space_already_exists",
    )
    db.refresh(space)
    logger.info("Espacio creado: %s (id %s)", space.name, space.id)
    return _space_out(space)


@router.patch(
    "/spaces/{space_id}",
    response_model=SportSpaceAdminOut,
    responses=documented_errors(400, 404, 409),
    summary="Editar un espacio (parcial)",
)
def update_space(
    space_id: int, payload: SportSpaceUpdate, db: Session = Depends(get_db)
) -> SportSpaceAdminOut:
    space = _get_space(db, space_id)
    cambios = payload.model_dump(exclude_unset=True)
    if not cambios:
        return _space_out(space)

    venue_id = cambios.get("venue_id", space.venue_id)
    space_type = cambios.get("space_type", space.space_type)
    number = cambios.get("number", space.number)

    if venue_id != space.venue_id:
        venue = _get_venue(db, venue_id)
        if not venue.is_active:
            raise ConflictError(
                "La sede destino está dada de baja: reactivala antes de mover el espacio.",
                code="venue_inactive",
            )
        space.venue = venue

    if (venue_id, space_type, number) != (space.venue_id, space.space_type, space.number):
        _assert_space_slot_free(db, venue_id, space_type, number, exclude_id=space.id)

    space.space_type = space_type
    space.number = number
    space.name = build_space_name(space.venue, space_type, number)
    if "is_active" in cambios:
        space.is_active = cambios["is_active"]

    _commit(
        db,
        detail="Esa sede ya tiene un espacio de ese tipo con ese número.",
        code="space_already_exists",
    )
    db.refresh(space)
    return _space_out(space)


@router.delete(
    "/spaces/{space_id}",
    response_model=SportSpaceAdminOut,
    responses=documented_errors(404, 409),
    summary="Dar de baja un espacio (baja lógica)",
)
def deactivate_space(space_id: int, db: Session = Depends(get_db)) -> SportSpaceAdminOut:
    space = _get_space(db, space_id)
    if not space.is_active:
        return _space_out(space)

    if _has_future_reservations(db, [space.id]):
        raise ConflictError(
            "El espacio tiene reservas activas de hoy en adelante: cancelalas antes de darlo de baja.",
            code="space_has_future_reservations",
        )

    space.is_active = False
    db.commit()
    db.refresh(space)
    logger.info("Espacio dado de baja: %s (id %s)", space.name, space.id)
    return _space_out(space)


# --------------------------------------------------------------------------- #
# Usuarios
# --------------------------------------------------------------------------- #
@router.get(
    "/users",
    response_model=list[UserAdminOut],
    summary="Listar los usuarios del club",
)
def list_users(db: Session = Depends(get_db)) -> list[UserAdminOut]:
    """Devuelve todos los usuarios con su estado y su perfil de permisos.

    No expone el hash de la contraseña: para la UI alcanza con saber quién es admin y
    quién está activo.
    """
    users = db.execute(select(User).order_by(User.id)).scalars().all()
    return [UserAdminOut.model_validate(user) for user in users]


@router.post(
    "/firebase/migrate",
    summary="Importar los usuarios de la base a Firebase Authentication",
)
def migrate_users_to_firebase(db: Session = Depends(get_db)) -> dict:
    """Alta masiva en Firebase Auth conservando la contraseña de cada socio.

    Importa el hash bcrypt que ya está en la base, así nadie tiene que resetear nada. Es
    idempotente: los correos que ya existen en Firebase vuelven como error y se informan.
    """
    if not firebase_admin.configured():
        raise ValidationError(
            "Falta FCM_SERVICE_ACCOUNT_JSON: sin la cuenta de servicio no se puede escribir "
            "en Firebase Authentication.",
            code="firebase_not_configured",
        )

    users = db.execute(select(User).where(User.is_active.is_(True)).order_by(User.id)).scalars().all()
    importable = [u for u in users if u.password_hash.startswith("$2")]
    omitted = len(users) - len(importable)

    if not importable:
        return {"attempted": 0, "created": 0, "omitted": omitted, "errors": []}

    result = firebase_admin.import_users(
        [{"email": u.email, "password_hash": u.password_hash} for u in importable]
    )
    result["omitted"] = omitted
    logger.info(
        "Migración a Firebase: %s creados de %s intentados (%s sin contraseña local)",
        result.get("created"),
        result.get("attempted"),
        omitted,
    )
    return result
