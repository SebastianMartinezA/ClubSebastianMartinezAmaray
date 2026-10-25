"""Detección de reservas próximas y envío opcional de notificaciones push (FCM HTTP v1).

Sin credenciales configuradas (FCM_SERVICE_ACCOUNT_JSON) el envío no se intenta: se registra en el
log y no falla. Se puede correr como job puntual con:

    python -m app.services.notifications
"""

from __future__ import annotations

import json
import logging
import time as time_module
from datetime import datetime, timedelta

import requests
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import SessionLocal
from ..models import DeviceToken, NotificationLog, Reservation, ReservationStatus
from ..clock import now_local

logger = logging.getLogger(__name__)

DEFAULT_WINDOW_MINUTES = 60
_GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
_FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


def find_upcoming_reservations(
    db: Session, window_minutes: int = DEFAULT_WINDOW_MINUTES, now: datetime | None = None
) -> list[Reservation]:
    """Reservas activas que arrancan dentro de los próximos `window_minutes`.

    La ventana se compara como fecha + hora completa. Comparar sólo la fecha dejaría entrar
    cualquier reserva del día siguiente cuando la ventana cruza la medianoche: a las 23:30, un
    turno de mañana a las 20:00 está a más de 20 horas, no dentro de la hora que se busca.
    """
    now = now or now_local()
    limit = now + timedelta(minutes=window_minutes)
    candidates = (
        db.execute(
            select(Reservation)
            .where(
                Reservation.status == ReservationStatus.active,
                # Filtro grueso en SQL (sólo hoy y, si cruza la medianoche, mañana) y
                # comparación exacta en memoria sobre ese conjunto chico.
                Reservation.date >= now.date(),
                Reservation.date <= limit.date(),
            )
            .order_by(Reservation.date, Reservation.start_time)
        )
        .scalars()
        .all()
    )
    return [reservation for reservation in candidates if now < reservation.starts_at <= limit]


def _fcm_access_token(service_account: dict) -> str | None:
    """Pide un access token OAuth2 a Google firmando un JWT con la clave de la cuenta de servicio."""
    import jwt  # import perezoso: el envío real es opcional

    now = int(time_module.time())
    claims = {
        "iss": service_account["client_email"],
        "scope": _FCM_SCOPE,
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
        timeout=15,
    )
    response.raise_for_status()
    return response.json().get("access_token")


def send_push(token: str, title: str, body: str, data: dict | None = None) -> bool:
    """Envía un push por FCM HTTP v1. Devuelve False (sin excepción) si no está configurado."""
    settings = get_settings()
    if not settings.fcm_configured:
        logger.info("[push:simulado] token=%s… titulo=%r cuerpo=%r", token[:12], title, body)
        return False

    try:
        service_account = json.loads(settings.fcm_service_account_json)
        project_id = service_account["project_id"]
        access_token = _fcm_access_token(service_account)
        response = requests.post(
            f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send",
            headers={"Authorization": f"Bearer {access_token}"},
            json={
                "message": {
                    "token": token,
                    "notification": {"title": title, "body": body},
                    "data": {k: str(v) for k, v in (data or {}).items()},
                }
            },
            timeout=15,
        )
        if response.status_code >= 400:
            logger.warning("FCM rechazó el envío (%s): %s", response.status_code, response.text[:300])
            return False
        return True
    except Exception:  # el job no puede tumbar el proceso por un push fallido
        logger.exception("Falló el envío de push")
        return False


def notify_upcoming_reservations(db: Session, window_minutes: int = DEFAULT_WINDOW_MINUTES) -> dict:
    """Recorre las reservas próximas y notifica a los dispositivos del dueño de cada una.

    Cada par (reserva, dispositivo) se avisa una sola vez: el envío queda registrado en
    `notification_logs`, así volver a correr el job dentro de la misma ventana no repite el aviso.
    """
    upcoming = find_upcoming_reservations(db, window_minutes=window_minutes)
    sent = 0
    attempted = 0
    skipped = 0
    for reservation in upcoming:
        tokens = db.execute(
            select(DeviceToken).where(DeviceToken.user_id == reservation.user_id)
        ).scalars().all()
        for device in tokens:
            already_sent = db.execute(
                select(NotificationLog.id).where(
                    NotificationLog.reservation_id == reservation.id,
                    NotificationLog.device_token_id == device.id,
                )
            ).scalar_one_or_none()
            if already_sent is not None:
                skipped += 1
                continue
            attempted += 1
            if send_push(
                device.token,
                "Tenés una reserva próxima",
                f"{reservation.sport_space.name} el {reservation.date} "
                f"de {reservation.start_time.strftime('%H:%M')} a {reservation.end_time.strftime('%H:%M')}",
                data={"reservation_id": reservation.id},
            ):
                db.add(NotificationLog(reservation_id=reservation.id, device_token_id=device.id))
                db.commit()
                sent += 1
    summary = {"upcoming": len(upcoming), "attempted": attempted, "sent": sent, "skipped": skipped}
    logger.info("Job de notificaciones: %s", summary)
    return summary


