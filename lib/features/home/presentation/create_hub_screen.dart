import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';

class CreateHubScreen extends StatelessWidget {
  const CreateHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Compartir en el círculo')),
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Elige qué quieres crear hoy con tus amigos.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          _CreateOptionTile(
            icon: Icons.edit_square,
            title: 'Publicación o Recuerdo',
            subtitle: 'Texto, fotos, videos y recuerdos permanentes en el muro',
            onTap: () => context.push(RouteNames.createPost),
          ),
          const SizedBox(height: AppSpacing.md),
          _CreateOptionTile(
            icon: Icons.auto_awesome_outlined,
            title: 'Momento · 24h',
            subtitle: 'Historia efímera que desaparece en 24 horas',
            onTap: () => context.push('/create-moment'),
          ),
          const SizedBox(height: AppSpacing.md),
          _CreateOptionTile(
            icon: Icons.poll_outlined,
            title: 'Encuesta del grupo',
            subtitle: 'Votación rápida para planes, salidas o decisiones',
            onTap: () => context.push('${RouteNames.createPost}?poll=1'),
          ),
          const SizedBox(height: AppSpacing.md),
          _CreateOptionTile(
            icon: Icons.hourglass_bottom_rounded,
            title: 'Cápsula del tiempo',
            subtitle: 'Mensaje o foto sellada hasta una fecha futura',
            onTap: () => context.push('/create-capsule'),
          ),
        ],
      ),
    );
  }
}

class _CreateOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateOptionTile({
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.blackSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.blackPrimary, size: 22),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMedium),
                  const SizedBox(height: 3),
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