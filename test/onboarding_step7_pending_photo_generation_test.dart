import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_controller.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_state.dart';
import 'package:optivus/features/uploads/controllers/upload_interaction_controller.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/services/device_country_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  const testUid = 'user-gate3-closure';

  final photoA = UploadedAsset(
    assetId: 'asset-photo-a',
    ownerUid: testUid,
    sourceFeature: 'onboarding',
    purpose: UploadedAssetPurpose.skinProducts,
    fileName: 'asset-photo-a.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    r2Key: 'users/$testUid/onboarding/skin_products/asset-photo-a.jpg',
    status: UploadedAssetStatus.uploaded,
    createdAt: DateTime.utc(2026, 6, 15, 10),
    updatedAt: DateTime.utc(2026, 6, 15, 10),
  );

  final photoB = UploadedAsset(
    assetId: 'asset-photo-b',
    ownerUid: testUid,
    sourceFeature: 'onboarding',
    purpose: UploadedAssetPurpose.skinProducts,
    fileName: 'asset-photo-b.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 2048,
    r2Key: 'users/$testUid/onboarding/skin_products/asset-photo-b.jpg',
    status: UploadedAssetStatus.uploaded,
    createdAt: DateTime.utc(2026, 6, 15, 11),
    updatedAt: DateTime.utc(2026, 6, 15, 11),
  );

  final facePhotoA = UploadedAsset(
    assetId: 'asset-face-a',
    ownerUid: testUid,
    sourceFeature: 'onboarding',
    purpose: UploadedAssetPurpose.skinFace,
    fileName: 'asset-face-a.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    r2Key: 'users/$testUid/onboarding/skin_face/asset-face-a.jpg',
    status: UploadedAssetStatus.uploaded,
    createdAt: DateTime.utc(2026, 6, 15, 10),
    updatedAt: DateTime.utc(2026, 6, 15, 10),
  );

  final facePhotoB = UploadedAsset(
    assetId: 'asset-face-b',
    ownerUid: testUid,
    sourceFeature: 'onboarding',
    purpose: UploadedAssetPurpose.skinFace,
    fileName: 'asset-face-b.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 2048,
    r2Key: 'users/$testUid/onboarding/skin_face/asset-face-b.jpg',
    status: UploadedAssetStatus.uploaded,
    createdAt: DateTime.utc(2026, 6, 15, 11),
    updatedAt: DateTime.utc(2026, 6, 15, 11),
  );

  final testRoutineResult = const SkinCareAiRoutineResult(
    routinePlans: [
      SkinCareRoutinePlan(
        slotLabel: 'morning',
        title: 'Morning Routine',
        steps: ['Cleanse', 'Sunscreen'],
        productNames: [
          'Minimalist Gentle Cleanser',
          'Minimalist SPF 50 Sunscreen',
        ],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'night',
        title: 'Night Routine',
        steps: ['Cleanse', 'Moisturize'],
        productNames: [
          'Minimalist Gentle Cleanser',
          'Minimalist Barrier Moisturizer',
        ],
      ),
    ],
    morningRoutine: [],
    nightRoutine: [],
    weeklyRoutine: [],
    timelineBlocks: [],
  );

  Future<void> replaceSkinPhotoViaUI(WidgetTester tester) async {
    final photoTarget = find.text('Photo uploaded');
    expect(photoTarget, findsOneWidget);
    await tester.ensureVisible(photoTarget);
    await tester.tap(photoTarget);
    await tester.pumpAndSettle();

    final galleryOption = find.byKey(
      const ValueKey('onboarding-step7-choose-gallery'),
    );
    expect(galleryOption, findsOneWidget);
    await tester.tap(galleryOption);
    await tester.pumpAndSettle();
  }

  group('Gate 3 Sixth Closure — Pending Replacement AI Integration Tests', () {
    testWidgets(
      '1. Has-products pending photo label analysis: Worker receives Photo B key and session guard accepts response',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final assetRepo = _PendingTestAssetRepo([photoA]);
        final r2Client = _PendingTestR2Client(signedAssetId: 'asset-photo-b');
        final imageService = _PendingTestImageService(pickedAsset: photoB);
        final aiClient = _PendingTestAiClient(
          productResult: const SkinCareAiProductResult(
            products: [
              {'name': 'Photo B Cleanser', 'category': 'cleanser'},
            ],
          ),
        );

        final initialDraft = _buildHasProductsPlanADraft(testUid, photoA);
        final harness = _TestHarness(
          draft: initialDraft,
          assetRepo: assetRepo,
          r2Client: r2Client,
          imageService: imageService,
          aiClient: aiClient,
        );

        await tester.pumpWidget(harness.buildWidget());
        await tester.pumpAndSettle();

        harness.flowController.startEditing(initialDraft.baseTimeline);
        await tester.pumpAndSettle();

        await replaceSkinPhotoViaUI(tester);

        final slot = harness.currentSlot(onboardingSkinProductsUploadSlot);
        expect(slot?.durableAsset?.assetId, 'asset-photo-a');
        expect(slot?.pendingReplacementAsset?.assetId, 'asset-photo-b');
        expect(slot?.isDeferredReplacement, isTrue);
        expect(slot?.effectiveAsset?.assetId, 'asset-photo-b');

        final resolved = currentSkinPhotoForTransaction(
          slot: slot,
          draft: harness.currentDraft,
          purpose: UploadedAssetPurpose.skinProducts,
        );
        expect(resolved?.assetId, 'asset-photo-b');
        expect(resolved?.r2Key, photoB.r2Key);

        final readLabelsFinder = find.text('Read product labels');
        expect(readLabelsFinder, findsOneWidget);
        await tester.ensureVisible(readLabelsFinder);
        await tester.tap(readLabelsFinder);
        await tester.pumpAndSettle();

        expect(aiClient.analyzeCalls, 1);
        expect(aiClient.lastProductPhotos, [photoB.r2Key]);

        expect(find.text('Photo B Cleanser - cleanser'), findsOneWidget);
        expect(
          harness.currentDraft.baseTimeline.skinCareProductNames,
          contains('Photo B Cleanser'),
        );
      },
    );

    testWidgets(
      '2. Has-products pending photo routine generation: session guard accepts Photo B, tags blocks, and commits replacement',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final assetRepo = _PendingTestAssetRepo([photoA]);
        final r2Client = _PendingTestR2Client(signedAssetId: 'asset-photo-b');
        final imageService = _PendingTestImageService(pickedAsset: photoB);
        final aiClient = _PendingTestAiClient(
          productResult: const SkinCareAiProductResult(
            products: [
              {'name': 'Minimalist Gentle Cleanser', 'category': 'cleanser'},
              {'name': 'Minimalist SPF 50 Sunscreen', 'category': 'sunscreen'},
              {
                'name': 'Minimalist Barrier Moisturizer',
                'category': 'moisturizer',
              },
            ],
          ),
          routineResult: testRoutineResult,
        );

        final initialDraft = _buildHasProductsPlanADraft(testUid, photoA);
        final harness = _TestHarness(
          draft: initialDraft,
          assetRepo: assetRepo,
          r2Client: r2Client,
          imageService: imageService,
          aiClient: aiClient,
        );

        await tester.pumpWidget(harness.buildWidget());
        await tester.pumpAndSettle();

        harness.flowController.startEditing(initialDraft.baseTimeline);
        await tester.pumpAndSettle();

        await replaceSkinPhotoViaUI(tester);

        await tester.ensureVisible(find.text('Read product labels'));
        await tester.tap(find.text('Read product labels'));
        await tester.pumpAndSettle();

        final generateBtn = find.byKey(
          const ValueKey('onboarding-step7-generate-button'),
        );
        expect(generateBtn, findsOneWidget);
        await tester.ensureVisible(generateBtn);
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        expect(aiClient.generateCalls, hasLength(1));

        final nextDraft = harness.currentDraft;
        final skinBlocks = nextDraft.baseTimeline.confirmedBlocksForSection(
          'skin_care',
        );
        expect(skinBlocks, isNotEmpty);
        for (final block in skinBlocks) {
          expect(block.provenanceSourceIds, contains(photoB.assetId));
          expect(block.provenanceSourceIds, contains(photoB.r2Key));
        }

        final finalSlot = harness.currentSlot(onboardingSkinProductsUploadSlot);
        expect(finalSlot?.durableAsset?.assetId, 'asset-photo-b');
        expect(finalSlot?.pendingReplacementAsset, isNull);
        expect(finalSlot?.isDeferredReplacement, isFalse);
        expect(assetRepo.deletedAssetIds, contains('asset-photo-a'));
        expect(r2Client.deletedObjectKeys, contains(photoA.r2Key));
      },
    );

    testWidgets(
      '3. No-products pending face photo find-products: Worker receives Photo B key and session guard accepts response',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final assetRepo = _PendingTestAssetRepo([facePhotoA]);
        final r2Client = _PendingTestR2Client(signedAssetId: 'asset-face-b');
        final imageService = _PendingTestImageService(pickedAsset: facePhotoB);
        final aiClient = _PendingTestAiClient(
          routineResult: const SkinCareAiRoutineResult(
            morningRoutine: [],
            nightRoutine: [],
            weeklyRoutine: [],
            timelineBlocks: [],
            recommendedProducts: [
              SkinCareProductRecommendation(
                name: 'Minimalist Gentle Cleanser',
                brand: 'Minimalist',
                category: 'cleanser',
                estimatedPrice: '299',
                currencyCode: 'INR',
                reason: 'Gentle',
              ),
              SkinCareProductRecommendation(
                name: 'Minimalist Barrier Moisturizer',
                brand: 'Minimalist',
                category: 'moisturizer',
                estimatedPrice: '349',
                currencyCode: 'INR',
                reason: 'Moisturizes',
              ),
              SkinCareProductRecommendation(
                name: 'Minimalist SPF 50 Sunscreen',
                brand: 'Minimalist',
                category: 'sunscreen',
                estimatedPrice: '399',
                currencyCode: 'INR',
                reason: 'Protects',
              ),
            ],
          ),
        );

        final initialDraft = _buildNoProductsPlanADraft(testUid, facePhotoA);
        final harness = _TestHarness(
          draft: initialDraft,
          assetRepo: assetRepo,
          r2Client: r2Client,
          imageService: imageService,
          aiClient: aiClient,
        );

        await tester.pumpWidget(harness.buildWidget());
        await tester.pumpAndSettle();

        harness.flowController.startEditing(initialDraft.baseTimeline);
        await tester.pumpAndSettle();

        // When in edit mode with existing recommendations, tap "Change details" to show photo inputs
        final changeDetailsBtn = find.text('Change details');
        expect(changeDetailsBtn, findsOneWidget);
        await tester.tap(changeDetailsBtn);
        await tester.pumpAndSettle();

        // Now photo target is visible
        await replaceSkinPhotoViaUI(tester);

        final slot = harness.currentSlot(onboardingSkinFaceUploadSlot);
        expect(slot?.durableAsset?.assetId, 'asset-face-a');
        expect(slot?.pendingReplacementAsset?.assetId, 'asset-face-b');
        expect(slot?.effectiveAsset?.assetId, 'asset-face-b');

        // Tap "Find products"
        final findBtn = find.text('Find products');
        expect(findBtn, findsOneWidget);
        await tester.ensureVisible(findBtn);
        await tester.tap(findBtn);
        await tester.pumpAndSettle();

        // Worker received Photo B's key
        expect(aiClient.generateCalls, hasLength(1));
        final params = aiClient.generateCalls.first;
        expect(params['facePhotoR2Key'], facePhotoB.r2Key);

        // Session guard accepted: recommendations updated onto draft
        final draftRecs =
            harness.currentDraft.baseTimeline.skinCareProductRecommendations;
        expect(draftRecs, hasLength(3));
      },
    );

    testWidgets(
      '4. No-products pending face photo routine generation: commits Plan B blocks and promotes Photo B to durable',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final assetRepo = _PendingTestAssetRepo([facePhotoA]);
        final r2Client = _PendingTestR2Client(signedAssetId: 'asset-face-b');
        final imageService = _PendingTestImageService(pickedAsset: facePhotoB);
        final aiClient = _PendingTestAiClient(routineResult: testRoutineResult);

        final initialDraft = _buildNoProductsWithRecsDraft(testUid, facePhotoA);
        final harness = _TestHarness(
          draft: initialDraft,
          assetRepo: assetRepo,
          r2Client: r2Client,
          imageService: imageService,
          aiClient: aiClient,
        );

        await tester.pumpWidget(harness.buildWidget());
        await tester.pumpAndSettle();

        harness.flowController.startEditing(initialDraft.baseTimeline);
        await tester.pumpAndSettle();

        // Switch to photo inputs
        await tester.tap(find.text('Change details'));
        await tester.pumpAndSettle();

        await replaceSkinPhotoViaUI(tester);

        // Find products with Face Photo B
        aiClient.queueRoutineResult(
          const SkinCareAiRoutineResult(
            morningRoutine: [],
            nightRoutine: [],
            weeklyRoutine: [],
            timelineBlocks: [],
            recommendedProducts: [
              SkinCareProductRecommendation(
                name: 'Minimalist Gentle Cleanser',
                brand: 'Minimalist',
                category: 'cleanser',
                estimatedPrice: '299',
                currencyCode: 'INR',
                reason: 'Gentle',
              ),
              SkinCareProductRecommendation(
                name: 'Minimalist Barrier Moisturizer',
                brand: 'Minimalist',
                category: 'moisturizer',
                estimatedPrice: '349',
                currencyCode: 'INR',
                reason: 'Moisturizes',
              ),
              SkinCareProductRecommendation(
                name: 'Minimalist SPF 50 Sunscreen',
                brand: 'Minimalist',
                category: 'sunscreen',
                estimatedPrice: '399',
                currencyCode: 'INR',
                reason: 'Protects',
              ),
            ],
          ),
        );

        await tester.ensureVisible(find.text('Find products'));
        await tester.tap(find.text('Find products'));
        await tester.pumpAndSettle();

        // Select the essential recommended products
        await tester.tap(find.text('Minimalist Gentle Cleanser'));
        await tester.tap(find.text('Minimalist Barrier Moisturizer'));
        await tester.tap(find.text('Minimalist SPF 50 Sunscreen'));
        await tester.pumpAndSettle();

        // Tap "Build skin routine"
        final buildBtn = find.text('Build skin routine');
        expect(buildBtn, findsOneWidget);
        await tester.ensureVisible(buildBtn);
        await tester.tap(buildBtn);
        await tester.pumpAndSettle();

        expect(
          aiClient.generateCalls.first['facePhotoR2Key'],
          facePhotoB.r2Key,
        );

        // Blocks committed with Photo B provenance
        final nextDraft = harness.currentDraft;
        final skinBlocks = nextDraft.baseTimeline.confirmedBlocksForSection(
          'skin_care',
        );
        expect(skinBlocks, isNotEmpty);
        for (final block in skinBlocks) {
          expect(block.provenanceSourceIds, contains(facePhotoB.assetId));
          expect(block.provenanceSourceIds, contains(facePhotoB.r2Key));
        }

        // Photo B promoted, Photo A cleaned
        final slot = harness.currentSlot(onboardingSkinFaceUploadSlot);
        expect(slot?.durableAsset?.assetId, 'asset-face-b');
        expect(slot?.pendingReplacementAsset, isNull);
        expect(assetRepo.deletedAssetIds, contains('asset-face-a'));
        expect(r2Client.deletedObjectKeys, contains(facePhotoA.r2Key));
      },
    );

    testWidgets(
      '5. Back navigation while pending Photo B AI runs: epoch change and rollback ignores late response and preserves Plan A',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final assetRepo = _PendingTestAssetRepo([photoA]);
        final r2Client = _PendingTestR2Client(signedAssetId: 'asset-photo-b');
        final imageService = _PendingTestImageService(pickedAsset: photoB);
        final routineCompleter = Completer<SkinCareAiRoutineResult>();
        final aiClient = _PendingTestAiClient(
          productResult: const SkinCareAiProductResult(
            products: [
              {'name': 'Minimalist Gentle Cleanser', 'category': 'cleanser'},
            ],
          ),
          routineCompleter: routineCompleter,
        );

        final initialDraft = _buildHasProductsPlanADraft(testUid, photoA);
        final harness = _TestHarness(
          draft: initialDraft,
          assetRepo: assetRepo,
          r2Client: r2Client,
          imageService: imageService,
          aiClient: aiClient,
        );

        await tester.pumpWidget(harness.buildWidget());
        await tester.pumpAndSettle();

        harness.flowController.startEditing(initialDraft.baseTimeline);
        await tester.pumpAndSettle();

        await replaceSkinPhotoViaUI(tester);

        await tester.ensureVisible(find.text('Read product labels'));
        await tester.tap(find.text('Read product labels'));
        await tester.pumpAndSettle();

        // Start routine generation (in-flight via completer)
        final generateBtn = find.byKey(
          const ValueKey('onboarding-step7-generate-button'),
        );
        await tester.ensureVisible(generateBtn);
        await tester.tap(generateBtn);
        await tester.pump(); // Start operation without settling

        expect(aiClient.generateCalls, hasLength(1));

        // While AI is in-flight, user cancels editing / navigates back
        harness.flowController.cancelEditing();
        await tester.pumpAndSettle();

        // Pending Photo B was rolled back
        final slot = harness.currentSlot(onboardingSkinProductsUploadSlot);
        expect(slot?.pendingReplacementAsset, isNull);
        expect(slot?.durableAsset?.assetId, 'asset-photo-a');
        expect(assetRepo.deletedAssetIds, contains('asset-photo-b'));
        expect(r2Client.deletedObjectKeys, contains(photoB.r2Key));

        // Now AI finishes in the background
        routineCompleter.complete(testRoutineResult);
        await tester.pumpAndSettle();

        // Late response was dropped: Plan A blocks and Photo A remain intact
        final currentDraft = harness.currentDraft;
        final skinBlocks = currentDraft.baseTimeline.confirmedBlocksForSection(
          'skin_care',
        );
        expect(skinBlocks.every((b) => b.title.startsWith('Plan A')), isTrue);
        expect(
          currentDraft.baseTimeline.skinCareProductPhotoAssetId,
          'asset-photo-a',
        );
        expect(
          currentDraft.baseTimeline.isSkinCareRoutineCurrent(testUid),
          isTrue,
        );
      },
    );

    test(
      '6. Mid-flight rollback rejects delayed response when requestAssetId (Photo B) != currentSkinPhotoForTransaction() (Photo A)',
      () {
        final draftA = _buildHasProductsPlanADraft(testUid, photoA);
        final slotWithB = UploadSlotRuntimeState(
          slotKey: onboardingSkinProductsUploadSlot,
          purpose: UploadedAssetPurpose.skinProducts,
          phase: UploadInteractionPhase.uploaded,
          durableAsset: photoA,
          pendingReplacementAsset: photoB,
          isDeferredReplacement: true,
        );

        // In-flight request was captured for Photo B
        final requestAsset = currentSkinPhotoForTransaction(
          slot: slotWithB,
          draft: draftA.copyWith(
            baseTimeline: draftA.baseTimeline.copyWith(
              skinCareProductPhotoAssetId: photoB.assetId,
              skinCareProductPhotoR2Key: photoB.r2Key,
            ),
          ),
          purpose: UploadedAssetPurpose.skinProducts,
        );
        expect(requestAsset?.assetId, 'asset-photo-b');

        // Rollback occurs: slot clears pending replacement, draft restores Plan A snapshot
        final slotAfterRollback = slotWithB.copyWith(
          clearPendingReplacementAsset: true,
          clearDeferredReplacement: true,
          phase: UploadInteractionPhase.uploaded,
        );

        final liveAsset = currentSkinPhotoForTransaction(
          slot: slotAfterRollback,
          draft: draftA, // Restored draft with Photo A
          purpose: UploadedAssetPurpose.skinProducts,
        );
        expect(liveAsset?.assetId, 'asset-photo-a');

        // Guard invariant: live asset != request asset
        final matches =
            liveAsset?.assetId == requestAsset?.assetId &&
            liveAsset?.r2Key == requestAsset?.r2Key;
        expect(matches, isFalse);
      },
    );

    testWidgets(
      '7. AI failure with pending Photo B preserves Photo A durable and leaves Photo B pending for retry',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final assetRepo = _PendingTestAssetRepo([photoA]);
        final r2Client = _PendingTestR2Client(signedAssetId: 'asset-photo-b');
        final imageService = _PendingTestImageService(pickedAsset: photoB);
        final aiClient = _PendingTestAiClient(
          productResult: const SkinCareAiProductResult(
            products: [
              {'name': 'Minimalist Gentle Cleanser', 'category': 'cleanser'},
            ],
          ),
          routineResult: SkinCareAiRoutineResult.error(
            'AI routine generation failed for test',
            errorCode: 'error',
          ),
        );

        final initialDraft = _buildHasProductsPlanADraft(testUid, photoA);
        final harness = _TestHarness(
          draft: initialDraft,
          assetRepo: assetRepo,
          r2Client: r2Client,
          imageService: imageService,
          aiClient: aiClient,
        );

        await tester.pumpWidget(harness.buildWidget());
        await tester.pumpAndSettle();

        harness.flowController.startEditing(initialDraft.baseTimeline);
        await tester.pumpAndSettle();

        await replaceSkinPhotoViaUI(tester);

        await tester.ensureVisible(find.text('Read product labels'));
        await tester.tap(find.text('Read product labels'));
        await tester.pumpAndSettle();

        // Tap generate -> returns error
        final generateBtn = find.byKey(
          const ValueKey('onboarding-step7-generate-button'),
        );
        await tester.ensureVisible(generateBtn);
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        // Error is shown
        expect(
          find.textContaining('AI routine generation failed for test'),
          findsOneWidget,
        );

        // Photo A durable preserved, Photo B pending preserved for retry
        final slot = harness.currentSlot(onboardingSkinProductsUploadSlot);
        expect(slot?.durableAsset?.assetId, 'asset-photo-a');
        expect(slot?.pendingReplacementAsset?.assetId, 'asset-photo-b');
        expect(slot?.isDeferredReplacement, isTrue);

        // Photo A was NOT deleted
        expect(assetRepo.deletedAssetIds, isNot(contains('asset-photo-a')));
        expect(r2Client.deletedObjectKeys, isNot(contains(photoA.r2Key)));

        // Plan A blocks in draft preserved
        final skinBlocks = harness.currentDraft.baseTimeline
            .confirmedBlocksForSection('skin_care');
        expect(skinBlocks.every((b) => b.title.startsWith('Plan A')), isTrue);
      },
    );

    testWidgets(
      '8. AI failure then cancel rolls back Photo B and restores Plan A with Photo A',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final assetRepo = _PendingTestAssetRepo([photoA]);
        final r2Client = _PendingTestR2Client(signedAssetId: 'asset-photo-b');
        final imageService = _PendingTestImageService(pickedAsset: photoB);
        final aiClient = _PendingTestAiClient(
          productResult: const SkinCareAiProductResult(
            products: [
              {'name': 'Minimalist Gentle Cleanser', 'category': 'cleanser'},
            ],
          ),
          routineResult: SkinCareAiRoutineResult.error(
            'AI routine generation failed for test',
            errorCode: 'error',
          ),
        );

        final initialDraft = _buildHasProductsPlanADraft(testUid, photoA);
        final harness = _TestHarness(
          draft: initialDraft,
          assetRepo: assetRepo,
          r2Client: r2Client,
          imageService: imageService,
          aiClient: aiClient,
        );

        await tester.pumpWidget(harness.buildWidget());
        await tester.pumpAndSettle();

        harness.flowController.startEditing(initialDraft.baseTimeline);
        await tester.pumpAndSettle();

        await replaceSkinPhotoViaUI(tester);

        await tester.ensureVisible(find.text('Read product labels'));
        await tester.tap(find.text('Read product labels'));
        await tester.pumpAndSettle();

        final generateBtn = find.byKey(
          const ValueKey('onboarding-step7-generate-button'),
        );
        await tester.ensureVisible(generateBtn);
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        // Shell Back cancels rebuild and returns to choice
        harness.flowController.handleBack();
        await tester.pumpAndSettle();

        // Photo B cleaned up
        final slot = harness.currentSlot(onboardingSkinProductsUploadSlot);
        expect(slot?.pendingReplacementAsset, isNull);
        expect(slot?.durableAsset?.assetId, 'asset-photo-a');
        expect(assetRepo.deletedAssetIds, contains('asset-photo-b'));
        expect(r2Client.deletedObjectKeys, contains(photoB.r2Key));

        // Plan A restored: Photo A retained, Plan A blocks retained, controller at choice
        final draft = harness.currentDraft;
        expect(draft.baseTimeline.skinCareProductPhotoAssetId, 'asset-photo-a');
        expect(
          draft.baseTimeline.blocks.any((b) => b.section == 'skin_care'),
          isTrue,
        );
        expect(
          harness.flowController.currentFlowState,
          SkinCareFlowState.choice,
        );
        expect(draft.baseTimeline.isSkinCareRoutineCurrent(testUid), isFalse);
      },
    );

    test(
      '9. Account switch isolation: candidate with mismatched ownerUid is strictly rejected by currentSkinPhotoForTransaction',
      () {
        const victimUid = 'user-victim';
        const attackerUid = 'user-attacker';

        final victimPhoto = photoA.copyWith(
          ownerUid: victimUid,
          r2Key: 'users/$victimUid/onboarding/skin_products/asset-photo-a.jpg',
        );
        final attackerCandidate = photoB.copyWith(
          ownerUid: attackerUid,
          r2Key:
              'users/$attackerUid/onboarding/skin_products/asset-photo-b.jpg',
        );

        final draftVictim = OnboardingDraft(
          uid: victimUid,
          currentStep: 7,
          baseTimeline: BaseTimelineDraft(
            skinCareSetupPath: 'has_products',
            skinCareProductPhotoAssetId: victimPhoto.assetId,
            skinCareProductPhotoR2Key: victimPhoto.r2Key,
            skinCareProductPhotoStatus: 'uploaded',
            skinCareProductPhotoCreatedAt: victimPhoto.createdAt,
            skinCareProductPhotoUpdatedAt: victimPhoto.updatedAt,
          ),
        );

        final maliciousSlot = UploadSlotRuntimeState(
          slotKey: onboardingSkinProductsUploadSlot,
          purpose: UploadedAssetPurpose.skinProducts,
          phase: UploadInteractionPhase.uploaded,
          durableAsset: victimPhoto,
          pendingReplacementAsset: attackerCandidate,
          isDeferredReplacement: true,
        );

        // Candidate has ownerUid != draft.uid
        final resolved = currentSkinPhotoForTransaction(
          slot: maliciousSlot,
          draft: draftVictim,
          purpose: UploadedAssetPurpose.skinProducts,
        );

        // Must reject attacker candidate and fall back to durable victim photo
        expect(resolved, isNotNull);
        expect(resolved?.ownerUid, victimUid);
        expect(resolved?.assetId, victimPhoto.assetId);
        expect(resolved?.assetId, isNot(attackerCandidate.assetId));

        // If draft has empty uid, must return null
        final emptyUidDraft = draftVictim.copyWith(uid: '   ');
        final resolvedEmpty = currentSkinPhotoForTransaction(
          slot: maliciousSlot,
          draft: emptyUidDraft,
          purpose: UploadedAssetPurpose.skinProducts,
        );
        expect(resolvedEmpty, isNull);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test Data & Harness
// ---------------------------------------------------------------------------

OnboardingDraft _buildHasProductsPlanADraft(String uid, UploadedAsset photo) {
  final base = BaseTimelineDraft(
    skinCareSetupPath: 'has_products',
    skinCareSetupStep: 1,
    skinCareProductNames: 'Minimalist Gentle Cleanser',
    skinCareProductPhotoAssetId: photo.assetId,
    skinCareProductPhotoR2Key: photo.r2Key,
    skinCareProductPhotoStatus: 'uploaded',
    skinCareProductPhotoCreatedAt: photo.createdAt,
    skinCareProductPhotoUpdatedAt: photo.updatedAt,
    skinCareReviewedProducts: const [
      SkinCareDetectedProduct(
        name: 'Minimalist Gentle Cleanser',
        brand: 'Minimalist',
        category: 'cleanser',
      ),
    ],
    skinCareDesiredApplicationsPerDay: 2,
    blocks: [
      BaseTimelineDraft.defaultBathBlock(),
      TimelineBlockDraft(
        id: 'plan-a-block-1',
        title: 'Plan A Morning',
        startMinute: 480,
        endMinute: 495,
        repeatDays: onboarding7EveryDay,
        section: 'skin_care',
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: const ['Minimalist Gentle Cleanser'],
        skincareSteps: const ['Cleanse'],
      ),
      TimelineBlockDraft(
        id: 'plan-a-block-2',
        title: 'Plan A Night',
        startMinute: 1260,
        endMinute: 1275,
        repeatDays: onboarding7EveryDay,
        section: 'skin_care',
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: const ['Minimalist Gentle Cleanser'],
        skincareSteps: const ['Cleanse'],
      ),
    ],
  );

  final routineFp = base.computeSkinCareRoutineFingerprint();
  final taggedBlocks = base.blocks.map((b) {
    if (b.section != 'skin_care') return b;
    return b.copyWith(
      provenanceSourceIds: [
        'skin-care-generation:$routineFp',
        photo.assetId,
        photo.r2Key,
      ],
    );
  }).toList();

  return OnboardingDraft(
    uid: uid,
    currentStep: 7,
    welcomeSaved: true,
    patiencePledgeAccepted: true,
    stepCompleted: List.generate(OnboardingDraft.stepCount, (i) => i < 7),
    baseTimeline: base.copyWith(
      skinCareRoutineFingerprint: routineFp,
      blocks: taggedBlocks,
    ),
  );
}

OnboardingDraft _buildNoProductsPlanADraft(
  String uid,
  UploadedAsset facePhoto,
) {
  final base = BaseTimelineDraft(
    skinCareSetupPath: 'no_products',
    skinCareSetupStep: 1,
    skinCareSkinType: 'oily',
    skinCareProblems: const ['pimples'],
    skinCareBudget: 'medium',
    skinCareDesiredApplicationsPerDay: 2,
    skinCareFacePhotoAssetId: facePhoto.assetId,
    skinCareFacePhotoR2Key: facePhoto.r2Key,
    skinCareFacePhotoStatus: 'uploaded',
    skinCareFacePhotoCreatedAt: facePhoto.createdAt,
    skinCareFacePhotoUpdatedAt: facePhoto.updatedAt,
    skinCareSelectedProductNames: const ['Minimalist Gentle Cleanser'],
    skinCareSuggestedProducts: const ['Minimalist Gentle Cleanser'],
    skinCareProductRecommendations: const [
      SkinCareProductRecommendationDraft(
        name: 'Minimalist Gentle Cleanser',
        brand: 'Minimalist',
        category: 'cleanser',
        estimatedPrice: '299',
        currencyCode: 'INR',
        reason: 'Gentle',
      ),
    ],
    blocks: [
      BaseTimelineDraft.defaultBathBlock(),
      TimelineBlockDraft(
        id: 'plan-a-face-1',
        title: 'Plan A Morning',
        startMinute: 480,
        endMinute: 495,
        repeatDays: onboarding7EveryDay,
        section: 'skin_care',
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: const ['Minimalist Gentle Cleanser'],
        skincareSteps: const ['Cleanse'],
      ),
      TimelineBlockDraft(
        id: 'plan-a-face-2',
        title: 'Plan A Night',
        startMinute: 1260,
        endMinute: 1275,
        repeatDays: onboarding7EveryDay,
        section: 'skin_care',
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: const ['Minimalist Gentle Cleanser'],
        skincareSteps: const ['Cleanse'],
      ),
    ],
  );

  final recFp = base.computeSkinCareRecommendationFingerprint();
  final withRec = base.copyWith(skinCareRecommendationFingerprint: recFp);
  final routineFp = withRec.computeSkinCareRoutineFingerprint();
  final taggedBlocks = withRec.blocks.map((b) {
    if (b.section != 'skin_care') return b;
    return b.copyWith(
      provenanceSourceIds: [
        'skin-care-generation:$routineFp',
        facePhoto.assetId,
        facePhoto.r2Key,
      ],
    );
  }).toList();

  return OnboardingDraft(
    uid: uid,
    currentStep: 7,
    welcomeSaved: true,
    patiencePledgeAccepted: true,
    stepCompleted: List.generate(OnboardingDraft.stepCount, (i) => i < 7),
    baseTimeline: withRec.copyWith(
      skinCareRoutineFingerprint: routineFp,
      blocks: taggedBlocks,
    ),
  );
}

OnboardingDraft _buildNoProductsWithRecsDraft(
  String uid,
  UploadedAsset facePhoto,
) {
  final base = BaseTimelineDraft(
    skinCareSetupPath: 'no_products',
    skinCareSetupStep: 1,
    skinCareSkinType: 'oily',
    skinCareProblems: const ['pimples'],
    skinCareBudget: 'medium',
    skinCareDesiredApplicationsPerDay: 2,
    skinCareFacePhotoAssetId: facePhoto.assetId,
    skinCareFacePhotoR2Key: facePhoto.r2Key,
    skinCareFacePhotoStatus: 'uploaded',
    skinCareFacePhotoCreatedAt: facePhoto.createdAt,
    skinCareFacePhotoUpdatedAt: facePhoto.updatedAt,
    skinCareSelectedProductNames: const [
      'Minimalist Gentle Cleanser',
      'Minimalist Barrier Moisturizer',
      'Minimalist SPF 50 Sunscreen',
    ],
    skinCareSuggestedProducts: const [
      'Minimalist Gentle Cleanser',
      'Minimalist Barrier Moisturizer',
      'Minimalist SPF 50 Sunscreen',
    ],
    skinCareProductRecommendations: const [
      SkinCareProductRecommendationDraft(
        name: 'Minimalist Gentle Cleanser',
        brand: 'Minimalist',
        category: 'cleanser',
        estimatedPrice: '299',
        currencyCode: 'INR',
        reason: 'Gentle',
      ),
      SkinCareProductRecommendationDraft(
        name: 'Minimalist Barrier Moisturizer',
        brand: 'Minimalist',
        category: 'moisturizer',
        estimatedPrice: '349',
        currencyCode: 'INR',
        reason: 'Moisturizes',
      ),
      SkinCareProductRecommendationDraft(
        name: 'Minimalist SPF 50 Sunscreen',
        brand: 'Minimalist',
        category: 'sunscreen',
        estimatedPrice: '399',
        currencyCode: 'INR',
        reason: 'Protects',
      ),
    ],
    blocks: [
      BaseTimelineDraft.defaultBathBlock(),
      TimelineBlockDraft(
        id: 'plan-a-face-1',
        title: 'Plan A Morning',
        startMinute: 480,
        endMinute: 495,
        repeatDays: onboarding7EveryDay,
        section: 'skin_care',
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: const ['Minimalist Gentle Cleanser'],
        skincareSteps: const ['Cleanse'],
      ),
      TimelineBlockDraft(
        id: 'plan-a-face-2',
        title: 'Plan A Night',
        startMinute: 1260,
        endMinute: 1275,
        repeatDays: onboarding7EveryDay,
        section: 'skin_care',
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: const ['Minimalist Gentle Cleanser'],
        skincareSteps: const ['Cleanse'],
      ),
    ],
  );

  final recFp = base.computeSkinCareRecommendationFingerprint();
  final withRec = base.copyWith(skinCareRecommendationFingerprint: recFp);
  final routineFp = withRec.computeSkinCareRoutineFingerprint();
  final taggedBlocks = withRec.blocks.map((b) {
    if (b.section != 'skin_care') return b;
    return b.copyWith(
      provenanceSourceIds: [
        'skin-care-generation:$routineFp',
        facePhoto.assetId,
        facePhoto.r2Key,
      ],
    );
  }).toList();

  return OnboardingDraft(
    uid: uid,
    currentStep: 7,
    welcomeSaved: true,
    patiencePledgeAccepted: true,
    stepCompleted: List.generate(OnboardingDraft.stepCount, (i) => i < 7),
    baseTimeline: withRec.copyWith(
      skinCareRoutineFingerprint: routineFp,
      blocks: taggedBlocks,
    ),
  );
}

class _TestHarness {
  final OnboardingDraft draft;
  final _PendingTestAssetRepo assetRepo;
  final _PendingTestR2Client r2Client;
  final _PendingTestImageService imageService;
  final _PendingTestAiClient aiClient;
  late final ProviderContainer container;

  _TestHarness({
    required this.draft,
    required this.assetRepo,
    required this.r2Client,
    required this.imageService,
    required this.aiClient,
  }) {
    final notifier = OnboardingNotifier()..loadSeedData(draft);
    container = ProviderContainer(
      overrides: [
        onboardingStateProvider.overrideWith((ref) => notifier),
        authProvider.overrideWith(
          (ref) => _PendingTestAuthNotifier(
            AuthUser(
              uid: draft.uid,
              email: 'tester@optivus.dev',
              emailVerified: true,
            ),
          ),
        ),
        authRepositoryProvider.overrideWithValue(
          _PendingTestAuthRepo(
            currentUser: AuthUser(
              uid: draft.uid,
              email: 'tester@optivus.dev',
              emailVerified: true,
            ),
          ),
        ),
        uploadedAssetRepositoryProvider.overrideWithValue(assetRepo),
        r2UploadClientProvider.overrideWithValue(r2Client),
        imagePrepareServiceProvider.overrideWithValue(imageService),
        skinCareAiClientProvider.overrideWithValue(aiClient),
        deviceCountryServiceProvider.overrideWithValue(
          const _FakeDeviceCountryService(),
        ),
      ],
    );

    // Sync initial durable assets with upload interaction provider
    final durableProduct = durableSkinProductsAssetFromDraft(draft);
    final durableFace = durableSkinFaceAssetFromDraft(draft);
    final restoredMap = <UploadedAssetPurpose, RestoredUploadedAsset>{};
    if (durableProduct != null) {
      restoredMap[UploadedAssetPurpose.skinProducts] = RestoredUploadedAsset(
        asset: durableProduct,
      );
    }
    if (durableFace != null) {
      restoredMap[UploadedAssetPurpose.skinFace] = RestoredUploadedAsset(
        asset: durableFace,
      );
    }
    container
        .read(onboardingUploadInteractionProvider.notifier)
        .syncWithDurableState(
          RestoredUploadsState(assetsByPurpose: restoredMap),
          uid: draft.uid,
        );
  }

  SkinCareFlowController get flowController =>
      container.read(skinCareFlowControllerProvider.notifier);

  UploadInteractionController get uploadController =>
      container.read(onboardingUploadInteractionProvider.notifier);

  OnboardingDraft get currentDraft =>
      container.read(onboardingStateProvider).draft;

  UploadSlotRuntimeState? currentSlot(String slotKey) =>
      container.read(onboardingUploadInteractionProvider)[slotKey];

  Widget buildWidget() {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: OnboardingStep7())),
    );
  }
}

