import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../providers/feed_provider.dart';
import 'widgets/post_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 320;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedControllerProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return AppScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: AppTypography.titleLarge.copyWith(letterSpacing: 1.5),
            ),
            Text(
              AppConstants.appSlogan,
              style: AppTypography.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/capsules'),
            icon: const Icon(Icons.hourglass_bottom_rounded),
            tooltip: 'Cápsulas del tiempo',
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'Notificaciones',
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 11,
                  right: 11,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () => context.push(RouteNames.createPost),
            icon: const Icon(Icons.edit_square),
            tooltip: 'Nueva publicación',
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: feedAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          itemCount: 4,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.lg),
          itemBuilder: (context, index) => const SkeletonLoader(
            width: double.infinity,
            height: 165,
            borderRadius: AppRadius.lg,
          ),
        ),
        error: (err, stackTrace) => EmptyStateView(
          icon: Icons.wifi_off_rounded,
          title: 'No se pudo cargar el muro',
          subtitle: err.toString(),
          actionLabel: 'Reintentar',
          onAction: () => ref.read(feedControllerProvider.notifier).refresh(),
        ),
        data: (feedState) {
          return RefreshIndicator(
            color: AppColors.white,
            backgroundColor: AppColors.blackSecondary,
            onRefresh: () => ref.read(feedControllerProvider.notifier).refresh(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                      AppSpacing.screenHorizontal,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _FilterPill(
                              label: 'Recientes',
                              selected: feedState.filter == FeedFilter.all,
                              onTap: () => ref
                                  .read(feedControllerProvider.notifier)
                                  .setFilter(FeedFilter.all),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _FilterPill(
                              label: 'Guardados',
                              selected: feedState.filter == FeedFilter.saved,
                              onTap: () => ref
                                  .read(feedControllerProvider.notifier)
                                  .setFilter(FeedFilter.saved),
                            ),
                          ],
                        ),
                        if (feedState.hasNewRemotePosts) ...[
                          const SizedBox(height: AppSpacing.md),
                          InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            onTap: () => ref
                                .read(feedControllerProvider.notifier)
                                .refresh(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'Nuevas publicaciones · Tocar para actualizar',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.blackPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (feedState.posts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      icon: feedState.filter == FeedFilter.saved
                          ? Icons.bookmark_border_rounded
                          : Icons.forum_outlined,
                      title: feedState.filter == FeedFilter.saved
                          ? 'Sin publicaciones guardadas'
                          : 'Aún no hay publicaciones',
                      subtitle: feedState.filter == FeedFilter.saved
                          ? 'Guarda las publicaciones importantes del grupo para tenerlas siempre a mano.'
                          : 'Sé el primero en compartir algo con tus amigos en ENTRE NOS.',
                      actionLabel: feedState.filter == FeedFilter.saved
                          ? null
                          : 'Crear primera publicación',
                      onAction: feedState.filter == FeedFilter.saved
                          ? null
                          : () => context.push(RouteNames.createPost),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.sm,
                      AppSpacing.screenHorizontal,
                      AppSpacing.xxxl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: feedState.posts.length +
                          (feedState.isLoadingMore ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.lg),
                      itemBuilder: (context, index) {
                        if (index >= feedState.posts.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            ),
                          );
                        }
                        return PostCard(post: feedState.posts[index]);
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.white : AppColors.blackSecondary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.white : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: selected ? AppColors.blackPrimary : AppColors.gray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}