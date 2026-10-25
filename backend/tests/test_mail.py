"""Correo de recuperación: elección de transporte y envío por la API HTTPS.

Contexto: el plan gratuito de Render bloquea el tráfico saliente a los puertos SMTP 25/465/587, así
que en producción el correo sólo puede salir por HTTPS. Estos tests no tocan la red: el POST y el
SMTP se reemplazan por dobles.
"""

import smtplib

import pytest
import requests

from app.config import Settings, get_settings
from app.services import notifications


class _Respuesta:
    def __init__(self, status_code: int, text: str = "") -> None:
        self.status_code = status_code
        self.text = text


@pytest.fixture
def ajustes(monkeypatch):
    """Settings aislados por test: arranca sin transporte y sin remitente heredado."""
    settings = get_settings()
    monkeypatch.setattr(settings, "resend_api_key", "")
    monkeypatch.setattr(settings, "mail_from", "")
    monkeypatch.setattr(settings, "smtp_from", "no-reply@club.local")
    monkeypatch.setattr(settings, "smtp_host", "")
    monkeypatch.setattr(settings, "smtp_user", "")
    monkeypatch.setattr(settings, "smtp_password", "")
    return settings


def test_el_transporte_prioriza_https_sobre_smtp(ajustes):
    assert Settings(resend_api_key="", smtp_host="").mail_transport == "none"
    assert Settings(resend_api_key="re_x", smtp_host="").mail_transport == "resend"
    assert Settings(resend_api_key="re_x", smtp_host="smtp.x.com").mail_transport == "resend"
    assert Settings(resend_api_key="", smtp_host="smtp.x.com").mail_transport == "smtp"


def test_sin_transporte_no_se_envia_nada(ajustes, monkeypatch):
    def post_que_no_debe_llamarse(*args, **kwargs):  # pragma: no cover - no debería ejecutarse
        raise AssertionError("no se tiene que intentar ningún envío sin transporte configurado")

    monkeypatch.setattr(notifications.requests, "post", post_que_no_debe_llamarse)

    assert notifications.send_password_reset_email("alguien@example.com", "tok-123", 30) is False


def test_envio_por_resend_arma_el_pedido_correcto(ajustes, monkeypatch):
    capturado: dict = {}

    def post_falso(url, json=None, headers=None, timeout=None):
        capturado.update(url=url, json=json, headers=headers, timeout=timeout)
        return _Respuesta(200, '{"id":"abc"}')

    monkeypatch.setattr(ajustes, "resend_api_key", "re_clave_de_prueba")
    monkeypatch.setattr(ajustes, "mail_from", "onboarding@resend.dev")
    monkeypatch.setattr(notifications.requests, "post", post_falso)

    enviado = notifications.send_password_reset_email("sebas@example.com", "tok-abc", 30)

    assert enviado is True
    assert capturado["url"] == "https://api.resend.com/emails"
    assert capturado["headers"]["Authorization"] == "Bearer re_clave_de_prueba"
    assert capturado["json"]["from"] == "onboarding@resend.dev"
    assert capturado["json"]["to"] == ["sebas@example.com"]
    assert "tok-abc" in capturado["json"]["text"]
    assert "30 minutos" in capturado["json"]["text"]
    assert capturado["timeout"] == 15


def test_resend_que_rechaza_devuelve_false(ajustes, monkeypatch, caplog):
    monkeypatch.setattr(ajustes, "resend_api_key", "re_clave_de_prueba")
    monkeypatch.setattr(ajustes, "mail_from", "onboarding@resend.dev")
    monkeypatch.setattr(
        notifications.requests, "post", lambda *a, **k: _Respuesta(422, "domain is not verified")
    )

    assert notifications.send_password_reset_email("sebas@example.com", "tok-abc", 30) is False
    assert "domain is not verified" in caplog.text


def test_resend_sin_red_devuelve_false(ajustes, monkeypatch):
    monkeypatch.setattr(ajustes, "resend_api_key", "re_clave_de_prueba")
    monkeypatch.setattr(ajustes, "mail_from", "onboarding@resend.dev")

    def post_que_falla(*args, **kwargs):
        raise requests.ConnectionError("sin salida")

    monkeypatch.setattr(notifications.requests, "post", post_que_falla)

    assert notifications.send_password_reset_email("sebas@example.com", "tok-abc", 30) is False


def test_smtp_sigue_funcionando_en_local(ajustes, monkeypatch):
    monkeypatch.setattr(ajustes, "smtp_host", "smtp.local")
    monkeypatch.setattr(ajustes, "mail_from", "no-reply@club.local")
    enviados: list = []

    class SMTPFalso:
        def __init__(self, host, port, timeout=None):
            self.host = host

        def __enter__(self):
            return self

        def __exit__(self, *exc):
            return False

        def starttls(self):
            pass

        def login(self, user, password):
            pass

        def send_message(self, message):
            enviados.append(message)

    monkeypatch.setattr(smtplib, "SMTP", SMTPFalso)

    assert notifications.send_password_reset_email("sebas@example.com", "tok-smtp", 30) is True
    assert len(enviados) == 1
    assert enviados[0]["To"] == "sebas@example.com"
    assert "tok-smtp" in enviados[0].get_content()


def test_health_informa_el_transporte_de_correo(client):
    respuesta = client.get("/health").json()

    assert respuesta["mail_transport"] in {"none", "smtp", "resend"}
