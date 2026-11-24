import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_exception.dart';

/// Traduce errores técnicos de red, Supabase Auth, PostgreSQL (RLS/RPC)
/// y Storage a mensajes claros y seguros para el usuario.
abstract final class ErrorMapper {
  static AppException map(Object error) {
    if (error is AppException) return error;

    if (error is SocketException || error is TimeoutException) {
      return NetworkAppException(
        'Sin conexión a internet. Verifica tu red e inténtalo de nuevo.',
        originalError: error,
      );
    }

    if (error is AuthException) {
      return _mapAuthException(error);
    }

    if (error is PostgrestException) {
      return _mapPostgrestException(error);
    }

    if (error is StorageException) {
      return StorageAppException(
        'No se pudo procesar el archivo privado. Intenta nuevamente.',
        code: error.statusCode,
        originalError: error,
      );
    }

    return UnknownAppException(
      'Ocurrió un error inesperado. Intenta nuevamente.',
      originalError: error,
    );
  }

  static AuthAppException _mapAuthException(AuthException error) {
    final msg = error.message.toLowerCase();

    if (msg.contains('invalid login credentials')) {
      return AuthAppException(
        'Correo o contraseña incorrectos.',
        code: error.statusCode,
        originalError: error,
      );
    }
    if (msg.contains('user already registered')) {
      return AuthAppException(
        'Este correo ya está registrado en ENTRE NOS.',
        code: error.statusCode,
        originalError: error,
      );
    }
    if (msg.contains('email not confirmed')) {
      return AuthAppException(
        'Debes confirmar tu correo electrónico antes de ingresar.',
        code: error.statusCode,
        originalError: error,
      );
    }
    if (msg.contains('password should be at least')) {
      return AuthAppException(
        'La contraseña debe tener al menos 8 caracteres.',
        code: error.statusCode,
        originalError: error,
      );
    }

    return AuthAppException(
      error.message,
      code: error.statusCode,
      originalError: error,
    );
  }

  static AppException _mapPostgrestException(PostgrestException error) {
    final msg = error.message.toLowerCase();

    if (error.code == '42501' || msg.contains('row-level security')) {
      return PermissionAppException(
        'No tienes autorización para acceder o modificar este contenido.',
        code: error.code,
        originalError: error,
      );
    }
    if (msg.contains('circle_full') || msg.contains('30')) {
      return ValidationAppException(
        'El círculo privado ya alcanzó su límite máximo de 30 integrantes.',
        code: error.code,
        originalError: error,
      );
    }
    if (msg.contains('invalid_invitation')) {
      return ValidationAppException(
        'El código de invitación es inválido, expiró o ya fue utilizado.',
        code: error.code,
        originalError: error,
      );
    }
    if (error.code == '23505') {
      return ValidationAppException(
        'Este registro o nickname ya está en uso dentro del grupo.',
        code: error.code,
        originalError: error,
      );
    }

    return UnknownAppException(
      'Error al sincronizar con el servidor (${error.code ?? 'DB'}).',
      code: error.code,
      originalError: error,
    );
  }
}