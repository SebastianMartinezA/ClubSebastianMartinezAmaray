"""Excepciones de dominio y handlers globales.

Todos los errores salen con el mismo formato: {"detail": "...", "code": "..."}.
"""

import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger(__name__)


class DomainError(Exception):
    """Error de negocio. status_code y code viajan tal cual al cliente."""

    status_code: int = 400
    code: str = "domain_error"

    def __init__(self, detail: str, *, code: str | None = None, status_code: int | None = None):
        super().__init__(detail)
        self.detail = detail
        if code is not None:
            self.code = code
        if status_code is not None:
            self.status_code = status_code


class ValidationError(DomainError):
    status_code = 400
    code = "validation_error"


class UnauthorizedError(DomainError):
    status_code = 401
    code = "unauthorized"


class ForbiddenError(DomainError):
    status_code = 403
    code = "forbidden"


class NotFoundError(DomainError):
    status_code = 404
    code = "not_found"


class ConflictError(DomainError):
    status_code = 409
    code = "conflict"


_STATUS_CODE_NAMES = {
    400: "validation_error",
    401: "unauthorized",
    403: "forbidden",
    404: "not_found",
    405: "method_not_allowed",
    409: "conflict",
    422: "validation_error",
    429: "too_many_requests",
    500: "internal_error",
}


def error_body(detail: str, code: str) -> dict[str, str]:
    return {"detail": detail, "code": code}


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(DomainError)
    async def _domain_error_handler(_: Request, exc: DomainError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content=error_body(exc.detail, exc.code))

    @app.exception_handler(RequestValidationError)
    async def _validation_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
        # FastAPI devuelve 422 por defecto; la consigna pide 400 para errores de validación.
        parts = []
        for err in exc.errors():
            loc = ".".join(str(p) for p in err.get("loc", ()) if p != "body")
            parts.append(f"{loc}: {err.get('msg', 'valor inválido')}" if loc else err.get("msg", "valor inválido"))
        detail = "Datos inválidos. " + "; ".join(parts) if parts else "Datos inválidos."
        return JSONResponse(status_code=400, content=error_body(detail, "validation_error"))

    @app.exception_handler(StarletteHTTPException)
    async def _http_handler(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = _STATUS_CODE_NAMES.get(exc.status_code, "http_error")
        detail = exc.detail if isinstance(exc.detail, str) else "Error HTTP"
        return JSONResponse(status_code=exc.status_code, content=error_body(detail, code))

    @app.exception_handler(Exception)
    async def _unhandled_handler(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Error no manejado en %s %s", request.method, request.url.path)
        return JSONResponse(
            status_code=500,
            content=error_body("Error interno del servidor.", "internal_error"),
        )
