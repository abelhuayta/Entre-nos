import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/services/supabase_service.dart';
import '../../auth/providers/session_gate_provider.dart';

final conversationsListProvider =
    FutureProvider.autoDispose<List<ChatConversation>>((ref) async {
  return await ref.read(chatRepositoryProvider).fetchConversations();
});

final circleMembersForChatProvider =
    FutureProvider.autoDispose<List<UserProfile>>((ref) async {
  return await ref.read(chatRepositoryProvider).fetchApprovedCircleFriends();
});

class ChatRoomState {
  final ChatConversation conversation;
  final List<ChatMessage> messages;

  const ChatRoomState({
    required this.conversation,
    required this.messages,
  });

  ChatRoomState copyWith({
    ChatConversation? conversation,
    List<ChatMessage>? messages,
  }) {
    return ChatRoomState(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
    );
  }
}

class ChatRoomController
    extends AutoDisposeFamilyAsyncNotifier<ChatRoomState, String> {
  RealtimeChannel? _channel;

  @override
  Future<ChatRoomState> build(String conversationId) async {
    ref.onDispose(() {
      if (_channel != null) {
        ref.read(supabaseClientProvider)?.removeChannel(_channel!);
        _channel = null;
      }
    });

    final repo = ref.read(chatRepositoryProvider);
    final conversation = await repo.fetchConversationById(conversationId);
    final messages = await repo.fetchMessages(conversationId);
    await repo.markConversationRead(conversationId);

    _subscribeRealtime(conversationId);

    return ChatRoomState(
      conversation: conversation,
      messages: messages,
    );
  }

  void _subscribeRealtime(String conversationId) {
    final client = ref.read(supabaseClientProvider);
    if (client == null || _channel != null) return;

    _channel = client
        .channel('chat_room_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) async {
            await _syncLatestMessages(conversationId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) async {
            await _syncLatestMessages(conversationId);
          },
        )
        .subscribe();
  }

  Future<void> _syncLatestMessages(String conversationId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    try {
      final repo = ref.read(chatRepositoryProvider);
      final fresh = await repo.fetchMessages(conversationId);
      await repo.markConversationRead(conversationId);
      state = AsyncData(current.copyWith(messages: fresh));
      ref.invalidate(conversationsListProvider);
    } catch (_) {}
  }

  Future<String?> sendMessage({
    String content = '',
    File? imageFile,
  }) async {
    final conversationId = arg;
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            conversationId: conversationId,
            content: content,
            imageFile: imageFile,
          );
      await _syncLatestMessages(conversationId);
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<String?> deleteMessage(ChatMessage message) async {
    final myUid = ref.read(sessionGateProvider).user?.id;
    if (myUid == null || message.senderId != myUid) return null;

    try {
      await ref.read(chatRepositoryProvider).deleteMessage(message);
      await _syncLatestMessages(arg);
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }
}

final chatRoomProvider = AutoDisposeAsyncNotifierProviderFamily<
    ChatRoomController, ChatRoomState, String>(
  ChatRoomController.new,
);