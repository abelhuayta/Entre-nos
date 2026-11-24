import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/capsule_model.dart';
import '../../../data/repositories/capsules_repository.dart';

class CapsulesController
    extends AutoDisposeAsyncNotifier<List<TimeCapsuleItem>> {
  @override
  Future<List<TimeCapsuleItem>> build() async {
    return await ref.read(capsulesRepositoryProvider).fetchCapsules();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(capsulesRepositoryProvider).fetchCapsules(),
    );
  }

  Future<String?> createCapsule({
    required String title,
    required String message,
    required DateTime unlockAt,
    File? imageFile,
  }) async {
    try {
      await ref.read(capsulesRepositoryProvider).createCapsule(
            title: title,
            message: message,
            unlockAt: unlockAt,
            imageFile: imageFile,
          );
      await refresh();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }
}

final capsulesProvider = AutoDisposeAsyncNotifierProvider<CapsulesController,
    List<TimeCapsuleItem>>(
  CapsulesController.new,
);