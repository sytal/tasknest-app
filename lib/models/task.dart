import 'task_assignee.dart';

class Label {
  final int id;
  final String name;
  final String color;
  Label({required this.id, required this.name, required this.color});
  factory Label.fromJson(Map<String, dynamic> j) => Label(
    id: j['id'] as int,
    name: j['name']?.toString() ?? '',
    color: j['color']?.toString() ?? 'gray',
  );
}

class Subtask {
  final int id;
  final String title;
  final bool isDone;
  Subtask({required this.id, required this.title, required this.isDone});
  factory Subtask.fromJson(Map<String, dynamic> j) => Subtask(
    id: j['id'] as int,
    title: j['title']?.toString() ?? '',
    isDone: j['is_done'] == true,
  );
}

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
  final String? creatorName;
  final String? createdAt;
  final String? startDate;
  final double? estimateHours;
  final List<Label> labels;
  final List<Subtask> subtasks;
  final int subtasksCount;
  final int subtasksDoneCount;

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
    this.creatorName,
    this.createdAt,
    this.startDate,
    this.estimateHours,
    this.labels = const [],
    this.subtasks = const [],
    this.subtasksCount = 0,
    this.subtasksDoneCount = 0,
  });

  TaskItem copyWithStatus(String newStatus) => TaskItem(
    id: id,
    title: title,
    description: description,
    status: newStatus,
    priority: priority,
    dueDate: dueDate,
    projectId: projectId,
    projectName: projectName,
    assignee: assignee,
    createdBy: createdBy,
    creatorName: creatorName,
    createdAt: createdAt,
    startDate: startDate,
    estimateHours: estimateHours,
    labels: labels,
    subtasks: subtasks,
    subtasksCount: subtasksCount,
    subtasksDoneCount: subtasksDoneCount,
  );

  DateTime? get due => dueDate == null ? null : DateTime.tryParse(dueDate!);

  /// True when the task has a due date before today and is not done.
  bool get isOverdue {
    final d = due;
    if (d == null || status == StatusOptions.done) return false;
    final now = DateTime.now();
    return d.isBefore(DateTime(now.year, now.month, now.day));
  }

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
      projectName:
          json['project_name']?.toString() ??
          (json['project'] is Map ? json['project']['name']?.toString() : null),
      creatorName: json['creator'] is Map
          ? json['creator']['name']?.toString()
          : null,
      createdAt: json['created_at']?.toString(),
      startDate: json['start_date']?.toString(),
      estimateHours: double.tryParse('${json['estimate_hours']}'),
      labels: ((json['labels'] as List?) ?? [])
          .map((e) => Label.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtasks: ((json['subtasks'] as List?) ?? [])
          .map((e) => Subtask.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtasksCount: int.tryParse('${json['subtasks_count']}') ?? 0,
      subtasksDoneCount: int.tryParse('${json['subtasks_done_count']}') ?? 0,
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
