"""Pruebas de regresión del backend.

Cada caso fija un comportamiento que se corrigió y que no debe volver a romperse:
    A1 cancelación con timestamp en UTC,
    A2 el perfil no acepta nombres en blanco,
    A3 birth_date no acepta fechas futuras y se puede limpiar,
    A4 el login de un usuario inactivo no filtra la existencia de la cuenta,
    A5 recursos inactivos no se consultan por detalle,
    A6 el filtro por tipo ignora acentos y mayúsculas,
    A7 la disponibilidad no ofrece turnos imposibles de reservar.
"""

from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import select

from app.models import SportSpace, User, Venue


# --------------------------------------------------------------------------- #
# cancelled_at en UTC con zona horaria
# --------------------------------------------------------------------------- #
def test_cancelacion_guarda_cancelled_at_en_utc(client, auth_headers, paddle_space, future_date):
    dia = future_date(2)
    creada = client.post(
        "/reservations",
        headers=auth_headers,
        json={"sport_space_id": paddle_space.id, "date": dia, "start_time": "10:00:00", "end_time": "11:00:00"},
    )
    assert creada.status_code == 201, creada.text
    reserva = creada.json()

    cancelada = client.post(f"/reservations/{reserva['id']}/cancel", headers=auth_headers)
    assert cancelada.status_code == 200, cancelada.text
    body = cancelada.json()

    def _parse(value: str) -> datetime:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))

    created_at = _parse(body["created_at"])
    cancelled_at = _parse(body["cancelled_at"])

    # El evento de cancelación no puede ser anterior a la creación.
    assert cancelled_at >= created_at, (created_at, cancelled_at)

    # Y tiene que estar en UTC con zona horaria, a menos de 60 segundos del reloj del servidor.
    assert cancelled_at.tzinfo is not None, "cancelled_at quedó sin zona horaria"
    diferencia = abs((datetime.now(timezone.utc) - cancelled_at).total_seconds())
    assert diferencia < 60, f"cancelled_at está a {diferencia:.0f}s del reloj UTC (se esperaba <60s)"


# --------------------------------------------------------------------------- #
# PATCH /users/me rechaza nombres en blanco
# --------------------------------------------------------------------------- #
def test_patch_nombre_en_blanco_da_400(client, auth_headers):
    for blanco in ("   ", "  \t "):
        response = client.patch("/users/me", headers=auth_headers, json={"first_name": blanco})
        assert response.status_code == 400, (blanco, response.text)
        assert response.json()["code"] == "validation_error"


def test_patch_nombre_valido_con_espacios_se_recorta(client, auth_headers):
    response = client.patch("/users/me", headers=auth_headers, json={"first_name": "  Ana  "})
    assert response.status_code == 200, response.text
    assert response.json()["first_name"] == "Ana"


def test_patch_apellido_en_blanco_da_400(client, auth_headers):
    response = client.patch("/users/me", headers=auth_headers, json={"last_name": "   "})
    assert response.status_code == 400, response.text
    assert response.json()["code"] == "validation_error"


# --------------------------------------------------------------------------- #
# birth_date: sin fechas futuras y se puede limpiar
# --------------------------------------------------------------------------- #
def test_patch_birth_date_futura_da_400(client, auth_headers):
    response = client.patch("/users/me", headers=auth_headers, json={"birth_date": "2999-01-01"})
    assert response.status_code == 400, response.text
    assert response.json()["code"] == "validation_error"


def test_patch_birth_date_anterior_a_1900_da_400(client, auth_headers):
    response = client.patch("/users/me", headers=auth_headers, json={"birth_date": "1899-12-31"})
    assert response.status_code == 400, response.text
    assert response.json()["code"] == "validation_error"


def test_patch_birth_date_null_la_borra(client, auth_headers):
    assert (
        client.patch("/users/me", headers=auth_headers, json={"birth_date": "1990-05-05"}).status_code == 200
    )
    assert client.get("/users/me", headers=auth_headers).json()["birth_date"] == "1990-05-05"

    response = client.patch("/users/me", headers=auth_headers, json={"birth_date": None})
    assert response.status_code == 200, response.text
    assert response.json()["birth_date"] is None
    assert client.get("/users/me", headers=auth_headers).json()["birth_date"] is None


def test_patch_sin_birth_date_no_la_borra(client, auth_headers):
    client.patch("/users/me", headers=auth_headers, json={"birth_date": "1990-05-05"})
    response = client.patch("/users/me", headers=auth_headers, json={"first_name": "Otro"})
    assert response.status_code == 200
    assert response.json()["birth_date"] == "1990-05-05"


# --------------------------------------------------------------------------- #
# el login de un inactivo no filtra la existencia de la cuenta
# --------------------------------------------------------------------------- #
def test_login_de_usuario_inactivo_no_filtra(client, db, demo_credentials):
    user = db.execute(select(User).where(User.email == demo_credentials["email"])).scalar_one()
    user.is_active = False
    db.commit()

    inactivo = client.post("/auth/login", json=demo_credentials)  # contraseña correcta
    incorrecto = client.post("/auth/login", json=dict(demo_credentials, password="incorrecta"))

    assert inactivo.status_code == 401, inactivo.text
    assert inactivo.status_code == incorrecto.status_code
    assert inactivo.json() == incorrecto.json()


