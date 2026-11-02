import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when the API returns an error response.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

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
  static const String baseUrl = 'http://127.0.0.1:8012/api';

  static const _tokenKey = 'tasknest_token';

  static String? _cachedToken;

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

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handle(response);
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
    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] != null) {
        message = decoded['message'].toString();
      } else if (decoded['errors'] != null) {
        message = decoded['errors'].toString();
      }
    }
    throw ApiException(status, message);
  }
}
