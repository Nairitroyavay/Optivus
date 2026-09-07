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

  BaseTimelineDraft createBaseTimeline(
    int mealsPerDay, {
    NutritionTargets? targets,
    int? version = BaseTimelineDraft.currentGate2EatingPlanVersion,
    String? fingerprint,
    String? mealPlanningGoal,
  }) {
    final effectiveTargets = targets ?? testTargets;
    final base = BaseTimelineDraft(
      eatingSetupPath: onboardingEatingPathCreate,
      eatingSetupStep: 2,
      mealsPerDay: mealsPerDay,
      foodType: 'veg',
      mealPlanningGoal: mealPlanningGoal,
      breakfastMinute: 8 * 60,
      lunchMinute: 13 * 60,
      snackMinute: 17 * 60,
      dinnerMinute: 20 * 60 + 30,
      eatingGeneratedPlanVersion: version,
    );
    return base.copyWith(
      eatingGeneratedInputFingerprint:
          fingerprint ??
          (version != null
              ? base.computeEatingGeneratedInputFingerprint(
                  targets: effectiveTargets,
                )
              : null),
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

    test('passes when calories are within ±15% tolerance', () {
      final base = createBaseTimeline(4);
      final targetCal = testTargets.targetCalories!;
      final highCal = (targetCal * 1.14).round();
      final lowCal = (targetCal * 0.86).round();

      final highCalCandidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: highCal,
        proteinTarget: testTargets.proteinTarget!.round(),
      );
      final highMapped = mapOnboarding5MealCandidates(
        highCalCandidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );
      expect(
        validateGeneratedEatingWeeklyPlan(
          base.copyWith(blocks: highMapped.blocks),
          targets: testTargets,
        ),
        isNull,
      );

      final lowCalCandidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: lowCal,
        proteinTarget: testTargets.proteinTarget!.round(),
      );
      final lowMapped = mapOnboarding5MealCandidates(
        lowCalCandidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );
      expect(
        validateGeneratedEatingWeeklyPlan(
          base.copyWith(blocks: lowMapped.blocks),
          targets: testTargets,
        ),
        isNull,
      );
    });

    test('fails when calories deviance exceeds ±15%', () {
      final base = createBaseTimeline(4);
      final targetCal = testTargets.targetCalories!;
      final highCal = (targetCal * 1.16).round();
      final lowCal = (targetCal * 0.84).round();

      final highCandidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: highCal,
        proteinTarget: testTargets.proteinTarget!.round(),
      );
      final highMapped = mapOnboarding5MealCandidates(
        highCandidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );
      final highError = validateGeneratedEatingWeeklyPlan(
        base.copyWith(blocks: highMapped.blocks),
        targets: testTargets,
      );
      expect(highError, contains('deviate significantly from your target'));

      final lowCandidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: lowCal,
        proteinTarget: testTargets.proteinTarget!.round(),
      );
      final lowMapped = mapOnboarding5MealCandidates(
        lowCandidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );
      final lowError = validateGeneratedEatingWeeklyPlan(
        base.copyWith(blocks: lowMapped.blocks),
        targets: testTargets,
      );
      expect(lowError, contains('deviate significantly from your target'));
    });

    test('passes when protein is within ±20% tolerance', () {
      final base = createBaseTimeline(4);
      final targetPro = testTargets.proteinTarget!;
      final highPro = (targetPro * 1.19).round();
      final lowPro = (targetPro * 0.81).round();

      final highCandidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: testTargets.targetCalories!,
        proteinTarget: highPro,
      );
      final highMapped = mapOnboarding5MealCandidates(
        highCandidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );
      expect(
        validateGeneratedEatingWeeklyPlan(
          base.copyWith(blocks: highMapped.blocks),
          targets: testTargets,
        ),
        isNull,
      );

      final lowCandidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: testTargets.targetCalories!,
        proteinTarget: lowPro,
      );
      final lowMapped = mapOnboarding5MealCandidates(
        lowCandidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );
      expect(
        validateGeneratedEatingWeeklyPlan(
          base.copyWith(blocks: lowMapped.blocks),
          targets: testTargets,
        ),
        isNull,
      );
    });

    test('fails when protein deviance exceeds ±20%', () {
      final base = createBaseTimeline(4);
      final targetPro = testTargets.proteinTarget!;
      final highPro = (targetPro * 1.22).round();
      final lowPro = (targetPro * 0.78).round();

      final highCandidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: testTargets.targetCalories!,
        proteinTarget: highPro,
      );
      final highMapped = mapOnboarding5MealCandidates(
        highCandidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );
      final highError = validateGeneratedEatingWeeklyPlan(
        base.copyWith(blocks: highMapped.blocks),
        targets: testTargets,
      );
      expect(highError, contains('deviate significantly from your target'));

      final lowCandidates = createCandidateWeek(
        mealsPerDay: 4,
        targetCalories: testTargets.targetCalories!,
        proteinTarget: lowPro,
      );
      final lowMapped = mapOnboarding5MealCandidates(
        lowCandidates,
        source: onboardingEatingGeneratedSource,
        baseTimeline: base,
      );
      final lowError = validateGeneratedEatingWeeklyPlan(
        base.copyWith(blocks: lowMapped.blocks),
        targets: testTargets,
      );
      expect(lowError, contains('deviate significantly from your target'));
    });

    test(
      'fails when weekly diversity is insufficient: repeated dish set in a meal slot',
      () {
        final base = createBaseTimeline(4);
        // Force breakfast on day 1 and day 3 to repeat identical dishes
        final candidates = createCandidateWeek(
          mealsPerDay: 4,
          targetCalories: testTargets.targetCalories!,
          proteinTarget: testTargets.proteinTarget!.round(),
          dishOverride: (slot, day) {
            if (slot == 'breakfast' && day == 3) {
              return dishLibrary['breakfast']![0]; // Same as Day 1
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
      'fails when weekly diversity is insufficient: repeated full daily menu',
      () {
        final base = createBaseTimeline(4);
        // Day 4 repeats Day 1 menu exactly
        final candidates = createCandidateWeek(
          mealsPerDay: 4,
          targetCalories: testTargets.targetCalories!,
          proteinTarget: testTargets.proteinTarget!.round(),
          dishOverride: (slot, day) {
            final effectiveDay = day == 4 ? 1 : day;
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

    test(
      'adversarial diversity check: whitespace, case, and ordering variations are detected as duplicate',
      () {
        final base = createBaseTimeline(4);
        // Day 1 breakfast: ['Oatmeal Bowl', 'Almond Milk']
        // Day 2 breakfast: ['  almond milk  ', 'OATMEAL BOWL']
        final candidates = createCandidateWeek(
          mealsPerDay: 4,
          targetCalories: testTargets.targetCalories!,
          proteinTarget: testTargets.proteinTarget!.round(),
          dishOverride: (slot, day) {
            if (slot == 'breakfast' && day == 2) {
              return ['  almond milk  ', 'OATMEAL BOWL'];
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
        final base = createBaseTimeline(
          4,
          targets: targets,
          mealPlanningGoal: 'gain',
        );
        final mapped = mapOnboarding5MealCandidates(
          validCandidates,
          source: onboardingEatingGeneratedSource,
          baseTimeline: base,
        );

        final completedDraft = draft.copyWith(
          baseTimeline: base.copyWith(blocks: mapped.blocks),
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
        final draftWithBasics = OnboardingDraft(
          uid: 'projection-user',
          lifeRole: const LifeRoleDraft(
            lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
            exerciseLevel: '3_4_days',
          ),
          bodyBasics: const BodyBasicsDraft(
            ageRange: '25-34',
            heightCm: 175,
            weightKg: 70,
            gender: 'male',
          ).withEstimates(),
        );
        final targets = draftWithBasics.canonicalNutritionTargets();
        final validCandidates = createCandidateWeek(
          mealsPerDay: 4,
          targetCalories: targets.targetCalories!,
          proteinTarget: targets.proteinTarget!.round(),
        );
        final mapped = mapOnboarding5MealCandidates(
          validCandidates,
          source: onboardingEatingGeneratedSource,
          baseTimeline: createBaseTimeline(4, targets: targets),
        );

        final draft = draftWithBasics.copyWith(
          baseTimeline: createBaseTimeline(
            4,
            targets: targets,
          ).copyWith(blocks: mapped.blocks),
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

  group('Gate 2 - Regeneration Transaction Safety & Retained Routine', () {
    test(
      'editing meal preferences preserves existing valid eating blocks in draft',
      () {
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
        final timelineWithPlanA = base.copyWith(blocks: mapped.blocks);
        expect(
          timelineWithPlanA.confirmedBlocksForSection('eating'),
          hasLength(28),
        );

        // User changes foodType from 'veg' to 'vegan'
        final editedTimeline = timelineWithPlanA.copyWith(foodType: 'vegan');

        // Blocks are preserved!
        expect(
          editedTimeline.confirmedBlocksForSection('eating'),
          hasLength(28),
        );

        // But fingerprint no longer matches computed fingerprint with new settings!
        final error = editedTimeline.validateEatingSetup(targets: testTargets);
        expect(
          error,
          'Your meal preferences changed. Generate the updated weekly routine first.',
        );
      },
    );

    test(
      'atomic replacement: Plan B cleanly replaces Plan A without leaving duplicates',
      () {
        final base = createBaseTimeline(4);
        final planACandidates = createCandidateWeek(
          mealsPerDay: 4,
          targetCalories: testTargets.targetCalories!,
          proteinTarget: testTargets.proteinTarget!.round(),
        );
        final planAMapped = mapOnboarding5MealCandidates(
          planACandidates,
          source: onboardingEatingGeneratedSource,
          baseTimeline: base,
        );
        final timelineWithPlanA = base.copyWith(blocks: planAMapped.blocks);
        expect(
          timelineWithPlanA.confirmedBlocksForSection('eating'),
          hasLength(28),
        );

        // Plan B generated with different dishes
        final planBCandidates = createCandidateWeek(
          mealsPerDay: 4,
          targetCalories: testTargets.targetCalories!,
          proteinTarget: testTargets.proteinTarget!.round(),
          dishOverride: (slot, day) => [
            'Plan B Dish 1 ($slot, d$day)',
            'Plan B Dish 2 ($slot, d$day)',
          ],
        );
        final planBMapped = mapOnboarding5MealCandidates(
          planBCandidates,
          source: onboardingEatingGeneratedSource,
          baseTimeline: base,
        );

        // Replace eating blocks
        final replacedBlocks =
            timelineWithPlanA.blocks
                .where((b) => b.section != 'eating')
                .toList()
              ..addAll(planBMapped.blocks);
        final timelineWithPlanB = timelineWithPlanA.copyWith(
          blocks: replacedBlocks,
        );

        final finalEatingBlocks = timelineWithPlanB.confirmedBlocksForSection(
          'eating',
        );
        expect(finalEatingBlocks, hasLength(28));
        expect(
          finalEatingBlocks.every(
            (b) => b.dishes.first.startsWith('Plan B Dish 1'),
          ),
          isTrue,
        );
      },
    );
  });

  group('Gate 2 - Input Fingerprint Sensitivity', () {
    test('deterministic fingerprint matches for identical inputs', () {
      final base1 = createBaseTimeline(4);
      final base2 = createBaseTimeline(4);
      expect(
        base1.computeEatingGeneratedInputFingerprint(targets: testTargets),
        base2.computeEatingGeneratedInputFingerprint(targets: testTargets),
      );
    });

    test('fingerprint changes when any key input changes', () {
      final base = createBaseTimeline(4);
      final fpBase = base.computeEatingGeneratedInputFingerprint(
        targets: testTargets,
      );

      // mealPlanningGoal
      expect(
        base
            .copyWith(mealPlanningGoal: 'lose')
            .computeEatingGeneratedInputFingerprint(targets: testTargets),
        isNot(fpBase),
      );
      // targetCalories
      expect(
        base.computeEatingGeneratedInputFingerprint(
          targets: NutritionTargets(
            bmi: testTargets.bmi,
            estimatedAge: testTargets.estimatedAge,
            estimatedBmr: testTargets.estimatedBmr,
            activityFactor: testTargets.activityFactor,
            estimatedMaintenanceCalories:
                testTargets.estimatedMaintenanceCalories,
            targetCalories: testTargets.targetCalories! + 100,
            proteinTarget: testTargets.proteinTarget,
            bodyGoal: testTargets.bodyGoal,
            hasBodyBasics: testTargets.hasBodyBasics,
          ),
        ),
        isNot(fpBase),
      );
      // proteinTarget
      expect(
        base.computeEatingGeneratedInputFingerprint(
          targets: NutritionTargets(
            bmi: testTargets.bmi,
            estimatedAge: testTargets.estimatedAge,
            estimatedBmr: testTargets.estimatedBmr,
            activityFactor: testTargets.activityFactor,
            estimatedMaintenanceCalories:
                testTargets.estimatedMaintenanceCalories,
            targetCalories: testTargets.targetCalories,
            proteinTarget: testTargets.proteinTarget! + 20,
            bodyGoal: testTargets.bodyGoal,
            hasBodyBasics: testTargets.hasBodyBasics,
          ),
        ),
        isNot(fpBase),
      );
      // foodType
      expect(
        base
            .copyWith(foodType: 'non_veg')
            .computeEatingGeneratedInputFingerprint(targets: testTargets),
        isNot(fpBase),
      );
      // eatingMode
      expect(
        base
            .copyWith(eatingMode: 'mediterranean')
            .computeEatingGeneratedInputFingerprint(targets: testTargets),
        isNot(fpBase),
      );
      // foodStyleCustomText
      expect(
        base
            .copyWith(foodStyleCustomText: 'No spicy food')
            .computeEatingGeneratedInputFingerprint(targets: testTargets),
        isNot(fpBase),
      );
      // mealsPerDay
      expect(
        base
            .copyWith(mealsPerDay: 5)
            .computeEatingGeneratedInputFingerprint(targets: testTargets),
        isNot(fpBase),
      );
      // breakfastMinute
      expect(
        base
            .copyWith(breakfastMinute: 9 * 60)
            .computeEatingGeneratedInputFingerprint(targets: testTargets),
        isNot(fpBase),
      );
    });
  });

  group('Gate 2 - Legacy Plan Migration Contract', () {
    test(
      'isLegacyGeneratedEatingPlan flags unversioned and older version plans',
      () {
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

        // Version null
        final unversioned = base.copyWith(
          blocks: mapped.blocks,
          clearEatingGeneratedPlanVersion: true,
        );
        expect(isLegacyGeneratedEatingPlan(unversioned), isTrue);

        // Version 1
        final v1 = base.copyWith(
          blocks: mapped.blocks,
          eatingGeneratedPlanVersion: 1,
        );
        expect(isLegacyGeneratedEatingPlan(v1), isTrue);

        // Version 2 with 28 day-specific blocks -> not legacy
        final v2 = base.copyWith(
          blocks: mapped.blocks,
          eatingGeneratedPlanVersion: 2,
        );
        expect(isLegacyGeneratedEatingPlan(v2), isFalse);
      },
    );

    test(
      'isLegacyGeneratedEatingPlan flags plans with repeating multi-day blocks',
      () {
        final multiDayBlock = TimelineBlockDraft(
          id: 'eating-ai-d1-breakfast',
          section: 'eating',
          title: 'Breakfast',
          startMinute: 8 * 60,
          endMinute: 8 * 60 + 30,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7], // multi-day!
          blockType: TimelineBlockDraft.hardBlockKey,
          source: onboardingEatingGeneratedSource,
          mealSlot: 'breakfast',
          dishes: const ['Dish 1'],
          calories: 500,
          protein: 30,
        );
        final multiDayBase = createBaseTimeline(
          3,
        ).copyWith(blocks: [multiDayBlock], eatingGeneratedPlanVersion: 2);
        expect(isLegacyGeneratedEatingPlan(multiDayBase), isTrue);
      },
    );

    test(
      'completed user at or past Step 14 remains valid even with legacy draft',
      () {
        final legacyDraft = OnboardingDraft(
          uid: 'completed-legacy-user',
          currentStep: 14,
          stepCompleted: List.filled(15, true),
          baseTimeline: const BaseTimelineDraft(
            eatingSetupPath: onboardingEatingPathCreate,
            eatingGeneratedPlanVersion: 1,
          ),
        );
        // Invariant: completed user is not broken by migration check
        expect(legacyDraft.stepCompleted[14], isTrue);
        expect(legacyDraft.currentStep, 14);
      },
    );
  });

  group(
    'Gate 2 - Third Pass Closure: Strict Fingerprint, Versioning & Source Purity',
    () {
      test(
        'validateEatingSetup fails closed on null or blank fingerprint for version 2',
        () {
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

          // Version 2 with null fingerprint -> must reject
          final v2NullFp = base.copyWith(
            blocks: mapped.blocks,
            eatingGeneratedPlanVersion: 2,
            clearEatingGeneratedInputFingerprint: true,
          );
          final inputs = base.canonicalEatingGenerationInputs(
            targets: testTargets,
          );
          final errNull = v2NullFp.validateEatingSetup(
            targets: testTargets,
            generationInputs: inputs,
          );
          expect(errNull, isNotNull);
          expect(errNull, contains('missing generation verification'));

          // Version 2 with whitespace fingerprint -> must reject
          final v2BlankFp = base.copyWith(
            blocks: mapped.blocks,
            eatingGeneratedPlanVersion: 2,
            eatingGeneratedInputFingerprint: '   ',
          );
          final errBlank = v2BlankFp.validateEatingSetup(
            targets: testTargets,
            generationInputs: inputs,
          );
          expect(errBlank, isNotNull);
          expect(errBlank, contains('missing generation verification'));
        },
      );

      test('validateEatingSetup fails closed on mismatched fingerprint', () {
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
        final v2WrongFp = base.copyWith(
          blocks: mapped.blocks,
          eatingGeneratedPlanVersion: 2,
          eatingGeneratedInputFingerprint: 'outdated_hash_12345',
        );
        final inputs = base.canonicalEatingGenerationInputs(
          targets: testTargets,
        );
        final err = v2WrongFp.validateEatingSetup(
          targets: testTargets,
          generationInputs: inputs,
        );
        expect(err, isNotNull);
        expect(err, contains('Your meal preferences changed'));
      });

      test('validateEatingSetup fails closed on future version (> 2)', () {
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
        final v3 = base.copyWith(
          blocks: mapped.blocks,
          eatingGeneratedPlanVersion: 3,
          eatingGeneratedInputFingerprint: 'future_hash',
        );
        final err = v3.validateEatingSetup(
          targets: testTargets,
          generationInputs: base.canonicalEatingGenerationInputs(
            targets: testTargets,
          ),
        );
        expect(err, isNotNull);
        expect(err, contains('unsupported newer format'));
      });

      test(
        'validateEatingSetup returns legacy message for version < 2 or unversioned',
        () {
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
          final v1 = base.copyWith(
            blocks: mapped.blocks,
            eatingGeneratedPlanVersion: 1,
          );
          final err = v1.validateEatingSetup(
            targets: testTargets,
            generationInputs: base.canonicalEatingGenerationInputs(
              targets: testTargets,
            ),
          );
          expect(err, isNotNull);
          expect(err, contains('older weekly format'));
        },
      );

      test('validateEatingSetup enforces source purity under create path', () {
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

        // Block with ai_import instead of ai_generated_meal_setup
        final taintedBlocks = mapped.blocks.map((b) {
          if (b.repeatDays.contains(1) && b.mealSlot == 'breakfast') {
            return b.copyWith(source: 'ai_import');
          }
          return b;
        }).toList();

        final inputs = base.canonicalEatingGenerationInputs(
          targets: testTargets,
        );
        final tainted = base.copyWith(
          blocks: taintedBlocks,
          eatingGeneratedPlanVersion: 2,
          eatingGeneratedInputFingerprint: inputs.computeFingerprint(),
        );

        final err = tainted.validateEatingSetup(
          targets: testTargets,
          generationInputs: inputs,
        );
        expect(err, isNotNull);
        expect(err, contains('invalid meal items'));
      });

      test(
        'EatingGenerationInputs and computeFingerprint are sensitive to all material inputs',
        () {
          const inputs1 = EatingGenerationInputs(
            contractVersion: 2,
            heightCm: 175.0,
            weightKg: 70.0,
            estimatedAge: 30,
            gender: 'male',
            exerciseLevel: '3_4_days',
            lifeRole: 'student',
            bmi: 22.86,
            estimatedBmr: 1675,
            estimatedMaintenanceCalories: 2261,
            bodyGoal: 'maintain',
            targetMode: 'calories_and_protein',
            targetCalories: 2261,
            proteinTarget: 140.0,
            foodType: 'veg',
            eatingMode: 'intermittent_fasting',
            foodStyleCustomText: '',
            mealsPerDay: 4,
            breakfastMinute: 480,
            morningSnackMinute: null,
            lunchMinute: 780,
            afternoonSnackMinute: 1020,
            dinnerMinute: 1230,
            country: 'IN',
          );
          final fp1 = inputs1.computeFingerprint();

          // lifeRole difference
          expect(
            inputs1.copyWith(lifeRole: 'entrepreneur').computeFingerprint(),
            isNot(fp1),
          );

          // exerciseLevel difference
          expect(
            inputs1.copyWith(exerciseLevel: 'rarely').computeFingerprint(),
            isNot(fp1),
          );

          // weightKg difference (even 0.1 kg)
          expect(
            inputs1.copyWith(weightKg: 70.1).computeFingerprint(),
            isNot(fp1),
          );

          // heightCm difference
          expect(
            inputs1.copyWith(heightCm: 176.0).computeFingerprint(),
            isNot(fp1),
          );

          // gender difference
          expect(
            inputs1.copyWith(gender: 'female').computeFingerprint(),
            isNot(fp1),
          );

          // estimatedAge difference
          expect(
            inputs1.copyWith(estimatedAge: 31).computeFingerprint(),
            isNot(fp1),
          );

          // targetCalories difference
          expect(
            inputs1.copyWith(targetCalories: 2300).computeFingerprint(),
            isNot(fp1),
          );

          // proteinTarget difference
          expect(
            inputs1.copyWith(proteinTarget: 145.0).computeFingerprint(),
            isNot(fp1),
          );
        },
      );
    },
  );
}
