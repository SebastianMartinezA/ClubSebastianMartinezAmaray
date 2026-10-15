"""Sedes, espacios deportivos y consulta de disponibilidad."""


def test_listar_sedes_con_horarios(client):
    response = client.get("/venues")
    assert response.status_code == 200
    venues = response.json()
    assert len(venues) >= 2
    for venue in venues:
        assert venue["name"] and venue["address"]
        assert venue["opening_time"] < venue["closing_time"]
    assert [v["name"] for v in venues] == sorted(v["name"] for v in venues)


def test_detalle_de_sede(client, moron_venue):
    response = client.get(f"/venues/{moron_venue.id}")
    assert response.status_code == 200
    assert response.json()["name"] == "Moron"
    assert response.json()["address"] == "Rivadavia 19850"


def test_sede_inexistente_da_404(client):
    response = client.get("/venues/999999")
    assert response.status_code == 404
    assert response.json()["code"] == "venue_not_found"


def test_espacios_de_la_sede(client, moron_venue):
    response = client.get(f"/venues/{moron_venue.id}/spaces")
    assert response.status_code == 200
    spaces = response.json()
    assert len(spaces) == 3
    assert all(space["venue_id"] == moron_venue.id for space in spaces)
    assert all(space["venue_name"] == "Moron" for space in spaces)


def test_nombre_compuesto_del_espacio(client, moron_venue):
    """Formato exigido por la consigna: Moron_Rivadavia_19850_Paddle_1."""
    spaces = client.get(f"/venues/{moron_venue.id}/spaces").json()
    nombres = {space["name"] for space in spaces}
    assert "Moron_Rivadavia_19850_Paddle_1" in nombres
    assert "Moron_Rivadavia_19850_Futbol_1" in nombres


def test_listar_todos_los_espacios(client):
    response = client.get("/spaces")
    assert response.status_code == 200
    spaces = response.json()
    assert len(spaces) >= 5
    assert all(space["space_type"] and space["number"] for space in spaces)


def test_filtrar_espacios_por_tipo(client):
    response = client.get("/spaces", params={"type": "Paddle"})
    assert response.status_code == 200
    spaces = response.json()
    assert spaces, "tiene que haber espacios Paddle en el seed"
    assert all(space["space_type"] == "Paddle" for space in spaces)

    futbol = client.get("/spaces", params={"type": "Futbol"}).json()
    assert all(space["space_type"] == "Futbol" for space in futbol)
    assert {s["name"] for s in futbol} & {s["name"] for s in spaces} == set()


def test_filtrar_espacios_por_sede(client, moron_venue):
    spaces = client.get("/spaces", params={"venue_id": moron_venue.id}).json()
    assert all(space["venue_id"] == moron_venue.id for space in spaces)


def test_detalle_de_espacio_y_404(client, paddle_space):
    response = client.get(f"/spaces/{paddle_space.id}")
    assert response.status_code == 200
    assert response.json()["id"] == paddle_space.id

    assert client.get("/spaces/999999").status_code == 404


def test_disponibilidad_devuelve_grilla_de_turnos(client, moron_venue, future_date):
    response = client.get(
        f"/venues/{moron_venue.id}/availability", params={"date": future_date(3)}
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["date"] == future_date(3)
    assert body["venue"]["name"] == "Moron"
    assert len(body["spaces"]) == 3

    # Morón abre 08:00 y cierra 22:00 -> 14 turnos de una hora.
    primer_espacio = body["spaces"][0]
    assert len(primer_espacio["slots"]) == 14
    assert primer_espacio["slots"][0]["start_time"] == "08:00:00"
    assert primer_espacio["slots"][0]["end_time"] == "09:00:00"
    assert primer_espacio["slots"][-1]["start_time"] == "21:00:00"
    assert all(slot["available"] for slot in primer_espacio["slots"])


def test_disponibilidad_marca_turno_reservado(client, auth_headers, moron_venue, paddle_space, future_date):
    dia = future_date(4)
    creada = client.post(
        "/reservations",
        headers=auth_headers,
        json={
            "sport_space_id": paddle_space.id,
            "date": dia,
            "start_time": "10:00:00",
            "end_time": "12:00:00",
        },
    )
    assert creada.status_code == 201, creada.text

    body = client.get(f"/venues/{moron_venue.id}/availability", params={"date": dia}).json()
    espacio = next(s for s in body["spaces"] if s["space"]["id"] == paddle_space.id)
    por_hora = {slot["start_time"]: slot["available"] for slot in espacio["slots"]}
    assert por_hora["10:00:00"] is False
    assert por_hora["11:00:00"] is False
    assert por_hora["09:00:00"] is True
    assert por_hora["12:00:00"] is True


def test_disponibilidad_de_una_fecha_pasada_no_tiene_turnos_libres(client, moron_venue, past_date):
    body = client.get(f"/venues/{moron_venue.id}/availability", params={"date": past_date(1)}).json()
    slots = body["spaces"][0]["slots"]
    assert slots, "la grilla se arma igual aunque la fecha ya pasó"
    assert all(slot["available"] is False for slot in slots)


def test_disponibilidad_sede_inexistente_da_404(client, future_date):
    response = client.get("/venues/999999/availability", params={"date": future_date(2)})
    assert response.status_code == 404
    assert response.json()["code"] == "venue_not_found"


def test_disponibilidad_fecha_invalida_da_400(client, moron_venue):
    response = client.get(f"/venues/{moron_venue.id}/availability", params={"date": "no-es-fecha"})
    assert response.status_code == 400
    assert response.json()["code"] == "validation_error"


def test_disponibilidad_sin_fecha_da_400(client, moron_venue):
    response = client.get(f"/venues/{moron_venue.id}/availability")
    assert response.status_code == 400
