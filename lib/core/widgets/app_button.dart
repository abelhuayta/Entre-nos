import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant {
  primary,
  secondary,
  ghost,
  destructive,
}

/// Botón reutilizable con estética minimalista, feedback háptico y estado de carga.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isFullWidth;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isFullWidth = true,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    final (bgColor, fgColor, borderSide) = switch (variant) {
      AppButtonVariant.primary => (
          isDisabled ? AppColors.blackElevated : AppColors.white,
          isDisabled ? AppColors.grayMuted : AppColors.blackPrimary,
          BorderSide.none,
        ),
      AppButtonVariant.secondary => (
          AppColors.blackSecondary,
          isDisabled ? AppColors.grayMuted : AppColors.white,
          const BorderSide(color: AppColors.divider, width: 1),
        ),
      AppButtonVariant.ghost => (
          Colors.transparent,
          isDisabled ? AppColors.grayMuted : AppColors.white,
          BorderSide.none,
        ),
      AppButtonVariant.destructive => (
          AppColors.error.withValues(alpha: 0.14),
          AppColors.error,
          BorderSide(color: AppColors.error.withValues(alpha: 0.4), width: 1),
        ),
    };

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: borderSide,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: isDisabled
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed?.call();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: fgColor),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Text(
                          label,
                          style: AppTypography.labelLarge.copyWith(
                            color: fgColor,
                            fontWeight: variant == AppButtonVariant.primary
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}