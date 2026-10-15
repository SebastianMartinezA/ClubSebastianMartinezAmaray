# Brief: backend de la Entrega 2 del TP de Electiva General (3349)

## Contexto

Trabajo práctico de la facultad (Unimoron), materia Electiva General (3349). La consigna oficial la
escribió el profesor y está transcripta acá abajo. Lo que hay que construir es el **backend (API REST)**
de una aplicación móvil de gestión de espacios deportivos. La app móvil (Flutter) la hace otro equipo,
no la toques.

El nombre de la aplicación y del repositorio es **ClubSebastianMartinezAmaray** (la consigna exige
`Club` + nombre y apellido del alumno). Usá ese nombre en el README, en los títulos y en el repo.

## La consigna (textual, resumida a lo que aplica al backend)

Aplicación móvil para la gestión de espacios deportivos: los usuarios reservan espacios desde el
celular, consultan disponibilidad de espacios de distintas sedes y reciben notificaciones push de
reservas próximas. El sistema incluye **APIs para la gestión de reservas, sedes, espacios deportivos y
perfiles de usuarios**, y la app móvil en Flutter.

Requerimientos funcionales:

- Registro, inicio de sesión y recuperación de contraseña con correo electrónico y contraseña.
  Al iniciar sesión la app muestra una página inicial (Home Page). Quien olvide la contraseña tiene que
  disponer de un mecanismo seguro para recuperarla o establecer una nueva.
- Perfil de usuario: mostrar todos los datos y permitir su edición, **salvo el correo electrónico**.
  Como mínimo nombre, apellido y fecha de nacimiento. Poder cerrar la sesión.
- Gestión de reservas:
  - Los horarios disponibles están dentro del horario de funcionamiento de la sede.
  - Una reserva es: un espacio deportivo, una fecha, una hora de inicio y una hora de finalización.
  - Duración mínima: una hora.
  - Horas completas: inicio y fin en el minuto 00 (18:00 a 19:00, 18:00 a 20:00, etc.).
  - La hora de finalización no puede superar el horario de cierre de la sede.
  - Las reservas son solo para horarios futuros respecto del momento de la reserva.
  - Un espacio no puede reservarse dos veces para la misma fecha si hay superposición de horarios.
    **El backend debe validar la disponibilidad antes de registrar la reserva.**
  - Consultar disponibilidad de espacios según la sede.
  - Listar las reservas del usuario indicando sede, espacio deportivo, fecha y horario.
  - Cancelar una reserva; al cancelar, el espacio vuelve a estar disponible para ese mismo horario.
- Módulo de sedes: cada sede tiene como mínimo nombre, dirección y horarios de funcionamiento.
  Mostrar el listado de sedes con sus horarios y permitir seleccionar una sede para consultar sus
  espacios y horarios disponibles.
- Módulo de espacios deportivos: listado de espacios indicando la sede donde se ubica cada uno.
  Cada espacio está asociado a una sede y tiene como mínimo un tipo y un nombre compuesto por sede,
  dirección, tipo de espacio y un número. Ejemplo: `Moron_Rivadavia_19850_Paddle_1`.
  Permitir filtrar los espacios por tipo (Fútbol, Paddle, Básquet, etc.).
- Historial de reservas: incluye las reservas cuyo horario ya finalizó.
- Manejo de errores: sin conexión a internet, servidor caído, login incorrecto, usuario ya registrado, etc.

Requerimientos no funcionales (los que aplican al backend):

- API REST **documentada mediante Swagger/OpenAPI**.
- Lenguaje libre, **preferentemente Python**.
- Base de datos **relacional, preferentemente PostgreSQL**.
- La API REST y la base de datos tienen que estar **disponibles en la nube** (el profesor sugiere
  Render para el despliegue de la API y la base, y Firebase para autenticación y notificaciones push).
- Las operaciones de la API relacionadas con usuarios y reservas tienen que **identificar al usuario
  autenticado**.
- El backend necesita un **README** que explique todos los pasos para configurar, ejecutar y desplegar
  el proyecto.
- El proyecto se gestiona en un repositorio GitHub con commits propios del alumno.

