import 'sport_space.dart';
import 'venue.dart';

/// One one-hour slot of the availability grid (`AvailabilitySlot`).
///
/// Fields: `start_time`, `end_time` (`"20:00:00"`) and `available`.
/// A slot is `available: false` when there is an active reservation on it or
/// when the slot is already in the past.
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.startTime,
    required this.endTime,
    required this.available,
  });

  final String startTime;
  final String endTime;
  final bool available;

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      available: json['available'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'start_time': startTime,
        'end_time': endTime,
        'available': available,
      };
}

/// Availability of a single space on a date (`SpaceAvailability`).
class SpaceAvailability {
  const SpaceAvailability({required this.space, required this.slots});

  final SportSpace space;
  final List<AvailabilitySlot> slots;

  factory SpaceAvailability.fromJson(Map<String, dynamic> json) {
    return SpaceAvailability(
      space: SportSpace.fromJson(json['space'] as Map<String, dynamic>),
      slots: _parseSlots(json['slots']),
    );
  }

  List<AvailabilitySlot> get availableSlots =>
      slots.where((AvailabilitySlot slot) => slot.available).toList(growable: false);

  bool get hasFreeSlots => slots.any((AvailabilitySlot slot) => slot.available);
}

/// Response of `GET /venues/{id}/availability?date=YYYY-MM-DD`
/// (`VenueAvailability`).
class VenueAvailability {
  const VenueAvailability({
    required this.venue,
    required this.date,
    required this.spaces,
  });

  final Venue venue;

  /// Echoed by the API as `"2026-10-17"`.
  final String date;

  final List<SpaceAvailability> spaces;

  factory VenueAvailability.fromJson(Map<String, dynamic> json) {
    return VenueAvailability(
      venue: Venue.fromJson(json['venue'] as Map<String, dynamic>),
      date: json['date'] as String? ?? '',
      spaces: _parseSpaces(json['spaces']),
    );
  }

  List<AvailabilitySlot> slotsOf(int sportSpaceId) {
    for (final SpaceAvailability item in spaces) {
      if (item.space.id == sportSpaceId) {
        return item.slots;
      }
    }
    return const <AvailabilitySlot>[];
  }
}

List<AvailabilitySlot> _parseSlots(Object? value) {
  if (value is! List) {
    return const <AvailabilitySlot>[];
  }
  return value
      .whereType<Map<String, dynamic>>()
      .map(AvailabilitySlot.fromJson)
      .toList(growable: false);
}

List<SpaceAvailability> _parseSpaces(Object? value) {
  if (value is! List) {
    return const <SpaceAvailability>[];
  }
  return value
      .whereType<Map<String, dynamic>>()
      .map(SpaceAvailability.fromJson)
      .toList(growable: false);
}
