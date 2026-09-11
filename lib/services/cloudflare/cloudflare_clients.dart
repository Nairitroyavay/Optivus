import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:optivus/config/upload_config.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/uploads/upload_object_key.dart';

class CloudflareWorkerRequest {
  final String path;
  final Map<String, dynamic> body;
  final Map<String, String> headers;

  const CloudflareWorkerRequest({
    required this.path,
    required this.body,
    this.headers = const {},
  });
}

class CloudflareWorkerResponse {
  final int statusCode;
  final Map<String, dynamic> body;

  const CloudflareWorkerResponse({
    required this.statusCode,
    required this.body,
  });
}

abstract class CloudflareWorkerClient {
  Future<CloudflareWorkerResponse> post(CloudflareWorkerRequest request);
}

class CloudflareClientException implements Exception {
  final String message;
  final int? statusCode;

  const CloudflareClientException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class R2SignedUpload {
  final String assetId;
  final String objectKey;
  final String uploadUrl;
  final DateTime? expiresAt;

  const R2SignedUpload({
    required this.assetId,
    required this.objectKey,
    required this.uploadUrl,
    this.expiresAt,
  });
}

abstract class R2UploadClient {
  Future<R2SignedUpload> signUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    required String contentType,
    required int sizeBytes,
    required String idToken,
  });

  Future<void> uploadBytes({
    required String uploadUrl,
    required String contentType,
    required Uint8List bytes,
  });

  Future<void> markUploadComplete({
    required String assetId,
    required String objectKey,
    required int sizeBytes,
    required String idToken,
  });

  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  });

  Future<String> getPreviewUrl({
    required String objectKey,
    required String idToken,
  });
}

class FakeCloudflareWorkerClient implements CloudflareWorkerClient {
  @override
  Future<CloudflareWorkerResponse> post(CloudflareWorkerRequest request) async {
    // Future dependency plan: use http or dio to call the configured Worker.
    return const CloudflareWorkerResponse(
      statusCode: 200,
      body: {'mode': 'fake-worker'},
    );
  }
}

class RealCloudflareWorkerClient implements CloudflareWorkerClient {
  final String baseUrl;
  final http.Client _client;

