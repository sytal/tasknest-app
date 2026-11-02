import 'project_member.dart';

class Project {
  final int id;
  final String name;
  final String? description;
  final List<ProjectMember> members;

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.members,
  });

  List<ProjectMember> get leads => members.where((m) => m.isLead).toList();

  factory Project.fromJson(Map<String, dynamic> json) {
    final membersJson = (json['members'] as List<dynamic>?) ?? [];
    return Project(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      members: membersJson
          .map((m) => ProjectMember.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
