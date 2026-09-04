import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/services/onboarding_completion_service.dart';

void main() {
  group('Step 7 P0 Remediation - Migration & Completion Contracts', () {
    const testUid = 'test-uid';

    OnboardingDraft buildLegacyDraft({
      required String path,
      UploadedAsset? sharedAsset,
    }) {
      return OnboardingDraft(
        uid: testUid,
        revision: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        badHabits: [],
        baseTimeline: BaseTimelineDraft(
          skinCareSetupPath: path,
          skinCareProductPhotoAssetId: sharedAsset?.assetId,
          skinCareProductPhotoR2Key: sharedAsset?.r2Key,
          skinCareProductPhotoStatus: sharedAsset?.status.name,
          skinCareProductPhotoCreatedAt: sharedAsset?.createdAt,
          skinCareProductPhotoUpdatedAt: sharedAsset?.updatedAt,
        ),
      );
    }

    test('Migration executed twice -> same result (Idempotency)', () {
      final now = DateTime.now();
      final legacyAsset = UploadedAsset(
        assetId: 'legacy-asset-123',
        ownerUid: testUid,
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.skinCare,
        fileName: 'test.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1000,
        r2Key: 'users/$testUid/onboarding/skin_care/legacy-asset-123.jpg',
        status: UploadedAssetStatus.uploaded,
        createdAt: now,
        updatedAt: now,
      );

      final draft = buildLegacyDraft(
        path: 'has_products',
        sharedAsset: legacyAsset,
      );

      final productsAsset = durableSkinProductsAssetFromDraft(draft);
      final faceAsset = durableSkinFaceAssetFromDraft(draft);

      expect(productsAsset, isNotNull);
      expect(productsAsset?.assetId, 'legacy-asset-123');
      expect(faceAsset, isNull);

      final updatedDraft = draft.copyWith(
        baseTimeline: draft.baseTimeline.copyWith(
          skinCareProductPhotoAssetId: productsAsset?.assetId,
          skinCareProductPhotoR2Key: productsAsset?.r2Key,
          skinCareProductPhotoStatus: productsAsset?.status.name,
          skinCareProductPhotoCreatedAt: productsAsset?.createdAt,
          skinCareProductPhotoUpdatedAt: productsAsset?.updatedAt,
        ),
      );

      final productsAsset2 = durableSkinProductsAssetFromDraft(updatedDraft);
      final faceAsset2 = durableSkinFaceAssetFromDraft(updatedDraft);

      expect(productsAsset2?.assetId, 'legacy-asset-123');
      expect(faceAsset2, isNull);
    });

    test('Never copy one legacy asset into both slots', () {
      final now = DateTime.now();
      final legacyAsset = UploadedAsset(
        assetId: 'legacy-asset-456',
        ownerUid: testUid,
        sourceFeature: 'onboarding',
        purpose: UploadedAssetPurpose.skinCare,
        fileName: 'test.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1000,
        r2Key: 'users/$testUid/onboarding/skin_care/legacy-asset-456.jpg',
        status: UploadedAssetStatus.uploaded,
        createdAt: now,
        updatedAt: now,
      );

      final faceDraft = buildLegacyDraft(
        path: 'no_products',
        sharedAsset: legacyAsset,
      );
      final faceMigratedFace = durableSkinFaceAssetFromDraft(faceDraft);
      final faceMigratedProducts = durableSkinProductsAssetFromDraft(faceDraft);

      expect(faceMigratedFace?.assetId, 'legacy-asset-456');
      expect(faceMigratedProducts, isNull);

      final skipDraft = buildLegacyDraft(
        path: 'skip',
        sharedAsset: legacyAsset,
      );
      final skipMigratedFace = durableSkinFaceAssetFromDraft(skipDraft);
      final skipMigratedProducts = durableSkinProductsAssetFromDraft(skipDraft);

      expect(skipMigratedFace, isNull);
      expect(skipMigratedProducts, isNull);
    });

    test('current skin slot identity is exact and fail-closed', () {
      bool valid({
        String assetId = 'skin-1',
        String ownerUid = testUid,
        UploadedAssetPurpose purpose = UploadedAssetPurpose.skinProducts,
        String? r2Key,
        UploadedAssetStatus status = UploadedAssetStatus.uploaded,
      }) {
        return uploadedAssetFieldsAreDurablyUploadedForSlot(
          assetId: assetId,
          ownerUid: ownerUid,
          sourceFeature: OnboardingDraft.sourceOnboarding,
          purpose: purpose,
          r2Key:
              r2Key ??
              'users/$testUid/onboarding/${purpose.wireName}/$assetId.jpg',
          status: status,
          uid: testUid,
          expectedPurpose: UploadedAssetPurpose.skinProducts,
        );
      }

      expect(valid(), isTrue);
      expect(valid(ownerUid: 'another-user'), isFalse);
      expect(valid(purpose: UploadedAssetPurpose.skinFace), isFalse);
      expect(
        valid(
          r2Key: 'users/$testUid/onboarding/skin_products/different-asset.jpg',
        ),
        isFalse,
      );
      for (final status in const [
        UploadedAssetStatus.pending,
        UploadedAssetStatus.failed,
        UploadedAssetStatus.deleted,
      ]) {
        expect(valid(status: status), isFalse);
      }

      expect(
        uploadedAssetFieldsAreDurablyUploadedForSlot(
          assetId: 'face-1',
          ownerUid: testUid,
          sourceFeature: OnboardingDraft.sourceOnboarding,
          purpose: UploadedAssetPurpose.skinFace,
          r2Key: 'users/$testUid/onboarding/skin_face/face-1.webp',
          status: UploadedAssetStatus.uploaded,
          uid: testUid,
          expectedPurpose: UploadedAssetPurpose.skinFace,
        ),
        isTrue,
      );
    });

    test(
      'Completion projection exactly consumes face slot for no_products, and product slot for has_products',
      () {
        final now = DateTime.now();
        var fullDraft = OnboardingDraft(
          uid: testUid,
          revision: 1,
          sourceFingerprint:
              'abcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcd',
          baseTimeline: BaseTimelineDraft(
            skinCareSetupPath: 'no_products',
            skinCareFacePhotoAssetId: 'face-asset',
            skinCareFacePhotoR2Key:
                'users/$testUid/onboarding/skin_face/face-asset.jpg',
            skinCareFacePhotoStatus: 'uploaded',
            skinCareFacePhotoCreatedAt: now,
            skinCareFacePhotoUpdatedAt: now,

            skinCareProductPhotoAssetId: 'prod-asset',
            skinCareProductPhotoR2Key:
                'users/$testUid/onboarding/skin_products/prod-asset.jpg',
            skinCareProductPhotoStatus: 'uploaded',
            skinCareProductPhotoCreatedAt: now,
            skinCareProductPhotoUpdatedAt: now,

            skinCareBudget: 'low',
            skinCareSkinType: 'oily',
            skinCareProblems: ['acne'],
            skinCareSelectedProductNames: ['cleanser'],
            skinCareDesiredApplicationsPerDay: 2,
            blocks: [
              TimelineBlockDraft(
                id: 'block1',
                section: 'skin_care',
                title: 'Morning Skincare',
                needsTimeConfirmation: false,
                skincareSteps: ['Wash face'],
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                startMinute: 480,
                endMinute: 490,
                blockType: 'hardBlock',
              ),
              TimelineBlockDraft(
                id: 'block2',
                section: 'skin_care',
                title: 'Night Skincare',
                needsTimeConfirmation: false,
                skincareSteps: ['Wash face'],
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                startMinute: 1200,
                endMinute: 1210,
                blockType: 'hardBlock',
              ),
            ],
          ),
          createdAt: now,
          updatedAt: now,
          badHabits: [],
        );

        final recommendationFingerprint = fullDraft.baseTimeline
            .computeSkinCareRecommendationFingerprint();
        final withRecommendationFingerprint = fullDraft.baseTimeline.copyWith(
          skinCareRecommendationFingerprint: recommendationFingerprint,
        );
        final routineFingerprint = withRecommendationFingerprint
            .computeSkinCareRoutineFingerprint();
        final provenanceToken = 'skin-care-generation:$routineFingerprint';
        fullDraft = fullDraft.copyWith(
          baseTimeline: withRecommendationFingerprint.copyWith(
            skinCareRoutineFingerprint: routineFingerprint,
            blocks: withRecommendationFingerprint.blocks
                .map(
                  (block) => block.section == 'skin_care'
                      ? block.copyWith(provenanceSourceIds: [provenanceToken])
                      : block,
                )
                .toList(growable: false),
          ),
        );
        expect(
          fullDraft.baseTimeline.skinCareRecommendationFingerprint,
          fullDraft.baseTimeline.computeSkinCareRecommendationFingerprint(),
        );
        expect(fullDraft.baseTimeline.validateSkinCareSetup(testUid), isNull);

        final bundle = OnboardingCompletionService.buildBundle(fullDraft);

        final faceRef = bundle.uploadedAssetReferences
            .where((r) => r.id == 'face-asset')
            .firstOrNull;
        expect(faceRef, isNotNull);
        expect(faceRef?.mode, 'no_products');
        expect(faceRef?.section, 'skin_care');

        final prodRef = bundle.uploadedAssetReferences
            .where((r) => r.id == 'prod-asset')
            .firstOrNull;
        expect(
          prodRef,
          isNull,
          reason:
              'Should not generate reference for product photo if mode is no_products',
        );
      },
    );
  });
}
