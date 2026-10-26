"""CRUD de sedes y espacios deportivos (perfil administrador).

Cubre: autorización (401 sin token, 403 sin perfil de administrador), alta, edición parcial,
unicidad, validación de horarios, baja lógica y el 409 cuando hay reservas futuras que quedarían
colgadas de un lugar inactivo.
"""

from sqlalchemy import select

from app.models import SportSpace, Venue

# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
def _nueva_sede(client, headers, nombre="Tigre", direccion="Av. Cazon 1200"):
    return client.post(
        "/admin/venues",
        headers=headers,
        json={
            "name": nombre,
            "address": direccion,
            "opening_time": "08:00",
            "closing_time": "22:00",
        },
    )


def _reservar(client, headers, space_id, dia, desde="18:00:00", hasta="19:00:00"):
    return client.post(
        "/reservations",
        headers=headers,
        json={
            "sport_space_id": space_id,
            "date": dia,
            "start_time": desde,
            "end_time": hasta,
        },
    )


# --------------------------------------------------------------------------- #
# Autorización de la sección
# --------------------------------------------------------------------------- #
def test_sin_token_da_401(client):
    response = client.get("/admin/venues")
    assert response.status_code == 401
    assert response.json()["code"] == "missing_token"


def test_usuario_comun_da_403(client, auth_headers):
    response = client.get("/admin/venues", headers=auth_headers)
    assert response.status_code == 403
    assert response.json()["code"] == "admin_required"


def test_usuario_comun_no_puede_crear_sede(client, auth_headers):
    response = _nueva_sede(client, auth_headers)
    assert response.status_code == 403
    assert response.json()["code"] == "admin_required"


# --------------------------------------------------------------------------- #
# Sedes: alta
# --------------------------------------------------------------------------- #
def test_crear_sede(client, admin_headers):
    response = _nueva_sede(client, admin_headers)

    assert response.status_code == 201, response.text
    cuerpo = response.json()
    assert cuerpo["name"] == "Tigre"
    assert cuerpo["address"] == "Av. Cazon 1200"
    assert cuerpo["opening_time"].startswith("08:00")
    assert cuerpo["closing_time"].startswith("22:00")
    assert cuerpo["is_active"] is True
    assert cuerpo["spaces_count"] == 0


def test_la_sede_nueva_aparece_en_el_listado_publico(client, admin_headers):
    _nueva_sede(client, admin_headers)

    publico = client.get("/venues")
    assert "Tigre" in [venue["name"] for venue in publico.json()]


def test_nombre_de_sede_duplicado_da_409(client, admin_headers):
    response = _nueva_sede(client, admin_headers, nombre="Moron")

    assert response.status_code == 409
    assert response.json()["code"] == "venue_already_exists"


def test_nombre_de_sede_duplicado_no_distingue_mayusculas(client, admin_headers):
    response = _nueva_sede(client, admin_headers, nombre="  moron  ")

    assert response.status_code == 409
    assert response.json()["code"] == "venue_already_exists"


def test_horario_invertido_da_400(client, admin_headers):
    response = client.post(
        "/admin/venues",
        headers=admin_headers,
        json={
            "name": "San Miguel",
            "address": "Calle 1",
            "opening_time": "22:00",
            "closing_time": "08:00",
        },
    )

    assert response.status_code == 400
    assert response.json()["code"] == "validation_error"


def test_sede_sin_nombre_da_400(client, admin_headers):
    response = client.post(
        "/admin/venues",
        headers=admin_headers,
        json={
            "name": "   ",
            "address": "Calle 1",
            "opening_time": "08:00",
            "closing_time": "22:00",
        },
    )

    assert response.status_code == 400
    assert response.json()["code"] == "validation_error"


# --------------------------------------------------------------------------- #
# Sedes: edición
# --------------------------------------------------------------------------- #
def test_editar_sede_parcialmente(client, admin_headers, moron_venue):
    response = client.patch(
        f"/admin/venues/{moron_venue.id}",
        headers=admin_headers,
        json={"closing_time": "23:30"},
    )

    assert response.status_code == 200, response.text
    assert response.json()["closing_time"].startswith("23:30")
    assert response.json()["name"] == "Moron"  # lo no enviado queda igual


def test_editar_horario_invertido_da_400(client, admin_headers, moron_venue):
    response = client.patch(
        f"/admin/venues/{moron_venue.id}",
        headers=admin_headers,
        json={"closing_time": "07:00"},
    )

    assert response.status_code == 400
    assert response.json()["code"] == "invalid_opening_hours"


