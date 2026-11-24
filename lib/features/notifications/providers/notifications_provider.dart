import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notifications_repository.dart';

final notificationsListProvider =
    FutureProvider.autoDispose<List<AppNotificationItem>>((ref) async {
  return await ref.read(notificationsRepositoryProvider).fetchNotifications();
});

final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final list = ref.watch(notificationsListProvider).valueOrNull ?? const [];
  return list.where((n) => !n.isRead).length;
});