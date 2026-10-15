"""Reglas de negocio de reservas.

Acá viven las 14 reglas del TP: duración mínima, granularidad horaria, coherencia de horarios,
horario de funcionamiento de la sede, reservas sólo a futuro, no solapamiento, validación +
inserción atómicas, cancelación que libera el horario e historial.
"""

from datetime import date as date_type
from datetime import datetime, time, timedelta

from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session

from ..errors import ConflictError, ForbiddenError, NotFoundError, ValidationError
from ..models import Reservation, ReservationStatus, SportSpace, User, Venue
from ..schemas import AvailabilitySlot, ReservationOut, SpaceAvailability
from ..clock import now_local

MIN_DURATION = timedelta(hours=1)
SLOT_SIZE = timedelta(hours=1)


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
def _combine(day: date_type, moment: time) -> datetime:
    return datetime.combine(day, moment)


def to_reservation_out(reservation: Reservation) -> ReservationOut:
    space = reservation.sport_space
    venue = space.venue if space else None
    return ReservationOut(
        id=reservation.id,
        sport_space_id=reservation.sport_space_id,
        space_name=space.name if space else "",
        venue_id=venue.id if venue else 0,
        venue_name=venue.name if venue else "",
        date=reservation.date,
        start_time=reservation.start_time,
        end_time=reservation.end_time,
        status=reservation.status,
        created_at=reservation.created_at,
        cancelled_at=reservation.cancelled_at,
    )


def _upcoming_condition(now: datetime):
    """Reservas cuyo fin todavía no pasó (incluye la que está en curso)."""
    return or_(
        Reservation.date > now.date(),
        and_(Reservation.date == now.date(), Reservation.end_time > now.time()),
    )


def _finished_condition(now: datetime):
    return or_(
        Reservation.date < now.date(),
        and_(Reservation.date == now.date(), Reservation.end_time <= now.time()),
    )


# --------------------------------------------------------------------------- #
# Validaciones (reglas 1 a 5)
# --------------------------------------------------------------------------- #
def validate_time_granularity(start_time: time, end_time: time) -> None:
    """Regla 2: horas completas, minuto y segundo en 00."""
    for value, label in ((start_time, "inicio"), (end_time, "fin")):
        if value.minute != 0 or value.second != 0 or value.microsecond != 0:
            raise ValidationError(
                f"La hora de {label} tiene que ser en punto (minuto y segundo en 00).",
                code="invalid_time_granularity",
            )


def validate_range(day: date_type, start_time: time, end_time: time) -> None:
    """Reglas 3 y 1: start < end y duración mínima de una hora.

    Se evalúa antes que la granularidad para que una reserva de media hora (18:00 a 18:30)
    informe el problema de duración, que es el error real, y no el minuto 30.
    """
    if start_time >= end_time:
        raise ValidationError(
            "La hora de inicio tiene que ser anterior a la hora de finalización.", code="invalid_range"
        )
    if _combine(day, end_time) - _combine(day, start_time) < MIN_DURATION:
        raise ValidationError(
            "La reserva tiene que durar como mínimo una hora.", code="invalid_duration"
        )


def validate_inside_venue_hours(venue: Venue, start_time: time, end_time: time) -> None:
    """Regla 4: apertura <= inicio y fin <= cierre."""
    if start_time < venue.opening_time or end_time > venue.closing_time:
        raise ValidationError(
            f"El horario tiene que estar dentro del funcionamiento de la sede "
            f"({venue.opening_time.strftime('%H:%M')} a {venue.closing_time.strftime('%H:%M')}).",
            code="outside_venue_hours",
        )


def validate_is_future(day: date_type, start_time: time, now: datetime) -> None:
    """Regla 5: la reserva tiene que ser futura respecto del momento de la reserva."""
    if _combine(day, start_time) <= now:
        raise ValidationError(
            "La reserva tiene que ser para un horario futuro.", code="reservation_in_the_past"
        )


def find_overlapping_reservations(
    db: Session,
    sport_space_id: int,
    day: date_type,
    start_time: time,
    end_time: time,
    exclude_reservation_id: int | None = None,
) -> list[Reservation]:
    """Regla 6: solapamiento start < otro_end and end > otro_start, sólo entre reservas activas."""
    stmt = select(Reservation).where(
        Reservation.sport_space_id == sport_space_id,
        Reservation.date == day,
        Reservation.status == ReservationStatus.active,
        Reservation.start_time < end_time,
        Reservation.end_time > start_time,
    )
    if exclude_reservation_id is not None:
        stmt = stmt.where(Reservation.id != exclude_reservation_id)
    return list(db.execute(stmt).scalars().all())


def lock_space(db: Session, sport_space_id: int) -> SportSpace:
    """Regla 7: bloquea la fila del espacio hasta el commit.

    Dos requests simultáneos sobre el mismo espacio se serializan acá: el segundo espera a que
    el primero commitee y recién entonces evalúa el solapamiento sobre datos ya visibles.
    """
    space = db.execute(
        select(SportSpace).where(SportSpace.id == sport_space_id).with_for_update()
    ).scalar_one_or_none()
    if space is None:
        raise NotFoundError("El espacio deportivo no existe.", code="space_not_found")
    return space


