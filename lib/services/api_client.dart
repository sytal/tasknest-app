import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // Android emulator must use 10.0.2.2 instead of localhost to reach the host machine.
  static const String baseUrl = 'http://127.0.0.1:8012/api';

  static Future<http.Response> get(String path) {
    return http.get(Uri.parse('$baseUrl$path'), headers: _headers());
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
  }

  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
