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

## 3. Correr y verificar

```bash
flutter analyze             # resultado esperado: 0 problemas (ver la nota de abajo)
flutter test                # 17 archivos de tests
flutter run                 # con el backend levantado
```

Los tests cubren modelos, servicios (con un cliente HTTP simulado), utilidades, el estado de sesión y
cuatro pantallas. Se escribieron pero **no se pudieron ejecutar** en el servidor donde se armó el
proyecto, porque no hay SDK de Flutter para Linux ARM64: la primera corrida de `flutter test` es tuya.
Lo mismo con `flutter analyze` sobre la capa de interfaz: en ese servidor solo se verificó la sintaxis
de los 44 archivos `.dart` y el tipado completo de la capa que no es de interfaz (modelos, servicios,
estado y utilidades), con los paquetes reales. **`flutter analyze` con 0 problemas es el resultado
esperado, no algo comprobado**: en el servidor donde se armó el proyecto no se pudo correr, así que
esa verificación queda pendiente hasta que lo ejecutes en una máquina con el SDK de Flutter.

## 4. Activar las notificaciones push (opcional)

Vienen apagadas para que el proyecto compile sin depender de una cuenta externa.

1. En `pubspec.yaml`, descomentá `firebase_core` y `firebase_messaging`.
2. En la consola de Firebase, registrá la app Android con el package
   `ar.unimoron.club_sebastian_martinez_amaray` y bajá `google-services.json` a `android/app/`.
3. En `android/app/build.gradle.kts`, aplicá el plugin de Google Services.
4. En `lib/services/push_service.dart`, cambiá `isEnabled` para que devuelva `true`.

Con eso la app registra el token del dispositivo contra `POST /devices` al iniciar sesión, y el job de
reservas próximas del backend le manda el aviso.

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
test/         17 archivos: modelos, servicios, utilidades, estado y pantallas
android/      proyecto Android escrito a mano (manifest, gradle, MainActivity, íconos)
tool/         generate_icons.py: el script con el que se generó el ícono
docs/         icon-preview.png
```
