import 'package:club_sebastian_martinez_amaray/models/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reservation.fromJson', () {
    test('parses an active reservation with the exact API field names', () {
      final Reservation reservation =
          Reservation.fromJson(<String, dynamic>{
        'id': 1,
        'sport_space_id': 3,
        'space_name': 'Moron_Rivadavia_19850_Futbol_1',
        'venue_id': 1,
        'venue_name': 'Moron',
        'date': '2999-10-17',
        'start_time': '10:00:00',
        'end_time': '11:00:00',
        'status': 'active',
        'created_at': '2026-10-14T22:12:52.987654Z',
        'cancelled_at': null,
      });

      expect(reservation.id, 1);
      expect(reservation.sportSpaceId, 3);
      expect(reservation.spaceName, 'Moron_Rivadavia_19850_Futbol_1');
      expect(reservation.venueId, 1);
      expect(reservation.venueName, 'Moron');
      expect(reservation.date.year, 2999);
      expect(reservation.date.month, 10);
      expect(reservation.date.day, 17);
      expect(reservation.startTime, '10:00:00');
      expect(reservation.endTime, '11:00:00');
      expect(reservation.status, ReservationStatus.active);
      expect(reservation.isActive, isTrue);
      expect(reservation.isCancelled, isFalse);
      expect(reservation.cancelledAt, isNull);
      expect(reservation.startDateTime.hour, 10);
      expect(reservation.endDateTime.hour, 11);
    });

    test('parses a cancelled reservation and keeps cancelled_at', () {
      final Reservation reservation =
          Reservation.fromJson(<String, dynamic>{
        'id': 4,
        'sport_space_id': 3,
        'space_name': 'Moron_Rivadavia_19850_Futbol_1',
        'venue_id': 1,
        'venue_name': 'Moron',
        'date': '2999-10-17',
        'start_time': '10:00:00',
        'end_time': '11:00:00',
        'status': 'cancelled',
        'created_at': '2026-10-14T22:12:52.987654Z',
        'cancelled_at': '2026-10-15T10:00:00Z',
      });

      expect(reservation.isCancelled, isTrue);
      expect(reservation.statusLabel, 'Cancelada');
      expect(reservation.cancelledAt?.isUtc, isTrue);
      expect(reservation.canBeCancelled, isFalse);
    });

    test('toJson rebuilds the response shape', () {
      final Reservation reservation =
          Reservation.fromJson(<String, dynamic>{
        'id': 1,
        'sport_space_id': 3,
        'space_name': 'Moron_Rivadavia_19850_Futbol_1',
        'venue_id': 1,
        'venue_name': 'Moron',
        'date': '2999-10-17',
        'start_time': '10:00:00',
        'end_time': '11:00:00',
        'status': 'active',
      });
      final Map<String, dynamic> json = reservation.toJson();

      expect(json['sport_space_id'], 3);
      expect(json['space_name'], 'Moron_Rivadavia_19850_Futbol_1');
      expect(json['date'], '2999-10-17');
      expect(json['start_time'], '10:00:00');
      expect(json['status'], 'active');
    });
  });

  group('statusLabel', () {
    test('is "Activa" for a reservation in the future', () {
      final Reservation reservation = Reservation.fromJson(<String, dynamic>{
        'id': 1,
        'sport_space_id': 3,
        'space_name': 'Moron_Rivadavia_19850_Futbol_1',
        'venue_id': 1,
        'venue_name': 'Moron',
        'date': '2999-10-17',
        'start_time': '10:00:00',
        'end_time': '11:00:00',
        'status': 'active',
      });

      expect(reservation.statusLabel, 'Activa');
      expect(reservation.isFinished, isFalse);
      expect(reservation.canBeCancelled, isTrue);
    });

    test('is "Terminada" for a past reservation that is still active', () {
      final Reservation reservation = Reservation.fromJson(<String, dynamic>{
        'id': 1,
        'sport_space_id': 3,
        'space_name': 'Moron_Rivadavia_19850_Futbol_1',
        'venue_id': 1,
        'venue_name': 'Moron',
        'date': '2000-01-01',
        'start_time': '10:00:00',
        'end_time': '11:00:00',
        'status': 'active',
      });

      expect(reservation.isFinished, isTrue);
      expect(reservation.statusLabel, 'Terminada');
      expect(reservation.canBeCancelled, isFalse);
    });
  });
}
