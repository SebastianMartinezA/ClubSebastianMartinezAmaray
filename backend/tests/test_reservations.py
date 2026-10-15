"""Reglas de negocio de reservas (1 a 9), incluida la prueba de concurrencia (regla 7)."""

import threading
from datetime import date, datetime, time, timedelta

import pytest
from sqlalchemy import select

from app.database import SessionLocal
from app.errors import ConflictError
from app.models import Reservation, ReservationStatus, SportSpace, User, Venue
from app.seed import DEMO_EMAIL
from app.services.reservations import create_reservation


def _payload(space_id: int, dia: str, start: str, end: str) -> dict:
    return {"sport_space_id": space_id, "date": dia, "start_time": start, "end_time": end}


def _crear(client, headers, space_id, dia, start, end):
    return client.post("/reservations", headers=headers, json=_payload(space_id, dia, start, end))


# --------------------------------------------------------------------------- #
# Camino feliz
# --------------------------------------------------------------------------- #
def test_crear_reserva_valida(client, auth_headers, paddle_space, future_date):
    dia = future_date(2)
    response = _crear(client, auth_headers, paddle_space.id, dia, "18:00:00", "19:00:00")
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["sport_space_id"] == paddle_space.id
    assert body["date"] == dia
    assert body["start_time"] == "18:00:00"
    assert body["end_time"] == "19:00:00"
    assert body["status"] == "active"
    assert body["venue_name"] == "Moron"
    assert body["space_name"] == "Moron_Rivadavia_19850_Paddle_1"
    assert body["id"] > 0


def test_reserva_de_dos_horas_es_valida(client, auth_headers, paddle_space, future_date):
    response = _crear(client, auth_headers, paddle_space.id, future_date(2), "18:00:00", "20:00:00")
    assert response.status_code == 201, response.text


def test_listar_reservas_vigentes(client, auth_headers, paddle_space, future_date):
    dia = future_date(3)
    assert _crear(client, auth_headers, paddle_space.id, dia, "09:00:00", "10:00:00").status_code == 201

    response = client.get("/reservations", headers=auth_headers)
    assert response.status_code == 200
    reservas = response.json()
    assert len(reservas) == 1
    assert reservas[0]["date"] == dia
    assert reservas[0]["venue_name"] and reservas[0]["space_name"]


def test_reservas_contiguas_no_se_solapan(client, auth_headers, paddle_space, future_date):
    """Regla 6: 18-19 y 19-20 se tocan pero no se superponen."""
    dia = future_date(6)
    assert _crear(client, auth_headers, paddle_space.id, dia, "18:00:00", "19:00:00").status_code == 201
    assert _crear(client, auth_headers, paddle_space.id, dia, "19:00:00", "20:00:00").status_code == 201


def test_otro_espacio_en_el_mismo_horario_es_valido(client, auth_headers, moron_venue, future_date):
    espacios = client.get(f"/venues/{moron_venue.id}/spaces").json()
    dia = future_date(7)
    for espacio in espacios:
        assert _crear(client, auth_headers, espacio["id"], dia, "15:00:00", "16:00:00").status_code == 201


# --------------------------------------------------------------------------- #
# Regla 6: solapamiento -> 409
# --------------------------------------------------------------------------- #
def test_reserva_solapada_da_409(client, auth_headers, paddle_space, future_date):
    dia = future_date(2)
    assert _crear(client, auth_headers, paddle_space.id, dia, "18:00:00", "20:00:00").status_code == 201

    response = _crear(client, auth_headers, paddle_space.id, dia, "19:00:00", "21:00:00")
    assert response.status_code == 409
    assert response.json()["code"] == "space_not_available"
    assert "detail" in response.json()


def test_reserva_identica_da_409(client, auth_headers, paddle_space, future_date):
    dia = future_date(2)
    assert _crear(client, auth_headers, paddle_space.id, dia, "10:00:00", "11:00:00").status_code == 201
    assert _crear(client, auth_headers, paddle_space.id, dia, "10:00:00", "11:00:00").status_code == 409


