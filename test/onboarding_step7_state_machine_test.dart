import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/skin_care_product_draft.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_state.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_controller.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';

TimelineBlockDraft _bathBlock() => BaseTimelineDraft.defaultBathBlock();

TimelineBlockDraft _skinBlock(int day, String title) => TimelineBlockDraft(
  id: 'block-$day-$title',
  title: title,
  startMinute: 480,
  endMinute: 495,
  section: 'skin_care',
  repeatDays: onboarding7EveryDay,
  blockType: TimelineBlockDraft.softBlockKey,
  skincareProducts: const ['Gentle Cleanser'],
  skincareSteps: const ['Apply and rinse'],
);

List<TimelineBlockDraft> _fullWeekSkinBlocks(int timesPerDay) {
  final blocks = <TimelineBlockDraft>[];
  for (var day = 1; day <= 7; day++) {
    for (var slot = 0; slot < timesPerDay; slot++) {
      blocks.add(_skinBlock(day, 'Slot $slot'));
    }
  }
  return blocks;
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

void main() {
  const testUid = 'user-test-uid';

  group('Step 7 Skin Care State Machine - pure derivation', () {
    test('Empty / initial baseTimeline derives choice state', () {
      const base = BaseTimelineDraft();
      expect(deriveSkinCareFlowState(base, testUid), SkinCareFlowState.choice);
    });

    test('skinCareSkipped derives skipped state', () {
      const base = BaseTimelineDraft(skinCareSkipped: true);
      expect(deriveSkinCareFlowState(base, testUid), SkinCareFlowState.skipped);
    });

    test('setupPath skip derives skipped state', () {
      const base = BaseTimelineDraft(skinCareSetupPath: 'skip');
      expect(deriveSkinCareFlowState(base, testUid), SkinCareFlowState.skipped);
    });

    test('has_products with no routine derives hasProductsInput', () {
      final base = const BaseTimelineDraft().copyWith(
        skinCareSetupPath: 'has_products',
        skinCareSetupStep: 1,
        skinCareProductNames: 'Cleanser, Moisturizer',
      );
      expect(
        deriveSkinCareFlowState(base, testUid),
        SkinCareFlowState.hasProductsInput,
      );
    });

    test('has_products with complete routine derives hasProductsReview', () {
      var base = const BaseTimelineDraft().copyWith(
        skinCareSetupPath: 'has_products',
        skinCareSetupStep: 1,
        skinCareProductNames: 'Cleanser, Moisturizer',
        blocks: [_bathBlock(), ..._fullWeekSkinBlocks(2)],
      );
      base = base.copyWith(
        skinCareRoutineFingerprint: base.computeSkinCareRoutineFingerprint(),
      );
      expect(
        deriveSkinCareFlowState(base, testUid),
        SkinCareFlowState.hasProductsReview,
      );
    });

    test('no_products without recommendations derives noProductsInput', () {
      final base = const BaseTimelineDraft().copyWith(
        skinCareSetupPath: 'no_products',
        skinCareSetupStep: 1,
        skinCareSkinType: 'dry',
        skinCareProblems: const ['dryness'],
      );
      expect(
        deriveSkinCareFlowState(base, testUid),
        SkinCareFlowState.noProductsInput,
      );
    });

    test(
      'no_products with recommendations and no routine derives noProductsProductSelection',
      () {
        var base = const BaseTimelineDraft().copyWith(
          skinCareSetupPath: 'no_products',
          skinCareSetupStep: 1,
          skinCareSkinType: 'dry',
          skinCareProductRecommendations: const [
            SkinCareProductRecommendationDraft(
              category: 'cleanser',
              brand: 'Brand',
              name: 'Gentle Cleanser',
            ),
          ],
        );
        base = base.copyWith(
          skinCareRecommendationFingerprint: base
              .computeSkinCareRecommendationFingerprint(),
        );
        expect(
          deriveSkinCareFlowState(base, testUid),
          SkinCareFlowState.noProductsProductSelection,
        );
      },
    );

    test('no_products with routine derives noProductsReview', () {
      var base = const BaseTimelineDraft().copyWith(
        skinCareSetupPath: 'no_products',
        skinCareSetupStep: 1,
        skinCareSkinType: 'dry',
        skinCareBudget: 'medium',
        skinCareDesiredApplicationsPerDay: 2,
        skinCareProductRecommendations: const [
          SkinCareProductRecommendationDraft(
            category: 'cleanser',
            brand: 'Brand',
            name: 'Gentle Cleanser',
          ),
        ],
        blocks: [_bathBlock(), ..._fullWeekSkinBlocks(2)],
      );
      base = base.copyWith(
        skinCareRoutineFingerprint: base.computeSkinCareRoutineFingerprint(),
      );
      expect(
        deriveSkinCareFlowState(base, testUid),
        SkinCareFlowState.noProductsReview,
      );
    });
  });

  group('SkinCareFlowController - State transitions & Back navigation', () {
    late ProviderContainer container;

    setUp(() {
      final notifier = OnboardingNotifier()
        ..loadSeedData(
          OnboardingDraft(
            uid: testUid,
            currentStep: 7,
            baseTimeline: const BaseTimelineDraft(),
          ),
        );
      container = ProviderContainer(
        overrides: [onboardingStateProvider.overrideWith((ref) => notifier)],
      );
    });

    tearDown(() => container.dispose());

    test('Initial state is choice and handleBack returns false', () {
      final controller = container.read(
        skinCareFlowControllerProvider.notifier,
      );
      final state = container.read(skinCareFlowControllerProvider);

      expect(state.state, SkinCareFlowState.choice);
      expect(state.epoch, 0);
      expect(controller.canHandleBack, isFalse);
      expect(controller.handleBack(), isFalse);
    });

    test(
      'Transition to hasProductsInput enables handleBack to return to choice',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );
        controller.transitionTo(SkinCareFlowState.hasProductsInput);

        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.hasProductsInput,
        );
        expect(controller.canHandleBack, isTrue);

        final handled = controller.handleBack();
        expect(handled, isTrue);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.choice,
        );
      },
    );

    test(
      'noProductsProductSelection handleBack returns to noProductsInput',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );
        controller.transitionTo(SkinCareFlowState.noProductsProductSelection);

        final handled = controller.handleBack();
        expect(handled, isTrue);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.noProductsInput,
        );
      },
    );

    test(
      'startEditing captures Plan A snapshot and transitions to editing',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );
        final base = const BaseTimelineDraft().copyWith(
          skinCareSetupPath: 'no_products',
          skinCareBudget: 'medium',
          skinCareDesiredApplicationsPerDay: 2,
        );

        controller.startEditing(base);
        final state = container.read(skinCareFlowControllerProvider);
        expect(state.state, SkinCareFlowState.noProductsEditing);
        expect(state.planASnapshot, isNotNull);
        expect(state.planASnapshot!.budget, 'medium');
        expect(state.planASnapshot!.desiredApplicationsPerDay, 2);

        // Canceling editing returns to review mode and clears snapshot
        controller.cancelEditing();
        final afterCancel = container.read(skinCareFlowControllerProvider);
        expect(afterCancel.state, SkinCareFlowState.noProductsReview);
        expect(afterCancel.planASnapshot, isNull);
      },
    );

    test('Back during has-products rebuild returns to choice', () {
      final controller = container.read(
        skinCareFlowControllerProvider.notifier,
      );
      final base = const BaseTimelineDraft().copyWith(
        skinCareSetupPath: 'has_products',
      );

      controller.startEditing(base);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.hasProductsEditing,
      );

      final handled = controller.handleBack();
      expect(handled, isTrue);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.choice,
      );
    });

    test('Back during review enters rebuild without clearing blocks', () {
      final controller = container.read(
        skinCareFlowControllerProvider.notifier,
      );
      container
          .read(onboardingStateProvider.notifier)
          .updateDraft(
            (d) => d.copyWith(
              baseTimeline: d.baseTimeline.copyWith(
                skinCareSetupPath: 'has_products',
                skinCareSetupStep: 2,
                blocks: [_skinBlock(1, 'Routine Block')],
              ),
            ),
          );

      controller.transitionTo(SkinCareFlowState.hasProductsReview);
      final handled = controller.handleBack();
      expect(handled, isTrue);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.hasProductsEditing,
      );

      // Blocks are preserved
      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      expect(base.blocks, isNotEmpty);
      expect(base.skinCareSetupStep, 1);
      expect(
        deriveSkinCareFlowState(base, testUid),
        SkinCareFlowState.hasProductsInput,
      );
    });

    test('startGeneration bumps epoch and records generationOrigin', () {
      final controller = container.read(
        skinCareFlowControllerProvider.notifier,
      );
      final initialEpoch = controller.currentEpoch;

      controller.transitionTo(SkinCareFlowState.hasProductsEditing);
      final editingEpoch = controller.currentEpoch;
      expect(editingEpoch, initialEpoch + 1);

      controller.startGeneration(SkinCareFlowState.hasProductsGenerating);
      final genEpoch = controller.currentEpoch;
      expect(genEpoch, editingEpoch + 1);
      expect(
        container.read(skinCareFlowControllerProvider).generationOrigin,
        SkinCareFlowState.hasProductsEditing,
      );

      // Failing generation restores state to origin (hasProductsEditing)
      controller.failGeneration('Timeout occurred');
      final failState = container.read(skinCareFlowControllerProvider);
      expect(failState.state, SkinCareFlowState.hasProductsEditing);
      expect(failState.activeError, 'Timeout occurred');
      expect(failState.generationOrigin, isNull);
    });

    test(
      'Back during generation bumps epoch to invalidate in-flight request',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );
        controller.transitionTo(SkinCareFlowState.hasProductsInput);
        controller.startGeneration(SkinCareFlowState.hasProductsGenerating);
        final inFlightEpoch = controller.currentEpoch;

        final handled = controller.handleBack();
        expect(handled, isTrue);
        expect(controller.currentEpoch, greaterThan(inFlightEpoch));
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.hasProductsInput,
        );
      },
    );

    test(
      'Exact null-optional rollback restores null fields and routine currentness',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );

        // Valid has-products Plan A with null optional fields
        var base = const BaseTimelineDraft().copyWith(
          skinCareSetupPath: 'has_products',
          skinCareSetupStep: 1,
          skinCareProductNames: 'Gentle Cleanser',
          skinCareReviewedProducts: const [
            SkinCareDetectedProduct(name: 'Gentle Cleanser'),
          ],
        );
        final fp = base.computeSkinCareRoutineFingerprint();
        final taggedBlocks = _tagBlocks([
          _bathBlock(),
          ..._fullWeekSkinBlocks(2),
        ], fp);
        base = base.copyWith(
          skinCareRoutineFingerprint: fp,
          blocks: taggedBlocks,
        );

        container
            .read(onboardingStateProvider.notifier)
            .updateDraft((d) => d.copyWith(baseTimeline: base));

        expect(base.skinCareSkinType, isNull);
        expect(base.skinCareBudget, isNull);
        expect(base.skinCarePreference, isNull);
        expect(base.isSkinCareRoutineCurrent(testUid), isTrue);

        // Start editing: snapshot has null optional fields
        controller.startEditing(base);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.hasProductsEditing,
        );

        // Mutate optional fields to non-null values
        container
            .read(onboardingStateProvider.notifier)
            .updateDraft(
              (d) => d.copyWith(
                baseTimeline: d.baseTimeline.copyWith(
                  skinCareSkinType: 'oily',
                  skinCareBudget: 'high',
                  skinCarePreference: 'balanced',
                ),
              ),
            );

        final dirtyBase = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;
        expect(dirtyBase.skinCareSkinType, 'oily');
        expect(dirtyBase.isSkinCareRoutineCurrent(testUid), isFalse);

        // Cancel editing: must restore exact null values
        controller.cancelEditing();

        final restoredBase = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline;
        expect(restoredBase.skinCareSkinType, isNull);
        expect(restoredBase.skinCareBudget, isNull);
        expect(restoredBase.skinCarePreference, isNull);
        expect(restoredBase.skinCareRoutineFingerprint, fp);
        expect(restoredBase.isSkinCareRoutineCurrent(testUid), isTrue);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.hasProductsReview,
        );
      },
    );

    test('handleBack during edit mode restores exact null optional fields', () {
      final controller = container.read(
        skinCareFlowControllerProvider.notifier,
      );

      var base = const BaseTimelineDraft().copyWith(
        skinCareSetupPath: 'has_products',
        skinCareSetupStep: 1,
        skinCareProductNames: 'Gentle Cleanser',
        skinCareReviewedProducts: const [
          SkinCareDetectedProduct(name: 'Gentle Cleanser'),
        ],
      );
      final fp = base.computeSkinCareRoutineFingerprint();
      final taggedBlocks = _tagBlocks([
        _bathBlock(),
        ..._fullWeekSkinBlocks(2),
      ], fp);
      base = base.copyWith(
        skinCareRoutineFingerprint: fp,
        blocks: taggedBlocks,
      );

      container
          .read(onboardingStateProvider.notifier)
          .updateDraft((d) => d.copyWith(baseTimeline: base));

      controller.startEditing(base);

      container
          .read(onboardingStateProvider.notifier)
          .updateDraft(
            (d) => d.copyWith(
              baseTimeline: d.baseTimeline.copyWith(
                skinCareSkinType: 'dry',
                skinCareBudget: 'low',
                skinCarePreference: 'active',
              ),
            ),
          );

      final handled = controller.handleBack();
      expect(handled, isTrue);

      final restoredBase = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline;
      expect(restoredBase.skinCareSkinType, isNull);
      expect(restoredBase.skinCareBudget, isNull);
      expect(restoredBase.skinCarePreference, isNull);
      expect(restoredBase.isSkinCareRoutineCurrent(testUid), isFalse);
      expect(restoredBase.skinCareSetupStep, 0);
    });

    test(
      'Skip -> Back is durable and survives subsequent draft updates and cold derivation',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );

        // Setup skipped state
        container
            .read(onboardingStateProvider.notifier)
            .updateDraft(
              (d) => d.copyWith(
                baseTimeline: d.baseTimeline.copyWith(
                  skinCareSetupPath: 'skip',
                  skinCareSetupStep: 1,
                  skinCareSkipped: true,
                ),
              ),
            );

        controller.transitionTo(SkinCareFlowState.skipped);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.skipped,
        );

        // Tap Back from skipped
        final handled = controller.handleBack();
        expect(handled, isTrue);
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.choice,
        );

        final draftAfterBack = container.read(onboardingStateProvider).draft;
        expect(draftAfterBack.baseTimeline.skinCareSkipped, isFalse);
        expect(draftAfterBack.baseTimeline.skinCareSetupPath, isNull);
        expect(draftAfterBack.baseTimeline.skinCareSetupStep, 0);

        // An unrelated draft update must not revert back to skipped
        container
            .read(onboardingStateProvider.notifier)
            .updateDraft((d) => d.copyWith(welcomeSaved: true));
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.choice,
        );

        // Cold derivation also reconstructs choice
        final derived = deriveSkinCareFlowState(
          container.read(onboardingStateProvider).draft.baseTimeline,
          testUid,
        );
        expect(derived, SkinCareFlowState.choice);
      },
    );

    test(
      'User A editing -> User B account switch discards User A transient state',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );

        var baseA = const BaseTimelineDraft().copyWith(
          skinCareSetupPath: 'has_products',
          skinCareSetupStep: 1,
          skinCareProductNames: 'User A Products',
          blocks: [_bathBlock(), ..._fullWeekSkinBlocks(2)],
        );
        baseA = baseA.copyWith(
          skinCareRoutineFingerprint: baseA.computeSkinCareRoutineFingerprint(),
        );

        container
            .read(onboardingStateProvider.notifier)
            .updateDraft((d) => d.copyWith(uid: 'user-a', baseTimeline: baseA));
        controller.syncFromDraft(baseA, 'user-a', authGeneration: 1);

        controller.startEditing(baseA);
        final editingState = container.read(skinCareFlowControllerProvider);
        expect(editingState.state, SkinCareFlowState.hasProductsEditing);
        expect(editingState.ownerUid, 'user-a');
        expect(editingState.planASnapshot, isNotNull);

        // Switch to User B (different UID and authGeneration)
        final baseB = const BaseTimelineDraft(); // User B has no setup yet
        controller.syncFromDraft(baseB, 'user-b', authGeneration: 2);

        final stateB = container.read(skinCareFlowControllerProvider);
        expect(stateB.state, SkinCareFlowState.choice);
        expect(stateB.ownerUid, 'user-b');
        expect(stateB.authGeneration, 2);
        expect(stateB.planASnapshot, isNull);
      },
    );

    test(
      'completeGeneration routes intermediate generations correctly based on origin',
      () {
        final controller = container.read(
          skinCareFlowControllerProvider.notifier,
        );

        // 1. Rebuild no-products: origin is noProductsEditing
        controller.transitionTo(SkinCareFlowState.noProductsEditing);
        controller.startGeneration(SkinCareFlowState.noProductsFindingProducts);
        expect(
          container.read(skinCareFlowControllerProvider).generationOrigin,
          SkinCareFlowState.noProductsEditing,
        );

        controller.completeGeneration();
        // Must stay in noProductsEditing so user can select recommendations in the editor
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.noProductsEditing,
        );

        // 2. Rebuild has-products: origin is hasProductsEditing
        controller.transitionTo(SkinCareFlowState.hasProductsEditing);
        controller.startGeneration(SkinCareFlowState.hasProductsGenerating);
        expect(
          container.read(skinCareFlowControllerProvider).generationOrigin,
          SkinCareFlowState.hasProductsEditing,
        );

        controller.completeGeneration();
        // Must stay in hasProductsEditing so user can review detected products in the editor
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.hasProductsEditing,
        );

        // 3. First time setup no-products: origin is noProductsInput
        controller.transitionTo(SkinCareFlowState.noProductsInput);
        controller.startGeneration(SkinCareFlowState.noProductsFindingProducts);
        expect(
          container.read(skinCareFlowControllerProvider).generationOrigin,
          SkinCareFlowState.noProductsInput,
        );

        controller.completeGeneration();
        expect(
          container.read(skinCareFlowControllerProvider).state,
          SkinCareFlowState.noProductsProductSelection,
        );
      },
    );
  });
}
