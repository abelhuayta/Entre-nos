import 'user_profile.dart';

class ChatConversation {
  final String id;
  final String circleId;
  final bool isGroup;
  final String? title;
  final String? lastMessageText;
  final DateTime lastMessageAt;
  final int unreadCount;
  final List<UserProfile> participants;

  const ChatConversation({
    required this.id,
    required this.circleId,
    required this.isGroup,
    this.title,
    this.lastMessageText,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.participants = const [],
  });

  UserProfile? otherParticipant(String? myUid) {
    if (isGroup || myUid == null) return null;
    for (final p in participants) {
      if (p.id != myUid) return p;
    }
    return participants.isNotEmpty ? participants.first : null;
  }

  String displayName(String? myUid) {
    if (isGroup) {
      return (title != null && title!.trim().isNotEmpty)
          ? title!
          : 'ENTRE NOS · Grupo';
    }
    final other = otherParticipant(myUid);
    return other?.fullName ?? 'Mensaje directo';
  }

  String? displayAvatarPath(String? myUid) {
    if (isGroup) return null;
    return otherParticipant(myUid)?.avatarPath;
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String? mediaPath;
  final String? messageType;
  final DateTime createdAt;
  final UserProfile? sender;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.mediaPath,
    this.messageType,
    required this.createdAt,
    this.sender,
  });

  bool get hasImage => mediaPath != null && mediaPath!.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    UserProfile? parsedSender;
    final rawSender = json['sender'];
    if (rawSender is Map<String, dynamic>) {
      parsedSender = UserProfile.fromJson(rawSender);
    }

    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: (json['content'] as String?) ?? '',
      mediaPath: json['media_path'] as String?,
      messageType: json['message_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      sender: parsedSender,
    );
  }
}