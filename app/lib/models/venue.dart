/// Venue (sede) as returned by the API (`VenueOut`).
///
/// Fields: `id`, `name`, `address`, `opening_time`, `closing_time`.
/// Times are wall-clock times of the venue and always come as `"HH:MM:SS"`.
class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.address,
    required this.openingTime,
    required this.closingTime,
  });

  final int id;
  final String name;
  final String address;

  /// `"08:00:00"`.
  final String openingTime;

  /// `"22:00:00"`.
  final String closingTime;

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      openingTime: json['opening_time'] as String? ?? '',
      closingTime: json['closing_time'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'address': address,
        'opening_time': openingTime,
        'closing_time': closingTime,
      };
}
