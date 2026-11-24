/// Jerarquía tipada de excepciones de dominio para ENTRE NOS.
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException($code): $message';
}

final class AuthAppException extends AppException {
  const AuthAppException(super.message, {super.code, super.originalError});
}

final class NetworkAppException extends AppException {
  const NetworkAppException(super.message, {super.code, super.originalError});
}

final class PermissionAppException extends AppException {
  const PermissionAppException(super.message, {super.code, super.originalError});
}

final class StorageAppException extends AppException {
  const StorageAppException(super.message, {super.code, super.originalError});
}

final class ValidationAppException extends AppException {
  const ValidationAppException(super.message, {super.code, super.originalError});
}

final class UnknownAppException extends AppException {
  const UnknownAppException(super.message, {super.code, super.originalError});
}