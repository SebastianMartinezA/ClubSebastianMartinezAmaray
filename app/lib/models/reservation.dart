/// Reservation as returned by the API (`ReservationOut`).
///
/// Fields: `id`, `sport_space_id`, `space_name`, `venue_id`, `venue_name`,
/// `date`, `start_time`, `end_time`, `status`, `created_at`, `cancelled_at`.
class Reservation {
  const Reservation({
    required this.id,
    required this.sportSpaceId,
    required this.spaceName,
    required this.venueId,
    required this.venueName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.createdAt,
    this.cancelledAt,
  });

  final int id;
  final int sportSpaceId;
  final String spaceName;
  final int venueId;
  final String venueName;

  /// Day of the reservation (the API sends `"2026-10-17"`).
  final DateTime date;

  /// `"10:00:00"`.
  final String startTime;
  final String endTime;

  /// `active` or `cancelled`.
  final String status;

  final DateTime? createdAt;
  final DateTime? cancelledAt;

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: (json['id'] as num).toInt(),
      sportSpaceId: (json['sport_space_id'] as num?)?.toInt() ?? 0,
      spaceName: json['space_name'] as String? ?? '',
      venueId: (json['venue_id'] as num?)?.toInt() ?? 0,
      venueName: json['venue_name'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime(1970),
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      status: json['status'] as String? ?? ReservationStatus.active,
      createdAt: _parseDateTime(json['created_at']),
      cancelledAt: _parseDateTime(json['cancelled_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sport_space_id': sportSpaceId,
        'space_name': spaceName,
        'venue_id': venueId,
        'venue_name': venueName,
        'date': _formatDate(date),
        'start_time': startTime,
        'end_time': endTime,
        'status': status,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'cancelled_at': cancelledAt?.toUtc().toIso8601String(),
      };

  bool get isCancelled => status == ReservationStatus.cancelled;

  bool get isActive => status == ReservationStatus.active;

  /// `DateTime` of the slot start, in local time.
  DateTime get startDateTime => DateTime(date.year, date.month, date.day, _hour(startTime));

  /// `DateTime` of the slot end, in local time.
  DateTime get endDateTime => DateTime(date.year, date.month, date.day, _hour(endTime));

  /// True when the reservation is over (used by the history screen to tell
  /// finished reservations from active ones).
  bool get isFinished => endDateTime.isBefore(DateTime.now());

  /// Short label used by the UI: `Activa`, `Terminada` or `Cancelada`.
  String get statusLabel {
    if (isCancelled) {
      return 'Cancelada';
    }
    return isFinished ? 'Terminada' : 'Activa';
  }

  /// True when the reservation can still be cancelled.
  bool get canBeCancelled => isActive && !isFinished;

  static int _hour(String time) {
    final List<String> parts = time.split(':');
    if (parts.isEmpty) {
      return 0;
    }
    return int.tryParse(parts.first) ?? 0;
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

/// Values accepted by the API in the `status` field (`ReservationStatus`).
class ReservationStatus {
  ReservationStatus._();

  static const String active = 'active';
  static const String cancelled = 'cancelled';
}
