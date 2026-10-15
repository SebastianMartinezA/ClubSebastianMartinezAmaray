"""Módulo de espacios deportivos: listado con filtro por tipo y detalle."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..errors import NotFoundError
from ..models import SportSpace
from ..schemas import SportSpaceOut

router = APIRouter(prefix="/spaces", tags=["Espacios deportivos"])


def _to_out(space: SportSpace) -> SportSpaceOut:
    return SportSpaceOut(
        id=space.id,
        venue_id=space.venue_id,
        venue_name=space.venue.name if space.venue else "",
        name=space.name,
        space_type=space.space_type,
        number=space.number,
    )


@router.get("", response_model=list[SportSpaceOut], summary="Listar espacios deportivos (filtro por tipo)")
def list_spaces(
    type: str | None = Query(default=None, description="Tipo de espacio: Fútbol, Paddle, Básquet, etc."),
    venue_id: int | None = Query(default=None, description="Filtrar por sede"),
    db: Session = Depends(get_db),
) -> list[SportSpaceOut]:
    stmt = select(SportSpace).where(SportSpace.is_active.is_(True)).options(joinedload(SportSpace.venue))
    if type:
        stmt = stmt.where(SportSpace.space_type.ilike(f"%{type.strip()}%"))
    if venue_id is not None:
        stmt = stmt.where(SportSpace.venue_id == venue_id)
    spaces = db.execute(stmt.order_by(SportSpace.venue_id, SportSpace.space_type, SportSpace.number)).scalars().all()
    return [_to_out(space) for space in spaces]


@router.get("/{space_id}", response_model=SportSpaceOut, summary="Detalle de un espacio deportivo")
def get_space(space_id: int, db: Session = Depends(get_db)) -> SportSpaceOut:
    space = db.get(SportSpace, space_id)
    if space is None:
        raise NotFoundError("El espacio deportivo no existe.", code="space_not_found")
    return _to_out(space)
