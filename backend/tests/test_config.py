"""Configuración: normalización de la URL de base de datos y valores por defecto."""

from app.config import Settings, get_settings


def test_database_url_postgres_se_normaliza_a_psycopg2():
    """Render entrega postgres:// y SQLAlchemy necesita el driver explícito."""
    assert Settings(database_url="postgres://u:p@host:5432/db").database_url == (
        "postgresql+psycopg2://u:p@host:5432/db"
    )
    assert Settings(database_url="postgresql://u:p@host:5432/db").database_url == (
        "postgresql+psycopg2://u:p@host:5432/db"
    )


def test_database_url_ya_normalizada_no_se_toca():
    url = "postgresql+psycopg2://u:p@host:5432/db"
    assert Settings(database_url=url).database_url == url


def test_defaults_seguros():
    # Los valores por defecto del código, sin importar el entorno de la suite
    # (conftest fuerza AUTH_PROVIDER=local para que los tests usen el JWT propio).
    assert Settings.model_fields["auth_provider"].default == "hybrid"
    assert Settings.model_fields["firebase_project_id"].default == "club-smartinez-amaray"
    settings = get_settings()
    # El token de recuperación solo viaja en la respuesta cuando DEBUG está activo.
    assert settings.password_reset_token_expire_minutes == 30


def test_cors_origins_se_parsea_como_lista():
    assert Settings(cors_origins="*").cors_origin_list == ["*"]
    assert Settings(cors_origins="https://a.com, https://b.com").cors_origin_list == [
        "https://a.com",
        "https://b.com",
    ]


def test_smtp_y_fcm_se_detectan_por_su_configuracion():
    assert Settings(smtp_host="", smtp_from="").smtp_configured is False
    assert Settings(smtp_host="smtp.x.com", smtp_from="a@x.com").smtp_configured is True
    assert Settings(fcm_service_account_json="").fcm_configured is False
    assert Settings(fcm_service_account_json='{"project_id": "x"}').fcm_configured is True
