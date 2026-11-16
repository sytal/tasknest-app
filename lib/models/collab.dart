import 'task_assignee.dart';

class Comment {
  final int id;
  final String body;
  final TaskAssignee? author;
  final DateTime createdAt;
  final bool pending;
  final bool failed;

  Comment({
    required this.id,
    required this.body,
    this.author,
    required this.createdAt,
    this.pending = false,
    this.failed = false,
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    id: j['id'] as int,
    body: j['body']?.toString() ?? '',
    author: j['author'] is Map
        ? TaskAssignee.fromJson(j['author'] as Map<String, dynamic>)
        : null,
    createdAt:
        DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
  );

  Comment copyWith({int? id, bool? pending, bool? failed}) => Comment(
    id: id ?? this.id,
    body: body,
    author: author,
    createdAt: createdAt,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
  );
}

class ActivityItem {
  final int id;
  final String message;
  final int? projectId;
  final DateTime createdAt;

  ActivityItem({
    required this.id,
    required this.message,
    this.projectId,
    required this.createdAt,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> j) => ActivityItem(
    id: j['id'] as int,
    message: j['message']?.toString() ?? '',
    projectId: j['project_id'] as int?,
    createdAt:
        DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
  );
}

class AppNotification {
  final String id;
  final String kind;
  final String message;
  final int? taskId;
  final int? projectId;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.kind,
    required this.message,
    this.taskId,
    this.projectId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'].toString(),
    kind: j['kind']?.toString() ?? '',
    message: j['message']?.toString() ?? '',
    taskId: j['task_id'] as int?,
    projectId: j['project_id'] as int?,
    read: j['read'] == true,
    createdAt:
        DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
  );
}

class WorkloadItem {
  final String name;
  final int openTasks;
  WorkloadItem(this.name, this.openTasks);
}
