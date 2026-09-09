import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/skin_care_product_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_controller.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_state.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';

TimelineBlockDraft _bathBlock() => BaseTimelineDraft.defaultBathBlock();

List<TimelineBlockDraft> _fullWeekSkinBlocks(
  int count, {
  String prefix = 'Plan A',
  String product = 'Minimalist Gentle Cleanser',
}) {
  return List.generate(
    count,
    (i) => TimelineBlockDraft(
      id: '$prefix-block-$i',
      title: '$prefix Slot $i',
      startMinute: 450 + i * 120,
      endMinute: 465 + i * 120,
      section: 'skin_care',
      repeatDays: onboarding7EveryDay,
      blockType: TimelineBlockDraft.softBlockKey,
      skincareProducts: [product],
      skincareSteps: const ['Cleanse'],
    ),
  );
}

List<TimelineBlockDraft> _tagBlocks(
  List<TimelineBlockDraft> blocks,
  String fingerprint,
) {
  final token = 'skin-care-generation:$fingerprint';
  return blocks
      .map(
        (b) => b.section == 'skin_care'
            ? b.copyWith(
                provenanceSourceIds: {...b.provenanceSourceIds, token}.toList(),
              )
            : b,
      )
      .toList();
}

const _testRecs = [
  SkinCareProductRecommendationDraft(
    category: 'cleanser',
    brand: 'Minimalist',
    name: 'Minimalist Gentle Cleanser',
    estimatedPrice: '10',
    currencyCode: 'USD',
    reason: 'Gentle',
  ),
  SkinCareProductRecommendationDraft(
    category: 'moisturizer',
    brand: 'Minimalist',
    name: 'Minimalist Barrier Moisturizer',
    estimatedPrice: '12',
    currencyCode: 'USD',
    reason: 'Moisturizes',
  ),
  SkinCareProductRecommendationDraft(
    category: 'sunscreen',
    brand: 'Minimalist',
    name: 'Minimalist SPF 50 Sunscreen',
    estimatedPrice: '14',
    currencyCode: 'USD',
    reason: 'Protects',
  ),
];

const _testSelected = [
  'Minimalist Gentle Cleanser',
  'Minimalist Barrier Moisturizer',
  'Minimalist SPF 50 Sunscreen',
];

