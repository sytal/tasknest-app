import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  static Future<AppUser> login(String email, String password) async {
    final data = await ApiClient.post('/login', {
      'email': email,
      'password': password,
    });
    final token = data['token']?.toString();
    if (token == null) {
      throw Exception('Login response missing token');
    }
    await ApiClient.setToken(token);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  static Future<void> logout() async {
    try {
      await ApiClient.post('/logout', {});
    } catch (_) {
      // Ignore network/server errors on logout; always clear local token.
    } finally {
      await ApiClient.setToken(null);
    }
  }

  static Future<AppUser> me() async {
    final data = await ApiClient.get('/me') as Map<String, dynamic>;
    // /me responds with {"user": {...}} (no "data" wrapper).
    final user = data['user'] ?? data;
    return AppUser.fromJson(user as Map<String, dynamic>);
  }

  static Future<bool> hasToken() async {
    final token = await ApiClient.getToken();
    return token != null && token.isNotEmpty;
  }
}
