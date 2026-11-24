import 'user_profile.dart';

class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String? parentId;
  final String content;
  final DateTime createdAt;
  final UserProfile? author;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    this.parentId,
    required this.content,
    required this.createdAt,
    this.author,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    UserProfile? parsedAuthor;
    final authorRaw = json['author'];
    if (authorRaw is Map<String, dynamic>) {
      parsedAuthor = UserProfile.fromJson(authorRaw);
    }

    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      parentId: json['parent_id'] as String?,
      content: (json['content'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      author: parsedAuthor,
    );
  }
}