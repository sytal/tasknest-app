class ProjectMember {
  final int id;
  final String name;
  final String? designation;
  final String projectRole; // lead | member

  ProjectMember({
    required this.id,
    required this.name,
    this.designation,
    required this.projectRole,
  });

  bool get isLead => projectRole == 'lead';

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      designation: json['designation']?.toString(),
      projectRole: json['project_role']?.toString() ?? 'member',
    );
  }
}
