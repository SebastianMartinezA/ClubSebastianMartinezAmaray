import 'package:flutter/foundation.dart';

import '../models/api_error.dart';
import '../models/user.dart';
import '../utils/formatters.dart';
import 'api_client.dart';
import 'auth_backend.dart';
import 'firebase_auth_backend.dart';
import 'session_storage.dart';

/// Autenticación y perfil.
///
/// La credencial la maneja **Firebase Authentication** (email y contraseña): el
/// login y el registro se hacen contra Firebase y lo que viaja al backend es el
/// **ID token** que emite, firmado con RS256 y válido una hora. El backend lo
/// valida contra las claves públicas de Google.
///
/// El perfil y los permisos (`is_admin`) siguen viviendo en PostgreSQL:
/// `POST /auth/firebase-sync` crea o actualiza la fila local asociada al correo
/// del token, así las reservas quedan relacionadas con un usuario de la base.
///
/// Endpoints propios que se siguen usando: `POST /auth/firebase-sync`,
/// `GET /users/me` y `PATCH /users/me`.
///
/// El SDK de Firebase se usa a través de [AuthBackend]: los tests inyectan una
/// implementación falsa y no dependen del plugin.
class AuthService {
  AuthService({
    required ApiClient api,
    required SessionStorage storage,
    AuthBackend? backend,
  })  : _api = api,
        _storage = storage,
        _backend = backend ?? FirebaseAuthBackend();

  final ApiClient _api;
  final SessionStorage _storage;
  final AuthBackend _backend;

  String? _token;
  User? _user;

  /// Código propio para distinguir "el usuario cerró el diálogo de Google".
  static const String googleCancelled = AuthBackendCodes.googleCancelled;

  String? get token => _token;

  User? get user => _user;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// `signInWithEmailAndPassword` de Firebase Auth.
  ///
  /// El backend no recibe la contraseña: sólo el ID token que devuelve Firebase.
  Future<User> login({required String email, required String password}) async {
    try {
      await _backend.signInWithPassword(email: email.trim(), password: password);
    } on AuthBackendException catch (error) {
      throw _mapAuthError(error);
    }
    return _startSession();
  }

  /// Ingreso con la cuenta de Google.
  ///
  /// Google autentica la cuenta y entrega un `idToken`; Firebase lo canjea por
  /// su propio ID token, que es el que valida el backend. Si el correo todavía
  /// no tiene fila en PostgreSQL, `_startSession` la crea con
  /// `POST /auth/firebase-sync` usando el nombre del perfil de Google.
  Future<User> signInWithGoogle() async {
    final AuthUser? account;
    try {
      account = await _backend.signInWithGoogle();
    } on AuthBackendException catch (error) {
      if (error.code == AuthBackendCodes.googlePlatformError) {
        throw ApiException(
          code: ApiErrorCodes.unexpectedError,
          message: 'No pudimos abrir la cuenta de Google (${error.message}). '
              'Revisá que la app esté firmada con la huella registrada en Firebase.',
        );
      }
      if (error.code == AuthBackendCodes.googleMissingToken) {
        throw const ApiException(
          code: ApiErrorCodes.unexpectedError,
          message: 'Google no devolvió la credencial. Suele faltar la huella SHA-1 '
              'del APK en Firebase (Configuración del proyecto → Tus apps).',
        );
      }
      throw _mapAuthError(error);
    }
    if (account == null) {
      // El usuario cerró el diálogo: no es un error, la pantalla no muestra nada.
      throw const ApiException(
        code: googleCancelled,
        message: 'Cancelaste el ingreso con Google.',
      );
    }
    return _startSession();
  }

