import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/storage_service.dart';
import '../../features/media/providers/media_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppAvatar extends ConsumerWidget {
  final String name;
  final String? avatarPath;
  final double size;
  final Color? backgroundColor;
  final bool hasStoryRing;
  final bool storySeen;
  final bool isOnline;
  final bool showOnlineDot;

  const AppAvatar({
    super.key,
    required this.name,
    this.avatarPath,
    this.size = 44,
    this.backgroundColor,
    this.hasStoryRing = false,
    this.storySeen = false,
    this.isOnline = false,
    this.showOnlineDot = false,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'EN';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = backgroundColor ?? AppColors.blackElevated;
    final path = avatarPath?.trim() ?? '';
    final innerSize = hasStoryRing ? size - 7 : size;

    Widget innerAvatar = _buildInitials(innerSize);

    if (path.isNotEmpty) {
      final urlAsync = ref.watch(
        signedMediaUrlProvider(
          (bucket: StorageService.avatarsBucket, path: path),
        ),
      );
      innerAvatar = urlAsync.when(
        loading: () => _buildInitials(innerSize),
        error: (error, stackTrace) => _buildInitials(innerSize),
        data: (signedUrl) => ClipOval(
          child: Image.network(
            signedUrl,
            width: innerSize,
            height: innerSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildInitials(innerSize),
          ),
        ),
      );
    }

    final avatarCircle = Container(
      width: innerSize,
      height: innerSize,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.divider, width: 1.2),
      ),
      alignment: Alignment.center,
      child: innerAvatar,
    );

    final showDot = isOnline || showOnlineDot;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasStoryRing)
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: storySeen ? AppColors.grayMuted : AppColors.white,
                  width: 2,
                ),
              ),
              child: avatarCircle,
            )
          else
            avatarCircle,
          if (showDot)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.blackPrimary, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInitials(double targetSize) {
    return Text(
      _initials,
      style: AppTypography.labelLarge.copyWith(
        fontSize: targetSize * 0.36,
        color: AppColors.white,
        letterSpacing: 0.5,
      ),
    );
  }
}