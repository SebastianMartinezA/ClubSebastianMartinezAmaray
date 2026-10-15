import 'dart:async';
import 'dart:convert';

import 'package:club_sebastian_martinez_amaray/services/api_client.dart';
import 'package:club_sebastian_martinez_amaray/services/auth_service.dart';
import 'package:club_sebastian_martinez_amaray/services/catalog_service.dart';
import 'package:club_sebastian_martinez_amaray/services/device_service.dart';
import 'package:club_sebastian_martinez_amaray/services/push_service.dart';
import 'package:club_sebastian_martinez_amaray/services/reservation_service.dart';
import 'package:club_sebastian_martinez_amaray/services/session_storage.dart';
import 'package:club_sebastian_martinez_amaray/state/session.dart';
import 'package:club_sebastian_martinez_amaray/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

/// Fake backend: a `MockClient` that records every request and answers with the
/// body the test decides. No network involved.
class FakeBackend {
  FakeBackend(this.handler);

  /// Handler of every request. Can throw (`SocketException`, for instance) to
  /// simulate a connection problem.
  final FutureOr<http.Response> Function(http.Request request) handler;

  final List<http.Request> requests = <http.Request>[];

  http.Client get client => MockClient((http.Request request) async {
        requests.add(request);
        return handler(request);
      });

  http.Request get lastRequest => requests.last;

  List<String> get paths =>
      requests.map((http.Request request) => request.url.path).toList();

  /// Requests received for a given path.
  List<http.Request> requestsFor(String path) => requests
      .where((http.Request request) => request.url.path == path)
      .toList(growable: false);

  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;
}

/// JSON response with the exact `content-type` of the API (no charset: the app
/// has to decode UTF-8 by itself).
http.Response jsonResponse(Object? body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

/// Error response with the standard shape `{"detail": ..., "code": ...}`.
http.Response errorResponse(int statusCode, String detail, String code) {
  return jsonResponse(
    <String, dynamic>{'detail': detail, 'code': code},
    statusCode: statusCode,
  );
}

// --- fixtures (copied from backend/docs/api.md) ---------------------------

Map<String, dynamic> userJson({
  int id = 2,
  String email = 'maria@club.com',
  String firstName = 'María',
  String lastName = 'Lopez',
  String? birthDate = '1996-03-08',
}) {
  return <String, dynamic>{
    'id': id,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'birth_date': birthDate,
    'created_at': '2026-10-14T22:12:52.123456Z',
  };
}

Map<String, dynamic> tokenResponseJson({
  String token = 'eyJhbG.token.de.prueba',
  Map<String, dynamic>? user,
}) {
  return <String, dynamic>{
    'access_token': token,
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': user ?? userJson(),
  };
}

Map<String, dynamic> venueJson({
  int id = 1,
  String name = 'Moron',
  String address = 'Rivadavia 19850',
  String openingTime = '08:00:00',
  String closingTime = '22:00:00',
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'address': address,
    'opening_time': openingTime,
    'closing_time': closingTime,
  };
}

Map<String, dynamic> spaceJson({
  int id = 3,
  int venueId = 1,
  String venueName = 'Moron',
  String name = 'Moron_Rivadavia_19850_Futbol_1',
  String spaceType = 'Futbol',
  int number = 1,
}) {
  return <String, dynamic>{
    'id': id,
    'venue_id': venueId,
    'venue_name': venueName,
    'name': name,
    'space_type': spaceType,
    'number': number,
  };
}

Map<String, dynamic> slotJson(String start, String end, {bool available = true}) {
  return <String, dynamic>{
    'start_time': start,
    'end_time': end,
    'available': available,
  };
}

Map<String, dynamic> availabilityJson({
  int venueId = 1,
  String date = '2026-10-17',
  List<Map<String, dynamic>>? slots,
}) {
  return <String, dynamic>{
    'venue': venueJson(id: venueId),
    'date': date,
    'spaces': <Map<String, dynamic>>[
      <String, dynamic>{
        'space': spaceJson(),
        'slots': slots ??
            <Map<String, dynamic>>[
              slotJson('08:00:00', '09:00:00'),
              slotJson('10:00:00', '11:00:00', available: false),
              slotJson('21:00:00', '22:00:00'),
            ],
      },
    ],
  };
}

Map<String, dynamic> reservationJson({
  int id = 1,
  int sportSpaceId = 3,
  String spaceName = 'Moron_Rivadavia_19850_Futbol_1',
  int venueId = 1,
  String venueName = 'Moron',
  // Far in the future so `statusLabel` is "Activa" no matter when the tests run.
  String date = '2999-10-17',
  String startTime = '10:00:00',
  String endTime = '11:00:00',
  String status = 'active',
  String? cancelledAt,
}) {
  return <String, dynamic>{
    'id': id,
    'sport_space_id': sportSpaceId,
    'space_name': spaceName,
    'venue_id': venueId,
    'venue_name': venueName,
    'date': date,
    'start_time': startTime,
    'end_time': endTime,
    'status': status,
    'created_at': '2026-10-14T22:12:52.987654Z',
    'cancelled_at': cancelledAt,
  };
}

/// Wires the whole service graph against a fake backend, exactly like
/// `main.dart` does for the real app.
class TestApp {
  TestApp(
    FutureOr<http.Response> Function(http.Request request) handler, {
    SessionStorage? storage,
  })  : backend = FakeBackend(handler),
        storage = storage ?? InMemorySessionStorage() {
    api = ApiClient(baseUrl: 'http://test.local', client: backend.client);
    auth = AuthService(api: api, storage: this.storage);
    catalog = CatalogService(api);
    reservations = ReservationService(api);
    devices = DeviceService(api);
    session = Session(
      api: api,
      auth: auth,
      push: PushService(deviceService: devices),
    );
  }

  final FakeBackend backend;
  final SessionStorage storage;

  late final ApiClient api;
  late final AuthService auth;
  late final CatalogService catalog;
  late final ReservationService reservations;
  late final DeviceService devices;
  late final Session session;

  /// Logs the test user in through the real `Session.signIn` (the fake backend
  /// has to answer `POST /auth/login`).
  Future<void> signIn() => session.signIn(
        email: 'maria@club.com',
        password: 'Secreta123',
      );

  /// Pumps [child] with the same providers `main.dart` installs.
  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<Session>.value(value: session),
        Provider<CatalogService>.value(value: catalog),
        Provider<ReservationService>.value(value: reservations),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: child,
      ),
    );
  }
}
