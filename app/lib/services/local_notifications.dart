import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Muestra en pantalla los avisos que llegan con la app **abierta**.
///
/// FCM auto-muestra la notificación sólo cuando la app está en segundo plano o
/// cerrada. En primer plano el mensaje llega al callback `onMessage` y, sin este
/// servicio, no se ve nada aunque el envío haya funcionado. Acá se publica como
/// notificación local con el mismo título y texto que manda el backend.
class LocalNotifications {
  LocalNotifications();

  static const String channelId = 'club_avisos';
  static const String channelName = 'Avisos de reservas';
  static const String channelDescription =
      'Recordatorio de la reserva que está por empezar.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Prepara el canal de Android y engancha el listener de primer plano.
  ///
  /// Es idempotente y nunca lanza: si el permiso o el canal fallan, la app
  /// sigue funcionando y el push en segundo plano no se ve afectado.
  Future<void> init() async {
    if (_ready || kIsWeb) {
      return;
    }
    try {
      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: android),
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        ),
      );

      FirebaseMessaging.onMessage.listen(_show);
      _ready = true;
    } catch (error) {
      debugPrint('[push] avisos locales desactivados: $error');
    }
  }

  Future<void> _show(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    final String title = notification?.title ??
        message.data['title'] as String? ??
        'Club Sebastián Martínez Amaray';
    final String body = notification?.body ??
        message.data['body'] as String? ??
        'Tenés una reserva por empezar.';

    try {
      await _plugin.show(
        0,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      debugPrint('[push] aviso mostrado en primer plano: ${message.messageId}');
    } catch (error) {
      debugPrint('[push] no se pudo mostrar el aviso: $error');
    }
  }
}
