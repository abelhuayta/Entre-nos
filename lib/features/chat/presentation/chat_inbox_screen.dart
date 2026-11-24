import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../auth/providers/session_gate_provider.dart';
import '../providers/chat_provider.dart';

class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsListProvider);
    final myUid = ref.watch(sessionGateProvider).user?.id;

    return AppScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mensajes',
              style: AppTypography.titleLarge.copyWith(letterSpacing: 0.6),
            ),
            Text(
              'Conversaciones privadas del círculo',
              style: AppTypography.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showNewDirectChatSheet(context, ref),
            icon: const Icon(Icons.rate_review_outlined),
            tooltip: 'Nuevo chat privado',
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: conversationsAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          itemCount: 5,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => const SkeletonLoader(
            width: double.infinity,
            height: 76,
            borderRadius: AppRadius.lg,
          ),
        ),
        error: (err, stackTrace) => EmptyStateView(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'No se pudieron cargar los chats',
          subtitle: err.toString(),
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(conversationsListProvider),
        ),
        data: (conversations) {
          return RefreshIndicator(
            color: AppColors.white,
            backgroundColor: AppColors.blackSecondary,
            onRefresh: () async {
              ref.invalidate(conversationsListProvider);
              await ref.read(conversationsListProvider.future);
            },
            child: conversations.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      EmptyStateView(
                        icon: Icons.forum_outlined,
                        title: 'Sin conversaciones aún',
                        subtitle:
                            'Inicia un mensaje privado con cualquiera de tus amigos aprobados.',
                        actionLabel: 'Nuevo chat privado',
                        onAction: () => _showNewDirectChatSheet(context, ref),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                      AppSpacing.screenHorizontal,
                      AppSpacing.xxxl,
                    ),
                    itemCount: conversations.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final conv = conversations[index];
                      return _ConversationTile(
                        conversation: conv,
                        myUid: myUid,
                        onTap: () async {
                          await context.push('/chat/${conv.id}');
                          ref.invalidate(conversationsListProvider);
                        },
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  void _showNewDirectChatSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.88,
          builder: (context, scrollController) {
            return _DirectMemberPickerSheet(
              scrollController: scrollController,
              onSelectMember: (userId) async {
                Navigator.of(ctx).pop();
                try {
                  final convId = await ref
                      .read(chatRepositoryProvider)
                      .startOrGetDirectChat(userId);
                  if (context.mounted) {
                    await context.push('/chat/$convId');
                    ref.invalidate(conversationsListProvider);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
            );
          },
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final String? myUid;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.myUid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = conversation.displayName(myUid);
    final avatarPath = conversation.displayAvatarPath(myUid);
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.blackSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: conversation.isGroup
                ? AppColors.white.withValues(alpha: 0.28)
                : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            if (conversation.isGroup)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.groups_rounded,
                  color: AppColors.blackPrimary,
                  size: 26,
                ),
              )
            else
              AppAvatar(
                name: title,
                avatarPath: avatarPath,
                size: 50,
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormatter.timeAgo(conversation.lastMessageAt),
                        style: AppTypography.labelSmall.copyWith(
                          color: hasUnread ? AppColors.white : AppColors.gray,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessageText ??
                              (conversation.isGroup
                                  ? '${conversation.participants.length} integrantes'
                                  : 'Toca para escribir un mensaje'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: hasUnread ? AppColors.white : AppColors.gray,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.blackPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectMemberPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final ValueChanged<String> onSelectMember;

  const _DirectMemberPickerSheet({
    required this.scrollController,
    required this.onSelectMember,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(circleMembersForChatProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Nuevo mensaje privado', style: AppTypography.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Elige un integrante aprobado del círculo',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: friendsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.white),
              ),
              error: (err, stackTrace) => Center(
                child: Text(err.toString(), style: AppTypography.bodySmall),
              ),
              data: (friends) {
                if (friends.isEmpty) {
                  return Center(
                    child: Text(
                      'Aún no hay otros miembros aprobados en el círculo.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall,
                    ),
                  );
                }

                return ListView.separated(
                  controller: scrollController,
                  itemCount: friends.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: AppAvatar(
                        name: friend.fullName,
                        avatarPath: friend.avatarPath,
                        size: 44,
                      ),
                      title: Text(
                        friend.fullName,
                        style: AppTypography.titleMedium,
                      ),
                      subtitle: Text(
                        '@${friend.nickname}',
                        style: AppTypography.bodySmall,
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.gray,
                      ),
                      onTap: () => onSelectMember(friend.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}