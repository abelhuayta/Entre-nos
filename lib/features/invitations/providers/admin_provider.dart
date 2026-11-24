import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/circle_member.dart';
import '../../../data/models/invitation_model.dart';
import '../../../data/repositories/admin_repository.dart';

class AdminDashboardState {
  final List<CircleMember> members;
  final List<InvitationModel> invitations;

  const AdminDashboardState({
    required this.members,
    required this.invitations,
  });

  List<CircleMember> get pendingMembers =>
      members.where((m) => m.status == MemberStatus.pending).toList();

  List<CircleMember> get approvedMembers =>
      members.where((m) => m.status == MemberStatus.approved).toList();

  List<CircleMember> get restrictedMembers => members
      .where((m) =>
          m.status == MemberStatus.blocked ||
          m.status == MemberStatus.removed ||
          m.status == MemberStatus.rejected)
      .toList();
}

class AdminController extends AutoDisposeAsyncNotifier<AdminDashboardState> {
  @override
  Future<AdminDashboardState> build() async {
    return _loadDashboard();
  }

  Future<AdminDashboardState> _loadDashboard() async {
    final repo = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      repo.fetchCircleMembers(),
      repo.fetchInvitations(),
    ]);

    return AdminDashboardState(
      members: results[0] as List<CircleMember>,
      invitations: results[1] as List<InvitationModel>,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadDashboard);
  }

  Future<String?> createInvitation({
    required int maxUses,
    required bool autoApprove,
    int? expiresInHours,
  }) async {
    try {
      await ref.read(adminRepositoryProvider).createInvitation(
            maxUses: maxUses,
            autoApprove: autoApprove,
            expiresInHours: expiresInHours,
          );
      state = await AsyncValue.guard(_loadDashboard);
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<String?> toggleInvitation(String id, bool isActive) async {
    try {
      await ref.read(adminRepositoryProvider).setInvitationActive(
            invitationId: id,
            isActive: isActive,
          );
      state = await AsyncValue.guard(_loadDashboard);
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<String?> manageMember({
    required String targetUserId,
    required String action,
  }) async {
    try {
      await ref.read(adminRepositoryProvider).manageMember(
            targetUserId: targetUserId,
            action: action,
          );
      state = await AsyncValue.guard(_loadDashboard);
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }
}

final adminControllerProvider =
    AutoDisposeAsyncNotifierProvider<AdminController, AdminDashboardState>(
  AdminController.new,
);