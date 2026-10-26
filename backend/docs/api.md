# API REST — ClubSebastianMartinezAmaray

Base local: `http://localhost:8000` · Swagger UI: `/docs` · OpenAPI: `/openapi.json`

Todas las operaciones sobre usuarios y reservas exigen `Authorization: Bearer <access_token>`.
Todos los errores responden `{"detail": "...", "code": "..."}`.

## Resumen de endpoints

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| GET | `/` | — | Info básica del servicio |
| GET | `/health` | — | Healthcheck |
| POST | `/auth/register` | — | Registrar usuario (devuelve token) |
| POST | `/auth/login` | — | Iniciar sesión |
| POST | `/auth/forgot-password` | — | Pedir token de recuperación |
| POST | `/auth/reset-password` | — | Cambiar la contraseña con el token |
| GET | `/auth/me` | ✅ | Usuario autenticado |
| GET | `/users/me` | ✅ | Ver mi perfil |
| PATCH | `/users/me` | ✅ | Editar mi perfil (el correo no se puede cambiar → 400) |
| GET | `/venues` | — | Listar sedes con horarios |
| GET | `/venues/{id}` | — | Detalle de una sede |
| GET | `/venues/{id}/spaces` | — | Espacios de la sede |
| GET | `/venues/{id}/availability?date=YYYY-MM-DD` | — | Disponibilidad por fecha |
| GET | `/spaces` | — | Listar espacios (filtro `?type=` y `?venue_id=`) |
| GET | `/spaces/{id}` | — | Detalle de un espacio |
| POST | `/reservations` | ✅ | Crear reserva (valida disponibilidad de forma atómica) |
| GET | `/reservations` | ✅ | Mis reservas vigentes |
| GET | `/reservations/history` | ✅ | Historial (terminadas + canceladas) |
| POST | `/reservations/{id}/cancel` | ✅ | Cancelar (libera el horario) |
| POST | `/devices` | ✅ | Registrar token de notificaciones |
| GET | `/devices` | ✅ | Mis dispositivos registrados |
| GET | `/admin/venues` | 🔑 | Listar sedes, incluidas las dadas de baja |
| POST | `/admin/venues` | 🔑 | Crear sede |
| PATCH | `/admin/venues/{id}` | 🔑 | Editar sede (o reactivarla) |
| DELETE | `/admin/venues/{id}` | 🔑 | Dar de baja la sede (baja lógica) |
| GET | `/admin/spaces` | 🔑 | Listar espacios, incluidas las bajas |
| POST | `/admin/spaces` | 🔑 | Crear espacio en una sede |
| PATCH | `/admin/spaces/{id}` | 🔑 | Editar espacio (o reactivarlo) |
| DELETE | `/admin/spaces/{id}` | 🔑 | Dar de baja el espacio (baja lógica) |

🔑 = además del token, el usuario necesita el perfil de administrador (`users.is_admin`).

---

## Autenticación

### POST /auth/register

```json
{ "email": "maria@club.com", "password": "Secreta123", "first_name": "Maria",
  "last_name": "Lopez", "birth_date": "1996-03-08" }
```

`201 Created`

```json
{ "access_token": "eyJhbGciOiJIUzI1NiIs…", "token_type": "bearer", "expires_in": 3600,
  "user": { "id": 2, "email": "maria@club.com", "first_name": "Maria", "last_name": "Lopez",
            "birth_date": "1996-03-08", "created_at": "2026-10-14T22:12:52.123456Z" } }
```

Correo ya registrado → `409` `email_already_registered`. Contraseña de menos de 8 caracteres o correo
mal formado → `400` `validation_error`.

### POST /auth/login

```json
{ "email": "maria@club.com", "password": "Secreta123" }
```

`200 OK` con el mismo cuerpo que el registro. Credenciales incorrectas → `401 invalid_credentials`
(el mismo mensaje exista o no el correo, para no filtrar qué cuentas existen).

### POST /auth/forgot-password

```json
{ "email": "maria@club.com" }
```

`200 OK`

```json
{ "message": "Si el correo está registrado, te enviamos las instrucciones para restablecer la contraseña.",
  "reset_token": null }
```

`reset_token` solo viene con valor si **no hay SMTP configurado y `DEBUG=true`** (entorno de prueba).
El token vence a los 30 minutos y es de un solo uso.

