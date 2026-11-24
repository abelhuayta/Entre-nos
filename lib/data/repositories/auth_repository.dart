import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';

class AuthRepository {
  final SupabaseClient? _client;

  const AuthRepository(this._client);

  SupabaseClient get _requireClient {
    final c = _client;
    if (c == null) {
      throw const AuthAppException('Supabase no está configurado.');
    }
    return c;
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _requireClient.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String nickname,
    String? invitationCode,
  }) async {
    try {
      final client = _requireClient;
      final cleanNick = nickname.trim().toLowerCase();

      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'nickname': cleanNick,
        },
      );

      final hasSession = response.session != null;
      if (hasSession &&
          invitationCode != null &&
          invitationCode.trim().isNotEmpty) {
        await redeemInvitation(invitationCode.trim());
      }

      return hasSession;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _requireClient.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'io.supabase.entrenos://login-callback/',
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> redeemInvitation(String code) async {
    try {
      await _requireClient.rpc(
        'redeem_invitation_code',
        params: {'p_code': code.trim().toUpperCase()},
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> claimInitialAdmin() async {
    try {
      await _requireClient.rpc('claim_initial_admin');
    } on PostgrestException catch (e) {
      if (e.message.contains('admin_already_exists')) {
        throw const ValidationAppException(
          'Este círculo ya tiene un administrador activo. Solicita un código de invitación.',
        );
      }
      throw ErrorMapper.map(e);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<UserProfile?> fetchCurrentProfile() async {
    try {
      final client = _requireClient;
      final user = client.auth.currentUser;
      if (user == null) return null;

      final data = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return null;
      return UserProfile.fromJson(data);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _requireClient.auth.signOut();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});