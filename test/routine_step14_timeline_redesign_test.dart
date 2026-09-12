import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_adapter.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_viewport.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

class _MockRoutineNotifier extends RoutineNotifier {
  final List<String> startedItemIds = [];
  final List<String> completedItemIds = [];
  final List<(String, int)> toggledSubtasks = [];
  final List<String> trackerStarts = [];
  final List<String> trackerCompletes = [];
  final List<String> moneySavedIds = [];
  final List<(String, String)> checkInCalls = [];
  final List<String> discardedCreates = [];

  _MockRoutineNotifier(
    Ref ref, {
    List<RoutineItem> initialItems = const [],
    Set<String> pendingIds = const {},
    Map<String, RoutineWriteIntent> failedIntents = const {},
  }) : super(
         FakeRoutineRepository(),
         FakeRoutineHistoryRepository(),
         FakeRoutineTransactionRepository(),
         ref,
       ) {
    state = state.copyWith(
      items: initialItems,
      selectedDay: DateTime(2026, 7, 27),
      loading: false,
      pendingItemIds: pendingIds,
      failedIntentsByItemId: failedIntents,
    );
  }

  @override
  Future<RoutineWriteResult> startRoutineItem(String itemId) async {
    startedItemIds.add(itemId);
    final targetIndex = state.items.indexWhere((e) => e.id == itemId);
    if (targetIndex != -1) {
      final item = state.items[targetIndex];
      if (item.blockType == RoutineBlockType.trackerTask) {
        return await startTrackerTask(item);
      }
    }
    return RoutineWriteResult.saved(
      operationId: 'start-$itemId',
      message: 'Started',
    );
  }

  @override
  Future<RoutineWriteResult> startFlexibleTask(String itemId) async {
    startedItemIds.add(itemId);
    return RoutineWriteResult.saved(
      operationId: 'start-flex-$itemId',
      message: 'Started',
    );
  }

  @override
  Future<RoutineWriteResult> startTrackerTask(RoutineItem item) async {
    trackerStarts.add(item.id);
    state = state.copyWith(
      items: state.items
          .map(
            (i) => i.id == item.id
                ? i.copyWith(status: RoutineStatus.inTracker)
                : i,
          )
          .toList(),
    );
    return RoutineWriteResult.saved(
      operationId: 'start-tracker-${item.id}',
      message: 'Tracker started',
    );
  }

  @override
  Future<RoutineWriteResult> completeTrackerSession(
    String routineTaskId,
  ) async {
    trackerCompletes.add(routineTaskId);
    completedItemIds.add(routineTaskId);
    state = state.copyWith(
      items: state.items
          .map(
            (i) => i.id == routineTaskId
                ? i.copyWith(isCompleted: true, status: RoutineStatus.completed)
                : i,
          )
          .toList(),
    );
    return RoutineWriteResult.saved(
      operationId: 'complete-tracker-$routineTaskId',
      message: 'Tracker completed',
    );
  }

  @override
  Future<RoutineWriteResult> alreadySaved(
    String itemId, {
    double? amount,
  }) async {
    moneySavedIds.add(itemId);
    completedItemIds.add(itemId);
    state = state.copyWith(
      items: state.items
          .map(
            (i) => i.id == itemId
                ? i.copyWith(isCompleted: true, status: RoutineStatus.completed)
                : i,
          )
          .toList(),
    );
    return RoutineWriteResult.saved(
      operationId: 'saved-$itemId',
      message: 'Saved',
    );
  }

  @override
  Future<RoutineWriteResult> checkIn(String itemId, String response) async {
    checkInCalls.add((itemId, response));
    completedItemIds.add(itemId);
    state = state.copyWith(
      items: state.items
          .map(
            (i) => i.id == itemId
                ? i.copyWith(isCompleted: true, status: RoutineStatus.completed)
                : i,
          )
          .toList(),
    );
    return RoutineWriteResult.saved(
      operationId: 'checkin-$itemId',
      message: 'Checked in: $response',
    );
  }

