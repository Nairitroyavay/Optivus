import 'package:optivus/models/uploaded_asset.dart';

class UploadObjectKeyBuilder {
  const UploadObjectKeyBuilder._();

  static String build({
    required String uid,
    required String sourceFeature,
    required UploadedAssetPurpose purpose,
    required String assetId,
    String contentType = 'image/jpeg',
  }) {
    final safeUid = _safeSegment(uid, fieldName: 'uid');
    final safeSourceFeature = _safeSegment(
      sourceFeature,
      fieldName: 'sourceFeature',
    );
    final safeAssetId = _safeSegment(assetId, fieldName: 'assetId');
    final extension = _extensionForContentType(contentType);
    return 'users/$safeUid/$safeSourceFeature/${purpose.wireName}/$safeAssetId.$extension';
  }

  static String _safeSegment(String value, {required String fieldName}) {
    final trimmed = value.trim();
    final safe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');
    if (!safe.hasMatch(trimmed) ||
        trimmed.contains('..') ||
        trimmed.contains('/') ||
        trimmed.contains(r'\')) {
      throw ArgumentError.value(value, fieldName, 'Unsafe upload path segment');
    }
    return trimmed;
  }

  static String _extensionForContentType(String contentType) {
    final normalized = contentType.split(';').first.trim().toLowerCase();
    return switch (normalized) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }
}
