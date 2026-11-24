import 'dart:io';
import 'dart:math';
import 'package:flutter/painting.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import 'supabase_service.dart';

class PendingMediaAttachment {
  final File file;
  final bool isVideo;

  const PendingMediaAttachment({
    required this.file,
    required this.isVideo,
  });
}

class UploadedMediaMetadata {
  final String storagePath;
  final String mediaType;
  final double aspectRatio;
  final int? durationSec;
  final int orderIndex;

  const UploadedMediaMetadata({
    required this.storagePath,
    required this.mediaType,
    required this.aspectRatio,
    this.durationSec,
    required this.orderIndex,
  });
}

class _CachedSignedUrl {
  final String url;
  final DateTime expiresAt;

  const _CachedSignedUrl({
    required this.url,
    required this.expiresAt,
  });

  bool get isValid =>
      DateTime.now().isBefore(expiresAt.subtract(const Duration(minutes: 5)));
}

class StorageService {
  static const String postsMediaBucket = 'posts_media';
  static const String avatarsBucket = 'avatars';
  static const int maxVideoBytes = 45 * 1024 * 1024; // 45 MB

  final SupabaseClient? _client;
  final Map<String, _CachedSignedUrl> _signedUrlCache = {};

  StorageService(this._client);

  SupabaseClient get _requireClient {
    final c = _client;
    if (c == null) {
      throw const AuthAppException('Supabase no está configurado.');
    }
    return c;
  }

  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 3600,
  }) async {
    final cacheKey = '$bucket::$path';
    final cached = _signedUrlCache[cacheKey];
    if (cached != null && cached.isValid) {
      return cached.url;
    }

    try {
      final signedUrl = await _requireClient.storage
          .from(bucket)
          .createSignedUrl(path, expiresInSeconds);

      _signedUrlCache[cacheKey] = _CachedSignedUrl(
        url: signedUrl,
        expiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
      );
      return signedUrl;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<UploadedMediaMetadata> uploadPostMedia({
    required String postId,
    required PendingMediaAttachment attachment,
    required int orderIndex,
  }) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final token = _randomToken();

      if (attachment.isVideo) {
        final sizeBytes = await attachment.file.length();
        if (sizeBytes > maxVideoBytes) {
          throw const ValidationAppException(
            'El video supera el límite de 45 MB.',
          );
        }

        final videoInfo = await _inspectVideo(attachment.file);
        final ext = p.extension(attachment.file.path).toLowerCase();
        final safeExt = ext.isNotEmpty ? ext : '.mp4';
        final storagePath = '$uid/$postId/${orderIndex}_$token$safeExt';

        await client.storage.from(postsMediaBucket).upload(
              storagePath,
              attachment.file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );

        return UploadedMediaMetadata(
          storagePath: storagePath,
          mediaType: 'video',
          aspectRatio: videoInfo.aspectRatio,
          durationSec: videoInfo.durationSec,
          orderIndex: orderIndex,
        );
      } else {
        final compressedFile = await _compressImage(
          attachment.file,
          minWidth: 1440,
          minHeight: 1440,
          quality: 82,
        );
        final aspectRatio = await _inspectImageAspectRatio(compressedFile);
        final storagePath = '$uid/$postId/${orderIndex}_$token.jpg';

        await client.storage.from(postsMediaBucket).upload(
              storagePath,
              compressedFile,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
                upsert: false,
              ),
            );

        return UploadedMediaMetadata(
          storagePath: storagePath,
          mediaType: 'image',
          aspectRatio: aspectRatio,
          orderIndex: orderIndex,
        );
      }
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<String> uploadMomentImage(File imageFile) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final compressed = await _compressImage(
        imageFile,
        minWidth: 1080,
        minHeight: 1920,
        quality: 84,
      );

      final storagePath =
          '$uid/moments/${DateTime.now().millisecondsSinceEpoch}_${_randomToken()}.jpg';

      await client.storage.from(postsMediaBucket).upload(
            storagePath,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
              upsert: false,
            ),
          );

      return storagePath;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<String> uploadChatImage({
    required String conversationId,
    required File imageFile,
  }) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final compressed = await _compressImage(
        imageFile,
        minWidth: 1280,
        minHeight: 1280,
        quality: 80,
      );

      final storagePath =
          '$uid/chat/$conversationId/${DateTime.now().millisecondsSinceEpoch}_${_randomToken()}.jpg';

      await client.storage.from(postsMediaBucket).upload(
            storagePath,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
              upsert: false,
            ),
          );

      return storagePath;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<String> uploadAndSaveAvatar(File imageFile) async {
    try {
      final client = _requireClient;
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthAppException('Sesión no iniciada.');
      }

      final compressed = await _compressImage(
        imageFile,
        minWidth: 600,
        minHeight: 600,
        quality: 85,
      );

      final storagePath =
          '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage.from(avatarsBucket).upload(
            storagePath,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
              upsert: true,
            ),
          );

      await client
          .from('profiles')
          .update({'avatar_path': storagePath}).eq('id', uid);

      return storagePath;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> removePostFiles(List<String> storagePaths) async {
    if (storagePaths.isEmpty) return;
    try {
      await _requireClient.storage.from(postsMediaBucket).remove(storagePaths);
    } catch (_) {}
  }

  Future<File> _compressImage(
    File source, {
    required int minWidth,
    required int minHeight,
    required int quality,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outPath = p.join(
      tempDir.path,
      'en_cmp_${DateTime.now().microsecondsSinceEpoch}_${_randomToken()}.jpg',
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      outPath,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );

    if (result == null) return source;
    return File(result.path);
  }

  Future<double> _inspectImageAspectRatio(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      if (decoded.height == 0) return 0.8;
      final ratio = decoded.width / decoded.height;
      return ratio.clamp(0.56, 1.91);
    } catch (_) {
      return 0.8;
    }
  }

  Future<({double aspectRatio, int durationSec})> _inspectVideo(
    File videoFile,
  ) async {
    final controller = VideoPlayerController.file(videoFile);
    try {
      await controller.initialize();
      final size = controller.value.size;
      final ratio = (size.width > 0 && size.height > 0)
          ? (size.width / size.height).clamp(0.56, 1.91)
          : 0.8;
      final durationSec = controller.value.duration.inSeconds;
      return (aspectRatio: ratio, durationSec: durationSec);
    } catch (_) {
      return (aspectRatio: 0.8, durationSec: 0);
    } finally {
      await controller.dispose();
    }
  }

  String _randomToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(supabaseClientProvider));
});