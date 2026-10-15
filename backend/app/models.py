"""Modelos ORM. Entidades del DER: usuarios, tokens de recuperación, dispositivos,
sedes, espacios deportivos y reservas."""

import enum
from datetime import date as date_type
from datetime import datetime, time, timezone

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Integer,
    String,
    Time,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ReservationStatus(str, enum.Enum):
    """Una reserva activa ocupa el horario; una cancelada lo libera (no se borra)."""

    active = "active"
    cancelled = "cancelled"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    birth_date: Mapped[date_type | None] = mapped_column(Date, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False
    )

    reservations: Mapped[list["Reservation"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    device_tokens: Mapped[list["DeviceToken"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    reset_tokens: Mapped[list["PasswordResetToken"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class PasswordResetToken(Base):
    """Token de un solo uso para recuperar la contraseña. Se guarda el hash, nunca el token."""

    __tablename__ = "password_reset_tokens"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    token_hash: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    user: Mapped["User"] = relationship(back_populates="reset_tokens")


class DeviceToken(Base):
    """Token de dispositivo registrado para notificaciones push (FCM)."""

    __tablename__ = "device_tokens"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    token: Mapped[str] = mapped_column(String(512), unique=True, index=True, nullable=False)
    platform: Mapped[str] = mapped_column(String(20), default="android", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    user: Mapped["User"] = relationship(back_populates="device_tokens")


class Venue(Base):
    """Sede deportiva: nombre, dirección y horario de funcionamiento."""

    __tablename__ = "venues"
    __table_args__ = (
        CheckConstraint("opening_time < closing_time", name="ck_venues_opening_before_closing"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(120), unique=True, nullable=False)
    address: Mapped[str] = mapped_column(String(200), nullable=False)
    opening_time: Mapped[time] = mapped_column(Time, nullable=False)
    closing_time: Mapped[time] = mapped_column(Time, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    spaces: Mapped[list["SportSpace"]] = relationship(
        back_populates="venue", cascade="all, delete-orphan", order_by="SportSpace.id"
    )


class SportSpace(Base):
    """Espacio deportivo de una sede. El nombre se compone con sede, dirección, tipo y número."""

    __tablename__ = "sport_spaces"
    __table_args__ = (
        UniqueConstraint("venue_id", "space_type", "number", name="uq_space_per_venue_type_number"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    venue_id: Mapped[int] = mapped_column(ForeignKey("venues.id", ondelete="CASCADE"), index=True, nullable=False)
    space_type: Mapped[str] = mapped_column(String(60), index=True, nullable=False)
    number: Mapped[int] = mapped_column(Integer, nullable=False)
    name: Mapped[str] = mapped_column(String(200), unique=True, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    venue: Mapped["Venue"] = relationship(back_populates="spaces")
    reservations: Mapped[list["Reservation"]] = relationship(
        back_populates="sport_space", cascade="all, delete-orphan"
    )


class Reservation(Base):
    """Reserva de un espacio deportivo para una fecha y un rango horario."""

    __tablename__ = "reservations"
    __table_args__ = (
        CheckConstraint("start_time < end_time", name="ck_reservations_start_before_end"),
        # Índice pensado para la búsqueda de solapamiento del servicio de reservas.
        # (SQLAlchemy no tiene un helper portable para índices parciales con condicional,
        # por eso se declara con DDL explícito en create_all.)
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    sport_space_id: Mapped[int] = mapped_column(
        ForeignKey("sport_spaces.id", ondelete="CASCADE"), index=True, nullable=False
    )
    date: Mapped[date_type] = mapped_column(Date, index=True, nullable=False)
    start_time: Mapped[time] = mapped_column(Time, nullable=False)
    end_time: Mapped[time] = mapped_column(Time, nullable=False)
    status: Mapped[ReservationStatus] = mapped_column(
        SAEnum(ReservationStatus, name="reservation_status", values_callable=lambda e: [m.value for m in e]),
        default=ReservationStatus.active,
        index=True,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped["User"] = relationship(back_populates="reservations")
    sport_space: Mapped["SportSpace"] = relationship(back_populates="reservations")

    @property
    def starts_at(self) -> datetime:
        return datetime.combine(self.date, self.start_time)

    @property
    def ends_at(self) -> datetime:
        return datetime.combine(self.date, self.end_time)


__all__ = [
    "ReservationStatus",
    "User",
    "PasswordResetToken",
    "DeviceToken",
    "Venue",
    "SportSpace",
    "Reservation",
    "utcnow",
]
