/// Error codes returned by the API in the `code` field of
/// `{"detail": "...", "code": "..."}` (see backend/openapi.json and
/// backend/docs/api.md). Keep this list in sync with the backend.
class ApiErrorCodes {
  ApiErrorCodes._();

  // Auth
  static const String emailAlreadyRegistered = 'email_already_registered';
  static const String invalidCredentials = 'invalid_credentials';
  static const String invalidResetToken = 'invalid_reset_token';
  static const String resetTokenUsed = 'reset_token_used';
  static const String resetTokenExpired = 'reset_token_expired';
  static const String passwordUpdated = 'password_updated';

  // Token / transversal
  static const String missingToken = 'missing_token';
  static const String invalidToken = 'invalid_token';
  static const String tokenExpired = 'token_expired';
  static const String validationError = 'validation_error';
  static const String forbidden = 'forbidden';
  static const String notFound = 'not_found';
  static const String methodNotAllowed = 'method_not_allowed';
  static const String internalError = 'internal_error';

  // Profile
  static const String emailNotEditable = 'email_not_editable';

  // Catalog
  static const String venueNotFound = 'venue_not_found';
  static const String spaceNotFound = 'space_not_found';

  // Reservations
  static const String invalidDuration = 'invalid_duration';
  static const String invalidTimeGranularity = 'invalid_time_granularity';
  static const String invalidRange = 'invalid_range';
  static const String outsideVenueHours = 'outside_venue_hours';
  static const String reservationInThePast = 'reservation_in_the_past';
  static const String spaceNotAvailable = 'space_not_available';
  static const String spaceInactive = 'space_inactive';
  static const String venueInactive = 'venue_inactive';
  static const String reservationNotFound = 'reservation_not_found';
  static const String notReservationOwner = 'not_reservation_owner';
  static const String reservationAlreadyCancelled = 'reservation_already_cancelled';

  // Errors generated on the client (no HTTP response involved).
  static const String networkError = 'network_error';
  static const String timeoutError = 'timeout_error';
  static const String unexpectedError = 'unexpected_error';
}

/// Every failure the app can show to the user is represented by this class.
///
/// It covers both errors coming from the API (which carry the `detail` and
/// `code` fields) and connectivity problems detected on the device.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.rawBody,
  });

  /// Generic message for failures the server did not describe with the API's
  /// `{"detail": ..., "code": ...}` shape (an HTML page from a proxy, a
  /// plain-text body, an empty answer). Nothing raw ever reaches the screen.
  static const String genericMessage =
      'Ocurrió un error inesperado. Intentá de nuevo.';

  /// Machine readable code: either an [ApiErrorCodes] value or a code returned
  /// by the backend.
  final String code;

  /// Message returned by the API (`detail`) or a local message.
  final String message;

  /// HTTP status, or `null` when the request never reached the server.
  final int? statusCode;

  /// Raw response body when it was NOT a JSON error object. It is kept only for
  /// the log (see [toString]); the user always sees [message] instead.
  final String? rawBody;

  /// The device could not reach the server (no internet, server down, DNS).
  factory ApiException.network() => const ApiException(
        code: ApiErrorCodes.networkError,
        message: 'No pudimos conectarnos con el servidor.',
      );

  /// The server did not answer within the configured timeout.
  factory ApiException.timeout() => const ApiException(
        code: ApiErrorCodes.timeoutError,
        message: 'El servidor tardó demasiado en responder.',
      );

  /// Unexpected client side failure (malformed body, unexpected status...).
  factory ApiException.unexpected([int? statusCode]) => ApiException(
        code: ApiErrorCodes.unexpectedError,
        message: 'Ocurrió un error inesperado.',
        statusCode: statusCode,
      );

  /// Builds the exception from the standard API error body
  /// `{"detail": "...", "code": "..."}`.
  ///
  /// `detail` is normally a string, but FastAPI's own validation errors send a
  /// list of objects, so both shapes are supported.
  factory ApiException.fromBody(Object? body, {int? statusCode}) {
    if (body is Map) {
      final String? code = body['code'] is String ? body['code'] as String : null;
      final Object? detail = body['detail'];
      if (detail is String && detail.isNotEmpty) {
        return ApiException(
          code: code ?? ApiErrorCodes.unexpectedError,
          message: detail,
          statusCode: statusCode,
        );
      }
      if (detail is List && detail.isNotEmpty) {
        final List<String> messages = <String>[];
        for (final Object? item in detail) {
          if (item is Map && item['msg'] is String) {
            final String field = item['loc'] is List && (item['loc'] as List).isNotEmpty
                ? (item['loc'] as List).last.toString()
                : 'campo';
            messages.add('$field: ${item['msg']}');
          }
        }
        if (messages.isNotEmpty) {
          return ApiException(
            code: code ?? ApiErrorCodes.validationError,
            message: messages.join('\n'),
            statusCode: statusCode,
          );
        }
      }
      if (code != null) {
        return ApiException(
          code: code,
          message: 'La operación no se pudo completar.',
          statusCode: statusCode,
        );
      }
    }
    if (body is String && body.trim().isNotEmpty && statusCode != null) {
      // Not a JSON error object: an HTML page, a plain-text body... The raw
      // text is useless (and confusing) for the user, so it is kept only for
      // the log and a generic message is shown instead.
      return ApiException(
        code: _codeFromStatus(statusCode),
        message: genericMessage,
        statusCode: statusCode,
        rawBody: body,
      );
    }
    return ApiException(
      code: _codeFromStatus(statusCode),
      message: genericMessage,
      statusCode: statusCode,
    );
  }

  /// True when the session is no longer valid (expired or invalid token).
  bool get isSessionExpired =>
      statusCode == 401 &&
      (code == ApiErrorCodes.tokenExpired ||
          code == ApiErrorCodes.invalidToken ||
          code == ApiErrorCodes.missingToken);

  /// True when the request never reached the server (offline, timeout).
  bool get isConnectivityProblem =>
      code == ApiErrorCodes.networkError || code == ApiErrorCodes.timeoutError;

  /// Message shown in the UI: the text the assignment asks for on the
  /// well-known cases, the API `detail` on any other server error.
  String get userMessage {
    switch (code) {
      case ApiErrorCodes.networkError:
      case ApiErrorCodes.timeoutError:
        return 'No pudimos conectarnos con el servidor. Revisá tu conexión.';
      case ApiErrorCodes.invalidCredentials:
        return 'El correo o la contraseña son incorrectos.';
      case ApiErrorCodes.emailAlreadyRegistered:
        return 'Ya existe una cuenta con ese correo.';
      case ApiErrorCodes.spaceNotAvailable:
        return 'Ese horario se acaba de ocupar. Elegí otro.';
      default:
        return message.isEmpty ? 'La operación no se pudo completar.' : message;
    }
  }

  static String _codeFromStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return ApiErrorCodes.validationError;
      case 401:
        return ApiErrorCodes.invalidToken;
      case 403:
        return ApiErrorCodes.forbidden;
      case 404:
        return ApiErrorCodes.notFound;
      case 405:
        return ApiErrorCodes.methodNotAllowed;
      case 500:
        return ApiErrorCodes.internalError;
      default:
        return ApiErrorCodes.unexpectedError;
    }
  }

  @override
  String toString() {
    final String raw = rawBody == null ? '' : ' rawBody: $rawBody';
    return 'ApiException($code, status: $statusCode): $message$raw';
  }
}
