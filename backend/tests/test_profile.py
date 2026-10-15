"""Perfil del usuario autenticado (regla 10: el correo no se puede cambiar)."""


def test_get_perfil(client, auth_headers, demo_credentials):
    response = client.get("/users/me", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["email"] == demo_credentials["email"]
    assert body["first_name"] and body["last_name"]
    assert "created_at" in body


def test_patch_perfil_actualiza_datos(client, auth_headers):
    response = client.patch(
        "/users/me",
        headers=auth_headers,
        json={"first_name": "Sebastián", "last_name": "Martínez Amaray", "birth_date": "1998-07-31"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["first_name"] == "Sebastián"
    assert body["last_name"] == "Martínez Amaray"
    assert body["birth_date"] == "1998-07-31"

    # Se persiste: se ve en el GET siguiente.
    assert client.get("/users/me", headers=auth_headers).json()["birth_date"] == "1998-07-31"


def test_patch_con_mismo_correo_es_valido(client, auth_headers, demo_credentials):
    response = client.patch(
        "/users/me", headers=auth_headers, json={"email": demo_credentials["email"]}
    )
    assert response.status_code == 200
    assert response.json()["email"] == demo_credentials["email"]


def test_patch_con_otro_correo_da_400(client, auth_headers):
    response = client.patch("/users/me", headers=auth_headers, json={"email": "otro@club.com"})
    assert response.status_code == 400
    assert response.json()["code"] == "email_not_editable"
    assert "correo" in response.json()["detail"].lower()


def test_patch_no_cambia_el_correo_tras_intento_rechazado(client, auth_headers, demo_credentials):
    client.patch("/users/me", headers=auth_headers, json={"email": "otro@club.com"})
    assert client.get("/users/me", headers=auth_headers).json()["email"] == demo_credentials["email"]


def test_patch_sin_token_da_401(client):
    response = client.patch("/users/me", json={"first_name": "X"})
    assert response.status_code == 401


def test_patch_parcial_no_pisa_lo_demas(client, auth_headers):
    antes = client.get("/users/me", headers=auth_headers).json()
    response = client.patch("/users/me", headers=auth_headers, json={"first_name": "Otro"})
    assert response.status_code == 200
    despues = response.json()
    assert despues["first_name"] == "Otro"
    assert despues["last_name"] == antes["last_name"]
    assert despues["birth_date"] == antes["birth_date"]
