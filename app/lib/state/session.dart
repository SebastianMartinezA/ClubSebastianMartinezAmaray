import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/api_error.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';

/// Status of the session, used by the splash screen to decide where to go.
enum SessionStatus {
  /// Still reading the persisted session.
  unknown,

  /// Nobody is logged in (or the session expired).
  unauthenticated,

  /// There is a stored session.
  authenticated,
}

/// Session state shared through `provider`.
///
/// It wraps `AuthService` and notifies the widgets when the user logs in or
/// out. It also reacts to `401` answers coming from the API (expired token):
/// the session is closed and the UI returns to the login screen.
class Session extends ChangeNotifier {
  Session({
    required ApiClient api,
    required AuthService auth,
    required PushService push,
  })  : _api = api,
        _auth = auth,
        _push = push {
    _api.onUnauthorized = _handleUnauthorized;
  }

  final ApiClient _api;
  final AuthService _auth;
  final PushService _push;

  SessionStatus _status = SessionStatus.unknown;
  User? _user;

  SessionStatus get status => _status;

  User? get user => _user;

  bool get isAuthenticated => _status == SessionStatus.authenticated;

  ApiClient get api => _api;

  AuthService get auth => _auth;

  /// Reads the session stored on the device. Called by the splash screen.
  Future<bool> restore() async {
    final bool restored = await _auth.restore();
    if (restored) {
      _user = _auth.user;
      _status = SessionStatus.authenticated;
      // The token may be valid but the cached user may be stale.
      unawaited(_refreshUser());
    } else {
      _status = SessionStatus.unauthenticated;
    }
    notifyListeners();
    return restored;
  }

  /// Login. Throws `ApiException` so the screen can show the exact message.
  Future<void> signIn({required String email, required String password}) async {
    _user = await _auth.login(email: email, password: password);
    _status = SessionStatus.authenticated;
    notifyListeners();
    unawaited(_push.syncTokenAfterLogin());
  }

  /// Registration; the API logs the user in, so the session starts here too.
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    DateTime? birthDate,
  }) async {
    _user = await _auth.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
    );
    _status = SessionStatus.authenticated;
    notifyListeners();
    unawaited(_push.syncTokenAfterLogin());
  }

  /// Goes back to the login screen.
  Future<void> signOut() async {
    await _auth.logout();
    _user = null;
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  /// Re-reads the profile from `GET /users/me`.
  Future<void> refreshUser() async {
    await _refreshUser();
    notifyListeners();
  }

  /// Updates the cached profile after `PATCH /users/me`.
  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  Future<void> _refreshUser() async {
    try {
      _user = await _auth.fetchProfile();
    } on ApiException {
      // Offline or token no longer valid: the cached user stays in memory and
      // the 401 hook takes care of closing the session when needed.
    }
  }

  void _handleUnauthorized() {
    if (_status == SessionStatus.authenticated) {
      unawaited(signOut());
    }
  }

  @override
  void dispose() {
    _api.onUnauthorized = null;
    super.dispose();
  }
}
