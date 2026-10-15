# Guía de defensa — Entrega 2 (ClubSebastianMartinezAmaray)

Material para la exposición oral del martes 27/10 a las 19:40. No es para leer en voz alta: es para
estudiar y tener a mano las respuestas. Todo lo que dice acá está implementado y verificado en el
código que se entrega.

---

## 1. Qué es el sistema, en dos frases

Una aplicación móvil para reservar espacios deportivos en distintas sedes. El usuario se registra,
mira qué turnos están libres en cada sede, reserva un turno, ve sus reservas y las cancela. Detrás hay
una API REST propia con una base de datos PostgreSQL, las dos desplegadas en la nube.

Arquitectura, de afuera hacia adentro:

```
App Flutter (Android)  →  HTTPS  →  API REST (FastAPI, contenedor en Render)  →  PostgreSQL (Render)
     JWT en cada request              reglas de negocio y validaciones            6 tablas
```

---

## 2. Backend

### Stack y por qué

| Pieza | Elección | Por qué |
|---|---|---|
| Lenguaje | Python 3.11 | La consigna lo recomienda y es lo que más se usa para APIs rápidas |
| Framework | FastAPI | Genera la documentación Swagger/OpenAPI sola, valida los datos con Pydantic y es asíncrono |
| Base de datos | PostgreSQL | Es relacional, como pide la consigna, y soporta transacciones y bloqueo de filas, que es lo que resuelve el problema de las reservas simultáneas |
| ORM | SQLAlchemy 2.0 | Modela las tablas como clases y evita escribir SQL a mano |
| Autenticación | JWT propio con bcrypt | No depende de cuentas externas y se puede mostrar entero en la defensa: el token se firma y se verifica en el servidor |

### Estructura de carpetas (y qué hace cada una)

```
backend/app/
  main.py       # arma la app, CORS, manejadores de error, conecta los routers
  config.py     # toda la configuración por variables de entorno
  database.py   # motor de conexión, sesión y Base de los modelos
  models.py     # las 6 tablas del modelo de datos
  schemas.py    # qué entra y qué sale en cada endpoint (Pydantic)
  security.py   # hash de contraseñas, creación y verificación del JWT
  clock.py      # "ahora" en la zona horaria de las sedes
  errors.py     # excepciones propias y el formato único de error
  seed.py       # datos de ejemplo: 2 sedes, 5 espacios, 1 usuario demo
  routers/      # los endpoints agrupados por tema
  services/     # las reglas de negocio de reservas y las notificaciones
```

La separación importante es `routers/` contra `services/`: los routers solo reciben el pedido y
devuelven la respuesta; las reglas de negocio viven en `services/reservations.py`, así se pueden
testear sin pasar por HTTP.

### Modelo de datos

Seis tablas. Detalle con diagrama en [`modelo-datos.md`](modelo-datos.md).

- `users`: email (único), contraseña hasheada con bcrypt, nombre, apellido, fecha de nacimiento, activo.
- `venues` (sedes): nombre, dirección, hora de apertura y de cierre.
- `sport_spaces` (espacios): pertenece a una sede, tiene tipo (Fútbol, Paddle, Básquet), número y un
  nombre armado como `Sede_Direccion_Tipo_Numero`, por ejemplo `Moron_Rivadavia_19850_Paddle_1`.
- `reservations`: usuario, espacio, fecha, hora de inicio, hora de fin y estado (`active` o `cancelled`).
- `password_reset_tokens`: token de recuperación (se guarda el hash, nunca el token), vencimiento y si
  ya se usó.
- `device_tokens`: los tokens de dispositivo para las notificaciones push.

Relaciones: una sede tiene muchos espacios, un espacio tiene muchas reservas, un usuario tiene muchas
reservas. Todas las claves foráneas borran en cascada.

Decisiones que el profesor puede preguntar:

- **El correo es único y se normaliza a minúsculas**: así `Juan@Ejemplo.com` y `juan@ejemplo.com` no
  pueden ser dos cuentas distintas.
- **El correo no se puede editar** en el perfil (lo pide la consigna): el endpoint responde 400.
- **La reserva cancelada no se borra**, cambia de estado. Así queda el historial y el horario se libera
  igual, porque la validación de solapamiento solo mira las reservas activas.
- **La fecha y las horas se guardan separadas** (columna `date` y dos columnas `time`), no como un
  timestamp, porque los turnos son horas de pared de la sede.

### Las reglas de negocio de las reservas

