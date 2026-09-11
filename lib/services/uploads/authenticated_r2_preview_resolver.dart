import 'dart:async';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/state/upload_state.dart';

/// Securely resolves historical R2 object keys to short-lived presigned
/// preview URIs using the authenticated Cloudflare R2 upload worker.
class AuthenticatedR2PreviewResolver implements UploadedAssetPreviewResolver {
  final R2UploadClient _client;
  final Future<String?> Function() _getIdToken;
  final Map<String, (Uri, DateTime)> _cache = {};

  AuthenticatedR2PreviewResolver({
    required R2UploadClient client,
    required Future<String?> Function() getIdToken,
  }) : _client = client,
       _getIdToken = getIdToken;

  @override
  Future<Uri?> resolvePreview({
    required String uid,
    required UploadedAsset asset,
  }) async {
    final r2Key = asset.r2Key.trim();
    if (r2Key.isEmpty) {
      return null;
    }
    return resolveR2Key(uid: uid, r2Key: r2Key);
  }

  Future<Uri?> resolveR2Key({
    required String uid,
    required String r2Key,
  }) async {
    final trimmedKey = r2Key.trim();
    if (trimmedKey.isEmpty) {
      return null;
    }

    // Check cache for a valid unexpired preview URI (cached for 10 minutes max)
    final cached = _cache[trimmedKey];
    if (cached != null) {
      if (DateTime.now().isBefore(cached.$2)) {
        return cached.$1;
      } else {
        _cache.remove(trimmedKey);
      }
    }

    try {
      final token = await _getIdToken();
      if (token == null || token.isEmpty) {
        return null;
      }

      final previewUrlString = await _client.getPreviewUrl(
        objectKey: trimmedKey,
        idToken: token,
      );

      final uri = Uri.tryParse(previewUrlString);
      if (uri != null) {
        // Cache for 10 minutes (presigned URL is valid for 15 minutes)
        _cache[trimmedKey] = (uri, DateTime.now().add(const Duration(minutes: 10)));
        return uri;
      }
    } catch (_) {
      // Truthful fallback: if resolution fails, return null so UI displays
      // the designed source placeholder rather than broken UI.
      return null;
    }
    return null;
  }

  void clearCache() {
    _cache.clear();
  }
}

