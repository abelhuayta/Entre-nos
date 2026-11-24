class InvitationModel {
  final String id;
  final String circleId;
  final String code;
  final String createdBy;
  final int maxUses;
  final int usesCount;
  final bool autoApprove;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime createdAt;

  const InvitationModel({
    required this.id,
    required this.circleId,
    required this.code,
    required this.createdBy,
    required this.maxUses,
    required this.usesCount,
    required this.autoApprove,
    this.expiresAt,
    required this.isActive,
    required this.createdAt,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isAvailable => isActive && !isExpired && usesCount < maxUses;

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    return InvitationModel(
      id: json['id'] as String,
      circleId: json['circle_id'] as String,
      code: json['code'] as String,
      createdBy: json['created_by'] as String,
      maxUses: (json['max_uses'] as int?) ?? 1,
      usesCount: (json['uses_count'] as int?) ?? 0,
      autoApprove: (json['auto_approve'] as bool?) ?? false,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}