/// Lo que la app necesita de Firebase Authentication, detrás de una interfaz.
///
/// El SDK de Firebase no arranca en un test de host (`No Firebase App '[DEFAULT]'
/// has been created`), así que la app nunca lo toca de forma directa: pide estas
/// operaciones y el test inyecta una implementación falsa.
library;

/// Error de autenticación con el mismo `code` que devuelve Firebase
/// (`invalid-email`, `wrong-password`, `too-many-requests`, ...).
class AuthBackendException implements Exception {
  const AuthBackendException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'AuthBackendException($code): $message';
}

/// Usuario ya autenticado, con la posibilidad de pedir un ID token vigente.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.getIdToken,
    this.email,
    this.displayName,
  });

  final String id;
  final String? email;
  final String? displayName;

  /// Firebase renueva el token solo; la app pide uno nuevo en cada request.
  final Future<String?> Function() getIdToken;
}

/// Puerto de autenticación. La implementación real es `FirebaseAuthBackend`.
abstract class AuthBackend {
  /// Ingreso con correo y contraseña. Tira [AuthBackendException] si falla.
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  });

  /// Alta de la cuenta en el proveedor (la fila local la crea la API).
  Future<AuthUser> createUser({
    required String email,
    required String password,
    String? displayName,
  });

  /// Ingreso con Google. Devuelve `null` si la persona cerró el selector.
  Future<AuthUser?> signInWithGoogle();

  /// Envía el correo de recuperación de contraseña.
  Future<void> sendPasswordResetEmail({required String email});

  /// Usuario recordado entre aperturas, o `null`.
  Future<AuthUser?> currentUser();

  /// Cierra la sesión en el proveedor.
  Future<void> signOut();
}

/// Códigos propios de Google que no vienen de Firebase.
class AuthBackendCodes {
  static const String googlePlatformError = 'google-sign-in-platform';
  static const String googleMissingToken = 'google-sign-in-no-token';
  static const String googleCancelled = 'google-sign-in-cancelled';
}
