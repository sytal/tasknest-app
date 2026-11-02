import '../models/task.dart';
import 'api_client.dart';

class TaskService {
  static Future<List<TaskItem>> list({
    int? projectId,
    String? status,
    int? assignee,
  }) async {
    final params = <String, String>{};
    if (projectId != null) params['project_id'] = '$projectId';
    if (status != null) params['status'] = status;
    if (assignee != null) params['assignee'] = '$assignee';

    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';

    final data = await ApiClient.get('/tasks$query');
    final items = (data as List<dynamic>? ?? []);
    return items
        .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<TaskItem> create({
    required String title,
    String? description,
    required String priority,
    String? dueDate,
    required int projectId,
    required int assigneeId,
  }) async {
    final data = await ApiClient.post('/tasks', {
      'title': title,
      'description': description,
      'priority': priority,
      'due_date': dueDate,
      'project_id': projectId,
      'assignee_id': assigneeId,
    });
    return TaskItem.fromJson(data as Map<String, dynamic>);
  }

  static Future<TaskItem> update({
    required int id,
    required String title,
    String? description,
    required String priority,
    String? dueDate,
    required int assigneeId,
    required String status,
  }) async {
    final data = await ApiClient.put('/tasks/$id', {
      'title': title,
      'description': description,
      'priority': priority,
      'due_date': dueDate,
      'assignee_id': assigneeId,
      'status': status,
    });
    return TaskItem.fromJson(data as Map<String, dynamic>);
  }

  static Future<TaskItem> updateStatus({
    required int id,
    required String status,
  }) async {
    final data = await ApiClient.patch('/tasks/$id/status', {
      'status': status,
    });
    return TaskItem.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> delete(int id) async {
    await ApiClient.delete('/tasks/$id');
  }
}