def test_mismo_horario_en_otra_fecha_es_valido(client, auth_headers, paddle_space, future_date):
    assert _crear(client, auth_headers, paddle_space.id, future_date(2), "10:00:00", "11:00:00").status_code == 201
    assert _crear(client, auth_headers, paddle_space.id, future_date(3), "10:00:00", "11:00:00").status_code == 201


def test_solapamiento_entre_usuarios_distintos(client, auth_headers, paddle_space, future_date):
    dia = future_date(2)
    assert _crear(client, auth_headers, paddle_space.id, dia, "10:00:00", "11:00:00").status_code == 201

    registro = client.post(
        "/auth/register",
        json={
            "email": "otro@club.com",
            "password": "OtraClave123",
            "first_name": "Otro",
            "last_name": "Usuario",
        },
    )
    assert registro.status_code == 201
    otros_headers = {"Authorization": f"Bearer {registro.json()['access_token']}"}
    assert _crear(client, otros_headers, paddle_space.id, dia, "10:00:00", "11:00:00").status_code == 409


# --------------------------------------------------------------------------- #
# Reglas 1 a 5
# --------------------------------------------------------------------------- #
def test_duracion_menor_a_una_hora_da_400(client, auth_headers, paddle_space, future_date):
    response = _crear(client, auth_headers, paddle_space.id, future_date(2), "18:00:00", "18:30:00")
    assert response.status_code == 400
    assert response.json()["code"] == "invalid_duration"


def test_minutos_distintos_de_00_da_400(client, auth_headers, paddle_space, future_date):
    response = _crear(client, auth_headers, paddle_space.id, future_date(2), "18:30:00", "20:00:00")
    assert response.status_code == 400
    assert response.json()["code"] == "invalid_time_granularity"


def test_inicio_igual_al_fin_da_400(client, auth_headers, paddle_space, future_date):
    response = _crear(client, auth_headers, paddle_space.id, future_date(2), "18:00:00", "18:00:00")
    assert response.status_code == 400
    assert response.json()["code"] == "invalid_range"


def test_fin_menor_que_inicio_da_400(client, auth_headers, paddle_space, future_date):
    response = _crear(client, auth_headers, paddle_space.id, future_date(2), "19:00:00", "18:00:00")
    assert response.status_code == 400
    assert response.json()["code"] == "invalid_range"


def test_antes_de_la_apertura_da_400(client, auth_headers, paddle_space, future_date):
    """Morón abre 08:00."""
    response = _crear(client, auth_headers, paddle_space.id, future_date(2), "06:00:00", "07:00:00")
    assert response.status_code == 400
    assert response.json()["code"] == "outside_venue_hours"


def test_despues_del_cierre_da_400(client, auth_headers, paddle_space, future_date):
    """Morón cierra 22:00."""
    response = _crear(client, auth_headers, paddle_space.id, future_date(2), "22:00:00", "23:00:00")
    assert response.status_code == 400
    assert response.json()["code"] == "outside_venue_hours"


def test_reserva_en_el_pasado_da_400(client, auth_headers, paddle_space, past_date):
    response = _crear(client, auth_headers, paddle_space.id, past_date(1), "10:00:00", "11:00:00")
    assert response.status_code == 400
    assert response.json()["code"] == "reservation_in_the_past"


def test_reserva_de_hoy_con_hora_ya_pasada_da_400(client, auth_headers, paddle_space):
    ahora = datetime.now()
    if ahora.time() <= time(9, 0):
        pytest.skip("recién arranca el día: todavía no hay turnos de hoy ya vencidos")
    hoy = ahora.date().isoformat()
    response = _crear(client, auth_headers, paddle_space.id, hoy, "08:00:00", "09:00:00")
    assert response.status_code == 400
    assert response.json()["code"] == "reservation_in_the_past"


def test_espacio_inexistente_da_404(client, auth_headers, future_date):
    response = _crear(client, auth_headers, 999999, future_date(2), "10:00:00", "11:00:00")
    assert response.status_code == 404
    assert response.json()["code"] == "space_not_found"


def test_crear_reserva_sin_token_da_401(client, paddle_space, future_date):
    response = client.post(
        "/reservations", json=_payload(paddle_space.id, future_date(2), "10:00:00", "11:00:00")
    )
    assert response.status_code == 401


