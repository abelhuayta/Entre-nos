import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env_config.dart';

/// Expone el cliente oficial de Supabase si las variables de entorno fueron
/// configuradas mediante `--dart-define`.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!EnvConfig.isConfigured) return null;
  return Supabase.instance.client;
});