### POST /auth/reset-password

```json
{ "token": "6fNa8JxywwKY-F-FHGRO5Bx6emx0Wd21dfNDMapUnXI", "new_password": "NuevaClave123" }
```

`200 OK` `{"detail": "Contraseña actualizada. Ya podés iniciar sesión con la nueva.", "code": "password_updated"}`

Token inexistente → `400 invalid_reset_token` · ya usado → `400 reset_token_used` · vencido →
`400 reset_token_expired`.

## Perfil

### GET /users/me

`200 OK`

```json
{ "id": 2, "email": "maria@club.com", "first_name": "María", "last_name": "Lopez",
  "birth_date": "1996-03-08", "created_at": "2026-10-14T22:12:52.123456Z" }
```

### PATCH /users/me

```bash
curl -X PATCH .../users/me -H "Authorization: Bearer $TOKEN" \
     -d '{"first_name":"María","birth_date":"1996-03-08"}'
```

`200 OK`. Si llega un `email` distinto del actual → `400 email_not_editable`:

```json
{ "detail": "El correo electrónico no se puede modificar.", "code": "email_not_editable" }
```

Mandarlo igual al registrado no rompe nada (se ignora).

## Sedes y espacios

### GET /venues

```json
[ { "id": 1, "name": "Moron", "address": "Rivadavia 19850",
    "opening_time": "08:00:00", "closing_time": "22:00:00" },
  { "id": 2, "name": "Castelar", "address": "Av. Yrigoyen 1234",
    "opening_time": "09:00:00", "closing_time": "23:00:00" } ]
```

### GET /venues/{id}/spaces

```json
[ { "id": 1, "venue_id": 1, "venue_name": "Moron", "name": "Moron_Rivadavia_19850_Paddle_1",
    "space_type": "Paddle", "number": 1 } ]
```

### GET /spaces?type=Paddle

Mismo formato. El filtro `type` es case-insensitive y parcial; `venue_id` filtra por sede.

### GET /venues/{id}/availability?date=2026-10-17

Devuelve, por cada espacio activo de la sede, la grilla de turnos de una hora entre apertura y cierre.
Un turno está `available: false` si ya hay una reserva activa encima o si ya pasó.

```json
{ "venue": { "id": 1, "name": "Moron", "address": "Rivadavia 19850",
             "opening_time": "08:00:00", "closing_time": "22:00:00" },
  "date": "2026-10-17",
  "spaces": [
    { "space": { "id": 3, "venue_id": 1, "venue_name": "Moron",
                 "name": "Moron_Rivadavia_19850_Futbol_1", "space_type": "Futbol", "number": 1 },
      "slots": [ { "start_time": "08:00:00", "end_time": "09:00:00", "available": true },
                 { "start_time": "10:00:00", "end_time": "11:00:00", "available": false },
                 { "start_time": "21:00:00", "end_time": "22:00:00", "available": true } ] } ] }
```

## Reservas

### POST /reservations

```json
{ "sport_space_id": 3, "date": "2026-10-17", "start_time": "10:00:00", "end_time": "11:00:00" }
```

`201 Created`

```json
{ "id": 1, "sport_space_id": 3, "space_name": "Moron_Rivadavia_19850_Futbol_1",
  "venue_id": 1, "venue_name": "Moron", "date": "2026-10-17",
  "start_time": "10:00:00", "end_time": "11:00:00", "status": "active",
  "created_at": "2026-10-14T22:12:52.987654Z", "cancelled_at": null }
```

Errores posibles:

| Status | `code` | Cuándo |
|---|---|---|
| 400 | `invalid_duration` | duración menor a una hora (18:00→18:30) |
| 400 | `invalid_time_granularity` | minuto o segundo distintos de 00 (18:30→20:00) |
| 400 | `invalid_range` | inicio >= fin |
| 400 | `outside_venue_hours` | fuera del horario de la sede (06:00→07:00 con apertura 08:00) |
| 400 | `reservation_in_the_past` | `datetime(date, start_time) <= now()` |
| 404 | `space_not_found` | el espacio no existe |
| 409 | `space_not_available` | ya hay una reserva activa que se superpone |

Ejemplo de conflicto:

```json
{ "detail": "El espacio ya está reservado en ese horario.", "code": "space_not_available" }
```

