import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/services/nutrition_target_service.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  const targetService = NutritionTargetService();
  final testTargets = targetService.calculate(
    ageRange: '25-34',
    heightCm: 175,
    weightKg: 70,
    gender: 'male',
    exerciseLevel: '3_4_days',
    bodyGoal: 'maintain',
  );

  const dishLibrary = {
    'breakfast': [
      ['Vegetable Poha', 'Curd'],
      ['Oats with Almonds', 'Boiled Egg'],
      ['Idli Sambar', 'Coconut Chutney'],
      ['Moong Dal Cheela', 'Mint Chutney'],
      ['Whole Wheat Toast', 'Scrambled Eggs'],
      ['Besan Cheela', 'Plain Curd'],
      ['Paneer Bhurji', 'Roti'],
    ],
    'morning_snack': [
      ['Apple Slices', 'Peanut Butter'],
      ['Mixed Nuts', 'Green Tea'],
      ['Roasted Makhana', 'Almonds'],
      ['Fruit Salad', 'Walnuts'],
      ['Sprouted Moong', 'Lemon Juice'],
      ['Greek Yogurt', 'Chia Seeds'],
      ['Boiled Chana', 'Chaat Masala'],
    ],
    'lunch': [
      ['Brown Rice', 'Dal Tadka', 'Spinach'],
      ['Quinoa Bowl', 'Chickpea Curry'],
      ['Chapati', 'Rajma Curry', 'Salad'],
      ['Brown Rice', 'Paneer Curry', 'Salad'],
      ['Millet Roti', 'Mixed Dal', 'Bhindi'],
      ['Vegetable Pulao', 'Raita'],
      ['Roti', 'Soya Curry', 'Salad'],
    ],
    'afternoon_snack': [
      ['Roasted Chana', 'Buttermilk'],
      ['Carrot Sticks', 'Hummus Dip'],
      ['Pistachios', 'Herbal Tea'],
      ['Sprouts Chaat', 'Pomegranate'],
      ['Dry Fruits', 'Coconut Water'],
      ['Cucumber Slices', 'Guacamole'],
      ['Boiled Corn', 'Lime Juice'],
    ],
    'dinner': [
      ['Whole Wheat Roti', 'Methi Paneer', 'Soup'],
      ['Lentil Soup', 'Steamed Broccoli', 'Tofu'],
      ['Multigrain Roti', 'Palak Dal', 'Salad'],
      ['Grilled Fish', 'Steamed Veggies', 'Millet'],
      ['Egg Curry', 'Roti', 'Kachumber'],
      ['Khichdi', 'Curd', 'Roasted Papad'],
      ['Tofu Stir Fry', 'Brown Rice', 'Soup'],
    ],
  };

  List<RoutineImportCandidateBlock> createCandidateWeek({
    required int mealsPerDay,
    int? targetCalories,
    double? proteinTarget,
    int breakfastMinute = 480,
    int lunchMinute = 780,
    int dinnerMinute = 1230,
    int? morningSnackMinute,
    int? afternoonSnackMinute,
  }) {
    final effectiveCalories =
        targetCalories ?? testTargets.targetCalories ?? 2256;
    final effectiveProtein =
        proteinTarget ?? testTargets.proteinTarget ?? 140.0;

    final slotDefs = <(String, String, int, int)>[
      ('breakfast', 'Breakfast', breakfastMinute, 30),
      if (mealsPerDay >= 5)
        (
          'morning_snack',
          'Snack',
          morningSnackMinute ?? (breakfastMinute + 120),
          20,
        ),
      ('lunch', 'Lunch', lunchMinute, 45),
      if (mealsPerDay >= 4)
        (
          'afternoon_snack',
          'Snack',
          afternoonSnackMinute ?? (lunchMinute + 210),
          20,
        ),
      ('dinner', 'Dinner', dinnerMinute, 45),
    ];

    final calPerMeal = (effectiveCalories / slotDefs.length).toDouble();
    final proPerMeal = (effectiveProtein / slotDefs.length).toDouble();

    final candidates = <RoutineImportCandidateBlock>[];
    for (var d = 1; d <= 7; d++) {
      for (final slot in slotDefs) {
        final slotId = slot.$1;
        final title = slot.$2;
        final start = slot.$3;
        final duration = slot.$4;
        final dishes =
            dishLibrary[slotId]?[d - 1] ?? ['Dish A $d', 'Dish B $d'];

        candidates.add(
          RoutineImportCandidateBlock(
            id: 'gen-d$d-$slotId',
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
            caloriesEstimate: calPerMeal,
            proteinEstimate: proPerMeal,
          ),
        );
      }
    }
    return candidates;
  }

  OnboardingDraft makeSeededDraft({
    required int mealsPerDay,
    String? bodyGoal,
    String? foodType,
    String? eatingMode,
    int? breakfastMinute,
    int? lunchMinute,
    int? dinnerMinute,
  }) {
    final candidateBlocks = createCandidateWeek(
      mealsPerDay: mealsPerDay,
      targetCalories: testTargets.targetCalories,
      proteinTarget: testTargets.proteinTarget,
    );

    final mapped = mapOnboarding5MealCandidates(
      candidateBlocks,
      now: DateTime.now(),
      source: onboardingEatingGeneratedSource,
    );

    final initialDraft = OnboardingDraft(
      uid: 'test-user',
      lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
      bodyBasics: const BodyBasicsDraft(
        ageRange: '25-34',
        heightCm: 175,
        weightKg: 70,
        gender: 'male',
      ).withEstimates(),
      baseTimeline: BaseTimelineDraft(
        eatingSetupPath: onboardingEatingPathCreate,
        eatingSetupStep: 2, // review screen
        mealsPerDay: mealsPerDay,
        mealPlanningGoal: bodyGoal ?? 'maintain',
        foodType: foodType ?? 'mixed',
        eatingMode: eatingMode ?? 'india',
        breakfastMinute: breakfastMinute ?? 480,
        lunchMinute: lunchMinute ?? 780,
        dinnerMinute: dinnerMinute ?? 1230,
        eatingGeneratedPlanVersion:
            BaseTimelineDraft.currentGate2EatingPlanVersion,
        blocks: mapped.blocks,
      ),
    );

    final targets = initialDraft.canonicalNutritionTargets();
    final inputs = initialDraft.canonicalEatingGenerationInputs(
      targets: targets,
    );
    return initialDraft.copyWith(
      baseTimeline: initialDraft.baseTimeline.copyWith(
        eatingGeneratedInputFingerprint: inputs.computeFingerprint(),
      ),
    );
  }

  group('Step 5 Eating Regeneration — Preference Changes & Atomic Replacement', () {
    testWidgets(
      'Plan A (3 meals, 21 blocks) -> change to 4 meals -> Plan B (28 blocks) replaces Plan A',
      (tester) async {
        final initialDraft = makeSeededDraft(mealsPerDay: 3);
        expect(
          initialDraft.baseTimeline.confirmedBlocksForSection('eating').length,
          21,
        );

        final fakeClient = _MockConfigurableNutritionClient(
          responder: (params) {
            final mealsPerDay = params['mealsPerDay'] as int? ?? 3;
            final candidates = createCandidateWeek(
              mealsPerDay: mealsPerDay,
              targetCalories: testTargets.targetCalories,
              proteinTarget: testTargets.proteinTarget,
            );
            return RoutineImportExtractionResult(
              id: 'resp-new-4meals',
              uid: 'test-user',
              source: RoutineImportReviewSource.eating,
              createdAt: DateTime.now(),
              candidates: candidates,
            );
          },
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => OnboardingNotifier()..loadSeedData(initialDraft),
              ),
              nutritionAiClientProvider.overrideWithValue(fakeClient),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  home: Scaffold(body: OnboardingStep5()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // We are in review mode (eatingSetupStep == 2)
        expect(
          find.byKey(const ValueKey('onboarding-step5-review-screen')),
          findsOneWidget,
        );

        // User navigates back to preferences (eatingSetupStep = 1)
        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(eatingSetupStep: 1),
          );
        });
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('onboarding-step5-setup-screen')),
          findsOneWidget,
        );

        // User changes meals per day from 3 to 4
        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(mealsPerDay: 4),
          );
        });
        await tester.pumpAndSettle();

        // Tap generate routine
        final generateBtn = find.text('Generate meal routine');
        expect(generateBtn, findsOneWidget);
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        // Check results
        final currentDraft = container.read(onboardingStateProvider).draft;
        final eatingBlocks = currentDraft.baseTimeline
            .confirmedBlocksForSection('eating');
        expect(eatingBlocks.length, 28);
        expect(currentDraft.baseTimeline.mealsPerDay, 4);

        // Verify all 7 days have 4 distinct meal slots
        for (var d = 1; d <= 7; d++) {
          final dayBlocks = eatingBlocks
              .where((b) => b.repeatDays.contains(d))
              .toList();
          expect(dayBlocks.length, 4);
          final slots = dayBlocks.map((b) => b.mealSlot).toSet();
          expect(slots, {'breakfast', 'lunch', 'afternoon_snack', 'dinner'});
        }
      },
    );

    testWidgets(
      'Plan A (4 meals, 28 blocks) -> change to 3 meals -> Plan B (21 blocks) replaces Plan A',
      (tester) async {
        final initialDraft = makeSeededDraft(mealsPerDay: 4);
        expect(
          initialDraft.baseTimeline.confirmedBlocksForSection('eating').length,
          28,
        );

        final fakeClient = _MockConfigurableNutritionClient(
          responder: (params) {
            final mealsPerDay = params['mealsPerDay'] as int? ?? 3;
            final candidates = createCandidateWeek(
              mealsPerDay: mealsPerDay,
              targetCalories: testTargets.targetCalories,
              proteinTarget: testTargets.proteinTarget,
            );
            return RoutineImportExtractionResult(
              id: 'resp-new-3meals',
              uid: 'test-user',
              source: RoutineImportReviewSource.eating,
              createdAt: DateTime.now(),
              candidates: candidates,
            );
          },
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => OnboardingNotifier()..loadSeedData(initialDraft),
              ),
              nutritionAiClientProvider.overrideWithValue(fakeClient),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  home: Scaffold(body: OnboardingStep5()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(
              eatingSetupStep: 1,
              mealsPerDay: 3,
            ),
          );
        });
        await tester.pumpAndSettle();

        final generateBtn = find.text('Generate meal routine');
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        final currentDraft = container.read(onboardingStateProvider).draft;
        final eatingBlocks = currentDraft.baseTimeline
            .confirmedBlocksForSection('eating');
        expect(eatingBlocks.length, 21);
        expect(currentDraft.baseTimeline.mealsPerDay, 3);
      },
    );

    testWidgets(
      'Plan A (4 meals, 28 blocks) -> change to 5 meals -> Plan B (35 blocks) replaces Plan A',
      (tester) async {
        final initialDraft = makeSeededDraft(mealsPerDay: 4);

        final fakeClient = _MockConfigurableNutritionClient(
          responder: (params) {
            final mealsPerDay = params['mealsPerDay'] as int? ?? 5;
            final candidates = createCandidateWeek(
              mealsPerDay: mealsPerDay,
              targetCalories: testTargets.targetCalories,
              proteinTarget: testTargets.proteinTarget,
            );
            return RoutineImportExtractionResult(
              id: 'resp-new-5meals',
              uid: 'test-user',
              source: RoutineImportReviewSource.eating,
              createdAt: DateTime.now(),
              candidates: candidates,
            );
          },
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => OnboardingNotifier()..loadSeedData(initialDraft),
              ),
              nutritionAiClientProvider.overrideWithValue(fakeClient),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  home: Scaffold(body: OnboardingStep5()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(
              eatingSetupStep: 1,
              mealsPerDay: 5,
            ),
          );
        });
        await tester.pumpAndSettle();

        final generateBtn = find.text('Generate meal routine');
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        final currentDraft = container.read(onboardingStateProvider).draft;
        final eatingBlocks = currentDraft.baseTimeline
            .confirmedBlocksForSection('eating');
        expect(eatingBlocks.length, 35);
        expect(currentDraft.baseTimeline.mealsPerDay, 5);
      },
    );

    testWidgets(
      'Plan A -> Goal change (Gain -> Maintain) regenerates with new fingerprint',
      (tester) async {
        final initialDraft = makeSeededDraft(mealsPerDay: 3, bodyGoal: 'gain');
        final initialFingerprint =
            initialDraft.baseTimeline.eatingGeneratedInputFingerprint;

        Map<String, dynamic>? receivedParams;
        final fakeClient = _MockConfigurableNutritionClient(
          responder: (params) {
            receivedParams = params;
            return RoutineImportExtractionResult(
              id: 'resp-goal-change',
              uid: 'test-user',
              source: RoutineImportReviewSource.eating,
              createdAt: DateTime.now(),
              candidates: createCandidateWeek(
                mealsPerDay: 3,
                targetCalories: testTargets.targetCalories,
                proteinTarget: testTargets.proteinTarget,
              ),
            );
          },
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => OnboardingNotifier()..loadSeedData(initialDraft),
              ),
              nutritionAiClientProvider.overrideWithValue(fakeClient),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  home: Scaffold(body: OnboardingStep5()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(
              eatingSetupStep: 1,
              mealPlanningGoal: 'maintain',
            ),
          );
        });
        await tester.pumpAndSettle();

        final generateBtn = find.text('Generate meal routine');
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        expect(receivedParams?['bodyGoal'], 'maintain');
        final newFingerprint = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .eatingGeneratedInputFingerprint;
        expect(newFingerprint, isNot(equals(initialFingerprint)));
      },
    );

    testWidgets(
      'Plan A -> Food type change (Veg -> Non-veg) regenerates successfully',
      (tester) async {
        final initialDraft = makeSeededDraft(mealsPerDay: 3, foodType: 'veg');

        Map<String, dynamic>? receivedParams;
        final fakeClient = _MockConfigurableNutritionClient(
          responder: (params) {
            receivedParams = params;
            return RoutineImportExtractionResult(
              id: 'resp-foodtype-change',
              uid: 'test-user',
              source: RoutineImportReviewSource.eating,
              createdAt: DateTime.now(),
              candidates: createCandidateWeek(
                mealsPerDay: 3,
                targetCalories: testTargets.targetCalories,
                proteinTarget: testTargets.proteinTarget,
              ),
            );
          },
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => OnboardingNotifier()..loadSeedData(initialDraft),
              ),
              nutritionAiClientProvider.overrideWithValue(fakeClient),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  home: Scaffold(body: OnboardingStep5()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(
              eatingSetupStep: 1,
              foodType: 'non_veg',
            ),
          );
        });
        await tester.pumpAndSettle();

        final generateBtn = find.text('Generate meal routine');
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        expect(receivedParams?['foodType'], 'non_veg');
      },
    );

    testWidgets(
      'Plan A -> Meal times change regenerates with updated startMinutes',
      (tester) async {
        final initialDraft = makeSeededDraft(
          mealsPerDay: 3,
          breakfastMinute: 480, // 8:00 AM
          lunchMinute: 780, // 1:00 PM
          dinnerMinute: 1230, // 8:30 PM
        );

        Map<String, dynamic>? receivedParams;
        final fakeClient = _MockConfigurableNutritionClient(
          responder: (params) {
            receivedParams = params;
            return RoutineImportExtractionResult(
              id: 'resp-times-change',
              uid: 'test-user',
              source: RoutineImportReviewSource.eating,
              createdAt: DateTime.now(),
              candidates: createCandidateWeek(
                mealsPerDay: 3,
                breakfastMinute: 540, // 9:00 AM
                lunchMinute: 840, // 2:00 PM
                dinnerMinute: 1260, // 9:00 PM
              ),
            );
          },
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => OnboardingNotifier()..loadSeedData(initialDraft),
              ),
              nutritionAiClientProvider.overrideWithValue(fakeClient),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  home: Scaffold(body: OnboardingStep5()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(
              eatingSetupStep: 1,
              breakfastMinute: 540,
              lunchMinute: 840,
              dinnerMinute: 1260,
            ),
          );
        });
        await tester.pumpAndSettle();

        final generateBtn = find.text('Generate meal routine');
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        expect(receivedParams?['breakfastMinute'], 540);
        expect(receivedParams?['lunchMinute'], 840);
        expect(receivedParams?['dinnerMinute'], 1260);

        final blocks = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .confirmedBlocksForSection('eating');
        final breakfastDay1 = blocks.firstWhere(
          (b) => b.repeatDays.contains(1) && b.mealSlot == 'breakfast',
        );
        expect(breakfastDay1.startMinute, 540);
      },
    );

    testWidgets(
      'Plan A -> Multiple simultaneous changes (meals, goal, foodType, times) regenerate correctly',
      (tester) async {
        final initialDraft = makeSeededDraft(mealsPerDay: 3);

        Map<String, dynamic>? receivedParams;
        final fakeClient = _MockConfigurableNutritionClient(
          responder: (params) {
            receivedParams = params;
            return RoutineImportExtractionResult(
              id: 'resp-multi-change',
              uid: 'test-user',
              source: RoutineImportReviewSource.eating,
              createdAt: DateTime.now(),
              candidates: createCandidateWeek(
                mealsPerDay: 4,
                breakfastMinute: 500,
                lunchMinute: 800,
                dinnerMinute: 1200,
              ),
            );
          },
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => OnboardingNotifier()..loadSeedData(initialDraft),
              ),
              nutritionAiClientProvider.overrideWithValue(fakeClient),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  home: Scaffold(body: OnboardingStep5()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(
              eatingSetupStep: 1,
              mealsPerDay: 4,
              mealPlanningGoal: 'gain',
              foodType: 'non_veg',
              eatingMode: 'custom',
              breakfastMinute: 500,
              lunchMinute: 800,
              dinnerMinute: 1200,
            ),
          );
        });
        await tester.pumpAndSettle();

        final generateBtn = find.text('Generate meal routine');
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        expect(receivedParams?['mealsPerDay'], 4);
        expect(receivedParams?['bodyGoal'], 'gain');
        expect(receivedParams?['foodType'], 'non_veg');
        expect(receivedParams?['eatingMode'], 'custom');

        final eatingBlocks = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .confirmedBlocksForSection('eating');
        expect(eatingBlocks.length, 28);
      },
    );
  });

  group('Step 5 Eating Regeneration — Safety, Retention & Error Handling', () {
    testWidgets(
      'AI failure preserves Plan A and displays specific safe reason AND retention notice',
      (tester) async {
        final initialDraft = makeSeededDraft(mealsPerDay: 3);
        final initialBlocks = initialDraft.baseTimeline
            .confirmedBlocksForSection('eating');
        expect(initialBlocks.length, 21);

        final fakeClient = _MockConfigurableNutritionClient(
          responder: (_) {
            return RoutineImportExtractionResult(
              id: '',
              uid: '',
              source: RoutineImportReviewSource.eating,
              createdAt: DateTime.now(),
              candidates: const [],
              warnings: const ['provider_target_mismatch'],
            );
          },
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => OnboardingNotifier()..loadSeedData(initialDraft),
              ),
              nutritionAiClientProvider.overrideWithValue(fakeClient),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  home: Scaffold(body: OnboardingStep5()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Go back to preferences and change to 4 meals
        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(
              eatingSetupStep: 1,
              mealsPerDay: 4,
            ),
          );
        });
        await tester.pumpAndSettle();

        final generateBtn = find.text('Generate meal routine');
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        // Verify Plan A blocks are completely retained in state
        final currentBlocks = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .confirmedBlocksForSection('eating');
        expect(currentBlocks.length, 21);
        expect(
          currentBlocks.map((b) => b.id),
          equals(initialBlocks.map((b) => b.id)),
        );

        // Verify error message combines the specific safe reason AND retention notice
        expect(
          find.textContaining(
            "AI couldn't match your updated calorie and protein targets closely enough.",
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Your previous routine is still saved.'),
          findsOneWidget,
        );

        // Verify the review screen is showing the retained routine
        expect(
          find.byKey(const ValueKey('onboarding-step5-review-screen')),
          findsOneWidget,
        );

        // When user goes back to preferences step, view current meal routine button is available
        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(eatingSetupStep: 1),
          );
        });
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('onboarding-step5-view-current-routine')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AI provider incomplete week error displays specific message and retains Plan A',
      (tester) async {
        final initialDraft = makeSeededDraft(mealsPerDay: 3);

        final fakeClient = _MockConfigurableNutritionClient(
          responder: (_) {
            return RoutineImportExtractionResult(
              id: '',
              uid: '',
              source: RoutineImportReviewSource.eating,
              createdAt: DateTime.now(),
              candidates: const [],
              warnings: const ['provider_incomplete_week'],
            );
          },
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => OnboardingNotifier()..loadSeedData(initialDraft),
              ),
              nutritionAiClientProvider.overrideWithValue(fakeClient),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  home: Scaffold(body: OnboardingStep5()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(eatingSetupStep: 1),
          );
        });
        await tester.pumpAndSettle();

        final generateBtn = find.text('Generate meal routine');
        await tester.tap(generateBtn);
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            "AI couldn't complete all 7 days for the updated meal plan.",
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Your previous routine is still saved.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Stale in-flight generation response is discarded when user edits while generation is active',
      (tester) async {
        final initialDraft = makeSeededDraft(mealsPerDay: 3);
        final completer = Completer<RoutineImportExtractionResult>();

        final fakeClient = _MockConfigurableNutritionClient(
          asyncResponder: (_) => completer.future,
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => OnboardingNotifier()..loadSeedData(initialDraft),
              ),
              nutritionAiClientProvider.overrideWithValue(fakeClient),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  home: Scaffold(body: OnboardingStep5()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(
              eatingSetupStep: 1,
              mealsPerDay: 4,
            ),
          );
        });
        await tester.pumpAndSettle();

        final generateBtn = find.text('Generate meal routine');
        await tester.tap(generateBtn);
        await tester.pump(); // generation started

        // While generation is in-flight, user edits meal planning goal
        container.read(onboardingStateProvider.notifier).updateDraft((draft) {
          return draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(mealPlanningGoal: 'gain'),
          );
        });

        // Now complete the in-flight request
        completer.complete(
          RoutineImportExtractionResult(
            id: 'resp-stale',
            uid: 'test-user',
            source: RoutineImportReviewSource.eating,
            createdAt: DateTime.now(),
            candidates: createCandidateWeek(mealsPerDay: 4),
          ),
        );
        await tester.pumpAndSettle();

        // The stale response must have been discarded: confirmed blocks must still be initial 21 blocks
        final currentBlocks = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .confirmedBlocksForSection('eating');
        expect(currentBlocks.length, 21);
      },
    );
  });

  group('Canonical defaults in EatingGenerationInputs', () {
    test(
      'supplies mixed and india defaults when foodType and eatingMode are null',
      () {
        const draft = BaseTimelineDraft(
          eatingSetupPath: onboardingEatingPathCreate,
          mealsPerDay: 4,
        );
        expect(draft.foodType, isNull);
        expect(draft.eatingMode, isNull);

        final inputs = EatingGenerationInputs.fromTimeline(
          draft,
          targets: const NutritionTargets(
            bmi: 22.0,
            estimatedAge: 28,
            estimatedBmr: 1600,
            activityFactor: 1.3,
            estimatedMaintenanceCalories: 2000,
            targetCalories: 2000,
            proteinTarget: 100.0,
            bodyGoal: 'maintain',
            hasBodyBasics: true,
          ),
        );
        expect(inputs.foodType, 'mixed');
        expect(inputs.eatingMode, 'india');

        final params = inputs.toWorkerParams();
        expect(params['foodType'], 'mixed');
        expect(params['eatingMode'], 'india');
        expect(params['foodType'], isNotNull);
        expect(params['eatingMode'], isNotNull);
      },
    );
  });
}

class _MockConfigurableNutritionClient implements NutritionAiClient {
  _MockConfigurableNutritionClient({this.responder, this.asyncResponder});

  final RoutineImportExtractionResult Function(Map<String, dynamic> params)?
  responder;
  final Future<RoutineImportExtractionResult> Function(
    Map<String, dynamic> params,
  )?
  asyncResponder;

  @override
  Future<RoutineImportExtractionResult> generateEatingRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    if (asyncResponder != null) {
      return asyncResponder!(params);
    }
    if (responder != null) {
      return responder!(params);
    }
    return RoutineImportExtractionResult(
      id: 'default-id',
      uid: 'test-user',
      source: RoutineImportReviewSource.eating,
      createdAt: DateTime.now(),
      candidates: const [],
    );
  }
}
