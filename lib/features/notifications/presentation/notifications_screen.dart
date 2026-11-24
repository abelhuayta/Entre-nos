import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/notifications_repository.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(notificationsRepositoryProvider).markAllAsRead();
      ref.invalidate(notificationsListProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return AppScaffold(
      appBar: AppBar(title: const Text('Actividad')),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.white),
        ),
        error: (err, stackTrace) => EmptyStateView(
          icon: Icons.notifications_off_outlined,
          title: 'No se pudo cargar la actividad',
          subtitle: err.toString(),
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(notificationsListProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateView(
              icon: Icons.notifications_none_rounded,
              title: 'Todo al día',
              subtitle:
                  'Aquí verás las reacciones y comentarios nuevos en tus publicaciones.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: item.referenceId != null
                    ? () => context.push('/post/${item.referenceId}')
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.blackSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: item.isRead
                          ? AppColors.divider
                          : AppColors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.blackElevated,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.type == 'comment'
                              ? Icons.chat_bubble_outline_rounded
                              : Icons.favorite_border_rounded,
                          color: AppColors.white,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: AppTypography.titleMedium),
                            if (item.body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormatter.timeAgo(item.createdAt),
                        style: AppTypography.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}