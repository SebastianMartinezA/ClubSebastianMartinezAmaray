"""Registro, login, recuperación de contraseña y token (reglas 11, 12 y 13)."""

from app.config import get_settings


def _payload(email: str = "nuevo@club.com", password: str = "Secreta123") -> dict:
    return {
        "email": email,
        "password": password,
        "first_name": "Ana",
        "last_name": "Gomez",
        "birth_date": "1995-04-12",
    }


def test_register_devuelve_token_y_usuario(client):
    response = client.post("/auth/register", json=_payload("Nuevo@Club.com"))
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["user"]["email"] == "nuevo@club.com"  # normalizado
    assert body["user"]["first_name"] == "Ana"
    assert body["expires_in"] > 0
    assert "password" not in body["user"]


def test_register_email_repetido_da_409(client):
    assert client.post("/auth/register", json=_payload()).status_code == 201
    response = client.post("/auth/register", json=_payload())
    assert response.status_code == 409
    assert response.json()["code"] == "email_already_registered"
    assert "detail" in response.json()


def test_register_password_corta_da_400(client):
    payload = _payload()
    payload["password"] = "corta"
    response = client.post("/auth/register", json=payload)
    assert response.status_code == 400
    assert response.json()["code"] == "validation_error"


def test_register_email_invalido_da_400(client):
    payload = _payload("no-es-un-mail")
    response = client.post("/auth/register", json=payload)
    assert response.status_code == 400
    assert response.json()["code"] == "validation_error"


def test_login_ok(client, demo_credentials):
    response = client.post("/auth/login", json=demo_credentials)
    assert response.status_code == 200, response.text
    assert response.json()["user"]["email"] == demo_credentials["email"]


def test_login_password_incorrecta_da_401(client, demo_credentials):
    payload = dict(demo_credentials, password="incorrecta")
    response = client.post("/auth/login", json=payload)
    assert response.status_code == 401
    assert response.json()["code"] == "invalid_credentials"


def test_login_correo_inexistente_no_filtra(client, demo_credentials):
    """Regla 12: mismo status y mismo mensaje que con correo existente."""
    existente = client.post("/auth/login", json=dict(demo_credentials, password="mala"))
    inexistente = client.post(
        "/auth/login", json={"email": "nadie@club.com", "password": "mala"}
    )
    assert inexistente.status_code == 401
    assert inexistente.json() == existente.json()


def test_me_devuelve_perfil(client, auth_headers, demo_credentials):
    response = client.get("/auth/me", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["email"] == demo_credentials["email"]


def test_me_sin_token_da_401(client):
    response = client.get("/auth/me")
    assert response.status_code == 401
    assert response.json()["code"] == "missing_token"


def test_me_con_token_invalido_da_401(client):
    response = client.get("/auth/me", headers={"Authorization": "Bearer token-invalido"})
    assert response.status_code == 401
    assert response.json()["code"] == "invalid_token"


def test_forgot_password_no_revela_si_el_correo_existe(client):
    response = client.post("/auth/forgot-password", json={"email": "nadie@club.com"})
    assert response.status_code == 200
    body = response.json()
    assert body["reset_token"] is None
    assert "message" in body


def test_flujo_completo_de_recuperacion(client, monkeypatch, demo_credentials):
    monkeypatch.setattr(get_settings(), "debug", True)

    pedido = client.post("/auth/forgot-password", json={"email": demo_credentials["email"]})
    assert pedido.status_code == 200
    token = pedido.json()["reset_token"]
    assert token, "con DEBUG=true y sin SMTP el token tiene que venir en la respuesta"

    cambio = client.post("/auth/reset-password", json={"token": token, "new_password": "NuevaClave123"})
    assert cambio.status_code == 200, cambio.text
    assert cambio.json()["code"] == "password_updated"

    assert client.post("/auth/login", json=demo_credentials).status_code == 401
    assert (
        client.post(
            "/auth/login", json={"email": demo_credentials["email"], "password": "NuevaClave123"}
        ).status_code
        == 200
    )

    # Token de un solo uso.
    reuso = client.post("/auth/reset-password", json={"token": token, "new_password": "OtraClave123"})
    assert reuso.status_code == 400
    assert reuso.json()["code"] == "reset_token_used"


def test_reset_password_con_token_invalido_da_400(client):
    response = client.post("/auth/reset-password", json={"token": "no-existe", "new_password": "NuevaClave123"})
    assert response.status_code == 400
    assert response.json()["code"] == "invalid_reset_token"


def test_forgot_password_sin_smtp_no_devuelve_token_si_debug_false(client, demo_credentials):
    response = client.post("/auth/forgot-password", json={"email": demo_credentials["email"]})
    assert response.status_code == 200
    assert response.json()["reset_token"] is None