La validación de disponibilidad y el insert ocurren en la misma transacción, con
`SELECT … FOR UPDATE` sobre la fila del espacio: si dos pedidos simultáneos piden el mismo horario,
**solo uno crea la reserva** y el otro recibe 409.

### GET /reservations

Reservas vigentes del usuario (`status = active` y fin todavía no alcanzado), ordenadas por fecha y hora.

### GET /reservations/history

Reservas terminadas (fecha y hora de fin anteriores a ahora) y canceladas, más recientes primero.
Las canceladas se distinguen por `"status": "cancelled"` y traen `cancelled_at`.

### POST /reservations/{id}/cancel

`200 OK` con la reserva en `"status": "cancelled"`. Después de cancelar, **el mismo horario vuelve a
estar disponible** y se puede reservar de nuevo.

| Status | `code` | Cuándo |
|---|---|---|
| 403 | `not_reservation_owner` | la reserva es de otro usuario |
| 404 | `reservation_not_found` | no existe |
| 409 | `reservation_already_cancelled` | ya estaba cancelada |

## Dispositivos

### POST /devices

```json
{ "token": "fcm-token-del-dispositivo", "platform": "android" }
```

`201 Created` `{"id": 1, "token": "…", "platform": "android", "created_at": "…"}`.
Es idempotente: registrar el mismo token otra vez lo reasigna al usuario actual.

## Administración del catálogo

El catálogo (sedes y espacios) no lo edita el socio: lo administra el club. Por eso vive bajo
`/admin`, separado de las rutas públicas que usa la app.

### Permisos

El token JWT identifica al usuario; el permiso se resuelve **contra la base en cada request**
(`users.is_admin`), no adentro del token. Si se le quita el permiso a alguien, deja de poder operar
en el acto, sin esperar a que venza su token.

- Sin token → `401 missing_token`
- Usuario común → `403 admin_required`
- El administrador se designa al arrancar con la variable `ADMIN_EMAIL` (no es secreta; va en
  `render.yaml`).

### Alta de sede

```json
{ "name": "Tigre", "address": "Av. Cazon 1200", "opening_time": "08:00", "closing_time": "22:00" }
```

`201 Created` `{ "id": 3, "name": "Tigre", "address": "Av. Cazon 1200", "opening_time": "08:00:00",
"closing_time": "22:00:00", "is_active": true, "spaces_count": 0 }`

- El nombre es único entre las sedes **activas**, sin distinguir mayúsculas → `409
  venue_already_exists`.
- `opening_time` tiene que ser anterior a `closing_time` → `400 validation_error`.

### Alta de espacio

```json
{ "venue_id": 3, "space_type": "Paddle", "number": 1 }
```

`201 Created` `{ "id": 6, "venue_id": 3, "space_type": "Paddle", "number": 1,
"name": "Tigre_Av._Cazon_1200_Paddle_1", "is_active": true }`

- El `name` se compone solo (sede + dirección + tipo + número) y se recalcula si después se edita
  la sede, el tipo o el número: nunca queda desincronizado.
- El slot (sede, tipo, número) es único entre los espacios activos → `409 space_already_exists`.

### Baja y reactivación

`DELETE` no borra: deja `is_active: false`. Las reservas históricas siguen apuntando a esa sede o
espacio.

- Si hay reservas activas de hoy en adelante: `409 venue_has_future_reservations` o `409
  space_has_future_reservations`. Primero se cancelan, después se da de baja.
- El socio deja de verla (`404` en las rutas públicas), el administrador la sigue viendo en
  `/admin/*`.
- `PATCH { "is_active": true }` la reactiva y vuelve al listado público.
- Como el nombre se libera al dar de baja la sede, se puede volver a crear una sede con ese nombre.

## Errores transversales

| Status | `code` | Cuándo |
|---|---|---|
| 400 | `validation_error` | el payload no cumple el esquema |
| 401 | `missing_token` / `invalid_token` / `token_expired` | falta el token, es inválido o expiró |
| 401 | `invalid_credentials` | login incorrecto |
| 403 | `forbidden` / `not_reservation_owner` | sin permiso sobre el recurso |
| 404 | `not_found` | ruta o recurso inexistente |
| 405 | `method_not_allowed` | método HTTP no soportado |
| 409 | `*` | conflicto de negocio (correo repetido, horario tomado, ya cancelada) |
| 500 | `internal_error` | error interno del servidor |