_RESEND_ENDPOINT = "https://api.resend.com/emails"
_RESET_SUBJECT = "Recuperación de contraseña - ClubSebastianMartinezAmaray"


def _reset_body(token: str, expires_minutes: int) -> str:
    return (
        "Pediste restablecer tu contraseña.\n\n"
        f"Usá este token en POST /auth/reset-password (vence en {expires_minutes} minutos):\n\n"
        f"{token}\n\n"
        "Si no fuiste vos, ignorá este mensaje."
    )


def _send_reset_via_smtp(settings, email: str, body: str) -> bool:
    import smtplib
    from email.message import EmailMessage

    message = EmailMessage()
    message["Subject"] = _RESET_SUBJECT
    message["From"] = settings.mail_sender
    message["To"] = email
    message.set_content(body)
    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as server:
            if settings.smtp_use_tls:
                server.starttls()
            if settings.smtp_user:
                server.login(settings.smtp_user, settings.smtp_password)
            server.send_message(message)
        return True
    except Exception:
        logger.exception("No se pudo enviar el correo de recuperación a %s por SMTP", email)
        return False


def _send_reset_via_resend(settings, email: str, body: str) -> bool:
    """Manda el correo por la API HTTPS de Resend.

    Existe porque el plan gratuito de Render bloquea el tráfico saliente a los puertos SMTP
    25/465/587: con SMTP el correo nunca sale en producción, por más que las credenciales estén
    bien. La API va por HTTPS (443) y no tiene ese problema.
    """
    try:
        response = requests.post(
            _RESEND_ENDPOINT,
            json={
                "from": settings.mail_sender,
                "to": [email],
                "subject": _RESET_SUBJECT,
                "text": body,
            },
            headers={
                "Authorization": f"Bearer {settings.resend_api_key}",
                "Content-Type": "application/json",
            },
            timeout=15,
        )
    except requests.RequestException:
        logger.exception("No se pudo enviar el correo de recuperación a %s por Resend", email)
        return False
    if response.status_code >= 300:
        logger.warning(
            "Resend rechazó el envío a %s (%s): %s",
            email,
            response.status_code,
            response.text[:300],
        )
        return False
    return True


def send_password_reset_email(email: str, token: str, expires_minutes: int) -> bool:
    """Manda el correo de recuperación por el transporte configurado.

    El transporte lo decide `settings.mail_transport`: `resend` si hay `RESEND_API_KEY` (API HTTPS,
    la única opción que funciona en el plan gratuito de Render), `smtp` si hay `SMTP_HOST`, y `none`
    si no hay nada configurado (devuelve False y el token queda solo en el log).
    """
    settings = get_settings()
    transport = settings.mail_transport
    if transport == "none":
        return False

    body = _reset_body(token, expires_minutes)
    if transport == "resend":
        handled = _send_reset_via_resend(settings, email, body)
    else:
        handled = _send_reset_via_smtp(settings, email, body)
    if handled:
        logger.info("Correo de recuperación enviado a %s por %s", email, transport)
    return handled


def run_notifications_job() -> dict[str, int]:
    """Corre el job con su propia sesión de base: es el punto de entrada del scheduler interno.

    Abre y cierra la sesión acá porque el loop del scheduler vive fuera del ciclo request/response
    de FastAPI (ver `app/services/scheduler.py`).
    """
    with SessionLocal() as db:
        return notify_upcoming_reservations(db)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    print(run_notifications_job())


if __name__ == "__main__":
    main()
