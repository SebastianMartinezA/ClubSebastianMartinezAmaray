import '../models/reservation.dart';
import '../utils/formatters.dart';
import 'api_client.dart';

/// Reservations of the logged-in user.
///
/// Endpoints used: `POST /reservations`, `GET /reservations`,
/// `GET /reservations/history`, `POST /reservations/{id}/cancel`.
class ReservationService {
  ReservationService(this._api);

  final ApiClient _api;

  /// Creates a reservation.
  ///
  /// Slots are always one hour long, on the hour, inside the venue opening
  /// hours (the backend validates it and answers with
  /// `invalid_duration`, `invalid_time_granularity`, `outside_venue_hours`,
  /// `reservation_in_the_past` or `space_not_available`).
  Future<Reservation> create({
    required int sportSpaceId,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    final Map<String, dynamic> json = await _api.postMap(
      '/reservations',
      body: <String, dynamic>{
        'sport_space_id': sportSpaceId,
        'date': Formatters.toIsoDate(date),
        'start_time': startTime,
        'end_time': endTime,
      },
    );
    return Reservation.fromJson(json);
  }

  /// Current reservations (active and not finished yet).
  Future<List<Reservation>> current() async {
    final List<Map<String, dynamic>> items = await _api.getItems('/reservations');
    return items.map(Reservation.fromJson).toList(growable: false);
  }

  /// Finished and cancelled reservations.
  Future<List<Reservation>> history() async {
    final List<Map<String, dynamic>> items =
        await _api.getItems('/reservations/history');
    return items.map(Reservation.fromJson).toList(growable: false);
  }

  /// Cancels a reservation; the slot becomes available again on the backend.
  Future<Reservation> cancel(int reservationId) async {
    final Map<String, dynamic> json =
        await _api.postMap('/reservations/$reservationId/cancel');
    return Reservation.fromJson(json);
  }
}
