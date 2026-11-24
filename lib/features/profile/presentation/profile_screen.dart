import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/supabase_service.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/providers/session_gate_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../posts/providers/feed_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _changeAvatar() async {
    if (_uploadingAvatar) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      await ref
          .read(storageServiceProvider)
          .uploadAndSaveAvatar(File(picked.path));
      ref.invalidate(currentUserProfileProvider);
      ref.read(feedControllerProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada.')),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showEditProfileSheet(UserProfile profile) {
    final nameCtrl = TextEditingController(text: profile.fullName);
    final nickCtrl = TextEditingController(text: profile.nickname);
    final bioCtrl = TextEditingController(text: profile.bio);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editar perfil', style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: nameCtrl,
                label: 'Nombre completo', hint: 'Tu nombre',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: nickCtrl,
                label: 'Apodo (@usuario)', hint: 'Algo corto para que te identifiquen',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: bioCtrl,
                label: 'Biografía corta',
                hint: 'Algo sobre ti para tus amigos...',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Guardar cambios',
                onPressed: () async {
                  final client = ref.read(supabaseClientProvider);
                  if (client == null) return;
                  final fullName = nameCtrl.text.trim();
                  final nickname = nickCtrl.text.trim().replaceAll('@', '');
                  if (fullName.isEmpty || nickname.isEmpty) return;

                  Navigator.of(ctx).pop();
                  try {
                    await client.from('profiles').update({
                      'full_name': fullName,
                      'nickname': nickname,
                      'bio': bioCtrl.text.trim(),
                    }).eq('id', profile.id);

                    ref.invalidate(currentUserProfileProvider);
                    ref.read(feedControllerProvider.notifier).refresh();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Perfil actualizado.')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(sessionGateProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final friendsAsync = ref.watch(circleMembersForChatProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Tu Perfil'),
        actions: [
          if (profileAsync.valueOrNull != null)
            IconButton(
              onPressed: () =>
                  _showEditProfileSheet(profileAsync.valueOrNull!),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar perfil',
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            profileAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.white),
              ),
              error: (error, stackTrace) => Text(
                gate.user?.email ?? 'Integrante',
                style: AppTypography.titleLarge,
              ),
              data: (profile) => Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.blackSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _changeAvatar,
                          child: Stack(
                            children: [
                              AppAvatar(
                                name: profile?.fullName ?? 'Integrante',
                                avatarPath: profile?.avatarPath,
                                size: 68,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.blackPrimary,
                                    ),
                                  ),
                                  child: _uploadingAvatar
                                      ? const Padding(
                                          padding: EdgeInsets.all(5),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.blackPrimary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 13,
                                          color: AppColors.blackPrimary,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.fullName ?? 'Integrante',
                                style: AppTypography.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${profile?.nickname ?? 'amigo'} · ${gate.isAdmin ? 'Administrador' : 'Miembro aprobado'}',
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if ((profile?.bio ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        profile!.bio,
                        style: AppTypography.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Accesos rápidos del círculo
            Text(
              'ESPACIOS DEL CÍRCULO',
              style: AppTypography.labelSmall.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            _ProfileActionTile(
              icon: Icons.hourglass_bottom_rounded,
              title: 'Cápsulas del Tiempo',
              subtitle: 'Mensajes y fotos selladas para abrir en el futuro',
              onTap: () => context.push('/capsules'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ProfileActionTile(
              icon: Icons.notifications_none_rounded,
              title: 'Actividad y Notificaciones',
              subtitle: 'Reacciones y comentarios en tus publicaciones',
              onTap: () => context.push('/notifications'),
            ),
            if (gate.isAdmin) ...[
              const SizedBox(height: AppSpacing.sm),
              _ProfileActionTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Administración del grupo (30 cupos)',
                subtitle: 'Aprobar solicitudes, gestionar códigos y reportes',
                onTap: () => context.push(RouteNames.adminPanel),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // Directorio de integrantes aprobados
            Text(
              'INTEGRANTES DEL CÍRCULO',
              style: AppTypography.labelSmall.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            friendsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.white),
                ),
              ),
              error: (err, stackTrace) => Text(
                err.toString(),
                style: AppTypography.bodySmall,
              ),
              data: (friends) {
                if (friends.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.blackSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      'Aún eres el único integrante aprobado. Comparte tu código de invitación desde el panel de administración.',
                      style: AppTypography.bodySmall,
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.blackSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: friends.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      return ListTile(
                        leading: AppAvatar(
                          name: friend.fullName,
                          avatarPath: friend.avatarPath,
                          size: 40,
                        ),
                        title: Text(
                          friend.fullName,
                          style: AppTypography.titleMedium,
                        ),
                        subtitle: Text(
                          '@${friend.nickname}',
                          style: AppTypography.bodySmall,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.white,
                            size: 20,
                          ),
                          tooltip: 'Enviar mensaje privado',
                          onPressed: () async {
                            final convId = await ref
                                .read(chatRepositoryProvider)
                                .startOrGetDirectChat(friend.id);
                            if (context.mounted) {
                              context.push('/chat/$convId');
                            }
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            AppButton(
              label: 'Cerrar sesión',
              variant: AppButtonVariant.secondary,
              icon: Icons.logout_rounded,
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.blackSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.blackElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.white, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.bodySmall),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.gray,
            ),
          ],
        ),
      ),
    );
  }
}