/// Reglas de dominio y límites operativos de ENTRE NOS.
abstract final class AppConstants {
  static const String appName = 'ENTRE NOS';
  static const String appSlogan = 'Lo que pasa entre nosotros';

  /// Límite estricto de integrantes aprobados en el círculo privado
  static const int maxCircleMembers = 30;

  /// Duración de los Momentos (historias temporales) en horas
  static const int storyDurationHours = 24;

  /// Validez de Signed URLs para archivos privados (60 minutos)
  static const int signedUrlTtlSeconds = 3600;

  /// Límites de carga multimedia
  static const int maxPostImages = 6;
  static const int maxImageDimensionPx = 1440;
  static const int imageCompressionQuality = 82;
  static const int maxVideoDurationSeconds = 45;
  static const int maxAudioDurationSeconds = 120;

  /// Paginación del feed y mensajes
  static const int feedPageSize = 15;
  static const int messagesPageSize = 30;
}