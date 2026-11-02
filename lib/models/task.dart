import 'task_assignee.dart';

class TaskItem {
  final int id;
  final String title;
  final String? description;
  final String status; // todo | in_progress | done
  final String priority; // low | medium | high
  final String? dueDate;
  final int projectId;
  final String? projectName;
  final TaskAssignee? assignee;
  final int? createdBy;

  TaskItem({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    required this.projectId,
    this.projectName,
    this.assignee,
    this.createdBy,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as int,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'todo',
      priority: json['priority']?.toString() ?? 'medium',
      dueDate: json['due_date']?.toString(),
      projectId: json['project_id'] is int
          ? json['project_id'] as int
          : int.tryParse('${json['project_id']}') ?? 0,
      projectName: json['project_name']?.toString(),
      assignee: json['assignee'] != null
          ? TaskAssignee.fromJson(json['assignee'] as Map<String, dynamic>)
          : null,
      createdBy: json['created_by'] is int
          ? json['created_by'] as int
          : int.tryParse('${json['created_by']}'),
    );
  }
}

class StatusOptions {
  static const todo = 'todo';
  static const inProgress = 'in_progress';
  static const done = 'done';
  static const all = [todo, inProgress, done];

  static String label(String status) {
    switch (status) {
      case todo:
        return 'To Do';
      case inProgress:
        return 'In Progress';
      case done:
        return 'Done';
      default:
        return status;
    }
  }
}

class PriorityOptions {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';
  static const all = [low, medium, high];

  static String label(String priority) =>
      priority[0].toUpperCase() + priority.substring(1);
}
