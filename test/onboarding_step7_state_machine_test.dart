import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_draft.dart';
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
      final notifier = MockOnboardingNotifier()
        ..loadSeedData(
          OnboardingDraft(
            uid: testUid,
            currentStep: 7,
            baseTimeline: const BaseTimelineDraft(),
          ),
        );
      container = ProviderContainer(
        overrides: [mockOnboardingProvider.overrideWith((ref) => notifier)],
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

    test('Back during editing cancels editing back to review mode', () {
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
        SkinCareFlowState.hasProductsReview,
      );
    });

    test('Back during review returns to choice without clearing blocks', () {
      final controller = container.read(
        skinCareFlowControllerProvider.notifier,
      );
      container
          .read(mockOnboardingProvider.notifier)
          .updateDraft(
            (d) => d.copyWith(
              baseTimeline: d.baseTimeline.copyWith(
                skinCareSetupPath: 'has_products',
                skinCareSetupStep: 1,
                blocks: [_skinBlock(1, 'Routine Block')],
              ),
            ),
          );

      controller.transitionTo(SkinCareFlowState.hasProductsReview);
      final handled = controller.handleBack();
      expect(handled, isTrue);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.choice,
      );

      // Blocks are preserved
      final base = container.read(mockOnboardingProvider).draft.baseTimeline;
      expect(base.blocks, isNotEmpty);
      expect(base.skinCareSetupStep, 0);
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
  });
}
