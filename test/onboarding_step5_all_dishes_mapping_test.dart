import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  group('Onboarding 5 Dish Extraction Mapping and UI', () {
    testWidgets('extracts all dishes without arbitrary limits and renders them directly without normal ellipsis or +N more', (tester) async {
      // 1. First test the pure mapping logic
      final candidates = [
        RoutineImportCandidateBlock(
          id: 'test_1',
          title: 'Fruit Snack',
          startMinute: 600,
          endMinute: 630,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: 'activity',
          category: 'eating',
          hardBlock: false,
          sourceTextSnippet: 'Apple, Banana, Orange, Peach',
          steps: ['Strawberry', 'Blueberry'],
          extractionEngine: 'test',
        ),
      ];

      final result = mapOnboarding5MealCandidates(candidates, now: DateTime.now(), baseTimeline: null);
      expect(result.blocks.isNotEmpty, true);
      
      final firstBlock = result.blocks.first;
      final allDishes = firstBlock.dishes;
      
      expect(allDishes.contains('Strawberry'), true);
      expect(allDishes.contains('Blueberry'), true);
      expect(allDishes.contains('Apple'), true);
      expect(allDishes.contains('Banana'), true);
      expect(allDishes.contains('Orange'), true);
      expect(allDishes.contains('Peach'), true);
      expect(allDishes.length, 7);

      // 2. Now test the actual Step 5 UI rendering with 6 dishes
      final draft = OnboardingDraft(
        baseTimeline: BaseTimelineDraft(
          eatingSetupStep: 1,
          eatingSetupPath: 'create',
          blocks: [
            TimelineBlockDraft(
              id: 'large-snack',
              title: 'Huge Snack',
              section: 'eating',
              blockType: 'soft_block',
              startMinute: 700,
              endMinute: 730,
              repeatDays: [1, 2, 3, 4, 5],
              dishes: [
                'First Long Dish Name',
                'Second Long Dish Name',
                'Third Long Dish Name',
                'Fourth Long Dish Name',
                'Fifth Long Dish Name',
                'Sixth Long Dish Name'
              ],
              source: 'ai_generated_meal_setup',
            ),
          ],
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
            mockOnboardingProvider.overrideWith(
              (_) => MockOnboardingNotifier()..loadSeedData(draft),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(child: OnboardingStep5()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      
      // All 6 dishes should be directly visible
      expect(find.text('First Long Dish Name'), findsOneWidget);
      expect(find.text('Second Long Dish Name'), findsOneWidget);
      expect(find.text('Third Long Dish Name'), findsOneWidget);
      expect(find.text('Fourth Long Dish Name'), findsOneWidget);
      expect(find.text('Fifth Long Dish Name'), findsOneWidget);
      expect(find.text('Sixth Long Dish Name'), findsOneWidget);

      // Verify no "+N more" text is displayed in this normal condition
      expect(find.textContaining('more'), findsNothing);
      expect(find.textContaining('+'), findsNothing);
    });
  });
}
