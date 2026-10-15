/// Sports space (cancha / espacio deportivo) as returned by the API
/// (`SportSpaceOut`).
///
/// Fields: `id`, `venue_id`, `venue_name`, `name`, `space_type`, `number`.
/// Real names look like `Moron_Rivadavia_19850_Paddle_1` and the types used by
/// the demo data are `Futbol`, `Paddle` and `Basquet`.
class SportSpace {
  const SportSpace({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.name,
    required this.spaceType,
    required this.number,
  });

  final int id;
  final int venueId;
  final String venueName;
  final String name;
  final String spaceType;
  final int number;

  factory SportSpace.fromJson(Map<String, dynamic> json) {
    return SportSpace(
      id: (json['id'] as num).toInt(),
      venueId: (json['venue_id'] as num?)?.toInt() ?? 0,
      venueName: json['venue_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      spaceType: json['space_type'] as String? ?? '',
      number: (json['number'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'venue_id': venueId,
        'venue_name': venueName,
        'name': name,
        'space_type': spaceType,
        'number': number,
      };

  /// Friendly label for the UI: `Paddle 1`.
  String get displayName => '$spaceType $number'.trim();
}

/// Space types used by the demo data, handy for the filter chips.
class SpaceTypes {
  SpaceTypes._();

  static const String futbol = 'Futbol';
  static const String paddle = 'Paddle';
  static const String basquet = 'Basquet';
}
