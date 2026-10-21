import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'device_service.dart';

/// Push notifications hook (Firebase Cloud Messaging).
///
/// The app is registered in the Firebase project `club-smartinez-amaray`
/// (`app/android/app/google-services.json`), so `main.dart` initialises
/// Firebase and builds this service with `enabled: true`. Tests build it with
/// the default (`false`) and never touch the Firebase SDK.
///
/// Where the token goes: `POST /devices`
/// (`{"token": "...", "platform": "android"}`), after every login/registration
/// and again on every token refresh.
class PushService {
  PushService({
    required DeviceService deviceService,
    bool enabled = false,
  })  : _devices = deviceService,
        _enabled = enabled;

  final DeviceService _devices;
  final bool _enabled;

  bool _listeningRefresh = false;

  /// `true` only when Firebase was initialised successfully at startup.
  bool get isEnabled => _enabled;

  /// Platform name stored by the backend (`android`, `ios`...).
  String get platform => _platformName();

  /// Called after a successful login/registration.
  ///
  /// Returns `true` when a token was obtained and registered. Any Firebase or
  /// network failure returns `false`: a push token is never a reason to break
  /// the login flow.
  Future<bool> syncTokenAfterLogin() async {
    if (!_enabled) {
      return false;
    }

    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final String? token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        return false;
      }
      await _devices.register(token: token, platform: platform);
      _listenToTokenRefresh(messaging);
      return true;
    } catch (error) {
      debugPrint('[push] no se pudo registrar el token: $error');
      return false;
    }
  }

  /// Keeps the token fresh once the app is running: FCM can rotate it.
  void _listenToTokenRefresh(FirebaseMessaging messaging) {
    if (_listeningRefresh) {
      return;
    }
    _listeningRefresh = true;
    messaging.onTokenRefresh.listen((String fresh) async {
      try {
        await _devices.register(token: fresh, platform: platform);
      } catch (error) {
        debugPrint('[push] no se pudo actualizar el token: $error');
      }
    });
  }

  /// Manual registration, useful to test the `POST /devices` endpoint with a
  /// token copied by hand (for instance from the Firebase console).
  Future<void> registerManualToken(String token) async {
    await _devices.register(token: token, platform: platform);
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    }
    return defaultTargetPlatform.name.toLowerCase();
  }
}