Están todas en `services/reservations.py` y cada una tiene su test. En el orden en que se validan:

1. La hora de inicio tiene que ser anterior a la de fin.
2. Duración mínima de una hora.
3. Las horas tienen que ser en punto (minuto y segundo en 00).
4. El turno tiene que caer dentro del horario de la sede: no empezar antes de la apertura ni terminar
   después del cierre.
5. La reserva tiene que ser futura respecto del momento en que se hace.
6. No puede solaparse con otra reserva activa del mismo espacio y la misma fecha. Dos intervalos se
   solapan si `inicio < otro_fin` y `fin > otro_inicio`, que es más general que comparar si son iguales.
7. Cancelar libera el horario.
8. El historial incluye las reservas terminadas y las canceladas, con su estado.

### El problema difícil: dos personas reservando el mismo turno a la vez

Esto es lo que más vale la pena mostrar en la defensa.

Si dos pedidos llegan al mismo tiempo, los dos pueden consultar "¿está libre?" y los dos recibir "sí"
antes de que ninguno haya guardado nada. Terminan creadas dos reservas en el mismo horario.

Cómo se resolvió: **la validación y el guardado son una sola operación**. Cuando llega un pedido, el
servidor primero bloquea la fila del espacio (`SELECT ... FOR UPDATE`). El segundo pedido queda
esperando en ese bloqueo hasta que el primero termina de guardar y confirma la transacción. Recién ahí
evalúa el solapamiento, ahora sí ve la reserva del primero, y responde 409 en vez de crear otra.

En la base queda una sola reserva. Está probado de dos maneras: en el test `test_dos_reservas_simultaneas_dejan_una_sola`
(con dos pedidos concurrentes reales) y con la prueba de concurrencia contra el servidor corriendo
([`verificacion/concurrencia.txt`](../../verificacion/concurrencia.txt)): dos pedidos simultáneos, un
201 y un 409, una sola fila activa.

### El otro problema difícil: la zona horaria

En Render el contenedor corre en UTC, que son tres horas más que Argentina. Si el backend compara
contra la hora del servidor, a las 21:00 de Argentina ya cree que son las 00:00 del día siguiente y
rechaza como "pasada" una reserva de las 22:00.

Solución: `app/clock.py` define "ahora" con la zona horaria configurada (`TIMEZONE`, por defecto
`America/Argentina/Buenos_Aires`) y todas las validaciones usan eso. Hay dos tests que lo fijan y el
Dockerfile instala `tzdata` para que la zona exista dentro del contenedor.

### Seguridad

- Las contraseñas se guardan hasheadas con bcrypt, nunca en texto plano.
- El JWT se firma con una clave secreta que vive en las variables de entorno del servicio, no en el
  repositorio. Cada request protegido manda `Authorization: Bearer <token>`.
- Cada operación de reservas identifica al usuario autenticado: nadie puede listar, ver ni cancelar la
  reserva de otro (devuelve 403), y las reservas se filtran siempre por el usuario del token.
- La recuperación de contraseña usa un token aleatorio de un solo uso, con vencimiento de 30 minutos,
  y en la base se guarda solo su hash. Un segundo intento con el mismo token da 400.
- El login incorrecto devuelve el mismo mensaje exista o no el correo, para no filtrar qué cuentas hay.

### Manejo de errores

Todos los errores tienen el mismo cuerpo, con el status correcto:

```json
{ "detail": "El espacio ya está reservado en ese horario.", "code": "space_not_available" }
```

- 400: validación (duración, minutos, horario de la sede, fecha pasada)
- 401: falta el token, es inválido o expiró; login incorrecto
- 403: el recurso es de otro usuario
- 404: no existe
- 409: correo ya registrado, horario ya reservado
- 500: error interno, sin filtrar detalles

El `code` es para que la app pueda reaccionar sin depender del texto.

---

## 3. Documentación de la API (Swagger)

FastAPI genera la documentación sola desde el código: `/docs` (Swagger UI, se prueba desde el
navegador) y `/openapi.json` (el esquema). No hay que mantenerla a mano, y por eso no puede quedar
desactualizada respecto de los endpoints.

Todas las operaciones usan la autenticación por Bearer token, y se puede probar el flujo entero desde
`/docs`: registrar, loguearse, autorizar y reservar.

---

## 4. Notificaciones push

