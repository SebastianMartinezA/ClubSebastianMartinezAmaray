"""Alta de los usuarios de la base en Firebase Authentication.

Se usa una sola vez, para migrar: el hash bcrypt que ya está en `users.password_hash` se
importa tal cual (Firebase acepta BCRYPT), así cada socio conserva su contraseña y no tiene
que resetear nada. Los usuarios que ya existen en Firebase vuelven como error por correo
repetido, que es el resultado esperado al correrlo dos veces.
"""

from __future__ import annotations

import base64
import json
import logging
import time as time_module
import uuid

import requests

from ..config import get_settings

logger = logging.getLogger(__name__)

_GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
_IDENTITY_SCOPE = "https://www.googleapis.com/auth/identitytoolkit"

# Los hashes bcrypt empiezan con "$2"; cualquier otra cosa (por ejemplo el centinela
# "!firebase-auth" de los usuarios que ya viven sólo en Firebase) no se puede importar.
_BCRYPT_PREFIX = "$2"


def configured() -> bool:
    return bool(get_settings().fcm_service_account_json.strip())


def _service_account() -> dict:
    return json.loads(get_settings().fcm_service_account_json)


def _access_token(service_account: dict) -> str:
    """Access token OAuth2 con scope de Identity Toolkit, firmando un JWT con la cuenta."""
    import jwt  # import perezoso: sólo se usa al migrar

    now = int(time_module.time())
    claims = {
        "iss": service_account["client_email"],
        "scope": _IDENTITY_SCOPE,
        "aud": _GOOGLE_TOKEN_URL,
        "iat": now,
        "exp": now + 3600,
    }
    assertion = jwt.encode(claims, service_account["private_key"], algorithm="RS256")
    response = requests.post(
        _GOOGLE_TOKEN_URL,
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        },
        timeout=20,
    )
    response.raise_for_status()
    return response.json()["access_token"]


def import_users(users: list[dict]) -> dict:
    """Crea los usuarios en Firebase Auth conservando su hash bcrypt.

    `users` es una lista de `{"email": str, "password_hash": str}`. Devuelve un resumen con
    cuántos se intentaron, cuántos quedaron creados y los errores por correo.
    """
    service_account = _service_account()
    project_id = service_account["project_id"]
    access_token = _access_token(service_account)

    payload = {
        "hashAlgorithm": "BCRYPT",
        "users": [
            {
                # batchCreate exige un localId (el UID): si no se manda, rechaza la carga
                # entera con "localId is missing".
                "localId": uuid.uuid4().hex,
                "email": user["email"],
                "passwordHash": base64.b64encode(user["password_hash"].encode("utf-8")).decode("ascii"),
                "emailVerified": True,
            }
            for user in users
        ],
    }
    response = requests.post(
        f"https://identitytoolkit.googleapis.com/v1/projects/{project_id}/accounts:batchCreate",
        headers={"Authorization": f"Bearer {access_token}"},
        json=payload,
        timeout=60,
    )
    if response.status_code >= 400:
        logger.warning("Firebase rechazó la importación (%s): %s", response.status_code, response.text[:400])
        return {
            "attempted": len(users),
            "created": 0,
            "errors": [{"email": None, "message": response.text[:300]}],
        }

    body = response.json()
    errors = [
        {
            "email": users[item["index"]]["email"] if item.get("index") is not None and item["index"] < len(users) else None,
            "message": item.get("message", ""),
        }
        for item in body.get("error", []) or []
    ]
    created = len(users) - len(errors)
    logger.info("Importación a Firebase: %s de %s usuarios", created, len(users))
    return {"attempted": len(users), "created": created, "errors": errors}
