"""Configuración del backend. Todo por variables de entorno (ver .env.example)."""

from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore", case_sensitive=False
    )

    app_name: str = "ClubSebastianMartinezAmaray API"
    app_version: str = "2.0.0"
    environment: str = "development"
    debug: bool = False

    # Base de datos relacional (PostgreSQL en producción, Render en la nube)
    database_url: str = "postgresql+psycopg2://postgres:postgres@localhost:5432/club"
    auto_create_tables: bool = True
    seed_on_startup: bool = False

    # Zona horaria de las sedes: define qué es "ahora" al validar reservas futuras y disponibilidad.
    # Sin esto, un servidor en UTC (Render) rechaza reservas de horas que en Argentina son futuras.
    timezone: str = "America/Argentina/Buenos_Aires"

    # JWT propio
    jwt_secret_key: str = "cambiar-esta-clave-en-produccion"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    password_reset_token_expire_minutes: int = 30

    # Autenticación: "local" (JWT propio, por defecto) o "firebase" (ID tokens de Firebase Auth)
    auth_provider: str = "local"
    firebase_project_id: str = ""
    firebase_jwks_url: str = ""

    # SMTP para el correo de recuperación de contraseña.
    # Si está vacío, el token se registra en el log (y en la respuesta solo con DEBUG=true).
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = "no-reply@club.local"
    smtp_use_tls: bool = True

    # Firebase Cloud Messaging (HTTP v1). Si está vacío, el job solo loguea.
    fcm_service_account_json: str = ""

    # Job de avisos push: corre solo, adentro del proceso de la API (app/services/scheduler.py).
    # Se puede apagar para correrlo a mano con `python -m app.services.notifications`.
    notifications_scheduler_enabled: bool = True
    notifications_scheduler_interval_seconds: int = 60

    # CORS: lista separada por comas, o "*"
    cors_origins: str = "*"

    @field_validator("database_url")
    @classmethod
    def _normalize_database_url(cls, value: str) -> str:
        # Render entrega la URL como postgres://; SQLAlchemy necesita el driver explícito.
        for prefijo in ("postgres://", "postgresql://"):
            if value.startswith(prefijo):
                return "postgresql+psycopg2://" + value[len(prefijo) :]
        return value

    @property
    def cors_origin_list(self) -> list[str]:
        raw = (self.cors_origins or "").strip()
        if not raw or raw == "*":
            return ["*"]
        return [origin.strip() for origin in raw.split(",") if origin.strip()]

    @property
    def smtp_configured(self) -> bool:
        return bool(self.smtp_host and self.smtp_from)

    @property
    def fcm_configured(self) -> bool:
        return bool(self.fcm_service_account_json.strip())

    @property
    def firebase_jwks_endpoint(self) -> str:
        if self.firebase_jwks_url:
            return self.firebase_jwks_url
        return "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"


@lru_cache
def get_settings() -> Settings:
    return Settings()
