import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../routing/route_names.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_scaffold.dart';

/// Pantalla informativa que se muestra únicamente cuando aún no se han
/// inyectado SUPABASE_URL y SUPABASE_ANON_KEY mediante `--dart-define`.
class EnvSetupBannerScreen extends StatelessWidget {
  const EnvSetupBannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.blackSecondary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              'ARQUITECTURA CONECTADA · FASE 3',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppConstants.appName,
            style: AppTypography.displayLarge.copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Riverpod, GoRouter y el cliente Supabase están listos. Para conectar tu backend real, ejecuta la app pasando tus credenciales con --dart-define.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.gray),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.blackSecondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.divider),
            ),
            child: SelectableText(
              'flutter run \\\n'
              '  --dart-define=SUPABASE_URL=TU_URL \\\n'
              '  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.white,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const Spacer(),
          AppButton(
            label: 'Ver vista previa del Sistema Visual',
            variant: AppButtonVariant.secondary,
            icon: Icons.palette_outlined,
            onPressed: () => context.push(RouteNames.preview),
          ),
        ],
      ),
    );
  }
}