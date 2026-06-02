import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optivus/config/upload_config.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/services/uploads/upload_object_key.dart';

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
      expect(firestoreMap['createdAt'], isA<Timestamp>());
      final fromFirestore = UploadedAsset.fromFirestoreMap(firestoreMap);
      expect(fromFirestore.createdAt.toUtc(), createdAt);
      expect(fromFirestore.updatedAt.toUtc(), updatedAt);
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

  test('image prepare service handles cancelled picker safely', () async {
    final prepared = await ImagePrepareService().preparePickedFile(null);
    expect(prepared, isNull);
  });

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
}