# --------------------------------------------------------------------------- #
# recursos inactivos no se consultan por detalle ni disponibilidad
# --------------------------------------------------------------------------- #
def test_sede_inactiva_no_se_consulta(client, db, moron_venue, future_date):
    moron_venue.is_active = False
    db.commit()

    assert client.get(f"/venues/{moron_venue.id}").status_code == 404
    assert client.get(f"/venues/{moron_venue.id}/spaces").status_code == 404
    response = client.get(
        f"/venues/{moron_venue.id}/availability", params={"date": future_date(2)}
    )
    assert response.status_code == 404
    assert response.json()["code"] == "venue_not_found"


def test_espacio_inactivo_no_se_consulta(client, db, paddle_space):
    paddle_space.is_active = False
    db.commit()
    response = client.get(f"/spaces/{paddle_space.id}")
    assert response.status_code == 404
    assert response.json()["code"] == "space_not_found"


# --------------------------------------------------------------------------- #
# el filtro por tipo ignora acentos y mayúsculas
# --------------------------------------------------------------------------- #
def test_filtro_por_tipo_ignora_acentos_y_mayusculas(client):
    sin_acento = client.get("/spaces", params={"type": "Futbol"}).json()
    con_acento = client.get("/spaces", params={"type": "Fútbol"}).json()
    minusculas = client.get("/spaces", params={"type": "futbol"}).json()

    assert sin_acento, "tiene que haber espacios de tipo Futbol en el seed"
    assert sin_acento == con_acento == minusculas
    assert all(space["space_type"] == "Futbol" for space in sin_acento)


def test_filtro_por_tipo_no_rompe_los_valores_de_la_app(client):
    """La app usa los valores sin acento: Paddle, Basquet, Futbol."""
    for tipo in ("Paddle", "Basquet", "Futbol"):
        espacios = client.get("/spaces", params={"type": tipo}).json()
        assert espacios, f"el filtro {tipo!r} quedó vacío"
        assert all(space["space_type"] == tipo for space in espacios)


# --------------------------------------------------------------------------- #
# la disponibilidad no ofrece turnos imposibles de reservar
# --------------------------------------------------------------------------- #
def _sede_con_apertura_media(db, hh: int, mm: int) -> tuple[Venue, SportSpace]:
    venue = Venue(
        name=f"Sede {hh:02d}{mm:02d}",
        address="Calle A7",
        opening_time=time(hh, mm),
        closing_time=time(22, 0),
    )
    db.add(venue)
    db.flush()
    space = SportSpace(
        venue_id=venue.id, space_type="Paddle", number=1, name=f"Sede_{hh:02d}{mm:02d}_Paddle_1"
    )
    db.add(space)
    db.commit()
    return venue, space


def test_disponibilidad_arranca_en_hora_en_punto(client, db, future_date):
    venue, _ = _sede_con_apertura_media(db, 8, 30)
    body = client.get(f"/venues/{venue.id}/availability", params={"date": future_date(3)}).json()
    slots = body["spaces"][0]["slots"]

    assert slots[0]["start_time"] == "09:00:00", "la grilla tiene que empezar en la primera hora en punto"
    assert slots[-1]["start_time"] == "21:00:00"
    for slot in slots:
        hora, minuto, segundo = (int(part) for part in slot["start_time"].split(":"))
        assert (minuto, segundo) == (0, 0), f"turno con minutos: {slot}"
        fin = time.fromisoformat(slot["end_time"])
        assert time(hora, minuto) >= venue.opening_time, slot
        assert fin <= venue.closing_time, slot


def test_el_primer_turno_ofrecido_es_reservable(client, db, auth_headers, future_date):
    venue, space = _sede_con_apertura_media(db, 8, 30)
    dia = future_date(3)
    body = client.get(f"/venues/{venue.id}/availability", params={"date": dia}).json()
    primero = body["spaces"][0]["slots"][0]

    response = client.post(
        "/reservations",
        headers=auth_headers,
        json={
            "sport_space_id": space.id,
            "date": dia,
            "start_time": primero["start_time"],
            "end_time": primero["end_time"],
        },
    )
    assert response.status_code == 201, response.text


# --------------------------------------------------------------------------- #
# un espacio de una sede inactiva tampoco se consulta
# --------------------------------------------------------------------------- #
def test_espacio_de_sede_inactiva_no_se_consulta(client, db, moron_venue, paddle_space):
    """Un espacio activo de una sede inactiva no se ofrece: el filtro tiene que mirar
    la sede además del espacio."""
    moron_venue.is_active = False
    db.commit()

    listado = client.get("/spaces").json()
    assert all(space["venue_id"] != moron_venue.id for space in listado), listado
    assert client.get("/spaces", params={"venue_id": moron_venue.id}).json() == []

    detalle = client.get(f"/spaces/{paddle_space.id}")
    assert detalle.status_code == 404, detalle.text
    assert detalle.json()["code"] == "space_not_found"

    # Y la sede inactiva sigue dando 404 en su propio detalle (parte ya cubierta de A5).
    assert client.get(f"/venues/{moron_venue.id}").status_code == 404
