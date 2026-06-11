import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/models/routine_import_review.dart';

void main() {
  group('Onboarding 5 Dish Extraction Mapping', () {
    test('extracts all dishes from source text snippet and steps without arbitrary limits', () {
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
          sourceTextSnippet: 'Apple, Banana, Orange, Peach, Grape, Melon, Kiwi, Mango',
          steps: ['Strawberry', 'Blueberry', 'Raspberry'],
          extractionEngine: 'test',
        ),
      ];

      final result = mapOnboarding5MealCandidates(candidates, now: DateTime.now(), baseTimeline: null);
      
      // We expect 1 block mapped for weekdays (or individual blocks)
      expect(result.blocks.isNotEmpty, true);
      
      final firstBlock = result.blocks.first;
      
      // Expected dishes from steps + text snippet
      final allDishes = firstBlock.dishes;
      
      expect(allDishes.contains('Strawberry'), true);
      expect(allDishes.contains('Blueberry'), true);
      expect(allDishes.contains('Raspberry'), true);
      expect(allDishes.contains('Apple'), true);
      expect(allDishes.contains('Banana'), true);
      expect(allDishes.contains('Mango'), true);
      expect(allDishes.contains('Fruit'), true);
      expect(allDishes.length, 12);
    });
  });
}
