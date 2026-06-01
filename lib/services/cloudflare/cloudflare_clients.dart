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

abstract class R2UploadClient {
  Future<String> createSignedUploadUrl({
    required String uid,
    required String objectKey,
    required String contentType,
  });

  Future<void> markUploadComplete({
    required String uid,
    required String objectKey,
    required int byteLength,
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

class FakeR2UploadClient implements R2UploadClient {
  @override
  Future<String> createSignedUploadUrl({
    required String uid,
    required String objectKey,
    required String contentType,
  }) async {
    // Future dependency plan: Worker returns a short-lived R2 presigned URL.
    return 'r2://fake-r2/$uid/$objectKey';
  }

  @override
  Future<void> markUploadComplete({
    required String uid,
    required String objectKey,
    required int byteLength,
  }) async {
    // Future dependency plan: Worker writes upload metadata to Firestore.
  }
}
