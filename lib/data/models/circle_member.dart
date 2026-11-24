import 'user_profile.dart';

enum MemberRole {
  admin,
  member;

  static MemberRole fromString(String? value) {
    return value == 'admin' ? MemberRole.admin : MemberRole.member;
  }
}

enum MemberStatus {
  pending,
  approved,
  rejected,
  blocked,
  removed;

  static MemberStatus fromString(String? value) {
    return switch (value) {
      'approved' => MemberStatus.approved,
      'rejected' => MemberStatus.rejected,
      'blocked' => MemberStatus.blocked,
      'removed' => MemberStatus.removed,
      _ => MemberStatus.pending,
    };
  }
}

class CircleMember {
  final String id;
  final String circleId;
  final String userId;
  final MemberRole role;
  final MemberStatus status;
  final String? invitedBy;
  final DateTime? joinedAt;
  final DateTime createdAt;
  final UserProfile? profile;

  const CircleMember({
    required this.id,
    required this.circleId,
    required this.userId,
    required this.role,
    required this.status,
    this.invitedBy,
    this.joinedAt,
    required this.createdAt,
    this.profile,
  });

  bool get isAdmin => role == MemberRole.admin;

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    final profileData = json['profiles'];
    UserProfile? parsedProfile;
    if (profileData is Map<String, dynamic>) {
      parsedProfile = UserProfile.fromJson(profileData);
    }

    return CircleMember(
      id: json['id'] as String,
      circleId: json['circle_id'] as String,
      userId: json['user_id'] as String,
      role: MemberRole.fromString(json['role'] as String?),
      status: MemberStatus.fromString(json['status'] as String?),
      invitedBy: json['invited_by'] as String?,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      profile: parsedProfile,
    );
  }
}