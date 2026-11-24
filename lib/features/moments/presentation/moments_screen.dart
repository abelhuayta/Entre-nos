import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../data/models/moment_model.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/providers/session_gate_provider.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../providers/moments_provider.dart';
import 'moment_viewer_screen.dart';

class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hubAsync = ref.watch(momentsHubProvider);
    final myUid = ref.watch(sessionGateProvider).user?.id;
    final myProfile = ref.watch(currentUserProfileProvider).valueOrNull;

    return AppScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Momentos y Recuerdos',
              style: AppTypography.titleLarge.copyWith(letterSpacing: 0.4),
            ),
            Text(
              'Historias de 24h y archivo compartido',
              style: AppTypography.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/create-moment'),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Subir momento 24h',
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: hubAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: const [
            SkeletonLoader(
              width: double.infinity,
              height: 92,
              borderRadius: AppRadius.lg,
            ),
            SizedBox(height: AppSpacing.lg),
            SkeletonLoader(
              width: double.infinity,
              height: 180,
              borderRadius: AppRadius.lg,
            ),
          ],
        ),
        error: (err, stackTrace) => EmptyStateView(
          icon: Icons.auto_awesome_outlined,
          title: 'No se pudieron cargar los momentos',
          subtitle: err.toString(),
          actionLabel: 'Reintentar',
          onAction: () => ref.read(momentsHubProvider.notifier).refresh(),
        ),
        data: (hub) {
          return RefreshIndicator(
            color: AppColors.white,
            backgroundColor: AppColors.blackSecondary,
            onRefresh: () => ref.read(momentsHubProvider.notifier).refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Tira horizontal de Momentos activos (24h)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.md,
                          AppSpacing.screenHorizontal,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          'ACTIVOS · 24H',
                          style: AppTypography.labelSmall.copyWith(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 98,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          itemCount: hub.groups.length + 1,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: AppSpacing.md),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _AddMomentAvatarTile(
                                name: myProfile?.fullName ?? 'Tú',
                                avatarPath: myProfile?.avatarPath,
                                onTap: () => context.push('/create-moment'),
                              );
                            }

                            final groupIndex = index - 1;
                            final group = hub.groups[groupIndex];
                            final isMine = group.authorId == myUid;

                            return _StoryRingTile(
                              group: group,
                              isMine: isMine,
                              onTap: () async {
                                await context.push(
                                  '/moment-viewer',
                                  extra: MomentViewerArgs(
                                    groups: hub.groups,
                                    initialGroupIndex: groupIndex,
                                  ),
                                );
                                ref
                                    .read(momentsHubProvider.notifier)
                                    .refresh();
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(height: 1),
                    ],
                  ),
                ),

                // Encabezado del Álbum de Recuerdos
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.lg,
                      AppSpacing.screenHorizontal,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Álbum de Recuerdos',
                                style: AppTypography.titleLarge,
                              ),
                              Text(
                                'Momentos permanentes destacados por el grupo',
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push(RouteNames.createPost),
                          icon: const Icon(
                            Icons.bookmark_add_outlined,
                            size: 18,
                            color: AppColors.white,
                          ),
                          label: Text(
                            'Destacar',
                            style: AppTypography.labelLarge.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (hub.memories.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      icon: Icons.photo_album_outlined,
                      title: 'Aún no hay recuerdos guardados',
                      subtitle:
                          'Activa "Destacar como Recuerdo del grupo" al crear una publicación para conservarla aquí.',
                      actionLabel: 'Crear recuerdo',
                      onAction: () => context.push(RouteNames.createPost),
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
                      itemCount: hub.memories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.lg),
                      itemBuilder: (context, index) =>
                          PostCard(post: hub.memories[index]),
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

class _AddMomentAvatarTile extends StatelessWidget {
  final String name;
  final String? avatarPath;
  final VoidCallback onTap;

  const _AddMomentAvatarTile({
    required this.name,
    required this.avatarPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              children: [
                AppAvatar(
                  name: name,
                  avatarPath: avatarPath,
                  size: 62,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.blackPrimary,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: AppColors.blackPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Subir',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryRingTile extends StatelessWidget {
  final AuthorMomentGroup group;
  final bool isMine;
  final VoidCallback onTap;

  const _StoryRingTile({
    required this.group,
    required this.isMine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = group.author?.fullName ?? 'Integrante';
    final firstName = fullName.trim().split(RegExp(r'\s+')).first;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AppAvatar(
              name: fullName,
              avatarPath: group.author?.avatarPath,
              size: 62,
              hasStoryRing: true,
              storySeen: group.allSeen,
            ),
            const SizedBox(height: 6),
            Text(
              isMine ? 'Tu historia' : firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: group.allSeen ? AppColors.gray : AppColors.white,
                fontWeight:
                    group.allSeen ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}