# ClubSebastianMartinezAmaray

Trabajo práctico de **Electiva General (3349)** — Unimoron. Aplicación móvil para la gestión de
espacios deportivos: reservar desde el celular, consultar la disponibilidad de espacios de distintas
sedes y recibir notificaciones de reservas próximas.

El repositorio se llama como pide la consigna: `Club` + nombre y apellido del alumno.

## Qué hay acá

```
backend/      API REST (Python 3.11 + FastAPI + PostgreSQL + SQLAlchemy 2.0) con Swagger/OpenAPI
app/          Aplicación móvil en Flutter, conectada a la API
```

- **Backend** → [`backend/README.md`](backend/README.md) · Swagger en `/docs` · esquema en `/openapi.json`
- **App** → [`app/README.md`](app/README.md)
- **Diseño** (paleta medida del prototipo de Figma, componentes y tipografía) → [`docs/design-system.md`](docs/design-system.md)
- **Modelo de datos** (entidades, atributos y relaciones) → [`backend/docs/modelo-datos.md`](backend/docs/modelo-datos.md)
- **Endpoints** con ejemplos → [`backend/docs/api.md`](backend/docs/api.md)

## Cómo se corre

### Backend

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # completar DATABASE_URL y JWT_SECRET_KEY

# PostgreSQL de prueba (o el que ya tengas)
docker run -d --rm --name club-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=club -p 5432:5432 postgres:16-alpine

uvicorn app.main:app --reload --port 8000
```

Swagger: <http://localhost:8000/docs>. Los datos de ejemplo (dos sedes, cinco espacios y un usuario
demo) se cargan con `SEED_ON_STARTUP=true`.

### App

```bash
cd app
flutter create .              # completa las carpetas nativas que faltan (no toca lib/ ni test/)
flutter pub get
flutter run                   # por defecto, contra la API desplegada en Render
```

Sin `--dart-define`, la app apunta a `https://clubsebastianmartinezamaray-api.onrender.com`, así que
la demo funciona sin acordarse de ninguna bandera. Para un backend local se pasa el valor a mano:
`--dart-define=API_BASE_URL=http://10.0.2.2:8000` (`10.0.2.2` es la forma de llegar a la máquina
anfitriona desde el emulador de Android).

## Tests

```bash
# Backend: 127 tests (reglas de negocio, validaciones de perfil, errores, concurrencia, scheduler y zona horaria)
cd backend && DATABASE_URL=postgresql+psycopg2://test:test@localhost:55432/club_test .venv/bin/pytest -q
# en la última corrida pasaron los 127; uno de ellos depende de la hora a la que se corra

# App
cd app && flutter test
```

## Despliegue

La API y la base de datos van a la nube (Render), según lo que pide la consigna. Está desplegada en
<https://clubsebastianmartinezamaray-api.onrender.com> (Swagger en `/docs`), con PostgreSQL administrado
por la misma plataforma. El repositorio incluye `backend/render.yaml` como Blueprint: Render crea el
servicio web y la base PostgreSQL, e inyecta `DATABASE_URL`. Los pasos están en
[`backend/README.md`](backend/README.md#5-despliegue-en-render-api--postgresql).

El plan gratuito duerme el servicio a los 15 minutos sin tráfico, así que la primera petición después
de eso tarda alrededor de un minuto.

## Alcance y decisiones

- **Autenticación con JWT propio** (contraseñas con bcrypt): no depende de cuentas externas y se puede
  mostrar funcionando en la defensa. El backend tiene además un modo opcional con ID tokens de Firebase
  Auth, apagado por defecto (`AUTH_PROVIDER=firebase`).
- **Notificaciones push**: circuito completo y probado con un envío real al teléfono. La app
  (`firebase_core` + `firebase_messaging`, proyecto `club-smartinez-amaray`) registra su token en
  `POST /devices` al iniciar sesión y lo refresca solo; el backend firma con la cuenta de servicio
  (`FCM_SERVICE_ACCOUNT_JSON`) y envía por FCM HTTP v1. El job que detecta las reservas próximas
  (ventana de una hora, comparada como fecha y hora, y sin repetir un aviso ya enviado) **corre solo**:
  un loop interno de la API lo ejecuta cada 60 s, y su estado se ve en `/health` (`runs`,
  `last_run_at`, `last_result`). Si la credencial de FCM no está cargada, registra la intención sin fallar.
- **Disponibilidad de reservas**: la validación y la inserción son atómicas (bloqueo de la fila del
  espacio), así que dos pedidos simultáneos del mismo horario no pueden crear dos reservas.
- **Zona horaria**: las reservas son horas de pared de la sede. El backend usa `TIMEZONE`
  (`America/Argentina/Buenos_Aires` por defecto) porque el servidor de Render corre en UTC.
