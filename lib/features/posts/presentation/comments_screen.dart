import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../auth/providers/session_gate_provider.dart';
import '../providers/comments_provider.dart';
import '../providers/feed_provider.dart';

class CommentsScreen extends ConsumerStatefulWidget {
  final String postId;

  const CommentsScreen({
    super.key,
    required this.postId,
  });

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _inputController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final error = await ref
        .read(commentsControllerProvider(widget.postId).notifier)
        .addComment(text);

    if (!mounted) return;
    setState(() => _sending = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    _inputController.clear();
    ref.read(feedControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsControllerProvider(widget.postId));
    final gate = ref.watch(sessionGateProvider);

    return AppScaffold(
      appBar: AppBar(title: const Text('Comentarios')),
      body: Column(
        children: [
          Expanded(
            child: commentsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.white),
              ),
              error: (err, stackTrace) => EmptyStateView(
                icon: Icons.error_outline_rounded,
                title: 'Error al cargar comentarios',
                subtitle: err.toString(),
              ),
              data: (comments) {
                if (comments.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Sin comentarios aún',
                    subtitle: 'Inicia la conversación con el grupo.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  itemCount: comments.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = comments[index];
                    final canDelete =
                        item.authorId == gate.user?.id || gate.isAdmin;

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.blackSecondary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppAvatar(
                            name: item.author?.fullName ?? 'Amigo',
                            size: 36,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.author?.fullName ?? 'Integrante',
                                      style: AppTypography.titleMedium
                                          .copyWith(fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormatter.timeAgo(item.createdAt),
                                      style: AppTypography.labelSmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.content,
                                  style: AppTypography.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          if (canDelete)
                            IconButton(
                              onPressed: () async {
                                await ref
                                    .read(
                                      commentsControllerProvider(widget.postId)
                                          .notifier,
                                    )
                                    .deleteComment(item.id);
                                ref
                                    .read(feedControllerProvider.notifier)
                                    .refresh();
                              },
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppColors.gray,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Barra inferior de redacción
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.blackSecondary,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    cursorColor: AppColors.white,
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      filled: true,
                      fillColor: AppColors.blackPrimary,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: const BorderSide(color: AppColors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: AppColors.white,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}