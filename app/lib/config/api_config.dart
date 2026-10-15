/// Configuration of the REST API the app talks to.
///
/// The base URL is injected at build/run time so the same code works in the
/// Android emulator, on a physical phone or against a deployed backend:
///
/// ```bash
/// flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
/// ```
///
/// Default value is the magic address the Android emulator uses to reach the
/// host machine, so `uvicorn` running on the development machine works out of
/// the box.
class ApiConfig {
  ApiConfig._();

  /// Base URL of the API, without a trailing slash.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Timeout applied to every HTTP request.
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Timeout of the cold start check ([ApiClient.warmUp]).
  ///
  /// The free tier of Render puts the service to sleep after 15 minutes of
  /// inactivity and the first request can take close to a minute: with the
  /// normal timeout that first request would fail and look like a connectivity
  /// problem. Only this call waits that long.
  static const Duration warmUpTimeout = Duration(seconds: 90);

  /// Health endpoint used to wake the service up.
  static const String healthPath = '/health';
}
