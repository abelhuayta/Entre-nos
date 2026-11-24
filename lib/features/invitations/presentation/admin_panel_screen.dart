import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/circle_member.dart';
import '../../../data/models/invitation_model.dart';
import '../../auth/providers/session_gate_provider.dart';
import '../providers/admin_provider.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(sessionGateProvider);
    if (!gate.isAdmin) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Administración')),
        body: const EmptyStateView(
          icon: Icons.lock_outline_rounded,
          title: 'Acceso exclusivo de administrador',
          subtitle: 'Solo el administrador del círculo puede gestionar miembros e invitaciones.',
        ),
      );
    }

    final dashboardAsync = ref.watch(adminControllerProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Administración del grupo'),
        actions: [
          IconButton(
            onPressed: () => ref.read(adminControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.white),
        ),
        error: (err, _) => EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'No se pudo cargar el panel',
          subtitle: err.toString(),
          actionLabel: 'Reintentar',
          onAction: () => ref.read(adminControllerProvider.notifier).refresh(),
        ),
        data: (data) {
          final approvedCount = data.approvedMembers.length;
          return RefreshIndicator(
            color: AppColors.white,
            backgroundColor: AppColors.blackSecondary,
            onRefresh: () => ref.read(adminControllerProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.lg,
              ),
              children: [
                // Resumen de capacidad del círculo (máx. 30)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.blackSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CAPACIDAD DEL CÍRCULO',
                              style: AppTypography.labelSmall
                                  .copyWith(letterSpacing: 0.9),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$approvedCount / ${AppConstants.maxCircleMembers} integrantes',
                              style: AppTypography.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                      AppButton(
                        label: 'Nuevo código',
                        icon: Icons.add_rounded,
                        isFullWidth: false,
                        height: 44,
                        onPressed: approvedCount >= AppConstants.maxCircleMembers
                            ? null
                            : () => _showCreateInviteSheet(context, ref),
                      ),
                    ],
                  ),
                ),

                // Solicitudes pendientes de aprobación
                if (data.pendingMembers.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Solicitudes pendientes (${data.pendingMembers.length})',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...data.pendingMembers.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _PendingMemberTile(member: member),
                    ),
                  ),
                ],

                // Códigos de invitación
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Invitaciones generadas (${data.invitations.length})',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                if (data.invitations.isEmpty)
                  Text(
                    'Aún no has creado códigos de invitación.',
                    style: AppTypography.bodySmall,
                  )
                else
                  ...data.invitations.map(
                    (inv) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _InvitationTile(invitation: inv),
                    ),
                  ),

                // Integrantes aprobados
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Integrantes activos ($approvedCount)',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                ...data.approvedMembers.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ApprovedMemberTile(
                      member: member,
                      isSelf: member.userId == gate.user?.id,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreateInviteSheet(BuildContext context, WidgetRef ref) {
    int maxUses = 1;
    bool autoApprove = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generar invitación privada',
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Configura cuántos amigos pueden usar este código y si requieren revisión manual.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Usos permitidos', style: AppTypography.bodyMedium),
                      Row(
                        children: [1, 5, 10].map((count) {
                          final selected = maxUses == count;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text('$count'),
                              selected: selected,
                              selectedColor: AppColors.white,
                              backgroundColor: AppColors.blackElevated,
                              labelStyle: AppTypography.labelLarge.copyWith(
                                color: selected
                                    ? AppColors.blackPrimary
                                    : AppColors.white,
                              ),
                              onSelected: (_) =>
                                  setModalState(() => maxUses = count),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: AppColors.white,
                    title: Text(
                      'Aprobación automática',
                      style: AppTypography.bodyMedium,
                    ),
                    subtitle: Text(
                      'Si está desactivado, deberás aprobar manualmente cada solicitud.',
                      style: AppTypography.bodySmall,
                    ),
                    value: autoApprove,
                    onChanged: (val) =>
                        setModalState(() => autoApprove = val),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Crear código',
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final error = await ref
                          .read(adminControllerProvider.notifier)
                          .createInvitation(
                            maxUses: maxUses,
                            autoApprove: autoApprove,
                            expiresInHours: 72,
                          );
                      if (context.mounted && error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PendingMemberTile extends ConsumerWidget {
  final CircleMember member;

  const _PendingMemberTile({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = member.profile?.fullName ?? 'Solicitante';
    final nick = member.profile?.nickname ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.blackSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          AppAvatar(name: name, size: 42),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.titleMedium),
                Text('@$nick · Pendiente', style: AppTypography.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _handle(context, ref, 'reject'),
            icon: const Icon(Icons.close_rounded, color: AppColors.error),
            tooltip: 'Rechazar',
          ),
          IconButton(
            onPressed: () => _handle(context, ref, 'approve'),
            icon: const Icon(Icons.check_rounded, color: AppColors.success),
            tooltip: 'Aprobar',
          ),
        ],
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final error = await ref
        .read(adminControllerProvider.notifier)
        .manageMember(targetUserId: member.userId, action: action);
    if (context.mounted && error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _InvitationTile extends ConsumerWidget {
  final InvitationModel invitation;

  const _InvitationTile({required this.invitation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.blackSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.code,
                  style: AppTypography.titleMedium.copyWith(
                    letterSpacing: 1.2,
                    color: invitation.isAvailable
                        ? AppColors.white
                        : AppColors.grayMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Usos: ${invitation.usesCount}/${invitation.maxUses} · ${invitation.autoApprove ? 'Directo' : 'Con aprobación'}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invitation.code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Código ${invitation.code} copiado')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copiar código',
          ),
          if (invitation.isAvailable)
            IconButton(
              onPressed: () => ref
                  .read(adminControllerProvider.notifier)
                  .toggleInvitation(invitation.id, false),
              icon: const Icon(
                Icons.block_outlined,
                size: 20,
                color: AppColors.error,
              ),
              tooltip: 'Desactivar código',
            ),
        ],
      ),
    );
  }
}

class _ApprovedMemberTile extends ConsumerWidget {
  final CircleMember member;
  final bool isSelf;

  const _ApprovedMemberTile({
    required this.member,
    required this.isSelf,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = member.profile?.fullName ?? 'Integrante';
    final nick = member.profile?.nickname ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.blackSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          AppAvatar(name: name, size: 42),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSelf ? '$name (Tú)' : name,
                  style: AppTypography.titleMedium,
                ),
                Text(
                  '@$nick${member.isAdmin ? ' · Administrador' : ''}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          if (!isSelf)
            PopupMenuButton<String>(
              color: AppColors.blackElevated,
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.gray),
              onSelected: (action) async {
                final error = await ref
                    .read(adminControllerProvider.notifier)
                    .manageMember(targetUserId: member.userId, action: action);
                if (context.mounted && error != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Expulsar del grupo'),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Text(
                    'Bloquear usuario',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}