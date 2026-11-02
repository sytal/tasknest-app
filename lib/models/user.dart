class AppUser {
  final int id;
  final String name;
  final String email;
  final String role; // director | ceo | member
  final String? designation;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.designation,
  });

  bool get isDirectorOrCeo => role == 'director' || role == 'ceo';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      designation: json['designation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'designation': designation,
      };
}
