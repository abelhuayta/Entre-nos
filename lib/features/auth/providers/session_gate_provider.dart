import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/env_config.dart';
import '../../../data/services/supabase_service.dart';

/// Estados posibles del control de acceso ("Gatekeeper") de ENTRE NOS.
enum GateStatus {
  unconfigured,
  loading,
  unauthenticated,
  needsInvitation,
  pendingApproval,
  blockedOrRemoved,
  approved,
}

class SessionGateState {
  final GateStatus status;
  final User? user;
  final bool isAdmin;

  const SessionGateState({
    required this.status,
    this.user,
    this.isAdmin = false,
  });

  const SessionGateState.initial()
      : status = GateStatus.loading,
        user = null,
        isAdmin = false;
}

class SessionGateNotifier extends Notifier<SessionGateState>
    implements Listenable {
  final List<VoidCallback> _listeners = [];
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _membershipChannel;
  String? _subscribedUserId;

  @override
  SessionGateState build() {
    ref.onDispose(() {
      _authSub?.cancel();
      _unsubscribeRealtime();
      _listeners.clear();
    });

    if (!EnvConfig.isConfigured) {
      return const SessionGateState(status: GateStatus.unconfigured);
    }

    final client = ref.watch(supabaseClientProvider);
    if (client == null) {
      return const SessionGateState(status: GateStatus.unconfigured);
    }

    _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen((_) {
      refreshMembershipStatus();
    });

    Future.microtask(refreshMembershipStatus);
    return const SessionGateState.initial();
  }

  void _ensureRealtimeSubscription(SupabaseClient client, String userId) {
    if (_subscribedUserId == userId && _membershipChannel != null) return;

    _unsubscribeRealtime();
    _subscribedUserId = userId;

    _membershipChannel = client
        .channel('gate_membership_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'memberships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {
            refreshMembershipStatus();
          },
        )
        .subscribe();
  }

  void _unsubscribeRealtime() {
    if (_membershipChannel != null) {
      ref.read(supabaseClientProvider)?.removeChannel(_membershipChannel!);
      _membershipChannel = null;
      _subscribedUserId = null;
    }
  }

  Future<void> refreshMembershipStatus() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      _updateState(const SessionGateState(status: GateStatus.unconfigured));
      return;
    }

    final currentUser = client.auth.currentUser;
    if (currentUser == null) {
      _unsubscribeRealtime();
      _updateState(const SessionGateState(status: GateStatus.unauthenticated));
      return;
    }

    _ensureRealtimeSubscription(client, currentUser.id);

    try {
      final response = await client
          .from('memberships')
          .select('role, status')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (response == null) {
        _updateState(
          SessionGateState(
            status: GateStatus.needsInvitation,
            user: currentUser,
          ),
        );
        return;
      }

      final statusStr = response['status'] as String? ?? 'pending';
      final roleStr = response['role'] as String? ?? 'member';

      final gateStatus = switch (statusStr) {
        'approved' => GateStatus.approved,
        'pending' => GateStatus.pendingApproval,
        'blocked' || 'removed' || 'rejected' => GateStatus.blockedOrRemoved,
        _ => GateStatus.pendingApproval,
      };

      _updateState(
        SessionGateState(
          status: gateStatus,
          user: currentUser,
          isAdmin: roleStr == 'admin',
        ),
      );
    } on PostgrestException catch (e) {
      if (e.code == '42P01') {
        _updateState(
          SessionGateState(
            status: GateStatus.needsInvitation,
            user: currentUser,
          ),
        );
        return;
      }
      _updateState(
        SessionGateState(
          status: GateStatus.pendingApproval,
          user: currentUser,
        ),
      );
    } catch (_) {
      _updateState(
        SessionGateState(
          status: GateStatus.pendingApproval,
          user: currentUser,
        ),
      );
    }
  }

  void _updateState(SessionGateState next) {
    state = next;
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}

final sessionGateProvider =
    NotifierProvider<SessionGateNotifier, SessionGateState>(
  SessionGateNotifier.new,
);