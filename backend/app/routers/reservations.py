"""Gestión de reservas: crear, listar activas, historial y cancelar."""

from datetime import datetime

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from ..clock import now_local
from ..database import get_db
from ..errors import documented_errors
from ..models import User
from ..schemas import ReservationCreate, ReservationOut
from ..security import get_current_user
from ..services.reservations import (
    cancel_reservation,
    create_reservation,
    list_active_reservations,
    list_reservation_history,
    to_reservation_out,
)

router = APIRouter(prefix="/reservations", tags=["Reservas"])


@router.post(
    "",
    response_model=ReservationOut,
    status_code=status.HTTP_201_CREATED,
    responses=documented_errors(400, 401, 404, 409),
    summary="Crear una reserva (valida disponibilidad de forma atómica)",
)
def create(
    payload: ReservationCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReservationOut:
    reservation = create_reservation(
        db,
        current_user,
        sport_space_id=payload.sport_space_id,
        day=payload.date,
        start_time=payload.start_time,
        end_time=payload.end_time,
        now=now_local(),
    )
    return to_reservation_out(reservation)


@router.get(
    "",
    response_model=list[ReservationOut],
    responses=documented_errors(401),
    summary="Listar mis reservas vigentes",
)
def list_active(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> list[ReservationOut]:
    return [
        to_reservation_out(reservation)
        for reservation in list_active_reservations(db, current_user, now=now_local())
    ]


@router.get(
    "/history",
    response_model=list[ReservationOut],
    responses=documented_errors(401),
    summary="Historial: reservas terminadas y canceladas",
)
def history(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> list[ReservationOut]:
    return [
        to_reservation_out(reservation)
        for reservation in list_reservation_history(db, current_user, now=now_local())
    ]


@router.post(
    "/{reservation_id}/cancel",
    response_model=ReservationOut,
    responses=documented_errors(400, 401, 404),
    summary="Cancelar una reserva",
)
def cancel(
    reservation_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReservationOut:
    reservation = cancel_reservation(db, current_user, reservation_id)
    return to_reservation_out(reservation)
