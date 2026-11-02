class TaskAssignee {
  final int id;
  final String name;

  TaskAssignee({required this.id, required this.name});

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
    );
  }
}
