import 'package:intl/intl.dart';

/// Utilidades de formato de fecha y tiempo relativo en español.
abstract final class DateFormatter {
  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 45) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';

    return DateFormat('d MMM yyyy', 'es').format(dateTime.toLocal());
  }

  static String chatTimestamp(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final isSameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    if (isSameDay) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('d MMM, HH:mm', 'es').format(local);
  }

  static String capsuleCountdown(DateTime unlockAt) {
    final diff = unlockAt.difference(DateTime.now());
    if (diff.isNegative) return 'Disponible para abrir';

    if (diff.inDays >= 1) {
      final days = diff.inDays;
      return days == 1 ? 'Falta 1 día' : 'Faltan $days días';
    }
    if (diff.inHours >= 1) {
      final hours = diff.inHours;
      return hours == 1 ? 'Falta 1 hora' : 'Faltan $hours horas';
    }
    final mins = diff.inMinutes.clamp(1, 59);
    return 'Faltan $mins min';
  }
}