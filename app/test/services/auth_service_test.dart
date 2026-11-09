import 'dart:io';

import 'package:club_sebastian_martinez_amaray/models/api_error.dart';
import 'package:club_sebastian_martinez_amaray/services/api_client.dart';
import 'package:club_sebastian_martinez_amaray/services/auth_backend.dart';
import 'package:club_sebastian_martinez_amaray/services/auth_service.dart';
import 'package:club_sebastian_martinez_amaray/services/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_helpers.dart';

/// La credencial la resuelve el proveedor (Firebase) detrás de [AuthBackend]; el
/// backend propio sólo recibe el ID token. Por eso estos tests inyectan
/// `FakeAuthBackend` y sólo simulan las respuestas de la API.
void main() {
  AuthService buildAuth(
    FakeBackend backend, {
    SessionStorage? storage,
    AuthBackend? authBackend,
  }) {
    return AuthService(
      api: ApiClient(baseUrl: 'http://test.local', client: backend.client),
      storage: storage ?? InMemorySessionStorage(),
      backend: authBackend ?? FakeAuthBackend(),
    );
  }

  group('login', () {
    test('autentica con el proveedor y trae el perfil de GET /users/me',
        () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(userJson()),
      );
      final FakeAuthBackend authBackend = FakeAuthBackend();
      final InMemorySessionStorage storage = InMemorySessionStorage();
      final AuthService auth =
          buildAuth(backend, storage: storage, authBackend: authBackend);

      final user = await auth.login(
        email: 'maria@club.com',
        password: 'Secreta123',
      );

      // El proveedor recibió las credenciales; la API sólo el token.
      expect(authBackend.calls, contains('signInWithPassword'));
      expect(authBackend.lastEmail, 'maria@club.com');
      expect(backend.paths, equals(<String>['/users/me']));
      expect(user.email, 'maria@club.com');
      expect(auth.token, 'id-token-de-prueba');
      expect(auth.isAuthenticated, isTrue);

      final SessionData? saved = await storage.read();
      expect(saved, isNotNull);
      expect(saved!.token, 'id-token-de-prueba');
      expect(saved.user['email'], 'maria@club.com');
    });

    test('traduce las credenciales inválidas del proveedor', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(userJson()),
      );
      final AuthService auth = buildAuth(
        backend,
        authBackend: FakeAuthBackend(
          loginError: const AuthBackendException('wrong-password'),
        ),
      );

      await expectLater(
        auth.login(email: 'maria@club.com', password: 'mala'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.userMessage,
            'userMessage',
            'El correo o la contraseña son incorrectos.',
          ),
        ),
      );
      expect(auth.isAuthenticated, isFalse);
      // Ni siquiera llegó a pedir el perfil.
      expect(backend.requests, isEmpty);
    });

    test('propaga los problemas de conexión', () async {
      final FakeBackend backend = FakeBackend((http.Request request) {
        throw const SocketException('Connection refused');
      });
      final AuthService auth = buildAuth(backend);

      await expectLater(
        auth.login(email: 'maria@club.com', password: 'Secreta123'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.userMessage,
            'userMessage',
            'No pudimos conectarnos con el servidor. Revisá tu conexión.',
          ),
        ),
      );
    });
  });

  group('register', () {
    test('crea la cuenta y manda el perfil a POST /auth/firebase-sync',
        () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(userJson()),
      );
      final FakeAuthBackend authBackend = FakeAuthBackend();
      final AuthService auth = buildAuth(backend, authBackend: authBackend);

      await auth.register(
        email: 'maria@club.com',
        password: 'Secreta123',
        firstName: 'María',
        lastName: 'Lopez',
        birthDate: DateTime(1996, 3, 8),
      );

      expect(authBackend.calls, contains('createUser'));

      final http.Request sync = backend.requestsFor('/auth/firebase-sync').single;
      final Map<String, dynamic> body = backend.bodyOf(sync);
      expect(body['first_name'], 'María');
      expect(body['last_name'], 'Lopez');
      expect(body['birth_date'], '1996-03-08');
      expect(auth.token, isNotNull);
    });

    test('traduce el correo ya registrado', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(userJson()),
      );
      final AuthService auth = buildAuth(
        backend,
        authBackend: FakeAuthBackend(
          registerError: const AuthBackendException('email-already-in-use'),
        ),
      );

      await expectLater(
        auth.register(
          email: 'maria@club.com',
          password: 'Secreta123',
          firstName: 'María',
          lastName: 'Lopez',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.userMessage,
            'userMessage',
            'Ya existe una cuenta con ese correo.',
          ),
        ),
      );
    });
  });

  group('password recovery', () {
    test('pide el correo de recuperación al proveedor y no devuelve token',
        () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<String, dynamic>{}),
      );
      final FakeAuthBackend authBackend = FakeAuthBackend();
      final AuthService auth = buildAuth(backend, authBackend: authBackend);

      final String? token = await auth.requestPasswordReset('maria@club.com');

      expect(authBackend.calls, contains('sendPasswordResetEmail'));
      expect(authBackend.lastEmail, 'maria@club.com');
      expect(token, isNull);
      // El envío lo hace Firebase: no hay request propio.
      expect(backend.requests, isEmpty);
    });

    test('no revela si el correo existe', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<String, dynamic>{}),
      );
      final AuthService auth = buildAuth(
        backend,
        authBackend: FakeAuthBackend(
          resetError: const AuthBackendException('user-not-found'),
        ),
      );

      // El proveedor diría "user-not-found", pero el servicio lo silencia.
      expect(await auth.requestPasswordReset('nadie@club.com'), isNull);
    });

    test('resets the password and returns the message of the API', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<String, dynamic>{
          'detail': 'Contraseña actualizada. Ya podés iniciar sesión con la nueva.',
          'code': 'password_updated',
        }),
      );
      final AuthService auth = buildAuth(backend);

      final String detail = await auth.resetPassword(
        token: '6fNa8JxywwKY-F-FHGRO5Bx6emx0Wd21dfNDMapUnXI',
        newPassword: 'NuevaClave123',
      );

      expect(backend.lastRequest.url.path, '/auth/reset-password');
      final Map<String, dynamic> body = backend.bodyOf(backend.lastRequest);
      expect(body['token'], '6fNa8JxywwKY-F-FHGRO5Bx6emx0Wd21dfNDMapUnXI');
      expect(body['new_password'], 'NuevaClave123');
      expect(detail, 'Contraseña actualizada. Ya podés iniciar sesión con la nueva.');
    });

    test('propagates reset_token_used', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async =>
            errorResponse(400, 'El token ya fue usado.', 'reset_token_used'),
      );
      final AuthService auth = buildAuth(backend);

      await expectLater(
        auth.resetPassword(token: 'token-usado', newPassword: 'NuevaClave123'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.userMessage,
            'userMessage',
            'El token ya fue usado.',
          ),
        ),
      );
    });
  });

  group('session', () {
    test('restore toma el ID token del proveedor y el perfil guardado',
        () async {
      final InMemorySessionStorage storage = InMemorySessionStorage();
      await storage.save(
        SessionData(token: 'token-guardado', user: userJson()),
      );
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(userJson()),
      );
      final ApiClient api =
          ApiClient(baseUrl: 'http://test.local', client: backend.client);
      final AuthService auth = AuthService(
        api: api,
        storage: storage,
        backend: FakeAuthBackend(idToken: 'token-guardado', rememberUser: true),
      );

      expect(await auth.restore(), isTrue);
      expect(auth.token, 'token-guardado');
      expect(api.authToken, 'token-guardado');
      expect(auth.user?.email, 'maria@club.com');
    });

    test('restore devuelve false sin usuario en el proveedor', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<String, dynamic>{}),
      );
      final AuthService auth = buildAuth(backend);

      expect(await auth.restore(), isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(backend.requests, isEmpty);
    });

    test('logout cierra la sesión del proveedor y olvida el perfil', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(userJson()),
      );
      final FakeAuthBackend authBackend = FakeAuthBackend();
      final ApiClient api =
          ApiClient(baseUrl: 'http://test.local', client: backend.client);
      final AuthService auth = AuthService(
        api: api,
        storage: InMemorySessionStorage(),
        backend: authBackend,
      );

      await auth.login(email: 'maria@club.com', password: 'Secreta123');
      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(api.authToken, isNull);
      expect(authBackend.signedOut, isTrue);
    });
  });

  group('profile', () {
    test('fetchProfile reads GET /users/me', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(userJson()),
      );
      final AuthService auth = buildAuth(backend);

      final user = await auth.fetchProfile();

      expect(backend.lastRequest.url.path, '/users/me');
      expect(user.fullName, 'María Lopez');
    });

    test('updateProfile sends only the editable fields (never the email)',
        () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async =>
            jsonResponse(userJson(firstName: 'Mariana')),
      );
      final AuthService auth = buildAuth(backend);

      final user = await auth.updateProfile(
        firstName: 'Mariana',
        birthDate: DateTime(1996, 3, 8),
      );

      expect(backend.lastRequest.method, 'PATCH');
      expect(backend.lastRequest.url.path, '/users/me');
      final Map<String, dynamic> body = backend.bodyOf(backend.lastRequest);
      expect(body.containsKey('email'), isFalse);
      expect(
        body.keys.toSet(),
        equals(<String>{'first_name', 'birth_date'}),
      );
      expect(body['birth_date'], '1996-03-08');
      expect(user.firstName, 'Mariana');
    });

    test('propagates email_not_editable', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => errorResponse(
          400,
          'El correo electrónico no se puede modificar.',
          'email_not_editable',
        ),
      );
      final AuthService auth = buildAuth(backend);

      await expectLater(
        auth.updateProfile(firstName: 'Mariana'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.userMessage,
            'userMessage',
            'El correo electrónico no se puede modificar.',
          ),
        ),
      );
    });
  });
}
