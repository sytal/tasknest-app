import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when the API returns an error response.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  /// Laravel 422 `errors` map: field name -> first message.
  final Map<String, String> fieldErrors;

  /// Seconds to wait before retrying (429 `Retry-After`), if provided.
  final int? retryAfter;

  ApiException(
    this.statusCode,
    this.message, {
    this.fieldErrors = const {},
    this.retryAfter,
  });

  @override
  String toString() => message;
}

/// Thin HTTP wrapper around the TaskNest Laravel API.
///
/// Base URL note:
/// - Desktop / web / iOS simulator: `http://127.0.0.1:8012/api` works fine.
/// - Android emulator: the host machine is reachable at `10.0.2.2`, so use
///   `http://10.0.2.2:8012/api` instead (127.0.0.1 inside the emulator points
///   to the emulator itself, not your dev machine).
/// - Physical device: use your machine's LAN IP, e.g. `http://192.168.x.x:8012/api`.
///
/// Change [baseUrl] below as needed for the platform you're testing on.
class ApiClient {
  /// Override at build time: `--dart-define=API_BASE_URL=https://api.example.com/api`.
  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8012/api',
  );

  /// Always without a trailing slash (paths start with `/`).
  static final String baseUrl = _rawBaseUrl.replaceAll(RegExp(r'/+$'), '');

  static const _tokenKey = 'tasknest_token';

  static String? _cachedToken;

  /// Test hook: forget the in-memory token so storage is re-read.
  static void resetCacheForTests() => _cachedToken = null;

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  static Future<void> setToken(String? token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  static Future<Map<String, String>> _headers() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = await getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _handle(response);
  }

  /// GET returning the whole JSON body (keeps `meta` / `links` of paginated
  /// responses, which [get] strips by unwrapping `data`).
  static Future<Map<String, dynamic>> getPage(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    _handle(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handle(response);
  }

  static Future<Map<String, dynamic>> postRaw(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _handle(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handle(response);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handle(response);
  }

  static Future<dynamic> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _handle(response);
  }

  static dynamic _handle(http.Response response) {
    final status = response.statusCode;
    dynamic decoded;
    try {
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      decoded = null;
    }

    if (status >= 200 && status < 300) {
      // Laravel API Resources wrap both single items and collections in a
      // top-level "data" key. Auth endpoints (login/me) don't use Resources
      // and have no "data" key, so this only unwraps Resource responses.
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        return decoded['data'];
      }
      return decoded;
    }

    String message = 'Request failed ($status)';
    final fields = <String, String>{};
    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] != null) {
        message = decoded['message'].toString();
      }
      final errors = decoded['errors'];
      if (errors is Map) {
        errors.forEach((k, v) {
          final first = v is List && v.isNotEmpty ? v.first : v;
          fields[k.toString()] = first.toString();
        });
      }
    }
    int? retry;
    if (status == 429) {
      retry = int.tryParse(response.headers['retry-after'] ?? '');
      message = retry == null
          ? 'Too many attempts. Please wait a moment and try again.'
          : 'Too many attempts. Try again in $retry seconds.';
    }
    throw ApiException(status, message, fieldErrors: fields, retryAfter: retry);
  }
}