void main() {
  const testUid = 'transaction-test-uid';

  group('Transactional Rebuild & Plan A/B Replacement Invariants', () {
    late ProviderContainer container;

    setUp(() {
      final initialBase = const BaseTimelineDraft().copyWith(
        skinCareSetupPath: 'no_products',
        skinCareSetupStep: 1,
        skinCareSkinType: 'oily',
        skinCareProblems: const ['pimples'],
        skinCareBudget: 'medium',
        skinCareDesiredApplicationsPerDay: 2,
        skinCareFacePhotoAssetId: 'skin-asset',
        skinCareFacePhotoR2Key:
            'users/$testUid/onboarding/skin_care/skin-asset.jpg',
        skinCareFacePhotoStatus: 'uploaded',
        skinCareFacePhotoCreatedAt: DateTime.utc(2026, 6, 15, 10),
        skinCareFacePhotoUpdatedAt: DateTime.utc(2026, 6, 15, 10),
        skinCareProductRecommendations: _testRecs,
        skinCareSelectedProductNames: _testSelected,
        skinCareSuggestedProducts: _testSelected,
      );

      final recFp = initialBase.computeSkinCareRecommendationFingerprint();
      final withRec = initialBase.copyWith(
        skinCareRecommendationFingerprint: recFp,
      );
      final routineFp = withRec.computeSkinCareRoutineFingerprint();
      final planABlocks = _tagBlocks([
        _bathBlock(),
        ..._fullWeekSkinBlocks(2, prefix: 'Plan A'),
      ], routineFp);

      final draft = OnboardingDraft(
        uid: testUid,
        currentStep: 7,
        baseTimeline: withRec.copyWith(
          skinCareRoutineFingerprint: routineFp,
          blocks: planABlocks,
        ),
      );

      final notifier = OnboardingNotifier()..loadSeedData(draft);
      container = ProviderContainer(
        overrides: [onboardingStateProvider.overrideWith((ref) => notifier)],
      );
    });

    tearDown(() => container.dispose());

    test('Initial state has Plan A routine blocks and is current', () {
      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      final skinBlocks = base.confirmedBlocksForSection('skin_care');

      expect(skinBlocks, hasLength(2));
      expect(skinBlocks.every((b) => b.title.startsWith('Plan A')), isTrue);
      // print validation failure if any
      final validationError = base.validateSkinCareSetup(testUid);
      expect(validationError, isNull);
      expect(base.isSkinCareRoutineCurrent(testUid), isTrue);
    });

    test('startEditing preserves Plan A blocks in draft', () {
      final controller = container.read(
        skinCareFlowControllerProvider.notifier,
      );
      final baseBefore = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline;

      controller.startEditing(baseBefore);

      final baseAfter = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline;
      final skinBlocks = baseAfter.confirmedBlocksForSection('skin_care');

      expect(skinBlocks, hasLength(2));
      expect(skinBlocks.every((b) => b.title.startsWith('Plan A')), isTrue);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.noProductsEditing,
      );
    });

    test('cancelEditing exits edit mode and keeps Plan A blocks intact', () {
      final controller = container.read(
        skinCareFlowControllerProvider.notifier,
      );
      final baseBefore = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline;

      controller.startEditing(baseBefore);
      controller.cancelEditing();

      final baseAfter = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline;
      final skinBlocks = baseAfter.confirmedBlocksForSection('skin_care');

      expect(skinBlocks, hasLength(2));
      expect(skinBlocks.every((b) => b.title.startsWith('Plan A')), isTrue);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.noProductsReview,
      );
    });

    test(
      'mutating inputs during edit and calling cancelEditing restores Plan A snapshot and keeps routine current',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );
        final baseBefore = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;

        expect(baseBefore.isSkinCareRoutineCurrent(testUid), isTrue);

        controller.startEditing(baseBefore);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.noProductsEditing,
        );

        // Mutate inputs during edit (e.g. user changes budget, skinType, problems)
        container
            .read(onboardingStateProvider.notifier)
            .updateDraft(
              (d) => d.copyWith(
                baseTimeline: d.baseTimeline.copyWith(
                  skinCareBudget: 'high',
                  skinCareSkinType: 'dry',
                  skinCareProblems: const ['redness'],
                  skinCareDesiredApplicationsPerDay: 4,
                  skinCareSelectedProductNames: const ['Other Product'],
                ),
              ),
            );

        final dirtyBase = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;
        expect(dirtyBase.isSkinCareRoutineCurrent(testUid), isFalse);

        // Cancel editing restores Plan A snapshot onto draft
        controller.cancelEditing();

        final restoredBase = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;

        expect(restoredBase.skinCareBudget, 'medium');
        expect(restoredBase.skinCareSkinType, 'oily');
        expect(restoredBase.skinCareProblems, const ['pimples']);
        expect(restoredBase.skinCareDesiredApplicationsPerDay, 2);
        expect(restoredBase.skinCareSelectedProductNames, _testSelected);
        expect(restoredBase.skinCareProductRecommendations, _testRecs);
        expect(
          restoredBase.skinCareRoutineFingerprint,
          baseBefore.skinCareRoutineFingerprint,
        );
        expect(restoredBase.validateSkinCareSetup(testUid), isNull);
        expect(restoredBase.isSkinCareRoutineCurrent(testUid), isTrue);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.noProductsReview,
        );
      },
    );

    test(
      'handleBack during edit mode restores Plan A snapshot and keeps routine current',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );
        final baseBefore = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;

        controller.startEditing(baseBefore);

        // Mutate inputs during edit
        container
            .read(onboardingStateProvider.notifier)
            .updateDraft(
              (d) => d.copyWith(
                baseTimeline: d.baseTimeline.copyWith(
                  skinCareBudget: 'high',
                  skinCareDesiredApplicationsPerDay: 3,
                ),
              ),
            );

        // Shell top-left back button triggers handleBack
        final handled = controller.handleBack();
        expect(handled, isTrue);

        final restoredBase = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;
        expect(restoredBase.skinCareBudget, 'medium');
        expect(restoredBase.skinCareDesiredApplicationsPerDay, 2);
        expect(restoredBase.isSkinCareRoutineCurrent(testUid), isTrue);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.noProductsReview,
        );
      },
    );

    test('Failed rebuild leaves Plan A blocks untouched', () {
      final controller = container.read(
        skinCareFlowControllerProvider.notifier,
      );
      final baseBefore = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline;

      controller.startEditing(baseBefore);

      // Simulate a failure during generation: controller transitions with error
      controller.transitionTo(
        SkinCareFlowState.noProductsEditing,
        error: 'AI generation timed out',
      );

      final baseAfter = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline;
      final skinBlocks = baseAfter.confirmedBlocksForSection('skin_care');

      // Plan A blocks are still completely preserved
      expect(skinBlocks, hasLength(2));
      expect(skinBlocks.every((b) => b.title.startsWith('Plan A')), isTrue);
      expect(
        container.read(skinCareFlowControllerProvider).activeError,
        'AI generation timed out',
      );
    });

    test(
      'Plan B replaces Plan A atomically only upon commitRebuildSuccess',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );
        final baseBefore = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;

        controller.startEditing(baseBefore);

        var updatedBase = baseBefore.copyWith(
          skinCareDesiredApplicationsPerDay: 3,
        );
        final recFp = updatedBase.computeSkinCareRecommendationFingerprint();
        updatedBase = updatedBase.copyWith(
          skinCareRecommendationFingerprint: recFp,
        );
        final planBFingerprint = updatedBase
            .computeSkinCareRoutineFingerprint();
        final planBBlocks = _tagBlocks([
          _bathBlock(),
          ..._fullWeekSkinBlocks(3, prefix: 'Plan B'),
        ], planBFingerprint);
        updatedBase = updatedBase.copyWith(
          skinCareRoutineFingerprint: planBFingerprint,
          blocks: planBBlocks,
        );

        // Commit rebuild success
        container
            .read(onboardingStateProvider.notifier)
            .updateDraft((d) => d.copyWith(baseTimeline: updatedBase));
        controller.commitRebuildSuccess(updatedBase);

        final finalBase = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;
        final skinBlocks = finalBase.confirmedBlocksForSection('skin_care');

        // Now Plan B has atomically replaced Plan A
        expect(skinBlocks, hasLength(3));
        expect(skinBlocks.every((b) => b.title.startsWith('Plan B')), isTrue);
        expect(finalBase.validateSkinCareSetup(testUid), isNull);
        expect(finalBase.isSkinCareRoutineCurrent(testUid), isTrue);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.noProductsReview,
        );
      },
    );

    test(
      'No-products rebuild: details -> find products stays in noProductsEditing with snapshot preserved, and cancel restores Plan A recommendations',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );
        final baseBefore = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;

        expect(baseBefore.isSkinCareRoutineCurrent(testUid), isTrue);

        // Enter rebuild/edit
        controller.startEditing(baseBefore);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.noProductsEditing,
        );
        expect(
          container.read(skinCareFlowControllerProvider).noProductsEditStage,
          NoProductsEditStage.productSelection,
        );

        // Change details and trigger find products
        controller.setNoProductsEditStage(NoProductsEditStage.details);
        expect(
          container.read(skinCareFlowControllerProvider).noProductsEditStage,
          NoProductsEditStage.details,
        );
        controller.startGeneration(SkinCareFlowState.noProductsFindingProducts);
        expect(
          container.read(skinCareFlowControllerProvider).generationOrigin,
          SkinCareFlowState.noProductsEditing,
        );

        // New recommendations received from AI
        const newRecs = [
          SkinCareProductRecommendationDraft(
            category: 'cleanser',
            brand: 'CeraVe',
            name: 'CeraVe Hydrating Cleanser',
            estimatedPrice: '15',
            currencyCode: 'USD',
            reason: 'Gentle hydration',
          ),
          SkinCareProductRecommendationDraft(
            category: 'moisturizer',
            brand: 'CeraVe',
            name: 'CeraVe Moisturizing Cream',
            estimatedPrice: '18',
            currencyCode: 'USD',
            reason: 'Barrier support',
          ),
          SkinCareProductRecommendationDraft(
            category: 'sunscreen',
            brand: 'CeraVe',
            name: 'CeraVe AM Facial Lotion SPF 30',
            estimatedPrice: '19',
            currencyCode: 'USD',
            reason: 'Daily UV filter',
          ),
        ];

        container.read(onboardingStateProvider.notifier).updateDraft((d) {
          final withRecs = d.baseTimeline.copyWith(
            skinCareProductRecommendations: newRecs,
            skinCareSelectedProductNames: const ['CeraVe Hydrating Cleanser'],
          );
          return d.copyWith(
            baseTimeline: withRecs.copyWith(
              skinCareRecommendationFingerprint: withRecs
                  .computeSkinCareRecommendationFingerprint(),
            ),
          );
        });

        // completeGeneration must keep user in noProductsEditing
        controller.completeGeneration();

        final stateAfterFind = container.read(skinCareFlowControllerProvider);
        expect(stateAfterFind.state, SkinCareFlowState.noProductsEditing);
        expect(
          stateAfterFind.noProductsEditStage,
          NoProductsEditStage.productSelection,
        );
        expect(stateAfterFind.planASnapshot, isNotNull);

        // Plan A blocks are still preserved in draft
        final currentBase = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;
        final currentBlocks = currentBase.confirmedBlocksForSection(
          'skin_care',
        );
        expect(currentBlocks, hasLength(2));
        expect(
          currentBlocks.every((b) => b.title.startsWith('Plan A')),
          isTrue,
        );
        expect(currentBase.skinCareProductRecommendations, newRecs);

        // Now cancel editing: must restore original Plan A recommendations and fingerprints
        controller.cancelEditing();

        final restoredBase = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;
        expect(restoredBase.skinCareProductRecommendations, _testRecs);
        expect(restoredBase.skinCareSelectedProductNames, _testSelected);
        expect(
          restoredBase.skinCareRecommendationFingerprint,
          baseBefore.skinCareRecommendationFingerprint,
        );
        expect(
          restoredBase.skinCareRoutineFingerprint,
          baseBefore.skinCareRoutineFingerprint,
        );
        expect(restoredBase.isSkinCareRoutineCurrent(testUid), isTrue);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.noProductsReview,
        );
      },
    );

    test(
      'Has-products photo rebuild: photo re-analysis stays in hasProductsEditing with snapshot preserved',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );

        // Setup has-products Plan A
        var hpBase = const BaseTimelineDraft().copyWith(
          skinCareSetupPath: 'has_products',
          skinCareSetupStep: 1,
          skinCareProductNames: 'Original Cleanser',
          skinCareReviewedProducts: const [
            SkinCareDetectedProduct(name: 'Original Cleanser'),
          ],
        );
        final hpRoutineFp = hpBase.computeSkinCareRoutineFingerprint();
        final hpBlocks = _tagBlocks([
          _bathBlock(),
          ..._fullWeekSkinBlocks(
            2,
            prefix: 'HP Plan A',
            product: 'Original Cleanser',
          ),
        ], hpRoutineFp);
        hpBase = hpBase.copyWith(
          skinCareRoutineFingerprint: hpRoutineFp,
          blocks: hpBlocks,
        );

        container
            .read(onboardingStateProvider.notifier)
            .updateDraft((d) => d.copyWith(baseTimeline: hpBase));

        expect(hpBase.isSkinCareRoutineCurrent(testUid), isTrue);

        // Start rebuild
        controller.startEditing(hpBase);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.hasProductsEditing,
        );

        // Start photo analysis
        controller.startGeneration(SkinCareFlowState.hasProductsGenerating);
        expect(
          container.read(skinCareFlowControllerProvider).generationOrigin,
          SkinCareFlowState.hasProductsEditing,
        );

        // Photo analysis completes
        container
            .read(onboardingStateProvider.notifier)
            .updateDraft(
              (d) => d.copyWith(
                baseTimeline: d.baseTimeline.copyWith(
                  skinCareReviewedProducts: const [
                    SkinCareDetectedProduct(name: 'New Cleanser'),
                    SkinCareDetectedProduct(name: 'New Cream'),
                  ],
                ),
              ),
            );

        // completeGeneration must keep user in hasProductsEditing
        controller.completeGeneration();

        final stateAfterAnalysis = container.read(
          skinCareFlowControllerProvider,
        );
        expect(stateAfterAnalysis.state, SkinCareFlowState.hasProductsEditing);
        expect(stateAfterAnalysis.planASnapshot, isNotNull);

        // Blocks are still HP Plan A
        final draftBlocks = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .confirmedBlocksForSection('skin_care');
        expect(draftBlocks, hasLength(2));
        expect(
          draftBlocks.every((b) => b.title.startsWith('HP Plan A')),
          isTrue,
        );
      },
    );
  });

  group(
    'Transactional Photo Replacement Lifecycle (Edit/Rebuild) with Real Controllers & Fake Deps',
    () {
      test(
        'Plan A with Photo A -> Edit -> upload Photo B (defer) -> cancel preserves Photo A in repo/R2, deletes Photo B',
        () async {
          final photoA = UploadedAsset(
            assetId: 'asset-photo-a',
            ownerUid: testUid,
            sourceFeature: 'onboarding',
            purpose: UploadedAssetPurpose.skinFace,
            fileName: 'photo-a.jpg',
            contentType: 'image/jpeg',
            sizeBytes: 100,
            r2Key: 'users/$testUid/onboarding/skin_face/asset-photo-a.jpg',
            status: UploadedAssetStatus.uploaded,
            createdAt: DateTime.utc(2026, 6, 15, 10),
            updatedAt: DateTime.utc(2026, 6, 15, 10),
          );

          final assetRepo = _TxTestAssetRepo([photoA]);
          final r2Client = _TxTestR2Client();
          final authRepo = _TxTestAuthRepo(
            currentUser: const AuthUser(
              uid: testUid,
              email: 'test@optivus.dev',
              emailVerified: true,
            ),
          );

          final testDraft = OnboardingDraft(
            uid: testUid,
            currentStep: 7,
            baseTimeline: BaseTimelineDraft(
              skinCareSetupPath: 'no_products',
              skinCareSetupStep: 1,
              skinCareFacePhotoAssetId: 'asset-photo-a',
              skinCareFacePhotoR2Key:
                  'users/$testUid/onboarding/skin_face/asset-photo-a.jpg',
              skinCareFacePhotoStatus: 'uploaded',
            ),
          );

          final testNotifier = OnboardingNotifier()..loadSeedData(testDraft);
          final testContainer = ProviderContainer(
            overrides: [
              onboardingStateProvider.overrideWith((ref) => testNotifier),
              authProvider.overrideWith(
                (ref) => _Step7TestAuthNotifier(
                  const AuthUser(
                    uid: testUid,
                    email: 'test@optivus.dev',
                    emailVerified: true,
                  ),
                ),
              ),
              uploadedAssetRepositoryProvider.overrideWithValue(assetRepo),
              authRepositoryProvider.overrideWithValue(authRepo),
              imagePrepareServiceProvider.overrideWithValue(
                _TxTestImagePrepareService(),
              ),
              r2UploadClientProvider.overrideWithValue(r2Client),
            ],
          );
          addTearDown(testContainer.dispose);

          final uploadController = testContainer.read(
            onboardingUploadInteractionProvider.notifier,
          );
          uploadController.syncWithDurableState(
            RestoredUploadsState(
              assetsByPurpose: {
                UploadedAssetPurpose.skinFace: RestoredUploadedAsset(
                  asset: photoA,
                ),
              },
            ),
            uid: testUid,
          );

          final flowController = testContainer.read(
            skinCareFlowControllerProvider.notifier,
          );
          flowController.startEditing(testDraft.baseTimeline);

          // Upload Photo B with deferReplacement: true (as triggered during isEditing)
          await uploadController.chooseFromGallery(
            onboardingSkinFaceUploadSlot,
            uid: testUid,
            sourceFeature: 'onboarding',
            deferReplacement: true,
          );

          // Verify intermediate state: Photo A preserved as durable, Photo B staged
          var slotState = testContainer.read(
            onboardingUploadInteractionProvider,
          )[onboardingSkinFaceUploadSlot]!;
          expect(slotState.durableAsset?.assetId, 'asset-photo-a');
          expect(slotState.pendingReplacementAsset?.assetId, 'asset-photo-b');
          expect(slotState.isDeferredReplacement, isTrue);
          expect(assetRepo.deletedAssetIds, isNot(contains('asset-photo-a')));
          expect(r2Client.deletedObjectKeys, isNot(contains(photoA.r2Key)));

          // User cancels / navigates back
          flowController.cancelEditing();
          await Future<void>.delayed(Duration.zero);

          // Verify rollback: Photo B cleaned from repo and R2, Photo A remains durable
          slotState = testContainer.read(
            onboardingUploadInteractionProvider,
          )[onboardingSkinFaceUploadSlot]!;
          expect(slotState.pendingReplacementAsset, isNull);
          expect(slotState.durableAsset?.assetId, 'asset-photo-a');
          expect(assetRepo.deletedAssetIds, contains('asset-photo-b'));
          expect(assetRepo.deletedAssetIds, isNot(contains('asset-photo-a')));
          expect(
            r2Client.deletedObjectKeys,
            contains('users/$testUid/onboarding/skin_face/asset-photo-b.jpg'),
          );
          expect(r2Client.deletedObjectKeys, isNot(contains(photoA.r2Key)));
        },
      );

      test(
        'Plan A with Photo A -> Edit -> upload Photo B -> commitRebuildSuccess promotes Photo B and cleans Photo A',
        () async {
          final photoA = UploadedAsset(
            assetId: 'asset-photo-a',
            ownerUid: testUid,
            sourceFeature: 'onboarding',
            purpose: UploadedAssetPurpose.skinFace,
            fileName: 'photo-a.jpg',
            contentType: 'image/jpeg',
            sizeBytes: 100,
            r2Key: 'users/$testUid/onboarding/skin_face/asset-photo-a.jpg',
            status: UploadedAssetStatus.uploaded,
            createdAt: DateTime.utc(2026, 6, 15, 10),
            updatedAt: DateTime.utc(2026, 6, 15, 10),
          );

          final assetRepo = _TxTestAssetRepo([photoA]);
          final r2Client = _TxTestR2Client();
          final authRepo = _TxTestAuthRepo(
            currentUser: const AuthUser(
              uid: testUid,
              email: 'test@optivus.dev',
              emailVerified: true,
            ),
          );

          final testDraft = OnboardingDraft(
            uid: testUid,
            currentStep: 7,
            baseTimeline: BaseTimelineDraft(
              skinCareSetupPath: 'no_products',
              skinCareSetupStep: 1,
              skinCareFacePhotoAssetId: 'asset-photo-a',
              skinCareFacePhotoR2Key:
                  'users/$testUid/onboarding/skin_face/asset-photo-a.jpg',
              skinCareFacePhotoStatus: 'uploaded',
            ),
          );

          final testNotifier = OnboardingNotifier()..loadSeedData(testDraft);
          final testContainer = ProviderContainer(
            overrides: [
              onboardingStateProvider.overrideWith((ref) => testNotifier),
              authProvider.overrideWith(
                (ref) => _Step7TestAuthNotifier(
                  const AuthUser(
                    uid: testUid,
                    email: 'test@optivus.dev',
                    emailVerified: true,
                  ),
                ),
              ),
              uploadedAssetRepositoryProvider.overrideWithValue(assetRepo),
              authRepositoryProvider.overrideWithValue(authRepo),
              imagePrepareServiceProvider.overrideWithValue(
                _TxTestImagePrepareService(),
              ),
              r2UploadClientProvider.overrideWithValue(r2Client),
            ],
          );
          addTearDown(testContainer.dispose);

          final uploadController = testContainer.read(
            onboardingUploadInteractionProvider.notifier,
          );
          uploadController.syncWithDurableState(
            RestoredUploadsState(
              assetsByPurpose: {
                UploadedAssetPurpose.skinFace: RestoredUploadedAsset(
                  asset: photoA,
                ),
              },
            ),
            uid: testUid,
          );

          final flowController = testContainer.read(
            skinCareFlowControllerProvider.notifier,
          );
          flowController.startEditing(testDraft.baseTimeline);

          await uploadController.chooseFromGallery(
            onboardingSkinFaceUploadSlot,
            uid: testUid,
            sourceFeature: 'onboarding',
            deferReplacement: true,
          );

          // Commit rebuild
          final updatedBase = testDraft.baseTimeline.copyWith(
            skinCareFacePhotoAssetId: 'asset-photo-b',
            skinCareFacePhotoR2Key:
                'users/$testUid/onboarding/skin_face/asset-photo-b.jpg',
            skinCareFacePhotoStatus: 'uploaded',
          );
          flowController.commitRebuildSuccess(updatedBase);
          await Future<void>.delayed(Duration.zero);

          // Verify: Photo B is durable, Photo A is deleted
          final slotState = testContainer.read(
            onboardingUploadInteractionProvider,
          )[onboardingSkinFaceUploadSlot]!;
          expect(slotState.durableAsset?.assetId, 'asset-photo-b');
          expect(slotState.pendingReplacementAsset, isNull);
          expect(assetRepo.deletedAssetIds, contains('asset-photo-a'));
          expect(r2Client.deletedObjectKeys, contains(photoA.r2Key));
        },
      );

      test(
        'Explicit removal during Edit -> cancel -> photo is not resurrected',
        () async {
          final photoA = UploadedAsset(
            assetId: 'asset-photo-a',
            ownerUid: testUid,
            sourceFeature: 'onboarding',
            purpose: UploadedAssetPurpose.skinFace,
            fileName: 'photo-a.jpg',
            contentType: 'image/jpeg',
            sizeBytes: 100,
            r2Key: 'users/$testUid/onboarding/skin_face/asset-photo-a.jpg',
            status: UploadedAssetStatus.uploaded,
            createdAt: DateTime.utc(2026, 6, 15, 10),
            updatedAt: DateTime.utc(2026, 6, 15, 10),
          );

          final assetRepo = _TxTestAssetRepo([photoA]);
          final r2Client = _TxTestR2Client();
          final authRepo = _TxTestAuthRepo(
            currentUser: const AuthUser(
              uid: testUid,
              email: 'test@optivus.dev',
              emailVerified: true,
            ),
          );

          final testDraft = OnboardingDraft(
            uid: testUid,
            currentStep: 7,
            baseTimeline: BaseTimelineDraft(
              skinCareSetupPath: 'no_products',
              skinCareSetupStep: 1,
              skinCareFacePhotoAssetId: 'asset-photo-a',
              skinCareFacePhotoR2Key:
                  'users/$testUid/onboarding/skin_face/asset-photo-a.jpg',
              skinCareFacePhotoStatus: 'uploaded',
            ),
          );

          final testNotifier = OnboardingNotifier()..loadSeedData(testDraft);
          final testContainer = ProviderContainer(
            overrides: [
              onboardingStateProvider.overrideWith((ref) => testNotifier),
              authProvider.overrideWith(
                (ref) => _Step7TestAuthNotifier(
                  const AuthUser(
                    uid: testUid,
                    email: 'test@optivus.dev',
                    emailVerified: true,
                  ),
                ),
              ),
              uploadedAssetRepositoryProvider.overrideWithValue(assetRepo),
              authRepositoryProvider.overrideWithValue(authRepo),
              imagePrepareServiceProvider.overrideWithValue(
                _TxTestImagePrepareService(),
              ),
              r2UploadClientProvider.overrideWithValue(r2Client),
            ],
          );
          addTearDown(testContainer.dispose);

          final uploadController = testContainer.read(
            onboardingUploadInteractionProvider.notifier,
          );
          uploadController.syncWithDurableState(
            RestoredUploadsState(
              assetsByPurpose: {
                UploadedAssetPurpose.skinFace: RestoredUploadedAsset(
                  asset: photoA,
                ),
              },
            ),
            uid: testUid,
          );

          final flowController = testContainer.read(
            skinCareFlowControllerProvider.notifier,
          );
          flowController.startEditing(testDraft.baseTimeline);

          // Explicit removal during edit
          flowController.clearSnapshotPhoto(isFacePhoto: true);
          await uploadController.remove(
            onboardingSkinFaceUploadSlot,
            uid: testUid,
          );

          // Cancel editing
          flowController.cancelEditing();

          final base = testContainer
              .read(onboardingStateProvider)
              .draft
              .baseTimeline;
          expect(base.skinCareFacePhotoAssetId, isNull);
          final slotState = testContainer.read(
            onboardingUploadInteractionProvider,
          )[onboardingSkinFaceUploadSlot]!;
          expect(slotState.durableAsset, isNull);
        },
      );

      test(
        'Account switch during active deferred replacement rolls back pending replacement and isolates accounts',
        () async {
          final photoA = UploadedAsset(
            assetId: 'asset-photo-a',
            ownerUid: testUid,
            sourceFeature: 'onboarding',
            purpose: UploadedAssetPurpose.skinFace,
            fileName: 'photo-a.jpg',
            contentType: 'image/jpeg',
            sizeBytes: 100,
            r2Key: 'users/$testUid/onboarding/skin_face/asset-photo-a.jpg',
            status: UploadedAssetStatus.uploaded,
            createdAt: DateTime.utc(2026, 6, 15, 10),
            updatedAt: DateTime.utc(2026, 6, 15, 10),
          );

          final assetRepo = _TxTestAssetRepo([photoA]);
          final r2Client = _TxTestR2Client();
          final authRepo = _TxTestAuthRepo(
            currentUser: const AuthUser(
              uid: testUid,
              email: 'test@optivus.dev',
              emailVerified: true,
            ),
          );

          final testDraft = OnboardingDraft(
            uid: testUid,
            currentStep: 7,
            baseTimeline: BaseTimelineDraft(
              skinCareSetupPath: 'no_products',
              skinCareSetupStep: 1,
              skinCareFacePhotoAssetId: 'asset-photo-a',
              skinCareFacePhotoR2Key:
                  'users/$testUid/onboarding/skin_face/asset-photo-a.jpg',
              skinCareFacePhotoStatus: 'uploaded',
            ),
          );

          final testNotifier = OnboardingNotifier()..loadSeedData(testDraft);
          final testContainer = ProviderContainer(
            overrides: [
              onboardingStateProvider.overrideWith((ref) => testNotifier),
              authProvider.overrideWith(
                (ref) => _Step7TestAuthNotifier(
                  const AuthUser(
                    uid: testUid,
                    email: 'test@optivus.dev',
                    emailVerified: true,
                  ),
                ),
              ),
              uploadedAssetRepositoryProvider.overrideWithValue(assetRepo),
              authRepositoryProvider.overrideWithValue(authRepo),
              imagePrepareServiceProvider.overrideWithValue(
                _TxTestImagePrepareService(),
              ),
              r2UploadClientProvider.overrideWithValue(r2Client),
            ],
          );
          addTearDown(testContainer.dispose);

          final uploadController = testContainer.read(
            onboardingUploadInteractionProvider.notifier,
          );
          uploadController.syncWithDurableState(
            RestoredUploadsState(
              assetsByPurpose: {
                UploadedAssetPurpose.skinFace: RestoredUploadedAsset(
                  asset: photoA,
                ),
              },
            ),
            uid: testUid,
          );

          final flowController = testContainer.read(
            skinCareFlowControllerProvider.notifier,
          );
          flowController.startEditing(testDraft.baseTimeline);

          await uploadController.chooseFromGallery(
            onboardingSkinFaceUploadSlot,
            uid: testUid,
            sourceFeature: 'onboarding',
            deferReplacement: true,
          );

          // Account switches to user-b
          flowController.syncFromDraft(
            const BaseTimelineDraft(),
            'user-b',
            authGeneration: 2,
          );
          await Future<void>.delayed(Duration.zero);

          // Verify: User A's pending replacement was rolled back and cleaned up
          expect(assetRepo.deletedAssetIds, contains('asset-photo-b'));
          expect(
            r2Client.deletedObjectKeys,
            contains('users/$testUid/onboarding/skin_face/asset-photo-b.jpg'),
          );
        },
      );
    },
  );
}

