import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/timeline/adapters/fixed_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/adapters/meal_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/adapters/skin_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  TimelineBlockDraft block({
    required String id,
    required String section,
    required String title,
    List<int> repeatDays = const [1],
    List<String> dishes = const [],
    double? calories,
    double? protein,
    String? mealSlot,
    String? mealCategory,
    List<String> steps = const [],
    List<String> products = const [],
    List<String> missing = const [],
    String? slotLabel,
    String? location,
    String? notes,
    bool crossesMidnight = false,
  }) {
    return TimelineBlockDraft(
      id: id,
      section: section,
      title: title,
      startMinute: crossesMidnight ? 23 * 60 : 8 * 60,
      endMinute: crossesMidnight ? 7 * 60 : 9 * 60,
      repeatDays: repeatDays,
      blockType: TimelineBlockDraft.hardBlockKey,
      dishes: dishes,
      calories: calories,
      protein: protein,
      mealSlot: mealSlot,
      mealCategory: mealCategory,
      skincareSteps: steps,
      skincareProducts: products,
      skincareMissingItems: missing,
      skincareSlotLabel: slotLabel,
      location: location,
      notes: notes,
      crossesMidnight: crossesMidnight,
      endsNextDay: crossesMidnight,
    );
  }

  PositionedTimelineEntry positioned(TimelineBlockDraft block) {
    final positionedEnd = block.endMinute <= block.startMinute
        ? 24 * 60
        : block.endMinute;
    return PositionedTimelineEntry(
      entry: TimelineEntry(
        id: block.id,
        sourceId: block.id,
        startMinute: block.startMinute,
        endMinute: positionedEnd,
        repeatDays: block.repeatDays,
        title: block.title,
        category: TimelineCategory.fixed,
      ),
      top: 0,
      height: 380,
      left: 0,
      width: 320,
      column: 0,
      columnCount: 1,
    );
  }

  Future<void> pumpCard(
    WidgetTester tester,
    TimelineBlockDraft block,
    BaseTimelineCardDomain domain,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 380,
            child: BaseTimelineDomainCard(
              positioned: positioned(block),
              block: block,
              domain: domain,
              accent: Colors.teal,
              isEditable: false,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'Eating front card displays macros, slot, category, and every dish',
    (tester) async {
      final meal = block(
        id: 'meal',
        section: 'eating',
        title: 'Breakfast',
        mealSlot: 'Morning',
        mealCategory: 'High protein',
        calories: 520,
        protein: 28,
        dishes: const ['Oats', 'Banana', 'Eggs', 'Milk', 'Peanut butter'],
      );

      await pumpCard(tester, meal, BaseTimelineCardDomain.eating);

      expect(find.text('Morning · High protein'), findsOneWidget);
      expect(find.text('520 kcal · 28 g protein'), findsOneWidget);
      for (final dish in meal.dishes) {
        expect(find.text(dish), findsOneWidget);
      }
      expect(find.textContaining('more'), findsNothing);
    },
  );

  testWidgets(
    'Skin Care front card displays all steps, products, and missing items',
    (tester) async {
      final skin = block(
        id: 'skin',
        section: 'skin_care',
        title: 'Night routine',
        slotLabel: 'Night',
        steps: const ['Cleanse', 'Apply serum', 'Moisturize'],
        products: const ['CeraVe Cleanser', 'Niacinamide Serum', 'Moisturizer'],
        missing: const ['Sunscreen'],
      );

      await pumpCard(tester, skin, BaseTimelineCardDomain.skinCare);

      expect(find.text('1. Cleanse'), findsOneWidget);
      expect(find.text('2. Apply serum'), findsOneWidget);
      expect(find.text('3. Moisturize'), findsOneWidget);
      for (final product in skin.skincareProducts) {
        expect(find.text(product), findsOneWidget);
      }
      expect(find.text('Sunscreen'), findsOneWidget);
    },
  );

  testWidgets('Work and Fixed cards expose stored details on the front card', (
    tester,
  ) async {
    final work = block(
      id: 'work',
      section: 'work',
      title: 'Product lead',
      location: 'Remote · Bengaluru',
      notes: 'Weekly planning and customer reviews',
    );
    await pumpCard(tester, work, BaseTimelineCardDomain.work);
    expect(find.text('Remote · Bengaluru'), findsOneWidget);
    expect(find.text('Weekly planning and customer reviews'), findsOneWidget);

    final sleep = block(
      id: 'sleep',
      section: 'fixed',
      title: 'Sleep',
      crossesMidnight: true,
    );
    await pumpCard(tester, sleep, BaseTimelineCardDomain.fixed);
    expect(find.text('Continues overnight'), findsOneWidget);
  });

  test('persisted empty repeat days are never manufactured by adapters', () {
    final fixed = block(
      id: 'fixed-empty',
      section: 'fixed',
      title: 'Sleep',
      repeatDays: const [],
      crossesMidnight: true,
    );
    final meal = block(
      id: 'meal-empty',
      section: 'eating',
      title: 'Lunch',
      repeatDays: const [],
    );
    final skin = block(
      id: 'skin-empty',
      section: 'skin_care',
      title: 'Night',
      repeatDays: const [],
    );

    expect(const FixedTimelineAdapter().toEntries(fixed), isEmpty);
    expect(
      const MealTimelineAdapter().toEntries(meal).single.repeatDays,
      isEmpty,
    );
    expect(
      const SkinTimelineAdapter().toEntries(skin).single.repeatDays,
      isEmpty,
    );
    expect(
      const BaseTimelineWorkAdapter()
          .toEntries(
            block(
              id: 'work-empty',
              section: 'work',
              title: 'Work',
              repeatDays: const [],
            ),
          )
          .single
          .repeatDays,
      isEmpty,
    );
  });

  test('typed Work, Eating, and Skin edits preserve unexposed metadata', () {
    final original = TimelineBlockDraft(
      id: 'lossless',
      section: 'work',
      title: 'Role',
      startMinute: 540,
      endMinute: 600,
      repeatDays: const [1, 3],
      location: 'Office',
      blockType: TimelineBlockDraft.hardBlockKey,
      source: 'vision-v3',
      provenanceSourceIds: const ['asset-1'],
      mealSlot: 'lunch',
      mealCategory: 'balanced',
      dishes: const ['Dal', 'Rice'],
      calories: 600,
      protein: 24,
      skincareProducts: const ['Cleanser'],
      skincareSteps: const ['Cleanse'],
      skincareMissingItems: const ['SPF'],
      skincareSlotLabel: 'Morning',
    );

    final changed = original.copyWith(location: 'Remote');
    expect(changed.location, 'Remote');
    expect(changed.source, 'vision-v3');
    expect(changed.provenanceSourceIds, const ['asset-1']);
    expect(changed.dishes, const ['Dal', 'Rice']);
    expect(changed.calories, 600);
    expect(changed.protein, 24);
    expect(changed.skincareProducts, const ['Cleanser']);
    expect(changed.skincareMissingItems, const ['SPF']);
    expect(changed.skincareSlotLabel, 'Morning');
  });

  test(
    'main Routine CRUD detail path is removed and Add sheet is create-only',
    () {
      expect(
        File(
          'lib/features/routine/sheets/routine_detail_sheet.dart',
        ).existsSync(),
        isFalse,
      );
      final viewport = File(
        'lib/features/routine/widgets/routine_timeline_viewport.dart',
      ).readAsStringSync();
      final addSheet = File(
        'lib/features/routine/sheets/add_routine_sheet.dart',
      ).readAsStringSync();

      expect(viewport, isNot(contains('onCardTap')));
      expect(addSheet, isNot(contains('editItem')));
      expect(addSheet, isNot(contains('Edit Routine Item')));
      expect(addSheet, isNot(contains('.updateItem(')));
      expect(addSheet, contains('.addItem(item)'));
      final workFlow = File(
        'lib/features/routine/managers/base_timeline/screens/schedule_setup_flow.dart',
      ).readAsStringSync();
      expect(workFlow, isNot(contains('ClassRoutineBlock')));
      expect(workFlow, isNot(contains('showClassEditSheet')));
      expect(workFlow, contains('BaseTimelineWorkAdapter.showEditSheet'));
    },
  );
}
