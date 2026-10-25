"""Scheduler interno del job de avisos push (app/services/scheduler.py).

Estos tests no tocan FCM ni la red: el job se reemplaza por una función falsa. Lo que se verifica es
el contrato del loop: corre solo, corre seguido, registra el estado que después expone /health, y no
se muere si el job levanta una excepción.
"""

import asyncio

import pytest

from app.services import scheduler


@pytest.fixture(autouse=True)
def _estado_limpio():
    scheduler.reset_state()
    yield
    scheduler.reset_state()


def test_el_loop_corre_el_job_varias_veces_y_frena_con_el_evento():
    corridas: list[int] = []

    def job_falso() -> dict[str, int]:
        corridas.append(len(corridas))
        return {"upcoming": 0, "attempted": 0, "sent": 0, "skipped": 0}

    async def escenario() -> None:
        stop = asyncio.Event()
        # Intervalo 0 = corridas encadenadas, para no esperar un minuto en el test.
        task = asyncio.create_task(scheduler.notifications_loop(stop, 0, job=job_falso))
        while len(corridas) < 3:
            await asyncio.sleep(0.01)
        stop.set()
        await asyncio.wait_for(task, timeout=5)

    asyncio.run(escenario())

    assert len(corridas) >= 3
    assert scheduler.state.enabled is True
    assert scheduler.state.running is False
    assert scheduler.state.runs >= 3
    assert scheduler.state.last_run_at is not None
    assert scheduler.state.last_result == {
        "upcoming": 0,
        "attempted": 0,
        "sent": 0,
        "skipped": 0,
    }
    assert scheduler.state.last_error is None


def test_si_el_job_falla_el_loop_sigue_corriendo():
    intentos: list[int] = []

    def job_que_falla_la_primera_vez() -> dict[str, int]:
        intentos.append(len(intentos))
        if len(intentos) == 1:
            raise RuntimeError("FCM no responde")
        return {"upcoming": 0, "attempted": 0, "sent": 0, "skipped": 0}

    async def escenario() -> None:
        stop = asyncio.Event()
        task = asyncio.create_task(
            scheduler.notifications_loop(stop, 0, job=job_que_falla_la_primera_vez)
        )
        while len(intentos) < 2:
            await asyncio.sleep(0.01)
        stop.set()
        await asyncio.wait_for(task, timeout=5)

    asyncio.run(escenario())

    assert len(intentos) >= 2, "el loop se murió con la primera excepción"
    assert scheduler.state.runs >= 2
    assert scheduler.state.last_error is None, "el error quedó pegado después de una corrida buena"
    assert scheduler.state.last_result["sent"] == 0


def test_snapshot_es_serializable_y_refleja_el_estado():
    scheduler.state.enabled = True
    scheduler.state.interval_seconds = 60
    scheduler.state.runs = 7

    snapshot = scheduler.scheduler_snapshot()

    assert snapshot["enabled"] is True
    assert snapshot["interval_seconds"] == 60
    assert snapshot["runs"] == 7
    assert set(snapshot) == {
        "enabled",
        "running",
        "interval_seconds",
        "runs",
        "started_at",
        "last_run_at",
        "last_result",
        "last_error",
    }


def test_la_suite_no_arranca_el_scheduler_por_defecto(client):
    """El scheduler se apaga por variable de entorno en los tests: no puede tocar la base ni FCM."""
    respuesta = client.get("/health").json()

    assert respuesta["notifications"]["enabled"] is False
    assert respuesta["notifications"]["running"] is False
    assert respuesta["notifications"]["runs"] == 0
    assert scheduler.state.running is False
