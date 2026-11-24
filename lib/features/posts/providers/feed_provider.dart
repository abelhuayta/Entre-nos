import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/post_model.dart';
import '../../../data/repositories/posts_repository.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/supabase_service.dart';
import '../../auth/providers/session_gate_provider.dart';

enum FeedFilter {
  all,
  saved,
}

class FeedState {
  final List<PostModel> posts;
  final FeedFilter filter;
  final bool hasMore;
  final bool isLoadingMore;
  final bool hasNewRemotePosts;

  const FeedState({
    required this.posts,
    this.filter = FeedFilter.all,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.hasNewRemotePosts = false,
  });

  FeedState copyWith({
    List<PostModel>? posts,
    FeedFilter? filter,
    bool? hasMore,
    bool? isLoadingMore,
    bool? hasNewRemotePosts,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      filter: filter ?? this.filter,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasNewRemotePosts: hasNewRemotePosts ?? this.hasNewRemotePosts,
    );
  }
}

class FeedController extends AutoDisposeAsyncNotifier<FeedState> {
  RealtimeChannel? _postsChannel;

  @override
  Future<FeedState> build() async {
    ref.onDispose(() {
      if (_postsChannel != null) {
        ref.read(supabaseClientProvider)?.removeChannel(_postsChannel!);
        _postsChannel = null;
      }
    });

    _subscribeRealtimePosts();
    return _loadInitial(FeedFilter.all);
  }

