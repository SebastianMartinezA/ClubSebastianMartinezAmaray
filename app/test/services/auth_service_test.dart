import 'dart:io';

import 'package:club_sebastian_martinez_amaray/models/api_error.dart';
import 'package:club_sebastian_martinez_amaray/services/api_client.dart';
import 'package:club_sebastian_martinez_amaray/services/auth_service.dart';
import 'package:club_sebastian_martinez_amaray/services/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_helpers.dart';

void main() {
  AuthService buildAuth(FakeBackend backend, {SessionStorage? storage}) {
    return AuthService(
      api: ApiClient(baseUrl: 'http://test.local', client: backend.client),
      storage: storage ?? InMemorySessionStorage(),
    );
  }

  group('login', () {
    test('sends the credentials and keeps the token of the session', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(tokenResponseJson()),
      );
      final InMemorySessionStorage storage = InMemorySessionStorage();
      final AuthService auth = buildAuth(backend, storage: storage);

      final user = await auth.login(
        email: 'maria@club.com',
        password: 'Secreta123',
      );

      expect(backend.lastRequest.url.path, '/auth/login');
      expect(backend.bodyOf(backend.lastRequest)['email'], 'maria@club.com');
      expect(backend.bodyOf(backend.lastRequest)['password'], 'Secreta123');
      expect(user.email, 'maria@club.com');
      expect(auth.token, 'eyJhbG.token.de.prueba');
      expect(auth.isAuthenticated, isTrue);

      final SessionData? saved = await storage.read();
      expect(saved, isNotNull);
      expect(saved!.token, 'eyJhbG.token.de.prueba');
      expect(saved.user['email'], 'maria@club.com');
    });

    test('propagates invalid_credentials', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => errorResponse(
          401,
          'Correo o contraseña incorrectos.',
          'invalid_credentials',
        ),
      );
      final AuthService auth = buildAuth(backend);

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
    });

    test('propagates connectivity problems', () async {
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
    test('sends the fields of UserRegister and logs the user in', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async =>
            jsonResponse(tokenResponseJson(), statusCode: 201),
      );
      final AuthService auth = buildAuth(backend);

      await auth.register(
        email: 'maria@club.com',
        password: 'Secreta123',
        firstName: 'María',
        lastName: 'Lopez',
        birthDate: DateTime(1996, 3, 8),
      );

      final Map<String, dynamic> body = backend.bodyOf(backend.lastRequest);
      expect(backend.lastRequest.url.path, '/auth/register');
      expect(
        body.keys.toSet(),
        equals(<String>{
          'email',
          'password',
          'first_name',
          'last_name',
          'birth_date',
        }),
      );
      expect(body['birth_date'], '1996-03-08');
      expect(auth.token, isNotNull);
    });

    test('propagates email_already_registered', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => errorResponse(
          409,
          'Ya existe un usuario registrado con ese correo.',
          'email_already_registered',
        ),
      );
      final AuthService auth = buildAuth(backend);

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
    test('returns the reset token when the API is in DEBUG mode', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<String, dynamic>{
          'message':
              'Si el correo está registrado, te enviamos las instrucciones.',
          'reset_token': '6fNa8JxywwKY-F-FHGRO5Bx6emx0Wd21dfNDMapUnXI',
        }),
      );
      final AuthService auth = buildAuth(backend);

      final String? token = await auth.requestPasswordReset('maria@club.com');

      expect(backend.lastRequest.url.path, '/auth/forgot-password');
      expect(backend.bodyOf(backend.lastRequest)['email'], 'maria@club.com');
      expect(token, '6fNa8JxywwKY-F-FHGRO5Bx6emx0Wd21dfNDMapUnXI');
    });

    test('returns null when the API does not expose the token', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<String, dynamic>{
          'message': 'Si el correo está registrado, te enviamos las '
              'instrucciones para restablecer la contraseña.',
          'reset_token': null,
        }),
      );
      final AuthService auth = buildAuth(backend);

      expect(await auth.requestPasswordReset('maria@club.com'), isNull);
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
    test('restore reads the stored session and applies the token', () async {
      final InMemorySessionStorage storage = InMemorySessionStorage();
      await storage.save(
        SessionData(token: 'token-guardado', user: userJson()),
      );
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(userJson()),
      );
      final ApiClient api =
          ApiClient(baseUrl: 'http://test.local', client: backend.client);
      final AuthService auth = AuthService(api: api, storage: storage);

      expect(await auth.restore(), isTrue);
      expect(auth.token, 'token-guardado');
      expect(api.authToken, 'token-guardado');
      expect(auth.user?.email, 'maria@club.com');
    });

    test('restore returns false without a stored session', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<String, dynamic>{}),
      );
      final AuthService auth = buildAuth(backend);

      expect(await auth.restore(), isFalse);
      expect(auth.isAuthenticated, isFalse);
    });

    test('logout forgets the token and the stored session', () async {
      final InMemorySessionStorage storage = InMemorySessionStorage();
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(tokenResponseJson()),
      );
      final ApiClient api =
          ApiClient(baseUrl: 'http://test.local', client: backend.client);
      final AuthService auth = AuthService(api: api, storage: storage);

      await auth.login(email: 'maria@club.com', password: 'Secreta123');
      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(api.authToken, isNull);
      expect(await storage.read(), isNull);
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
