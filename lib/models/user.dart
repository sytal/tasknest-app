class AppUser {
  final int id;
  final String name;
  final String email;
  final String role; // director | ceo | member
  final String? designation;
  final String? avatarUrl;
  final bool isActive;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.designation,
    this.avatarUrl,
    this.isActive = true,
  });

  bool get isDirectorOrCeo => role == 'director' || role == 'ceo';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      designation: json['designation']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      isActive: json['is_active'] != false,
    );
  }

  AppUser copyWith({String? avatarUrl, bool clearAvatarUrl = false}) {
    return AppUser(
      id: id,
      name: name,
      email: email,
      role: role,
      designation: designation,
      isActive: isActive,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'designation': designation,
    'avatar_url': avatarUrl,
  };
}
