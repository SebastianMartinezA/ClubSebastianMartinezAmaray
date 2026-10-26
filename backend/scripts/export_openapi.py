#!/usr/bin/env python3
"""Regenera `openapi.json` (el que se entrega en el repo) desde la app real.

Uso:
    cd backend && python scripts/export_openapi.py

Se corre cada vez que cambia un endpoint, un schema o una respuesta documentada. Hay un test que
falla si el archivo del repo no coincide con la app (`tests/test_docs.py`).
"""

import json
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

from app.main import app  # noqa: E402


def main() -> int:
    esquema = app.openapi()
    destino = RAIZ / "openapi.json"
    destino.write_text(json.dumps(esquema, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    rutas = len(esquema["paths"])
    operaciones = sum(
        len([metodo for metodo in operaciones if metodo in ("get", "post", "patch", "put", "delete")])
        for operaciones in esquema["paths"].values()
    )
    print(f"{destino}: {rutas} rutas, {operaciones} operaciones")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
