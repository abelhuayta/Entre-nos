import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../models/capsule_model.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class CapsulesRepository {
  static const String _defaultCircleId =
      '00000000-0000-0000-0000-000000000001';

  final SupabaseClient? _client;
  final StorageService _storageService;

  const CapsulesRepository(this._client, this._storageService);

  SupabaseClient get _requireClient {
    final c = _client;
    if (c == null) {
      throw const AuthAppException('Supabase no está configurado.');
    }
    return c;
  }

  Future<List<TimeCapsuleItem>> fetchCapsules() async {
    try {
      final rows = await _requireClient.rpc(
        'get_circle_capsules',
        params: {'p_circle_id': _defaultCircleId},
      );

      return (rows as List<dynamic>)
          .map((row) => TimeCapsuleItem.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> createCapsule({
    required String title,
    required String message,
    required DateTime unlockAt,
    File? imageFile,
  }) async {
    String? uploadedPath;
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      if (title.trim().isEmpty || message.trim().isEmpty) {
        throw const ValidationAppException(
          'Completa el título y el mensaje para el futuro.',
        );
      }

      if (imageFile != null) {
        uploadedPath = await _storageService.uploadMomentImage(imageFile);
      }

      await client.from('capsules').insert({
        'circle_id': _defaultCircleId,
        'creator_id': uid,
        'title': title.trim(),
        'message': message.trim(),
        'media_path': uploadedPath,
        'media_type': uploadedPath != null ? 'image' : null,
        'visibility': 'circle',
        'unlock_at': unlockAt.toUtc().toIso8601String(),
      });
    } catch (e) {
      if (uploadedPath != null) {
        await _storageService.removePostFiles([uploadedPath]);
      }
      throw ErrorMapper.map(e);
    }
  }
}

final capsulesRepositoryProvider = Provider<CapsulesRepository>((ref) {
  return CapsulesRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storageServiceProvider),
  );
});