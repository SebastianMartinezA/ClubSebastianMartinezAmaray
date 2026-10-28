"""Schemas Pydantic v2: request y response de toda la API."""

from datetime import date as date_type
from datetime import datetime, time

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator

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


class FirebaseSyncRequest(BaseModel):
    """Alta o sincronización del usuario local a partir de una sesión de Firebase Auth.

    El correo no viaja en el cuerpo: se toma del ID token ya validado, que es la única
    fuente confiable. Los nombres son obligatorios cuando el usuario todavía no existe
    en la base; si existe, se actualizan sólo los campos que vienen con valor.
    """

    first_name: str | None = Field(default=None, max_length=100)
    last_name: str | None = Field(default=None, max_length=100)
    birth_date: date_type | None = None

    @field_validator("first_name", "last_name")
    @classmethod
    def _strip_names(cls, value: str | None) -> str | None:
        return None if value is None else _strip_name(value)

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


class UserAdminOut(UserOut):
    """Usuario visto por el administrador: agrega el estado y el perfil de permisos."""

    is_active: bool
    is_admin: bool


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
# Consultas abiertas (sin token). Sólo lectura y sin datos sensibles.
# --------------------------------------------------------------------------- #
class PublicUserOut(BaseModel):
    """Socio visto desde afuera: sin contraseña, permisos ni fecha de nacimiento."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    first_name: str
    last_name: str
    created_at: datetime


class PublicVenueOut(VenueOut):
    """Sede con sus espacios ya anidados, para no encadenar llamadas."""

    spaces: list[SportSpaceOut] = []


class PublicSummary(BaseModel):
    """Conteos del club para una portada o un chequeo rápido."""

    users: int
    venues: int
    spaces: int
    active_reservations: int


# --------------------------------------------------------------------------- #
# Administración del catálogo (sedes y espacios). Requiere perfil de administrador.
# --------------------------------------------------------------------------- #
def _strip_text(value: str) -> str:
    value = value.strip()
    if not value:
        raise ValueError("no puede estar vacío")
    return value


class VenueCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120, examples=["Tigre"])
    address: str = Field(min_length=1, max_length=200, examples=["Av. Cazón 1200"])
    opening_time: time = Field(examples=["08:00"])
    closing_time: time = Field(examples=["22:00"])

    @field_validator("name", "address")
    @classmethod
    def _clean_text(cls, value: str) -> str:
        return _strip_text(value)

    @model_validator(mode="after")
    def _check_hours(self):
        if self.opening_time >= self.closing_time:
            raise ValueError("la hora de apertura debe ser anterior a la de cierre")
        return self


class VenueUpdate(BaseModel):
    """Actualización parcial: sólo se tocan los campos enviados."""

    name: str | None = Field(default=None, min_length=1, max_length=120)
    address: str | None = Field(default=None, min_length=1, max_length=200)
    opening_time: time | None = None
    closing_time: time | None = None
    is_active: bool | None = None

    @field_validator("name", "address")
    @classmethod
    def _clean_text(cls, value: str | None) -> str | None:
        return _strip_text(value) if value is not None else None


class VenueAdminOut(VenueOut):
    is_active: bool
    spaces_count: int


class SportSpaceCreate(BaseModel):
    venue_id: int = Field(ge=1)
    space_type: str = Field(min_length=1, max_length=60, examples=["Paddle"])
    number: int = Field(ge=1, le=999, examples=[3])

    @field_validator("space_type")
    @classmethod
    def _clean_type(cls, value: str) -> str:
        return _strip_text(value)


class SportSpaceUpdate(BaseModel):
    venue_id: int | None = Field(default=None, ge=1)
    space_type: str | None = Field(default=None, min_length=1, max_length=60)
    number: int | None = Field(default=None, ge=1, le=999)
    is_active: bool | None = None

    @field_validator("space_type")
    @classmethod
    def _clean_type(cls, value: str | None) -> str | None:
        return _strip_text(value) if value is not None else None


class SportSpaceAdminOut(SportSpaceOut):
    is_active: bool


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
