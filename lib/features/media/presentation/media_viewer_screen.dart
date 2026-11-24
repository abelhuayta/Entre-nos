import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/post_model.dart';
import '../../../data/services/storage_service.dart';
import '../providers/media_provider.dart';
import 'widgets/signed_storage_image.dart';

class MediaViewerArgs {
  final List<PostMediaItem> items;
  final int initialIndex;

  const MediaViewerArgs({
    required this.items,
    this.initialIndex = 0,
  });
}

class MediaViewerScreen extends StatefulWidget {
  final MediaViewerArgs args;

  const MediaViewerScreen({
    super.key,
    required this.args,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.args.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.args.items.length;

    return Scaffold(
      backgroundColor: AppColors.blackPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.blackPrimary,
        title: Text(
          total > 1 ? '${_currentIndex + 1} de $total' : 'Vista privada',
          style: AppTypography.titleMedium,
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: total,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final item = widget.args.items[index];
          if (item.isVideo) {
            return _FullScreenVideoPlayer(storagePath: item.storagePath);
          }
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: SignedStorageImage(
                bucket: StorageService.postsMediaBucket,
                storagePath: item.storagePath,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FullScreenVideoPlayer extends ConsumerStatefulWidget {
  final String storagePath;

  const _FullScreenVideoPlayer({required this.storagePath});

  @override
  ConsumerState<_FullScreenVideoPlayer> createState() =>
      _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState
    extends ConsumerState<_FullScreenVideoPlayer> {
  VideoPlayerController? _controller;
  String? _initializedForUrl;
  bool _hasError = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initVideo(String url) async {
    if (_initializedForUrl == url) return;
    _initializedForUrl = url;

    await _controller?.dispose();
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = ctrl;

    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlAsync = ref.watch(
      signedMediaUrlProvider(
        (bucket: StorageService.postsMediaBucket, path: widget.storagePath),
      ),
    );

    return urlAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.white),
      ),
      error: (error, stackTrace) => const Center(
        child: Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
      ),
      data: (url) {
        if (_initializedForUrl != url && !_hasError) {
          Future.microtask(() => _initVideo(url));
        }

        if (_hasError) {
          return const Center(
            child: Text('No se pudo reproducir el video.'),
          );
        }

        final ctrl = _controller;
        if (ctrl == null || !ctrl.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.white),
          );
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              if (ctrl.value.isPlaying) {
                ctrl.pause();
              } else {
                ctrl.play();
              }
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: ctrl.value.aspectRatio,
                child: VideoPlayer(ctrl),
              ),
              if (!ctrl.value.isPlaying)
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.blackPrimary.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.white,
                    size: 38,
                  ),
                ),
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: VideoProgressIndicator(
                  ctrl,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.white,
                    bufferedColor: AppColors.grayMuted,
                    backgroundColor: AppColors.divider,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}