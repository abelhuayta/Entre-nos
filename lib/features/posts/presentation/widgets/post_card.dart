import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../data/models/post_model.dart';
import '../../../auth/providers/session_gate_provider.dart';
import '../../../media/presentation/widgets/post_media_carousel.dart';
import '../../providers/feed_provider.dart';

class PostCard extends ConsumerWidget {
  final PostModel post;
  final bool isDetailView;

  const PostCard({
    super.key,
    required this.post,
    this.isDetailView = false,
  });

  static const List<String> _reactionChoices = ['❤️', '😂', '🔥', '👏', '😮', '😢'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(sessionGateProvider);
    final myUid = gate.user?.id;
    final canDelete = post.authorId == myUid || gate.isAdmin;
    final myEmoji = post.myReactionEmoji(myUid);

    final authorName = post.author?.fullName ?? 'Integrante';
    final authorNick = post.author?.nickname ?? 'amigo';

    return GestureDetector(
      onTap: isDetailView ? null : () => context.push('/post/${post.id}'),
      onDoubleTap: () {
        HapticFeedback.lightImpact();
        ref.read(feedControllerProvider.notifier).toggleReaction(
              post: post,
              emoji: myEmoji ?? '❤️',
            );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.blackSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  name: authorName,
                  avatarPath: post.author?.avatarPath,
                  size: 42,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium,
                            ),
                          ),
                          if (post.isMemory) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.blackElevated,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Text(
                                'RECUERDO',
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 9.5,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$authorNick · ${DateFormatter.timeAgo(post.createdAt)}',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      _showPostOptionsSheet(context, ref, canDelete: canDelete),
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.gray,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            if (post.content.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                post.content,
                style: AppTypography.bodyLarge,
              ),
            ],

            if (post.poll != null) ...[
              const SizedBox(height: AppSpacing.md),
              _PollCardSection(
                post: post,
                poll: post.poll!,
                myUid: myUid,
              ),
            ],

            if (post.media.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              PostMediaCarousel(media: post.media),
            ],

            if (post.postType == PostKind.shared) ...[
              const SizedBox(height: AppSpacing.md),
              _EmbeddedSharedPost(sharedPost: post.sharedPost),
            ],

            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(feedControllerProvider.notifier).toggleReaction(
                          post: post,
                          emoji: myEmoji ?? '❤️',
                        );
                  },
                  onLongPress: () => _showReactionPicker(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: myEmoji != null
                          ? AppColors.blackElevated
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: myEmoji != null
                            ? AppColors.white.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (myEmoji != null)
                          Text(myEmoji, style: const TextStyle(fontSize: 15))
                        else
                          const Icon(
                            Icons.favorite_border_rounded,
                            size: 19,
                            color: AppColors.gray,
                          ),
                        if (post.reactions.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${post.reactions.length}',
                            style: AppTypography.bodySmall.copyWith(
                              color: myEmoji != null
                                  ? AppColors.white
                                  : AppColors.gray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.md),

                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: () => context.push('/comments/${post.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: AppColors.gray,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          post.commentsCount == 0
                              ? 'Comentar'
                              : '${post.commentsCount}',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),

                IconButton(
                  onPressed: () => _showShareSheet(context, ref),
                  icon: const Icon(
                    Icons.repeat_rounded,
                    size: 19,
                    color: AppColors.gray,
                  ),
                  tooltip: 'Compartir en el círculo',
                  visualDensity: VisualDensity.compact,
                ),

                const Spacer(),

                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref.read(feedControllerProvider.notifier).toggleSave(post);
                  },
                  icon: Icon(
                    post.isSavedByMe
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 20,
                    color: post.isSavedByMe ? AppColors.white : AppColors.gray,
                  ),
                  tooltip: 'Guardar',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _reactionChoices.map((emoji) {
              return InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(feedControllerProvider.notifier).toggleReaction(
                        post: post,
                        emoji: emoji,
                      );
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(emoji, style: const TextStyle(fontSize: 30)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showShareSheet(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final targetId = post.sharedPostId ?? post.id;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Compartir en ENTRE NOS', style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Vuelve a compartir esta publicación con el grupo.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: controller,
                hint: 'Añade un comentario opcional...',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Compartir ahora',
                onPressed: () async {
                  final text = controller.text;
                  Navigator.of(ctx).pop();
                  final error = await ref
                      .read(feedControllerProvider.notifier)
                      .sharePost(
                        originalPostId: targetId,
                        comment: text,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error ?? 'Compartido en el muro del círculo.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPostOptionsSheet(
    BuildContext context,
    WidgetRef ref, {
    required bool canDelete,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    post.isSavedByMe
                        ? Icons.bookmark_remove_outlined
                        : Icons.bookmark_add_outlined,
                    color: AppColors.white,
                  ),
                  title: Text(
                    post.isSavedByMe
                        ? 'Quitar de guardados'
                        : 'Guardar publicación',
                    style: AppTypography.bodyLarge,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref.read(feedControllerProvider.notifier).toggleSave(post);
                  },
                ),
                if (canDelete)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(
                      'Eliminar publicación',
                      style: AppTypography.bodyLarge
                          .copyWith(color: AppColors.error),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final error = await ref
                          .read(feedControllerProvider.notifier)
                          .deletePost(post);
                      if (context.mounted && error != null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(
                      Icons.flag_outlined,
                      color: AppColors.warning,
                    ),
                    title: Text(
                      'Reportar contenido al administrador',
                      style: AppTypography.bodyLarge,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showReportDialog(context, ref);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reportar publicación', style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'El administrador revisará este aviso de forma confidencial.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: reasonController,
                hint: 'Describe brevemente el motivo...',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Enviar reporte',
                variant: AppButtonVariant.destructive,
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.length < 3) return;
                  Navigator.of(ctx).pop();
                  final error = await ref
                      .read(feedControllerProvider.notifier)
                      .reportPost(postId: post.id, reason: reason);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error ?? 'Reporte enviado al administrador.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PollCardSection extends ConsumerWidget {
  final PostModel post;
  final PostPollData poll;
  final String? myUid;

  const _PollCardSection({
    required this.post,
    required this.poll,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalVotes = poll.votes.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.blackPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.poll_outlined,
                size: 16,
                color: AppColors.gray,
              ),
              const SizedBox(width: 6),
              Text(
                poll.allowsMultiple ? 'ENCUESTA · MÚLTIPLE' : 'ENCUESTA',
                style: AppTypography.labelSmall.copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            poll.question,
            style: AppTypography.titleMedium.copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.md),
          ...poll.options.map((option) {
            final count = poll.votesForOption(option.id);
            final selected = poll.hasUserVotedOption(myUid, option.id);
            final ratio = totalVotes == 0 ? 0.0 : count / totalVotes;
            final pct = (ratio * 100).round();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(feedControllerProvider.notifier).voteInPoll(
                        post: post,
                        optionId: option.id,
                      );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.blackSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: selected ? AppColors.white : AppColors.divider,
                      width: selected ? 1.3 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio.clamp(0.0, 1.0),
                          child: Container(
                            color: selected
                                ? AppColors.white.withValues(alpha: 0.16)
                                : AppColors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: selected
                                  ? AppColors.white
                                  : AppColors.gray,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                option.optionText,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (totalVotes > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '$pct%',
                                style: AppTypography.labelSmall.copyWith(
                                  color: selected
                                      ? AppColors.white
                                      : AppColors.gray,
                                  fontWeight: FontWeight.w700,
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
          }),
          const SizedBox(height: 4),
          Text(
            '${poll.totalVoters} ${poll.totalVoters == 1 ? 'voto' : 'votos'} en el círculo',
            style: AppTypography.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _EmbeddedSharedPost extends StatelessWidget {
  final PostModel? sharedPost;

  const _EmbeddedSharedPost({required this.sharedPost});

  @override
  Widget build(BuildContext context) {
    final original = sharedPost;
    if (original == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.blackPrimary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          'Publicación original no disponible.',
          style: AppTypography.bodySmall,
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.push('/post/${original.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.blackPrimary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  name: original.author?.fullName ?? 'Integrante',
                  avatarPath: original.author?.avatarPath,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  original.author?.fullName ?? 'Integrante',
                  style: AppTypography.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(width: 6),
                Text(
                  '· ${DateFormatter.timeAgo(original.createdAt)}',
                  style: AppTypography.labelSmall,
                ),
              ],
            ),
            if (original.content.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                original.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium,
              ),
            ],
            if (original.media.isNotEmpty) ...[
              const SizedBox(height: 8),
              PostMediaCarousel(media: original.media),
            ],
          ],
        ),
      ),
    );
  }
}