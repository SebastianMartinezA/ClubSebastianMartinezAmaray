"""Módulo de sedes: listado, detalle, espacios de la sede y disponibilidad por fecha."""

from datetime import date as date_type
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from ..database import get_db
from ..errors import NotFoundError, documented_errors
from ..models import Venue
from ..schemas import SportSpaceOut, VenueAvailability, VenueOut
from ..services.reservations import build_venue_availability
from ..clock import now_local

router = APIRouter(prefix="/venues", tags=["Sedes"])


def _get_venue_or_404(db: Session, venue_id: int) -> Venue:
    # Una sede inactiva no existe para el usuario: 404, igual que list_venues (que filtra is_active).
    venue = db.get(Venue, venue_id)
    if venue is None or not venue.is_active:
        raise NotFoundError("La sede no existe.", code="venue_not_found")
    return venue


@router.get("", response_model=list[VenueOut], summary="Listar sedes con sus horarios")
def list_venues(db: Session = Depends(get_db)) -> list[VenueOut]:
    venues = db.execute(select(Venue).where(Venue.is_active.is_(True)).order_by(Venue.name)).scalars().all()
    return [VenueOut.model_validate(venue) for venue in venues]


@router.get(
    "/{venue_id}",
    response_model=VenueOut,
    responses=documented_errors(404),
    summary="Detalle de una sede",
)
def get_venue(venue_id: int, db: Session = Depends(get_db)) -> VenueOut:
    return VenueOut.model_validate(_get_venue_or_404(db, venue_id))


@router.get(
    "/{venue_id}/spaces",
    response_model=list[SportSpaceOut],
    responses=documented_errors(404),
    summary="Espacios deportivos de una sede",
)
def list_venue_spaces(venue_id: int, db: Session = Depends(get_db)) -> list[SportSpaceOut]:
    venue = _get_venue_or_404(db, venue_id)
    return [
        SportSpaceOut(
            id=space.id,
            venue_id=venue.id,
            venue_name=venue.name,
            name=space.name,
            space_type=space.space_type,
            number=space.number,
        )
        for space in venue.spaces
        if space.is_active
    ]


@router.get(
    "/{venue_id}/availability",
    response_model=VenueAvailability,
    responses=documented_errors(400, 404),
    summary="Disponibilidad de los espacios de la sede para una fecha",
)
def get_venue_availability(
    venue_id: int,
    date: date_type = Query(..., description="Fecha a consultar (YYYY-MM-DD)"),
    db: Session = Depends(get_db),
) -> VenueAvailability:
    venue = db.execute(
        select(Venue)
        .where(Venue.id == venue_id, Venue.is_active.is_(True))
        .options(selectinload(Venue.spaces))
    ).scalar_one_or_none()
    if venue is None:
        raise NotFoundError("La sede no existe.", code="venue_not_found")

    return VenueAvailability(
        venue=VenueOut.model_validate(venue),
        date=date,
        spaces=build_venue_availability(db, venue, date, now=now_local()),
    )
