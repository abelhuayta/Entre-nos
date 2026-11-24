import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/skeleton_loader.dart';

class DesignSystemPreviewScreen extends StatefulWidget {
  const DesignSystemPreviewScreen({super.key});

  @override
  State<DesignSystemPreviewScreen> createState() =>
      _DesignSystemPreviewScreenState();
}

class _DesignSystemPreviewScreenState extends State<DesignSystemPreviewScreen> {
  int _selectedTab = 0;
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ENTRE NOS',
              style: AppTypography.titleLarge.copyWith(letterSpacing: 1.4),
            ),
            Text(
              'Lo que pasa entre nosotros · 30/30',
              style: AppTypography.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.hourglass_bottom_rounded),
            tooltip: 'Cápsulas del tiempo',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Recuerdos',
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg,
        ),
        children: [
          // Tira de Momentos (24h)
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _StoryPreviewItem(
                  name: 'Tú',
                  hasRing: false,
                  isOnline: true,
                ),
                SizedBox(width: AppSpacing.lg),
                _StoryPreviewItem(
                  name: 'Mateo',
                  hasRing: true,
                  seen: false,
                  isOnline: true,
                ),
                SizedBox(width: AppSpacing.lg),
                _StoryPreviewItem(
                  name: 'Camila',
                  hasRing: true,
                  seen: false,
                ),
                SizedBox(width: AppSpacing.lg),
                _StoryPreviewItem(
                  name: 'Diego',
                  hasRing: true,
                  seen: true,
                ),
                SizedBox(width: AppSpacing.lg),
                _StoryPreviewItem(
                  name: 'Valeria',
                  hasRing: true,
                  seen: true,
                ),
              ],
            ),
          ),
          const Divider(height: AppSpacing.xxl),

          // Tarjeta de Cápsula del Tiempo bloqueada
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.blackSecondary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.capsuleAccent.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.capsuleAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.lock_clock_outlined,
                    color: AppColors.capsuleAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CÁPSULA DEL TIEMPO · SELLADA',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.capsuleAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fin de año 2026 — Se abre el 31 Dic',
                        style: AppTypography.titleMedium.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Tarjeta de Publicación del Feed
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.blackSecondary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppAvatar(
                      name: 'Mateo Rivera',
                      size: 40,
                      isOnline: true,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mateo Rivera', style: AppTypography.titleMedium),
                          Text('Hace 18 min · Solo círculo',
                              style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.more_horiz, color: AppColors.gray),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Queda inaugurado nuestro espacio privado. Sin ruido, sin algoritmos y solo entre nosotros.',
                  style: AppTypography.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _liked = !_liked),
                      child: Row(
                        children: [
                          Icon(
                            _liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: _liked ? AppColors.error : AppColors.gray,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _liked ? '14' : '13',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 19,
                          color: AppColors.gray,
                        ),
                        const SizedBox(width: 6),
                        Text('6 comentarios', style: AppTypography.bodySmall),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.bookmark_border_rounded,
                      size: 20,
                      color: AppColors.gray,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Bloque de verificación de controles de formulario
          Text('Componentes Base', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.md),
          const AppTextField(
            label: 'Código de invitación privada',
            hint: 'Ej. EN-8492-X',
            prefixIcon: Icons.vpn_key_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Solicitar acceso al círculo',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sistema visual ENTRE NOS verificado.'),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Acción secundaria',
            variant: AppButtonVariant.secondary,
            onPressed: () {},
          ),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonLoader(width: double.infinity, height: 54),
        ],
      ),
      bottomNavigationBar: _EntreNosBottomNav(
        currentIndex: _selectedTab,
        onTap: (index) => setState(() => _selectedTab = index),
      ),
    );
  }
}

class _StoryPreviewItem extends StatelessWidget {
  final String name;
  final bool hasRing;
  final bool seen;
  final bool isOnline;

  const _StoryPreviewItem({
    required this.name,
    this.hasRing = true,
    this.seen = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAvatar(
          name: name,
          size: 58,
          hasStoryRing: hasRing,
          storySeen: seen,
          isOnline: isOnline,
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: AppTypography.labelSmall.copyWith(
            color: seen ? AppColors.gray : AppColors.white,
          ),
        ),
      ],
    );
  }
}

class _EntreNosBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _EntreNosBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
      (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Momentos'),
      (Icons.add_box_outlined, Icons.add_box_rounded, 'Crear'),
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chat'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.blackPrimary,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (index) {
              final isSelected = currentIndex == index;
              final item = items[index];
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? item.$2 : item.$1,
                        size: 23,
                        color: isSelected ? AppColors.white : AppColors.gray,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$3,
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 10.5,
                          color: isSelected ? AppColors.white : AppColors.gray,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}