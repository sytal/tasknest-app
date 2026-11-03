import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/task_assignee.dart';
import '../models/user.dart';
import 'api_client.dart';

class UserService {
  static Future<List<TaskAssignee>> list() async {
    final data = await ApiClient.get('/users');
    final items = (data as List<dynamic>? ?? []);
    return items
        .map((e) => TaskAssignee.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new user account. Only director/ceo accounts should be able
  /// to reach this from the UI; the backend also enforces authorization.
  static Future<TaskAssignee> create({
    required String name,
    required String email,
    required String password,
    required String role, // director | ceo | member
    String? designation,
  }) async {
    final data = await ApiClient.post('/users', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      if (designation != null && designation.isNotEmpty) 'designation': designation,
    });
    return TaskAssignee.fromJson(data as Map<String, dynamic>);
  }

  /// Uploads [bytes] as the current user's avatar via multipart POST and
  /// returns the updated user (carrying the new `avatar_url`).
  static Future<AppUser> uploadAvatar({
    required Uint8List bytes,
    required String filename,
  }) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/me/avatar');
    final request = http.MultipartRequest('POST', uri);

    final token = await ApiClient.getToken();
    request.headers['Accept'] = 'application/json';
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes('avatar', bytes, filename: filename),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    dynamic decoded;
    try {
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Upload failed (${response.statusCode})';
      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] != null) {
          message = decoded['message'].toString();
        } else if (decoded['errors'] != null) {
          message = decoded['errors'].toString();
        }
      }
      throw ApiException(response.statusCode, message);
    }

    final data = decoded is Map<String, dynamic> && decoded.containsKey('data')
        ? decoded['data']
        : decoded;
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  /// Removes the current user's avatar. The backend may or may not return
  /// the updated user body on delete, so callers should clear `avatarUrl`
  /// locally on success rather than relying on a response payload.
  static Future<void> deleteAvatar() async {
    await ApiClient.delete('/me/avatar');
  }
}
