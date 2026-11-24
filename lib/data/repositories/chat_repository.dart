import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../models/chat_models.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class ChatRepository {
  static const String _defaultCircleId =
      '00000000-0000-0000-0000-000000000001';

  final SupabaseClient? _client;
  final StorageService _storageService;

  const ChatRepository(this._client, this._storageService);

  SupabaseClient get _requireClient {
    final c = _client;
    if (c == null) {
      throw const AuthAppException('Supabase no está configurado.');
    }
    return c;
  }

  Future<List<ChatConversation>> fetchConversations() async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      await client.rpc(
        'ensure_circle_group_chat',
        params: {'p_circle_id': _defaultCircleId},
      );

      final myMemberships = await client
          .from('conversation_members')
          .select('conversation_id, last_read_at')
          .eq('user_id', uid);

      final memberRows = myMemberships as List<dynamic>;
      if (memberRows.isEmpty) return const [];

      final lastReadByConv = <String, DateTime>{};
      for (final raw in memberRows) {
        final row = raw as Map<String, dynamic>;
        final convId = row['conversation_id'] as String;
        lastReadByConv[convId] = DateTime.parse(row['last_read_at'] as String);
      }

      final convIds = lastReadByConv.keys.toList();

      final convRows = await client
          .from('conversations')
          .select(
            'id, circle_id, type, title, last_message_text, last_message_at',
          )
          .inFilter('id', convIds)
          .order('last_message_at', ascending: false);

      final allParticipantRows = await client
          .from('conversation_members')
          .select(
            'conversation_id, profile:profiles!user_id(id, email, full_name, nickname, bio, avatar_path, avatar_config, created_at)',
          )
          .inFilter('conversation_id', convIds);

      final participantsByConv = <String, List<UserProfile>>{};
      for (final raw in (allParticipantRows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final convId = row['conversation_id'] as String;
        final profileRaw = row['profile'];
        if (profileRaw is Map<String, dynamic>) {
          participantsByConv
              .putIfAbsent(convId, () => [])
              .add(UserProfile.fromJson(profileRaw));
        }
      }

      final result = <ChatConversation>[];
      for (final raw in (convRows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final convId = row['id'] as String;
        final lastRead = lastReadByConv[convId] ?? DateTime.now();

        final unreadRows = await client
            .from('messages')
            .select('id')
            .eq('conversation_id', convId)
            .neq('sender_id', uid)
            .gt('created_at', lastRead.toUtc().toIso8601String());

        result.add(
          ChatConversation(
            id: convId,
            circleId: row['circle_id'] as String,
            isGroup: (row['type'] as String?) == 'group',
            title: row['title'] as String?,
            lastMessageText: row['last_message_text'] as String?,
            lastMessageAt: DateTime.parse(row['last_message_at'] as String),
            unreadCount: (unreadRows as List<dynamic>).length,
            participants: participantsByConv[convId] ?? const [],
          ),
        );
      }

      result.sort((a, b) {
        if (a.isGroup != b.isGroup) return a.isGroup ? -1 : 1;
        return b.lastMessageAt.compareTo(a.lastMessageAt);
      });

      return result;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<ChatConversation> fetchConversationById(String conversationId) async {
    try {
      final client = _requireClient;

      final row = await client
          .from('conversations')
          .select(
            'id, circle_id, type, title, last_message_text, last_message_at',
          )
          .eq('id', conversationId)
          .single();

      final participantRows = await client
          .from('conversation_members')
          .select(
            'profile:profiles!user_id(id, email, full_name, nickname, bio, avatar_path, avatar_config, created_at)',
          )
          .eq('conversation_id', conversationId);

      final participants = <UserProfile>[];
      for (final raw in (participantRows as List<dynamic>)) {
        final map = raw as Map<String, dynamic>;
        final profileRaw = map['profile'];
        if (profileRaw is Map<String, dynamic>) {
          participants.add(UserProfile.fromJson(profileRaw));
        }
      }

      return ChatConversation(
        id: row['id'] as String,
        circleId: row['circle_id'] as String,
        isGroup: (row['type'] as String?) == 'group',
        title: row['title'] as String?,
        lastMessageText: row['last_message_text'] as String?,
        lastMessageAt: DateTime.parse(row['last_message_at'] as String),
        participants: participants,
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<UserProfile>> fetchApprovedCircleFriends() async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final rows = await client
          .from('memberships')
          .select(
            'profile:profiles!user_id(id, email, full_name, nickname, bio, avatar_path, avatar_config, created_at)',
          )
          .eq('circle_id', _defaultCircleId)
          .eq('status', 'approved')
          .neq('user_id', uid);

      final friends = <UserProfile>[];
      for (final raw in (rows as List<dynamic>)) {
        final map = raw as Map<String, dynamic>;
        final profileRaw = map['profile'];
        if (profileRaw is Map<String, dynamic>) {
          friends.add(UserProfile.fromJson(profileRaw));
        }
      }

      friends.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
      return friends;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<String> startOrGetDirectChat(String otherUserId) async {
    try {
      final result = await _requireClient.rpc(
        'get_or_create_dm',
        params: {
          'p_circle_id': _defaultCircleId,
          'p_other_user_id': otherUserId,
        },
      );
      return result as String;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    int limit = 80,
  }) async {
    try {
      final rows = await _requireClient
          .from('messages')
          .select('''
            id,
            conversation_id,
            sender_id,
            message_type,
            content,
            media_path,
            created_at,
            sender:profiles!sender_id(id, email, full_name, nickname, bio, avatar_path, avatar_config, created_at)
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);

      final parsed = (rows as List<dynamic>)
          .map((row) => ChatMessage.fromJson(row as Map<String, dynamic>))
          .toList();

      return parsed.reversed.toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    String content = '',
    File? imageFile,
  }) async {
    String? uploadedPath;
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final trimmed = content.trim();
      if (trimmed.isEmpty && imageFile == null) {
        throw const ValidationAppException(
          'Escribe un mensaje o selecciona una imagen.',
        );
      }

      if (imageFile != null) {
        uploadedPath = await _storageService.uploadChatImage(
          conversationId: conversationId,
          imageFile: imageFile,
        );
      }

      await client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': uid,
        'message_type': uploadedPath != null ? 'image' : 'text',
        'content': trimmed,
        'media_path': uploadedPath,
      });
    } catch (e) {
      if (uploadedPath != null) {
        await _storageService.removePostFiles([uploadedPath]);
      }
      throw ErrorMapper.map(e);
    }
  }

  Future<void> deleteMessage(ChatMessage message) async {
    try {
      await _requireClient.from('messages').delete().eq('id', message.id);
      if (message.mediaPath != null && message.mediaPath!.isNotEmpty) {
        await _storageService.removePostFiles([message.mediaPath!]);
      }
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> markConversationRead(String conversationId) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      await client
          .from('conversation_members')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', uid);
    } catch (_) {}
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storageServiceProvider),
  );
});