import 'package:club_sebastian_martinez_amaray/models/api_error.dart';
import 'package:club_sebastian_martinez_amaray/models/user.dart';
import 'package:club_sebastian_martinez_amaray/services/session_storage.dart';
import 'package:club_sebastian_martinez_amaray/state/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_helpers.dart';

void main() {
  group('signIn', () {
    test('sets the session as authenticated and keeps the user', () async {
      final TestApp app = TestApp(
        (http.Request request) async => jsonResponse(tokenResponseJson()),
      );

      expect(app.session.status, SessionStatus.unknown);

      await app.signIn();

      expect(app.session.status, SessionStatus.authenticated);
      expect(app.session.isAuthenticated, isTrue);
      expect(app.session.user?.firstName, 'María');
      expect(app.api.authToken, isNotNull);
    });

    test('does not change the session when the credentials are wrong',
        () async {
      final TestApp app = TestApp(
        (http.Request request) async => errorResponse(
          401,
          'Correo o contraseña incorrectos.',
          'invalid_credentials',
        ),
      );

      await expectLater(app.signIn(), throwsA(isA<ApiException>()));
      expect(app.session.status, SessionStatus.unknown);
      expect(app.session.user, isNull);
    });
  });

  group('signUp', () {
    test('starts the session with the user of POST /auth/register', () async {
      final TestApp app = TestApp(
        (http.Request request) async =>
            jsonResponse(tokenResponseJson(), statusCode: 201),
      );

      await app.session.signUp(
        email: 'maria@club.com',
        password: 'Secreta123',
        firstName: 'María',
        lastName: 'Lopez',
        birthDate: DateTime(1996, 3, 8),
      );

      expect(app.session.isAuthenticated, isTrue);
      expect(app.session.user?.email, 'maria@club.com');
    });
  });

  group('restore', () {
    test('comes back authenticated with the stored session', () async {
      final InMemorySessionStorage storage = InMemorySessionStorage();
      await storage.save(
        SessionData(token: 'token-guardado', user: userJson()),
      );
      final TestApp app = TestApp(
        (http.Request request) async => jsonResponse(userJson()),
        storage: storage,
      );

      final bool restored = await app.session.restore();

      expect(restored, isTrue);
      expect(app.session.status, SessionStatus.authenticated);
      expect(app.session.user?.email, 'maria@club.com');
      expect(app.api.authToken, 'token-guardado');
    });

    test('comes back unauthenticated without a stored session', () async {
      final TestApp app = TestApp(
        (http.Request request) async => jsonResponse(userJson()),
      );

      final bool restored = await app.session.restore();

      expect(restored, isFalse);
      expect(app.session.status, SessionStatus.unauthenticated);
      expect(app.session.user, isNull);
    });
  });

  group('signOut', () {
    test('forgets the user and the token', () async {
      final TestApp app = TestApp(
        (http.Request request) async => jsonResponse(tokenResponseJson()),
      );
      await app.signIn();

      await app.session.signOut();

      expect(app.session.status, SessionStatus.unauthenticated);
      expect(app.session.user, isNull);
      expect(app.api.authToken, isNull);
    });
  });

  group('expired token', () {
    test('closes the session when the API answers token_expired', () async {
      final TestApp app = TestApp((http.Request request) async {
        if (request.url.path == '/auth/login') {
          return jsonResponse(tokenResponseJson());
        }
        return errorResponse(
          401,
          'El token expiró. Volvé a iniciar sesión.',
          'token_expired',
        );
      });
      await app.signIn();
      expect(app.session.isAuthenticated, isTrue);

      // Any authenticated request now fails with an expired token.
      try {
        await app.reservations.current();
      } catch (_) {
        // expected
      }
      // The hook of ApiClient closes the session asynchronously.
      await Future<void>.delayed(Duration.zero);

      expect(app.session.isAuthenticated, isFalse);
      expect(app.session.user, isNull);
    });
  });

  group('notifications', () {
    test('notifies listeners when the user logs in and out', () async {
      final TestApp app = TestApp(
        (http.Request request) async => jsonResponse(tokenResponseJson()),
      );
      int notifications = 0;
      app.session.addListener(() => notifications++);

      await app.signIn();
      expect(notifications, greaterThanOrEqualTo(1));

      final int afterLogin = notifications;
      await app.session.signOut();
      expect(notifications, greaterThan(afterLogin));
    });

    test('setUser updates the cached user', () async {
      final TestApp app = TestApp(
        (http.Request request) async => jsonResponse(tokenResponseJson()),
      );
      await app.signIn();

      app.session.setUser(
        User.fromJson(userJson(firstName: 'Mariana')),
      );

      expect(app.session.user?.firstName, 'Mariana');
    });
  });
}