class _TxTestAuthRepo implements AuthRepository {
  @override
  AuthUser? currentUser;
  _TxTestAuthRepo({this.currentUser});
  @override
  Future<String?> currentIdToken() async => 'test-token';
  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(currentUser);
  @override
  Future<AuthUser?> signInWithGoogle() async => currentUser;
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

class _Step7TestAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _Step7TestAuthNotifier(AuthUser? user)
    : super(
        AuthState(
          user: user,
          status: AuthFlowStatus.signedInOnboardingIncomplete,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TxTestAssetRepo extends FakeUploadedAssetRepository {
  final List<String> deletedAssetIds = [];

  _TxTestAssetRepo([List<UploadedAsset>? initial]) {
    if (initial != null) {
      for (final asset in initial) {
        saveAsset(asset);
      }
    }
  }

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {
    deletedAssetIds.add(assetId);
    await super.markDeleted(uid: uid, assetId: assetId);
  }
}

class _TxTestR2Client implements R2UploadClient {
  final List<String> deletedObjectKeys = [];
  int signCallCount = 0;
  int uploadCallCount = 0;
  int completeCallCount = 0;

  @override
  Future<R2SignedUpload> signUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    required String contentType,
    required int sizeBytes,
    required String idToken,
  }) async {
    signCallCount++;
    return R2SignedUpload(
      assetId: 'asset-photo-b',
      objectKey:
          'users/$uid/$sourceFeature/${purpose.wireName}/asset-photo-b.jpg',
      uploadUrl: 'https://r2.optivus.dev/upload',
    );
  }

  @override
  Future<void> uploadBytes({
    required String uploadUrl,
    required String contentType,
    required Uint8List bytes,
  }) async {
    uploadCallCount++;
  }

  @override
  Future<void> markUploadComplete({
    required String assetId,
    required String objectKey,
    required int sizeBytes,
    required String idToken,
  }) async {
    completeCallCount++;
  }

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    deletedObjectKeys.add(objectKey);
  }
}

class _TxTestImagePrepareService extends ImagePrepareService {
  @override
  Future<XFile?> pickImageFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    return XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'photo-b.jpg',
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<PreparedUploadImage?> preparePickedFile(
    XFile? picked, {
    UploadedAssetPurpose purpose = UploadedAssetPurpose.profilePhoto,
  }) async {
    if (picked == null) return null;
    return PreparedUploadImage(
      fileName: 'photo-b.jpg',
      contentType: 'image/jpeg',
      bytes: Uint8List.fromList([1, 2, 3]),
      sizeBytes: 3,
    );
  }
}