## Decisiones técnicas ya tomadas (no las cambies sin avisar)

- **Python 3.11 + FastAPI** (Swagger/OpenAPI automático en `/docs` y `/openapi.json`).
- **SQLAlchemy 2.0 + PostgreSQL** (`psycopg2-binary`), migraciones simples con `Base.metadata.create_all`
  al arrancar más un script de seed con datos de ejemplo (sedes, espacios y un usuario demo).
- **Autenticación con JWT propio** (contraseñas con bcrypt). Se elige esto porque no depende de cuentas
  externas y se puede demostrar en la defensa. Dejá preparado, documentado y **desactivado por defecto**
  un modo alternativo que valide ID tokens de Firebase Auth si la variable de entorno
  `AUTH_PROVIDER=firebase` está seteada (usá el endpoint JWKS de Google, sin SDK).
- **Notificaciones push**: el backend expone el registro de tokens de dispositivo y un job que detecta
  reservas próximas. El envío real por Firebase Cloud Messaging (HTTP v1) se activa solo si hay
  credenciales en el entorno (`FCM_SERVICE_ACCOUNT_JSON`); si no, se registra en el log y no falla.
- Config por variables de entorno (`.env.example` incluido). Nada de secretos en el repo.

## Estructura esperada

```
backend/
  app/
    main.py            # app FastAPI, CORS, manejo global de errores, include_router
    config.py          # settings por env vars
    database.py        # engine, SessionLocal, get_db, Base
    models.py          # User, PasswordResetToken, DeviceToken, Venue, SportSpace, Reservation
    schemas.py         # Pydantic v2 request/response
    security.py        # hash de contraseñas, JWT, dependencia get_current_user
    errors.py          # excepciones de dominio + handlers (formato consistente)
    seed.py            # datos de ejemplo idempotentes
    routers/
      auth.py          # register, login, forgot-password, reset-password, me
      users.py         # GET/PATCH /users/me (email no editable)
      venues.py        # listado, detalle, disponibilidad por fecha, espacios de la sede
      spaces.py        # listado con filtro por tipo, detalle
      reservations.py  # crear, listar activas, historial, cancelar
      devices.py       # registrar token de dispositivo
    services/
      reservations.py  # validaciones de negocio y detección de solapamiento
      notifications.py # detección de reservas próximas y envío opcional por FCM
  tests/
    conftest.py        # fixtures: app de test, base de datos de test, cliente, usuario autenticado
    test_auth.py
    test_profile.py
    test_venues_spaces.py
    test_reservations.py
    test_errors.py
  docs/
    modelo-datos.md    # entidades, atributos, relaciones + diagrama Mermaid del DER
    api.md             # resumen de endpoints con ejemplos de request/response
  requirements.txt
  Dockerfile
  render.yaml
  .env.example
  README.md
  openapi.json         # generado al final (ver Verificación)
```

## Reglas de negocio que tienen que estar implementadas y testeadas

1. Duración mínima de una hora: `end_time - start_time >= 1h`.
2. `start_time` y `end_time` con minuto 00 y segundo 00.
3. `start_time < end_time`.
4. La reserva tiene que caer dentro del horario de funcionamiento de la sede (apertura <= inicio y
   fin <= cierre). Modelá el horario de la sede como hora de apertura y de cierre (`time`).
5. La reserva tiene que ser futura: `datetime(fecha, start_time) > now()`.
6. Sin superposición: para el mismo espacio y la misma fecha, ninguna reserva **activa** puede
   solaparse con el intervalo pedido. Dos intervalos se solapan si `start < otro_end and end > otro_start`.
7. La validación de disponibilidad y el insert tienen que ser **atómicos**: usá una transacción con
   `SELECT ... FOR UPDATE` sobre la fila del espacio (o una constraint de exclusión en Postgres) para
   que dos pedidos simultáneos no puedan crear reservas superpuestas. Si el espacio ya está tomado,
   respondé `409 Conflict`. Agregá un test que dispare dos requests concurrentes sobre el mismo horario
   y verifique que solo una se cree.
