/// User as returned by the API (`UserOut` in backend/openapi.json).
///
/// Fields: `id`, `email`, `first_name`, `last_name`, `birth_date`, `created_at`.
class User {
  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.birthDate,
    this.createdAt,
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;

  /// `birth_date` is nullable in the API (`"1996-03-08"`).
  final DateTime? birthDate;

  /// `created_at`, an ISO-8601 UTC timestamp.
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      birthDate: _parseDate(json['birth_date']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'birth_date': birthDate == null ? null : _formatDate(birthDate!),
        'created_at': createdAt?.toUtc().toIso8601String(),
      };

  User copyWith({
    String? firstName,
    String? lastName,
    DateTime? birthDate,
  }) {
    return User(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthDate: birthDate ?? this.birthDate,
      createdAt: createdAt,
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  /// First name, used for the home greeting.
  String get displayName => firstName.isEmpty ? email : firstName;

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
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
