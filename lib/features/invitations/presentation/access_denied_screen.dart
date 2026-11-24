import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/providers/auth_controller.dart';

class AccessDeniedScreen extends ConsumerWidget {
  const AccessDeniedScreen({super.key});

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
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.block_rounded,
              color: AppColors.error,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Acceso no autorizado',
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tu solicitud no fue aprobada o tu membresía en ENTRE NOS fue revocada por el administrador del grupo.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.gray),
          ),
          const Spacer(),
          AppButton(
            label: 'Cerrar sesión',
            variant: AppButtonVariant.secondary,
            isLoading: isLoading,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}