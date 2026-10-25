"""Scheduler interno del job de avisos push.

Corre adentro del proceso de la API, con un `asyncio.Task` que despierta cada
`NOTIFICATIONS_SCHEDULER_INTERVAL_SECONDS` segundos. No agrega dependencias: usa
`asyncio.to_thread` para ejecutar el job sincrónico (SQLAlchemy) sin bloquear el event loop.

Por qué existe: la Entrega 2 pide que el usuario *reciba* notificaciones push de reservas próximas.
Con el job sólo como comando de consola, en el despliegue no lo dispara nadie y el aviso nunca sale.
El comando sigue disponible (`python -m app.services.notifications`) para correrlo a mano.

Límites conocidos (documentados en backend/README.md):
- Un solo worker. Con `uvicorn --workers N` cada worker correría su propio job; el registro en
  `notification_logs` evita el envío repetido, pero igual conviene un solo worker.
- En el plan gratuito de Render el servicio duerme sin tráfico, así que mientras está dormido el
  scheduler no corre. El primer request lo despierta y el job arranca de nuevo.
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from datetime import datetime, timezone as dt_timezone
from typing import Any, Callable

from .notifications import run_notifications_job

logger = logging.getLogger(__name__)


def _now() -> datetime:
    return datetime.now(dt_timezone.utc)


@dataclass
class SchedulerState:
    """Estado observable del scheduler. `/health` lo expone para poder verificarlo en vivo."""

    enabled: bool = False
    running: bool = False
    interval_seconds: int = 0
    started_at: datetime | None = None
    last_run_at: datetime | None = None
    runs: int = 0
    last_result: dict[str, Any] | None = None
    last_error: str | None = None

    def snapshot(self) -> dict[str, Any]:
        return {
            "enabled": self.enabled,
            "running": self.running,
            "interval_seconds": self.interval_seconds,
            "runs": self.runs,
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "last_run_at": self.last_run_at.isoformat() if self.last_run_at else None,
            "last_result": self.last_result,
            "last_error": self.last_error,
        }


state = SchedulerState()


def reset_state() -> None:
    """Vuelve el estado al inicial, mutando el objeto (no lo reemplaza).

    Lo usan los tests. Se muta en el lugar para que cualquier referencia importada a `state` siga
    apuntando al mismo objeto.
    """
    state.enabled = False
    state.running = False
    state.interval_seconds = 0
    state.started_at = None
    state.last_run_at = None
    state.runs = 0
    state.last_result = None
    state.last_error = None


def scheduler_snapshot() -> dict[str, Any]:
    return state.snapshot()


async def notifications_loop(
    stop: asyncio.Event,
    interval_seconds: int,
    job: Callable[[], dict[str, Any]] = run_notifications_job,
) -> None:
    """Corre `job` cada `interval_seconds` hasta que `stop` se active.

    La primera corrida es inmediata (así, al despertar el servicio, no hay que esperar un intervalo
    entero para mandar el aviso que quedó pendiente). Un error del job se registra en el estado y en
    el log, y el loop sigue: un push fallido no puede apagar los recordatorios.
    """
    state.enabled = True
    state.running = True
    state.interval_seconds = interval_seconds
    state.started_at = _now()
    logger.info("Scheduler de avisos push activo cada %s s", interval_seconds)

    try:
        while not stop.is_set():
            try:
                result = await asyncio.to_thread(job)
                state.last_result = result
                state.last_error = None
            except asyncio.CancelledError:
                raise
            except Exception as error:  # el loop no puede morirse por un job fallido
                state.last_error = f"{type(error).__name__}: {error}"
                logger.exception(
                    "El job de avisos falló; se reintenta en %s s", interval_seconds
                )
            state.runs += 1
            state.last_run_at = _now()

            try:
                await asyncio.wait_for(stop.wait(), timeout=interval_seconds)
            except (asyncio.TimeoutError, TimeoutError):
                continue
    finally:
        state.running = False


async def start(stop: asyncio.Event, interval_seconds: int) -> asyncio.Task:
    """Arranca el loop como tarea de background y devuelve la tarea."""
    return asyncio.create_task(
        notifications_loop(stop, interval_seconds), name="notifications-scheduler"
    )


async def stop(task: asyncio.Task | None, stop_event: asyncio.Event) -> None:
    """Frena el loop y espera a que la tarea termine."""
    if task is None:
        return
    stop_event.set()
    try:
        await task
    except asyncio.CancelledError:
        pass


__all__ = [
    "SchedulerState",
    "notifications_loop",
    "reset_state",
    "scheduler_snapshot",
    "start",
    "state",
    "stop",
]
