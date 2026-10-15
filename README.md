# ClubSebastianMartinezAmaray

Trabajo práctico de **Electiva General (3349)** — Unimoron. Aplicación móvil para la gestión de
espacios deportivos: reservar desde el celular, consultar la disponibilidad de espacios de distintas
sedes y recibir notificaciones de reservas próximas.

El repositorio se llama como pide la consigna: `Club` + nombre y apellido del alumno.

## Qué hay acá

```
backend/      API REST (Python 3.11 + FastAPI + PostgreSQL + SQLAlchemy 2.0) con Swagger/OpenAPI
app/          Aplicación móvil en Flutter, conectada a la API
verificacion/ Evidencia de las pruebas: salidas reales de curl y prueba de concurrencia
```

- **Backend** → [`backend/README.md`](backend/README.md) · Swagger en `/docs` · esquema en `/openapi.json`
- **App** → [`app/README.md`](app/README.md)
- **Diseño** (paleta medida del prototipo de Figma, componentes y tipografía) → [`docs/design-system.md`](docs/design-system.md)
- **Guía de defensa** (arquitectura, decisiones y guion de la demo) → [`docs/guia-defensa.md`](docs/guia-defensa.md)
- **Modelo de datos** (entidades, atributos y relaciones) → [`backend/docs/modelo-datos.md`](backend/docs/modelo-datos.md)
- **Endpoints** con ejemplos → [`backend/docs/api.md`](backend/docs/api.md)
- **Evidencia de verificación** (salidas reales de `curl` y de la prueba de concurrencia) →
  [`verificacion/`](verificacion/)
- **Verificación contra la API desplegada** (26 casos, incluida la reserva simultánea y el aislamiento
  entre usuarios) → [`verificacion/e2e-nube.txt`](verificacion/e2e-nube.txt), se reproduce con
  `python3 verificacion/e2e-nube.py`

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
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

`10.0.2.2` es la forma de llegar a la máquina anfitriona desde el emulador de Android. Para apuntar a
la API desplegada, se cambia el valor de `API_BASE_URL`.

## Tests

```bash
# Backend: 92 tests (reglas de negocio, errores, concurrencia y zona horaria)
cd backend && DATABASE_URL=postgresql+psycopg2://test:test@localhost:55432/club_test .venv/bin/pytest -q

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
- **Notificaciones push**: la API registra los tokens de dispositivo y tiene el job que detecta las
  reservas próximas. El envío real por Firebase Cloud Messaging se activa cuando hay credenciales
  (`FCM_SERVICE_ACCOUNT_JSON`); sin ellas, el job registra la intención y no falla.
- **Disponibilidad de reservas**: la validación y la inserción son atómicas (bloqueo de la fila del
  espacio), así que dos pedidos simultáneos del mismo horario no pueden crear dos reservas.
- **Zona horaria**: las reservas son horas de pared de la sede. El backend usa `TIMEZONE`
  (`America/Argentina/Buenos_Aires` por defecto) porque el servidor de Render corre en UTC.
