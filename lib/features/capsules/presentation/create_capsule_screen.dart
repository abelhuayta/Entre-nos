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
import '../providers/capsules_provider.dart';

class CreateCapsuleScreen extends ConsumerStatefulWidget {
  const CreateCapsuleScreen({super.key});

  @override
  ConsumerState<CreateCapsuleScreen> createState() =>
      _CreateCapsuleScreenState();
}

class _CreateCapsuleScreenState extends ConsumerState<CreateCapsuleScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  DateTime _unlockAt = DateTime.now().add(const Duration(days: 30));
  File? _imageFile;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _unlockAt,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_unlockAt),
    );
    if (!mounted) return;

    setState(() {
      _unlockAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? 20,
        pickedTime?.minute ?? 0,
      );
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _imageFile = File(picked.path));
  }

  Future<void> _saveCapsule() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final error = await ref.read(capsulesProvider.notifier).createCapsule(
          title: _titleController.text,
          message: _messageController.text,
          unlockAt: _unlockAt,
          imageFile: _imageFile,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    context.pop();
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y a las $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Sellar Cápsula'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: AppButton(
              label: _submitting ? 'Sellando...' : 'Sellar',
              isFullWidth: false,
              height: 38,
              isLoading: _submitting,
              onPressed: _saveCapsule,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _titleController,
              label: 'Título de la cápsula',
              hint: 'Ej. Año Nuevo 2027 · Promesas del grupo',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _messageController,
              label: 'Mensaje secreto para el futuro',
              hint: 'Nadie podrá leer esto hasta la fecha elegida...',
              maxLines: 5,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Fecha y hora de apertura', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: _submitting ? null : _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.blackSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      color: AppColors.white,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _formatDate(_unlockAt),
                        style: AppTypography.bodyLarge,
                      ),
                    ),
                    Text(
                      'Cambiar',
                      style: AppTypography.labelLarge.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_imageFile != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.file(
                      _imageFile!,
                      width: double.infinity,
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _submitting
                          ? null
                          : () => setState(() => _imageFile = null),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.blackPrimary.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              AppButton(
                label: 'Adjuntar fotografía opcional',
                variant: AppButtonVariant.secondary,
                icon: Icons.photo_outlined,
                onPressed: _submitting ? null : _pickImage,
              ),
          ],
        ),
      ),
    );
  }
}