def test_renombrar_sede_renombra_sus_espacios(client, admin_headers, moron_venue, db):
    response = client.patch(
        f"/admin/venues/{moron_venue.id}",
        headers=admin_headers,
        json={"name": "Moron Centro"},
    )
    assert response.status_code == 200, response.text

    nombres = [
        space.name
        for space in db.execute(
            select(SportSpace).where(SportSpace.venue_id == moron_venue.id)
        ).scalars()
    ]
    assert nombres, "la sede tiene espacios en el seed"
    assert all(nombre.startswith("Moron_Centro_") for nombre in nombres)


def test_editar_sede_inexistente_da_404(client, admin_headers):
    response = client.patch(
        "/admin/venues/999999", headers=admin_headers, json={"name": "Fantasma"}
    )

    assert response.status_code == 404
    assert response.json()["code"] == "venue_not_found"


# --------------------------------------------------------------------------- #
# Sedes: baja
# --------------------------------------------------------------------------- #
def test_baja_de_sede_sin_reservas(client, admin_headers, moron_venue):
    response = client.delete(f"/admin/venues/{moron_venue.id}", headers=admin_headers)

    assert response.status_code == 200, response.text
    assert response.json()["is_active"] is False
    # deja de existir para el usuario común
    assert client.get(f"/venues/{moron_venue.id}").status_code == 404


def test_baja_de_sede_con_reserva_futura_da_409(
    client, admin_headers, auth_headers, paddle_space, future_date
):
    creada = _reservar(client, auth_headers, paddle_space.id, future_date(2))
    assert creada.status_code == 201, creada.text

    response = client.delete(f"/admin/venues/{paddle_space.venue_id}", headers=admin_headers)

    assert response.status_code == 409
    assert response.json()["code"] == "venue_has_future_reservations"


def test_baja_de_sede_es_idempotente(client, admin_headers, moron_venue):
    primera = client.delete(f"/admin/venues/{moron_venue.id}", headers=admin_headers)
    segunda = client.delete(f"/admin/venues/{moron_venue.id}", headers=admin_headers)

    assert primera.status_code == 200
    assert segunda.status_code == 200
    assert segunda.json()["is_active"] is False


def test_se_puede_reactivar_una_sede(client, admin_headers, moron_venue):
    client.delete(f"/admin/venues/{moron_venue.id}", headers=admin_headers)

    response = client.patch(
        f"/admin/venues/{moron_venue.id}", headers=admin_headers, json={"is_active": True}
    )

    assert response.status_code == 200
    assert response.json()["is_active"] is True
    assert client.get(f"/venues/{moron_venue.id}").status_code == 200


# --------------------------------------------------------------------------- #
# Espacios
# --------------------------------------------------------------------------- #
def test_crear_espacio_arma_el_nombre_compuesto(client, admin_headers, moron_venue):
    response = client.post(
        "/admin/spaces",
        headers=admin_headers,
        json={"venue_id": moron_venue.id, "space_type": "Paddle", "number": 3},
    )

    assert response.status_code == 201, response.text
    cuerpo = response.json()
    assert cuerpo["name"] == "Moron_Rivadavia_19850_Paddle_3"
    assert cuerpo["venue_id"] == moron_venue.id
    assert cuerpo["is_active"] is True


def test_el_espacio_nuevo_aparece_en_el_listado_publico(client, admin_headers, moron_venue):
    client.post(
        "/admin/spaces",
        headers=admin_headers,
        json={"venue_id": moron_venue.id, "space_type": "Basquet", "number": 1},
    )

    publico = client.get("/spaces", params={"venue_id": moron_venue.id})
    assert "Moron_Rivadavia_19850_Basquet_1" in [space["name"] for space in publico.json()]


def test_espacio_duplicado_da_409(client, admin_headers, moron_venue):
    response = client.post(
        "/admin/spaces",
        headers=admin_headers,
        json={"venue_id": moron_venue.id, "space_type": "Paddle", "number": 1},
    )

    assert response.status_code == 409
    assert response.json()["code"] == "space_already_exists"


def test_crear_espacio_en_sede_inexistente_da_404(client, admin_headers):
    response = client.post(
        "/admin/spaces",
        headers=admin_headers,
        json={"venue_id": 999999, "space_type": "Paddle", "number": 1},
    )

    assert response.status_code == 404
    assert response.json()["code"] == "venue_not_found"


