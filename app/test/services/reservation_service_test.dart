import 'package:club_sebastian_martinez_amaray/models/api_error.dart';
import 'package:club_sebastian_martinez_amaray/models/reservation.dart';
import 'package:club_sebastian_martinez_amaray/services/api_client.dart';
import 'package:club_sebastian_martinez_amaray/services/device_service.dart';
import 'package:club_sebastian_martinez_amaray/services/reservation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_helpers.dart';

void main() {
  ReservationService buildReservations(FakeBackend backend) {
    return ReservationService(
      ApiClient(baseUrl: 'http://test.local', client: backend.client),
    );
  }

  group('create', () {
    test('POST /reservations sends exactly the fields of ReservationCreate',
        () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async =>
            jsonResponse(reservationJson(), statusCode: 201),
      );
      final ReservationService service = buildReservations(backend);

      final Reservation reservation = await service.create(
        sportSpaceId: 3,
        date: DateTime(2026, 10, 17),
        startTime: '10:00:00',
        endTime: '11:00:00',
      );

      expect(backend.lastRequest.method, 'POST');
      expect(backend.lastRequest.url.path, '/reservations');
      final Map<String, dynamic> body = backend.bodyOf(backend.lastRequest);
      expect(
        body.keys.toSet(),
        equals(<String>{
          'sport_space_id',
          'date',
          'start_time',
          'end_time',
        }),
      );
      expect(body['sport_space_id'], 3);
      expect(body['date'], '2026-10-17');
      expect(body['start_time'], '10:00:00');
      expect(body['end_time'], '11:00:00');
      expect(reservation.id, 1);
      expect(reservation.status, ReservationStatus.active);
    });

    test('propagates space_not_available (someone else took the slot)',
        () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => errorResponse(
          409,
          'El espacio ya está reservado en ese horario.',
          'space_not_available',
        ),
      );
      final ReservationService service = buildReservations(backend);

      await expectLater(
        service.create(
          sportSpaceId: 3,
          date: DateTime(2026, 10, 17),
          startTime: '10:00:00',
          endTime: '11:00:00',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.userMessage,
            'userMessage',
            'Ese horario se acaba de ocupar. Elegí otro.',
          ),
        ),
      );
    });

    test('propagates outside_venue_hours', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => errorResponse(
          400,
          'El horario está fuera del horario de la sede (08:00 a 22:00).',
          'outside_venue_hours',
        ),
      );
      final ReservationService service = buildReservations(backend);

      await expectLater(
        service.create(
          sportSpaceId: 3,
          date: DateTime(2026, 10, 17),
          startTime: '06:00:00',
          endTime: '07:00:00',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            ApiErrorCodes.outsideVenueHours,
          ),
        ),
      );
    });
  });

  group('lists', () {
    test('GET /reservations returns the current reservations', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async =>
            jsonResponse(<Object>[reservationJson()]),
      );
      final ReservationService service = buildReservations(backend);

      final List<Reservation> reservations = await service.current();

      expect(backend.lastRequest.url.path, '/reservations');
      expect(reservations.single.spaceName, 'Moron_Rivadavia_19850_Futbol_1');
    });

    test('GET /reservations/history returns finished and cancelled ones',
        () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<Object>[
          reservationJson(
            id: 9,
            date: '2026-10-01',
            status: 'cancelled',
            cancelledAt: '2026-09-30T10:00:00Z',
          ),
          reservationJson(id: 8, date: '2026-09-20'),
        ]),
      );
      final ReservationService service = buildReservations(backend);

      final List<Reservation> history = await service.history();

      expect(backend.lastRequest.url.path, '/reservations/history');
      expect(history.length, 2);
      expect(history.first.isCancelled, isTrue);
      expect(history.first.statusLabel, 'Cancelada');
      expect(history.last.statusLabel, 'Terminada');
    });
  });

  group('cancel', () {
    test('POST /reservations/{id}/cancel', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(
          reservationJson(
            status: 'cancelled',
            cancelledAt: '2026-10-15T10:00:00Z',
          ),
        ),
      );
      final ReservationService service = buildReservations(backend);

      final Reservation cancelled = await service.cancel(1);

      expect(backend.lastRequest.method, 'POST');
      expect(backend.lastRequest.url.path, '/reservations/1/cancel');
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.status, ReservationStatus.cancelled);
    });

    test('propagates not_reservation_owner', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => errorResponse(
          403,
          'La reserva pertenece a otro usuario.',
          'not_reservation_owner',
        ),
      );
      final ReservationService service = buildReservations(backend);

      await expectLater(
        service.cancel(5),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.userMessage,
            'userMessage',
            'La reserva pertenece a otro usuario.',
          ),
        ),
      );
    });
  });

  group('devices (push tokens)', () {
    test('POST /devices sends token and platform', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<String, dynamic>{
          'id': 1,
          'token': 'fcm-token-de-prueba',
          'platform': 'android',
          'created_at': '2026-10-14T22:12:52.123456Z',
        }, statusCode: 201),
      );
      final DeviceService service = DeviceService(
        ApiClient(baseUrl: 'http://test.local', client: backend.client),
      );

      final device = await service.register(token: 'fcm-token-de-prueba');

      expect(backend.lastRequest.url.path, '/devices');
      final Map<String, dynamic> body = backend.bodyOf(backend.lastRequest);
      expect(body['token'], 'fcm-token-de-prueba');
      expect(body['platform'], 'android');
      expect(device.platform, 'android');
    });
  });
}