# --------------------------------------------------------------------------- #
# Regla 8: cancelar libera el horario
# --------------------------------------------------------------------------- #
def test_cancelar_libera_el_horario(client, auth_headers, paddle_space, future_date):
    dia = future_date(2)
    creada = _crear(client, auth_headers, paddle_space.id, dia, "16:00:00", "17:00:00")
    assert creada.status_code == 201
    reserva_id = creada.json()["id"]

    # Mientras está activa, el horario está tomado.
    assert _crear(client, auth_headers, paddle_space.id, dia, "16:00:00", "17:00:00").status_code == 409

    cancelada = client.post(f"/reservations/{reserva_id}/cancel", headers=auth_headers)
    assert cancelada.status_code == 200, cancelada.text
    assert cancelada.json()["status"] == "cancelled"
    assert cancelada.json()["cancelled_at"] is not None

    # Al cancelar, el espacio vuelve a estar disponible para ese mismo horario.
    recreada = _crear(client, auth_headers, paddle_space.id, dia, "16:00:00", "17:00:00")
    assert recreada.status_code == 201, recreada.text
    assert recreada.json()["id"] != reserva_id

    # La cancelada sale de las vigentes.
    vigentes = client.get("/reservations", headers=auth_headers).json()
    assert reserva_id not in [r["id"] for r in vigentes]

    # Y queda en el historial.
    historial = client.get("/reservations/history", headers=auth_headers).json()
    canceladas = [r for r in historial if r["id"] == reserva_id]
    assert len(canceladas) == 1 and canceladas[0]["status"] == "cancelled"


def test_cancelar_dos_veces_da_409(client, auth_headers, paddle_space, future_date):
    creada = _crear(client, auth_headers, paddle_space.id, future_date(2), "16:00:00", "17:00:00")
    reserva_id = creada.json()["id"]
    assert client.post(f"/reservations/{reserva_id}/cancel", headers=auth_headers).status_code == 200

    response = client.post(f"/reservations/{reserva_id}/cancel", headers=auth_headers)
    assert response.status_code == 409
    assert response.json()["code"] == "reservation_already_cancelled"


