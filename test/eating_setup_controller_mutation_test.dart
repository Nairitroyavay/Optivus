import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_setup_controller.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_source_transition_policy.dart';

void main() {
  group('EatingSetupController Mutation Tests', () {
    late ProviderContainer container;
    late EatingSetupController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(eatingSetupControllerProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('Group A: updateBlock on AI plan -> workingCustomized == true', () {
      final setup = BaseTimelineSetup(uid: 'u1', updatedAt: DateTime.now())
          .replaceEatingGeneratedConfiguration(
            blocks: [],
            goal: 'lose',
            meals: 3,
            mode: 'balanced',
            type: 'mixed',
            styleCustomText: null,
            foodsToAvoid: [],
            breakfast: 480,
            lunch: 720,
            dinner: 1080,
            snack: null,
            extraSnack: null,
            calories: 2000,
            protein: 100,
            caloriesOverride: null,
            proteinOverride: null,
            planVersion: 1,
            inputFingerprint: 'fp',
            customized: false,
          );

      controller.editCurrentMealPlan(setup);

      expect(controller.state.workingCustomized, false);
      expect(controller.state.workingGeneratedPlanVersion, 1);

      final newBlock = TimelineBlockDraft(
        id: '1',
        title: 'New Meal',
        startMinute: 600,
        endMinute: 630,
        repeatDays: [1],
        section: 'eating',
        blockType: TimelineBlockDraft.softBlockKey,
        mealCategory: 'snack',
        mealSlot: '1',
      );

      controller.addBlock(newBlock);
      expect(controller.state.workingCustomized, true);
    });

    test('Group B: Case A - AI generate -> edit meal -> validate passes', () {
      final engine = container.read(eatingDomainEngineProvider);

      final b1 = TimelineBlockDraft(
        id: '1',
        title: 'Breakfast',
        startMinute: 480,
        endMinute: 510,
        repeatDays: [1],
        section: 'eating',
        blockType: TimelineBlockDraft.softBlockKey,
        mealCategory: 'breakfast',
        mealSlot: '1',
        dishes: const ['Eggs'],
      );

      final setup = BaseTimelineSetup(uid: 'u1', updatedAt: DateTime.now())
          .replaceEatingGeneratedConfiguration(
            blocks: [b1],
            goal: 'lose',
            meals: 3,
            mode: 'balanced',
            type: 'mixed',
            styleCustomText: null,
            foodsToAvoid: [],
            breakfast: 480,
            lunch: 720,
            dinner: 1080,
            snack: null,
            extraSnack: null,
            calories: 2000,
            protein: 100,
            caloriesOverride: null,
            proteinOverride: null,
            planVersion: 1,
            inputFingerprint: 'fp',
            customized: true,
          );

      final err = engine.validateBeforeSave(
        blocks: [b1],
        setup: setup,
        targets: null,
      );

      expect(err, isNull);
    });

    test(
      'Group C: Integration regression - edit preserves generated metadata',
      () {
        final setup = BaseTimelineSetup(uid: 'u1', updatedAt: DateTime.now())
            .replaceEatingGeneratedConfiguration(
              blocks: [],
              goal: 'lose',
              meals: 3,
              mode: 'balanced',
              type: 'mixed',
              styleCustomText: null,
              foodsToAvoid: [],
              breakfast: 480,
              lunch: 720,
              dinner: 1080,
              snack: null,
              extraSnack: null,
              calories: 2000,
              protein: 100,
              caloriesOverride: null,
              proteinOverride: null,
              planVersion: 1,
              inputFingerprint: 'test-fingerprint',
              customized: false,
            );

        controller.editCurrentMealPlan(setup);

        final newBlock = TimelineBlockDraft(
          id: '1',
          title: 'Meal',
          startMinute: 600,
          endMinute: 630,
          repeatDays: [1],
          section: 'eating',
          blockType: TimelineBlockDraft.softBlockKey,
          mealCategory: 'lunch',
          mealSlot: '1',
        );

        controller.addBlock(newBlock);

        expect(controller.state.workingCustomized, true);
        expect(controller.state.isDirty, true);

        expect(
          controller.state.workingGeneratedInputFingerprint,
          'test-fingerprint',
        );
        expect(controller.state.workingGeneratedPlanVersion, 1);
        expect(controller.state.workingSetupPath, 'create');
        expect(controller.state.workingBlocks.length, 1);
      },
    );

    test('Group D: Photo -> AI transition clears photo metadata', () {
      final transitionState = EatingSourceTransitionPolicy.toGenerated(
        blocks: [],
        goal: 'maintain',
        mealsPerDay: 3,
        eatingMode: 'balanced',
        foodType: 'mixed',
        foodStyleCustomText: null,
        foodsToAvoid: [],
        breakfastMinute: 480,
        lunchMinute: 720,
        dinnerMinute: 1080,
        snackMinute: null,
        extraSnackMinute: null,
        targetCalories: 2000,
        targetProtein: 100,
        targetCaloriesOverride: null,
        targetProteinOverride: null,
        planVersion: 1,
        inputFingerprint: 'fp',
        customized: false,
      );

      expect(transitionState.photoAssetId, isNull);
      expect(transitionState.photoR2Key, isNull);
      expect(transitionState.setupPath, 'create');
    });

    test('Group E: AI -> Manual transition clears generated metadata', () {
      final manualState = EatingSourceTransitionPolicy.toManual(blocks: []);

      expect(manualState.planVersion, isNull);
      expect(manualState.inputFingerprint, isNull);
      expect(manualState.setupPath, 'manual');
    });

    test(
      'Group B: Case E - AI generate -> delete a meal -> validate passes if valid',
      () {
        final engine = container.read(eatingDomainEngineProvider);

        final b1 = TimelineBlockDraft(
          id: '1',
          title: 'Breakfast',
          startMinute: 480,
          endMinute: 510,
          repeatDays: [1],
          section: 'eating',
          blockType: TimelineBlockDraft.softBlockKey,
          mealCategory: 'breakfast',
          mealSlot: '1',
          dishes: const ['Eggs'],
        );

        final b2 = TimelineBlockDraft(
          id: '2',
          title: 'Lunch',
          startMinute: 720,
          endMinute: 750,
          repeatDays: [1],
          section: 'eating',
          blockType: TimelineBlockDraft.softBlockKey,
          mealCategory: 'lunch',
          mealSlot: '1',
          dishes: const ['Salad'],
        );

        final setup = BaseTimelineSetup(uid: 'u1', updatedAt: DateTime.now())
            .replaceEatingGeneratedConfiguration(
              blocks: [b1, b2],
              goal: 'lose',
              meals: 3,
              mode: 'balanced',
              type: 'mixed',
              styleCustomText: null,
              foodsToAvoid: [],
              breakfast: 480,
              lunch: 720,
              dinner: 1080,
              snack: null,
              extraSnack: null,
              calories: 2000,
              protein: 100,
              caloriesOverride: null,
              proteinOverride: null,
              planVersion: 1,
              inputFingerprint: 'fp',
              customized: true,
            );

        final err = engine.validateBeforeSave(
          blocks: [b1],
          setup: setup,
          targets: null,
        );

        expect(err, isNull);
      },
    );

    test(
      'Group B: Case E negative - AI generate pristine -> delete one block sets customized and validates',
      () {
        final engine = container.read(eatingDomainEngineProvider);

        final b1 = TimelineBlockDraft(
          id: '1',
          title: 'Breakfast',
          startMinute: 480,
          endMinute: 510,
          repeatDays: [1],
          section: 'eating',
          blockType: TimelineBlockDraft.softBlockKey,
          mealCategory: 'breakfast',
          mealSlot: '1',
          dishes: const ['Eggs'],
        );
        final b2 = TimelineBlockDraft(
          id: '2',
          title: 'Lunch',
          startMinute: 720,
          endMinute: 750,
          repeatDays: [1],
          section: 'eating',
          blockType: TimelineBlockDraft.softBlockKey,
          mealCategory: 'lunch',
          mealSlot: '1',
          dishes: const ['Salad'],
        );

        final setup = BaseTimelineSetup(uid: 'u1', updatedAt: DateTime.now())
            .replaceEatingGeneratedConfiguration(
              blocks: [b1, b2],
              goal: 'lose',
              meals: 3,
              mode: 'balanced',
              type: 'mixed',
              styleCustomText: null,
              foodsToAvoid: [],
              breakfast: 480,
              lunch: 720,
              dinner: 1080,
              snack: null,
              extraSnack: null,
              calories: 2000,
              protein: 100,
              caloriesOverride: null,
              proteinOverride: null,
              planVersion: 1,
              inputFingerprint: 'fp',
              customized: false,
            );

        controller.editCurrentMealPlan(setup);
        controller.deleteBlock('2');
        expect(controller.state.workingCustomized, true);

        final updatedSetup = setup.copyWith(
          eatingCustomized: controller.state.workingCustomized,
        );

        final err = engine.validateBeforeSave(
          blocks: [b1],
          setup: updatedSetup,
          targets: null,
        );

        expect(err, isNull);
      },
    );

    test(
      'Group B: Case F - AI generate -> change settings -> validate passes',
      () {
        final engine = container.read(eatingDomainEngineProvider);

        final b1 = TimelineBlockDraft(
          id: '1',
          title: 'Breakfast',
          startMinute: 480,
          endMinute: 510,
          repeatDays: [1],
          section: 'eating',
          blockType: TimelineBlockDraft.softBlockKey,
          mealCategory: 'breakfast',
          mealSlot: '1',
          dishes: const ['Eggs'],
        );

        final setup = BaseTimelineSetup(uid: 'u1', updatedAt: DateTime.now())
            .replaceEatingGeneratedConfiguration(
              blocks: [b1],
              goal: 'lose',
              meals: 3,
              mode: 'balanced',
              type: 'mixed',
              styleCustomText: null,
              foodsToAvoid: [],
              breakfast: 480,
              lunch: 720,
              dinner: 1080,
              snack: null,
              extraSnack: null,
              calories: 2000,
              protein: 100,
              caloriesOverride: null,
              proteinOverride: null,
              planVersion: 1,
              inputFingerprint: 'fp',
              customized: false,
            );

        controller.editCurrentMealPlan(setup);
        controller.updateSettingsParameters(
          goal: 'lose',
          mealsPerDay: 3,
          eatingMode: 'balanced',
          foodType: 'mixed',
          foodStyleCustomText: null,
          foodsToAvoid: ['Peanuts'],
          breakfastMinute: 480,
          lunchMinute: 720,
          dinnerMinute: 1080,
          snackMinute: null,
          extraSnackMinute: null,
          targetCalories: 2000,
          targetProtein: 100,
          targetCaloriesOverride: 1800,
          targetProteinOverride: 90,
        );

        expect(controller.state.workingCustomized, true);

        final updatedSetup = setup.copyWith(
          eatingCustomized: controller.state.workingCustomized,
          targetCaloriesOverride:
              controller.state.workingTargetCaloriesOverride,
          targetProteinOverride: controller.state.workingTargetProteinOverride,
          foodsToAvoid: controller.state.workingFoodsToAvoid,
        );

        final err = engine.validateBeforeSave(
          blocks: [b1],
          setup: updatedSetup,
          targets: null,
        );

        expect(err, isNull);
      },
    );

    test('Group B: Case J - concurrency conflict', () {
      // Test that state can capture concurrency conflict
      controller.state = controller.state.copyWith(
        isConcurrencyConflict: true,
        errorMessage: 'The plan was updated by another device.',
      );

      expect(controller.state.isConcurrencyConflict, true);
      expect(controller.state.errorMessage, isNotNull);
    });

    test(
      'controller AI -> Manual clears every generated-only nullable field',
      () {
        final generated =
            BaseTimelineSetup(
              uid: 'u1',
              updatedAt: DateTime.now(),
            ).replaceEatingGeneratedConfiguration(
              blocks: const [],
              goal: 'gain',
              meals: 5,
              mode: 'custom',
              type: 'vegetarian',
              styleCustomText: 'regional',
              foodsToAvoid: const ['peanuts'],
              breakfast: 480,
              lunch: 780,
              dinner: 1200,
              snack: 1020,
              extraSnack: 660,
              calories: 2500,
              protein: 150,
              caloriesOverride: 2600,
              proteinOverride: 160,
              planVersion: 1,
              inputFingerprint: 'generated-fingerprint',
            );

        controller.editCurrentMealPlan(generated);
        controller.startManualSetup(generated);

        expect(controller.state.workingSetupPath, 'manual');
        expect(controller.state.workingAssetId, isNull);
        expect(controller.state.workingR2Key, isNull);
        expect(controller.state.workingGeneratedPlanVersion, isNull);
        expect(controller.state.workingGeneratedInputFingerprint, isNull);
        expect(controller.state.workingGoal, isNull);
        expect(controller.state.workingMealsPerDay, isNull);
        expect(controller.state.workingEatingMode, isNull);
        expect(controller.state.workingFoodType, isNull);
        expect(controller.state.workingFoodStyleCustomText, isNull);
        expect(controller.state.workingBreakfastMinute, isNull);
        expect(controller.state.workingLunchMinute, isNull);
        expect(controller.state.workingDinnerMinute, isNull);
        expect(controller.state.workingSnackMinute, isNull);
        expect(controller.state.workingExtraSnackMinute, isNull);
        expect(controller.state.workingTargetCalories, isNull);
        expect(controller.state.workingTargetProtein, isNull);
        expect(controller.state.workingTargetCaloriesOverride, isNull);
        expect(controller.state.workingTargetProteinOverride, isNull);
      },
    );

    test('cancel explicitly clears candidate asset metadata', () async {
      controller.state = controller.state.copyWith(
        candidateAssetId: 'candidate-asset',
        candidateR2Key: 'users/u1/eating/candidate.jpg',
        sessionGeneration: 3,
      );

      await controller.cancelCurrentOperation(null, uid: 'u1');

      expect(controller.state.candidateAssetId, isNull);
      expect(controller.state.candidateR2Key, isNull);
      expect(controller.state.sessionGeneration, 4);
    });
  });
}