8. Cancelar una reserva la pasa a estado `cancelled` (no se borra) y libera el horario: después de
   cancelar, otra reserva en el mismo horario tiene que poder crearse.
9. El historial incluye las reservas terminadas (fecha y hora de fin anteriores a ahora) y las canceladas
   se distinguen por estado.
10. El perfil no permite cambiar el correo: si llega un `email` distinto en el PATCH, respondé 400.
11. El registro con un correo ya existente responde 409 con un mensaje claro.
12. Login incorrecto responde 401 sin filtrar si el correo existe o no.
13. Recuperación de contraseña: `POST /auth/forgot-password` genera un token de un solo uso con
    vencimiento (30 min), guarda el hash y, si `SMTP_*` está configurado, manda el mail; si no, deja el
    token en el log y en la respuesta **solo si `DEBUG=true`**. `POST /auth/reset-password` valida el
    token, cambia la contraseña y lo invalida.
14. Todos los errores tienen un cuerpo consistente: `{"detail": "...", "code": "..."}` con el status
    correcto (400 validación, 401 no autenticado, 403 sin permiso sobre el recurso, 404 no existe,
    409 conflicto).

## Verificación obligatoria (no entregues sin esto)

Todo se corre en la máquina donde estás (Linux ARM64, hay Docker). Pasos:

1. Crear el venv e instalar dependencias: `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`.
2. Levantar Postgres de prueba en Docker:
   `docker run -d --rm --name tp-pg-test -e POSTGRES_PASSWORD=test -e POSTGRES_USER=test -e POSTGRES_DB=club_test -p 55432:5432 postgres:16-alpine`
   (esperá a que acepte conexiones; `docker exec tp-pg-test pg_isready -U test`).
3. Correr la suite: `.venv/bin/pytest -q` con `DATABASE_URL=postgresql+psycopg2://test:test@localhost:55432/club_test`
   (los tests tienen que crear y limpiar su propia base/esquema). **Todos los tests tienen que pasar.**
4. Levantar la API de verdad (`.venv/bin/uvicorn app.main:app --port 8099`) y pegarle con `curl` a:
   registro, login, perfil (GET y PATCH), listado de sedes, disponibilidad, creación de reserva válida,
   intento de reserva superpuesta (tiene que dar 409), reserva con duración menor a una hora (400),
   reserva con minutos distintos de 00 (400), reserva fuera del horario de la sede (400), reserva en el
   pasado (400), listado de reservas, cancelación y recreación del mismo horario (tiene que funcionar).
   **Pegá las salidas reales de curl en tu respuesta final** (resumidas, con el status code y el cuerpo).
5. Generar `openapi.json`: `curl -s localhost:8099/openapi.json -o openapi.json` y verificar que tiene
   los endpoints.
6. Al terminar, borrá el contenedor de prueba: `docker stop tp-pg-test` y verificá que no quede nada
   corriendo (`docker ps | grep tp-pg-test` vacío, `pkill -f 'uvicorn app.main'`).

## Restricciones

- Trabajá **solo** dentro de `/opt/data/workspace/tp-electiva2/` (es el directorio del proyecto). No
  toques nada fuera de ahí, no toques otros contenedores Docker, no reinicies servicios del sistema.
- No uses `execute_code` (se cuelga en este entorno): usá `terminal`, `write_file`, `read_file` y `patch`.
- No subas nada a GitHub ni a ningún servicio externo: el repositorio y el despliegue los manejo yo.
- No inventes credenciales. Nada de secretos en archivos versionados.
- Código en inglés (nombres de clases, funciones, endpoints), textos de usuario y documentación en
  español rioplatense.
- Comentarios y docstrings solo donde expliquen una decisión no obvia. Sin relleno.

## Qué devolver en tu respuesta final

Un informe corto y verificable: estructura de archivos creada, cantidad de tests y su resultado real,
la tabla de los `curl` de verificación con status code y respuesta resumida, el resultado de la prueba
de concurrencia, y cualquier cosa que haya quedado sin resolver o dudosa. Si algo no lo pudiste
verificar, decilo explícitamente en vez de darlo por hecho.
