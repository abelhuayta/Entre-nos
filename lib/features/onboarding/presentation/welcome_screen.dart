import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.xxl,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.blackSecondary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              'CÍRCULO PRIVADO · MÁX. 30 INTEGRANTES',
              style: AppTypography.labelSmall.copyWith(letterSpacing: 0.9),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            AppConstants.appName,
            style: AppTypography.displayLarge.copyWith(
              fontSize: 38,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppConstants.appSlogan,
            style: AppTypography.titleLarge.copyWith(color: AppColors.gray),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Sin seguidores públicos, sin desconocidos y sin algoritmos. Un espacio íntimo reservado exclusivamente para quienes forman parte del grupo.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.gray),
          ),
          const Spacer(flex: 3),
          AppButton(
            label: 'Tengo un código de invitación',
            icon: Icons.vpn_key_outlined,
            onPressed: () => context.push(RouteNames.register),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Ya tengo cuenta · Iniciar sesión',
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(RouteNames.login),
          ),
        ],
      ),
    );
  }
}