# --------------------------------------------------------------------------- #
# Casos de uso
# --------------------------------------------------------------------------- #
def create_reservation(
    db: Session,
    user: User,
    *,
    sport_space_id: int,
    day: date_type,
    start_time: time,
    end_time: time,
    now: datetime | None = None,
) -> Reservation:
    """Valida disponibilidad e inserta la reserva dentro de la misma transacción."""
    now = now or now_local()

    space = lock_space(db, sport_space_id)
    if not space.is_active:
        raise ValidationError("El espacio deportivo no está disponible.", code="space_inactive")
    venue = db.get(Venue, space.venue_id)
    if venue is None or not venue.is_active:
        raise ValidationError("La sede del espacio no está disponible.", code="venue_inactive")

    validate_range(day, start_time, end_time)
    validate_time_granularity(start_time, end_time)
    validate_inside_venue_hours(venue, start_time, end_time)
    validate_is_future(day, start_time, now)

    if find_overlapping_reservations(db, space.id, day, start_time, end_time):
        raise ConflictError(
            "El espacio ya está reservado en ese horario.", code="space_not_available"
        )

    reservation = Reservation(
        user_id=user.id,
        sport_space_id=space.id,
        date=day,
        start_time=start_time,
        end_time=end_time,
        status=ReservationStatus.active,
    )
    db.add(reservation)
    db.commit()
    db.refresh(reservation)
    return reservation


def cancel_reservation(db: Session, user: User, reservation_id: int, now: datetime | None = None) -> Reservation:
    """Regla 8: pasa a cancelled (no se borra) y libera el horario."""
    now = now or now_local()
    reservation = db.get(Reservation, reservation_id)
    if reservation is None:
        raise NotFoundError("La reserva no existe.", code="reservation_not_found")
    if reservation.user_id != user.id:
        raise ForbiddenError("La reserva pertenece a otro usuario.", code="not_reservation_owner")
    if reservation.status == ReservationStatus.cancelled:
        raise ConflictError("La reserva ya estaba cancelada.", code="reservation_already_cancelled")

    reservation.status = ReservationStatus.cancelled
    reservation.cancelled_at = now
    db.commit()
    db.refresh(reservation)
    return reservation


def list_active_reservations(db: Session, user: User, now: datetime | None = None) -> list[Reservation]:
    now = now or now_local()
    stmt = (
        select(Reservation)
        .where(
            Reservation.user_id == user.id,
            Reservation.status == ReservationStatus.active,
            _upcoming_condition(now),
        )
        .order_by(Reservation.date, Reservation.start_time)
    )
    return list(db.execute(stmt).scalars().all())


def list_reservation_history(db: Session, user: User, now: datetime | None = None) -> list[Reservation]:
    """Regla 9: incluye las terminadas y las canceladas, distinguidas por estado."""
    now = now or now_local()
    stmt = (
        select(Reservation)
        .where(
            Reservation.user_id == user.id,
            or_(
                Reservation.status == ReservationStatus.cancelled,
                and_(
                    Reservation.status == ReservationStatus.active,
                    _finished_condition(now),
                ),
            ),
        )
        .order_by(Reservation.date.desc(), Reservation.start_time.desc())
    )
    return list(db.execute(stmt).scalars().all())


def build_venue_availability(
    db: Session, venue: Venue, day: date_type, now: datetime | None = None
) -> list[SpaceAvailability]:
    """Consultar disponibilidad de espacios de una sede según la fecha.

    Devuelve, por cada espacio activo, la grilla de turnos de una hora entre apertura y cierre,
    marcando cuáles están libres. Un turno pasado tampoco está disponible.
    """
    now = now or now_local()
    result: list[SpaceAvailability] = []

    for space in sorted(venue.spaces, key=lambda s: (s.space_type, s.number)):
        if not space.is_active:
            continue
        busy = find_overlapping_reservations(
            db, space.id, day, time.min, time.max
        )
        slots: list[AvailabilitySlot] = []
        cursor = _combine(day, venue.opening_time)
        limit = _combine(day, venue.closing_time)
        while cursor + SLOT_SIZE <= limit:
            slot_start = cursor.time()
            slot_end = (cursor + SLOT_SIZE).time()
            taken = any(r.start_time < slot_end and r.end_time > slot_start for r in busy)
            slots.append(
                AvailabilitySlot(
                    start_time=slot_start,
                    end_time=slot_end,
                    available=(not taken) and cursor > now,
                )
            )
            cursor += SLOT_SIZE

        result.append(
            SpaceAvailability(
                space={
                    "id": space.id,
                    "venue_id": space.venue_id,
                    "venue_name": venue.name,
                    "name": space.name,
                    "space_type": space.space_type,
                    "number": space.number,
                },
                slots=slots,
            )
        )
    return result
