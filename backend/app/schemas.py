"""Schemas Pydantic v2: request y response de toda la API."""

from datetime import date as date_type
from datetime import datetime, time

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from .models import ReservationStatus

# Límites de negocio para la fecha de nacimiento (regla de perfil).
_BIRTH_DATE_MIN = date_type(1900, 1, 1)


def _strip_name(value: str | None) -> str | None:
    """Recorta espacios y rechaza un nombre que quede vacío.

    Misma validación para el registro y para la edición del perfil: un nombre no puede ser
    sólo espacios (ni en el alta ni al editar).
    """
    if value is None:
        return None
    value = value.strip()
    if not value:
        raise ValueError("no puede estar vacío")
    return value


def _validate_birth_date(value: date_type | None) -> date_type | None:
    """Rechaza fechas de nacimiento futuras o absurdamente viejas (< 1900)."""
    if value is None:
        return None
    if value > date_type.today():
        raise ValueError("la fecha de nacimiento no puede ser futura")
    if value < _BIRTH_DATE_MIN:
        raise ValueError("la fecha de nacimiento no puede ser anterior a 1900")
    return value


# --------------------------------------------------------------------------- #
# Usuarios / autenticación
# --------------------------------------------------------------------------- #
class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=72, description="Mínimo 8 caracteres")
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    birth_date: date_type | None = None

    @field_validator("first_name", "last_name")
    @classmethod
    def _strip_names(cls, value: str) -> str:
        return _strip_name(value)

    @field_validator("birth_date")
    @classmethod
    def _check_birth_date(cls, value: date_type | None) -> date_type | None:
        return _validate_birth_date(value)


class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=72)


class UserUpdate(BaseModel):
    """El correo se acepta solo para poder rechazarlo con 400 si intenta cambiarse."""

    first_name: str | None = Field(default=None, min_length=1, max_length=100)
    last_name: str | None = Field(default=None, min_length=1, max_length=100)
    birth_date: date_type | None = None
    email: EmailStr | None = None

    @field_validator("first_name", "last_name")
    @classmethod
    def _strip_names(cls, value: str | None) -> str | None:
        # Misma validación que en el registro: un nombre no puede quedar vacío tras recortar.
        return _strip_name(value)

    @field_validator("birth_date")
    @classmethod
    def _check_birth_date(cls, value: date_type | None) -> date_type | None:
        return _validate_birth_date(value)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    first_name: str
    last_name: str
    birth_date: date_type | None = None
    created_at: datetime


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    message: str
    # Solo se completa con DEBUG=true y sin SMTP configurado (entorno de prueba/defensa).
    reset_token: str | None = None


class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=8, max_length=512)
    new_password: str = Field(min_length=8, max_length=72)


class MessageOut(BaseModel):
    detail: str
    code: str


# --------------------------------------------------------------------------- #
# Sedes y espacios deportivos
# --------------------------------------------------------------------------- #
class VenueOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    address: str
    opening_time: time
    closing_time: time


class SportSpaceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    venue_id: int
    venue_name: str
    name: str
    space_type: str
    number: int


# --------------------------------------------------------------------------- #
# Reservas
# --------------------------------------------------------------------------- #
class ReservationCreate(BaseModel):
    sport_space_id: int
    date: date_type
    start_time: time
    end_time: time


class ReservationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sport_space_id: int
    space_name: str
    venue_id: int
    venue_name: str
    date: date_type
    start_time: time
    end_time: time
    status: ReservationStatus
    created_at: datetime
    cancelled_at: datetime | None = None


# --------------------------------------------------------------------------- #
# Disponibilidad
# --------------------------------------------------------------------------- #
class AvailabilitySlot(BaseModel):
    start_time: time
    end_time: time
    available: bool


class SpaceAvailability(BaseModel):
    space: SportSpaceOut
    slots: list[AvailabilitySlot]


class VenueAvailability(BaseModel):
    venue: VenueOut
    date: date_type
    spaces: list[SpaceAvailability]


# --------------------------------------------------------------------------- #
# Dispositivos
# --------------------------------------------------------------------------- #
class DeviceTokenCreate(BaseModel):
    token: str = Field(min_length=8, max_length=512)
    platform: str = Field(default="android", max_length=20)


class DeviceTokenOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    token: str
    platform: str
    created_at: datetime
