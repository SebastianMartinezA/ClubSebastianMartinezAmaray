"""Consultas abiertas: tienen que responder sin token y no filtrar datos sensibles."""

from app.seed import DEMO_EMAIL


def test_usuarios_sin_token(client) -> None:
    response = client.get("/public/users")
    assert response.status_code == 200, response.text
    emails = [u["email"] for u in response.json()]
    assert DEMO_EMAIL in emails


def test_usuarios_no_exponen_datos_privados(client) -> None:
    cuerpo = client.get("/public/users").text
    for prohibido in ("password_hash", "birth_date", "is_admin", "is_active"):
        assert prohibido not in cuerpo, f"la vista pública filtró {prohibido}"


def test_usuarios_paginan(client) -> None:
    todos = client.get("/public/users").json()
    primeros = client.get("/public/users?limit=1").json()
    assert len(primeros) == 1
    if len(todos) > 1:
        segundo = client.get("/public/users?limit=1&offset=1").json()
        assert segundo[0]["id"] != primeros[0]["id"]


def test_sedes_sin_token_traen_sus_espacios(client) -> None:
    response = client.get("/public/venues")
    assert response.status_code == 200, response.text
    sedes = response.json()
    assert sedes, "el seed tiene que dejar al menos una sede"
    assert all("spaces" in sede for sede in sedes)
    assert any(sede["spaces"] for sede in sedes)


def test_espacios_sin_token_y_filtrados_por_sede(client) -> None:
    response = client.get("/public/spaces")
    assert response.status_code == 200, response.text
    espacios = response.json()
    assert espacios
    assert all("venue_name" in espacio for espacio in espacios)

    sede_id = espacios[0]["venue_id"]
    filtrados = client.get(f"/public/spaces?venue_id={sede_id}").json()
    assert filtrados
    assert all(espacio["venue_id"] == sede_id for espacio in filtrados)
    assert len(filtrados) <= len(espacios)


def test_resumen_sin_token(client) -> None:
    response = client.get("/public/summary")
    assert response.status_code == 200, response.text
    datos = response.json()
    assert set(datos) == {"users", "venues", "spaces", "active_reservations"}
    assert datos["users"] >= 1
    assert datos["venues"] >= 1
    assert datos["spaces"] >= datos["venues"]


def test_las_consultas_abiertas_son_de_solo_lectura(client) -> None:
    """Un POST a una ruta pública no existe: 405, no una escritura sin permiso."""
    assert client.post("/public/users", json={}).status_code == 405
    # No hay handler de DELETE en /public: 404 o 405, nunca un 200 que borre algo.
    assert client.delete("/public/venues/1").status_code in (404, 405)
