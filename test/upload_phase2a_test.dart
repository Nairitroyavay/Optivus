import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:optivus/config/upload_config.dart';
import 'package:optivus/config/upload_policy.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/services/uploads/upload_object_key.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  test('upload config defaults to fake mode', () {
    expect(OptivusUploadConfig.mode, OptivusUploadMode.fake);
    expect(OptivusUploadConfig.useR2, isFalse);
    expect(OptivusUploadConfig.hasWorkerUrl, isFalse);
  });

  test(
    'UploadedAsset serializes with enum strings and Firestore timestamps',
    () {
      final createdAt = DateTime.utc(2026, 6, 2, 8, 30);
      final updatedAt = DateTime.utc(2026, 6, 2, 8, 31);
      final asset = UploadedAsset(
        assetId: 'asset-1',
        ownerUid: 'uid-1',
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.classTimetable,
        fileName: 'timetable.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 120000,
        r2Key: 'users/uid-1/onboarding/class_timetable/asset-1.jpg',
        localPreviewPath: '/tmp/timetable.jpg',
        status: UploadedAssetStatus.uploaded,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final map = asset.toMap();
      expect(map['purpose'], 'class_timetable');
      expect(map['status'], 'uploaded');

      final fromMap = UploadedAsset.fromMap(map);
      expect(fromMap.assetId, asset.assetId);
      expect(fromMap.purpose, UploadedAssetPurpose.classTimetable);
      expect(fromMap.status, UploadedAssetStatus.uploaded);

      final firestoreMap = asset.toFirestoreMap();
      expect(firestoreMap.containsKey('localPreviewPath'), isFalse);
      expect(firestoreMap['createdAt'], isA<Timestamp>());
      final fromFirestore = UploadedAsset.fromFirestoreMap(firestoreMap);
      expect(fromFirestore.createdAt.toUtc(), createdAt);
      expect(fromFirestore.updatedAt.toUtc(), updatedAt);
      expect(fromFirestore.localPreviewPath, isNull);
    },
  );

  test('uploaded asset Firestore paths stay under user uploads', () {
    expect(
      FirestoreUserPaths.uploadedAsset('uid-1', 'asset-1'),
      'users/uid-1/uploads/asset-1',
    );
    expect(FirestoreUserPaths.uploadedAssets('uid-1'), 'users/uid-1/uploads');
  });

  test('object key builder uses expected onboarding shape', () {
    expect(
      UploadObjectKeyBuilder.build(
        uid: 'uid',
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.classTimetable,
        assetId: 'asset',
      ),
      'users/uid/onboarding/class_timetable/asset.jpg',
    );
  });

  test('object key builder preserves safe image extensions', () {
    expect(
      UploadObjectKeyBuilder.build(
        uid: 'uid',
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.eatingMenu,
        assetId: 'asset',
        contentType: 'image/png',
      ),
      'users/uid/onboarding/eating_menu/asset.png',
    );
    expect(
      UploadObjectKeyBuilder.build(
        uid: 'uid',
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.skinCare,
        assetId: 'asset',
        contentType: 'image/webp',
      ),
      'users/uid/onboarding/skin_care/asset.webp',
    );
  });

  test('object key builder rejects unsafe path segments', () {
    expect(
      UploadObjectKeyBuilder.build(
        uid: 'uid_123',
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.eatingMenu,
        assetId: 'asset-123',
      ),
      'users/uid_123/onboarding/eating_menu/asset-123.jpg',
    );

    expect(
      () => UploadObjectKeyBuilder.build(
        uid: '../uid',
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.eatingMenu,
        assetId: 'asset-123',
      ),
      throwsArgumentError,
    );
    expect(
      () => UploadObjectKeyBuilder.build(
        uid: r'uid\other',
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.eatingMenu,
        assetId: 'asset-123',
      ),
      throwsArgumentError,
    );
    expect(
      () => UploadObjectKeyBuilder.build(
        uid: 'uid',
        sourceFeature: 'onboarding//extra',
        purpose: UploadedAssetPurpose.eatingMenu,
        assetId: 'asset-123',
      ),
      throwsArgumentError,
    );
    expect(
      () => UploadObjectKeyBuilder.build(
        uid: 'uid',
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.eatingMenu,
        assetId: '..',
      ),
      throwsArgumentError,
    );
  });

  test('PendingFutureImportDraft stores uploaded asset references', () {
    final draft = PendingFutureImportDraft(
      id: 'classes_photo_upload',
      section: 'Classes',
      mode: 'Photo Upload',
      createdAt: DateTime.utc(2026, 6, 2),
      uploadedAssetId: 'asset-1',
      uploadedAssetR2Key: 'users/u/onboarding/class_timetable/asset-1.jpg',
      uploadedAssetStatus: 'uploaded',
    );

    final map = draft.toMap();
    expect(map['uploadedAssetId'], 'asset-1');
    expect(map['uploadedAssetR2Key'], contains('class_timetable'));
    expect(map['uploadedAssetStatus'], 'uploaded');

    final fromMap = PendingFutureImportDraft.fromMap(map);
    expect(fromMap.uploadedAssetId, 'asset-1');
    expect(fromMap.uploadedAssetR2Key, contains('class_timetable'));
    expect(fromMap.uploadedAssetStatus, 'uploaded');
  });

  test('PendingFutureImportDraft copyWith supports uploadedAssetId', () {
    final draft = PendingFutureImportDraft(
      id: 'classes_photo_upload',
      section: 'Classes',
      mode: 'Photo Upload',
      createdAt: DateTime.utc(2026, 6, 2),
    );

    final updated = draft.copyWith(
      uploadedAssetId: 'asset-2',
      uploadedAssetR2Key: 'users/u/onboarding/class_timetable/asset-2.jpg',
      uploadedAssetStatus: 'uploaded',
    );

    expect(updated.uploadedAssetId, 'asset-2');
    expect(updated.uploadedAssetR2Key, contains('asset-2.jpg'));
    expect(updated.uploadedAssetStatus, 'uploaded');
  });

  test('image prepare service handles cancelled picker safely', () async {
    final prepared = await ImagePrepareService().preparePickedFile(null);
    expect(prepared, isNull);
  });

  test('upload image policy sets profile and routine limits', () {
    expect(UploadImagePolicy.normal.maxBytes, 5 * 1024 * 1024);
    expect(UploadImagePolicy.routineAiImport.maxBytes, 15 * 1024 * 1024);
    expect(UploadImagePolicy.normal.initialJpegQuality, 95);
    expect(UploadImagePolicy.normal.minJpegQuality, 80);
    expect(UploadImagePolicy.routineAiImport.initialJpegQuality, 100);
    expect(UploadImagePolicy.routineAiImport.minJpegQuality, 88);
  });

  test('upload policy keeps Gemini inline cap below routine upload max', () {
    final wrangler = File(
      'workers/routine-import-worker/wrangler.toml',
    ).readAsStringSync();

    expect(UploadImagePolicy.normal.maxBytes, 5 * 1024 * 1024);
    expect(UploadImagePolicy.routineAiImport.maxBytes, 15 * 1024 * 1024);
    expect(wrangler, contains('GEMINI_INLINE_MAX_IMAGE_BYTES = "11534336"'));
  });

  test(
    'routine import PNG under 15 MB is preserved without recompression',
    () async {
      final bytes = _pngBytes(width: 24, height: 16);
      final prepared = await ImagePrepareService().preparePickedFile(
        XFile.fromData(
          bytes,
          name: 'menu screenshot.png',
          mimeType: 'image/png',
        ),
        purpose: UploadedAssetPurpose.eatingMenu,
      );

      expect(prepared, isNotNull);
      expect(prepared!.contentType, 'image/png');
      expect(prepared.fileName, endsWith('.png'));
      expect(prepared.sizeBytes, bytes.length);
      expect(prepared.bytes, orderedEquals(bytes));
    },
  );

  test('profile JPEG under 5 MB is preserved safely', () async {
    final bytes = _jpegBytes(width: 20, height: 20);
    final prepared = await ImagePrepareService().preparePickedFile(
      XFile.fromData(bytes, name: 'profile.jpeg', mimeType: 'image/jpeg'),
      purpose: UploadedAssetPurpose.profilePhoto,
    );

    expect(prepared, isNotNull);
    expect(prepared!.contentType, 'image/jpeg');
    expect(prepared.sizeBytes, bytes.length);
    expect(prepared.bytes, orderedEquals(bytes));
  });

  test(
    'wide routine import image is resized without cropping aspect ratio',
    () async {
      final bytes = _pngBytes(width: 5000, height: 1000);
      final prepared = await ImagePrepareService().preparePickedFile(
        XFile.fromData(bytes, name: 'wide-menu.png', mimeType: 'image/png'),
        purpose: UploadedAssetPurpose.eatingMenu,
      );

      expect(prepared, isNotNull);
      expect(prepared!.contentType, 'image/jpeg');
      expect(prepared.sizeBytes, lessThanOrEqualTo(15 * 1024 * 1024));
      final decoded = image_lib.decodeImage(prepared.bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 4096);
      expect(decoded.height, closeTo(819, 1));
    },
  );

  test('unsupported routine image type gets friendly message', () async {
    await expectLater(
      ImagePrepareService().preparePickedFile(
        XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'photo.heic',
          mimeType: 'image/heic',
        ),
        purpose: UploadedAssetPurpose.classTimetable,
      ),
      throwsA(
        isA<ImagePreparationException>().having(
          (error) => error.message,
          'message',
          'Please upload JPEG, PNG, or WEBP for now.',
        ),
      ),
    );
  });

  test('R2 worker upload vars keep profile and routine limits separate', () {
    final wrangler = File(
      'workers/r2-upload-worker/wrangler.toml',
    ).readAsStringSync();

    expect(wrangler, contains('MAX_PROFILE_UPLOAD_BYTES = "5242880"'));
    expect(wrangler, contains('MAX_ROUTINE_IMPORT_UPLOAD_BYTES = "15728640"'));
  });

  test('R2 complete verifies object content type when metadata exists', () {
    final worker = File(
      'workers/r2-upload-worker/src/index.ts',
    ).readAsStringSync();

    expect(worker, contains('requiredUploadBucket(env).head(objectKey)'));
    expect(worker, contains('normalizedOptionalContentType'));
    expect(worker, contains('invalid_content_type'));
    expect(
      worker,
      contains('R2 may omit content type metadata for some clients'),
    );
  });

  test(
    'Firestore upload rules allow 5 MB profile and 15 MB routine metadata',
    () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('sizeBytes <= 5242880'));
      expect(rules, contains('sizeBytes <= 15728640'));
      expect(
        rules,
        contains('request.resource.data.ownerUid == request.auth.uid'),
      );
      expect(rules, contains('validUploadKeys(request.resource.data)'));
      expect(rules, contains('"localPreviewPath"'));
      expect(rules, contains('"imageBytes"'));
    },
  );

  test('UploadedAsset invalid status falls back to pending', () {
    expect(
      uploadedAssetStatusFromString('complete'),
      UploadedAssetStatus.pending,
    );
    expect(
      UploadedAsset.fromMap({'status': 'unknown'}).status,
      UploadedAssetStatus.pending,
    );
  });

  test('auth mapper explains email-already-in-use recovery', () {
    expect(
      friendlyAuthError(Exception('email-already-in-use')),
      emailAlreadyInUseMessage,
    );
  });

  test('worker client handles non-json error responses safely', () async {
    final client = RealCloudflareWorkerClient(
      baseUrl: 'https://worker.example',
      client: MockClient((request) async {
        return http.Response('<html>Bad gateway</html>', 502);
      }),
    );

    final response = await client.post(
      const CloudflareWorkerRequest(path: '/health', body: {}),
    );

    expect(response.statusCode, 502);
    expect(
      response.body['message'],
      'Upload service returned an invalid response.',
    );
  });

  test('RealR2UploadClient markUploadComplete throws on 404 and 405', () async {
    for (final statusCode in [404, 405]) {
      final client = RealR2UploadClient(
        workerClient: RealCloudflareWorkerClient(
          baseUrl: 'https://worker.example',
          client: MockClient((request) async {
            return http.Response(
              jsonEncode({'message': 'Complete endpoint unavailable.'}),
              statusCode,
            );
          }),
        ),
      );

      await expectLater(
        client.markUploadComplete(
          assetId: 'asset',
          objectKey: 'users/uid/onboarding/class_timetable/asset.jpg',
          sizeBytes: 100,
          idToken: 'token',
        ),
        throwsA(
          isA<CloudflareClientException>()
              .having((error) => error.statusCode, 'statusCode', statusCode)
              .having(
                (error) => error.message,
                'message',
                'Complete endpoint unavailable.',
              ),
        ),
      );
    }
  });

  test('FakeR2UploadClient deleteUpload succeeds', () async {
    await expectLater(
      FakeR2UploadClient().deleteUpload(
        objectKey: 'users/uid/onboarding/class_timetable/asset.jpg',
        idToken: 'token',
      ),
      completes,
    );
  });

  test('FakeR2UploadClient uses content-type aware object keys', () async {
    final signed = await FakeR2UploadClient().signUpload(
      uid: 'uid',
      purpose: UploadedAssetPurpose.eatingMenu,
      sourceFeature: OnboardingDraft.sourceOnboarding,
      contentType: 'image/png',
      sizeBytes: 100,
      idToken: 'token',
    );

    expect(signed.objectKey, startsWith('users/uid/onboarding/eating_menu/'));
    expect(signed.objectKey, endsWith('.png'));
  });

  test('RealR2UploadClient deleteUpload calls delete endpoint', () async {
    late http.Request recordedRequest;
    final client = RealR2UploadClient(
      workerClient: RealCloudflareWorkerClient(
        baseUrl: 'https://worker.example',
        client: MockClient((request) async {
          recordedRequest = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      ),
    );

    await client.deleteUpload(
      objectKey: 'users/uid/onboarding/class_timetable/asset.jpg',
      idToken: 'token',
    );

    expect(
      recordedRequest.url.toString(),
      'https://worker.example/v1/uploads/delete',
    );
    expect(recordedRequest.headers['authorization'], 'Bearer token');
    expect(jsonDecode(recordedRequest.body), {
      'objectKey': 'users/uid/onboarding/class_timetable/asset.jpg',
    });
  });

  test(
    'UploadController cleans completed R2 object when metadata save fails',
    () async {
      final r2 = _RecordingR2UploadClient();
      final repository = _FailingUploadedAssetRepository();
      final controller = UploadController(
        assetRepository: repository,
        authRepository: _TokenAuthRepository(),
        imagePrepareService: _PreparedImageService(),
        r2UploadClient: r2,
      );

      final asset = await controller.startUpload(
        uid: 'uid-1',
        purpose: UploadedAssetPurpose.classTimetable,
        sourceFeature: OnboardingDraft.sourceOnboarding,
      );

      expect(asset, isNull);
      expect(r2.completed, isTrue);
      expect(
        r2.deletedObjectKey,
        'users/uid-1/onboarding/class_timetable/asset-1.jpg',
      );
      expect(repository.saveAttempts, 1);
      expect(controller.state.status, UploadFlowStatus.failed);
      expect(
        controller.state.errorMessage,
        'Photo upload could not be saved. Please try again.',
      );
      expect(controller.state.asset, isNull);
    },
  );
}

Uint8List _pngBytes({required int width, required int height}) {
  return Uint8List.fromList(
    image_lib.encodePng(image_lib.Image(width: width, height: height)),
  );
}

Uint8List _jpegBytes({required int width, required int height}) {
  return Uint8List.fromList(
    image_lib.encodeJpg(
      image_lib.Image(width: width, height: height),
      quality: 92,
    ),
  );
}

class _TokenAuthRepository implements AuthRepository {
  @override
  Stream<AuthUser?> get authStateChanges => const Stream<AuthUser?>.empty();

  @override
  AuthUser? get currentUser => const AuthUser(
    uid: 'uid-1',
    email: 'test@optivus.dev',
    emailVerified: true,
  );

  @override
  Future<String?> currentIdToken() async => 'token';

  @override
  Future<AuthUser> signInAnonymously() async => currentUser!;

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async => currentUser!;

  @override
  Future<AuthUser?> reloadCurrentUser() async => currentUser;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signIn(String email, String password) async => currentUser!;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signUp(
    String email,
    String password, {
    String? name,
  }) async => currentUser!;
}

class _PreparedImageService extends ImagePrepareService {
  final XFile _file = XFile.fromData(
    Uint8List.fromList([1, 2, 3]),
    name: 'photo.jpg',
    mimeType: 'image/jpeg',
  );

  @override
  Future<XFile?> pickImageFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    return _file;
  }

  @override
  Future<PreparedUploadImage?> preparePickedFile(
    XFile? picked, {
    UploadedAssetPurpose purpose = UploadedAssetPurpose.profilePhoto,
  }) async {
    return PreparedUploadImage(
      fileName: 'photo.jpg',
      contentType: 'image/jpeg',
      bytes: Uint8List.fromList([1, 2, 3]),
      sizeBytes: 3,
    );
  }
}