  void _subscribeRealtimePosts() {
    final client = ref.read(supabaseClientProvider);
    final myUid = ref.read(sessionGateProvider).user?.id;
    if (client == null || _postsChannel != null) return;

    _postsChannel = client
        .channel('circle_feed_posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            final authorId = payload.newRecord['author_id'] as String?;
            if (authorId != null && authorId != myUid) {
              final current = state.valueOrNull;
              if (current != null && !current.hasNewRemotePosts) {
                state = AsyncData(current.copyWith(hasNewRemotePosts: true));
              }
            }
          },
        )
        .subscribe();
  }

  Future<FeedState> _loadInitial(FeedFilter filter) async {
    final posts = await ref.read(postsRepositoryProvider).fetchFeed(
          offset: 0,
          limit: AppConstants.feedPageSize,
          onlySaved: filter == FeedFilter.saved,
        );

    return FeedState(
      posts: posts,
      filter: filter,
      hasMore: posts.length >= AppConstants.feedPageSize,
      hasNewRemotePosts: false,
    );
  }

  Future<void> refresh() async {
    final currentFilter = state.valueOrNull?.filter ?? FeedFilter.all;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadInitial(currentFilter));
  }

  Future<void> setFilter(FeedFilter filter) async {
    final current = state.valueOrNull;
    if (current != null && current.filter == filter) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadInitial(filter));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final more = await ref.read(postsRepositoryProvider).fetchFeed(
            offset: current.posts.length,
            limit: AppConstants.feedPageSize,
            onlySaved: current.filter == FeedFilter.saved,
          );

      state = AsyncData(
        current.copyWith(
          posts: [...current.posts, ...more],
          hasMore: more.length >= AppConstants.feedPageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<String?> createPost({
    required String content,
    List<PendingMediaAttachment> attachments = const [],
    bool isMemory = false,
  }) async {
    try {
      await ref.read(postsRepositoryProvider).createPost(
            content: content,
            attachments: attachments,
            isMemory: isMemory,
          );
      await refresh();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<String?> createPollPost({
    required String question,
    required List<String> options,
    bool allowsMultiple = false,
  }) async {
    try {
      await ref.read(postsRepositoryProvider).createPollPost(
            question: question,
            options: options,
            allowsMultiple: allowsMultiple,
          );
      await refresh();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<String?> voteInPoll({
    required PostModel post,
    required String optionId,
  }) async {
    final myUid = ref.read(sessionGateProvider).user?.id;
    final current = state.valueOrNull;
    final poll = post.poll;
    if (myUid == null || current == null || poll == null || poll.isExpired) {
      return null;
    }

    final alreadyVotedThis = poll.hasUserVotedOption(myUid, optionId);
    final nextVotes = List<PollVoteItem>.from(poll.votes);

    if (alreadyVotedThis) {
      nextVotes.removeWhere(
        (v) => v.userId == myUid && v.optionId == optionId,
      );
    } else {
      if (!poll.allowsMultiple) {
        nextVotes.removeWhere((v) => v.userId == myUid);
      }
      nextVotes.add(PollVoteItem(optionId: optionId, userId: myUid));
    }

    final updatedPoll = poll.copyWith(votes: nextVotes);
    final optimisticPosts = current.posts
        .map((p) => p.id == post.id ? p.copyWith(poll: updatedPoll) : p)
        .toList();
    state = AsyncData(current.copyWith(posts: optimisticPosts));

    try {
      await ref.read(postsRepositoryProvider).voteInPoll(
            poll: poll,
            optionId: optionId,
          );
      return null;
    } on AppException catch (e) {
      state = AsyncData(current);
      return e.message;
    }
  }

  Future<String?> sharePost({
    required String originalPostId,
    String comment = '',
  }) async {
    try {
      await ref.read(postsRepositoryProvider).sharePostWithinCircle(
            originalPostId: originalPostId,
            comment: comment,
          );
      await refresh();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<String?> toggleReaction({
    required PostModel post,
    required String emoji,
  }) async {
    final myUid = ref.read(sessionGateProvider).user?.id;
    final current = state.valueOrNull;
    if (myUid == null || current == null) return null;

    final existingEmoji = post.myReactionEmoji(myUid);
    final nextEmoji = existingEmoji == emoji ? null : emoji;

    final updatedReactions =
        post.reactions.where((r) => r.userId != myUid).toList();
    if (nextEmoji != null) {
      updatedReactions.add(
        PostReactionItem(id: 'temp_$myUid', userId: myUid, emoji: nextEmoji),
      );
    }

    final optimisticPosts = current.posts
        .map(
          (p) => p.id == post.id ? p.copyWith(reactions: updatedReactions) : p,
        )
        .toList();
    state = AsyncData(current.copyWith(posts: optimisticPosts));

    try {
      await ref.read(postsRepositoryProvider).setReaction(
            postId: post.id,
            emoji: nextEmoji,
          );
      return null;
    } on AppException catch (e) {
      state = AsyncData(current);
      return e.message;
    }
  }

  Future<String?> toggleSave(PostModel post) async {
    final current = state.valueOrNull;
    if (current == null) return null;

    final nextSaved = !post.isSavedByMe;
    final optimisticPosts = current.posts
        .map((p) => p.id == post.id ? p.copyWith(isSavedByMe: nextSaved) : p)
        .toList();
    state = AsyncData(current.copyWith(posts: optimisticPosts));

    try {
      await ref.read(postsRepositoryProvider).toggleSavePost(
            postId: post.id,
            shouldSave: nextSaved,
          );
      if (current.filter == FeedFilter.saved && !nextSaved) {
        await refresh();
      }
      return null;
    } on AppException catch (e) {
      state = AsyncData(current);
      return e.message;
    }
  }

  Future<String?> deletePost(PostModel post) async {
    try {
      await ref.read(postsRepositoryProvider).deletePost(post);
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            posts: current.posts.where((p) => p.id != post.id).toList(),
          ),
        );
      }
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<String?> reportPost({
    required String postId,
    required String reason,
  }) async {
    try {
      await ref.read(postsRepositoryProvider).reportPost(
            postId: postId,
            reason: reason,
          );
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }
}

final feedControllerProvider =
    AutoDisposeAsyncNotifierProvider<FeedController, FeedState>(
  FeedController.new,
);

final postDetailProvider =
    FutureProvider.autoDispose.family<PostModel, String>((ref, postId) async {
  return await ref.read(postsRepositoryProvider).fetchPostById(postId);
});