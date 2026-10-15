import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

/// Key of the app's `Navigator`, installed on the `MaterialApp` of `main.dart`.
///
/// Why a global key: an expired token is detected deep inside `ApiClient` (see
/// `ApiException.isSessionExpired`), far from the widget that is on screen, and
/// at that point there is no `BuildContext` to navigate with. The key lets the
/// session jump back to the login screen from anywhere, without threading a
/// `BuildContext` down through the services — which would couple the HTTP and
/// state layers to the UI. `main.dart` owns it because that is where the
/// `MaterialApp` is built; the widget tests install the same key on their
/// `MaterialApp` so the flow can be exercised without the Flutter SDK.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Route that [goToLogin] pushed, and the navigator it was pushed on, kept so
/// that several requests failing with a `401` at the same time push the login
/// screen only once.
MaterialPageRoute<void>? _loginRoute;
NavigatorState? _loginNavigator;

/// True while [goToLogin] is running, to swallow re-entrant calls.
bool _returningToLogin = false;

/// Closes the session UI after a `401`: clears the whole navigation stack and
/// shows the login screen.
///
/// `Session` calls this (through its `onSessionExpired` hook) when the API
/// rejects the token, so the user never stays on a protected screen with an
/// empty profile.
///
/// It is a no-op when there is no navigator yet, when another call is already
/// doing it, or when the login screen is already on top. `pushAndRemoveUntil`
/// blows away the whole stack, so a dialog that happened to be open when the
/// token expired is closed too: the login is never left *behind* a dialog and
/// the user cannot go "back" to a screen that needs a session that no longer
/// exists.
void goToLogin() {
  final NavigatorState? navigator = appNavigatorKey.currentState;
  if (navigator == null || _returningToLogin) {
    return;
  }
  if (identical(_loginNavigator, navigator) &&
      _loginRoute != null &&
      _loginRoute!.isCurrent) {
    // The login screen is already showing on this navigator: do not stack
    // another one on top (two or more requests can fail with `401` at almost
    // the same time).
    return;
  }
  _returningToLogin = true;
  final MaterialPageRoute<void> loginRoute = MaterialPageRoute<void>(
    builder: (BuildContext _) => const LoginScreen(),
  );
  _loginRoute = loginRoute;
  _loginNavigator = navigator;
  navigator.pushAndRemoveUntil(loginRoute, (Route<dynamic> route) => false);
  _returningToLogin = false;
}
