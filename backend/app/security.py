"""Hash de contraseñas (bcrypt), emisión/validación de JWT y dependencia get_current_user.

Modo alternativo (desactivado por defecto): si AUTH_PROVIDER=firebase se validan ID tokens de
Firebase Auth contra el endpoint JWKS de Google, sin SDK.
"""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .config import get_settings
from .database import get_db
from .errors import ForbiddenError, UnauthorizedError
from .models import User

settings = get_settings()

# auto_error=False para poder responder 401 (y no el 403 por defecto de HTTPBearer) cuando falta el header.
bearer_scheme = HTTPBearer(auto_error=False)

_BCRYPT_MAX_BYTES = 72


def _to_bcrypt_bytes(password: str) -> bytes:
    # bcrypt trunca/falla por encima de 72 bytes: normalizamos para no romper con UTF-8 largo.
    return password.encode("utf-8")[:_BCRYPT_MAX_BYTES]


def hash_password(password: str) -> str:
    return bcrypt.hashpw(_to_bcrypt_bytes(password), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(_to_bcrypt_bytes(password), password_hash.encode("utf-8"))
    except (ValueError, TypeError):
        return False


def create_access_token(user: User, expires_minutes: int | None = None) -> tuple[str, int]:
    minutes = expires_minutes if expires_minutes is not None else settings.access_token_expire_minutes
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user.id),
        "email": user.email,
        "type": "access",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=minutes)).timestamp()),
    }
    token = jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    return token, minutes * 60


def decode_access_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except jwt.ExpiredSignatureError as exc:
        raise UnauthorizedError("El token expiró. Volvé a iniciar sesión.", code="token_expired") from exc
    except jwt.PyJWTError as exc:
        raise UnauthorizedError("Token inválido.", code="invalid_token") from exc
    if payload.get("type") != "access":
        raise UnauthorizedError("Token inválido.", code="invalid_token")
    return payload


# --------------------------------------------------------------------------- #
# Modo Firebase (opcional, desactivado por defecto)
# --------------------------------------------------------------------------- #
_firebase_jwk_client = None


def _get_firebase_jwk_client():
    global _firebase_jwk_client
    if _firebase_jwk_client is None:
        from jwt import PyJWKClient  # import perezoso: solo se usa en modo firebase

        _firebase_jwk_client = PyJWKClient(settings.firebase_jwks_endpoint)
    return _firebase_jwk_client


def verify_firebase_id_token(token: str) -> dict:
    """Valida un ID token de Firebase Auth contra las claves públicas de Google (JWKS)."""
    project_id = settings.firebase_project_id
    if not project_id:
        raise UnauthorizedError(
            "AUTH_PROVIDER=firebase pero falta FIREBASE_PROJECT_ID.", code="auth_misconfigured"
        )
    try:
        signing_key = _get_firebase_jwk_client().get_signing_key_from_jwt(token)
        return jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=project_id,
            issuer=f"https://securetoken.google.com/{project_id}",
        )
    except jwt.PyJWTError as exc:
        raise UnauthorizedError("ID token de Firebase inválido.", code="invalid_token") from exc


# --------------------------------------------------------------------------- #
# Dependencias
# --------------------------------------------------------------------------- #
def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Identifica al usuario autenticado (requerido en las operaciones de usuarios y reservas)."""
    if credentials is None or not credentials.credentials:
        raise UnauthorizedError("Falta el token de autenticación.", code="missing_token")
    token = credentials.credentials

    if settings.auth_provider.lower() == "firebase":
        payload = verify_firebase_id_token(token)
        email = (payload.get("email") or "").lower()
        user = db.query(User).filter(User.email == email).one_or_none()
    else:
        payload = decode_access_token(token)
        try:
            user_id = int(payload["sub"])
        except (KeyError, TypeError, ValueError) as exc:
            raise UnauthorizedError("Token inválido.", code="invalid_token") from exc
        user = db.get(User, user_id)

    if user is None or not user.is_active:
        raise UnauthorizedError("Usuario no encontrado o inactivo.", code="invalid_token")
    return user


def require_admin(user: User = Depends(get_current_user)) -> User:
    """Exige perfil de administrador (campo `is_admin` del usuario).

    Se resuelve en cada request contra la base, no contra el token: quitarle el permiso a un
    usuario tiene efecto inmediato, sin esperar a que venza su JWT.
    """
    if not user.is_admin:
        raise ForbiddenError(
            "Se requiere perfil de administrador para gestionar sedes y espacios.",
            code="admin_required",
        )
    return user


# --------------------------------------------------------------------------- #
# Tokens de recuperación de contraseña
# --------------------------------------------------------------------------- #
def generate_reset_token() -> str:
    return secrets.token_urlsafe(32)


def hash_reset_token(token: str) -> str:
    # SHA-256 alcanza: el token ya es aleatorio de 256 bits, no hace falta un KDF lento.
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
