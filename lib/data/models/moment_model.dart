import 'user_profile.dart';

class MomentViewItem {
  final String viewerId;
  final DateTime viewedAt;
  final UserProfile? viewer;

  const MomentViewItem({
    required this.viewerId,
    required this.viewedAt,
    this.viewer,
  });

  factory MomentViewItem.fromJson(Map<String, dynamic> json) {
    UserProfile? parsedViewer;
    final rawViewer = json['viewer'];
    if (rawViewer is Map<String, dynamic>) {
      parsedViewer = UserProfile.fromJson(rawViewer);
    }

    return MomentViewItem(
      viewerId: json['viewer_id'] as String,
      viewedAt: DateTime.parse(json['viewed_at'] as String),
      viewer: parsedViewer,
    );
  }
}

class MomentItem {
  final String id;
  final String circleId;
  final String authorId;
  final String mediaPath;
  final String mediaType;
  final String caption;
  final DateTime expiresAt;
  final DateTime createdAt;
  final UserProfile? author;
  final List<MomentViewItem> views;
  final bool isViewedByMe;

  const MomentItem({
    required this.id,
    required this.circleId,
    required this.authorId,
    required this.mediaPath,
    this.mediaType = 'image',
    this.caption = '',
    required this.expiresAt,
    required this.createdAt,
    this.author,
    this.views = const [],
    this.isViewedByMe = false,
  });

  MomentItem copyWith({
    bool? isViewedByMe,
    List<MomentViewItem>? views,
  }) {
    return MomentItem(
      id: id,
      circleId: circleId,
      authorId: authorId,
      mediaPath: mediaPath,
      mediaType: mediaType,
      caption: caption,
      expiresAt: expiresAt,
      createdAt: createdAt,
      author: author,
      views: views ?? this.views,
      isViewedByMe: isViewedByMe ?? this.isViewedByMe,
    );
  }

  factory MomentItem.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    UserProfile? parsedAuthor;
    final rawAuthor = json['author'];
    if (rawAuthor is Map<String, dynamic>) {
      parsedAuthor = UserProfile.fromJson(rawAuthor);
    }

    final rawViews = (json['moment_views'] as List<dynamic>?) ?? const [];
    final parsedViews = <MomentViewItem>[];
    for (final raw in rawViews) {
      if (raw is Map<String, dynamic>) {
        parsedViews.add(MomentViewItem.fromJson(raw));
      }
    }

    final seenByMe = parsedViews.any((v) => v.viewerId == currentUserId);

    return MomentItem(
      id: json['id'] as String,
      circleId: json['circle_id'] as String,
      authorId: json['author_id'] as String,
      mediaPath: json['media_path'] as String,
      mediaType: (json['media_type'] as String?) ?? 'image',
      caption: (json['caption'] as String?) ?? '',
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      author: parsedAuthor,
      views: parsedViews,
      isViewedByMe: seenByMe,
    );
  }
}

class AuthorMomentGroup {
  final String authorId;
  final UserProfile? author;
  final List<MomentItem> moments;

  const AuthorMomentGroup({
    required this.authorId,
    required this.author,
    required this.moments,
  });

  bool get allSeen => moments.every((m) => m.isViewedByMe);

  int get firstUnseenIndex {
    final idx = moments.indexWhere((m) => !m.isViewedByMe);
    return idx >= 0 ? idx : 0;
  }
}