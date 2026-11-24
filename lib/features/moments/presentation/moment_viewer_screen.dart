import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../data/models/moment_model.dart';
import '../../../data/services/storage_service.dart';
import '../../auth/providers/session_gate_provider.dart';
import '../../media/presentation/widgets/signed_storage_image.dart';
import '../providers/moments_provider.dart';

class MomentViewerArgs {
  final List<AuthorMomentGroup> groups;
  final int initialGroupIndex;

  const MomentViewerArgs({
    required this.groups,
    this.initialGroupIndex = 0,
  });
}

class MomentViewerScreen extends ConsumerStatefulWidget {
  final MomentViewerArgs args;

  const MomentViewerScreen({
    super.key,
    required this.args,
  });

  @override
  ConsumerState<MomentViewerScreen> createState() => _MomentViewerScreenState();
}

class _MomentViewerScreenState extends ConsumerState<MomentViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late int _groupIndex;
  late int _momentIndex;

  AuthorMomentGroup get _currentGroup => widget.args.groups[_groupIndex];
  MomentItem get _currentMoment => _currentGroup.moments[_momentIndex];

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.args.initialGroupIndex.clamp(
      0,
      widget.args.groups.length - 1,
    );
    _momentIndex = _currentGroup.firstUnseenIndex;

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextMoment();
        }
      });

    _startCurrentMoment();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _startCurrentMoment() {
    _progressController
      ..reset()
      ..forward();
    ref.read(momentsHubProvider.notifier).markViewed(_currentMoment.id);
  }

  void _nextMoment() {
    if (_momentIndex + 1 < _currentGroup.moments.length) {
      setState(() => _momentIndex++);
      _startCurrentMoment();
      return;
    }

    if (_groupIndex + 1 < widget.args.groups.length) {
      setState(() {
        _groupIndex++;
        _momentIndex = _currentGroup.firstUnseenIndex;
      });
      _startCurrentMoment();
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _previousMoment() {
    if (_momentIndex > 0) {
      setState(() => _momentIndex--);
      _startCurrentMoment();
      return;
    }

    if (_groupIndex > 0) {
      setState(() {
        _groupIndex--;
        _momentIndex = _currentGroup.moments.length - 1;
      });
      _startCurrentMoment();
      return;
    }

    _startCurrentMoment();
  }

  void _showViewersSheet(MomentItem moment) {
    _progressController.stop();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visto por ${moment.views.length}',
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                if (moment.views.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Nadie ha visto este momento todavía.',
                      style: AppTypography.bodySmall,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: moment.views.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final v = moment.views[index];
                        final name = v.viewer?.fullName ?? 'Integrante';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AppAvatar(
                            name: name,
                            avatarPath: v.viewer?.avatarPath,
                            size: 38,
                          ),
                          title: Text(name, style: AppTypography.titleMedium),
                          trailing: Text(
                            DateFormatter.timeAgo(v.viewedAt),
                            style: AppTypography.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) _progressController.forward();
    });
  }

  Future<void> _deleteCurrentMoment() async {
    _progressController.stop();
    final target = _currentMoment;
    final error =
        await ref.read(momentsHubProvider.notifier).deleteMoment(target);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      _progressController.forward();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(sessionGateProvider).user?.id;
    final group = _currentGroup;
    final moment = _currentMoment;
    final isMine = moment.authorId == myUid;
    final authorName = group.author?.fullName ?? 'Integrante';

    return Scaffold(
      backgroundColor: AppColors.blackPrimary,
      body: SafeArea(
        child: GestureDetector(
          onLongPressStart: (_) => _progressController.stop(),
          onLongPressEnd: (_) => _progressController.forward(),
          onTapUp: (details) {
            final width = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < width * 0.32) {
              _previousMoment();
            } else {
              _nextMoment();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagen del momento
              SignedStorageImage(
                bucket: StorageService.postsMediaBucket,
                storagePath: moment.mediaPath,
                fit: BoxFit.contain,
              ),

              // Degradado superior para legibilidad
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 110,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.blackPrimary.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Barras de progreso + cabecera del autor
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) {
                        return Row(
                          children: List.generate(group.moments.length, (i) {
                            double value = 0;
                            if (i < _momentIndex) {
                              value = 1;
                            } else if (i == _momentIndex) {
                              value = _progressController.value;
                            }
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    minHeight: 2.8,
                                    backgroundColor:
                                        AppColors.white.withValues(alpha: 0.3),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      AppColors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        AppAvatar(
                          name: authorName,
                          avatarPath: group.author?.avatarPath,
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMine ? 'Tu momento' : authorName,
                                style: AppTypography.titleMedium,
                              ),
                              Text(
                                DateFormatter.timeAgo(moment.createdAt),
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isMine)
                          IconButton(
                            onPressed: _deleteCurrentMoment,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.white,
                            ),
                            tooltip: 'Eliminar momento',
                          ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Pie de foto y contador de vistas en la parte inferior
              Positioned(
                bottom: 18,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (moment.caption.trim().isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blackPrimary.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          moment.caption,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                    if (isMine) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _showViewersSheet(moment),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blackSecondary
                                .withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.visibility_outlined,
                                size: 16,
                                color: AppColors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Visto por ${moment.views.length}',
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}