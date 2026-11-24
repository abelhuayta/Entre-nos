import 'user_profile.dart';

enum PostKind {
  text,
  media,
  poll,
  shared;

  static PostKind fromString(String? value) {
    return switch (value) {
      'media' => PostKind.media,
      'poll' => PostKind.poll,
      'shared' => PostKind.shared,
      _ => PostKind.text,
    };
  }
}

class PostMediaItem {
  final String id;
  final String storagePath;
  final String mediaType;
  final double aspectRatio;
  final int? durationSec;
  final String? thumbnailPath;
  final int orderIndex;

  const PostMediaItem({
    required this.id,
    required this.storagePath,
    required this.mediaType,
    this.aspectRatio = 0.8,
    this.durationSec,
    this.thumbnailPath,
    this.orderIndex = 0,
  });

  bool get isVideo => mediaType == 'video';

  factory PostMediaItem.fromJson(Map<String, dynamic> json) {
    return PostMediaItem(
      id: json['id'] as String,
      storagePath: json['storage_path'] as String,
      mediaType: (json['media_type'] as String?) ?? 'image',
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble() ?? 0.8,
      durationSec: json['duration_sec'] as int?,
      thumbnailPath: json['thumbnail_path'] as String?,
      orderIndex: (json['order_index'] as int?) ?? 0,
    );
  }
}

class PostReactionItem {
  final String id;
  final String userId;
  final String emoji;

  const PostReactionItem({
    required this.id,
    required this.userId,
    required this.emoji,
  });

  factory PostReactionItem.fromJson(Map<String, dynamic> json) {
    return PostReactionItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      emoji: (json['emoji'] as String?) ?? '❤️',
    );
  }
}

class PollOptionItem {
  final String id;
  final String optionText;
  final int orderIndex;

  const PollOptionItem({
    required this.id,
    required this.optionText,
    required this.orderIndex,
  });

  factory PollOptionItem.fromJson(Map<String, dynamic> json) {
    return PollOptionItem(
      id: json['id'] as String,
      optionText: (json['option_text'] as String?) ?? '',
      orderIndex: (json['order_index'] as int?) ?? 0,
    );
  }
}

class PollVoteItem {
  final String optionId;
  final String userId;

  const PollVoteItem({
    required this.optionId,
    required this.userId,
  });

  factory PollVoteItem.fromJson(Map<String, dynamic> json) {
    return PollVoteItem(
      optionId: json['option_id'] as String,
      userId: json['user_id'] as String,
    );
  }
}

class PostPollData {
  final String id;
  final String question;
  final bool allowsMultiple;
  final DateTime? endsAt;
  final List<PollOptionItem> options;
  final List<PollVoteItem> votes;

  const PostPollData({
    required this.id,
    required this.question,
    this.allowsMultiple = false,
    this.endsAt,
    this.options = const [],
    this.votes = const [],
  });

  bool get isExpired => endsAt != null && DateTime.now().isAfter(endsAt!);

  int get totalVoters => votes.map((v) => v.userId).toSet().length;

  int votesForOption(String optionId) =>
      votes.where((v) => v.optionId == optionId).length;

  bool hasUserVotedOption(String? userId, String optionId) {
    if (userId == null) return false;
    return votes.any((v) => v.userId == userId && v.optionId == optionId);
  }

  PostPollData copyWith({List<PollVoteItem>? votes}) {
    return PostPollData(
      id: id,
      question: question,
      allowsMultiple: allowsMultiple,
      endsAt: endsAt,
      options: options,
      votes: votes ?? this.votes,
    );
  }

  factory PostPollData.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['poll_options'] as List<dynamic>?) ?? const [];
    final parsedOptions = <PollOptionItem>[];
    for (final item in rawOptions) {
      if (item is Map<String, dynamic>) {
        parsedOptions.add(PollOptionItem.fromJson(item));
      }
    }
    parsedOptions.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final rawVotes = (json['poll_votes'] as List<dynamic>?) ?? const [];
    final parsedVotes = <PollVoteItem>[];
    for (final item in rawVotes) {
      if (item is Map<String, dynamic>) {
        parsedVotes.add(PollVoteItem.fromJson(item));
      }
    }

    return PostPollData(
      id: json['id'] as String,
      question: (json['question'] as String?) ?? '',
      allowsMultiple: (json['allows_multiple'] as bool?) ?? false,
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      options: parsedOptions,
      votes: parsedVotes,
    );
  }
}

