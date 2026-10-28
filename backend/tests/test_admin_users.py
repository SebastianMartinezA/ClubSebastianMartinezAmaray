"""Listado de usuarios y migración a Firebase Auth (endpoints de administración)."""

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import User
from app.routers import admin as admin_router
from app.services import firebase_admin
from app.seed import DEMO_EMAIL


def test_listar_usuarios_requiere_admin(client, auth_headers: dict) -> None:
    response = client.get("/admin/users", headers=auth_headers)
    assert response.status_code == 403, response.text


def test_listar_usuarios(client, admin_headers: dict) -> None:
    response = client.get("/admin/users", headers=admin_headers)
    assert response.status_code == 200, response.text
    emails = [u["email"] for u in response.json()]
    assert DEMO_EMAIL in emails
    # Nunca se expone el hash de la contraseña.
    assert "password_hash" not in response.text


def test_migrar_sin_cuenta_de_servicio_da_400(client, admin_headers: dict, monkeypatch) -> None:
    monkeypatch.setattr(admin_router.firebase_admin, "configured", lambda: False)
    response = client.post("/admin/firebase/migrate", headers=admin_headers)
    assert response.status_code == 400, response.text
    assert "firebase_not_configured" in response.text


def test_migrar_importa_solo_hashes_bcrypt(client, admin_headers: dict, db: Session, monkeypatch) -> None:
    # Un usuario que ya vive sólo en Firebase: su hash no es bcrypt y no se importa.
    db.add(
        User(
            email="solo.firebase@example.com",
            password_hash="!firebase-auth",
            first_name="Solo",
            last_name="Firebase",
        )
    )
    db.commit()

    capturado: dict = {}

    def _fake_import(users: list[dict]) -> dict:
        capturado["emails"] = [u["email"] for u in users]
        return {"attempted": len(users), "created": len(users), "errors": []}

    monkeypatch.setattr(admin_router.firebase_admin, "configured", lambda: True)
    monkeypatch.setattr(admin_router.firebase_admin, "import_users", _fake_import)

    response = client.post("/admin/firebase/migrate", headers=admin_headers)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["created"] == len(capturado["emails"])
    assert "solo.firebase@example.com" not in capturado["emails"]
    assert DEMO_EMAIL in capturado["emails"]
    assert body["omitted"] >= 1


def test_import_users_arma_el_payload_de_firebase(monkeypatch) -> None:
    """El payload de batchCreate lleva el hash en base64 y el algoritmo BCRYPT."""
    enviado: dict = {}

    class _Response:
        status_code = 200

        @staticmethod
        def json() -> dict:
            return {"kind": "identitytoolkit#UploadAccountResponse"}

    def _fake_post(url: str, headers=None, json=None, timeout=None):  # noqa: A002
        if url.endswith(":batchCreate"):
            enviado.update(json or {})
            return _Response()
        raise AssertionError(f"URL inesperada: {url}")

    monkeypatch.setattr(firebase_admin, "_service_account", lambda: {"project_id": "p", "client_email": "e", "private_key": "k"})
    monkeypatch.setattr(firebase_admin, "_access_token", lambda sa: "token")
    monkeypatch.setattr(firebase_admin.requests, "post", _fake_post)

    result = firebase_admin.import_users([{"email": "a@b.com", "password_hash": "$2b$12$abc"}])
    assert result["created"] == 1
    assert enviado["hashAlgorithm"] == "BCRYPT"
    import base64

    assert base64.b64decode(enviado["users"][0]["passwordHash"]).decode() == "$2b$12$abc"
