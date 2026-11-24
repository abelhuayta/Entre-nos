import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/moments_provider.dart';

class CreateMomentScreen extends ConsumerStatefulWidget {
  const CreateMomentScreen({super.key});

  @override
  ConsumerState<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends ConsumerState<CreateMomentScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  File? _selectedImage;
  bool _submitting = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_submitting) return;
    final picked = await _picker.pickImage(source: source);
    if (picked == null || !mounted) return;
    setState(() {
      _selectedImage = File(picked.path);
    });
  }

  Future<void> _publish() async {
    final file = _selectedImage;
    if (file == null || _submitting) return;

    setState(() => _submitting = true);
    final error = await ref.read(momentsHubProvider.notifier).publishMoment(
          imageFile: file,
          caption: _captionController.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Nuevo Momento · 24h'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: AppButton(
              label: _submitting ? 'Subiendo...' : 'Compartir',
              isFullWidth: false,
              height: 38,
              isLoading: _submitting,
              onPressed: _selectedImage == null ? null : _publish,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visible durante 24 horas exclusivamente para los integrantes aprobados del círculo.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            AspectRatio(
              aspectRatio: 9 / 14,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.blackSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: _selectedImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_selectedImage!, fit: BoxFit.cover),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: _submitting
                                  ? null
                                  : () => setState(() => _selectedImage = null),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.blackPrimary
                                      .withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            size: 42,
                            color: AppColors.gray,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Elige una foto para tu momento',
                            style: AppTypography.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppButton(
                                label: 'Galería',
                                icon: Icons.photo_library_outlined,
                                isFullWidth: false,
                                height: 42,
                                onPressed: () =>
                                    _pickImage(ImageSource.gallery),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              AppButton(
                                label: 'Cámara',
                                icon: Icons.camera_alt_outlined,
                                variant: AppButtonVariant.secondary,
                                isFullWidth: false,
                                height: 42,
                                onPressed: () => _pickImage(ImageSource.camera),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _captionController,
              hint: 'Pie de foto opcional...',
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}