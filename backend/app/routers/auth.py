"""Endpoints de autenticación: registro, login, recuperación de contraseña y perfil propio."""

import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..errors import (
    ConflictError,
    NotFoundError,
    UnauthorizedError,
    ValidationError,
    documented_errors,
)
from ..models import PasswordResetToken, User
from ..schemas import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    MessageOut,
    ResetPasswordRequest,
    TokenResponse,
    UserLogin,
    UserOut,
    UserRegister,
)
from ..security import (
    create_access_token,
    generate_reset_token,
    get_current_user,
    hash_password,
    hash_reset_token,
    verify_password,
)
from ..services.notifications import send_password_reset_email

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["Autenticación"])
settings = get_settings()

# Hash descartable: iguala el tiempo de respuesta cuando el correo no existe (regla 12).
_DUMMY_HASH = hash_password("contrasena-de-relleno-para-timing")

_FORGOT_MESSAGE = (
    "Si el correo está registrado, te enviamos las instrucciones para restablecer la contraseña."
)


def _normalize_email(email: str) -> str:
    return email.strip().lower()


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    responses=documented_errors(400, 409),
    summary="Registrar un usuario",
)
def register(payload: UserRegister, db: Session = Depends(get_db)) -> TokenResponse:
    email = _normalize_email(payload.email)

    if db.execute(select(User).where(User.email == email)).scalar_one_or_none() is not None:
        raise ConflictError(
            "Ya existe un usuario registrado con ese correo.", code="email_already_registered"
        )

    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        first_name=payload.first_name,
        last_name=payload.last_name,
        birth_date=payload.birth_date,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        # Carrera entre dos registros con el mismo correo.
        db.rollback()
        raise ConflictError(
            "Ya existe un usuario registrado con ese correo.", code="email_already_registered"
        ) from None
    db.refresh(user)

    token, expires_in = create_access_token(user)
    return TokenResponse(access_token=token, expires_in=expires_in, user=UserOut.model_validate(user))


@router.post(
    "/login",
    response_model=TokenResponse,
    responses=documented_errors(400, 401),
    summary="Iniciar sesión",
)
def login(payload: UserLogin, db: Session = Depends(get_db)) -> TokenResponse:
    email = _normalize_email(payload.email)
    user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()

    # Regla 12: mismo 401 y mismo mensaje exista o no el correo.
    if user is None:
        verify_password(payload.password, _DUMMY_HASH)
        raise UnauthorizedError("Correo o contraseña incorrectos.", code="invalid_credentials")
    # Regla 12: mismo 401 y mismo mensaje exista o no el correo, y también para una cuenta
    # inactiva. Un usuario deshabilitado NO puede responder 403 `user_inactive`: eso revelaría
    # que la cuenta existe y que la contraseña era correcta. Es coherente con get_current_user,
    # que también trata al inactivo como 401.
    if not verify_password(payload.password, user.password_hash) or not user.is_active:
        raise UnauthorizedError("Correo o contraseña incorrectos.", code="invalid_credentials")

    token, expires_in = create_access_token(user)
    return TokenResponse(access_token=token, expires_in=expires_in, user=UserOut.model_validate(user))


@router.post(
    "/forgot-password",
    response_model=ForgotPasswordResponse,
    responses=documented_errors(400),
    summary="Pedir el token de recuperación de contraseña",
)
def forgot_password(payload: ForgotPasswordRequest, db: Session = Depends(get_db)) -> ForgotPasswordResponse:
    email = _normalize_email(payload.email)
    user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()

    # No se revela si el correo existe.
    if user is None:
        return ForgotPasswordResponse(message=_FORGOT_MESSAGE)

    token = generate_reset_token()
    expires_minutes = settings.password_reset_token_expire_minutes
    db.add(
        PasswordResetToken(
            user_id=user.id,
            token_hash=hash_reset_token(token),
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=expires_minutes),
        )
    )
    db.commit()

    sent = send_password_reset_email(email, token, expires_minutes)
    if not sent:
        # El token en claro nunca se escribe en los logs fuera de modo debug: cualquiera con
        # acceso a esos logs podría usarlo mientras siga vigente, y el hash de la base no
        # protege esa copia.
        if settings.debug:
            logger.info("Token de recuperación para %s: %s", email, token)
        else:
            logger.warning(
                "No se pudo enviar el correo de recuperación a %s (SMTP sin configurar o caído).",
                email,
            )

    # Sin SMTP configurado, el token sólo viaja en la respuesta con DEBUG=true (uso en pruebas).
    return ForgotPasswordResponse(
        message=_FORGOT_MESSAGE,
        reset_token=token if (settings.debug and not sent) else None,
    )


@router.post(
    "/reset-password",
    response_model=MessageOut,
    responses=documented_errors(400, 404),
    summary="Restablecer la contraseña",
)
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)) -> MessageOut:
    record = db.execute(
        select(PasswordResetToken).where(PasswordResetToken.token_hash == hash_reset_token(payload.token))
    ).scalar_one_or_none()

    if record is None:
        raise ValidationError("El token de recuperación es inválido.", code="invalid_reset_token")

    now = datetime.now(timezone.utc)
    expires_at = record.expires_at
    if expires_at.tzinfo is None:  # por si la columna vuelve naive desde la base
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if record.used_at is not None:
        raise ValidationError("El token ya fue usado.", code="reset_token_used")
    if expires_at < now:
        raise ValidationError("El token de recuperación expiró.", code="reset_token_expired")

    user = db.get(User, record.user_id)
    if user is None:
        raise NotFoundError("El usuario del token ya no existe.", code="user_not_found")

    user.password_hash = hash_password(payload.new_password)
    record.used_at = now
    db.commit()

    return MessageOut(
        detail="Contraseña actualizada. Ya podés iniciar sesión con la nueva.",
        code="password_updated",
    )


@router.get(
    "/me",
    response_model=UserOut,
    responses=documented_errors(401),
    summary="Usuario autenticado (alias de /users/me)",
)
def read_me(current_user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.model_validate(current_user)
