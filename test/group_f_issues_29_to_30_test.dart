import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/services/onboarding_completion_service.dart';

void main() {
  group('Issue 29: Meal Schedule Density and Spacing Validation', () {
    test(
      'validateMealScheduleDensity fails when meals on same day are spaced < 120 minutes apart',
      () {
        final base = BaseTimelineDraft(
          blocks: [
            TimelineBlockDraft(
              id: 'm1',
              section: 'eating',
              title: 'Breakfast',
              startMinute: 8 * 60, // 08:00 (480)
              endMinute: 8 * 60 + 30, // 08:30
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              mealCategory: 'breakfast',
              dishes: ['Oatmeal'],
            ),
            TimelineBlockDraft(
              id: 'm2',
              section: 'eating',
              title: 'Mid-morning Snack',
              startMinute:
                  9 * 60 + 30, // 09:30 (570) -> 90 min difference < 120 min
              endMinute: 9 * 60 + 50,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              mealCategory: 'snack',
              dishes: ['Apple'],
            ),
          ],
        );

        final error = base.validateMealScheduleDensity();
        expect(error, isNotNull);
        expect(error, contains('120 minutes'));
      },
    );

    test(
      'validateMealScheduleDensity fails when more than 6 meals are scheduled per day',
      () {
        final base = BaseTimelineDraft(
          blocks: [
            for (int i = 0; i < 7; i++)
              TimelineBlockDraft(
                id: 'm_$i',
                section: 'eating',
                title: 'Meal ${i + 1}',
                startMinute:
                    (6 + i * 2) *
                    60, // 06:00, 08:00, 10:00, 12:00, 14:00, 16:00, 18:00 (7 meals, 120m apart)
                endMinute: (6 + i * 2) * 60 + 30,
                repeatDays: [1],
                blockType: TimelineBlockDraft.hardBlockKey,
                mealCategory: 'meal_${i + 1}',
                dishes: ['Dish ${i + 1}'],
              ),
          ],
        );

        final error = base.validateMealScheduleDensity();
        expect(error, isNotNull);
        expect(error, contains('6 meals'));
      },
    );

    test(
      'validateMealScheduleDensity passes with valid spacing (>= 120 min) and <= 6 meals per day',
      () {
        final base = BaseTimelineDraft(
          blocks: [
            TimelineBlockDraft(
              id: 'm1',
              section: 'eating',
              title: 'Breakfast',
              startMinute: 8 * 60, // 480
              endMinute: 8 * 60 + 30,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              mealCategory: 'breakfast',
              dishes: ['Oatmeal'],
            ),
            TimelineBlockDraft(
              id: 'm2',
              section: 'eating',
              title: 'Lunch',
              startMinute: 13 * 60, // 780 (300 min difference >= 120 min)
              endMinute: 13 * 60 + 45,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              mealCategory: 'lunch',
              dishes: ['Rice & Curry'],
            ),
            TimelineBlockDraft(
              id: 'm3',
              section: 'eating',
              title: 'Dinner',
              startMinute: 20 * 60, // 1200 (420 min difference >= 120 min)
              endMinute: 20 * 60 + 45,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              mealCategory: 'dinner',
              dishes: ['Salad & Soup'],
            ),
          ],
        );

        expect(base.validateMealScheduleDensity(), isNull);
      },
    );

    test(
      'validateEatingSetup invokes validateMealScheduleDensity when eating section is set',
      () {
        final base = BaseTimelineDraft(
          eatingSetupPath: 'has_routine',
          eatingSetupStep: 1,
          pendingFutureImports: [
            PendingFutureImportDraft(
              id: 'e_import',
              section: 'Eating',
              mode: 'Photo AI',
              createdAt: DateTime.now(),
              uploadedAssetId: 'menu_123',
              uploadedAssetR2Key:
                  'users/uid/onboarding/eating_menu/menu_123.jpg',
              uploadedAssetStatus: 'uploaded',
            ),
          ],
          blocks: [
            TimelineBlockDraft(
              id: 'm1',
              section: 'eating',
              title: 'Breakfast',
              startMinute: 8 * 60,
              endMinute: 8 * 60 + 30,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              mealCategory: 'breakfast',
              dishes: ['Eggs'],
              source: 'ai_import',
              provenanceSourceIds: const [
                'menu_123',
                'users/uid/onboarding/eating_menu/menu_123.jpg',
              ],
            ),
            TimelineBlockDraft(
              id: 'm2',
              section: 'eating',
              title: 'Snack',
              startMinute: 9 * 60, // Spacing 60 min < 120 min
              endMinute: 9 * 60 + 20,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              mealCategory: 'snack',
              dishes: ['Nuts'],
              source: 'ai_import',
              provenanceSourceIds: const [
                'menu_123',
                'users/uid/onboarding/eating_menu/menu_123.jpg',
              ],
            ),
          ],
        );

        final error = base.validateEatingSetup();
        expect(error, isNotNull);
        expect(error, contains('120 minutes'));
      },
    );

    test(
      'RoutineValidationService validates meal density and spacing for eating items',
      () {
        final existingMeal = RoutineItem(
          id: 'meal_1',
          title: 'Breakfast',
          startMinute: 8 * 60, // 08:00
          endMinute: 8 * 60 + 30,
          repeatDays: [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
          mealCategory: 'breakfast',
          dishes: const ['Pancakes'],
        );

        final newMealTooClose = RoutineItem(
          id: 'meal_2',
          title: 'Morning Snack',
          startMinute: 9 * 60, // 09:00 -> 60 min spacing < 120 min
          endMinute: 9 * 60 + 20,
          repeatDays: [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
          mealCategory: 'snack',
          dishes: const ['Fruit'],
        );

        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: newMealTooClose,
            existingTemplates: [existingMeal],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27), // Monday (day 1)
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(result.isValid, isTrue);
      },
    );
  });

  group('Issue 30: Multi-Dish Meal Timing Collision Resolution', () {
    test(
      'mapOnboarding5MealCandidates merges overlapping candidate blocks into a single TimelineBlockDraft with consolidated dishes',
      () {
        final candidates = [
          RoutineImportCandidateBlock(
            id: 'c1',
            title: 'Breakfast Part 1',
            category: 'eating',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 8 * 60, // 08:00
            endMinute: 8 * 60 + 30, // 08:30
            hasFixedTime: true,
            repeatDays: [1, 2, 3, 4, 5],
            mealCategory: 'breakfast',
            steps: ['Oatmeal', 'Berries'],
          ),
          RoutineImportCandidateBlock(
            id: 'c2',
            title: 'Breakfast Part 2',
            category: 'eating',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 8 * 60 + 15, // 08:15 -> Overlaps with c1
            endMinute: 8 * 60 + 45, // 08:45
            hasFixedTime: true,
            repeatDays: [1, 2, 3, 4, 5],
            mealCategory: 'breakfast',
            steps: ['Boiled Eggs', 'Oatmeal'], // 'Oatmeal' is duplicate
          ),
        ];

        final mapped = mapOnboarding5MealCandidates(
          candidates,
          now: DateTime(2026, 7, 25),
        );

        expect(mapped.blocks.length, equals(1));
        final mergedBlock = mapped.blocks.first;
        expect(mergedBlock.startMinute, equals(8 * 60)); // 480
        expect(mergedBlock.endMinute, equals(8 * 60 + 45)); // 525
        expect(
          mergedBlock.dishes,
          equals(['Oatmeal', 'Berries', 'Boiled Eggs']),
        );
      },
    );

    test(
      'OnboardingCompletionService.buildBundle pre-merges overlapping eating blocks to guarantee zero collisions and zero dish loss',
      () {
        final draft = OnboardingDraft(
          uid: 'user_issue_30',
          onboardingCompleted: true,
          baseTimeline: BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'fixed_sleep',
                section: 'fixed',
                title: 'Sleep',
                startMinute: 23 * 60,
                endMinute: 7 * 60,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'eating_dish_1',
                section: 'eating',
                title: 'Lunch Dish A',
                startMinute: 13 * 60, // 13:00
                endMinute: 13 * 60 + 30, // 13:30
                repeatDays: [1, 2, 3, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
                mealCategory: 'lunch',
                dishes: ['Rice', 'Dal'],
              ),
              TimelineBlockDraft(
                id: 'eating_dish_2',
                section: 'eating',
                title: 'Lunch Dish B',
                startMinute:
                    13 * 60 + 20, // 13:20 -> Overlaps with Lunch Dish A
                endMinute: 13 * 60 + 50, // 13:50
                repeatDays: [1, 2, 3, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
                mealCategory: 'lunch',
                dishes: ['Paneer Tikka', 'Salad'],
              ),
            ],
          ),
        );

        final bundle = OnboardingCompletionService.buildBundle(draft);

        final eatingRoutineItems = bundle.routineItemsForApp
            .where((item) => item.category == RoutineCategory.eating)
            .toList();

        expect(eatingRoutineItems.length, equals(1));
        final mergedItem = eatingRoutineItems.first;
        expect(mergedItem.startMinute, equals(13 * 60));
        expect(mergedItem.endMinute, equals(13 * 60 + 50));
        expect(
          mergedItem.dishes,
          equals(['Rice', 'Dal', 'Paneer Tikka', 'Salad']),
        );
      },
    );
  });
}
