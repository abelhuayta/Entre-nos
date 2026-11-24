import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../providers/media_provider.dart';

class SignedStorageImage extends ConsumerWidget {
  final String bucket;
  final String storagePath;
  final BoxFit fit;
  final double? width;
  final double? height;

  const SignedStorageImage({
    super.key,
    required this.bucket,
    required this.storagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(
      signedMediaUrlProvider((bucket: bucket, path: storagePath)),
    );

    return urlAsync.when(
      loading: () => SkeletonLoader(
        width: width ?? double.infinity,
        height: height ?? 220,
        borderRadius: 0,
      ),
      error: (error, stackTrace) => Container(
        width: width,
        height: height,
        color: AppColors.blackElevated,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: AppColors.gray,
          size: 28,
        ),
      ),
      data: (signedUrl) => Image.network(
        signedUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SkeletonLoader(
            width: width ?? double.infinity,
            height: height ?? 220,
            borderRadius: 0,
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: AppColors.blackElevated,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: AppColors.gray,
            size: 28,
          ),
        ),
      ),
    );
  }
}