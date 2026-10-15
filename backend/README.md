# ClubSebastianMartinezAmaray — Backend (Entrega 2, Electiva General 3349)

API REST para la gestión de espacios deportivos: reservas, sedes, espacios deportivos y
perfiles de usuarios. Es el backend de la app móvil en Flutter (esa parte la hace otro equipo).

- **Stack:** Python 3.11 · FastAPI · SQLAlchemy 2.0 · PostgreSQL · Pydantic v2
- **Auth:** JWT propio, contraseñas con bcrypt (modo alternativo con Firebase Auth, apagado por defecto)
- **Documentación:** Swagger UI en `/docs` y esquema OpenAPI en `/openapi.json`
- **Tests:** 108 tests con `pytest`, incluida una prueba de concurrencia sobre el mismo horario

---

## 1. Requisitos

- Python 3.11+
- PostgreSQL 14+ (o Docker para levantar uno de prueba)
- Docker (opcional, para la base de prueba y para desplegar)

## 2. Puesta en marcha local

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env               # completar DATABASE_URL y JWT_SECRET_KEY
```

Generá una clave JWT de verdad (nunca dejes la de ejemplo):

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

### Base de datos

Si ya tenés un PostgreSQL, creá la base y apuntá `DATABASE_URL` ahí:

```bash
createdb club
# DATABASE_URL=postgresql+psycopg2://usuario:password@localhost:5432/club
```

Si no tenés ninguno a mano, levantalo con Docker:

```bash
docker run -d --name club-pg \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres -e POSTGRES_DB=club \
  -p 5432:5432 postgres:16-alpine
```

El esquema se crea solo al arrancar (`AUTO_CREATE_TABLES=true`, `Base.metadata.create_all`).
Los datos de ejemplo (dos sedes, cinco espacios y un usuario demo) se cargan con `SEED_ON_STARTUP=true`
o a mano:

```bash
python -m app.seed
```

### Correr la API

```bash
uvicorn app.main:app --reload --port 8000
```

- Swagger UI: <http://localhost:8000/docs>
- OpenAPI JSON: <http://localhost:8000/openapi.json>
- Healthcheck: <http://localhost:8000/health>

### Usuario demo del seed

| Correo | Contraseña |
|---|---|
| `demo@club.com` | `Demo1234!` |

## 3. Tests

> ⚠️ **La suite destruye los datos de la base que le indiques.** El fixture de sesión hace
> `drop_all`/`create_all` y borra las filas en cada test. **Usá siempre una base exclusiva y
> descartable**, nunca una compartida ni la de producción. Para prevenir accidentes, la suite
> aborta al arrancar si el nombre de la base apuntada por `DATABASE_URL` no contiene `test` ni
> `verify`.

```bash
# Postgres de prueba (base exclusiva, el nombre contiene "test")
docker run -d --rm --name tp-pg-test \
  -e POSTGRES_PASSWORD=test -e POSTGRES_USER=test -e POSTGRES_DB=club_test \
  -p 55432:5432 postgres:16-alpine

# esperar a que acepte conexiones
docker exec tp-pg-test pg_isready -U test

# (opcional) una base aparte para tus corridas
docker exec tp-pg-test psql -U test -d postgres -c 'CREATE DATABASE club_verify'

# suite completa
DATABASE_URL=postgresql+psycopg2://test:test@localhost:55432/club_test .venv/bin/pytest -q
```

Resultado esperado: **108 tests**, de los cuales **107 passed** y uno se saltea si la suite corre antes
de las 09:00 locales (depende de la hora por el horario de la sede), así que de madrugada puede dar
`107 passed, 1 skipped`: es el mismo resultado. Entre los tests están:

- las 14 reglas de negocio (duración, granularidad horaria, horario de la sede, futuro,
  solapamiento, cancelación que libera el horario, historial, correo no editable, etc.);
- `test_dos_reservas_simultaneas_dejan_una_sola` y `test_concurrencia_a_nivel_servicio`, que disparan
  dos pedidos concurrentes sobre el mismo horario y verifican que sólo uno se cree (el otro recibe 409);
- el reloj de la sede (`tests/test_timezone.py`): con el servidor en UTC (como en Render), una reserva de
  las 22:00 en Argentina tiene que seguir siendo válida. Sin esto, el backend la rechazaba como pasada.
- las pruebas de regresión (`tests/test_regresiones.py`):
  `cancelled_at` en UTC, perfil sin nombres en blanco ni fechas futuras, login de cuenta inactiva sin
  filtrar, recursos inactivos con 404, filtro por tipo sin acentos y disponibilidad reservable.

## 4. Docker

```bash
docker build -t club-api ./backend
docker run --rm -p 8000:8000 \
  -e DATABASE_URL="postgresql+psycopg2://usuario:password@host:5432/club" \
  -e JWT_SECRET_KEY="una-clave-larga" \
  -e SEED_ON_STARTUP=true \
  club-api
```

## 5. Despliegue en Render (API + PostgreSQL)

El repo incluye `backend/render.yaml` como Blueprint.

1. Subí el repo a GitHub.
2. En Render: **New → Blueprint**, elegí el repositorio y confirmá `backend/render.yaml`.
3. Render crea la base (`club-postgres`) y el servicio web, e inyecta `DATABASE_URL` sola.
   `JWT_SECRET_KEY` se genera automáticamente (`generateValue: true`).
4. Completá a mano, si los usás, `FCM_SERVICE_ACCOUNT_JSON`, `SMTP_*` y `FIREBASE_PROJECT_ID`.
5. Verificá que `https://<servicio>.onrender.com/health` responda `{"status":"ok"}` y que
   `/docs` abra el Swagger.

