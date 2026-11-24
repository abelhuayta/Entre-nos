import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class PostsRepository {
  static const String _defaultCircleId =
      '00000000-0000-0000-0000-000000000001';

  static const String _postSelectQuery = '''
    id,
    circle_id,
    author_id,
    content,
    post_type,
    shared_post_id,
    is_memory,
    created_at,
    author:profiles!posts_author_id_fkey(id, email, full_name, nickname, bio, avatar_path, avatar_config, created_at),
    post_media(id, storage_path, media_type, aspect_ratio, duration_sec, thumbnail_path, order_index),
    reactions(id, user_id, emoji),
    comments(count),
    polls(id, question, allows_multiple, ends_at, poll_options(id, option_text, order_index), poll_votes(option_id, user_id))
  ''';

  final SupabaseClient? _client;
  final StorageService _storageService;

  const PostsRepository(this._client, this._storageService);

  SupabaseClient get _requireClient {
    final c = _client;
    if (c == null) {
      throw const AuthAppException('Supabase no está configurado.');
    }
    return c;
  }

  Future<List<PostModel>> fetchFeed({
    int offset = 0,
    int limit = AppConstants.feedPageSize,
    bool onlySaved = false,
  }) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final savedRows = await client
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', uid);

      final savedIds = (savedRows as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['post_id'] as String)
          .toSet();

      if (onlySaved && savedIds.isEmpty) {
        return const [];
      }

      var query = client
          .from('posts')
          .select(_postSelectQuery)
          .eq('circle_id', _defaultCircleId);

      if (onlySaved) {
        query = query.inFilter('id', savedIds.toList());
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final posts = (rows as List<dynamic>)
          .map(
            (row) => PostModel.fromJson(
              row as Map<String, dynamic>,
              savedPostIds: savedIds,
            ),
          )
          .toList();

      return await _hydrateSharedPosts(posts, savedIds);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<PostModel>> fetchMemories({int limit = 60}) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final savedRows = await client
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', uid);

      final savedIds = (savedRows as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['post_id'] as String)
          .toSet();

      final rows = await client
          .from('posts')
          .select(_postSelectQuery)
          .eq('circle_id', _defaultCircleId)
          .eq('is_memory', true)
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = (rows as List<dynamic>)
          .map(
            (row) => PostModel.fromJson(
              row as Map<String, dynamic>,
              savedPostIds: savedIds,
            ),
          )
          .toList();

      return await _hydrateSharedPosts(posts, savedIds);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<PostModel> fetchPostById(String postId) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final savedRow = await client
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', uid)
          .eq('post_id', postId)
          .maybeSingle();

      final savedIds = savedRow != null ? {postId} : <String>{};

      final row = await client
          .from('posts')
          .select(_postSelectQuery)
          .eq('id', postId)
          .single();

      final post = PostModel.fromJson(row, savedPostIds: savedIds);
      final hydrated = await _hydrateSharedPosts([post], savedIds);
      return hydrated.first;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<PostModel>> _hydrateSharedPosts(
    List<PostModel> posts,
    Set<String> savedIds,
  ) async {
    final sharedIds = posts
        .map((p) => p.sharedPostId)
        .whereType<String>()
        .toSet()
        .toList();

    if (sharedIds.isEmpty) return posts;

    final sharedRows = await _requireClient
        .from('posts')
        .select(_postSelectQuery)
        .inFilter('id', sharedIds);

    final sharedMap = <String, PostModel>{};
    for (final raw in (sharedRows as List<dynamic>)) {
      final parsed = PostModel.fromJson(
        raw as Map<String, dynamic>,
        savedPostIds: savedIds,
      );
      sharedMap[parsed.id] = parsed;
    }

    return posts.map((post) {
      final targetId = post.sharedPostId;
      if (targetId != null && sharedMap.containsKey(targetId)) {
        return post.copyWith(sharedPost: sharedMap[targetId]);
      }
      return post;
    }).toList();
  }

  Future<void> createPost({
    required String content,
    List<PendingMediaAttachment> attachments = const [],
    bool isMemory = false,
  }) async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      throw const AuthAppException('Sesión no iniciada.');
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty && attachments.isEmpty) {
      throw const ValidationAppException(
        'Escribe un texto o adjunta al menos una foto o video.',
      );
    }

    String? createdPostId;
    final List<String> uploadedPaths = [];

    try {
      final inserted = await client
          .from('posts')
          .insert({
            'circle_id': _defaultCircleId,
            'author_id': uid,
            'content': trimmed,
            'post_type': attachments.isNotEmpty ? 'media' : 'text',
            'is_memory': isMemory,
          })
          .select('id')
          .single();

      createdPostId = inserted['id'] as String;

      if (attachments.isNotEmpty) {
        final List<dynamic> mediaRows = [];
        for (var i = 0; i < attachments.length; i++) {
          final uploaded = await _storageService.uploadPostMedia(
            postId: createdPostId,
            attachment: attachments[i],
            orderIndex: i,
          );
          uploadedPaths.add(uploaded.storagePath);
          mediaRows.add({
            'post_id': createdPostId,
            'storage_path': uploaded.storagePath,
            'media_type': uploaded.mediaType,
            'aspect_ratio': uploaded.aspectRatio,
            'duration_sec': uploaded.durationSec,
            'order_index': uploaded.orderIndex,
          });
        }

        await client.from('post_media').insert(mediaRows);
      }
    } catch (e) {
      if (uploadedPaths.isNotEmpty) {
        await _storageService.removePostFiles(uploadedPaths);
      }
      if (createdPostId != null) {
        try {
          await client.from('posts').delete().eq('id', createdPostId);
        } catch (_) {}
      }
      throw ErrorMapper.map(e);
    }
  }

  Future<void> createPollPost({
    required String question,
    required List<String> options,
    bool allowsMultiple = false,
  }) async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      throw const AuthAppException('Sesión no iniciada.');
    }

    final cleanQuestion = question.trim();
    final cleanOptions = options
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();

    if (cleanQuestion.isEmpty || cleanOptions.length < 2) {
      throw const ValidationAppException(
        'Ingresa una pregunta y al menos 2 opciones.',
      );
    }

    String? createdPostId;
    try {
      final postRow = await client
          .from('posts')
          .insert({
            'circle_id': _defaultCircleId,
            'author_id': uid,
            'content': '',
            'post_type': 'poll',
            'is_memory': false,
          })
          .select('id')
          .single();

      createdPostId = postRow['id'] as String;

      final pollRow = await client
          .from('polls')
          .insert({
            'post_id': createdPostId,
            'question': cleanQuestion,
            'allows_multiple': allowsMultiple,
          })
          .select('id')
          .single();

      final pollId = pollRow['id'] as String;

      final List<dynamic> optionRows = [];
      for (var i = 0; i < cleanOptions.length; i++) {
        optionRows.add({
          'poll_id': pollId,
          'option_text': cleanOptions[i],
          'order_index': i,
        });
      }

      await client.from('poll_options').insert(optionRows);
    } catch (e) {
      if (createdPostId != null) {
        try {
          await client.from('posts').delete().eq('id', createdPostId);
        } catch (_) {}
      }
      throw ErrorMapper.map(e);
    }
  }

  Future<void> voteInPoll({
    required PostPollData poll,
    required String optionId,
  }) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final alreadyVotedThis = poll.hasUserVotedOption(uid, optionId);

      if (alreadyVotedThis) {
        await client
            .from('poll_votes')
            .delete()
            .eq('poll_id', poll.id)
            .eq('option_id', optionId)
            .eq('user_id', uid);
        return;
      }

      if (!poll.allowsMultiple) {
        await client
            .from('poll_votes')
            .delete()
            .eq('poll_id', poll.id)
            .eq('user_id', uid);
      }

      await client.from('poll_votes').insert({
        'poll_id': poll.id,
        'option_id': optionId,
        'user_id': uid,
      });
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> sharePostWithinCircle({
    required String originalPostId,
    String comment = '',
  }) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      await client.from('posts').insert({
        'circle_id': _defaultCircleId,
        'author_id': uid,
        'content': comment.trim(),
        'post_type': 'shared',
        'shared_post_id': originalPostId,
        'is_memory': false,
      });
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> deletePost(PostModel post) async {
    try {
      final paths = post.media.map((m) => m.storagePath).toList();
      await _requireClient.from('posts').delete().eq('id', post.id);
      await _storageService.removePostFiles(paths);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> setReaction({
    required String postId,
    required String? emoji,
  }) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      if (emoji == null) {
        await client
            .from('reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', uid);
      } else {
        await client.from('reactions').upsert(
          {
            'post_id': postId,
            'user_id': uid,
            'emoji': emoji,
          },
          onConflict: 'post_id,user_id',
        );
      }
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> toggleSavePost({
    required String postId,
    required bool shouldSave,
  }) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      if (shouldSave) {
        await client.from('saved_posts').upsert(
          {
            'user_id': uid,
            'post_id': postId,
          },
          onConflict: 'user_id,post_id',
        );
      } else {
        await client
            .from('saved_posts')
            .delete()
            .eq('user_id', uid)
            .eq('post_id', postId);
      }
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> reportPost({
    required String postId,
    required String reason,
  }) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      await client.from('content_reports').upsert(
        {
          'post_id': postId,
          'reporter_id': uid,
          'reason': reason.trim(),
        },
        onConflict: 'post_id,reporter_id',
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<CommentModel>> fetchComments(String postId) async {
    try {
      final rows = await _requireClient
          .from('comments')
          .select('''
            id,
            post_id,
            author_id,
            parent_id,
            content,
            created_at,
            author:profiles!comments_author_id_fkey(id, email, full_name, nickname, bio, avatar_path, avatar_config, created_at)
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (rows as List<dynamic>)
          .map((row) => CommentModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> addComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final trimmed = content.trim();
      if (trimmed.isEmpty) {
        throw const ValidationAppException('Escribe un comentario.');
      }

      await client.from('comments').insert({
        'post_id': postId,
        'author_id': uid,
        'parent_id': parentId,
        'content': trimmed,
      });
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _requireClient.from('comments').delete().eq('id', commentId);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}

final postsRepositoryProvider = Provider<PostsRepository>((ref) {
  return PostsRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storageServiceProvider),
  );
});