/// Configuración de entorno inyectada en tiempo de compilación mediante
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
/// Nunca se almacena la clave `service_role` en el cliente.
abstract final class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}