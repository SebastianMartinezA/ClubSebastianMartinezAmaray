import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_navigator.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/catalog_service.dart';
import 'services/device_service.dart';
import 'services/local_notifications.dart';
import 'services/push_service.dart';
import 'services/reservation_service.dart';
import 'services/session_storage.dart';
import 'state/session.dart';
import 'theme/app_theme.dart';

/// Runs when a data message arrives with the app in the background or closed.
/// FCM shows `notification` payloads by itself; this keeps the isolate alive so
/// the message is not dropped.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[push] mensaje en segundo plano: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is initialised from `android/app/google-services.json`. If it is
  // missing the app still starts: push stays disabled and everything else works
  // (that is what the Linux desktop build does).
  bool pushEnabled = false;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    pushEnabled = true;
  } catch (error) {
    debugPrint('[push] Firebase no inicializó, push desactivado: $error');
  }

  // Manual dependency injection: one instance of each service, created once
  // (simple enough to explain in the oral defence, no code generation).
  final ApiClient api = ApiClient();
  final SessionStorage storage = SharedPreferencesSessionStorage();
  final AuthService auth = AuthService(api: api, storage: storage);
  final CatalogService catalog = CatalogService(api);
  final ReservationService reservations = ReservationService(api);
  final DeviceService devices = DeviceService(api);
  final PushService push =
      PushService(deviceService: devices, enabled: pushEnabled);
  final Session session = Session(api: api, auth: auth, push: push);

  // The free tier of Render sleeps the service after 15 minutes without
  // requests and the first one takes close to a minute; waking it up here,
  // while the user looks at the splash screen, keeps that first request from
  // dying on the 15 second timeout. The result is ignored on purpose: if the
  // service does not wake up, the screen that made the real request shows the
  // error a few seconds later.
  // Con la app abierta, FCM entrega el mensaje pero Android no muestra nada:
  // este servicio lo publica como notificación local. Si el permiso o el canal
  // fallan, el push sigue funcionando en segundo plano como antes.
  if (pushEnabled) {
    await LocalNotifications().init();
  }

  unawaited(api.warmUp());

  // When a `401` arrives (expired or invalid token) the session closes itself;
  // this hook is what actually takes the user back to the login screen. It uses
  // the global `appNavigatorKey` because a `401` can surface from any service,
  // with no widget (and so no `BuildContext`) at hand. See app_navigator.dart.
  session.onSessionExpired = goToLogin;

  runApp(
    ClubApp(
      session: session,
      catalog: catalog,
      reservations: reservations,
    ),
  );
}

/// Root widget: providers + MaterialApp.
class ClubApp extends StatelessWidget {
  const ClubApp({
    super.key,
    required this.session,
    required this.catalog,
    required this.reservations,
  });

  final Session session;
  final CatalogService catalog;
  final ReservationService reservations;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<Session>.value(value: session),
        Provider<CatalogService>.value(value: catalog),
        Provider<ReservationService>.value(value: reservations),
      ],
      child: MaterialApp(
        title: 'Club Sebastián Martínez Amaray',
        debugShowCheckedModeBanner: false,
        // Global key used by `goToLogin` (via `Session.onSessionExpired`) to
        // send the user back to the login screen after a `401`.
        navigatorKey: appNavigatorKey,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        locale: const Locale('es', 'AR'),
        supportedLocales: const <Locale>[
          Locale('es', 'AR'),
          Locale('en'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SplashScreen(),
      ),
    );
  }
}