  @override
  Future<RoutineWriteResult> completeRoutineItem(String itemId) async {
    final targetIndex = state.items.indexWhere((e) => e.id == itemId);
    if (targetIndex != -1) {
      final item = state.items[targetIndex];
      if (item.blockType == RoutineBlockType.trackerTask) {
        return await completeTrackerSession(itemId);
      }
      if (item.blockType == RoutineBlockType.moneyTask) {
        return await alreadySaved(itemId);
      }
      if (item.blockType == RoutineBlockType.checkIn &&
          item.category == RoutineCategory.badHabit) {
        return await checkIn(itemId, 'Avoided');
      }
    }
    return await markCompleted(itemId);
  }

  @override
  Future<RoutineWriteResult> markCompleted(String itemId) async {
    completedItemIds.add(itemId);
    final updated = state.items.map((i) {
      if (i.id == itemId) {
        return i.copyWith(isCompleted: true, status: RoutineStatus.completed);
      }
      return i;
    }).toList();
    state = state.copyWith(items: updated);
    return RoutineWriteResult.saved(
      operationId: 'done-$itemId',
      message: 'Completed',
    );
  }

  @override
  Future<RoutineWriteResult> toggleSubtask(
    String itemId,
    int subtaskIndex,
  ) async {
    toggledSubtasks.add((itemId, subtaskIndex));
    final updated = state.items.map((i) {
      if (i.id == itemId && i.subtasks != null) {
        final currentCompleted = List<bool>.from(
          i.subtasksCompleted ?? List.filled(i.subtasks!.length, false),
        );
        if (subtaskIndex >= 0 && subtaskIndex < currentCompleted.length) {
          currentCompleted[subtaskIndex] = !currentCompleted[subtaskIndex];
        }
        return i.copyWith(subtasksCompleted: currentCompleted);
      }
      return i;
    }).toList();
    state = state.copyWith(items: updated);
    return RoutineWriteResult.saved(
      operationId: 'toggle-$itemId-$subtaskIndex',
      message: 'Subtask toggled',
    );
  }

  @override
  void discardFailedCreate(String itemId) {
    discardedCreates.add(itemId);
  }
}

