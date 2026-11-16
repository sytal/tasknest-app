import 'project_member.dart';

class Project {
  final int id;
  final String name;
  final String? description;
  final List<ProjectMember> members;
  final int tasksCount;
  final int tasksDoneCount;
  final int overdueCount;
  final String status; // active | archived
  final String? dueDate;

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.members,
    this.tasksCount = 0,
    this.tasksDoneCount = 0,
    this.overdueCount = 0,
    this.status = 'active',
    this.dueDate,
  });

  bool get isArchived => status == 'archived';

  List<ProjectMember> get leads => members.where((m) => m.isLead).toList();

  double get progress => tasksCount == 0 ? 0 : tasksDoneCount / tasksCount;

  factory Project.fromJson(Map<String, dynamic> json) {
    final membersJson = (json['members'] as List<dynamic>?) ?? [];
    return Project(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      members: membersJson
          .map((m) => ProjectMember.fromJson(m as Map<String, dynamic>))
          .toList(),
      tasksCount: json['tasks_count'] is int
          ? json['tasks_count'] as int
          : int.tryParse('${json['tasks_count']}') ?? 0,
      tasksDoneCount: json['tasks_done_count'] is int
          ? json['tasks_done_count'] as int
          : int.tryParse('${json['tasks_done_count']}') ?? 0,
      overdueCount: int.tryParse('${json['overdue_count']}') ?? 0,
      status: json['status']?.toString() ?? 'active',
      dueDate: json['due_date']?.toString(),
    );
  }
}
