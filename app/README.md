# ClubSebastianMartinezAmaray — App Flutter

Aplicación móvil del trabajo práctico de Electiva General (3349). Se conecta a la API REST que está en
[`../backend`](../backend) y cubre las once pantallas del trabajo: splash, login, registro,
recuperación de contraseña, home, sedes, detalle de sede con disponibilidad, reserva, mis reservas,
historial y perfil.

El diseño sigue el prototipo de Figma de la Entrega 1: fondo casi negro `#050508`, tarjetas
`#171719`, acento lima `#D4FF00`. La paleta completa y su medición están en
[`../docs/design-system.md`](../docs/design-system.md).

---

## 1. Qué falta antes de compilar (una sola vez)

Este proyecto se escribió en un servidor Linux ARM64, donde **Flutter no publica SDK** (solo hay
binarios para x64, arm64 de macOS y Windows). Por eso la carpeta `android/` viene con los archivos que
se escriben a mano (manifest, gradle, `MainActivity.kt`, íconos y temas), pero **sin los archivos que
genera Flutter**, que hay que regenerar en tu máquina:

```bash
cd app
flutter create .            # no borra nada: agrega gradlew, gradle-wrapper.jar, .metadata
flutter pub get
```

`flutter create .` completa el andamiaje del proyecto y respeta el código existente. Si te pide
confirmación, aceptá: solo agrega los archivos faltantes de la plataforma.

**Ojo con un detalle:** en un Flutter reciente, `flutter create .` también genera
`android/build.gradle.kts`, `android/app/build.gradle.kts` y `android/settings.gradle.kts` al lado de
los `build.gradle` escritos a mano, y borra `test/widget_test.dart` si aparece (apunta al widget raíz de
la plantilla). Gradle prefiere el archivo `.kts` cuando existen los dos, así que si quedan los
duplicados el proyecto deja de compilar los archivos propios. Borrá esos tres `.kts` y quedate con los
`.gradle` del repositorio.

### Versiones que necesita el toolchain

El plugin de Gradle de Flutter valida estas tres versiones antes de aplicar el suyo y corta el build si
alguna queda por debajo del mínimo. El repositorio ya viene con las tres en un valor aceptado:

- **Flutter ≥ 3.27**: `lib/theme/app_theme.dart` usa `CardThemeData`, el tipo que recibe `cardTheme`
  desde esa versión (en 3.24 a 3.26 el mismo objeto se llamaba `CardTheme` y el proyecto no compila).
- **Gradle ≥ 8.14**: `android/gradle/wrapper/gradle-wrapper.properties` está fijado en 8.14.3.
- **Android Gradle Plugin ≥ 8.11.1** y **Kotlin ≥ 2.2.20**: declarados en `android/settings.gradle`.

Con Flutter 3.47.5 y el JDK 17, esta combinación compila. Si actualizás Flutter y el build se queja de
una versión, el mensaje dice el mínimo exacto que pide: se cambia el número en el wrapper o en
`settings.gradle` y se vuelve a intentar.

## 2. Apuntar la app a la API

La dirección de la API se inyecta al compilar, no está en el código:

```bash
# Backend desplegado en la nube (el que se usa para la demo)
flutter run --dart-define=API_BASE_URL=https://<tu-servicio>.onrender.com

# Backend local en la misma computadora (emulador de Android)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Backend local en un teléfono físico (misma red wifi que la computadora)
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
```

Sin `--dart-define`, la app usa `http://10.0.2.2:8000`, que es la dirección con la que el emulador de
Android ve a la computadora que lo hospeda. `10.0.2.2` es el alias del host; en un teléfono real hay
que pasar la IP de la computadora.

El `AndroidManifest.xml` ya trae `INTERNET` y `usesCleartextTraffic="true"`, necesario para hablar con
la API por HTTP en desarrollo. Para producción conviene HTTPS y quitar esa última opción.

Al arrancar, la app pega un `GET /health` en segundo plano mientras se ve el splash, con un timeout
largo (`ApiConfig.warmUpTimeout`, 90 s). Es por el plan gratuito de Render, que duerme el servicio a
los 15 minutos sin tráfico: la primera petición puede tardar cerca de un minuto y con el timeout
normal de 15 s (`ApiConfig.requestTimeout`) el primer login fallaba y parecía un problema de conexión
del teléfono.

## 3. Correr y verificar

