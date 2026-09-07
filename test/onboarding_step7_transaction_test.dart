import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/skin_care_product_draft.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_controller.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_state.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/state/app_state.dart';

TimelineBlockDraft _bathBlock() => BaseTimelineDraft.defaultBathBlock();

List<TimelineBlockDraft> _fullWeekSkinBlocks(
  int count, {
  String prefix = 'Plan A',
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
      skincareProducts: const ['Minimalist Gentle Cleanser'],
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

      final notifier = MockOnboardingNotifier()..loadSeedData(draft);
      container = ProviderContainer(
        overrides: [mockOnboardingProvider.overrideWith((ref) => notifier)],
      );
    });

    tearDown(() => container.dispose());

    test('Initial state has Plan A routine blocks and is current', () {
      final base = container.read(mockOnboardingProvider).draft.baseTimeline;
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
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline;

      controller.startEditing(baseBefore);

      final baseAfter = container
          .read(mockOnboardingProvider)
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
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline;

      controller.startEditing(baseBefore);
      controller.cancelEditing();

      final baseAfter = container
          .read(mockOnboardingProvider)
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
            .read(mockOnboardingProvider)
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
            .read(mockOnboardingProvider.notifier)
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
            .read(mockOnboardingProvider)
            .draft
            .baseTimeline;
        expect(dirtyBase.isSkinCareRoutineCurrent(testUid), isFalse);

        // Cancel editing restores Plan A snapshot onto draft
        controller.cancelEditing();

        final restoredBase = container
            .read(mockOnboardingProvider)
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
            .read(mockOnboardingProvider)
            .draft
            .baseTimeline;

        controller.startEditing(baseBefore);

        // Mutate inputs during edit
        container
            .read(mockOnboardingProvider.notifier)
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
            .read(mockOnboardingProvider)
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
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline;

      controller.startEditing(baseBefore);

      // Simulate a failure during generation: controller transitions with error
      controller.transitionTo(
        SkinCareFlowState.noProductsEditing,
        error: 'AI generation timed out',
      );

      final baseAfter = container
          .read(mockOnboardingProvider)
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
            .read(mockOnboardingProvider)
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
            .read(mockOnboardingProvider.notifier)
            .updateDraft((d) => d.copyWith(baseTimeline: updatedBase));
        controller.commitRebuildSuccess(updatedBase);

        final finalBase = container
            .read(mockOnboardingProvider)
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
            .read(mockOnboardingProvider)
            .draft
            .baseTimeline;

        expect(baseBefore.isSkinCareRoutineCurrent(testUid), isTrue);

        // Enter rebuild/edit
        controller.startEditing(baseBefore);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.noProductsEditing,
        );

        // Change details and trigger find products
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

        container.read(mockOnboardingProvider.notifier).updateDraft((d) {
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
        expect(stateAfterFind.planASnapshot, isNotNull);

        // Plan A blocks are still preserved in draft
        final currentBase = container
            .read(mockOnboardingProvider)
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
            .read(mockOnboardingProvider)
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
          ..._fullWeekSkinBlocks(2, prefix: 'HP Plan A'),
        ], hpRoutineFp);
        hpBase = hpBase.copyWith(
          skinCareRoutineFingerprint: hpRoutineFp,
          blocks: hpBlocks,
        );

        container
            .read(mockOnboardingProvider.notifier)
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
            .read(mockOnboardingProvider.notifier)
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
            .read(mockOnboardingProvider)
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
}
