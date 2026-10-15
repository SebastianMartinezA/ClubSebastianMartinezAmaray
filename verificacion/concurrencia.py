#!/usr/bin/env python3
"""Prueba de concurrencia contra la API real: dos requests simultáneos al mismo horario.

Uso: .venv/bin/python ../verificacion/concurrencia.py
Salida: ../verificacion/concurrencia.txt
"""

import json
import subprocess
import sys
import threading
from datetime import date, timedelta
from pathlib import Path

import requests

BASE = "http://127.0.0.1:8098"
DIR = Path(__file__).resolve().parent
OUT = DIR / "concurrencia.txt"
SPACE_ID = 3
DIA = (date.today() + timedelta(days=5)).isoformat()
HORA = ("18:00:00", "19:00:00")

lineas: list[str] = []


def log(texto: str = "") -> None:
    print(texto)
    lineas.append(texto)


def main() -> int:
    login = requests.post(
        f"{BASE}/auth/login",
        json={"email": "maria@club.com", "password": "NuevaClave123"},
        timeout=10,
    )
    login.raise_for_status()
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "sport_space_id": SPACE_ID,
        "date": DIA,
        "start_time": HORA[0],
        "end_time": HORA[1],
    }

    log(f"Prueba de concurrencia - {DIA} {HORA[0]}-{HORA[1]} - espacio {SPACE_ID}")
    log(f"payload idéntico: {json.dumps(payload)}")
    log("")

    barrera = threading.Barrier(2)
    resultados: list[tuple[str, int, str]] = []
    lock = threading.Lock()

    def worker(nombre: str) -> None:
        barrera.wait(timeout=10)
        respuesta = requests.post(f"{BASE}/reservations", json=payload, headers=headers, timeout=20)
        with lock:
            resultados.append((nombre, respuesta.status_code, respuesta.text))

    hilos = [threading.Thread(target=worker, args=(f"request {i}",)) for i in (1, 2)]
    for hilo in hilos:
        hilo.start()
    for hilo in hilos:
        hilo.join(timeout=30)

    for nombre, status, cuerpo in sorted(resultados):
        log(f"{nombre}: HTTP {status}")
        log(f"  {cuerpo}")

    codigos = sorted(status for _, status, _ in resultados)

    conteo = subprocess.run(
        [
            "docker",
            "exec",
            "tp-pg-test",
            "psql",
            "-U",
            "test",
            "-d",
            "club_demo",
            "-tAc",
            "SELECT count(*) FROM reservations "
            f"WHERE sport_space_id={SPACE_ID} AND date='{DIA}' AND status='active';",
        ],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.strip()

    log("")
    log(f"status codes obtenidos: {codigos}")
    log(f"filas activas en la base para ese espacio/fecha: {conteo}")
    log("")
    ok = codigos == [201, 409] and conteo == "1"
    log("RESULTADO: " + ("OK - una sola reserva creada" if ok else "FALLO"))
    OUT.write_text("\n".join(lineas) + "\n", encoding="utf-8")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
