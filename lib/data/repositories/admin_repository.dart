import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../models/circle_member.dart';
import '../models/invitation_model.dart';
import '../services/supabase_service.dart';

class AdminRepository {
  static const String _defaultCircleId =
      '00000000-0000-0000-0000-000000000001';

  final SupabaseClient? _client;

  const AdminRepository(this._client);

  SupabaseClient get _requireClient {
    final c = _client;
    if (c == null) {
      throw const AuthAppException('Supabase no está configurado.');
    }
    return c;
  }

  Future<List<CircleMember>> fetchCircleMembers() async {
    try {
      final data = await _requireClient
          .from('memberships')
          .select(
            '*, profiles!memberships_user_id_fkey(id, email, full_name, nickname, bio, avatar_path, avatar_config, created_at)',
          )
          .eq('circle_id', _defaultCircleId)
          .order('created_at', ascending: true);

      return (data as List<dynamic>)
          .map((row) => CircleMember.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<InvitationModel>> fetchInvitations() async {
    try {
      final data = await _requireClient
          .from('invitations')
          .select()
          .eq('circle_id', _defaultCircleId)
          .order('created_at', ascending: false);

      return (data as List<dynamic>)
          .map((row) => InvitationModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<InvitationModel> createInvitation({
    int maxUses = 1,
    bool autoApprove = false,
    int? expiresInHours,
  }) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no válida.');
      }

      final code = _generateCode();
      final expiresAt = expiresInHours != null
          ? DateTime.now()
              .toUtc()
              .add(Duration(hours: expiresInHours))
              .toIso8601String()
          : null;

      final inserted = await client
          .from('invitations')
          .insert({
            'circle_id': _defaultCircleId,
            'code': code,
            'created_by': uid,
            'max_uses': maxUses,
            'auto_approve': autoApprove,
            'expires_at': expiresAt,
            'is_active': true,
          })
          .select()
          .single();

      return InvitationModel.fromJson(inserted);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> setInvitationActive({
    required String invitationId,
    required bool isActive,
  }) async {
    try {
      await _requireClient
          .from('invitations')
          .update({'is_active': isActive})
          .eq('id', invitationId);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> manageMember({
    required String targetUserId,
    required String action,
  }) async {
    try {
      await _requireClient.rpc(
        'admin_manage_member',
        params: {
          'p_target_user': targetUserId,
          'p_action': action,
        },
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    String chunk(int len) =>
        List.generate(len, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'EN-${chunk(4)}-${chunk(2)}';
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
});