Notas útiles:

- Render entrega la URL de la base como `postgres://…`; el backend la normaliza a
  `postgresql+psycopg2://…` automáticamente (`app/config.py`).
- El contenedor escucha en `$PORT`, que Render define por su cuenta.
- El plan free de Render duerme el servicio por inactividad: el primer request puede tardar.
- El contenedor de Render corre en UTC. La app define la zona de las sedes con `TIMEZONE`
  (`America/Argentina/Buenos_Aires` por defecto) y valida con esa hora: si no, rechazaría reservas de
  horarios que en Argentina todavía son futuros. Ver `app/clock.py`.

## 6. Variables de entorno

Todas están documentadas en `.env.example`. Las importantes:

| Variable | Default | Para qué |
|---|---|---|
| `DATABASE_URL` | `postgresql+psycopg2://postgres:postgres@localhost:5432/club` | Conexión a PostgreSQL |
| `JWT_SECRET_KEY` | valor de ejemplo | Firma de los JWT (**cambiar**) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `60` | Vencimiento del access token |
| `PASSWORD_RESET_TOKEN_EXPIRE_MINUTES` | `30` | Vencimiento del token de recuperación |
| `AUTO_CREATE_TABLES` | `true` | Crea el esquema al arrancar |
| `SEED_ON_STARTUP` | `false` | Carga los datos de ejemplo al arrancar |
| `DEBUG` | `false` | Con `true`, `forgot-password` devuelve el token si no hay SMTP |
| `TIMEZONE` | `America/Argentina/Buenos_Aires` | Zona horaria de las sedes: define qué es "ahora" al validar reservas futuras |
| `AUTH_PROVIDER` | `local` | `local` (JWT propio) o `firebase` (ID tokens) |
| `FCM_SERVICE_ACCOUNT_JSON` | vacío | Activa el envío real de push (FCM HTTP v1) |
| `SMTP_*` | vacío | Envío del correo de recuperación |
| `CORS_ORIGINS` | `*` | Orígenes permitidos, o `*` |

Ningún secreto se versiona: `.env` está en `.gitignore`.

## 7. Autenticación

### JWT propio (por defecto)

1. `POST /auth/register` o `POST /auth/login` devuelven `access_token`.
2. En cada request protegido: `Authorization: Bearer <access_token>`.
3. Las operaciones de usuarios y reservas siempre identifican al usuario autenticado; nadie puede
   ver ni cancelar reservas de otro (eso devuelve 403).

### Modo Firebase (opcional, apagado por defecto)

Con `AUTH_PROVIDER=firebase` y `FIREBASE_PROJECT_ID=<proyecto>`, el backend valida los **ID tokens**
de Firebase Auth contra el endpoint JWKS público de Google (sin SDK): verifica firma RS256, `aud` y
`iss`, y busca al usuario por el `email` del token.

```bash
AUTH_PROVIDER=firebase
FIREBASE_PROJECT_ID=mi-proyecto-firebase
```

## 8. Notificaciones push

- `POST /devices` registra el token FCM del dispositivo del usuario autenticado.
- El job de reservas próximas se corre con:

```bash
python -m app.services.notifications
```

Detecta las reservas activas que arrancan dentro de la próxima hora y les manda el push a los
dispositivos del dueño. **Si `FCM_SERVICE_ACCOUNT_JSON` no está configurado, no falla**: registra
el envío en el log y sigue.

## 9. Recuperación de contraseña

1. `POST /auth/forgot-password` con el correo. Siempre responde lo mismo, exista o no el usuario.
2. Se genera un token aleatorio de un solo uso, con vencimiento (30 min por defecto). En la base se
   guarda **solo el hash SHA-256**, nunca el token.
3. Si `SMTP_*` está configurado, el token sale por correo. Si no, queda en el log y —solo con
   `DEBUG=true`— también en el campo `reset_token` de la respuesta.
4. `POST /auth/reset-password` con `token` y `new_password` cambia la contraseña e invalida el token.
   Un segundo intento con el mismo token devuelve 400 `reset_token_used`.

## 10. Errores

Todos los errores tienen el mismo cuerpo, con el status correcto:

```json
{ "detail": "El espacio ya está reservado en ese horario.", "code": "space_not_available" }
```

| Status | Cuándo |
|---|---|
| 400 | Validación de datos o regla de negocio (duración, minutos, horario de la sede, fecha pasada) |
| 401 | Falta el token, es inválido o expiró; login incorrecto |
| 403 | El recurso es de otro usuario |
| 404 | El recurso no existe |
| 409 | Correo ya registrado, horario ya reservado, reserva ya cancelada |
| 500 | Error interno (sin filtrar detalles al cliente) |

## 11. Estructura

```
backend/
  app/
    main.py            # app FastAPI, CORS, handlers globales, routers
    config.py          # settings por variables de entorno
    database.py        # engine, SessionLocal, get_db, Base
    models.py          # User, PasswordResetToken, DeviceToken, Venue, SportSpace, Reservation
    schemas.py         # Pydantic v2 (request/response)
    security.py        # bcrypt, JWT, get_current_user, modo Firebase
    errors.py          # excepciones de dominio + handlers
    seed.py            # datos de ejemplo idempotentes
    routers/           # auth, users, venues, spaces, reservations, devices
    services/          # reservations (reglas de negocio), notifications (push)
  tests/               # 108 tests
  docs/                # modelo-datos.md, api.md
  requirements.txt  Dockerfile  render.yaml  .env.example  README.md  openapi.json
```

Más detalle en [`docs/modelo-datos.md`](docs/modelo-datos.md) y [`docs/api.md`](docs/api.md).