  /// `createUserWithEmailAndPassword` de Firebase Auth y después el alta del
  /// perfil local con `POST /auth/firebase-sync`.
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    DateTime? birthDate,
  }) async {
    try {
      await _backend.createUser(
        email: email.trim(),
        password: password,
        displayName: '${firstName.trim()} ${lastName.trim()}'.trim(),
      );
    } on AuthBackendException catch (error) {
      throw _mapAuthError(error);
    }

    await _api.postMap(
      '/auth/firebase-sync',
      body: <String, dynamic>{
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'birth_date': birthDate == null ? null : Formatters.toIsoDate(birthDate),
      },
    );
    return _startSession();
  }

  /// Pide a Firebase el correo de recuperación de contraseña.
  ///
  /// El envío y el cambio de contraseña quedan del lado de Firebase, así que no
  /// hay token propio que devolver: se mantiene la firma `Future<String?>` para no
  /// tocar la pantalla. Nunca se revela si el correo existe.
  Future<String?> requestPasswordReset(String email) async {
    try {
      await _backend.sendPasswordResetEmail(email: email.trim());
    } on AuthBackendException catch (error) {
      if (error.code != 'user-not-found') {
        throw _mapAuthError(error);
      }
    }
    return null;
  }

  /// `POST /auth/reset-password` del backend (flujo de respaldo con token propio).
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

  /// Restaura la sesión: si Firebase tiene un usuario recordado, se pide un ID
  /// token nuevo (no se reusa el guardado, que puede estar vencido) y se refresca
  /// el perfil cacheado.
  Future<bool> restore() async {
    final AuthUser? fbUser = await _backend.currentUser();
    if (fbUser == null) {
      await _storage.clear();
      return false;
    }

    _api.tokenProvider = fbUser.getIdToken;
    final String? idToken = await fbUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      await _storage.clear();
      return false;
    }
    _token = idToken;
    _api.authToken = idToken;

    // El perfil guardado se muestra al instante; el refresco va en segundo plano
    // para que la apertura de la app no dependa de la red.
    final SessionData? data = await _storage.read();
    if (data != null) {
      try {
        _user = User.fromJson(data.user);
      } on TypeError {
        _user = null;
      }
    }
    if (_user == null) {
      try {
        await fetchProfile();
      } on ApiException catch (error) {
        debugPrint('[auth] no se pudo refrescar el perfil al restaurar: $error');
        return false;
      }
    }
    return true;
  }

  /// Cierra la sesión en Firebase y olvida el perfil local.
  Future<void> logout() async {
    _token = null;
    _user = null;
    _api.tokenProvider = null;
    _api.authToken = null;
    try {
      await _backend.signOut();
    } catch (error) {
      debugPrint('[auth] no se pudo cerrar la sesión de Firebase: $error');
    }
    await _storage.clear();
  }

  /// Arma la sesión local a partir del usuario que Firebase acaba de autenticar.
  Future<User> _startSession() async {
    final AuthUser? fbUser = await _backend.currentUser();
    if (fbUser == null) {
      throw const ApiException(
        code: ApiErrorCodes.invalidCredentials,
        message: 'No pudimos iniciar la sesión.',
      );
    }

    // Cada request pide el ID token vigente: Firebase lo renueva solo.
    _api.tokenProvider = fbUser.getIdToken;
    final String? idToken = await fbUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw ApiException.unexpected();
    }

    _token = idToken;
    _api.authToken = idToken;

    try {
      _user = User.fromJson(await _api.getMap('/users/me'));
    } on ApiException catch (error) {
      // El usuario existe en Firebase pero todavía no en la base (por ejemplo, si
      // lo crearon desde la consola de Firebase): se da de alta con el nombre que
      // tenga el perfil de Firebase y se reintenta una sola vez.
      if (!error.isSessionExpired) {
        rethrow;
      }
      await _syncLocalProfile(fbUser);
      _user = User.fromJson(await _api.getMap('/users/me'));
    }

    await _persist();
    return _user!;
  }

  /// `POST /auth/firebase-sync` con los datos del perfil de Firebase.
  Future<void> _syncLocalProfile(AuthUser fbUser) async {
    final String displayName = (fbUser.displayName ?? '').trim();
    final List<String> parts =
        displayName.isEmpty ? <String>[] : displayName.split(RegExp(r'\s+'));
    final String firstName = parts.isEmpty ? '' : parts.first;
    final String lastName = parts.length < 2 ? '' : parts.sublist(1).join(' ');

    try {
      await _api.postMap(
        '/auth/firebase-sync',
        body: <String, dynamic>{
          'first_name': firstName.isEmpty ? null : firstName,
          'last_name': lastName.isEmpty ? null : lastName,
        },
      );
    } on ApiException catch (error) {
      if (error.code == 'names_required') {
        throw const ApiException(
          code: ApiErrorCodes.validationError,
          message: 'La cuenta existe pero le faltan el nombre y el apellido: '
              'volvé a registrarte con el mismo correo.',
        );
      }
      rethrow;
    }
  }

  /// Traduce los errores del proveedor a los códigos que ya conoce la UI.
  ApiException _mapAuthError(AuthBackendException error) {
    switch (error.code) {
      case 'invalid-email':
        return const ApiException(
          code: ApiErrorCodes.validationError,
          message: 'El correo no tiene un formato válido.',
        );
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'user-disabled':
        // Mismo mensaje en los tres casos: no se revela si el correo existe.
        return const ApiException(
          code: ApiErrorCodes.invalidCredentials,
          message: 'El correo o la contraseña son incorrectos.',
        );
      case 'account-exists-with-different-credential':
        // Google dice que el correo ya existe: la cuenta se creó con contraseña.
        return const ApiException(
          code: ApiErrorCodes.emailAlreadyRegistered,
          message: 'Ese correo ya tiene una cuenta con contraseña: ingresá con '
              'tu contraseña o recuperala.',
        );
      case 'email-already-in-use':
        return const ApiException(
          code: ApiErrorCodes.emailAlreadyRegistered,
          message: 'Ya existe una cuenta con ese correo.',
        );
      case 'weak-password':
        return const ApiException(
          code: ApiErrorCodes.validationError,
          message: 'La contraseña es demasiado débil: usá al menos 8 caracteres.',
        );
      case 'network-request-failed':
        return ApiException.network();
      case 'too-many-requests':
        return const ApiException(
          code: ApiErrorCodes.validationError,
          message: 'Demasiados intentos seguidos. Esperá un momento y volvé a probar.',
        );
      case 'operation-not-allowed':
        return const ApiException(
          code: ApiErrorCodes.unexpectedError,
          message: 'El método de acceso con correo y contraseña no está habilitado '
              'en Firebase (Authentication → Sign-in method).',
        );
      case 'configuration-not-found':
        return const ApiException(
          code: ApiErrorCodes.unexpectedError,
          message: 'Firebase Authentication todavía no está habilitado en el proyecto: '
              'entrá a la consola de Firebase → Authentication → Comenzar.',
        );
      case 'invalid-api-key':
      case 'api-key-not-valid':
        return const ApiException(
          code: ApiErrorCodes.unexpectedError,
          message: 'La clave de API de Firebase no es válida para este proyecto.',
        );
      default:
        return ApiException(
          code: ApiErrorCodes.unexpectedError,
          message: error.message ?? ApiException.genericMessage,
        );
    }
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
