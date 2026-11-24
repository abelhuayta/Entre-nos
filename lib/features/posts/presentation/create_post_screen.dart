import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/services/storage_service.dart';
import '../../auth/providers/auth_controller.dart';
import '../providers/feed_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final bool startAsPoll;

  const CreatePostScreen({
    super.key,
    this.startAsPoll = false,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  static const int _maxAttachments = 6;

  final _contentController = TextEditingController();
  final _pollQuestionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  final _picker = ImagePicker();
  final List<PendingMediaAttachment> _attachments = [];
  late bool _isPollMode;
  bool _allowsMultiple = false;
  bool _isMemory = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _isPollMode = widget.startAsPoll;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _pollQuestionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_attachments.length >= _maxAttachments) {
      _showSnack('Máximo $_maxAttachments archivos por publicación.');
      return;
    }

    final remaining = _maxAttachments - _attachments.length;
    final picked = await _picker.pickMultiImage(limit: remaining);
    if (picked.isEmpty || !mounted) return;

    setState(() {
      for (final xFile in picked.take(remaining)) {
        _attachments.add(
          PendingMediaAttachment(file: File(xFile.path), isVideo: false),
        );
      }
    });
  }

  Future<void> _capturePhoto() async {
    if (_attachments.length >= _maxAttachments) {
      _showSnack('Máximo $_maxAttachments archivos por publicación.');
      return;
    }

    final shot = await _picker.pickImage(source: ImageSource.camera);
    if (shot == null || !mounted) return;

    setState(() {
      _attachments.add(
        PendingMediaAttachment(file: File(shot.path), isVideo: false),
      );
    });
  }

  Future<void> _pickVideo() async {
    if (_attachments.length >= _maxAttachments) {
      _showSnack('Máximo $_maxAttachments archivos por publicación.');
      return;
    }

    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _attachments.add(
        PendingMediaAttachment(file: File(picked.path), isVideo: true),
      );
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _publish() async {
    if (_submitting) return;

    if (_isPollMode) {
      final question = _pollQuestionController.text.trim();
      final options = _optionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      if (question.isEmpty || options.length < 2) {
        _showSnack('Escribe una pregunta y al menos 2 opciones.');
        return;
      }

      setState(() => _submitting = true);
      final error =
          await ref.read(feedControllerProvider.notifier).createPollPost(
                question: question,
                options: options,
                allowsMultiple: _allowsMultiple,
              );
      if (!mounted) return;
      setState(() => _submitting = false);

      if (error != null) {
        _showSnack(error);
        return;
      }
      context.pop();
      return;
    }

    final text = _contentController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    setState(() => _submitting = true);
    final error = await ref.read(feedControllerProvider.notifier).createPost(
          content: text,
          attachments: List<PendingMediaAttachment>.from(_attachments),
          isMemory: _isMemory,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      _showSnack(error);
      return;
    }

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;

    return AppScaffold(
      appBar: AppBar(
        title: Text(_isPollMode ? 'Nueva encuesta' : 'Nueva publicación'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: AppButton(
              label: _submitting ? 'Publicando...' : 'Publicar',
              isFullWidth: false,
              height: 38,
              isLoading: _submitting,
              onPressed: _publish,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  name: profile?.fullName ?? 'Tú',
                  avatarPath: profile?.avatarPath,
                  size: 42,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.fullName ?? 'Integrante',
                        style: AppTypography.titleMedium,
                      ),
                      Text(
                        'Exclusivo para el círculo privado',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Selector de modo: Publicación vs Encuesta
            Row(
              children: [
                _ModeChip(
                  icon: Icons.edit_note_rounded,
                  label: 'Publicación',
                  selected: !_isPollMode,
                  onTap: _submitting
                      ? null
                      : () => setState(() => _isPollMode = false),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ModeChip(
                  icon: Icons.poll_outlined,
                  label: 'Encuesta',
                  selected: _isPollMode,
                  onTap: _submitting
                      ? null
                      : () => setState(() => _isPollMode = true),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            if (_isPollMode) ...[
              AppTextField(
                controller: _pollQuestionController,
                label: 'Pregunta para el grupo',
                hint: 'Ej. ¿Dónde nos juntamos este viernes?',
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Opciones de respuesta',
                style: AppTypography.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...List.generate(_optionControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _optionControllers[index],
                          hint: 'Opción ${index + 1}',
                        ),
                      ),
                      if (_optionControllers.length > 2)
                        IconButton(
                          onPressed: _submitting
                              ? null
                              : () {
                                  setState(() {
                                    final removed =
                                        _optionControllers.removeAt(index);
                                    removed.dispose();
                                  });
                                },
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: AppColors.gray,
                          ),
                        ),
                    ],
                  ),
                );
              }),
              if (_optionControllers.length < 5)
                TextButton.icon(
                  onPressed: _submitting
                      ? null
                      : () => setState(
                            () => _optionControllers
                                .add(TextEditingController()),
                          ),
                  icon: const Icon(Icons.add_rounded, color: AppColors.white),
                  label: Text(
                    'Añadir otra opción',
                    style: AppTypography.labelLarge.copyWith(fontSize: 13),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blackSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppColors.white,
                  title: Text(
                    'Permitir selección múltiple',
                    style: AppTypography.bodyMedium,
                  ),
                  subtitle: Text(
                    'Cada amigo puede marcar más de una opción.',
                    style: AppTypography.bodySmall,
                  ),
                  value: _allowsMultiple,
                  onChanged: _submitting
                      ? null
                      : (val) => setState(() => _allowsMultiple = val),
                ),
              ),
            ] else ...[
              TextField(
                controller: _contentController,
                autofocus: true,
                maxLines: 7,
                minLines: 4,
                maxLength: 2000,
                cursorColor: AppColors.white,
                style: AppTypography.bodyLarge.copyWith(fontSize: 16),
                decoration: InputDecoration(
                  hintText: '¿Qué está pasando entre nosotros?',
                  hintStyle: AppTypography.bodyLarge
                      .copyWith(color: AppColors.grayMuted),
                  filled: true,
                  fillColor: AppColors.blackSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: const BorderSide(color: AppColors.white),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _ModeChip(
                    icon: Icons.photo_library_outlined,
                    label: 'Fotos',
                    selected: false,
                    onTap: _submitting ? null : _pickImages,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ModeChip(
                    icon: Icons.camera_alt_outlined,
                    label: 'Cámara',
                    selected: false,
                    onTap: _submitting ? null : _capturePhoto,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ModeChip(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    selected: false,
                    onTap: _submitting ? null : _pickVideo,
                  ),
                ],
              ),
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attachments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = _attachments[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Container(
                              width: 112,
                              height: 112,
                              color: AppColors.blackElevated,
                              child: item.isVideo
                                  ? const Center(
                                      child: Icon(
                                        Icons.videocam_rounded,
                                        color: AppColors.white,
                                        size: 32,
                                      ),
                                    )
                                  : Image.file(
                                      item.file,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: _submitting
                                  ? null
                                  : () => setState(
                                        () => _attachments.removeAt(index),
                                      ),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.blackPrimary
                                      .withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blackSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppColors.white,
                  title: Text(
                    'Destacar como Recuerdo del grupo',
                    style: AppTypography.bodyMedium,
                  ),
                  subtitle: Text(
                    'Se indexará automáticamente en el álbum compartido de Recuerdos.',
                    style: AppTypography.bodySmall,
                  ),
                  value: _isMemory,
                  onChanged: _submitting
                      ? null
                      : (val) => setState(() => _isMemory = val),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.white : AppColors.blackSecondary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.white : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.blackPrimary : AppColors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: selected ? AppColors.blackPrimary : AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}