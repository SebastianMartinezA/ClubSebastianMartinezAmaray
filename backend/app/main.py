"""Aplicación FastAPI del backend ClubSebastianMartinezAmaray.

Swagger/OpenAPI queda disponible en /docs y el esquema en /openapi.json.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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


@app.get("/", tags=["Estado"], summary="Información básica del servicio")
def root() -> dict[str, str]:
    return {
        "app": settings.app_name,
        "version": settings.app_version,
        "docs": "/docs",
        "openapi": "/openapi.json",
    }


@app.get("/health", tags=["Estado"], summary="Healthcheck")
def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.environment}
