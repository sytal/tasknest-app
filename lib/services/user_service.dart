import '../models/task_assignee.dart';
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
}
