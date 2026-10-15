"""Reloj de la aplicación.

Los horarios de las reservas son horas de pared de la sede, así que comparar contra la hora del
servidor rompe cuando el servidor corre en UTC (por ejemplo en Render): a las 20:00 de Argentina,
un servidor en UTC ya cree que son las 23:00 y rechaza como "pasada" una reserva de las 21:00.

Acá se centraliza la zona horaria configurable (TIMEZONE) y se devuelve siempre un datetime naive
en hora local, que es lo que comparan las reglas de negocio.
"""

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .config import get_settings

_FALLBACK = timezone(timedelta(hours=-3), "ART")


def local_tz():
    """Zona horaria configurada. Si el sistema no tiene los datos de zona, cae a UTC-3."""
    nombre = get_settings().timezone or "America/Argentina/Buenos_Aires"
    try:
        return ZoneInfo(nombre)
    except (ZoneInfoNotFoundError, ValueError):
        return _FALLBACK


def now_local() -> datetime:
    """Ahora, en hora local de la sede y sin tzinfo (para comparar con date/time naive)."""
    return datetime.now(local_tz()).replace(tzinfo=None)


def to_local(value: datetime) -> datetime:
    """Convierte un datetime con zona (por ejemplo un created_at en UTC) a hora local naive."""
    if value.tzinfo is None:
        return value
    return value.astimezone(local_tz()).replace(tzinfo=None)
