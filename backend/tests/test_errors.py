"""Formato consistente de errores (regla 14) y manejo de errores de transporte."""

import pytest


def _assert_cuerpo(response, code_esperado=None):
    body = response.json()
    assert set(body.keys()) >= {"detail", "code"}, body
    assert isinstance(body["detail"], str) and body["detail"]
    assert isinstance(body["code"], str) and body["code"]
    if code_esperado:
        assert body["code"] == code_esperado
    return body


def test_401_tiene_formato_consistente(client):
    body = _assert_cuerpo(client.get("/auth/me"), "missing_token")
    assert "token" in body["detail"].lower()


def test_404_de_ruta_inexistente(client):
    response = client.get("/ruta-que-no-existe")
    assert response.status_code == 404
    _assert_cuerpo(response, "not_found")


def test_404_de_recurso_inexistente(client):
    response = client.get("/venues/999999")
    assert response.status_code == 404
    _assert_cuerpo(response, "venue_not_found")


def test_405_metodo_no_permitido(client):
    response = client.delete("/venues")
    assert response.status_code == 405
    _assert_cuerpo(response, "method_not_allowed")


def test_400_de_validacion_de_payload(client):
    response = client.post("/auth/register", json={"email": "malo", "password": "1"})
    assert response.status_code == 400
    _assert_cuerpo(response, "validation_error")


def test_400_json_ilegible(client):
    response = client.post(
        "/auth/login", content=b"{no es json", headers={"Content-Type": "application/json"}
    )
    assert response.status_code == 400
    _assert_cuerpo(response)


def test_409_de_correo_repetido(client):
    payload = {
        "email": "repetido@club.com",
        "password": "Secreta123",
        "first_name": "Re",
        "last_name": "Petido",
    }
    assert client.post("/auth/register", json=payload).status_code == 201
    response = client.post("/auth/register", json=payload)
    assert response.status_code == 409
    _assert_cuerpo(response, "email_already_registered")


def test_409_de_solapamiento(client, auth_headers, paddle_space, future_date):
    payload = {
        "sport_space_id": paddle_space.id,
        "date": future_date(2),
        "start_time": "12:00:00",
        "end_time": "13:00:00",
    }
    assert client.post("/reservations", headers=auth_headers, json=payload).status_code == 201
    response = client.post("/reservations", headers=auth_headers, json=payload)
    assert response.status_code == 409
    _assert_cuerpo(response, "space_not_available")


def test_403_de_recurso_ajeno(client, auth_headers, paddle_space, future_date):
    creada = client.post(
        "/reservations",
        headers=auth_headers,
        json={
            "sport_space_id": paddle_space.id,
            "date": future_date(2),
            "start_time": "13:00:00",
            "end_time": "14:00:00",
        },
    )
    assert creada.status_code == 201

    registro = client.post(
        "/auth/register",
        json={
            "email": "intruso@club.com",
            "password": "OtraClave123",
            "first_name": "In",
            "last_name": "Truso",
        },
    )
    headers = {"Authorization": f"Bearer {registro.json()['access_token']}"}
    response = client.post(f"/reservations/{creada.json()['id']}/cancel", headers=headers)
    assert response.status_code == 403
    _assert_cuerpo(response, "not_reservation_owner")


def test_token_mal_formado_en_el_header(client):
    response = client.get("/users/me", headers={"Authorization": "Bearer"})
    assert response.status_code == 401
    _assert_cuerpo(response)


def test_health(client):
    assert client.get("/health").json()["status"] == "ok"


def test_raiz_apunta_a_la_documentacion(client):
    raiz = client.get("/").json()
    assert raiz["docs"] == "/docs"
    assert raiz["openapi"] == "/openapi.json"


@pytest.mark.parametrize(
    "metodo,ruta",
    [
        ("get", "/auth/me"),
        ("get", "/users/me"),
        ("patch", "/users/me"),
        ("get", "/reservations"),
        ("post", "/reservations"),
        ("get", "/reservations/history"),
        ("post", "/reservations/1/cancel"),
        ("post", "/devices"),
        ("get", "/devices"),
    ],
)
def test_rutas_protegidas_sin_token_dan_401(client, metodo, ruta):
    if metodo in ("post", "patch"):
        response = getattr(client, metodo)(ruta, json={})
    else:
        response = getattr(client, metodo)(ruta)
    assert response.status_code == 401, f"{metodo.upper()} {ruta} -> {response.status_code}"
    _assert_cuerpo(response, "missing_token")
