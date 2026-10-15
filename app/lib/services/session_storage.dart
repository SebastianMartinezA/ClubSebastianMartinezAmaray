import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted session payload: the bearer token plus the cached user.
class SessionData {
  const SessionData({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;
}

/// Storage of the session between app launches.
///
/// It is an interface so tests can use [InMemorySessionStorage] and never touch
/// the platform channels of `shared_preferences`.
abstract class SessionStorage {
  Future<SessionData?> read();

  Future<void> save(SessionData data);

  Future<void> clear();
}

/// Real implementation, backed by `shared_preferences`.
class SharedPreferencesSessionStorage implements SessionStorage {
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';

  @override
  Future<SessionData?> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(tokenKey);
    final String? rawUser = prefs.getString(userKey);
    if (token == null || token.isEmpty || rawUser == null || rawUser.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        return SessionData(token: token, user: decoded);
      }
    } on FormatException {
      await clear();
    }
    return null;
  }

  @override
  Future<void> save(SessionData data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, data.token);
    await prefs.setString(userKey, jsonEncode(data.user));
  }

  @override
  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userKey);
  }
}

/// In-memory implementation used by tests.
class InMemorySessionStorage implements SessionStorage {
  SessionData? _data;

  @override
  Future<SessionData?> read() async => _data;

  @override
  Future<void> save(SessionData data) async => _data = data;

  @override
  Future<void> clear() async => _data = null;
}