```bash
flutter analyze             # resultado: No issues found
flutter test                # 126 tests, todos pasan
flutter build apk --debug   # genera app-debug.apk (65 MB)
flutter run --dart-define=API_BASE_URL=https://<tu-servicio>.onrender.com
```

Los tests cubren modelos, servicios (con un cliente HTTP simulado), utilidades, el estado de sesión y
cuatro pantallas.

Estos comandos **ya se corrieron sobre este mismo código** en una máquina x86_64 con Flutter 3.47.5 y
JDK 17 (Fedora 42): `flutter analyze` no reportó nada, la suite pasó completa (126 tests en 16 archivos
más el helper), se generó el APK de depuración y la app se ejecutó conectada a la API desplegada, con
login y datos reales en pantalla. El proyecto se escribió en un servidor Linux ARM64, donde Flutter no
publica SDK, así que esa corrida se hizo después en otra máquina: por eso `android/` trae los archivos
escritos a mano y no los que genera Flutter.

Si no tenés un emulador o un teléfono a mano, `flutter run -d linux` levanta la misma app en el
escritorio (antes hay que agregar el target con `flutter create --platforms=linux .`): sirve para ver la
interfaz y el camino HTTP sin dispositivo. La carpeta `linux/` que genera ese comando no se versiona,
porque la entrega es una app móvil.

## 4. Notificaciones push (activadas)

El circuito está cerrado y probado de punta a punta: la app está registrada en el proyecto Firebase
`club-smartinez-amaray`, registra su token al iniciar sesión contra `POST /devices`, el backend firma
con la cuenta de servicio y envía por FCM HTTP v1, y el teléfono recibe el aviso.

- `app/android/app/google-services.json` está versionado: es configuración pública del cliente
  (project id, app id y API key restringida por package), no una credencial.
- La clave privada de la cuenta de servicio (`firebase-adminsdk-...json`) **no** va al repo: vive en
  la variable `FCM_SERVICE_ACCOUNT_JSON` del backend.
- `PushService` recibe `enabled: true` desde `main.dart` cuando Firebase inicializa; en tests queda
  apagado y nunca toca el SDK.
- Si Firebase no inicializa (por ejemplo en el build de escritorio Linux), la app arranca igual y el
  push queda desactivado.
- El token se refresca solo: `onTokenRefresh` vuelve a llamar a `POST /devices`.

Para probar el envío sin esperar a que haya una reserva próxima: `GET /devices` con el usuario demo
devuelve el token del teléfono, y con ese token se puede mandar un mensaje de prueba a
`https://fcm.googleapis.com/v1/projects/club-smartinez-amaray/messages:send` usando la cuenta de
servicio.

## 5. Qué no se versiona

- `android/local.properties` lo genera la máquina de cada uno (ruta del SDK de Android).
- `android/app/google-services.json` es tuyo y de tu proyecto de Firebase: está en el `.gitignore`.
- Nada de `.env` ni claves. La app no guarda secretos; solo el token de sesión, y eso va a
  `shared_preferences` en el teléfono.

## 6. Detalle de compatibilidad

El `pubspec.yaml` pide `flutter: ">=3.27.0"` porque `lib/theme/app_theme.dart` usa `CardThemeData`, el
tipo que recibe `cardTheme` desde Flutter 3.27. En versiones anteriores el mismo objeto se llamaba
`CardTheme`; esto es **historial de una decisión**, no algo que haya que cambiar: con el theme actual,
3.24 a 3.26 no compilan.

## 7. Estructura

```
lib/
  app_navigator.dart         navigatorKey global: vuelve al login cuando la API responde 401
  config/     api_config.dart          dirección de la API y timeouts
  models/     los objetos que devuelve la API, con su parseo
  services/   api_client (errores centralizados) + auth, catálogo, reservas, dispositivos, push
  state/      session.dart: sesión con ChangeNotifier (desconocido / sin sesión / con sesión)
  screens/    las 11 pantallas
  widgets/    13 widgets compartidos (tarjetas, chips, grilla de turnos, estados de carga y error)
  theme/      app_theme.dart: paleta y tema material 3, dark
  utils/      formateo de fechas y horas, validadores de formularios
test/         16 archivos de tests (más el helper): 126 tests de modelos, servicios, utilidades, estado y pantallas
android/      proyecto Android escrito a mano (manifest, gradle, MainActivity, íconos)
tool/         generate_icons.py: el script con el que se generó el ícono
docs/         icon-preview.png
```
