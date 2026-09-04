import 'package:optivus/models/uploaded_asset.dart';

bool uploadedSourceIdentityMatches({
  required String? assetId,
  required String? r2Key,
  required UploadedAsset asset,
}) {
  final expectedAssetId = asset.assetId.trim();
  final expectedR2Key = asset.r2Key.trim();
  final candidateAssetId = assetId?.trim() ?? '';
  final candidateR2Key = r2Key?.trim() ?? '';
  return expectedAssetId.isNotEmpty &&
      expectedR2Key.isNotEmpty &&
      candidateAssetId.isNotEmpty &&
      candidateR2Key.isNotEmpty &&
      candidateAssetId == expectedAssetId &&
      candidateR2Key == expectedR2Key;
}

bool provenanceContainsExactUploadIdentity(
  Iterable<String> provenanceSourceIds,
  String? assetId,
  String? r2Key,
) {
  final normalizedAssetId = assetId?.trim() ?? '';
  final normalizedR2Key = r2Key?.trim() ?? '';
  if (normalizedAssetId.isEmpty || normalizedR2Key.isEmpty) return false;
  final normalizedProvenance = provenanceSourceIds
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  return normalizedProvenance.contains(normalizedAssetId) &&
      normalizedProvenance.contains(normalizedR2Key);
}
