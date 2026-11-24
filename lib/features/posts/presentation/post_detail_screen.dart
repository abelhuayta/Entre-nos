import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../providers/feed_provider.dart';
import 'widgets/post_card.dart';

class PostDetailScreen extends ConsumerWidget {
  final String postId;

  const PostDetailScreen({
    super.key,
    required this.postId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postDetailProvider(postId));

    return AppScaffold(
      appBar: AppBar(title: const Text('Publicación')),
      body: postAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.white),
        ),
        error: (err, stackTrace) => EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Publicación no disponible',
          subtitle: err.toString(),
        ),
        data: (post) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            PostCard(post: post, isDetailView: true),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Ver conversación (${post.commentsCount} comentarios)',
              variant: AppButtonVariant.secondary,
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () => context.push('/comments/${post.id}'),
            ),
          ],
        ),
      ),
    );
  }
}