import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../models/moment_model.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class MomentsRepository {
  static const String _defaultCircleId =
      '00000000-0000-0000-0000-000000000001';

  final SupabaseClient? _client;
  final StorageService _storageService;

  const MomentsRepository(this._client, this._storageService);

  SupabaseClient get _requireClient {
    final c = _client;
    if (c == null) {
      throw const AuthAppException('Supabase no está configurado.');
    }
    return c;
  }

  Future<List<AuthorMomentGroup>> fetchActiveMomentGroups() async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final nowIso = DateTime.now().toUtc().toIso8601String();

      final rows = await client
          .from('moments')
          .select('''
            id,
            circle_id,
            author_id,
            media_path,
            media_type,
            caption,
            expires_at,
            created_at,
            author:profiles!author_id(id, email, full_name, nickname, bio, avatar_path, avatar_config, created_at),
            moment_views(
              viewer_id,
              viewed_at,
              viewer:profiles!viewer_id(id, email, full_name, nickname, bio, avatar_path, avatar_config, created_at)
            )
          ''')
          .eq('circle_id', _defaultCircleId)
          .gt('expires_at', nowIso)
          .order('created_at', ascending: true);

      final items = (rows as List<dynamic>)
          .map(
            (row) => MomentItem.fromJson(
              row as Map<String, dynamic>,
              currentUserId: uid,
            ),
          )
          .toList();

      final grouped = <String, List<MomentItem>>{};
      for (final item in items) {
        grouped.putIfAbsent(item.authorId, () => []).add(item);
      }

      final groups = grouped.entries.map((entry) {
        return AuthorMomentGroup(
          authorId: entry.key,
          author: entry.value.first.author,
          moments: entry.value,
        );
      }).toList();

      // Poner primero mis propios momentos, luego los no vistos, luego los ya vistos
      groups.sort((a, b) {
        if (a.authorId == uid) return -1;
        if (b.authorId == uid) return 1;
        if (a.allSeen != b.allSeen) return a.allSeen ? 1 : -1;
        return b.moments.last.createdAt.compareTo(a.moments.last.createdAt);
      });

      return groups;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> publishMoment({
    required File imageFile,
    String caption = '',
  }) async {
    String? uploadedPath;
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      uploadedPath = await _storageService.uploadMomentImage(imageFile);

      await client.from('moments').insert({
        'circle_id': _defaultCircleId,
        'author_id': uid,
        'media_path': uploadedPath,
        'media_type': 'image',
        'caption': caption.trim(),
      });
    } catch (e) {
      if (uploadedPath != null) {
        await _storageService.removePostFiles([uploadedPath]);
      }
      throw ErrorMapper.map(e);
    }
  }

  Future<void> markMomentViewed(String momentId) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      await client.from('moment_views').upsert(
        {
          'moment_id': momentId,
          'viewer_id': uid,
          'viewed_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'moment_id,viewer_id',
      );
    } catch (_) {}
  }

  Future<void> deleteMoment(MomentItem moment) async {
    try {
      await _requireClient.from('moments').delete().eq('id', moment.id);
      await _storageService.removePostFiles([moment.mediaPath]);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}

final momentsRepositoryProvider = Provider<MomentsRepository>((ref) {
  return MomentsRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storageServiceProvider),
  );
});