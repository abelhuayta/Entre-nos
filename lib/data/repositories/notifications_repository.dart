import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../models/notification_model.dart';
import '../services/supabase_service.dart';

class NotificationsRepository {
  final SupabaseClient? _client;

  const NotificationsRepository(this._client);

  SupabaseClient get _requireClient {
    final c = _client;
    if (c == null) {
      throw const AuthAppException('Supabase no está configurado.');
    }
    return c;
  }

  Future<List<AppNotificationItem>> fetchNotifications({int limit = 50}) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final rows = await client
          .from('notifications')
          .select(
            'id, recipient_id, actor_id, type, reference_id, title, body, is_read, created_at',
          )
          .eq('recipient_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List<dynamic>)
          .map((row) => AppNotificationItem.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', uid)
          .eq('is_read', false);
    } catch (_) {}
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(supabaseClientProvider));
});