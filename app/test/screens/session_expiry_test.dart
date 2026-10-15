import 'package:club_sebastian_martinez_amaray/screens/home_screen.dart';
import 'package:club_sebastian_martinez_amaray/screens/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_helpers.dart';

/// B1: a `401` mid-use (expired or invalid token) must close the session AND
/// take the user back to the login screen, clearing the navigation stack.
///
/// These tests cannot run on the server where the project was written (no
/// Flutter SDK for Linux ARM64); they run with `flutter test` on a machine with
/// Flutter >= 3.27.
void main() {
  /// Fake backend with a switch that makes every authenticated request fail
  /// with an expired token, which is what the app sees when the session dies
  /// while a protected screen is open.
  bool tokenExpired = false;

  Future<http.Response> backend(http.Request request) async {
    if (request.url.path == '/auth/login') {
      return jsonResponse(tokenResponseJson());
    }
    if (tokenExpired) {
      return errorResponse(
        401,
        'El token expiró. Volvé a iniciar sesión.',
        'token_expired',
      );
    }
    return jsonResponse(<Object>[]);
  }

  testWidgets('tras un 401 en medio del uso vuelve a la pantalla de login',
      (WidgetTester tester) async {
    tokenExpired = false;
    final TestApp app = TestApp(backend);
    await app.signIn();

    // A protected screen is open and showing the profile of the user.
    await tester.pumpWidget(app.wrap(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Hola, María'), findsOneWidget);

    // The token expires: the next authenticated request answers 401.
    tokenExpired = true;
    try {
      await app.reservations.current();
    } catch (_) {
      // expected: the ApiException also triggers the return to the login.
    }
    await tester.pumpAndSettle();

    // The login screen is what is visible now, and the session is closed.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(app.session.isAuthenticated, isFalse);
    expect(app.session.user, isNull);
  });

  testWidgets('varios 401 simultáneos apilan una sola pantalla de login',
      (WidgetTester tester) async {
    tokenExpired = false;
    final TestApp app = TestApp(backend);
    await app.signIn();

    await tester.pumpWidget(app.wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    tokenExpired = true;
    // Two requests fail with 401 at (almost) the same time.
    await Future.wait<void>(<Future<void>>[
      _swallow(app.reservations.current()),
      _swallow(app.reservations.current()),
    ]);
    await tester.pumpAndSettle();

    // Only one login screen: the second 401 must not push another one.
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}

/// Runs [future] and swallows its error: the call is expected to fail with the
/// expired-token `ApiException`; the test checks the side effect (the return to
/// the login screen), not the failure.
Future<void> _swallow(Future<Object?> future) async {
  try {
    await future;
  } catch (_) {
    // expected
  }
}
