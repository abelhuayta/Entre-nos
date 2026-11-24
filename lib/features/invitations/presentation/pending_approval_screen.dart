import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/providers/session_gate_provider.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AppScaffold(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.blackSecondary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Solicitud enviada',
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tu código fue validado. El administrador del círculo debe aprobar tu ingreso antes de que puedas ver el contenido privado.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.gray),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.blackSecondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Escuchando en tiempo real · Entrarás automáticamente al ser aprobado.',
                    style: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          AppButton(
            label: 'Comprobar estado ahora',
            variant: AppButtonVariant.secondary,
            icon: Icons.refresh_rounded,
            onPressed: () => ref
                .read(sessionGateProvider.notifier)
                .refreshMembershipStatus(),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Cerrar sesión',
            variant: AppButtonVariant.ghost,
            isLoading: isLoading,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}