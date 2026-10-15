"""Job de avisos push: ventana de tiempo y no repetición de avisos."""

from datetime import datetime, time, timedelta

from sqlalchemy import select

from app.clock import now_local
from app.models import DeviceToken, Reservation, ReservationStatus, User
from app.seed import DEMO_EMAIL
from app.services.notifications import find_upcoming_reservations, notify_upcoming_reservations


def _usuario_demo(db) -> User:
    return db.execute(select(User).where(User.email == DEMO_EMAIL)).scalar_one()


def _reserva(db, space_id: int, cuando: datetime) -> Reservation:
    """Reserva activa de una hora que arranca en `cuando` (hora local de la sede, sin tzinfo)."""
    reserva = Reservation(
        user_id=_usuario_demo(db).id,
        sport_space_id=space_id,
        date=cuando.date(),
        start_time=cuando.time().replace(second=0, microsecond=0),
        end_time=(cuando + timedelta(hours=1)).time().replace(second=0, microsecond=0),
        status=ReservationStatus.active,
    )
    db.add(reserva)
    db.commit()
    db.refresh(reserva)
    return reserva


def test_la_ventana_trae_solo_lo_que_arranca_dentro_de_la_hora(db, paddle_space):
    ahora = datetime.combine(now_local().date(), time(18, 0))
    dentro = _reserva(db, paddle_space.id, datetime.combine(ahora.date(), time(18, 45)))
    fuera = _reserva(db, paddle_space.id, datetime.combine(ahora.date(), time(19, 30)))

    encontradas = [r.id for r in find_upcoming_reservations(db, now=ahora, window_minutes=60)]

    assert dentro.id in encontradas
    assert fuera.id not in encontradas


def test_la_ventana_cruza_la_medianoche_sin_traer_todo_el_dia_siguiente(db, paddle_space):
    """Regresión: a las 23:30, la ventana de una hora no puede incluir un turno de mañana a las 20:00.

    Comparar sólo la fecha hacía entrar cualquier reserva del día siguiente cuando la ventana
    cruzaba la medianoche: 20 horas de anticipación en lugar de una.
    """
    ahora = datetime.combine(now_local().date(), time(23, 30))
    manana = (ahora + timedelta(days=1)).date()
    tarde = _reserva(db, paddle_space.id, datetime.combine(manana, time(20, 0)))
    madrugada = _reserva(db, paddle_space.id, datetime.combine(manana, time(0, 15)))

    encontradas = [r.id for r in find_upcoming_reservations(db, now=ahora, window_minutes=60)]

    assert madrugada.id in encontradas
    assert tarde.id not in encontradas


def test_una_reserva_cancelada_no_se_avisa(db, paddle_space):
    ahora = datetime.combine(now_local().date(), time(18, 0))
    cancelada = _reserva(db, paddle_space.id, datetime.combine(ahora.date(), time(18, 30)))
    cancelada.status = ReservationStatus.cancelled
    db.commit()

    encontradas = [r.id for r in find_upcoming_reservations(db, now=ahora, window_minutes=60)]

    assert cancelada.id not in encontradas


def test_el_mismo_aviso_no_se_manda_dos_veces(monkeypatch, db, paddle_space):
    """Correr el job dos veces con la misma reserva dentro de la ventana no repite el aviso."""
    monkeypatch.setattr("app.services.notifications.send_push", lambda *args, **kwargs: True)

    manana = now_local() + timedelta(days=1)
    reserva = _reserva(db, paddle_space.id, datetime.combine(manana.date(), time(20, 0)))
    db.add(DeviceToken(user_id=reserva.user_id, token="token-de-prueba", platform="android"))
    db.commit()

    monkeypatch.setattr(
        "app.services.notifications.find_upcoming_reservations", lambda *args, **kwargs: [reserva]
    )

    primera = notify_upcoming_reservations(db)
    segunda = notify_upcoming_reservations(db)

    assert primera == {"upcoming": 1, "attempted": 1, "sent": 1, "skipped": 0}
    assert segunda == {"upcoming": 1, "attempted": 0, "sent": 0, "skipped": 1}


def test_sin_dispositivos_registrados_no_intenta_enviar(monkeypatch, db, paddle_space):
    monkeypatch.setattr("app.services.notifications.send_push", lambda *args, **kwargs: True)

    manana = now_local() + timedelta(days=1)
    reserva = _reserva(db, paddle_space.id, datetime.combine(manana.date(), time(20, 0)))
    monkeypatch.setattr(
        "app.services.notifications.find_upcoming_reservations", lambda *args, **kwargs: [reserva]
    )

    resumen = notify_upcoming_reservations(db)

    assert resumen == {"upcoming": 1, "attempted": 0, "sent": 0, "skipped": 0}
