import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/post_model.dart';
import '../../../../data/services/storage_service.dart';
import '../media_viewer_screen.dart';
import 'signed_storage_image.dart';

class PostMediaCarousel extends StatefulWidget {
  final List<PostMediaItem> media;

  const PostMediaCarousel({
    super.key,
    required this.media,
  });

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  final _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openViewer(int initialIndex) {
    context.push(
      '/media-viewer',
      extra: MediaViewerArgs(
        items: widget.media,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) return const SizedBox.shrink();

    final firstRatio = widget.media.first.aspectRatio.clamp(0.65, 1.6);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        color: AppColors.blackPrimary,
        child: AspectRatio(
          aspectRatio: firstRatio,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.media.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final item = widget.media[index];
                  return GestureDetector(
                    onTap: () => _openViewer(index),
                    child: item.isVideo
                        ? _VideoPreviewTile(item: item)
                        : SignedStorageImage(
                            bucket: StorageService.postsMediaBucket,
                            storagePath: item.storagePath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                  );
                },
              ),

              // Contador superior derecho cuando hay múltiples archivos
              if (widget.media.length > 1)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blackPrimary.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${widget.media.length}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // Indicador de puntos inferior
              if (widget.media.length > 1)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.media.length, (i) {
                      final active = i == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.white
                              : AppColors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPreviewTile extends StatelessWidget {
  final PostMediaItem item;

  const _VideoPreviewTile({required this.item});

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return 'VIDEO';
    final mins = (seconds ~/ 60).toString().padLeft(1, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.blackElevated,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.blackPrimary.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 1.5),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.white,
              size: 34,
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.blackPrimary.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    size: 14,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _formatDuration(item.durationSec),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}