def test_cancelar_reserva_inexistente_da_404(client, auth_headers):
    response = client.post("/reservations/999999/cancel", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["code"] == "reservation_not_found"


def test_cancelar_reserva_ajena_da_403(client, auth_headers, paddle_space, future_date):
    creada = _crear(client, auth_headers, paddle_space.id, future_date(2), "16:00:00", "17:00:00")
    reserva_id = creada.json()["id"]

    registro = client.post(
        "/auth/register",
        json={
            "email": "ajeno@club.com",
            "password": "OtraClave123",
            "first_name": "Ajeno",
            "last_name": "Usuario",
        },
    )
    otros_headers = {"Authorization": f"Bearer {registro.json()['access_token']}"}

    response = client.post(f"/reservations/{reserva_id}/cancel", headers=otros_headers)
    assert response.status_code == 403
    assert response.json()["code"] == "not_reservation_owner"


def test_cada_usuario_ve_solo_sus_reservas(client, auth_headers, paddle_space, future_date):
    assert _crear(client, auth_headers, paddle_space.id, future_date(2), "09:00:00", "10:00:00").status_code == 201

    registro = client.post(
        "/auth/register",
        json={
            "email": "solo@club.com",
            "password": "OtraClave123",
            "first_name": "Solo",
            "last_name": "Mio",
        },
    )
    otros_headers = {"Authorization": f"Bearer {registro.json()['access_token']}"}
    assert client.get("/reservations", headers=otros_headers).json() == []


# --------------------------------------------------------------------------- #
# Regla 9: historial
# --------------------------------------------------------------------------- #
def test_historial_incluye_terminadas_y_canceladas(client, auth_headers, paddle_space, future_date, db):
    user = db.execute(select(User).where(User.email == DEMO_EMAIL)).scalar_one()

    # Reserva ya terminada: no se puede crear por API (regla 5), se inserta directo.
    ayer = date.today() - timedelta(days=1)
    db.add(
        Reservation(
            user_id=user.id,
            sport_space_id=paddle_space.id,
            date=ayer,
            start_time=time(9, 0),
            end_time=time(10, 0),
            status=ReservationStatus.active,
        )
    )
    db.commit()

    futura = _crear(client, auth_headers, paddle_space.id, future_date(2), "11:00:00", "12:00:00")
    cancelada_id = futura.json()["id"]
    assert client.post(f"/reservations/{cancelada_id}/cancel", headers=auth_headers).status_code == 200

    historial = client.get("/reservations/history", headers=auth_headers).json()
    estados = {r["id"]: r["status"] for r in historial}
    assert len(historial) == 2
    assert estados[cancelada_id] == "cancelled"
    terminada = next(r for r in historial if r["id"] != cancelada_id)
    assert terminada["status"] == "active"
    assert terminada["date"] == ayer.isoformat()

    # Las vigentes no incluyen nada de esto.
    assert client.get("/reservations", headers=auth_headers).json() == []


def test_historial_sin_reservas_es_lista_vacia(client, auth_headers):
    assert client.get("/reservations/history", headers=auth_headers).json() == []


# --------------------------------------------------------------------------- #
# Regla 7: concurrencia
# --------------------------------------------------------------------------- #
def test_dos_reservas_simultaneas_dejan_una_sola(client, auth_headers, paddle_space, future_date):
    """Dos requests HTTP concurrentes sobre el mismo horario: una 201, la otra 409."""
    dia = future_date(8)
    payload = _payload(paddle_space.id, dia, "17:00:00", "18:00:00")

    barrera = threading.Barrier(2)
    resultados: list[int] = []
    errores: list[str] = []
    lock = threading.Lock()

    def worker() -> None:
        try:
            barrera.wait(timeout=10)
            response = client.post("/reservations", headers=auth_headers, json=payload)
            with lock:
                resultados.append(response.status_code)
        except Exception as exc:  # se reporta abajo, no se pierde
            with lock:
                errores.append(repr(exc))

    hilos = [threading.Thread(target=worker) for _ in range(2)]
    for hilo in hilos:
        hilo.start()
    for hilo in hilos:
        hilo.join(timeout=30)

    assert not errores, errores
    assert sorted(resultados) == [201, 409], resultados

    # Y en la base quedó exactamente una reserva activa para ese horario.
    with SessionLocal() as session:
        activas = session.execute(
            select(Reservation).where(
                Reservation.sport_space_id == paddle_space.id,
                Reservation.date == date.fromisoformat(dia),
                Reservation.status == ReservationStatus.active,
            )
        ).scalars().all()
    assert len(activas) == 1


def test_concurrencia_a_nivel_servicio():
    """Misma carrera, pero con dos sesiones y dos transacciones reales."""
    with SessionLocal() as session:
        espacio_id = session.execute(
            select(SportSpace.id).where(SportSpace.name == "Moron_Rivadavia_19850_Paddle_1")
        ).scalar_one()
        usuario_id = session.execute(select(User.id).where(User.email == DEMO_EMAIL)).scalar_one()

    dia = datetime.now().date() + timedelta(days=9)
    barrera = threading.Barrier(2)
    resultados: list[str] = []
    lock = threading.Lock()

    def worker() -> None:
        with SessionLocal() as session:
            usuario = session.get(User, usuario_id)
            barrera.wait(timeout=10)
            try:
                create_reservation(
                    session,
                    usuario,
                    sport_space_id=espacio_id,
                    day=dia,
                    start_time=time(20, 0),
                    end_time=time(21, 0),
                )
                with lock:
                    resultados.append("created")
            except ConflictError:
                session.rollback()
                with lock:
                    resultados.append("conflict")

    hilos = [threading.Thread(target=worker) for _ in range(2)]
    for hilo in hilos:
        hilo.start()
    for hilo in hilos:
        hilo.join(timeout=30)

    assert sorted(resultados) == ["conflict", "created"], resultados

    with SessionLocal() as session:
        activas = session.execute(
            select(Reservation).where(
                Reservation.sport_space_id == espacio_id,
                Reservation.date == dia,
                Reservation.status == ReservationStatus.active,
            )
        ).scalars().all()
    assert len(activas) == 1
