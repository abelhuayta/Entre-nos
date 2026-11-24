import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Contenedor base para las pantallas de ENTRE NOS.
/// Gestiona el cierre automático del teclado al tocar fuera de inputs
/// y áreas seguras (SafeArea).
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry? padding;
  final bool useSafeArea;
  final bool dismissKeyboardOnTap;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.padding,
    this.useSafeArea = true,
    this.dismissKeyboardOnTap = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    final scaffold = Scaffold(
      backgroundColor: AppColors.blackPrimary,
      appBar: appBar,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );

    if (!dismissKeyboardOnTap) return scaffold;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: scaffold,
    );
  }
}