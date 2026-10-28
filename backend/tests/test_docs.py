"""Coherencia entre la documentación versionada y la app.

`openapi.json` se entrega en el repo y es lo que mira quien corrige: si queda viejo, el repo dice
tener menos endpoints de los que la API expone. Este test falla si el archivo no se regeneró después
de tocar rutas, schemas o respuestas documentadas (`python scripts/export_openapi.py`).
"""

import json
import pathlib

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def test_openapi_json_del_repo_coincide_con_la_app(client):
    en_disco = json.loads((RAIZ / "openapi.json").read_text(encoding="utf-8"))
    assert en_disco == client.get("/openapi.json").json()


def test_openapi_json_incluye_la_administracion(client):
    esquema = json.loads((RAIZ / "openapi.json").read_text(encoding="utf-8"))
    rutas_admin = sorted(ruta for ruta in esquema["paths"] if ruta.startswith("/admin"))
    assert rutas_admin == [
        "/admin/firebase/migrate",
        "/admin/spaces",
        "/admin/spaces/{space_id}",
        "/admin/users",
        "/admin/venues",
        "/admin/venues/{venue_id}",
    ]
