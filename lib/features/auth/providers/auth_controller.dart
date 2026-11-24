import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/auth_repository.dart';
import 'session_gate_provider.dart';

class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
          );
      await ref.read(sessionGateProvider.notifier).refreshMembershipStatus();
      state = const AsyncData(null);
      return null;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return e.message;
    }
  }

  Future<({String? error, bool needsEmailConfirmation})> signUp({
    required String email,
    required String password,
    required String fullName,
    required String nickname,
    String? invitationCode,
  }) async {
    state = const AsyncLoading();
    try {
      final hasSession = await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            fullName: fullName,
            nickname: nickname,
            invitationCode: invitationCode,
          );
      if (hasSession) {
        await ref.read(sessionGateProvider.notifier).refreshMembershipStatus();
      }
      state = const AsyncData(null);
      return (error: null, needsEmailConfirmation: !hasSession);
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return (error: e.message, needsEmailConfirmation: false);
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      state = const AsyncData(null);
      return null;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return e.message;
    }
  }

  Future<String?> redeemInvitation(String code) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).redeemInvitation(code);
      await ref.read(sessionGateProvider.notifier).refreshMembershipStatus();
      state = const AsyncData(null);
      return null;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return e.message;
    }
  }

  Future<String?> claimInitialAdmin() async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).claimInitialAdmin();
      await ref.read(sessionGateProvider.notifier).refreshMembershipStatus();
      state = const AsyncData(null);
      return null;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return e.message;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).signOut();
      state = const AsyncData(null);
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final gate = ref.watch(sessionGateProvider);
  if (gate.user == null) return null;
  return ref.read(authRepositoryProvider).fetchCurrentProfile();
});