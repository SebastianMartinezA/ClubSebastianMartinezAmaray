import 'package:club_sebastian_martinez_amaray/models/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiException.fromBody', () {
    test('reads detail and code from the API error body', () {
      final ApiException error = ApiException.fromBody(
        <String, dynamic>{
          'detail': 'Ya existe un usuario registrado con ese correo.',
          'code': 'email_already_registered',
        },
        statusCode: 409,
      );

      expect(error.code, ApiErrorCodes.emailAlreadyRegistered);
      expect(error.statusCode, 409);
      expect(error.message, 'Ya existe un usuario registrado con ese correo.');
    });

    test('joins FastAPI validation errors (detail as a list)', () {
      final ApiException error = ApiException.fromBody(
        <String, dynamic>{
          'detail': <Map<String, dynamic>>[
            <String, dynamic>{
              'loc': <String>['body', 'password'],
              'msg': 'String should have at least 8 characters',
              'type': 'string_too_short',
            },
            <String, dynamic>{
              'loc': <String>['body', 'email'],
              'msg': 'value is not a valid email address',
              'type': 'value_error',
            },
          ],
        },
        statusCode: 422,
      );

      expect(error.code, ApiErrorCodes.validationError);
      expect(error.message, contains('password'));
      expect(error.message, contains('8 characters'));
      expect(error.message, contains('email'));
    });

    test('falls back to a generic message when there is no body', () {
      final ApiException error = ApiException.fromBody(null, statusCode: 500);

      expect(error.code, ApiErrorCodes.internalError);
      expect(error.message, isNotEmpty);
    });
  });

  group('userMessage', () {
    test('maps invalid_credentials', () {
      final ApiException error = ApiException.fromBody(
        <String, dynamic>{
          'detail': 'Correo o contraseña incorrectos.',
          'code': 'invalid_credentials',
        },
        statusCode: 401,
      );

      expect(error.userMessage, 'El correo o la contraseña son incorrectos.');
    });

    test('maps email_already_registered', () {
      final ApiException error = ApiException.fromBody(
        <String, dynamic>{
          'detail': 'Ya existe un usuario registrado con ese correo.',
          'code': 'email_already_registered',
        },
        statusCode: 409,
      );

      expect(error.userMessage, 'Ya existe una cuenta con ese correo.');
    });

    test('maps space_not_available', () {
      final ApiException error = ApiException.fromBody(
        <String, dynamic>{
          'detail': 'El espacio ya está reservado en ese horario.',
          'code': 'space_not_available',
        },
        statusCode: 409,
      );

      expect(error.userMessage, 'Ese horario se acaba de ocupar. Elegí otro.');
    });

    test('shows the API detail for any other error code', () {
      final ApiException error = ApiException.fromBody(
        <String, dynamic>{
          'detail': 'Los turnos empiezan en punto.',
          'code': 'invalid_time_granularity',
        },
        statusCode: 400,
      );

      expect(error.userMessage, 'Los turnos empiezan en punto.');
    });

    test('shows the API detail of email_not_editable', () {
      final ApiException error = ApiException.fromBody(
        <String, dynamic>{
          'detail': 'El correo electrónico no se puede modificar.',
          'code': 'email_not_editable',
        },
        statusCode: 400,
      );

      expect(error.userMessage, 'El correo electrónico no se puede modificar.');
    });
  });

  group('connectivity', () {
    test('network errors get the message the assignment asks for', () {
      const ApiException error = ApiException(
        code: ApiErrorCodes.networkError,
        message: 'no route to host',
      );

      expect(
        error.userMessage,
        'No pudimos conectarnos con el servidor. Revisá tu conexión.',
      );
      expect(error.isConnectivityProblem, isTrue);
    });

    test('timeouts get the same treatment', () {
      final ApiException error = ApiException.timeout();

      expect(error.code, ApiErrorCodes.timeoutError);
      expect(
        error.userMessage,
        'No pudimos conectarnos con el servidor. Revisá tu conexión.',
      );
      expect(error.isConnectivityProblem, isTrue);
    });
  });

  group('session expiration', () {
    test('detects an expired token', () {
      final ApiException expired = ApiException.fromBody(
        <String, dynamic>{
          'detail': 'El token expiró. Volvé a iniciar sesión.',
          'code': 'token_expired',
        },
        statusCode: 401,
      );
      final ApiException badCredentials = ApiException.fromBody(
        <String, dynamic>{
          'detail': 'Correo o contraseña incorrectos.',
          'code': 'invalid_credentials',
        },
        statusCode: 401,
      );

      expect(expired.isSessionExpired, isTrue);
      expect(badCredentials.isSessionExpired, isFalse);
    });
  });
}
