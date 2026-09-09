import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  testWidgets(
    'Onboarding 5 renders each canonical meal card with its matching position and dishes',
    (tester) async {
      final mapped = mapOnboarding5MealCandidates(
        [
          for (var d = 1; d <= 7; d++) ...[
            _mealCandidate('', 'breakfast', 'Breakfast', 'breakfast', [
              'Upma',
              'Egg',
            ], day: d),
            _mealCandidate('same', 'lunch', 'Lunch', 'lunch', [
              'Rice',
              'Dal',
            ], day: d),
            _mealCandidate('same', 'afternoon_snack', 'Snack', 'snack', [
              'Fruit',
              'Yogurt',
            ], day: d),
            _mealCandidate('', 'dinner', 'Dinner', 'dinner', [
              'Roti',
              'Paneer',
            ], day: d),
          ],
        ],
        source: onboardingEatingGeneratedSource,
        baseTimeline: const BaseTimelineDraft(
          mealsPerDay: 4,
          breakfastMinute: 8 * 60,
          lunchMinute: 13 * 60,
          snackMinute: 17 * 60,
          dinnerMinute: 20 * 60 + 30,
        ),
      );
      final base = BaseTimelineDraft(
        eatingSetupStep: 2,
        eatingSetupPath: 'create',
        mealsPerDay: 4,
        breakfastMinute: 8 * 60,
        lunchMinute: 13 * 60,
        snackMinute: 17 * 60,
        dinnerMinute: 20 * 60 + 30,
        eatingGeneratedPlanVersion:
            BaseTimelineDraft.currentGate2EatingPlanVersion,
        blocks: mapped.blocks,
      );
      final initialDraft = OnboardingDraft(baseTimeline: base);
      final targets = initialDraft.canonicalNutritionTargets();
      final inputs = initialDraft.canonicalEatingGenerationInputs(
        targets: targets,
      );
      final draft = initialDraft.copyWith(
        baseTimeline: initialDraft.baseTimeline.copyWith(
          eatingGeneratedInputFingerprint: inputs.computeFingerprint(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStateProvider.overrideWith(
              (_) => OnboardingNotifier()..loadSeedData(draft),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SizedBox.expand(child: OnboardingStep5())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final dish in [
        'Upma',
        'Egg',
        'Rice',
        'Dal',
        'Fruit',
        'Yogurt',
        'Roti',
        'Paneer',
      ]) {
        expect(find.text(dish), findsOneWidget);
      }
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Snack'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('8:00 AM - 8:30 AM'), findsOneWidget);
      expect(find.text('1:00 PM - 1:45 PM'), findsOneWidget);
      expect(find.text('5:00 PM - 5:20 PM'), findsOneWidget);
      expect(find.text('8:30 PM - 9:15 PM'), findsOneWidget);
    },
  );

  testWidgets('Onboarding 5 short meal timeline alignment test', (
    tester,
  ) async {
    final testBlocks = <TimelineBlockDraft>[
      for (var d = 1; d <= 7; d++) ...[
        TimelineBlockDraft(
          id: 'breakfast-$d',
          title: 'Breakfast',
          section: 'eating',
          mealCategory: 'breakfast',
          blockType: 'hard_block',
          startMinute: 8 * 60,
          endMinute: 8 * 60 + 30,
          repeatDays: [d],
          dishes: ['Pancakes', 'Berries'],
          source: 'ai_generated_meal_setup',
          calories: 500,
          protein: 30,
        ),
        TimelineBlockDraft(
          id: 'short-snack-$d',
          title: 'Snack',
          section: 'eating',
          mealCategory: 'snack',
          blockType: 'hard_block',
          startMinute: 17 * 60, // 5:00 PM
          endMinute: 17 * 60 + 20, // 5:20 PM
          repeatDays: [d],
          dishes: d == 1
              ? [
                  'Roasted Almonds',
                  'Green Tea',
                  'Protein Bar',
                  'Apple Slices',
                  'Greek Yogurt',
                  'Dark Chocolate',
                ]
              : ['Almonds', 'Tea'],
          source: 'ai_generated_meal_setup',
          calories: 300,
          protein: 20,
        ),
        TimelineBlockDraft(
          id: 'long-dinner-$d',
          title: 'Dinner',
          section: 'eating',
          mealCategory: 'dinner',
          blockType: 'hard_block',
          startMinute: 19 * 60, // 7:00 PM
          endMinute: 20 * 60, // 8:00 PM
          repeatDays: [d],
          dishes: ['Steak', 'Salad'],
          source: 'ai_generated_meal_setup',
          calories: 700,
          protein: 40,
        ),
      ],
    ];

    final base = BaseTimelineDraft(
      eatingSetupStep: 2,
      eatingSetupPath: 'create',
      mealsPerDay: 3,
      breakfastMinute: 8 * 60,
      snackMinute: 17 * 60,
      dinnerMinute: 19 * 60,
      eatingGeneratedPlanVersion:
          BaseTimelineDraft.currentGate2EatingPlanVersion,
      blocks: testBlocks,
    );
    final initialDraft = OnboardingDraft(baseTimeline: base);
    final targets = initialDraft.canonicalNutritionTargets();
    final inputs = initialDraft.canonicalEatingGenerationInputs(
      targets: targets,
    );
    final draft = initialDraft.copyWith(
      baseTimeline: initialDraft.baseTimeline.copyWith(
        eatingGeneratedInputFingerprint: inputs.computeFingerprint(),
      ),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingStateProvider.overrideWith(
            (_) => OnboardingNotifier()..loadSeedData(draft),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox.expand(child: OnboardingStep5())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 6 dishes should be visible inside the block
    expect(find.text('Snack'), findsOneWidget);
    expect(find.text('Roasted Almonds'), findsOneWidget);
    expect(find.text('Green Tea'), findsOneWidget);
    expect(find.text('Protein Bar'), findsOneWidget);
    expect(find.text('Apple Slices'), findsOneWidget);
    expect(find.text('Greek Yogurt'), findsOneWidget);
    expect(find.text('Dark Chocolate'), findsOneWidget);
    expect(find.text('5:00 PM - 5:20 PM'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('7:00 PM - 8:00 PM'), findsOneWidget);

    expect(find.textContaining('more'), findsNothing);
    expect(find.textContaining('+'), findsNothing);

    // Verify timeline layout logic alignment
    final blockFinder = find
        .ancestor(of: find.text('Snack'), matching: find.byType(Positioned))
        .first;

    final positioned = tester.widget<Positioned>(blockFinder);

    // The required height for 6 dishes + title should be much larger than 20 minutes * 0.82 px/min (16.4px)
    expect(positioned.height, greaterThan(100.0));

    // Check that timeline stretches local segment but not unrelated downstream markers
    // To prove this, we can just check if Dinner start time marker exists and is below the block
    final dinnerBlockFinder = find
        .ancestor(of: find.text('Dinner'), matching: find.byType(Positioned))
        .first;
    final dinnerPositioned = tester.widget<Positioned>(dinnerBlockFinder);

    expect(
      dinnerPositioned.top,
      greaterThan(positioned.top! + positioned.height!),
    );
  });
}

RoutineImportCandidateBlock _mealCandidate(
  String id,
  String slot,
  String title,
  String category,
  List<String> dishes, {
  int day = 1,
}) => RoutineImportCandidateBlock(
  id: id,
  mealSlot: slot,
  title: title,
  startMinute: 0,
  endMinute: 1,
  repeatDays: [day],
  blockType: TimelineBlockDraft.softBlockKey,
  category: 'eating',
  hardBlock: false,
  mealCategory: category,
  steps: dishes,
  caloriesEstimate: 500.0,
  proteinEstimate: 35.0,
);
