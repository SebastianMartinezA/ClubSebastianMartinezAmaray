import 'dart:convert';
import 'dart:io';

import 'package:club_sebastian_martinez_amaray/models/api_error.dart';
import 'package:club_sebastian_martinez_amaray/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_helpers.dart';

void main() {
  ApiClient buildClient(
    FakeBackend backend, {
    String? token,
    Duration? timeout,
  }) {
    final ApiClient api = ApiClient(
      baseUrl: 'http://test.local',
      client: backend.client,
      timeout: timeout,
    );
    api.authToken = token;
    return api;
  }

  group('responses 2xx', () {
    test('decodes a JSON object', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(userJson()),
      );
      final ApiClient api = buildClient(backend);

      final Map<String, dynamic> json = await api.getMap('/users/me');

      expect(json['email'], 'maria@club.com');
      expect(backend.lastRequest.url.path, '/users/me');
      expect(backend.lastRequest.method, 'GET');
    });

    test('decodes a JSON array', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<Object>[venueJson()]),
      );
      final ApiClient api = buildClient(backend);

      final List<Map<String, dynamic>> items = await api.getItems('/venues');

      expect(items.length, 1);
      expect(items.first['name'], 'Moron');
    });

    test('decodes UTF-8 accents (the API sends JSON without charset)',
        () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => http.Response.bytes(
          utf8.encode('{"first_name":"María","detail":"Sede de Morón"}'),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );
      final ApiClient api = buildClient(backend);

      final Map<String, dynamic> json = await api.getMap('/users/me');

      expect(json['first_name'], 'María');
      expect(json['detail'], 'Sede de Morón');
    });

    test('sends the bearer token when there is a session', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<String, dynamic>{}),
      );
      final ApiClient api = buildClient(backend, token: 'token-de-prueba');

      await api.getMap('/reservations');

      expect(
        backend.lastRequest.headers['Authorization'],
        'Bearer token-de-prueba',
      );
    });

    test('does not send Authorization without a token', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<String, dynamic>{}),
      );
      final ApiClient api = buildClient(backend);

      await api.getMap('/venues');

      expect(backend.lastRequest.headers.containsKey('Authorization'), isFalse);
    });

    test('builds query parameters', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<String, dynamic>{}),
      );
      final ApiClient api = buildClient(backend);

      await api.getMap(
        '/venues/1/availability',
        query: <String, String>{'date': '2026-10-17'},
      );

      expect(backend.lastRequest.url.queryParameters['date'], '2026-10-17');
      expect(backend.lastRequest.url.path, '/venues/1/availability');
    });

    test('serialises the body of a POST as JSON', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async =>
            jsonResponse(reservationJson(), statusCode: 201),
      );
      final ApiClient api = buildClient(backend, token: 'token');

      await api.postMap(
        '/reservations',
        body: <String, dynamic>{'sport_space_id': 3},
      );

      expect(backend.lastRequest.method, 'POST');
      expect(backend.bodyOf(backend.lastRequest)['sport_space_id'], 3);
      expect(
        backend.lastRequest.headers['Content-Type'],
        contains('application/json'),
      );
    });
  });

  group('errors of the API', () {
    test('401 invalid_credentials', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => errorResponse(
          401,
          'Correo o contraseña incorrectos.',
          'invalid_credentials',
        ),
      );
      final ApiClient api = buildClient(backend);

      await expectLater(
        api.postMap('/auth/login', body: <String, dynamic>{}),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.statusCode, 'statusCode', 401)
              .having(
                (ApiException e) => e.code,
                'code',
                ApiErrorCodes.invalidCredentials,
              )
              .having(
                (ApiException e) => e.userMessage,
                'userMessage',
                'El correo o la contraseña son incorrectos.',
              ),
        ),
      );
    });

    test('409 space_not_available', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => errorResponse(
          409,
          'El espacio ya está reservado en ese horario.',
          'space_not_available',
        ),
      );
      final ApiClient api = buildClient(backend, token: 'token');

      await expectLater(
        api.postMap('/reservations', body: <String, dynamic>{}),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.code,
                'code',
                ApiErrorCodes.spaceNotAvailable,
              )
              .having(
                (ApiException e) => e.userMessage,
                'userMessage',
                'Ese horario se acaba de ocupar. Elegí otro.',
              ),
        ),
      );
    });

    test('404 venue_not_found keeps the detail of the API', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async =>
            errorResponse(404, 'La sede no existe.', 'venue_not_found'),
      );
      final ApiClient api = buildClient(backend);

      await expectLater(
        api.getMap('/venues/99'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            'La sede no existe.',
          ),
        ),
      );
    });

    test('400 invalid_time_granularity keeps the detail of the API', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => errorResponse(
          400,
          'Los turnos empiezan en punto.',
          'invalid_time_granularity',
        ),
      );
      final ApiClient api = buildClient(backend, token: 'token');

      await expectLater(
        api.postMap('/reservations', body: <String, dynamic>{}),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.userMessage,
            'userMessage',
            'Los turnos empiezan en punto.',
          ),
        ),
      );
    });

    test('a 500 without a JSON body does not break the app', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => http.Response('boom', 500),
      );
      final ApiClient api = buildClient(backend);

      await expectLater(
        api.getMap('/venues'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('connectivity', () {
    test('a timeout becomes a timeout ApiException', () async {
      final FakeBackend backend = FakeBackend((http.Request request) async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return jsonResponse(<String, dynamic>{});
      });
      final ApiClient api = buildClient(
        backend,
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        api.getMap('/venues'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.code,
                'code',
                ApiErrorCodes.timeoutError,
              )
              .having((ApiException e) => e.statusCode, 'statusCode', isNull)
              .having(
                (ApiException e) => e.userMessage,
                'userMessage',
                'No pudimos conectarnos con el servidor. Revisá tu conexión.',
              ),
        ),
      );
    });

    test('a SocketException becomes a network ApiException', () async {
      final FakeBackend backend = FakeBackend((http.Request request) {
        throw const SocketException('Connection refused');
      });
      final ApiClient api = buildClient(backend);

      await expectLater(
        api.getMap('/venues'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.code,
                'code',
                ApiErrorCodes.networkError,
              )
              .having(
                (ApiException e) => e.isConnectivityProblem,
                'isConnectivityProblem',
                isTrue,
              ),
        ),
      );
    });

    test('a ClientException becomes a network ApiException', () async {
      final FakeBackend backend = FakeBackend((http.Request request) {
        throw http.ClientException('Failed host lookup');
      });
      final ApiClient api = buildClient(backend);

      await expectLater(
        api.getMap('/venues'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            ApiErrorCodes.networkError,
          ),
        ),
      );
    });
  });

  group('expired token hook', () {
    test('calls onUnauthorized when the token expired', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => errorResponse(
          401,
          'El token expiró. Volvé a iniciar sesión.',
          'token_expired',
        ),
      );
      final ApiClient api = buildClient(backend, token: 'vencido');
      bool called = false;
      api.onUnauthorized = () => called = true;

      try {
        await api.getMap('/reservations');
      } on ApiException {
        // expected
      }

      expect(called, isTrue);
    });

    test('does not call onUnauthorized on a failed login', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => errorResponse(
          401,
          'Correo o contraseña incorrectos.',
          'invalid_credentials',
        ),
      );
      final ApiClient api = buildClient(backend);
      bool called = false;
      api.onUnauthorized = () => called = true;

      try {
        await api.postMap('/auth/login', body: <String, dynamic>{});
      } on ApiException {
        // expected
      }

      expect(called, isFalse);
    });
  });
}