// ---------------------------------------------------------------------------
// Test Fakes & Mocks
// ---------------------------------------------------------------------------

class _PendingTestAssetRepo implements UploadedAssetRepository {
  final List<UploadedAsset> assets;
  final List<String> deletedAssetIds = [];

  _PendingTestAssetRepo([List<UploadedAsset>? initial])
    : assets = initial ?? [];

  @override
  Future<UploadedAsset?> fetchAsset({
    required String uid,
    required String assetId,
  }) async {
    return assets
        .where((a) => a.ownerUid == uid && a.assetId == assetId)
        .firstOrNull;
  }

  @override
  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 20,
  }) async {
    return assets.where((a) {
      if (a.ownerUid != uid) return false;
      if (sourceFeature != null && a.sourceFeature != sourceFeature) {
        return false;
      }
      if (purpose != null && a.purpose != purpose) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> saveAsset(UploadedAsset asset) async {
    assets.removeWhere(
      (a) => a.ownerUid == asset.ownerUid && a.assetId == asset.assetId,
    );
    assets.add(asset);
  }

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {
    deletedAssetIds.add(assetId);
    assets.removeWhere((a) => a.ownerUid == uid && a.assetId == assetId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingTestR2Client implements R2UploadClient {
  final String signedAssetId;
  final List<String> deletedObjectKeys = [];

  _PendingTestR2Client({this.signedAssetId = 'asset-photo-b'});

  @override
  Future<R2SignedUpload> signUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    required String contentType,
    required int sizeBytes,
    required String idToken,
  }) async {
    return R2SignedUpload(
      assetId: signedAssetId,
      objectKey:
          'users/$uid/$sourceFeature/${purpose.wireName}/$signedAssetId.jpg',
      uploadUrl: 'https://r2.optivus.dev/upload',
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
  }) async {}

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    deletedObjectKeys.add(objectKey);
  }

  @override
  Future<String> getPreviewUrl({
    required String objectKey,
    required String idToken,
  }) async => 'https://preview.local/$objectKey';
}

class _PendingTestImageService extends ImagePrepareService {
  final UploadedAsset pickedAsset;

  _PendingTestImageService({required this.pickedAsset});

  @override
  Future<XFile?> pickImageFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    return XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: pickedAsset.fileName,
      mimeType: pickedAsset.contentType,
    );
  }

  @override
  Future<PreparedUploadImage?> preparePickedFile(
    XFile? picked, {
    UploadedAssetPurpose purpose = UploadedAssetPurpose.skinProducts,
  }) async {
    if (picked == null) return null;
    return PreparedUploadImage(
      fileName: pickedAsset.fileName,
      contentType: pickedAsset.contentType,
      bytes: Uint8List.fromList([1, 2, 3]),
      sizeBytes: pickedAsset.sizeBytes,
    );
  }
}

