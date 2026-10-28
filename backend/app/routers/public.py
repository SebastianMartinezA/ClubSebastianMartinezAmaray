"""Consultas abiertas: listados de sólo lectura que no piden token.

Pensado para mostrar los datos del club desde afuera (un panel, un curl de la
cátedra, DBeaver, una planilla) sin repartir credenciales. Todo lo que hay acá
es **sólo lectura** y sale de datos que el club ya publica: sedes, horarios,
espacios y la nómina de socios.

Lo que no se expone nunca en esta vista: el hash de la contraseña, el estado
`is_active`, el permiso `is_admin` y la fecha de nacimiento. Tampoco las
reservas: cruzar un socio con el horario que reservó es información de terceros
y no hace falta para demostrar el modelo de datos.
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from ..database import get_db
from ..models import Reservation, ReservationStatus, SportSpace, User, Venue
from ..schemas import PublicSummary, PublicUserOut, PublicVenueOut, SportSpaceOut

router = APIRouter(prefix="/public", tags=["Público"])


@router.get(
    "/users",
    response_model=list[PublicUserOut],
    summary="Todos los usuarios del club (sin token)",
)
def list_public_users(
    db: Session = Depends(get_db),
    limit: int = Query(default=100, ge=1, le=500, description="Cuántos devolver"),
    offset: int = Query(default=0, ge=0, description="Cuántos saltear"),
) -> list[PublicUserOut]:
    """Nómina de socios activos, ordenada por apellido.

    Devuelve lo mínimo para identificar a la persona: id, nombre, apellido,
    correo y fecha de alta. Nada de contraseñas, permisos ni fecha de nacimiento.
    """
    users = (
        db.execute(
            select(User)
            .where(User.is_active.is_(True))
            .order_by(User.last_name, User.first_name, User.id)
            .limit(limit)
            .offset(offset)
        )
        .scalars()
        .all()
    )
    return [PublicUserOut.model_validate(user) for user in users]


@router.get(
    "/venues",
    response_model=list[PublicVenueOut],
    summary="Sedes con sus espacios (sin token)",
)
def list_public_venues(db: Session = Depends(get_db)) -> list[PublicVenueOut]:
    """Las sedes activas con la lista de espacios de cada una.

    Es el listado que necesita cualquiera para saber dónde se puede reservar sin
    tener que encadenar una llamada por sede.
    """
    venues = (
        db.execute(
            select(Venue)
            .where(Venue.is_active.is_(True))
            .options(selectinload(Venue.spaces))
            .order_by(Venue.name)
        )
        .scalars()
        .all()
    )

    salida: list[PublicVenueOut] = []
    for venue in venues:
        espacios = sorted(
            (space for space in venue.spaces if space.is_active),
            key=lambda space: (space.space_type, space.number),
        )
        salida.append(
            PublicVenueOut(
                id=venue.id,
                name=venue.name,
                address=venue.address,
                opening_time=venue.opening_time,
                closing_time=venue.closing_time,
                spaces=[
                    SportSpaceOut(
                        id=space.id,
                        venue_id=venue.id,
                        venue_name=venue.name,
                        name=space.name,
                        space_type=space.space_type,
                        number=space.number,
                    )
                    for space in espacios
                ],
            )
        )
    return salida


@router.get(
    "/spaces",
    response_model=list[SportSpaceOut],
    summary="Todos los espacios deportivos (sin token)",
)
def list_public_spaces(
    db: Session = Depends(get_db),
    venue_id: int | None = Query(default=None, description="Filtrar por sede"),
) -> list[SportSpaceOut]:
    """Espacios activos de todas las sedes, con el nombre de la sede ya resuelto."""
    consulta = (
        select(SportSpace, Venue.name)
        .join(Venue, SportSpace.venue_id == Venue.id)
        .where(SportSpace.is_active.is_(True), Venue.is_active.is_(True))
        .order_by(Venue.name, SportSpace.space_type, SportSpace.number)
    )
    if venue_id is not None:
        consulta = consulta.where(SportSpace.venue_id == venue_id)

    return [
        SportSpaceOut(
            id=space.id,
            venue_id=space.venue_id,
            venue_name=venue_name,
            name=space.name,
            space_type=space.space_type,
            number=space.number,
        )
        for space, venue_name in db.execute(consulta).all()
    ]


@router.get(
    "/summary",
    response_model=PublicSummary,
    summary="Conteos del club (sin token)",
)
def get_public_summary(db: Session = Depends(get_db)) -> PublicSummary:
    """Cuántos socios, sedes, espacios y reservas activas hay.

    Sirve para una portada o para chequear de un vistazo que la base tiene los
    datos que debería, sin abrir un cliente de SQL.
    """
    usuarios = db.execute(
        select(func.count()).select_from(User).where(User.is_active.is_(True))
    ).scalar_one()
    sedes = db.execute(
        select(func.count()).select_from(Venue).where(Venue.is_active.is_(True))
    ).scalar_one()
    espacios = db.execute(
        select(func.count()).select_from(SportSpace).where(SportSpace.is_active.is_(True))
    ).scalar_one()
    reservas_activas = db.execute(
        select(func.count())
        .select_from(Reservation)
        .where(Reservation.status == ReservationStatus.active)
    ).scalar_one()

    return PublicSummary(
        users=usuarios,
        venues=sedes,
        spaces=espacios,
        active_reservations=reservas_activas,
    )
