"""Autenticación con Firebase Auth: modo híbrido del backend.

La app se autentica contra Firebase y manda el ID token en `Authorization`. El backend lo
valida contra el JWKS de Google y busca (o crea) la fila local por correo. El JWT propio
sigue sirviendo para el backoffice y las pruebas, y eso es lo que se verifica acá.

No se llama a Google: la validación del ID token se reemplaza por una función de prueba.
"""

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import security
from app.models import User
from app.routers import auth as auth_router

FIREBASE_EMAIL = "nuevo.socio@example.com"
FIREBASE_TOKEN = "id-token-de-prueba"


def _claims() -> dict:
    return {"email": FIREBASE_EMAIL, "sub": "uid-firebase-123", "email_verified": True}


@pytest.fixture
def firebase_headers(monkeypatch) -> dict:
    """Hace que el backend trate `FIREBASE_TOKEN` como un ID token válido de Firebase."""

    def _verify(token: str) -> dict:
        from app.errors import UnauthorizedError

        if token != FIREBASE_TOKEN:
            raise UnauthorizedError("ID token de Firebase inválido.", code="invalid_token")
        return _claims()

    # El router y la dependencia importan la función por separado: se parchean las dos.
    monkeypatch.setattr(auth_router, "verify_firebase_id_token", _verify)
    monkeypatch.setattr(security, "verify_firebase_id_token", _verify)
    # El token de prueba no es un JWT real, así que se fuerza la detección de RS256.
    monkeypatch.setattr(security, "_is_firebase_id_token", lambda token: token == FIREBASE_TOKEN)
    # La suite fija AUTH_PROVIDER=local en conftest; acá se prueba el modo de producción.
    monkeypatch.setattr(security.settings, "auth_provider", "hybrid")
    return {"Authorization": f"Bearer {FIREBASE_TOKEN}"}


def test_sync_crea_el_usuario_local(client, db: Session, firebase_headers: dict) -> None:
    response = client.post(
        "/auth/firebase-sync",
        json={"first_name": "Nuevo", "last_name": "Socio"},
        headers=firebase_headers,
    )
    assert response.status_code == 200, response.text
    assert response.json()["email"] == FIREBASE_EMAIL
    assert response.json()["first_name"] == "Nuevo"

    user = db.execute(select(User).where(User.email == FIREBASE_EMAIL)).scalar_one()
    # Sin contraseña local: la credencial vive en Firebase.
    assert user.password_hash == "!firebase-auth"


def test_sync_es_idempotente_y_actualiza_los_nombres(client, firebase_headers: dict) -> None:
    first = client.post(
        "/auth/firebase-sync",
        json={"first_name": "Nuevo", "last_name": "Socio"},
        headers=firebase_headers,
    )
    assert first.status_code == 200, first.text

    second = client.post(
        "/auth/firebase-sync", json={"first_name": "Corregido"}, headers=firebase_headers
    )
    assert second.status_code == 200, second.text
    assert second.json()["id"] == first.json()["id"]
    assert second.json()["first_name"] == "Corregido"
    assert second.json()["last_name"] == "Socio"


def test_sync_sin_nombres_da_400(client, firebase_headers: dict) -> None:
    response = client.post("/auth/firebase-sync", json={}, headers=firebase_headers)
    assert response.status_code == 400, response.text
    assert "names_required" in response.text


def test_sync_sin_token_da_401(client) -> None:
    response = client.post("/auth/firebase-sync", json={"first_name": "A", "last_name": "B"})
    assert response.status_code == 401, response.text


def test_sync_con_token_invalido_da_401(client, firebase_headers: dict) -> None:
    response = client.post(
        "/auth/firebase-sync",
        json={"first_name": "A", "last_name": "B"},
        headers={"Authorization": "Bearer otro-token"},
    )
    assert response.status_code == 401, response.text


def test_el_id_token_de_firebase_abre_los_endpoints_protegidos(
    client, firebase_headers: dict
) -> None:
    client.post(
        "/auth/firebase-sync",
        json={"first_name": "Nuevo", "last_name": "Socio"},
        headers=firebase_headers,
    )
    me = client.get("/users/me", headers=firebase_headers)
    assert me.status_code == 200, me.text
    assert me.json()["email"] == FIREBASE_EMAIL

    reservas = client.get("/reservations", headers=firebase_headers)
    assert reservas.status_code == 200, reservas.text


def test_los_dos_esquemas_conviven(client, firebase_headers: dict, auth_headers: dict) -> None:
    """El JWT propio sigue funcionando en el mismo proceso que acepta ID tokens."""
    client.post(
        "/auth/firebase-sync",
        json={"first_name": "Nuevo", "last_name": "Socio"},
        headers=firebase_headers,
    )
    local = client.get("/users/me", headers=auth_headers)
    assert local.status_code == 200, local.text
    assert local.json()["email"] != FIREBASE_EMAIL


def test_un_usuario_de_firebase_no_entra_por_el_login_local(client, firebase_headers: dict) -> None:
    client.post(
        "/auth/firebase-sync",
        json={"first_name": "Nuevo", "last_name": "Socio"},
        headers=firebase_headers,
    )
    response = client.post(
        "/auth/login", json={"email": FIREBASE_EMAIL, "password": "cualquier-clave-123"}
    )
    assert response.status_code == 401, response.text
