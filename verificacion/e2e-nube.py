#!/usr/bin/env python3
"""Bateria end-to-end contra la API desplegada en Render.

Solo lectura + un usuario y unas reservas de prueba. Usa la fecha de pasado manana
para no chocar con reservas reales.
"""
import json
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta

BASE = "https://clubsebastianmartinezamaray-api.onrender.com"
DEMO = ("demo@club.com", "Demo1234!")
ok = fail = 0
lineas = []


def req(method, path, body=None, token=None, timeout=90):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method)
    r.add_header("Content-Type", "application/json")
    if token:
        r.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            raw = resp.read().decode()
            try:
                return resp.status, json.loads(raw)
            except json.JSONDecodeError:
                return resp.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, raw


def check(nombre, obtenido, esperado):
    global ok, fail
    bien = obtenido == esperado
    ok, fail = ok + (1 if bien else 0), fail + (0 if bien else 1)
    lineas.append(f"{'OK ' if bien else 'MAL'} {nombre}: {obtenido} (esperado {esperado})")


def check_uno_de(nombre, obtenido, esperados, nota_extra=""):
    global ok, fail
    bien = obtenido in esperados
    ok, fail = ok + (1 if bien else 0), fail + (0 if bien else 1)
    lineas.append(f"{'OK ' if bien else 'MAL'} {nombre}: {obtenido} (esperado alguno de {esperados}){nota_extra}")


# 1. Salud y catalogo publico
st, _ = req("GET", "/health")
check("health", st, 200)
st, sedes = req("GET", "/venues")
check("sedes", st, 200)
lineas.append(f"    sedes devueltas: {[s['name'] for s in sedes] if isinstance(sedes, list) else sedes}")
st, espacios = req("GET", f"/venues/{sedes[0]['id']}/spaces")
check("espacios de la sede", st, 200)
espacio = espacios[0]
lineas.append(f"    espacio: {espacio['name']} (id {espacio['id']}, tipo {espacio.get('space_type')})")

# 2. Registro y login
nuevo = f"verif.{date.today().strftime('%Y%m%d')}.{datetime.now().strftime('%H%M%S')}@club.com"
st, r = req("POST", "/auth/register", {"email": nuevo, "password": "Verif1234!", "first_name": "Verif",
                                      "last_name": "Adversarial", "birth_date": "1990-05-05"})
check("registro usuario nuevo", st, 201)
st, r = req("POST", "/auth/register", {"email": nuevo, "password": "Verif1234!", "first_name": "Verif",
                                       "last_name": "Adversarial", "birth_date": "1990-05-05"})
check("registro con correo repetido", st, 409)
st, _ = req("POST", "/auth/login", {"email": DEMO[0], "password": "malisima"})
check("login con clave incorrecta", st, 401)
st, r = req("POST", "/auth/login", {"email": DEMO[0], "password": DEMO[1]})
check("login demo", st, 200)
token = r.get("access_token") if isinstance(r, dict) else None
check("login devuelve token", bool(token), True)

# 3. Perfil
st, perfil = req("GET", "/users/me", token=token)
check("perfil", st, 200)
st, _ = req("PATCH", "/users/me", {"first_name": "Sebastian"}, token=token)
check("editar perfil", st, 200)
st, r = req("PATCH", "/users/me", {"email": "otro@club.com"}, token=token)
check("intentar cambiar el correo", st, 400)
st, _ = req("GET", "/users/me")
check("perfil sin token", st, 401)

# 4. Reservas
fecha = (date.today() + timedelta(days=2)).isoformat()
cuerpo = None
reserva = None
st_reserva = None
hora_elegida = None
for h in range(8, 22):
    tentativo = {"sport_space_id": espacio["id"], "date": fecha,
                 "start_time": f"{h:02d}:00", "end_time": f"{h + 1:02d}:00"}
    st, r = req("POST", "/reservations", tentativo, token=token)
    if st == 201:
        cuerpo, reserva, st_reserva, hora_elegida = tentativo, r, st, h
        break
check("reserva valida (primer turno libre encontrado)", st_reserva, 201)
lineas.append(f"    turno probado: {fecha} de {hora_elegida:02d}:00 a {hora_elegida + 1:02d}:00")
rid = reserva.get("id") if isinstance(reserva, dict) else None
st, r = req("POST", "/reservations", cuerpo, token=token)
check("reserva superpuesta", st, 409)
lineas.append(f"    codigo de error: {r.get('code') if isinstance(r, dict) else r}")
st, _ = req("POST", "/reservations", {**cuerpo, "start_time": "15:00", "end_time": "15:30"}, token=token)
check("duracion menor a una hora", st, 400)
st, _ = req("POST", "/reservations", {**cuerpo, "start_time": "16:30", "end_time": "18:00"}, token=token)
check("minutos distintos de 00", st, 400)
st, _ = req("POST", "/reservations", {**cuerpo, "start_time": "04:00", "end_time": "05:00"}, token=token)
check("fuera del horario de la sede", st, 400)
st, _ = req("POST", "/reservations", {**cuerpo, "date": (date.today() - timedelta(days=1)).isoformat()}, token=token)
check("reserva en el pasado", st, 400)
st, mias = req("GET", "/reservations", token=token)
check("listar mis reservas", st, 200)
st, _ = req("POST", f"/reservations/{rid}/cancel", token=token)
check("cancelar", st, 200)
st, _ = req("POST", "/reservations", cuerpo, token=token)
check("reservar de nuevo el horario liberado", st, 201)
st, hist = req("GET", "/reservations/history", token=token)
check("historial", st, 200)
primera = hist[0] if isinstance(hist, list) and hist else {}
lineas.append(f"    historial: {len(hist) if isinstance(hist, list) else '?'} entradas, primera con estado {primera.get('status')}")

# 5. Aislamiento entre usuarios
otro = f"intruso.{date.today().strftime('%Y%m%d')}.{datetime.now().strftime('%H%M%S')}@club.com"
req("POST", "/auth/register", {"email": otro, "password": "Otro1234!", "first_name": "Intruso",
                               "last_name": "Prueba", "birth_date": "1991-01-01"})
st, r = req("POST", "/auth/login", {"email": otro, "password": "Otro1234!"})
token_otro = r.get("access_token") if isinstance(r, dict) else None
st, _ = req("GET", f"/reservations/{rid}", token=token_otro)
check_uno_de("ver la reserva de otro usuario", st, [403, 404], " (404 = la ruta de detalle no existe)")
st, _ = req("POST", f"/reservations/{rid}/cancel", token=token_otro)
check("cancelar la reserva de otro usuario", st, 403)

# 6. Documentacion
st, _ = req("GET", "/docs")
check("swagger", st, 200)
st, _ = req("GET", "/openapi.json")
check("openapi.json", st, 200)

print("\n".join(lineas))
print(f"\nRESULTADO: {ok} OK / {fail} MAL")
print("VEREDICTO:", "API EN LA NUBE FUNCIONANDO" if fail == 0 else "HAY FALLAS")