class _PendingTestAuthRepo implements AuthRepository {
  @override
  final AuthUser? currentUser;

  _PendingTestAuthRepo({this.currentUser});

  @override
  Future<String?> currentIdToken() async => 'test-id-token';

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(currentUser);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingTestAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _PendingTestAuthNotifier(AuthUser? user)
    : super(
        AuthState(
          user: user,
          status: AuthFlowStatus.signedInOnboardingIncomplete,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingTestAiClient implements SkinCareAiClient {
  final SkinCareAiProductResult productResult;
  SkinCareAiRoutineResult routineResult;
  final Completer<SkinCareAiRoutineResult>? routineCompleter;
  final List<SkinCareAiRoutineResult> _queuedRoutineResults = [];

  int analyzeCalls = 0;
  List<String>? lastProductPhotos;
  final List<Map<String, dynamic>> generateCalls = [];

  _PendingTestAiClient({
    this.productResult = const SkinCareAiProductResult(products: []),
    this.routineResult = const SkinCareAiRoutineResult(
      morningRoutine: [],
      nightRoutine: [],
      weeklyRoutine: [],
      timelineBlocks: [],
    ),
    this.routineCompleter,
  });

  void queueRoutineResult(SkinCareAiRoutineResult result) {
    _queuedRoutineResults.add(result);
  }

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async {
    analyzeCalls++;
    lastProductPhotos = productPhotos;
    return productResult;
  }

  @override
  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    generateCalls.add(params);
    if (routineCompleter != null) {
      return routineCompleter!.future;
    }
    if (_queuedRoutineResults.isNotEmpty) {
      return _queuedRoutineResults.removeAt(0);
    }
    return routineResult;
  }
}

class _FakeDeviceCountryService
    implements DeviceCountryService, PermissionAwareDeviceCountryService {
  const _FakeDeviceCountryService();

  @override
  Future<DeviceCountry?> detectCountry() async => const DeviceCountry(
    countryCode: 'IN',
    countryName: 'India',
    fromDeviceLocation: true,
  );

  @override
  Future<DeviceCountry?> detectCountryIfPermissionGranted() async =>
      detectCountry();
}
