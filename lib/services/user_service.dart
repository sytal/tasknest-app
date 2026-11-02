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
}
