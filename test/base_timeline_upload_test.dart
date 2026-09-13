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

    test(
      'cleanupStaleUncommittedAssets in Classes context protects committed asset and cleans up stale uncommitted asset',
      () async {
        const uid = 'user-classes-clean';
        final staleTime = DateTime.now().subtract(const Duration(minutes: 20));

        final committed = _makeAsset(
          uid: uid,
          assetId: 'asset-classes-committed',
          purpose: UploadedAssetPurpose.classTimetable,
          updatedAt: staleTime,
        );
        final stale = _makeAsset(
          uid: uid,
          assetId: 'asset-classes-stale',
          purpose: UploadedAssetPurpose.classTimetable,
          updatedAt: staleTime,
        );
        await assetRepo.saveAsset(committed);
        await assetRepo.saveAsset(stale);

        final cleaned = await helper.cleanupStaleUncommittedAssets(
          uid: uid,
          purposes: const {UploadedAssetPurpose.classTimetable},
          committedAssetId: committed.assetId,
          committedR2Key: committed.r2Key,
        );

        expect(cleaned, 1);
        expect(r2Client.deletedKeys, contains(stale.r2Key));
        expect(r2Client.deletedKeys, isNot(contains(committed.r2Key)));

        final committedFetch = await assetRepo.fetchAsset(
          uid: uid,
          assetId: committed.assetId,
        );
        expect(committedFetch?.status, UploadedAssetStatus.uploaded);

        final staleFetch = await assetRepo.fetchAsset(
          uid: uid,
          assetId: stale.assetId,
        );
        expect(staleFetch?.status, UploadedAssetStatus.deleted);
      },
    );

    test(
      'cleanupStaleUncommittedAssets in Work context cleans uncommitted work asset and leaves class asset untouched',
      () async {
        const uid = 'user-work-clean';
        final staleTime = DateTime.now().subtract(const Duration(minutes: 20));

        final classAsset = _makeAsset(
          uid: uid,
          assetId: 'asset-class',
          purpose: UploadedAssetPurpose.classTimetable,
          updatedAt: staleTime,
        );
        final workAsset = _makeAsset(
          uid: uid,
          assetId: 'asset-work',
          purpose: UploadedAssetPurpose.workSchedule,
          updatedAt: staleTime,
        );
        await assetRepo.saveAsset(classAsset);
        await assetRepo.saveAsset(workAsset);

        final cleaned = await helper.cleanupStaleUncommittedAssets(
          uid: uid,
          purposes: const {UploadedAssetPurpose.workSchedule},
        );

        expect(cleaned, 1);
        expect(r2Client.deletedKeys, contains(workAsset.r2Key));
        expect(r2Client.deletedKeys, isNot(contains(classAsset.r2Key)));

        final classFetch = await assetRepo.fetchAsset(
          uid: uid,
          assetId: classAsset.assetId,
        );
        expect(classFetch?.status, UploadedAssetStatus.uploaded);

        final workFetch = await assetRepo.fetchAsset(
          uid: uid,
          assetId: workAsset.assetId,
        );
        expect(workFetch?.status, UploadedAssetStatus.deleted);
      },
    );

    test(
      'cleanupStaleUncommittedAssets in Eating context cleans up uncommitted menu asset',
      () async {
        const uid = 'user-eating-clean';
        final staleTime = DateTime.now().subtract(const Duration(minutes: 20));

        final eatingAsset = _makeAsset(
          uid: uid,
          assetId: 'asset-menu',
          purpose: UploadedAssetPurpose.eatingMenu,
          updatedAt: staleTime,
        );
        await assetRepo.saveAsset(eatingAsset);

        final cleaned = await helper.cleanupStaleUncommittedAssets(
          uid: uid,
          purposes: const {UploadedAssetPurpose.eatingMenu},
        );

        expect(cleaned, 1);
        expect(r2Client.deletedKeys, contains(eatingAsset.r2Key));

        final eatingFetch = await assetRepo.fetchAsset(
          uid: uid,
          assetId: eatingAsset.assetId,
        );
        expect(eatingFetch?.status, UploadedAssetStatus.deleted);
      },
    );

    test(
      'cleanupStaleUncommittedAssets in Skin Care context cleans uncommitted products and face assets while protecting both committed assets',
      () async {
        const uid = 'user-skin-clean';
        final staleTime = DateTime.now().subtract(const Duration(minutes: 20));

        final committedProducts = _makeAsset(
          uid: uid,
          assetId: 'asset-skin-prod-committed',
          purpose: UploadedAssetPurpose.skinProducts,
          updatedAt: staleTime,
        );
        final staleProducts = _makeAsset(
          uid: uid,
          assetId: 'asset-skin-prod-stale',
          purpose: UploadedAssetPurpose.skinProducts,
          updatedAt: staleTime,
        );
        final committedFace = _makeAsset(
          uid: uid,
          assetId: 'asset-skin-face-committed',
          purpose: UploadedAssetPurpose.skinFace,
          updatedAt: staleTime,
        );
        final staleFace = _makeAsset(
          uid: uid,
          assetId: 'asset-skin-face-stale',
          purpose: UploadedAssetPurpose.skinFace,
          updatedAt: staleTime,
        );

        await assetRepo.saveAsset(committedProducts);
        await assetRepo.saveAsset(staleProducts);
        await assetRepo.saveAsset(committedFace);
        await assetRepo.saveAsset(staleFace);

        final cleaned = await helper.cleanupStaleUncommittedAssets(
          uid: uid,
          purposes: const {
            UploadedAssetPurpose.skinProducts,
            UploadedAssetPurpose.skinFace,
          },
          committedAssetIds: {
            committedProducts.assetId,
            committedFace.assetId,
          },
          committedR2Keys: {committedProducts.r2Key, committedFace.r2Key},
        );

        expect(cleaned, 2);
        expect(r2Client.deletedKeys, contains(staleProducts.r2Key));
        expect(r2Client.deletedKeys, contains(staleFace.r2Key));
        expect(r2Client.deletedKeys, isNot(contains(committedProducts.r2Key)));
        expect(r2Client.deletedKeys, isNot(contains(committedFace.r2Key)));

        final fetchCommittedProd = await assetRepo.fetchAsset(
          uid: uid,
          assetId: committedProducts.assetId,
        );
        expect(fetchCommittedProd?.status, UploadedAssetStatus.uploaded);

        final fetchCommittedFace = await assetRepo.fetchAsset(
          uid: uid,
          assetId: committedFace.assetId,
        );
        expect(fetchCommittedFace?.status, UploadedAssetStatus.uploaded);

        final fetchStaleProd = await assetRepo.fetchAsset(
          uid: uid,
          assetId: staleProducts.assetId,
        );
        expect(fetchStaleProd?.status, UploadedAssetStatus.deleted);

        final fetchStaleFace = await assetRepo.fetchAsset(
          uid: uid,
          assetId: staleFace.assetId,
        );
        expect(fetchStaleFace?.status, UploadedAssetStatus.deleted);
      },
    );

    test(
      'cleanupStaleUncommittedAssets evaluates multiple purposes independently without starvation',
      () async {
        const uid = 'user-starvation-test';
        final staleTime = DateTime.now().subtract(const Duration(minutes: 20));

        // Seed 25 items for skinProducts (more than the query limit of 20)
        for (var i = 0; i < 25; i++) {
          final asset = _makeAsset(
            uid: uid,
            assetId: 'asset-prod-$i',
            purpose: UploadedAssetPurpose.skinProducts,
            updatedAt: staleTime.subtract(Duration(minutes: i)),
          );
          await assetRepo.saveAsset(asset);
        }

        // Seed 1 item for skinFace
        final faceAsset = _makeAsset(
          uid: uid,
          assetId: 'asset-face-1',
          purpose: UploadedAssetPurpose.skinFace,
          updatedAt: staleTime,
        );
        await assetRepo.saveAsset(faceAsset);

        // Run cleanup with both purposes
        final cleaned = await helper.cleanupStaleUncommittedAssets(
          uid: uid,
          purposes: const {
            UploadedAssetPurpose.skinProducts,
            UploadedAssetPurpose.skinFace,
          },
        );

        // Both purposes were queried independently: faceAsset must be found and deleted
        expect(r2Client.deletedKeys, contains(faceAsset.r2Key));
        expect(cleaned, 21); // 20 products (query limit) + 1 face
      },
    );

    test(
      'Purpose isolation: Work cleanup leaves uncommitted Class assets untouched',
      () async {
        const uid = 'user-isolation-test';
        final staleTime = DateTime.now().subtract(const Duration(minutes: 20));

        final uncommittedClass = _makeAsset(
          uid: uid,
          assetId: 'uncommitted-class',
          purpose: UploadedAssetPurpose.classTimetable,
          updatedAt: staleTime,
        );
        final uncommittedWork = _makeAsset(
          uid: uid,
          assetId: 'uncommitted-work',
          purpose: UploadedAssetPurpose.workSchedule,
          updatedAt: staleTime,
        );

        await assetRepo.saveAsset(uncommittedClass);
        await assetRepo.saveAsset(uncommittedWork);

        await helper.cleanupStaleUncommittedAssets(
          uid: uid,
          purposes: const {UploadedAssetPurpose.workSchedule},
        );

        // uncommittedWork is deleted
        final workFetch = await assetRepo.fetchAsset(
          uid: uid,
          assetId: uncommittedWork.assetId,
        );
        expect(workFetch?.status, UploadedAssetStatus.deleted);

        // uncommittedClass is untouched
        final classFetch = await assetRepo.fetchAsset(
          uid: uid,
          assetId: uncommittedClass.assetId,
        );
        expect(classFetch?.status, UploadedAssetStatus.uploaded);
        expect(r2Client.deletedKeys, isNot(contains(uncommittedClass.r2Key)));
      },
    );

    test(
      'Active session protection: in-flight upload assets are protected from stale cleanup',
      () async {
        const uid = 'user-active-session';
        final staleTime = DateTime.now().subtract(const Duration(minutes: 20));

        final activeSessionAsset = _makeAsset(
          uid: uid,
          assetId: 'asset-active-session',
          purpose: UploadedAssetPurpose.classTimetable,
          updatedAt: staleTime,
        );
        await assetRepo.saveAsset(activeSessionAsset);

        final cleaned = await helper.cleanupStaleUncommittedAssets(
          uid: uid,
          purposes: const {UploadedAssetPurpose.classTimetable},
          activeSessionAssetIds: {activeSessionAsset.assetId},
          activeSessionR2Keys: {activeSessionAsset.r2Key},
        );

        expect(cleaned, 0);
        expect(r2Client.deletedKeys, isNot(contains(activeSessionAsset.r2Key)));
        final fetch = await assetRepo.fetchAsset(
          uid: uid,
          assetId: activeSessionAsset.assetId,
        );
        expect(fetch?.status, UploadedAssetStatus.uploaded);
      },
    );

    test(
      'Grace window: fresh assets within grace window are protected, older assets are cleaned',
      () async {
        const uid = 'user-grace-window';
        final freshTime = DateTime.now().subtract(const Duration(seconds: 30));
        final staleTime = DateTime.now().subtract(const Duration(minutes: 20));

        final freshAsset = _makeAsset(
          uid: uid,
          assetId: 'asset-fresh',
          purpose: UploadedAssetPurpose.classTimetable,
          updatedAt: freshTime,
        );
        final staleAsset = _makeAsset(
          uid: uid,
          assetId: 'asset-stale',
          purpose: UploadedAssetPurpose.classTimetable,
          updatedAt: staleTime,
        );
        await assetRepo.saveAsset(freshAsset);
        await assetRepo.saveAsset(staleAsset);

        final cleaned = await helper.cleanupStaleUncommittedAssets(
          uid: uid,
          purposes: const {UploadedAssetPurpose.classTimetable},
        );

        expect(cleaned, 1);
        expect(r2Client.deletedKeys, contains(staleAsset.r2Key));
        expect(r2Client.deletedKeys, isNot(contains(freshAsset.r2Key)));

        final freshFetch = await assetRepo.fetchAsset(
          uid: uid,
          assetId: freshAsset.assetId,
        );
        expect(freshFetch?.status, UploadedAssetStatus.uploaded);
      },
    );

    test(
      'Already deleted assets are skipped and not retired again',
      () async {
        const uid = 'user-already-deleted';
        final staleTime = DateTime.now().subtract(const Duration(minutes: 20));

        final deletedAsset = _makeAsset(
          uid: uid,
          assetId: 'asset-already-deleted',
          purpose: UploadedAssetPurpose.classTimetable,
          updatedAt: staleTime,
          status: UploadedAssetStatus.deleted,
        );
        await assetRepo.saveAsset(deletedAsset);

        final cleaned = await helper.cleanupStaleUncommittedAssets(
          uid: uid,
          purposes: const {UploadedAssetPurpose.classTimetable},
        );

        expect(cleaned, 0);
        expect(r2Client.deletedKeys, isEmpty);
      },
    );

    test(
      'Partial failure resilience: R2 deletion failure does not abort cleanup of other assets',
      () async {
        const uid = 'user-partial-failure';
        final staleTime = DateTime.now().subtract(const Duration(minutes: 20));

        final failingAsset = _makeAsset(
          uid: uid,
          assetId: 'asset-fail-r2',
          purpose: UploadedAssetPurpose.classTimetable,
          updatedAt: staleTime,
        );
        final succeedingAsset = _makeAsset(
          uid: uid,
          assetId: 'asset-succeed',
          purpose: UploadedAssetPurpose.classTimetable,
          updatedAt: staleTime,
        );

        await assetRepo.saveAsset(failingAsset);
        await assetRepo.saveAsset(succeedingAsset);

        r2Client.failOnKeys.add(failingAsset.r2Key);

        final cleaned = await helper.cleanupStaleUncommittedAssets(
          uid: uid,
          purposes: const {UploadedAssetPurpose.classTimetable},
        );

        expect(cleaned, 2); // Both were retired (Firestore tombstone succeeded)
        expect(r2Client.deletedKeys, contains(succeedingAsset.r2Key));

        // Firestore tombstone happened for BOTH
        final failingFetch = await assetRepo.fetchAsset(
          uid: uid,
          assetId: failingAsset.assetId,
        );
        expect(failingFetch?.status, UploadedAssetStatus.deleted);

        final succeedingFetch = await assetRepo.fetchAsset(
          uid: uid,
          assetId: succeedingAsset.assetId,
        );
        expect(succeedingFetch?.status, UploadedAssetStatus.deleted);
      },
    );
  });
}

UploadedAsset _makeAsset({
  required String uid,
  required String assetId,
  required UploadedAssetPurpose purpose,
  DateTime? updatedAt,
  UploadedAssetStatus status = UploadedAssetStatus.uploaded,
  String sourceFeature = 'routine_base_timeline',
}) {
  final now = DateTime.now();
  final time = updatedAt ?? now;
  return UploadedAsset(
    assetId: assetId,
    ownerUid: uid,
    sourceFeature: sourceFeature,
    purpose: purpose,
    fileName: '$assetId.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    r2Key: 'users/$uid/$sourceFeature/${purpose.wireName}/$assetId.jpg',
    status: status,
    createdAt: time,
    updatedAt: time,
  );
}

class _TrackingR2UploadClient extends FakeR2UploadClient {
  final List<String> deletedKeys = [];
  final Set<String> failOnKeys = {};

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    if (failOnKeys.contains(objectKey)) {
      throw StateError('Simulated R2 network error on $objectKey');
    }
    deletedKeys.add(objectKey);
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> currentIdToken() async => 'fake-id-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
