import 'package:flutter/material.dart';

/// Paleta oficial de ENTRE NOS ("Obsidian Intimate").
/// Define tokens cromáticos estrictos para garantizar alto contraste,
/// sobriedad editorial y protagonismo absoluto del contenido del círculo.
abstract final class AppColors {
  // Colores base solicitados
  static const Color blackPrimary = Color(0xFF090909);
  static const Color blackSecondary = Color(0xFF171717);
  static const Color white = Color(0xFFF5F5F5);
  static const Color gray = Color(0xFFA3A3A3);
  static const Color divider = Color(0xFF292929);

  // Variaciones tonales de soporte (derivadas de la paleta base)
  static const Color blackElevated = Color(0xFF212121);
  static const Color grayMuted = Color(0xFF6E6E6E);
  static const Color shimmerBase = Color(0xFF171717);
  static const Color shimmerHighlight = Color(0xFF242424);

  // Acentos semánticos mínimos y controlados
  static const Color capsuleAccent = Color(0xFFD4A373);
  static const Color success = Color(0xFF34D399);
  static const Color error = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);

  // Superposiciones translúcidas
  static Color get glassBackground => blackPrimary.withValues(alpha: 0.88);
  static Color get modalBarrier => Colors.black.withValues(alpha: 0.78);
}