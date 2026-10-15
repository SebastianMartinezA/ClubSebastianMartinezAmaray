import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/api_error.dart';

/// Thin HTTP layer over the REST API.
///
/// Responsibilities:
/// * builds the URL from [ApiConfig.baseUrl] and attaches the bearer token;
/// * decodes JSON with UTF-8 (the API answers `application/json` without a
///   charset, and the default of the `http` package would mangle accents);
/// * turns every failure into an [ApiException], so screens never deal with
///   `SocketException`, timeouts or raw status codes.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client, Duration? timeout})
      : baseUrl = _normalizeBaseUrl(baseUrl ?? ApiConfig.baseUrl),
        _client = client ?? http.Client(),
        _timeout = timeout ?? ApiConfig.requestTimeout;

  /// Base URL used for every request, without trailing slash.
  final String baseUrl;

  final http.Client _client;
  final Duration _timeout;

  /// Bearer token of the current session; set by `AuthService`.
  String? authToken;

  /// Called when the API rejects the token (it expired or is invalid) so the
  /// session can be closed and the app can go back to the login screen.
  void Function()? onUnauthorized;

  /// Releases the underlying HTTP connection pool.
  void close() => _client.close();

  /// `GET` returning a JSON object.
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String>? query,
  }) async {
    return _asMap(await _send('GET', path, query: query));
  }

  /// `GET` returning a JSON array of objects.
  Future<List<Map<String, dynamic>>> getItems(
    String path, {
    Map<String, String>? query,
  }) async {
    return _asItems(await _send('GET', path, query: query));
  }

  /// `POST` returning a JSON object.
  Future<Map<String, dynamic>> postMap(
    String path, {
    Object? body,
  }) async {
    return _asMap(await _send('POST', path, body: body));
  }

  /// `POST` without expecting a body in the answer.
  Future<void> post(String path, {Object? body}) async {
    await _send('POST', path, body: body);
  }

  /// `PATCH` returning a JSON object.
  Future<Map<String, dynamic>> patchMap(
    String path, {
    Object? body,
  }) async {
    return _asMap(await _send('PATCH', path, body: body));
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    Uri uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    final http.Request request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    final String? token = authToken;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      final http.StreamedResponse streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } on SocketException {
      throw ApiException.network();
    } on http.ClientException {
      throw ApiException.network();
    } on IOException {
      throw ApiException.network();
    }

    final Object? decoded = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final ApiException exception =
        ApiException.fromBody(decoded, statusCode: response.statusCode);
    if (exception.isSessionExpired) {
      onUnauthorized?.call();
    }
    throw exception;
  }

  Object? _decode(http.Response response) {
    final String text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (text.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(text);
    } on FormatException {
      // The endpoint answered with something that is not JSON (a proxy error
      // page, for instance): keep the text so it can be shown.
      return text;
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((Object? key, Object? item) => MapEntry<String, dynamic>(key.toString(), item));
    }
    throw ApiException.unexpected();
  }

  List<Map<String, dynamic>> _asItems(Object? value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    throw ApiException.unexpected();
  }

  static String _normalizeBaseUrl(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
