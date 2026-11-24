import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Contenedor persistente con las 5 pestañas inferiores de ENTRE NOS:
/// Inicio, Momentos, Crear, Chat y Perfil.
class MainShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({
    super.key,
    required this.navigationShell,
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

    return Scaffold(
      backgroundColor: AppColors.blackPrimary,
      body: navigationShell,
      bottomNavigationBar: Container(
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
                final isSelected = navigationShell.currentIndex == index;
                final item = items[index];
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
                      );
                    },
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
      ),
    );
  }
}