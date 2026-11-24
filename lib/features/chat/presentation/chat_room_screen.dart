import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/models/post_model.dart';
import '../../../data/services/storage_service.dart';
import '../../auth/providers/session_gate_provider.dart';
import '../../media/presentation/media_viewer_screen.dart';
import '../../media/presentation/widgets/signed_storage_image.dart';
import '../providers/chat_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatRoomScreen({
    super.key,
    required this.conversationId,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  bool _sending = false;
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _textController.clear();

    final error = await ref
        .read(chatRoomProvider(widget.conversationId).notifier)
        .sendMessage(content: text);

    if (!mounted) return;
    setState(() => _sending = false);

    if (error != null) {
      _textController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_sending) return;
    final picked = await _picker.pickImage(source: source);
    if (picked == null || !mounted) return;

    setState(() => _sending = true);
    final error = await ref
        .read(chatRoomProvider(widget.conversationId).notifier)
        .sendMessage(
          content: _textController.text.trim(),
          imageFile: File(picked.path),
        );

    if (!mounted) return;
    if (error == null) {
      _textController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(chatRoomProvider(widget.conversationId));
    final myUid = ref.watch(sessionGateProvider).user?.id;

    return roomAsync.when(
      loading: () => AppScaffold(
        appBar: AppBar(title: const Text('Cargando chat...')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.white),
        ),
      ),
      error: (err, stackTrace) => AppScaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: EmptyStateView(
          icon: Icons.wifi_off_rounded,
          title: 'No se pudo abrir la conversación',
          subtitle: err.toString(),
          actionLabel: 'Reintentar',
          onAction: () =>
              ref.invalidate(chatRoomProvider(widget.conversationId)),
        ),
      ),
      data: (room) {
        if (room.messages.length != _lastMessageCount) {
          _lastMessageCount = room.messages.length;
          _scrollToBottom();
        }

        final conv = room.conversation;
        final title = conv.displayName(myUid);
        final avatarPath = conv.displayAvatarPath(myUid);

        return AppScaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                if (conv.isGroup)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: AppColors.blackPrimary,
                      size: 20,
                    ),
                  )
                else
                  AppAvatar(
                    name: title,
                    avatarPath: avatarPath,
                    size: 36,
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium,
                      ),
                      Text(
                        conv.isGroup
                            ? '${conv.participants.length} integrantes aprobados'
                            : 'Chat privado 1 a 1',
                        style: AppTypography.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: room.messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Text(
                            conv.isGroup
                                ? 'Inicia la conversación con todo el grupo.'
                                : 'Envía el primer mensaje privado a $title.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.md,
                          AppSpacing.screenHorizontal,
                          AppSpacing.md,
                        ),
                        itemCount: room.messages.length,
                        itemBuilder: (context, index) {
                          final msg = room.messages[index];
                          final isMine = msg.senderId == myUid;
                          final showSenderHeader = conv.isGroup &&
                              !isMine &&
                              (index == 0 ||
                                  room.messages[index - 1].senderId !=
                                      msg.senderId);

                          return _MessageBubble(
                            message: msg,
                            isMine: isMine,
                            showSenderHeader: showSenderHeader,
                            onLongPress: isMine
                                ? () => _confirmDeleteMessage(msg)
                                : null,
                          );
                        },
                      ),
              ),
              _MessageComposerBar(
                controller: _textController,
                sending: _sending,
                onPickGallery: () => _pickAndSendImage(ImageSource.gallery),
                onPickCamera: () => _pickAndSendImage(ImageSource.camera),
                onSend: _sendText,
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteMessage(ChatMessage message) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
          ),
          title: Text(
            'Eliminar mensaje para todos',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.error),
          ),
          onTap: () async {
            Navigator.of(ctx).pop();
            final error = await ref
                .read(chatRoomProvider(widget.conversationId).notifier)
                .deleteMessage(message);
            if (mounted && error != null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(error)));
            }
          },
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool showSenderHeader;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showSenderHeader,
    this.onLongPress,
  });

  String _clockTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final senderName = message.sender?.fullName ?? 'Integrante';

    return Padding(
      padding: EdgeInsets.only(
        top: showSenderHeader ? AppSpacing.md : 4,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderHeader)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                senderName,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.gray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppColors.white : AppColors.blackSecondary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                border: isMine
                    ? null
                    : Border.all(color: AppColors.divider, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.hasImage) ...[
                    GestureDetector(
                      onTap: () {
                        context.push(
                          '/media-viewer',
                          extra: MediaViewerArgs(
                            items: [
                              PostMediaItem(
                                id: message.id,
                                storagePath: message.mediaPath!,
                                mediaType: 'image',
                              ),
                            ],
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: SignedStorageImage(
                          bucket: StorageService.postsMediaBucket,
                          storagePath: message.mediaPath!,
                          width: 220,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (message.content.trim().isNotEmpty)
                      const SizedBox(height: 8),
                  ],
                  if (message.content.trim().isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        message.content,
                        style: AppTypography.bodyMedium.copyWith(
                          color: isMine
                              ? AppColors.blackPrimary
                              : AppColors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _clockTime(message.createdAt),
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 10.5,
                      color: isMine
                          ? AppColors.blackPrimary.withValues(alpha: 0.65)
                          : AppColors.gray,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onSend;

  const _MessageComposerBar({
    required this.controller,
    required this.sending,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.blackPrimary,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: sending ? null : onPickGallery,
            icon: const Icon(
              Icons.photo_outlined,
              color: AppColors.gray,
            ),
            tooltip: 'Enviar foto',
          ),
          IconButton(
            onPressed: sending ? null : onPickCamera,
            icon: const Icon(
              Icons.camera_alt_outlined,
              color: AppColors.gray,
            ),
            tooltip: 'Cámara',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: AppColors.white,
              style: AppTypography.bodyMedium,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Mensaje privado...',
                hintStyle: AppTypography.bodySmall,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppColors.blackSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.blackPrimary,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      color: AppColors.blackPrimary,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}