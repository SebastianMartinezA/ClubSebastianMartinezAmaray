"""Aplicación FastAPI del backend ClubSebastianMartinezAmaray.

Swagger/OpenAPI queda disponible en /docs y el esquema en /openapi.json.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi
from sqlalchemy import text

from .config import get_settings
from .database import Base, engine
from .errors import register_exception_handlers
from .routers import auth, devices, reservations, spaces, users, venues
from .seed import seed_demo_data

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger(__name__)
settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Migraciones simples: el esquema se crea al arrancar (equivalente a Alembic para este TP).
    if settings.auto_create_tables:
        Base.metadata.create_all(bind=engine)
        logger.info("Esquema verificado/creado.")
    if settings.seed_on_startup:
        logger.info("Seed de datos de ejemplo: %s", seed_demo_data())
    yield


app = FastAPI(
    title=settings.app_name,
    description=(
        "API REST para la gestión de espacios deportivos: reservas, sedes, espacios deportivos "
        "y perfiles de usuario. Autenticación con JWT propio (bcrypt) y, opcionalmente, "
        "ID tokens de Firebase Auth."
    ),
    version=settings.app_version,
    lifespan=lifespan,
    openapi_tags=[
        {"name": "Estado", "description": "Chequeos de disponibilidad del servicio."},
        {"name": "Autenticación", "description": "Registro, login y recuperación de contraseña."},
        {"name": "Usuarios", "description": "Perfil del usuario autenticado."},
        {"name": "Sedes", "description": "Sedes, sus espacios y disponibilidad por fecha."},
        {"name": "Espacios deportivos", "description": "Listado y filtrado de espacios."},
        {"name": "Reservas", "description": "Alta, listado, historial y cancelación de reservas."},
        {"name": "Dispositivos", "description": "Tokens de notificaciones push."},
    ],
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=settings.cors_origin_list != ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

register_exception_handlers(app)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(venues.router)
app.include_router(spaces.router)
app.include_router(reservations.router)
app.include_router(devices.router)


def _openapi_with_real_error_contract() -> dict:
    """Esquema OpenAPI con el contrato de errores que la API devuelve de verdad.

    FastAPI documenta un 422 por cada parámetro validable de la firma, pero esta API nunca
    responde 422: el handler de RequestValidationError lo convierte en 400 con el mismo cuerpo
    uniforme que el resto de los errores. Acá se reemplaza ese 422 por el 400 real, para que el
    esquema no prometa una respuesta que no ocurre. Los 400/401/403/404/409 que produce cada
    endpoint se declaran en el propio endpoint con `documented_errors()`.
    """
    if app.openapi_schema:
        return app.openapi_schema
    schema = get_openapi(
        title=app.title, version=app.version, description=app.description, routes=app.routes
    )
    for operations in schema.get("paths", {}).values():
        for operation in operations.values():
            if not isinstance(operation, dict):
                continue
            responses = operation.get("responses")
            if not responses or "422" not in responses:
                continue
            responses.pop("422")
            responses.setdefault(
                "400",
                {
                    "description": (
                        "Datos inválidos: la petición no cumple el formato o una regla de negocio."
                    ),
                    "content": {
                        "application/json": {"schema": {"$ref": "#/components/schemas/ErrorOut"}}
                    },
                },
            )
    app.openapi_schema = schema
    return schema


app.openapi = _openapi_with_real_error_contract  # type: ignore[method-assign]


@app.get("/", tags=["Estado"], summary="Información básica del servicio")
def root() -> dict[str, str]:
    return {
        "app": settings.app_name,
        "version": settings.app_version,
        "docs": "/docs",
        "openapi": "/openapi.json",
    }


@app.get("/health", tags=["Estado"], summary="Healthcheck (servicio y base de datos)")
def health(response: Response) -> dict[str, str]:
    """Verifica el servicio y la conexión con la base.

    Sirve para despertar el despliegue antes de una demo: en el plan gratuito de Render, la
    primera petición después de 15 minutos de inactividad tarda cerca de un minuto, y devolver
    "ok" sin tocar la base no probaría que el servicio quedó realmente operativo.
    """
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception:
        logger.exception("Healthcheck: la base de datos no respondió")
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {
            "status": "degraded",
            "database": "unreachable",
            "environment": settings.environment,
        }
    return {"status": "ok", "database": "ok", "environment": settings.environment}