def test_crear_espacio_en_sede_dada_de_baja_da_409(client, admin_headers, moron_venue):
    client.delete(f"/admin/venues/{moron_venue.id}", headers=admin_headers)

    response = client.post(
        "/admin/spaces",
        headers=admin_headers,
        json={"venue_id": moron_venue.id, "space_type": "Paddle", "number": 9},
    )

    assert response.status_code == 409
    assert response.json()["code"] == "venue_inactive"


def test_numero_de_espacio_invalido_da_400(client, admin_headers, moron_venue):
    response = client.post(
        "/admin/spaces",
        headers=admin_headers,
        json={"venue_id": moron_venue.id, "space_type": "Paddle", "number": 0},
    )

    assert response.status_code == 400
    assert response.json()["code"] == "validation_error"


def test_editar_espacio_recalcula_el_nombre(client, admin_headers, paddle_space):
    response = client.patch(
        f"/admin/spaces/{paddle_space.id}", headers=admin_headers, json={"number": 7}
    )

    assert response.status_code == 200, response.text
    assert response.json()["number"] == 7
    assert response.json()["name"].endswith("_Paddle_7")


def test_editar_espacio_a_un_slot_ocupado_da_409(client, admin_headers, moron_venue, db):
    pongamos = client.post(
        "/admin/spaces",
        headers=admin_headers,
        json={"venue_id": moron_venue.id, "space_type": "Paddle", "number": 5},
    )
    assert pongamos.status_code == 201, pongamos.text
    nuevo_id = pongamos.json()["id"]

    response = client.patch(
        f"/admin/spaces/{nuevo_id}", headers=admin_headers, json={"number": 1}
    )

    assert response.status_code == 409
    assert response.json()["code"] == "space_already_exists"


def test_baja_de_espacio_con_reserva_futura_da_409(
    client, admin_headers, auth_headers, paddle_space, future_date
):
    creada = _reservar(client, auth_headers, paddle_space.id, future_date(2))
    assert creada.status_code == 201, creada.text

    response = client.delete(f"/admin/spaces/{paddle_space.id}", headers=admin_headers)

    assert response.status_code == 409
    assert response.json()["code"] == "space_has_future_reservations"


def test_baja_de_espacio_lo_esconde_del_listado_publico(client, admin_headers, paddle_space):
    response = client.delete(f"/admin/spaces/{paddle_space.id}", headers=admin_headers)

    assert response.status_code == 200, response.text
    assert response.json()["is_active"] is False
    assert client.get(f"/spaces/{paddle_space.id}").status_code == 404

    publico = client.get("/spaces")
    assert paddle_space.id not in [space["id"] for space in publico.json()]


def test_reactivar_espacio_lo_devuelve_al_listado(client, admin_headers, paddle_space):
    client.delete(f"/admin/spaces/{paddle_space.id}", headers=admin_headers)

    response = client.patch(
        f"/admin/spaces/{paddle_space.id}", headers=admin_headers, json={"is_active": True}
    )

    assert response.status_code == 200
    assert response.json()["is_active"] is True
    assert client.get(f"/spaces/{paddle_space.id}").status_code == 200


def test_el_administrador_ve_las_sedes_dadas_de_baja(client, admin_headers, moron_venue, db):
    client.delete(f"/admin/venues/{moron_venue.id}", headers=admin_headers)

    response = client.get("/admin/venues", headers=admin_headers)
    inactivas = [venue for venue in response.json() if venue["is_active"] is False]
    assert [venue["name"] for venue in inactivas] == ["Moron"]
    # la vista pública, en cambio, no la muestra
    assert "Moron" not in [venue["name"] for venue in client.get("/venues").json()]


def test_el_espacio_movido_de_sede_cambia_de_nombre(
    client, admin_headers, paddle_space, db
):
    castelar = db.execute(select(Venue).where(Venue.name == "Castelar")).scalar_one()

    response = client.patch(
        f"/admin/spaces/{paddle_space.id}",
        headers=admin_headers,
        json={"venue_id": castelar.id, "number": 4},
    )

    assert response.status_code == 200, response.text
    assert response.json()["venue_id"] == castelar.id
    assert response.json()["name"] == "Castelar_Av._Yrigoyen_1234_Paddle_4"
