import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/services/nutrition_target_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';

void main() {
  const targetService = NutritionTargetService();
  final testTargets = targetService.calculate(
    ageRange: '25-34',
    heightCm: 175,
    weightKg: 70,
    gender: 'male',
    exerciseLevel: '3_4_days',
    bodyGoal: 'maintain',
  ); // targetCalories: ~2256, proteinTarget: 140

  const dishLibrary = {
    'breakfast': [
      ['Oatmeal Bowl', 'Almond Milk'],
      ['Avocado Toast', 'Tofu Scramble'],
      ['Smoothie Bowl', 'Granola'],
      ['Poha', 'Boiled Sprouts'],
      ['Besan Chilla', 'Mint Chutney'],
      ['Idli Sambar', 'Coconut Chutney'],
      ['Oat Pancakes', 'Maple Drizzle'],
    ],
    'morning_snack': [
      ['Almonds', 'Green Tea'],
      ['Walnuts', 'Dried Apricots'],
      ['Fruit Bowl', 'Flax Seeds'],
      ['Boiled Corn', 'Lemon Juice'],
      ['Carrot Sticks', 'Hummus Dip'],
      ['Cucumber Slices', 'Mint Dip'],
      ['Roasted Chana', 'Herbal Tea'],
    ],
    'lunch': [
      ['Brown Rice', 'Dal Tadka'],
      ['Quinoa Salad', 'Chickpea Bowl'],
      ['Whole Wheat Wrap', 'Hummus Wrap'],
      ['Millet Bowl', 'Sambar Stew'],
      ['Rajma Chawal', 'Cucumber Salad'],
      ['Curd Rice', 'Stir Fry Beans'],
      ['Chole Masala', 'Whole Wheat Kulcha'],
    ],
    'afternoon_snack': [
      ['Greek Yogurt', 'Blueberries'],
      ['Apple Slices', 'Peanut Butter'],
      ['Mixed Nuts', 'Dried Figs'],
      ['Chia Seed Pudding', 'Walnuts'],
      ['Roasted Makhana', 'Almonds'],
      ['Fruit Chaat', 'Pumpkin Seeds'],
      ['Protein Shake', 'Medjool Dates'],
    ],
    'dinner': [
      ['Whole Wheat Roti', 'Paneer Sabzi'],
      ['Brown Rice', 'Lentil Soup'],
      ['Moong Dal Khichdi', 'Roasted Veggies'],
      ['Chapati', 'Mushroom Curry'],
      ['Vegetable Stew', 'Appam Bread'],
      ['Palak Paneer', 'Missi Roti'],
      ['Vegetable Biryani', 'Cucumber Raita'],
    ],
  };

  List<RoutineImportCandidateBlock> createCandidateWeek({
    required int mealsPerDay,
    int targetCalories = 2256,
    int proteinTarget = 140,
    List<String> Function(String slot, int day)? dishOverride,
    double? calorieOverride,
    double? proteinOverride,
  }) {
    final slotDefs = <(String, String, int, int)>[
      ('breakfast', 'Breakfast', 8 * 60, 30),
      if (mealsPerDay >= 5) ('morning_snack', 'Snack', 10 * 60 + 30, 20),
      ('lunch', 'Lunch', 13 * 60, 45),
      if (mealsPerDay >= 4) ('afternoon_snack', 'Snack', 17 * 60, 20),
      ('dinner', 'Dinner', 20 * 60 + 30, 45),
    ];

    final calPerMeal = (targetCalories / slotDefs.length).toDouble();
    final proPerMeal = (proteinTarget / slotDefs.length).toDouble();

    final candidates = <RoutineImportCandidateBlock>[];
    for (var d = 1; d <= 7; d++) {
      for (final slot in slotDefs) {
        final slotId = slot.$1;
        final title = slot.$2;
        final start = slot.$3;
        final duration = slot.$4;
        final dishes = dishOverride != null
            ? dishOverride(slotId, d)
            : (dishLibrary[slotId]?[d - 1] ?? ['Dish A $d', 'Dish B $d']);

        candidates.add(
          RoutineImportCandidateBlock(
            id: 'ai-gen-d$d-$slotId',
            mealSlot: slotId,
            title: title,
            startMinute: start,
            endMinute: start + duration,
            hasFixedTime: true,
            repeatDays: [d],
            blockType: TimelineBlockDraft.softBlockKey,
            category: 'eating',
            hardBlock: false,
            selected: true,
            candidateType: RoutineImportCandidateType.block,
            confidenceScore: 0.95,
            confidenceLabel: 'high',
            extractionEngine: 'test',
            extractionVersion: 'phase2d',
            needsManualReview: false,
            steps: dishes,
            mealCategory: slotId.contains('snack') ? 'snack' : slotId,
            caloriesEstimate: calorieOverride ?? calPerMeal,
            proteinEstimate: proteinOverride ?? proPerMeal,
          ),
        );
      }
    }
    return candidates;
  }

  BaseTimelineDraft createBaseTimeline(int mealsPerDay) {
    return BaseTimelineDraft(
      eatingSetupPath: onboardingEatingPathCreate,
      eatingSetupStep: 2,
      mealsPerDay: mealsPerDay,
      foodType: 'veg',
      breakfastMinute: 8 * 60,
      lunchMinute: 13 * 60,
      snackMinute: 17 * 60,
      dinnerMinute: 20 * 60 + 30,
    );
  }

  group('Gate 2 - Candidate Mapping Matrix (21, 28, 35 blocks)', () {
    test(
      '3 meals/day maps exactly 21 blocks across 7 days with repeatDays [day]',
      () {
        final base = createBaseTimeline(3);
        final candidates = createCandidateWeek(mealsPerDay: 3);

        final result = mapOnboarding5MealCandidates(
          candidates,
          source: onboardingEatingGeneratedSource,
          baseTimeline: base,
        );

        expect(result.blocks, hasLength(21));
        expect(result.blocks.every((b) => b.repeatDays.length == 1), isTrue);
        expect(
          result.blocks.every(
            (b) => b.source == onboardingEatingGeneratedSource,
          ),
          isTrue,
        );
        expect(
          result.blocks.every((b) => b.calories != null && b.protein != null),
          isTrue,
        );

        final days = result.blocks.map((b) => b.repeatDays.first).toSet();
        expect(days, {1, 2, 3, 4, 5, 6, 7});

        final slots = result.blocks.map((b) => b.mealSlot).toSet();
        expect(slots, {'breakfast', 'lunch', 'dinner'});
      },
    );

    test('4 meals/day maps exactly 28 blocks across 7 days', () {
      final base = createBaseTimeline(4);
      final candidates = createCandidateWeek(mealsPerDay: 4);

      final result = mapOnboarding5MealCandidates(
        candidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );

      expect(result.blocks, hasLength(28));
      expect(result.blocks.every((b) => b.repeatDays.length == 1), isTrue);

      final slots = result.blocks.map((b) => b.mealSlot).toSet();
      expect(slots, {'breakfast', 'lunch', 'afternoon_snack', 'dinner'});
    });

    test('5 meals/day maps exactly 35 blocks across 7 days', () {
      final base = createBaseTimeline(5);
      final candidates = createCandidateWeek(mealsPerDay: 5);

      final result = mapOnboarding5MealCandidates(
        candidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );

      expect(result.blocks, hasLength(35));
      expect(result.blocks.every((b) => b.repeatDays.length == 1), isTrue);

      final slots = result.blocks.map((b) => b.mealSlot).toSet();
      expect(slots, {
        'breakfast',
        'morning_snack',
        'lunch',
        'afternoon_snack',
        'dinner',
      });
    });

    test('rejection on missing day-slot coverage for generated source', () {
      final base = createBaseTimeline(4);
      // Missing day 7
      final candidates = createCandidateWeek(
        mealsPerDay: 4,
      ).where((c) => c.repeatDays.first != 7).toList();

      final result = mapOnboarding5MealCandidates(
        candidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );

      // Should refuse incomplete week
      expect(result.blocks, isEmpty);
    });

    test('duplicate slot on same day is rejected for generated source', () {
      final base = createBaseTimeline(4);
      final candidates = createCandidateWeek(mealsPerDay: 4);
      // Add duplicate day 1 breakfast
      candidates.add(
        RoutineImportCandidateBlock(
          id: 'dup-breakfast',
          mealSlot: 'breakfast',
          title: 'Breakfast',
          startMinute: 8 * 60,
          endMinute: 8 * 60 + 30,
          hasFixedTime: true,
          repeatDays: const [1],
          blockType: TimelineBlockDraft.softBlockKey,
          category: 'eating',
          hardBlock: false,
          mealCategory: 'breakfast',
          steps: const ['Extra Toast'],
          caloriesEstimate: 300,
          proteinEstimate: 10,
        ),
      );

      final result = mapOnboarding5MealCandidates(
        candidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );

      expect(result.blocks, isEmpty);
    });
  });

  group('Gate 2 - Weekly Plan Validation (validateGeneratedEatingWeeklyPlan)', () {
    test('valid 7-day 28-block plan passes validation completely', () {
      final base = createBaseTimeline(4);
      final candidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: testTargets.targetCalories!,
        proteinTarget: testTargets.proteinTarget!.round(),
      );
      final mapped = mapOnboarding5MealCandidates(
        candidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );

      final timeline = base.copyWith(blocks: mapped.blocks);
      final error = validateGeneratedEatingWeeklyPlan(
        timeline,
        targets: testTargets,
      );
      expect(error, isNull);
      expect(timeline.validateEatingSetup(targets: testTargets), isNull);
    });

    test(
      'legacy 3-block single-day plan is detected and rejected with regeneration error',
      () {
        final legacyBase = const BaseTimelineDraft(
          eatingSetupPath: onboardingEatingPathCreate,
          eatingSetupStep: 2,
          mealsPerDay: 3,
          blocks: [
            TimelineBlockDraft(
              id: 'eating-ai-breakfast',
              section: 'eating',
              title: 'Breakfast',
              startMinute: 8 * 60,
              endMinute: 8 * 60 + 30,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: onboardingEatingGeneratedSource,
              mealSlot: 'breakfast',
              dishes: ['Oatmeal', 'Banana'],
              calories: 500,
              protein: 20,
            ),
            TimelineBlockDraft(
              id: 'eating-ai-lunch',
              section: 'eating',
              title: 'Lunch',
              startMinute: 13 * 60,
              endMinute: 13 * 60 + 45,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: onboardingEatingGeneratedSource,
              mealSlot: 'lunch',
              dishes: ['Rice', 'Dal'],
              calories: 700,
              protein: 30,
            ),
            TimelineBlockDraft(
              id: 'eating-ai-dinner',
              section: 'eating',
              title: 'Dinner',
              startMinute: 20 * 60,
              endMinute: 20 * 60 + 45,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: onboardingEatingGeneratedSource,
              mealSlot: 'dinner',
              dishes: ['Roti', 'Sabzi'],
              calories: 600,
              protein: 25,
            ),
          ],
        );

        expect(isLegacyGeneratedEatingPlan(legacyBase), isTrue);
        final error = legacyBase.validateEatingSetup(targets: testTargets);
        expect(error, contains('older weekly format. Please regenerate'));
      },
    );

    test('fails on generic dish tokens (looksLikeNonDishMealToken)', () {
      expect(looksLikeNonDishMealToken('Meal 1'), isTrue);
      expect(looksLikeNonDishMealToken('Breakfast'), isTrue);
      expect(looksLikeNonDishMealToken('Lunch item'), isTrue);
      expect(looksLikeNonDishMealToken('Snack 2'), isTrue);
      expect(looksLikeNonDishMealToken('Food'), isTrue);
      expect(looksLikeNonDishMealToken('Oatmeal Bowl'), isFalse);
      expect(looksLikeNonDishMealToken('Dal Tadka'), isFalse);

      final base = createBaseTimeline(4);
      final candidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: testTargets.targetCalories!,
        proteinTarget: testTargets.proteinTarget!.round(),
        dishOverride: (slot, day) {
          if (slot == 'breakfast' && day == 1) {
            return ['Meal 1', 'Food'];
          }
          return ['Valid Dish A', 'Valid Dish B'];
        },
      );
      final mapped = mapOnboarding5MealCandidates(
        candidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );

      final timeline = base.copyWith(blocks: mapped.blocks);
      final error = validateGeneratedEatingWeeklyPlan(
        timeline,
        targets: testTargets,
      );
      expect(error, contains('without specific dishes'));
    });

    test('fails when calories or protein metadata is missing', () {
      final base = createBaseTimeline(4);
      final candidates = createCandidateWeek(
        mealsPerDay: 4,
        calorieOverride: null,
      );
      // Strip calories from candidate blocks
      final strippedCandidates = candidates
          .map(
            (c) => RoutineImportCandidateBlock(
              id: c.id,
              mealSlot: c.mealSlot,
              title: c.title,
              startMinute: c.startMinute,
              endMinute: c.endMinute,
              hasFixedTime: c.hasFixedTime,
              repeatDays: c.repeatDays,
              blockType: c.blockType,
              category: c.category,
              hardBlock: c.hardBlock,
              steps: c.steps,
              mealCategory: c.mealCategory,
              caloriesEstimate: null, // missing!
              proteinEstimate: 30,
            ),
          )
          .toList();

      final mapped = mapOnboarding5MealCandidates(
        strippedCandidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );

      final timeline = base.copyWith(blocks: mapped.blocks);
      final error = validateGeneratedEatingWeeklyPlan(
        timeline,
        targets: testTargets,
      );
      expect(error, contains('nutrition estimates'));
    });

    test('fails when calories deviance exceeds 25%', () {
      final base = createBaseTimeline(4);
      // Target is 2256, set total daily calories to 1000 (exceeds 25% deviance)
      final candidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: 1000,
        proteinTarget: testTargets.proteinTarget!.round(),
      );
      final mapped = mapOnboarding5MealCandidates(
        candidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );

      final timeline = base.copyWith(blocks: mapped.blocks);
      final error = validateGeneratedEatingWeeklyPlan(
        timeline,
        targets: testTargets,
      );
      expect(error, contains('deviate significantly from your target'));
    });

    test('fails when protein deviance exceeds 35%', () {
      final base = createBaseTimeline(4);
      // Target protein is 140g, set total daily protein to 40g (exceeds 35% deviance)
      final candidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: testTargets.targetCalories!,
        proteinTarget: 40,
      );
      final mapped = mapOnboarding5MealCandidates(
        candidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );

      final timeline = base.copyWith(blocks: mapped.blocks);
      final error = validateGeneratedEatingWeeklyPlan(
        timeline,
        targets: testTargets,
      );
      expect(error, contains('deviate significantly from your target'));
    });

    test(
      'fails when weekly diversity is insufficient (< 3 distinct dish sets per slot)',
      () {
        final base = createBaseTimeline(4);
        // Force breakfast to repeat identical dishes all 7 days
        final candidates = createCandidateWeek(
          mealsPerDay: 4,
          targetCalories: testTargets.targetCalories!,
          proteinTarget: testTargets.proteinTarget!.round(),
          dishOverride: (slot, day) {
            if (slot == 'breakfast') {
              return ['Exact Same Oatmeal', 'Same Banana'];
            }
            return dishLibrary[slot]?[day - 1] ?? ['Dish 1', 'Dish 2'];
          },
        );
        final mapped = mapOnboarding5MealCandidates(
          candidates,
          source: onboardingEatingGeneratedSource,
          baseTimeline: base,
        );

        final timeline = base.copyWith(blocks: mapped.blocks);
        final error = validateGeneratedEatingWeeklyPlan(
          timeline,
          targets: testTargets,
        );
        expect(error, contains('variety across days'));
      },
    );

    test(
      'fails when weekly diversity is insufficient (< 4 distinct daily menus)',
      () {
        final base = createBaseTimeline(4);
        // Only 2 distinct daily menus alternating across the week
        final candidates = createCandidateWeek(
          mealsPerDay: 4,
          targetCalories: testTargets.targetCalories!,
          proteinTarget: testTargets.proteinTarget!.round(),
          dishOverride: (slot, day) {
            final effectiveDay = day.isOdd ? 1 : 2;
            return dishLibrary[slot]?[effectiveDay - 1] ?? ['Dish 1', 'Dish 2'];
          },
        );
        final mapped = mapOnboarding5MealCandidates(
          candidates,
          source: onboardingEatingGeneratedSource,
          baseTimeline: base,
        );

        final timeline = base.copyWith(blocks: mapped.blocks);
        final error = validateGeneratedEatingWeeklyPlan(
          timeline,
          targets: testTargets,
        );
        expect(error, contains('variety across days'));
      },
    );
  });

  group('Gate 2 - Import Multi-Day Support', () {
    test(
      'Monday Breakfast and Tuesday Breakfast do not collide in import mode',
      () {
        const base = BaseTimelineDraft(
          mealsPerDay: 3,
          breakfastMinute: 8 * 60,
          lunchMinute: 13 * 60,
          dinnerMinute: 20 * 60 + 30,
        );

        final importCandidates = [
          RoutineImportCandidateBlock(
            id: 'mon-bfast',
            mealSlot: 'breakfast',
            title: 'Monday Breakfast',
            startMinute: 8 * 60,
            endMinute: 8 * 60 + 30,
            repeatDays: const [1],
            blockType: TimelineBlockDraft.softBlockKey,
            category: 'eating',
            hardBlock: false,
            mealCategory: 'breakfast',
            steps: const ['Eggs Benedict', 'Orange Juice'],
          ),
          RoutineImportCandidateBlock(
            id: 'tue-bfast',
            mealSlot: 'breakfast',
            title: 'Tuesday Breakfast',
            startMinute: 8 * 60,
            endMinute: 8 * 60 + 30,
            repeatDays: const [2],
            blockType: TimelineBlockDraft.softBlockKey,
            category: 'eating',
            hardBlock: false,
            mealCategory: 'breakfast',
            steps: const ['Waffles', 'Strawberries'],
          ),
        ];

        final mapped = mapOnboarding5MealCandidates(
          importCandidates,
          source: onboardingEatingAiImportSource,
          baseTimeline: base,
        );

        expect(mapped.blocks, hasLength(2));
        expect(mapped.blocks[0].repeatDays, [1]);
        expect(mapped.blocks[0].id, 'eating-ai-d1-breakfast');
        expect(mapped.blocks[1].repeatDays, [2]);
        expect(mapped.blocks[1].id, 'eating-ai-d2-breakfast');
      },
    );
  });

  group('Gate 2 - OnboardingDraft Canonical Targets Integration', () {
    test(
      'OnboardingDraft produces canonical targets and feeds into step 5/14 validation',
      () {
        final draft = OnboardingDraft(
          uid: 'target-user',
          lifeRole: const LifeRoleDraft(
            lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
            exerciseLevel: '3_4_days',
          ),
          bodyBasics: const BodyBasicsDraft(
            ageRange: '25-34',
            heightCm: 180,
            weightKg: 75,
            gender: 'male',
          ).withEstimates(),
          baseTimeline: const BaseTimelineDraft(mealPlanningGoal: 'gain'),
        );

        final targets = draft.canonicalNutritionTargets();
        expect(targets.hasBodyBasics, isTrue);
        expect(targets.bodyGoal, 'gain');
        // Gain goal increases calories by 300
        expect(
          targets.targetCalories,
          targets.estimatedMaintenanceCalories! + 300,
        );
        expect(targets.proteinTarget, 150.0);

        // Verify validateStep(5) and validateStep(14) use these targets
        final validCandidates = createCandidateWeek(
          mealsPerDay: 4,
          targetCalories: targets.targetCalories!,
          proteinTarget: targets.proteinTarget!.round(),
        );
        final mapped = mapOnboarding5MealCandidates(
          validCandidates,
          source: onboardingEatingGeneratedSource,
          baseTimeline: createBaseTimeline(4),
        );

        final completedDraft = draft.copyWith(
          baseTimeline: createBaseTimeline(4).copyWith(blocks: mapped.blocks),
        );

        expect(
          completedDraft.validateStep(5, completedDraft.stepCompleted),
          isNull,
        );
      },
    );

    test(
      'Serialization roundtrip preserves all 28 day-slot blocks and fields',
      () {
        final validCandidates = createCandidateWeek(
          mealsPerDay: 4,
          targetCalories: 2000,
          proteinTarget: 140,
        );
        final mapped = mapOnboarding5MealCandidates(
          validCandidates,
          source: onboardingEatingGeneratedSource,
          baseTimeline: createBaseTimeline(4),
        );

        final originalDraft = OnboardingDraft(
          uid: 'roundtrip-user',
          baseTimeline: createBaseTimeline(4).copyWith(blocks: mapped.blocks),
        );

        final map = originalDraft.toMap();
        final restoredDraft = OnboardingDraft.fromMap(map);
        final restoredBlocks = restoredDraft.baseTimeline
            .confirmedBlocksForSection('eating');

        expect(restoredBlocks, hasLength(28));
        for (var i = 0; i < 28; i++) {
          expect(restoredBlocks[i].id, mapped.blocks[i].id);
          expect(restoredBlocks[i].repeatDays, mapped.blocks[i].repeatDays);
          expect(restoredBlocks[i].mealSlot, mapped.blocks[i].mealSlot);
          expect(restoredBlocks[i].dishes, mapped.blocks[i].dishes);
          expect(restoredBlocks[i].calories, mapped.blocks[i].calories);
          expect(restoredBlocks[i].protein, mapped.blocks[i].protein);
        }
      },
    );

    test(
      'Routine projection preserves day-specific RoutineItems with distinct repeatDays and nutrition metadata',
      () {
        final validCandidates = createCandidateWeek(
          mealsPerDay: 4,
          targetCalories: 2000,
          proteinTarget: 140,
        );
        final mapped = mapOnboarding5MealCandidates(
          validCandidates,
          source: onboardingEatingGeneratedSource,
          baseTimeline: createBaseTimeline(4),
        );

        final draft = OnboardingDraft(
          uid: 'projection-user',
          baseTimeline: createBaseTimeline(4).copyWith(blocks: mapped.blocks),
        );

        final bundle = OnboardingCompletionService.buildBundle(draft);
        final eatingRoutines = bundle.routineItemsForApp
            .where((r) => r.mealSlot != null)
            .toList();

        expect(eatingRoutines, hasLength(28));
        expect(eatingRoutines.every((r) => r.repeatDays.length == 1), isTrue);
        expect(
          eatingRoutines.every(
            (r) => r.caloriesEstimate != null && r.proteinEstimate != null,
          ),
          isTrue,
        );

        final monBreakfast = eatingRoutines.firstWhere(
          (r) => r.mealSlot == 'breakfast' && r.repeatDays.first == 1,
        );
        final tueBreakfast = eatingRoutines.firstWhere(
          (r) => r.mealSlot == 'breakfast' && r.repeatDays.first == 2,
        );

        expect(monBreakfast.id, isNot(tueBreakfast.id));
        expect(monBreakfast.repeatDays, [1]);
        expect(tueBreakfast.repeatDays, [2]);
        expect(monBreakfast.dishes, isNotEmpty);
        expect(tueBreakfast.dishes, isNotEmpty);
        expect(monBreakfast.dishes, isNot(tueBreakfast.dishes));
      },
    );

    test(
      'mergeOverlappingEatingBlocks does not merge Monday and Tuesday meals',
      () {
        final monBreakfast = TimelineBlockDraft(
          id: 'eating-ai-d1-breakfast',
          section: 'eating',
          title: 'Breakfast',
          startMinute: 8 * 60,
          endMinute: 8 * 60 + 30,
          repeatDays: const [1],
          blockType: TimelineBlockDraft.hardBlockKey,
          source: onboardingEatingGeneratedSource,
          mealSlot: 'breakfast',
          dishes: const ['Dish 1', 'Dish 2'],
        );
        final tueBreakfast = TimelineBlockDraft(
          id: 'eating-ai-d2-breakfast',
          section: 'eating',
          title: 'Breakfast',
          startMinute: 8 * 60,
          endMinute: 8 * 60 + 30,
          repeatDays: const [2],
          blockType: TimelineBlockDraft.hardBlockKey,
          source: onboardingEatingGeneratedSource,
          mealSlot: 'breakfast',
          dishes: const ['Dish 3', 'Dish 4'],
        );

        final merged = mergeOverlappingEatingBlocks([
          monBreakfast,
          tueBreakfast,
        ]);
        expect(merged, hasLength(2));
        expect(merged[0].repeatDays, [1]);
        expect(merged[1].repeatDays, [2]);
      },
    );
  });
}
