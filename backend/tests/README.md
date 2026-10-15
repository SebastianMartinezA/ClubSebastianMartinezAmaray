# Tests del backend

⚠️ **La suite destruye los datos de la base que le indiques.** El fixture de sesión
(`tests/conftest.py::_tables`) hace `drop_all`/`create_all`, y `_clean_database` borra las filas de
todas las tablas antes de cada test. Si corrés la suite contra una base compartida o de producción
te llevás puesta la de otro proceso.

## Regla

Usá **siempre una base exclusiva y descartable**, y que su nombre contenga `test` o `verify`.

Como red de seguridad, la suite **aborta al arrancar** (con un mensaje claro y exit code 2) si el
nombre de la base apuntada por `DATABASE_URL` no contiene `test` ni `verify`. Aun así, no confíes
sólo en eso: el guard es una heurística de nombre.

## Cómo correrla

```bash
# 1. Postgres de prueba (contenedor tp-pg-test, puerto 55432)
docker run -d --rm --name tp-pg-test \
  -e POSTGRES_PASSWORD=test -e POSTGRES_USER=test -e POSTGRES_DB=club_test \
  -p 55432:5432 postgres:16-alpine
docker exec tp-pg-test pg_isready -U test

# 2. (opcional) una base exclusiva para tus corridas
docker exec tp-pg-test psql -U test -d postgres -c 'CREATE DATABASE club_verify'

# 3. suite completa
cd backend
DATABASE_URL=postgresql+psycopg2://test:test@localhost:55432/club_verify .venv/bin/pytest -q
```

Sin `DATABASE_URL`, el `conftest` usa por defecto `club_test` en `localhost:55432`.

## Archivos

| Archivo | Qué cubre |
|---|---|
| `test_auth.py` | registro, login, recuperación de contraseña, token |
| `test_profile.py` | perfil propio; el correo no se puede cambiar |
| `test_venues_spaces.py` | sedes, espacios, disponibilidad |
| `test_reservations.py` | reglas de negocio de reservas (1 a 9) y concurrencia |
| `test_timezone.py` | la validación de reserva futura usa la hora local de la sede |
| `test_errors.py` | formato uniforme de errores |
| `test_config.py` | settings por variables de entorno |
| `test_bugfixes_ronda1.py` | arreglos de la ronda 1 (timestamps UTC, perfil, inactivos, acentos, grilla) |
