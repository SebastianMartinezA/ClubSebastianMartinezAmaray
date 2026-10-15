import '../models/api_error.dart';
import '../models/user.dart';
import '../utils/formatters.dart';
import 'api_client.dart';
import 'session_storage.dart';

/// Authentication and profile operations, plus the persistence of the session.
///
/// Endpoints used: `POST /auth/login`, `POST /auth/register`,
/// `POST /auth/forgot-password`, `POST /auth/reset-password`, `GET /users/me`
/// and `PATCH /users/me`.
class AuthService {
  AuthService({required ApiClient api, required SessionStorage storage})
      : _api = api,
        _storage = storage;

  final ApiClient _api;
  final SessionStorage _storage;

  String? _token;
  User? _user;

  String? get token => _token;

  User? get user => _user;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// `POST /auth/login`; on success the token is stored and applied to [ApiClient].
  Future<User> login({required String email, required String password}) async {
    final Map<String, dynamic> json = await _api.postMap(
      '/auth/login',
      body: <String, dynamic>{'email': email.trim(), 'password': password},
    );
    return _applyTokenResponse(json);
  }

  /// `POST /auth/register`; the API answers `201` with a token, so the user is
  /// logged in right away.
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    DateTime? birthDate,
  }) async {
    final Map<String, dynamic> json = await _api.postMap(
      '/auth/register',
      body: <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'birth_date': birthDate == null ? null : Formatters.toIsoDate(birthDate),
      },
    );
    return _applyTokenResponse(json);
  }

  /// `POST /auth/forgot-password`.
  ///
  /// The API always answers `200` with a generic message (it never reveals
  /// whether the email exists). `reset_token` only comes with a value in the
  /// test environment (`DEBUG=true`, no SMTP configured), so the returned value
  /// may be `null`.
  Future<String?> requestPasswordReset(String email) async {
    final Map<String, dynamic> json = await _api.postMap(
      '/auth/forgot-password',
      body: <String, dynamic>{'email': email.trim()},
    );
    return json['reset_token'] as String?;
  }

  /// `POST /auth/reset-password`. Returns the confirmation message of the API.
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final Map<String, dynamic> json = await _api.postMap(
      '/auth/reset-password',
      body: <String, dynamic>{'token': token.trim(), 'new_password': newPassword},
    );
    return json['detail'] as String? ?? 'Contraseña actualizada.';
  }

  /// `GET /users/me`: refreshes the cached profile.
  Future<User> fetchProfile() async {
    final Map<String, dynamic> json = await _api.getMap('/users/me');
    _user = User.fromJson(json);
    await _persist();
    return _user!;
  }

  /// `PATCH /users/me`.
  ///
  /// Only the fields that changed are sent, and the email is never included:
  /// the API rejects any attempt to change it with `400 email_not_editable`.
  Future<User> updateProfile({
    String? firstName,
    String? lastName,
    DateTime? birthDate,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (firstName != null && firstName.trim().isNotEmpty) {
      body['first_name'] = firstName.trim();
    }
    if (lastName != null && lastName.trim().isNotEmpty) {
      body['last_name'] = lastName.trim();
    }
    if (birthDate != null) {
      body['birth_date'] = Formatters.toIsoDate(birthDate);
    }
    final Map<String, dynamic> json = await _api.patchMap('/users/me', body: body);
    _user = User.fromJson(json);
    await _persist();
    return _user!;
  }

  /// Reads the persisted session (if any) and applies the token to [ApiClient].
  ///
  /// Returns `true` when there is a session to restore.
  Future<bool> restore() async {
    final SessionData? data = await _storage.read();
    if (data == null || data.token.isEmpty) {
      return false;
    }
    _token = data.token;
    _api.authToken = data.token;
    try {
      _user = User.fromJson(data.user);
    } on TypeError {
      _user = null;
    }
    return true;
  }

  /// Forgets the session locally (the API has no logout endpoint: tokens are
  /// stateless JWTs).
  Future<void> logout() async {
    _token = null;
    _user = null;
    _api.authToken = null;
    await _storage.clear();
  }

  Future<User> _applyTokenResponse(Map<String, dynamic> json) async {
    final String? token = json['access_token'] as String?;
    final Object? rawUser = json['user'];
    if (token == null || token.isEmpty || rawUser is! Map<String, dynamic>) {
      throw ApiException.unexpected();
    }
    _token = token;
    _api.authToken = token;
    _user = User.fromJson(rawUser);
    await _persist();
    return _user!;
  }

  Future<void> _persist() async {
    final String? token = _token;
    final User? user = _user;
    if (token == null || user == null) {
      return;
    }
    await _storage.save(SessionData(token: token, user: user.toJson()));
  }
}
