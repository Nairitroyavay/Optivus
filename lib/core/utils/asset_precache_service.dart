import 'package:flutter/widgets.dart';

/// Pre-caches splash and cold-boot assets into Flutter's ImageCache to eliminate
/// first-frame rendering jank and asset decoding delays.
class SplashAssetCacheService {
  SplashAssetCacheService._();

  static const List<String> splashAssetPaths = ['assets/images/logo.png'];

  static Future<void> precacheSplashAssets(BuildContext context) async {
    for (final assetPath in splashAssetPaths) {
      try {
        await precacheImage(AssetImage(assetPath), context);
      } catch (error) {
        debugPrint(
          '[SplashAssetCacheService] Asset precache failed safely '
          '(${error.runtimeType}).',
        );
      }
    }
  }
}
