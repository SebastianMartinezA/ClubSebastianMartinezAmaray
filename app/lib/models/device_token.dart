/// Registered push device (`DeviceTokenOut` in backend/openapi.json).
///
/// Fields: `id`, `token`, `platform`, `created_at`.
class DeviceToken {
  const DeviceToken({
    required this.id,
    required this.token,
    required this.platform,
    this.createdAt,
  });

  final int id;
  final String token;
  final String platform;
  final DateTime? createdAt;

  factory DeviceToken.fromJson(Map<String, dynamic> json) {
    return DeviceToken(
      id: (json['id'] as num?)?.toInt() ?? 0,
      token: json['token'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'token': token,
        'platform': platform,
        'created_at': createdAt?.toUtc().toIso8601String(),
      };
}
