class AppNotificationItem {
  final String id;
  final String recipientId;
  final String? actorId;
  final String type;
  final String? referenceId;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const AppNotificationItem({
    required this.id,
    required this.recipientId,
    this.actorId,
    required this.type,
    this.referenceId,
    required this.title,
    this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      actorId: json['actor_id'] as String?,
      type: (json['type'] as String?) ?? 'activity',
      referenceId: json['reference_id'] as String?,
      title: (json['title'] as String?) ?? 'Nueva actividad',
      body: (json['body'] as String?) ?? '',
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}