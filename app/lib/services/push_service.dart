import 'package:flutter/foundation.dart';

import 'device_service.dart';

/// Push notifications hook.
///
/// Firebase Cloud Messaging is deliberately **not** a dependency of this
/// project: the assignment is graded without a Firebase project and the app has
/// to build and run out of the box. This class is the single place where the
/// integration is wired, so enabling notifications is a matter of following the
/// steps of the README and uncommenting the block below.
///
/// Where the token has to be sent: `POST /devices`
/// (`{"token": "...", "platform": "android"}`), after every login and after
/// every token refresh.
class PushService {
  PushService({required DeviceService deviceService}) : _devices = deviceService;

  final DeviceService _devices;

  /// Flips to `true` once `firebase_core` / `firebase_messaging` are added.
  bool get isEnabled => false;

  /// Platform name stored by the backend (`android`, `ios`...).
  String get platform => _platformName();

  /// Called after a successful login/registration.
  ///
  /// With Firebase disabled it does nothing; see the commented implementation
  /// for the exact code to enable.
  Future<bool> syncTokenAfterLogin() async {
    if (!isEnabled) {
      return false;
    }

    // ---------------------------------------------------------------------
    // Enabled implementation (requires firebase_core + firebase_messaging):
    //
    // await FirebaseMessaging.instance.requestPermission();
    // final String? token = await FirebaseMessaging.instance.getToken();
    // if (token != null && token.isNotEmpty) {
    //   await _devices.register(token: token, platform: platform);
    //   // Keep the token fresh once the app is running:
    //   FirebaseMessaging.instance.onTokenRefresh.listen(
    //     (String fresh) => _devices.register(token: fresh, platform: platform),
    //   );
    //   return true;
    // }
    // ---------------------------------------------------------------------
    return false;
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
