import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/repositories/posts_repository.dart';
import '../../../data/services/supabase_service.dart';
import 'feed_provider.dart';

class CommentsController
    extends AutoDisposeFamilyAsyncNotifier<List<CommentModel>, String> {
  RealtimeChannel? _channel;

  @override
  Future<List<CommentModel>> build(String postId) async {
    ref.onDispose(() {
      if (_channel != null) {
        ref.read(supabaseClientProvider)?.removeChannel(_channel!);
        _channel = null;
      }
    });

    _subscribeRealtime(postId);
    return ref.read(postsRepositoryProvider).fetchComments(postId);
  }

  void _subscribeRealtime(String postId) {
    final client = ref.read(supabaseClientProvider);
    if (client == null || _channel != null) return;

    _channel = client
        .channel('post_comments_$postId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (_) async {
            state = await AsyncValue.guard(
              () => ref.read(postsRepositoryProvider).fetchComments(postId),
            );
          },
        )
        .subscribe();
  }

  Future<String?> addComment(String content) async {
    try {
      await ref.read(postsRepositoryProvider).addComment(
            postId: arg,
            content: content,
          );
      state = await AsyncValue.guard(
        () => ref.read(postsRepositoryProvider).fetchComments(arg),
      );
      ref.invalidate(postDetailProvider(arg));
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<String?> deleteComment(String commentId) async {
    try {
      await ref.read(postsRepositoryProvider).deleteComment(commentId);
      state = await AsyncValue.guard(
        () => ref.read(postsRepositoryProvider).fetchComments(arg),
      );
      ref.invalidate(postDetailProvider(arg));
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }
}

final commentsControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    CommentsController, List<CommentModel>, String>(
  CommentsController.new,
);