- La app registra el token del dispositivo con `POST /devices` cuando el usuario inicia sesión.
- El backend tiene un job de reservas próximas (`python -m app.services.notifications`): busca las
  reservas activas que empiezan dentro de la próxima hora y les manda el aviso a los dispositivos del
  dueño.
- El envío real usa Firebase Cloud Messaging por HTTP v1. Si no hay credenciales configuradas, el job
  registra la intención en el log y no falla, así el sistema no se rompe por una credencial ausente.

---

## 5. Despliegue en la nube

- **API**: servicio web con Docker en Render, construido desde el repositorio.
- **Base de datos**: PostgreSQL administrado por Render. La cadena de conexión la inyecta la plataforma
  como variable de entorno; el backend la normaliza porque Render la entrega con el prefijo
  `postgres://` y SQLAlchemy necesita el driver explícito.
- **Variables de entorno**: `DATABASE_URL`, `JWT_SECRET_KEY` (generada aparte, no está en el repo),
  `TIMEZONE`, `AUTO_CREATE_TABLES`, `SEED_ON_STARTUP`, `CORS_ORIGINS`.
- El contenedor escucha en el puerto que Render define por su cuenta (`$PORT`) y tiene un healthcheck
  contra `/health`.
- El mismo repositorio incluye `render.yaml`, el blueprint que crea los dos recursos de una sola vez.

---

## 6. Guion de la demo (para no improvisar)

1. Mostrar la API desplegada: abrir `https://<servicio>.onrender.com/docs` y señalar el listado de
   endpoints agrupados.
2. Registrar un usuario nuevo desde la app (o desde `/docs`), mostrando la validación del formulario.
3. Iniciar sesión: mostrar que el home saluda al usuario.
4. Abrir el listado de sedes y entrar a una: mostrar el nombre, la dirección y el horario de
   funcionamiento.
5. Elegir un espacio, elegir la fecha y ver los turnos libres u ocupados.
6. Reservar un turno. Después, intentar reservar el mismo horario en el mismo espacio: tiene que
   aparecer el mensaje de que el horario se ocupó (409). Esa es la validación de solapamiento en vivo.
7. Mostrar "Mis reservas" con el turno recién creado, cancelarlo y volver a reservarlo para probar que
   se liberó.
8. Abrir el historial y mostrar la reserva cancelada distinguida por estado.
9. Abrir el perfil, editar el nombre y mostrar que el correo está deshabilitado.
10. Si hay conexión: mostrar la notificación push de una reserva próxima.

Plan B si falla internet en el aula: correr la API en la notebook con `uvicorn` y apuntar la app al
`localhost` de la máquina, con la base local en Docker. Los pasos están en el README.

---

## 7. Preguntas probables y respuestas cortas

**¿Por qué FastAPI y no Flask o Django?**
Porque genera la documentación OpenAPI sola, valida los datos de entrada automáticamente y es rápido
de escribir. Django trae mucho que acá no se usa; Flask no trae la validación ni la documentación.

**¿Por qué no usaste Firebase para el login?**
El login funciona con JWT propio, que se puede mostrar y explicar completo. El backend tiene además un
modo alternativo que valida los tokens de Firebase Auth (se activa con una variable de entorno), pero
sin depender de una cuenta externa el trabajo se puede correr y corregir en cualquier máquina.

**¿Cómo evitás que se reserven dos veces el mismo horario?**
Con el bloqueo de la fila del espacio dentro de la transacción, y validando el solapamiento antes del
insert, ya con el bloqueo tomado. Lo probé con dos pedidos simultáneos.

**¿Por qué la duración mínima y las horas en punto?**
Porque lo pide la consigna: los turnos son de una hora como mínimo y en horas completas, así la grilla
de disponibilidad es simple y no hay turnos de 40 minutos.

**¿Qué pasa si dos sedes están en provincias distintas con otra hora?**
Hoy el sistema asume una zona horaria configurable para todas las sedes (`TIMEZONE`). Si hiciera falta
una por sede, se agrega una columna en `venues` y el reloj se resuelve por sede.

**¿Dónde está el modelo de datos?**
En `backend/docs/modelo-datos.md`, con el diagrama entidad-relación y el detalle de cada tabla.

**¿Cómo se despliega un cambio?**
Se hace push al repositorio y Render vuelve a construir y desplegar el servicio.

**¿Qué falta o qué mejorarías?**
Pagos de las reservas, una zona horaria por sede, recuperación de contraseña por email real (hoy el
token sale por log o por SMTP si se configura) y roles de administrador para gestionar sedes y espacios
desde la app.
