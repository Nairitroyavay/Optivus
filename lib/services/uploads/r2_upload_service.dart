import 'dart:async';
import 'dart:io';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';

abstract class SkinCarePhotoUploadException implements Exception {
  final String message;
  final dynamic originalError;

  const SkinCarePhotoUploadException(this.message, [this.originalError]);

  @override
  String toString() => message;
}

class R2UploadExpiredUrlException extends SkinCarePhotoUploadException {
  const R2UploadExpiredUrlException([
    super.message = 'Upload URL has expired. Please try again.',
    super.originalError,
  ]);
}

class R2UploadNetworkException extends SkinCarePhotoUploadException {
  const R2UploadNetworkException([
    super.message = 'Network connection failed during upload.',
    super.originalError,
  ]);
}

class R2UploadHttpResponseException extends SkinCarePhotoUploadException {
  final int statusCode;

  const R2UploadHttpResponseException(
    this.statusCode, [
    super.message = 'R2 photo upload failed.',
    super.originalError,
  ]);
}

class R2UploadMarkCompleteException extends SkinCarePhotoUploadException {
  const R2UploadMarkCompleteException([
    super.message = 'Failed to confirm upload completion.',
    super.originalError,
  ]);
}

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

    if (signedUpload.expiresAt != null &&
        DateTime.now().isAfter(signedUpload.expiresAt!)) {
      throw const R2UploadExpiredUrlException(
        'Upload URL has expired before starting upload.',
      );
    }

    try {
      await _client.uploadBytes(
        uploadUrl: signedUpload.uploadUrl,
        contentType: image.contentType,
        bytes: image.bytes,
      );
    } on CloudflareClientException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        throw R2UploadExpiredUrlException(
          'Upload authorization expired (${e.statusCode}). Please retry.',
          e,
        );
      }
      throw R2UploadHttpResponseException(
        e.statusCode ?? 500,
        'Photo upload failed: ${e.message}',
        e,
      );
    } on SocketException catch (e) {
      throw R2UploadNetworkException(
        'Network error during photo upload. Please check your connection.',
        e,
      );
    } on TimeoutException catch (e) {
      throw R2UploadNetworkException(
        'Photo upload timed out. Please try again.',
        e,
      );
    } catch (e) {
      if (e is SkinCarePhotoUploadException) rethrow;
      throw R2UploadHttpResponseException(
        500,
        'Unexpected upload error: $e',
        e,
      );
    }

    try {
      await _client.markUploadComplete(
        assetId: signedUpload.assetId,
        objectKey: signedUpload.objectKey,
        sizeBytes: image.sizeBytes,
        idToken: idToken,
      );
    } catch (e) {
      throw R2UploadMarkCompleteException(
        'Could not confirm photo upload completion: $e',
        e,
      );
    }

    return R2UploadedObject(
      assetId: signedUpload.assetId,
      objectKey: signedUpload.objectKey,
    );
  }
}
