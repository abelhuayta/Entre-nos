import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/moment_model.dart';
import '../../../data/models/post_model.dart';
import '../../../data/repositories/moments_repository.dart';
import '../../../data/repositories/posts_repository.dart';

class MomentsHubState {
  final List<AuthorMomentGroup> groups;
  final List<PostModel> memories;

  const MomentsHubState({
    required this.groups,
    required this.memories,
  });
}

class MomentsHubController extends AutoDisposeAsyncNotifier<MomentsHubState> {
  @override
  Future<MomentsHubState> build() async {
    return _loadAll();
  }

  Future<MomentsHubState> _loadAll() async {
    final groups =
        await ref.read(momentsRepositoryProvider).fetchActiveMomentGroups();
    final memories = await ref.read(postsRepositoryProvider).fetchMemories();
    return MomentsHubState(groups: groups, memories: memories);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadAll);
  }

  Future<String?> publishMoment({
    required File imageFile,
    String caption = '',
  }) async {
    try {
      await ref.read(momentsRepositoryProvider).publishMoment(
            imageFile: imageFile,
            caption: caption,
          );
      await refresh();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<void> markViewed(String momentId) async {
    await ref.read(momentsRepositoryProvider).markMomentViewed(momentId);
  }

  Future<String?> deleteMoment(MomentItem moment) async {
    try {
      await ref.read(momentsRepositoryProvider).deleteMoment(moment);
      await refresh();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }
}

final momentsHubProvider =
    AutoDisposeAsyncNotifierProvider<MomentsHubController, MomentsHubState>(
  MomentsHubController.new,
);