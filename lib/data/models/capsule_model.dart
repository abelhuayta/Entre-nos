class TimeCapsuleItem {
  final String id;
  final String circleId;
  final String creatorId;
  final String title;
  final String? message;
  final String? mediaPath;
  final String? mediaType;
  final DateTime unlockAt;
  final DateTime createdAt;
  final bool isUnlocked;
  final String creatorName;
  final String creatorNickname;
  final String? creatorAvatarPath;

  const TimeCapsuleItem({
    required this.id,
    required this.circleId,
    required this.creatorId,
    required this.title,
    this.message,
    this.mediaPath,
    this.mediaType,
    required this.unlockAt,
    required this.createdAt,
    required this.isUnlocked,
    required this.creatorName,
    required this.creatorNickname,
    this.creatorAvatarPath,
  });

  factory TimeCapsuleItem.fromJson(Map<String, dynamic> json) {
    final unlockAt = DateTime.parse(json['unlock_at'] as String);
    final unlockedFlag =
        (json['is_unlocked'] as bool?) ?? DateTime.now().isAfter(unlockAt);

    return TimeCapsuleItem(
      id: json['id'] as String,
      circleId: json['circle_id'] as String,
      creatorId: json['creator_id'] as String,
      title: (json['title'] as String?) ?? 'Cápsula del tiempo',
      message: json['message'] as String?,
      mediaPath: json['media_path'] as String?,
      mediaType: json['media_type'] as String?,
      unlockAt: unlockAt,
      createdAt: DateTime.parse(json['created_at'] as String),
      isUnlocked: unlockedFlag,
      creatorName: (json['creator_name'] as String?) ?? 'Integrante',
      creatorNickname: (json['creator_nickname'] as String?) ?? 'amigo',
      creatorAvatarPath: json['creator_avatar_path'] as String?,
    );
  }
}