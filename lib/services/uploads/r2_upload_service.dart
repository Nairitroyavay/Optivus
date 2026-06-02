import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';

class R2UploadedObject {
  final String assetId;
  final String objectKey;

  const R2UploadedObject({required this.assetId, required this.objectKey});
}

class R2UploadService {
  final R2UploadClient _client;

  const R2UploadService(this._client);

  Future<R2UploadedObject> uploadPreparedImage({
    required String uid,
    required String idToken,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    required PreparedUploadImage image,
  }) async {
    final signedUpload = await _client.signUpload(
      uid: uid,
      purpose: purpose,
      sourceFeature: sourceFeature,
      contentType: image.contentType,
      sizeBytes: image.sizeBytes,
      idToken: idToken,
    );
    await _client.uploadBytes(
      uploadUrl: signedUpload.uploadUrl,
      contentType: image.contentType,
      bytes: image.bytes,
    );
    await _client.markUploadComplete(
      assetId: signedUpload.assetId,
      objectKey: signedUpload.objectKey,
      sizeBytes: image.sizeBytes,
      idToken: idToken,
    );
    return R2UploadedObject(
      assetId: signedUpload.assetId,
      objectKey: signedUpload.objectKey,
    );
  }
}