class _RecordingR2UploadClient implements R2UploadClient {
  bool completed = false;
  String? deletedObjectKey;

  @override
  Future<R2SignedUpload> signUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    required String contentType,
    required int sizeBytes,
    required String idToken,
  }) async {
    return const R2SignedUpload(
      assetId: 'asset-1',
      objectKey: 'users/uid-1/onboarding/class_timetable/asset-1.jpg',
      uploadUrl: 'https://r2.example/upload',
    );
  }

  @override
  Future<void> uploadBytes({
    required String uploadUrl,
    required String contentType,
    required Uint8List bytes,
  }) async {}

  @override
  Future<void> markUploadComplete({
    required String assetId,
    required String objectKey,
    required int sizeBytes,
    required String idToken,
  }) async {
    completed = true;
  }

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    deletedObjectKey = objectKey;
  }
}

class _FailingUploadedAssetRepository implements UploadedAssetRepository {
  int saveAttempts = 0;

  @override
  Future<UploadedAsset?> fetchAsset({
    required String uid,
    required String assetId,
  }) async => null;

  @override
  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 20,
  }) async => const [];

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {}

  @override
  Future<void> saveAsset(UploadedAsset asset) async {
    saveAttempts += 1;
    throw Exception('firestore unavailable');
  }
}
