class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String nickname;
  final String bio;
  final String? avatarPath;
  final Map<String, dynamic> avatarConfig;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.nickname,
    this.bio = '',
    this.avatarPath,
    this.avatarConfig = const {'bg': '#171717', 'accent': '#F5F5F5'},
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? 'Integrante',
      nickname: (json['nickname'] as String?) ?? 'amigo',
      bio: (json['bio'] as String?) ?? '',
      avatarPath: json['avatar_path'] as String?,
      avatarConfig: (json['avatar_config'] as Map<String, dynamic>?) ??
          const {'bg': '#171717', 'accent': '#F5F5F5'},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}