class PostModel {
  final String id;
  final String circleId;
  final String authorId;
  final String content;
  final PostKind postType;
  final String? sharedPostId;
  final bool isMemory;
  final DateTime createdAt;
  final UserProfile? author;
  final List<PostMediaItem> media;
  final List<PostReactionItem> reactions;
  final int commentsCount;
  final bool isSavedByMe;
  final PostModel? sharedPost;
  final PostPollData? poll;

  const PostModel({
    required this.id,
    required this.circleId,
    required this.authorId,
    required this.content,
    required this.postType,
    this.sharedPostId,
    this.isMemory = false,
    required this.createdAt,
    this.author,
    this.media = const [],
    this.reactions = const [],
    this.commentsCount = 0,
    this.isSavedByMe = false,
    this.sharedPost,
    this.poll,
  });

  String? myReactionEmoji(String? currentUserId) {
    if (currentUserId == null) return null;
    for (final r in reactions) {
      if (r.userId == currentUserId) return r.emoji;
    }
    return null;
  }

  PostModel copyWith({
    List<PostReactionItem>? reactions,
    int? commentsCount,
    bool? isSavedByMe,
    PostModel? sharedPost,
    PostPollData? poll,
  }) {
    return PostModel(
      id: id,
      circleId: circleId,
      authorId: authorId,
      content: content,
      postType: postType,
      sharedPostId: sharedPostId,
      isMemory: isMemory,
      createdAt: createdAt,
      author: author,
      media: media,
      reactions: reactions ?? this.reactions,
      commentsCount: commentsCount ?? this.commentsCount,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
      sharedPost: sharedPost ?? this.sharedPost,
      poll: poll ?? this.poll,
    );
  }

  factory PostModel.fromJson(
    Map<String, dynamic> json, {
    Set<String> savedPostIds = const {},
  }) {
    final id = json['id'] as String;

    UserProfile? parsedAuthor;
    final authorRaw = json['author'];
    if (authorRaw is Map<String, dynamic>) {
      parsedAuthor = UserProfile.fromJson(authorRaw);
    }

    final mediaRaw = (json['post_media'] as List<dynamic>?) ?? const [];
    final parsedMedia = <PostMediaItem>[];
    for (final item in mediaRaw) {
      if (item is Map<String, dynamic>) {
        parsedMedia.add(PostMediaItem.fromJson(item));
      }
    }
    parsedMedia.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final reactionsRaw = (json['reactions'] as List<dynamic>?) ?? const [];
    final parsedReactions = <PostReactionItem>[];
    for (final item in reactionsRaw) {
      if (item is Map<String, dynamic>) {
        parsedReactions.add(PostReactionItem.fromJson(item));
      }
    }

    int parsedCommentsCount = 0;
    final commentsRaw = json['comments'];
    if (commentsRaw is List && commentsRaw.isNotEmpty) {
      final first = commentsRaw.first;
      if (first is Map && first['count'] is num) {
        parsedCommentsCount = (first['count'] as num).toInt();
      }
    }

    PostPollData? parsedPoll;
    final pollsRaw = json['polls'];
    if (pollsRaw is List && pollsRaw.isNotEmpty) {
      final first = pollsRaw.first;
      if (first is Map<String, dynamic>) {
        parsedPoll = PostPollData.fromJson(first);
      }
    } else if (pollsRaw is Map<String, dynamic>) {
      parsedPoll = PostPollData.fromJson(pollsRaw);
    }

    return PostModel(
      id: id,
      circleId: (json['circle_id'] as String?) ??
          '00000000-0000-0000-0000-000000000001',
      authorId: json['author_id'] as String,
      content: (json['content'] as String?) ?? '',
      postType: PostKind.fromString(json['post_type'] as String?),
      sharedPostId: json['shared_post_id'] as String?,
      isMemory: (json['is_memory'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: parsedAuthor,
      media: parsedMedia,
      reactions: parsedReactions,
      commentsCount: parsedCommentsCount,
      isSavedByMe: savedPostIds.contains(id),
      poll: parsedPoll,
    );
  }
}