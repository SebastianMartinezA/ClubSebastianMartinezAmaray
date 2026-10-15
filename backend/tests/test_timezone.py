"""Zona horaria: las reservas son horas de pared de la sede, no del servidor.

En Render el contenedor corre en UTC, tres horas adelantado respecto de Argentina. Sin el reloj
local, el backend rechazaría como "pasada" una reserva de las 22:00 cuando en Argentina todavía son
las 21:00. Estos tests fijan ese comportamiento.
"""

import os
import time as time_module
from datetime import date, datetime, time, timedelta, timezone

import pytest

from app import clock
from app.errors import ValidationError
from app.models import SportSpace, User, Venue
from app.services.reservations import create_reservation


def test_now_local_usa_la_zona_configurada(monkeypatch):
    """Con el sistema en UTC, now_local() tiene que devolver la hora de Argentina (UTC-3)."""
    monkeypatch.setenv("TZ", "UTC")
    time_module.tzset()
    try:
        utc_naive = datetime.now(timezone.utc).replace(tzinfo=None)
        local = clock.now_local()
        diferencia = utc_naive - local
        assert timedelta(hours=2, minutes=55) <= diferencia <= timedelta(hours=3, minutes=5), (
            f"now_local() devolvió {local} y UTC {utc_naive}: no aplicó la zona horaria"
        )
        assert local.hour != utc_naive.hour or local.day != utc_naive.day
    finally:
        monkeypatch.delenv("TZ", raising=False)
        time_module.tzset()


def test_validacion_de_futuro_usa_la_hora_local(db):
    """Escenario real: servidor en UTC a las 00:00 del 15/10, sede en Argentina donde son las 21:00.

    Una reserva para el 14/10 de 22:00 a 23:00 es futura en Argentina y ya pasada en UTC.
    Con la hora local se acepta; con la hora del servidor se rechazaría.
    """
    venue = Venue(name="Sede TZ", address="Calle 1", opening_time=time(8, 0), closing_time=time(23, 0))
    db.add(venue)
    db.flush()
    space = SportSpace(venue_id=venue.id, space_type="Paddle", number=1, name="TZ_Paddle_1")
    db.add(space)
    user = User(
        email="tz@example.com",
        password_hash="x",
        first_name="Test",
        last_name="TZ",
        birth_date=date(1990, 1, 1),
    )
    db.add(user)
    db.commit()

    hora_del_servidor_en_utc = datetime(2026, 10, 15, 0, 0)
    hora_local_argentina = datetime(2026, 10, 14, 21, 0)

    # Con la hora del servidor (UTC) la reserva se rechaza...
    with pytest.raises(ValidationError) as error:
        create_reservation(
            db,
            user,
            sport_space_id=space.id,
            day=date(2026, 10, 14),
            start_time=time(22, 0),
            end_time=time(23, 0),
            now=hora_del_servidor_en_utc,
        )
    assert error.value.code == "reservation_in_the_past"

    # ...y con la hora local de la sede se acepta.
    reserva = create_reservation(
        db,
        user,
        sport_space_id=space.id,
        day=date(2026, 10, 14),
        start_time=time(22, 0),
        end_time=time(23, 0),
        now=hora_local_argentina,
    )
    assert reserva.id is not None