  RealCloudflareWorkerClient({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? OptivusUploadConfig.workerBaseUrl,
      _client = client ?? http.Client();

  @override
  Future<CloudflareWorkerResponse> post(CloudflareWorkerRequest request) async {
    final uri = _workerUri(request.path);
    final response = await _client.post(
      uri,
      headers: {
        'content-type': 'application/json',
        'accept': 'application/json',
        ...request.headers,
      },
      body: jsonEncode(request.body),
    );

    final body = _jsonObject(response.body);
    return CloudflareWorkerResponse(
      statusCode: response.statusCode,
      body: body,
    );
  }

  Uri _workerUri(String path) {
    final trimmedBase = baseUrl.trim();
    if (trimmedBase.isEmpty) {
      throw const CloudflareClientException(
        'Cloudflare R2 upload worker is not configured.',
      );
    }
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(
      '${trimmedBase.replaceFirst(RegExp(r'/+$'), '')}/$normalizedPath',
    );
  }

  Map<String, dynamic> _jsonObject(String source) {
    if (source.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'value': decoded};
    } on FormatException {
      return const {'message': 'Upload service returned an invalid response.'};
    }
  }
}

class FakeR2UploadClient implements R2UploadClient {
  @override
  Future<R2SignedUpload> signUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    required String contentType,
    required int sizeBytes,
    required String idToken,
  }) async {
    final assetId = 'fake-upload-${DateTime.now().microsecondsSinceEpoch}';
    final objectKey = UploadObjectKeyBuilder.build(
      uid: uid,
      sourceFeature: sourceFeature,
      purpose: purpose,
      assetId: assetId,
      contentType: contentType,
    );
    return R2SignedUpload(
      assetId: assetId,
      objectKey: objectKey,
      uploadUrl: 'r2://fake-r2/$objectKey',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  @override
  Future<void> uploadBytes({
    required String uploadUrl,
    required String contentType,
    required Uint8List bytes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> markUploadComplete({
    required String assetId,
    required String objectKey,
    required int sizeBytes,
    required String idToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  @override
  Future<String> getPreviewUrl({
    required String objectKey,
    required String idToken,
  }) async {
    return 'https://preview.local/$objectKey';
  }
}

class RealR2UploadClient implements R2UploadClient {
  final CloudflareWorkerClient _workerClient;
  final http.Client _uploadClient;

  RealR2UploadClient({
    CloudflareWorkerClient? workerClient,
    http.Client? uploadClient,
  }) : _workerClient = workerClient ?? RealCloudflareWorkerClient(),
       _uploadClient = uploadClient ?? http.Client();

  @override
  Future<R2SignedUpload> signUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    required String contentType,
    required int sizeBytes,
    required String idToken,
  }) async {
    final response = await _workerClient.post(
      CloudflareWorkerRequest(
        path: '/v1/uploads/sign',
        headers: {'authorization': 'Bearer $idToken'},
        body: {
          'purpose': purpose.wireName,
          'sourceFeature': sourceFeature,
          'contentType': contentType,
          'sizeBytes': sizeBytes,
        },
      ),
    );
    _throwIfWorkerFailed(response, 'Could not prepare the R2 upload.');
    final uploadUrl = response.body['uploadUrl'] as String?;
    final assetId = response.body['assetId'] as String?;
    final objectKey =
        response.body['objectKey'] as String? ??
        response.body['r2Key'] as String?;
    if (uploadUrl == null || assetId == null || objectKey == null) {
      throw const CloudflareClientException(
        'The upload worker returned an incomplete signed upload response.',
      );
    }
    return R2SignedUpload(
      assetId: assetId,
      objectKey: objectKey,
      uploadUrl: uploadUrl,
      expiresAt: DateTime.tryParse(response.body['expiresAt'] as String? ?? ''),
    );
  }

  @override
  Future<void> uploadBytes({
    required String uploadUrl,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final response = await _uploadClient.put(
      Uri.parse(uploadUrl),
      headers: {'content-type': contentType},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudflareClientException(
        'R2 upload failed. Please try again.',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> markUploadComplete({
    required String assetId,
    required String objectKey,
    required int sizeBytes,
    required String idToken,
  }) async {
    final response = await _workerClient.post(
      CloudflareWorkerRequest(
        path: '/v1/uploads/complete',
        headers: {'authorization': 'Bearer $idToken'},
        body: {
          'assetId': assetId,
          'objectKey': objectKey,
          'sizeBytes': sizeBytes,
        },
      ),
    );
    _throwIfWorkerFailed(response, 'Could not confirm the R2 upload.');
  }

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    final response = await _workerClient.post(
      CloudflareWorkerRequest(
        path: '/v1/uploads/delete',
        headers: {'authorization': 'Bearer $idToken'},
        body: {'objectKey': objectKey},
      ),
    );
    _throwIfWorkerFailed(response, 'Could not delete the uploaded photo.');
  }

  @override
  Future<String> getPreviewUrl({
    required String objectKey,
    required String idToken,
  }) async {
    final response = await _workerClient.post(
      CloudflareWorkerRequest(
        path: '/v1/uploads/preview',
        headers: {'authorization': 'Bearer $idToken'},
        body: {'objectKey': objectKey},
      ),
    );
    _throwIfWorkerFailed(response, 'Could not load the photo preview.');
    final previewUrl = response.body['previewUrl'] as String?;
    if (previewUrl == null || previewUrl.isEmpty) {
      throw const CloudflareClientException('Missing preview URL in response.');
    }
    return previewUrl;
  }

  void _throwIfWorkerFailed(
    CloudflareWorkerResponse response,
    String fallbackMessage,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw CloudflareClientException(
      response.body['message'] as String? ??
          response.body['error'] as String? ??
          fallbackMessage,
      statusCode: response.statusCode,
    );
  }
}
