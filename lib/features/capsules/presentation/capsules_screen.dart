import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../data/models/capsule_model.dart';
import '../../../data/models/post_model.dart';
import '../../../data/services/storage_service.dart';
import '../../media/presentation/media_viewer_screen.dart';
import '../../media/presentation/widgets/signed_storage_image.dart';
import '../providers/capsules_provider.dart';

class CapsulesScreen extends ConsumerWidget {
  const CapsulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capsulesAsync = ref.watch(capsulesProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Cápsulas del Tiempo'),
        actions: [
          IconButton(
            onPressed: () => context.push('/create-capsule'),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Sellar nueva cápsula',
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: capsulesAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          itemCount: 3,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => const SkeletonLoader(
            width: double.infinity,
            height: 140,
            borderRadius: AppRadius.lg,
          ),
        ),
        error: (err, stackTrace) => EmptyStateView(
          icon: Icons.hourglass_disabled_rounded,
          title: 'No se pudieron cargar las cápsulas',
          subtitle: err.toString(),
          actionLabel: 'Reintentar',
          onAction: () => ref.read(capsulesProvider.notifier).refresh(),
        ),
        data: (capsules) {
          if (capsules.isEmpty) {
            return EmptyStateView(
              icon: Icons.hourglass_empty_rounded,
              title: 'Sin cápsulas del tiempo aún',
              subtitle:
                  'Guarda una carta o fotografía hoy para abrirla junto a tus amigos en una fecha especial.',
              actionLabel: 'Crear primera cápsula',
              onAction: () => context.push('/create-capsule'),
            );
          }

          return RefreshIndicator(
            color: AppColors.white,
            backgroundColor: AppColors.blackSecondary,
            onRefresh: () => ref.read(capsulesProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: capsules.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) =>
                  _CapsuleCard(capsule: capsules[index]),
            ),
          );
        },
      ),
    );
  }
}

class _CapsuleCard extends StatelessWidget {
  final TimeCapsuleItem capsule;

  const _CapsuleCard({required this.capsule});

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y · $hh:$mm';
  }

  String _remainingLabel(DateTime unlockAt) {
    final diff = unlockAt.difference(DateTime.now());
    if (diff.isNegative) return 'Lista para abrir';
    if (diff.inDays >= 1) {
      return 'Se abre en ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}';
    }
    if (diff.inHours >= 1) {
      return 'Se abre en ${diff.inHours} ${diff.inHours == 1 ? 'hora' : 'horas'}';
    }
    final mins = diff.inMinutes.clamp(1, 59);
    return 'Se abre en $mins min';
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = capsule.isUnlocked;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.blackSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: unlocked
              ? AppColors.white.withValues(alpha: 0.35)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                name: capsule.creatorName,
                avatarPath: capsule.creatorAvatarPath,
                size: 38,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(capsule.title, style: AppTypography.titleMedium),
                    Text(
                      'Por ${capsule.creatorName} · ${_formatDate(capsule.unlockAt)}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: unlocked ? AppColors.white : AppColors.blackElevated,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      unlocked
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      size: 13,
                      color: unlocked
                          ? AppColors.blackPrimary
                          : AppColors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unlocked ? 'ABIERTA' : 'SELLADA',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: unlocked
                            ? AppColors.blackPrimary
                            : AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!unlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.blackPrimary,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.hourglass_bottom_rounded,
                    color: AppColors.gray,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Contenido protegido hasta su apertura · ${_remainingLabel(capsule.unlockAt)}',
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if ((capsule.message ?? '').trim().isNotEmpty)
              Text(
                capsule.message!,
                style: AppTypography.bodyLarge,
              ),
            if (capsule.mediaPath != null && capsule.mediaPath!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: () {
                  context.push(
                    '/media-viewer',
                    extra: MediaViewerArgs(
                      items: [
                        PostMediaItem(
                          id: capsule.id,
                          storagePath: capsule.mediaPath!,
                          mediaType: 'image',
                        ),
                      ],
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SignedStorageImage(
                    bucket: StorageService.postsMediaBucket,
                    storagePath: capsule.mediaPath!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}