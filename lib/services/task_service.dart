import '../models/task.dart';
import 'api_client.dart';

class TaskService {
  static Future<List<TaskItem>> list({
    int? projectId,
    String? status,
    int? assignee,
  }) async {
    // Spatie QueryBuilder (backend) expects filters nested under filter[...],
    // e.g. ?filter[project_id]=4 — a bare ?project_id=4 is silently ignored.
    final params = <String, String>{};
    if (projectId != null) params['filter[project_id]'] = '$projectId';
    if (status != null) params['filter[status]'] = status;
    if (assignee != null) params['filter[assignee_id]'] = '$assignee';

    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

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
    final data = await ApiClient.patch('/tasks/$id/status', {'status': status});
    return TaskItem.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> delete(int id) async {
    await ApiClient.delete('/tasks/$id');
  }

  /// Bulk-assigns [taskIds] to [assigneeIds]. If a single assignee is given,
  /// all tasks go to them; if multiple are given, the backend splits tasks
  /// evenly between them.
  static Future<void> bulkAssign({
    required int projectId,
    required List<int> taskIds,
    required List<int> assigneeIds,
  }) async {
    await ApiClient.post('/projects/$projectId/tasks/bulk-assign', {
      'task_ids': taskIds,
      'assignee_ids': assigneeIds,
    });
  }
}