void main() {
  const testWidth = 390.0;
  const testHeight = 844.0;

  Widget buildTestableViewport({
    required List<RoutineItem> items,
    TimelineLayout? layout,
    Set<String> pendingIds = const {},
    Map<String, RoutineWriteIntent> failedIntents = const {},
    void Function(_MockRoutineNotifier)? onNotifierCreated,
    bool isToday = false,
    bool showCurrentTimeLine = false,
  }) {
    return ProviderScope(
      overrides: [
        routineNotifierProvider.overrideWith((ref) {
          final notifier = _MockRoutineNotifier(
            ref,
            initialItems: items,
            pendingIds: pendingIds,
            failedIntents: failedIntents,
          );
          onNotifierCreated?.call(notifier);
          return notifier;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: testWidth,
            height: testHeight,
            child: RoutineTimelineViewport(
              items: items,
              layout:
                  layout ??
                  const TimelineLayout(
                    visibleStartMinute: 480, // 8:00 AM
                    visibleEndMinute: 1200, // 8:00 PM
                  ),
              isToday: isToday,
              showCurrentTimeLine: showCurrentTimeLine,
            ),
          ),
        ),
      ),
    );
  }

  group('Routine Step 14 Timeline Redesign: Overlap UX & Back Tabs', () {
    testWidgets(
      '3 overlapping items render 1 front card and 2 back tabs in gutter',
      (tester) async {
        final itemWork = RoutineItem(
          id: 'work_1',
          title: 'Office Deep Work',
          startMinute: 9 * 60, // 9:00 AM
          endMinute: 12 * 60, // 12:00 PM
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.job,
        );
        final itemMeal = RoutineItem(
          id: 'meal_1',
          title: 'Healthy Lunch',
          startMinute: 10 * 60, // 10:00 AM
          endMinute: 10 * 60 + 45, // 10:45 AM
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
          mealCategory: 'Lunch',
          dishes: const ['Salad', 'Grilled Chicken', 'Brown Rice'],
        );
        final itemSkin = RoutineItem(
          id: 'skin_1',
          title: 'Midday Skincare',
          startMinute: 10 * 60 + 15, // 10:15 AM
          endMinute: 10 * 60 + 30, // 10:30 AM
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.skinCare,
          steps: const ['Sunscreen reapply'],
        );

        await tester.pumpWidget(
          buildTestableViewport(items: [itemWork, itemMeal, itemSkin]),
        );
        await tester.pumpAndSettle();

        // Zero old conflict / hidden chooser UX
        expect(find.textContaining('+1 more'), findsNothing);
        expect(find.textContaining('+2 more'), findsNothing);
        expect(find.text('Overlapping tasks'), findsNothing);
        expect(find.text('Conflict'), findsNothing);

        // Back tab exists in the gutter for back items
        expect(
          find.byKey(const ValueKey('routine-back-label-work_1')),
          findsOneWidget,
        );

        // Back tab uses short label, front card displays full title
        expect(find.text('Office'), findsWidgets);
        expect(find.text('Midday Skincare'), findsWidgets);
      },
    );

    testWidgets('Tapping back tab promotes item to front without mutating DB', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final itemWork = RoutineItem(
        id: 'work_1',
        title: 'Office Work',
        startMinute: 9 * 60,
        endMinute: 12 * 60,
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.job,
      );
      final itemMeal = RoutineItem(
        id: 'meal_1',
        title: 'Power Lunch',
        startMinute: 10 * 60,
        endMinute: 10 * 60 + 30,
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
        dishes: const ['Salad'],
      );

      _MockRoutineNotifier? capturedNotifier;

      await tester.pumpWidget(
        buildTestableViewport(
          items: [itemWork, itemMeal],
          onNotifierCreated: (n) => capturedNotifier = n,
        ),
      );
      await tester.pumpAndSettle();

      // Initially, short task (meal) is in front, work is back tab
      final workBackTabFinder = find.byKey(
        const ValueKey('routine-back-label-work_1'),
      );
      expect(workBackTabFinder, findsOneWidget);

      // Tap work back tab to promote it
      await tester.tap(workBackTabFinder);
      await tester.pumpAndSettle();

      // Now Work is promoted to front! Meal becomes back tab!
      expect(
        find.byKey(const ValueKey('routine-back-label-meal_1')),
        findsOneWidget,
      );

      // Verify no DB mutations occurred during promotion
      expect(capturedNotifier!.completedItemIds, isEmpty);
      expect(capturedNotifier!.startedItemIds, isEmpty);
    });

    testWidgets('4 overlapping items are all accessible via back tabs', (
      tester,
    ) async {
      final item1 = RoutineItem(
        id: 'item_1',
        title: 'Morning Class',
        startMinute: 9 * 60,
        endMinute: 11 * 60,
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.classBlock,
      );
      final item2 = RoutineItem(
        id: 'item_2',
        title: 'Study Habit',
        startMinute: 9 * 60 + 15,
        endMinute: 10 * 60,
        blockType: RoutineBlockType.flexibleTask,
      );
      final item3 = RoutineItem(
        id: 'item_3',
        title: 'Snack Break',
        startMinute: 9 * 60 + 30,
        endMinute: 9 * 60 + 45,
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
        dishes: const ['Apple'],
      );
      final item4 = RoutineItem(
        id: 'item_4',
        title: 'Eye Drops',
        startMinute: 9 * 60 + 35,
        endMinute: 9 * 60 + 40,
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.skinCare,
        steps: const ['Eye drops'],
      );

      await tester.pumpWidget(
        buildTestableViewport(items: [item1, item2, item3, item4]),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('routine-back-label-item_1')),
        findsOneWidget,
      );
      expect(find.textContaining('+3 more'), findsNothing);
      expect(find.textContaining('+2 more'), findsNothing);
    });

    testWidgets(
      '6 concurrently overlapping items stack in gutter without collision',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final items = [
          RoutineItem(
            id: 'c_1',
            title: 'Deep Work Block',
            startMinute: 9 * 60,
            endMinute: 13 * 60,
            blockType: RoutineBlockType.hardBlock,
            category: RoutineCategory.job,
          ),
          RoutineItem(
            id: 'c_2',
            title: 'Midday Seminar',
            startMinute: 9 * 60 + 30,
            endMinute: 11 * 60,
            blockType: RoutineBlockType.hardBlock,
            category: RoutineCategory.classBlock,
          ),
          RoutineItem(
            id: 'c_3',
            title: 'Power Protein Snack',
            startMinute: 10 * 60,
            endMinute: 10 * 60 + 20,
            blockType: RoutineBlockType.softBlock,
            category: RoutineCategory.eating,
            dishes: const ['Almonds'],
          ),
          RoutineItem(
            id: 'c_4',
            title: 'Hydration Check',
            startMinute: 10 * 60 + 10,
            endMinute: 10 * 60 + 25,
            blockType: RoutineBlockType.checkIn,
          ),
          RoutineItem(
            id: 'c_5',
            title: 'Face Mist',
            startMinute: 10 * 60 + 15,
            endMinute: 10 * 60 + 30,
            blockType: RoutineBlockType.softBlock,
            category: RoutineCategory.skinCare,
            steps: const ['Mist spray'],
          ),
          RoutineItem(
            id: 'c_6',
            title: 'Mini Meditation',
            startMinute: 10 * 60 + 18,
            endMinute: 10 * 60 + 28,
            blockType: RoutineBlockType.flexibleTask,
          ),
        ];

        await tester.pumpWidget(buildTestableViewport(items: items));
        await tester.pumpAndSettle();

        // Ensure zero overflow errors and back tabs are rendered
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('routine-back-label-c_1')),
          findsOneWidget,
        );
      },
    );
  });

  group('Routine Step 14 Redesign: Full-Detail Cards & Primary Actions', () {
    testWidgets(
      'SoftBlockCard (Eating) displays ALL dishes as chips, nutrition, and mealSlot',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mealItem = RoutineItem(
          id: 'meal_full',
          title: 'Midday Fuel',
          startMinute: 11 * 60,
          endMinute: 12 * 60,
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
          mealSlot: 'Midday Fuel',
          caloriesEstimate: 650,
          proteinEstimate: 42,
          dishes: const [
            'Quinoa Salad',
            'Salmon Fillet',
            'Steamed Broccoli',
            'Avocado Dressing',
            'Fresh Berry Cup',
          ],
        );

        _MockRoutineNotifier? capturedNotifier;

        await tester.pumpWidget(
          buildTestableViewport(
            items: [mealItem],
            layout: const TimelineLayout(
              visibleStartMinute: 11 * 60,
              visibleEndMinute: 14 * 60,
            ),
            onNotifierCreated: (n) => capturedNotifier = n,
          ),
        );
        await tester.pumpAndSettle();

        // All 5 dishes rendered without truncation
        expect(find.text('Quinoa Salad'), findsOneWidget);
        expect(find.text('Salmon Fillet'), findsOneWidget);
        expect(find.text('Steamed Broccoli'), findsOneWidget);
        expect(find.text('Avocado Dressing'), findsOneWidget);
        expect(find.text('Fresh Berry Cup'), findsOneWidget);

        // Nutrition and mealSlot displayed
        expect(find.text('650 kcal • 42g protein'), findsOneWidget);
        expect(find.text('Midday Fuel'), findsOneWidget);

        // Old footers removed
        expect(find.text('View dishes'), findsNothing);
        expect(find.text('View steps'), findsNothing);
        expect(find.text('Edit base'), findsNothing);

        // Three primary actions present
        expect(
          find.byKey(const ValueKey('routine-action-start-meal_full')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-action-done-meal_full')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-action-move-meal_full')),
          findsOneWidget,
        );

        // Tap Done button
        await tester.tap(
          find.byKey(const ValueKey('routine-action-done-meal_full')),
        );
        await tester.pumpAndSettle();
        expect(capturedNotifier!.completedItemIds, contains('meal_full'));
      },
    );

    testWidgets('SoftBlockCard (Skin Care) displays ALL steps and products', (
      tester,
    ) async {
      final skinItem = RoutineItem(
        id: 'skin_full',
        title: 'Evening Glow Care',
        startMinute: 19 * 60,
        endMinute: 19 * 60 + 30,
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.skinCare,
        steps: const [
          'Gentle Cleanser',
          'Hydrating Toner',
          'Vitamin C Serum',
          'Night Moisturizer',
        ],
        skincareProducts: const ['CeraVe Hydrating', 'Klairs Supple Prep'],
      );

      await tester.pumpWidget(
        buildTestableViewport(
          items: [skinItem],
          layout: const TimelineLayout(
            visibleStartMinute: 18 * 60,
            visibleEndMinute: 21 * 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // STEPS header and all steps present
      expect(find.text('STEPS'), findsOneWidget);
      expect(find.text('1. Gentle Cleanser'), findsOneWidget);
      expect(find.text('2. Hydrating Toner'), findsOneWidget);
      expect(find.text('3. Vitamin C Serum'), findsOneWidget);
      expect(find.text('4. Night Moisturizer'), findsOneWidget);

      // PRODUCTS header and products present
      expect(find.text('PRODUCTS'), findsOneWidget);
      expect(find.text('• CeraVe Hydrating'), findsOneWidget);
      expect(find.text('• Klairs Supple Prep'), findsOneWidget);

      // Old View steps footer removed
      expect(find.text('View steps'), findsNothing);
    });

    testWidgets(
      'FlexibleTaskCard displays ALL subtasks with interactive checkboxes',
      (tester) async {
        final flexItem = RoutineItem(
          id: 'flex_subtasks',
          title: 'Project Setup',
          startMinute: 14 * 60,
          endMinute: 15 * 60,
          blockType: RoutineBlockType.flexibleTask,
          subtasks: const [
            'Run lint analysis',
            'Format dart files',
            'Execute unit tests',
            'Review pull request',
          ],
          subtasksCompleted: const [false, true, false, false],
        );

        _MockRoutineNotifier? capturedNotifier;

        await tester.pumpWidget(
          buildTestableViewport(
            items: [flexItem],
            layout: const TimelineLayout(
              visibleStartMinute: 13 * 60,
              visibleEndMinute: 16 * 60,
            ),
            onNotifierCreated: (n) => capturedNotifier = n,
          ),
        );
        await tester.pumpAndSettle();

        // All subtasks rendered
        expect(find.text('SUBTASKS (4)'), findsOneWidget);
        expect(find.text('Run lint analysis'), findsOneWidget);
        expect(find.text('Format dart files'), findsOneWidget);
        expect(find.text('Execute unit tests'), findsOneWidget);
        expect(find.text('Review pull request'), findsOneWidget);

        // Tap on first subtask toggles it
        await tester.tap(find.text('Run lint analysis'));
        await tester.pumpAndSettle();

        expect(
          capturedNotifier!.toggledSubtasks,
          contains(('flex_subtasks', 0)),
        );
      },
    );

    testWidgets(
      'HardBlockCard displays Professor, Course, Class Type, and Section Label',
      (tester) async {
        final classItem = RoutineItem(
          id: 'class_hard',
          title: 'Computer Science Lecture',
          startMinute: 10 * 60,
          endMinute: 11 * 60 + 30,
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
          professor: 'Dr. Turing',
          courseCode: 'CS 301',
          classType: 'Lecture Hall B',
          sectionLabel: 'Sec 04',
          location: 'Engineering Building',
        );

        await tester.pumpWidget(
          buildTestableViewport(
            items: [classItem],
            layout: const TimelineLayout(
              visibleStartMinute: 9 * 60,
              visibleEndMinute: 13 * 60,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Dr. Turing • CS 301 • Lecture Hall B • Sec 04'),
          findsOneWidget,
        );
        expect(find.text('Engineering Building'), findsOneWidget);
        expect(find.text('View'), findsNothing);
        expect(find.text('Edit base'), findsNothing);
      },
    );

    testWidgets(
      'TrackerTaskCard Start launches tracker session and Done completes tracker session',
      (tester) async {
        final trackerItem = RoutineItem(
          id: 'tracker_1',
          title: 'Cardio Run',
          startMinute: 8 * 60,
          endMinute: 9 * 60,
          blockType: RoutineBlockType.trackerTask,
          trackerType: TrackerType.hydration,
        );

        _MockRoutineNotifier? capturedNotifier;

        await tester.pumpWidget(
          buildTestableViewport(
            items: [trackerItem],
            onNotifierCreated: (n) => capturedNotifier = n,
          ),
        );
        await tester.pumpAndSettle();

        // Tracker type is shown
        expect(find.textContaining('hydration'), findsOneWidget);

        // Tap Start
        await tester.tap(
          find.byKey(const ValueKey('routine-action-start-tracker_1')),
        );
        await tester.pumpAndSettle();

        expect(capturedNotifier!.trackerStarts, contains('tracker_1'));

        // Tap Done
        await tester.tap(
          find.byKey(const ValueKey('routine-action-done-tracker_1')),
        );
        await tester.pumpAndSettle();

        expect(capturedNotifier!.trackerCompletes, contains('tracker_1'));
      },
    );

    testWidgets('MoneyTaskCard Done calls alreadySaved to preserve savings', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final moneyItem = RoutineItem(
        id: 'money_1',
        title: 'Daily Micro-saving',
        startMinute: 11 * 60,
        endMinute: 11 * 60 + 30,
        blockType: RoutineBlockType.moneyTask,
      );

      _MockRoutineNotifier? capturedNotifier;

      await tester.pumpWidget(
        buildTestableViewport(
          items: [moneyItem],
          layout: const TimelineLayout(
            visibleStartMinute: 11 * 60,
            visibleEndMinute: 12 * 60,
          ),
          onNotifierCreated: (n) => capturedNotifier = n,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Done
      await tester.tap(
        find.byKey(const ValueKey('routine-action-done-money_1')),
      );
      await tester.pumpAndSettle();

      expect(capturedNotifier!.moneySavedIds, contains('money_1'));
    });

    testWidgets('Bad habit CheckInCard Done calls checkIn with Avoided', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final checkInItem = RoutineItem(
        id: 'habit_checkin',
        title: 'No Smoking Check-in',
        startMinute: 14 * 60,
        endMinute: 14 * 60 + 15,
        blockType: RoutineBlockType.checkIn,
        category: RoutineCategory.badHabit,
      );

      _MockRoutineNotifier? capturedNotifier;

      await tester.pumpWidget(
        buildTestableViewport(
          items: [checkInItem],
          layout: const TimelineLayout(
            visibleStartMinute: 14 * 60,
            visibleEndMinute: 15 * 60,
          ),
          onNotifierCreated: (n) => capturedNotifier = n,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Done
      await tester.tap(
        find.byKey(const ValueKey('routine-action-done-habit_checkin')),
      );
      await tester.pumpAndSettle();

      expect(
        capturedNotifier!.checkInCalls,
        contains(('habit_checkin', 'Avoided')),
      );
    });

    testWidgets('Tapping front card body does NOT open detail sheet', (
      tester,
    ) async {
      final item = RoutineItem(
        id: 'front_card',
        title: 'Independent Study',
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        blockType: RoutineBlockType.flexibleTask,
      );

      await tester.pumpWidget(buildTestableViewport(items: [item]));
      await tester.pumpAndSettle();

      // Tap card body
      await tester.tap(find.text('Independent Study'));
      await tester.pumpAndSettle();

      // No modal sheet or dialog opens
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('Routine Step 14 Redesign: Card Colors & Scale Invariants', () {
    test('Routine card colors strictly match RoutineCardFactory tokens', () {
      expect(
        RoutineCardFactory.colorForType(RoutineBlockType.hardBlock),
        OptivusColors.blockHard,
      );
      expect(
        RoutineCardFactory.colorForType(RoutineBlockType.softBlock),
        OptivusColors.blockSoft,
      );
      expect(
        RoutineCardFactory.colorForType(RoutineBlockType.flexibleTask),
        OptivusColors.blockFlex,
      );
      expect(
        RoutineCardFactory.colorForType(RoutineBlockType.trackerTask),
        OptivusColors.blockTracker,
      );
      expect(
        RoutineCardFactory.colorForType(RoutineBlockType.checkIn),
        OptivusColors.blockCheckIn,
      );
      expect(
        RoutineCardFactory.colorForType(RoutineBlockType.moneyTask),
        OptivusColors.blockMoney,
      );
    });

    test('Short tasks stretch timeline without compressing card contents', () {
      final shortEating = RoutineItem(
        id: 'short_eat',
        title: 'Quick Snack',
        startMinute: 600,
        endMinute: 610, // 10 minutes
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
        dishes: const ['Almonds', 'Banana', 'Protein Shake'],
      );

      final constraints = [
        RoutineConstraintEntry(
          startMinute: shortEating.startMinute,
          endMinute: shortEating.endMinute,
          minHeight: 120.0,
        ),
      ];

      final segments = solveRoutineStretchConstraints(
        constraints,
        pixelsPerMinute: 112.0 / 60.0,
      );

      expect(segments, isNotEmpty);
      expect(segments.first.extraStretch, greaterThan(0));
    });

    test('Back-to-back short cards stretch timeline sequentially', () {
      final constraints = [
        const RoutineConstraintEntry(
          startMinute: 600,
          endMinute: 605, // 5 min
          minHeight: 100.0,
        ),
        const RoutineConstraintEntry(
          startMinute: 605,
          endMinute: 610, // 5 min
          minHeight: 100.0,
        ),
      ];

      final segments = solveRoutineStretchConstraints(
        constraints,
        pixelsPerMinute: 112.0 / 60.0,
      );

      expect(segments.length, greaterThanOrEqualTo(2));
      final totalStretch = segments.fold<double>(
        0,
        (sum, s) => sum + s.extraStretch,
      );
      expect(totalStretch, greaterThan(150));
    });

    testWidgets(
      'Large accessibility text scale (2.5x) renders without overflow errors',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final item = RoutineItem(
          id: 'accessibility_item',
          title: 'Complex Long Title Activity with Extensive Description',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
          professor: 'Professor With Very Long Name',
          courseCode: 'LONG-CODE-999',
          location: 'Building Room 102B North Wing',
          notes: 'Detailed notes about homework assignments and preparation',
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
            child: buildTestableViewport(items: [item]),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Complex Long Title'), findsOneWidget);
      },
    );

    testWidgets('Pending write state displays dimmed opacity (0.6)', (
      tester,
    ) async {
      final item = RoutineItem(
        id: 'pending_item',
        title: 'Pending Save Task',
        startMinute: 10 * 60,
        endMinute: 11 * 60,
        blockType: RoutineBlockType.flexibleTask,
      );

      await tester.pumpWidget(
        buildTestableViewport(items: [item], pendingIds: {'pending_item'}),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final opacityFinder = find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity == 0.6,
      );
      expect(opacityFinder, findsOneWidget);
    });

    testWidgets('Failed write displays retry and discard controls', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = RoutineItem(
        id: 'failed_item',
        title: 'Failed Task',
        startMinute: 10 * 60,
        endMinute: 11 * 60,
        blockType: RoutineBlockType.flexibleTask,
      );

      _MockRoutineNotifier? capturedNotifier;

      await tester.pumpWidget(
        buildTestableViewport(
          items: [item],
          layout: const TimelineLayout(
            visibleStartMinute: 10 * 60,
            visibleEndMinute: 11 * 60,
          ),
          failedIntents: {
            'failed_item': RoutineWriteIntent(
              action: RoutineWriteAction.create,
              ownerUid: 'test_user',
              itemId: 'failed_item',
              operationId: 'op_1',
              createdAt: DateTime.now(),
            ),
          },
          onNotifierCreated: (n) => capturedNotifier = n,
        ),
      );
      await tester.pumpAndSettle();

      // Retry (refresh icon) and Discard (close icon) exist
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap Discard
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(capturedNotifier!.discardedCreates, contains('failed_item'));
    });
  });
}
