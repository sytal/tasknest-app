class TaskAssignee {
  final int id;
  final String name;
  final String? avatarUrl;

  TaskAssignee({required this.id, required this.name, this.avatarUrl});

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}
