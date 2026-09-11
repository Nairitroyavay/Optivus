import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  group('Base Timeline Upload Lifecycle and Security Tests', () {
    late FakeUploadedAssetRepository assetRepo;
    late _TrackingR2UploadClient r2Client;
    late _FakeAuthRepository authRepo;
    late BaseTimelineUploadLifecycleHelper helper;

    setUp(() {
      assetRepo = FakeUploadedAssetRepository();
      r2Client = _TrackingR2UploadClient();
      authRepo = _FakeAuthRepository();
      helper = BaseTimelineUploadLifecycleHelper(
        assetRepository: assetRepo,
        r2UploadClient: r2Client,
        authRepository: authRepo,
      );
    });

    test(
      'retireUncommittedUpload deletes R2 object and marks asset deleted',
      () async {
        const uid = 'user-upload-1';
        const assetId = 'asset-uncommitted-1';
        const objectKey =
            'users/user-upload-1/routine_base_timeline/class_timetable/test.jpg';

        final asset = UploadedAsset(
          assetId: assetId,
          ownerUid: uid,
          sourceFeature: 'routine_base_timeline',
          purpose: UploadedAssetPurpose.classTimetable,
          fileName: 'test.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          r2Key: objectKey,
          status: UploadedAssetStatus.uploaded,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await assetRepo.saveAsset(asset);

        await helper.retireUncommittedUpload(
          uid: uid,
          assetId: assetId,
          objectKey: objectKey,
        );

        // Verify R2 deletion was called with the key
        expect(r2Client.deletedKeys, contains(objectKey));

        // Verify Firestore asset was marked deleted
        final saved = await assetRepo.fetchAsset(uid: uid, assetId: assetId);
        expect(saved?.status, UploadedAssetStatus.deleted);
      },
    );

    test('retireReplacedAsset cleans up replaced asset on commit', () async {
      const uid = 'user-upload-replace';
      const oldAssetId = 'asset-old';
      const oldObjectKey =
          'users/user-upload-replace/routine_base_timeline/eating_menu/old.jpg';

      final asset = UploadedAsset(
        assetId: oldAssetId,
        ownerUid: uid,
        sourceFeature: 'routine_base_timeline',
        purpose: UploadedAssetPurpose.eatingMenu,
        fileName: 'old.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 2048,
        r2Key: oldObjectKey,
        status: UploadedAssetStatus.uploaded,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await assetRepo.saveAsset(asset);

      await helper.retireReplacedAsset(
        uid: uid,
        oldAssetId: oldAssetId,
        oldObjectKey: oldObjectKey,
      );

      expect(r2Client.deletedKeys, contains(oldObjectKey));
      final saved = await assetRepo.fetchAsset(uid: uid, assetId: oldAssetId);
      expect(saved?.status, UploadedAssetStatus.deleted);
    });

    test(
      'Upload contract validation strictly requires explicit expectedSourceFeature',
      () {
        const uid = 'user-validation-1';
        final now = DateTime.now();

        // Base Timeline asset
        final baseTimelineAsset = UploadedAsset(
          assetId: 'asset-bt-1',
          ownerUid: uid,
          sourceFeature: 'routine_base_timeline',
          purpose: UploadedAssetPurpose.classTimetable,
          fileName: 'table.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 5000,
          r2Key:
              'users/$uid/routine_base_timeline/class_timetable/asset-bt-1.jpg',
          status: UploadedAssetStatus.uploaded,
          createdAt: now,
          updatedAt: now,
        );

        // When validating with routineBaseTimeline, passes
        final isValidForBaseTimeline = uploadedAssetIsDurablyUploadedForSlot(
          asset: baseTimelineAsset,
          uid: uid,
          expectedSourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: UploadedAssetPurpose.classTimetable,
        );
        expect(isValidForBaseTimeline, isTrue);

        // When validating with onboarding, strictly rejected!
        final isRejectedForOnboarding = uploadedAssetIsDurablyUploadedForSlot(
          asset: baseTimelineAsset,
          uid: uid,
          expectedSourceFeature: UploadSourceFeature.onboarding,
          purpose: UploadedAssetPurpose.classTimetable,
        );
        expect(isRejectedForOnboarding, isFalse);

        // When uid mismatches, strictly rejected!
        final isRejectedForWrongUid = uploadedAssetIsDurablyUploadedForSlot(
          asset: baseTimelineAsset,
          uid: 'wrong-user',
          expectedSourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: UploadedAssetPurpose.classTimetable,
        );
        expect(isRejectedForWrongUid, isFalse);
      },
    );
  });
}

class _TrackingR2UploadClient extends FakeR2UploadClient {
  final List<String> deletedKeys = [];

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    deletedKeys.add(objectKey);
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> currentIdToken() async => 'fake-id-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
