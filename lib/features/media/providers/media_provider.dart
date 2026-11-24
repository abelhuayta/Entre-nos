import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/storage_service.dart';

typedef SignedMediaKey = ({String bucket, String path});

final signedMediaUrlProvider =
    FutureProvider.family<String, SignedMediaKey>((ref, key) async {
  return await ref.read(storageServiceProvider).getSignedUrl(
        bucket: key.bucket,
        path: key.path,
      );
});