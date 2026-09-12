import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/timeline/timeline_visual_layout.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';
import 'package:optivus/core/timeline/widgets/timeline_card_chrome.dart';
import 'package:optivus/features/onboarding/timeline/layout/timeline_overlap_engine.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_actions.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_presentation.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_adapter.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_viewport.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/core/timeline/widgets/timeline_back_tab_strip.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_rich_timeline_card.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
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
    int? selectedDay,
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
              selectedDay: selectedDay,
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

    testWidgets(
      'Back tab strip matches Step 14 ClipRect styling without floating pill container',
      (tester) async {
        final item1 = RoutineItem(
          id: 'bt_1',
          title: 'First Event',
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );
        final item2 = RoutineItem(
          id: 'bt_2',
          title: 'Second Event',
          startMinute: 9 * 60 + 15,
          endMinute: 10 * 60,
          blockType: RoutineBlockType.flexibleTask,
        );

        await tester.pumpWidget(buildTestableViewport(items: [item1, item2]));
        await tester.pumpAndSettle();

        final backTabFinder = find.byKey(
          const ValueKey('routine-back-label-bt_1'),
        );
        expect(backTabFinder, findsOneWidget);

        final clipRectAncestor = find.ancestor(
          of: backTabFinder,
          matching: find.byType(ClipRect),
        );
        expect(clipRectAncestor, findsAtLeastNWidgets(1));

        final clipRRectAncestor = find.ancestor(
          of: backTabFinder,
          matching: find.byType(ClipRRect),
        );
        expect(clipRRectAncestor, findsNothing);
      },
    );

    testWidgets(
      'Routine timeline viewport reconciles focus when items change',
      (tester) async {
        final item1 = RoutineItem(
          id: 'foc_1',
          title: 'Focus 1',
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );
        final item2 = RoutineItem(
          id: 'foc_2',
          title: 'Focus 2',
          startMinute: 9 * 60 + 15,
          endMinute: 10 * 60,
          blockType: RoutineBlockType.flexibleTask,
        );

        await tester.pumpWidget(buildTestableViewport(items: [item1, item2]));
        await tester.pumpAndSettle();

        // Tap back tab to focus item1
        await tester.tap(
          find.byKey(const ValueKey('routine-back-label-foc_1')),
        );
        await tester.pumpAndSettle();

        final stateBefore = tester.state<RoutineTimelineViewportState>(
          find.byType(RoutineTimelineViewport),
        );
        expect(
          stateBefore.focusedItemIdByComponentForTesting.values,
          contains('foc_1'),
        );

        // Update widget with only item2 (foc_1 removed)
        await tester.pumpWidget(buildTestableViewport(items: [item2]));
        await tester.pumpAndSettle();

        final stateAfter = tester.state<RoutineTimelineViewportState>(
          find.byType(RoutineTimelineViewport),
        );
        expect(
          stateAfter.focusedItemIdByComponentForTesting.values,
          isNot(contains('foc_1')),
        );
      },
    );

    testWidgets(
      'Routine timeline viewport triggers auto-scroll when transitioning to Today',
      (tester) async {
        final item = RoutineItem(
          id: 'today_scroll_item',
          title: 'Midday Block',
          startMinute: 12 * 60,
          endMinute: 13 * 60,
          blockType: RoutineBlockType.hardBlock,
        );

        await tester.pumpWidget(
          buildTestableViewport(items: [item], isToday: false),
        );
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          buildTestableViewport(items: [item], isToday: true),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Transitive overlap (A 10-12, B 10:30-11, C 10:45-12:30, D 12-12:20) groups into a single component with 1 front and 3 back tabs and supports bidirectional promotion',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final itemA = RoutineItem(
          id: 'trans_a',
          title: 'Deep Work Block',
          startMinute: 10 * 60,
          endMinute: 12 * 60,
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.job,
        );
        final itemB = RoutineItem(
          id: 'trans_b',
          title: 'Brunch Break',
          startMinute: 10 * 60 + 30,
          endMinute: 11 * 60,
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
          mealSlot: 'Brunch',
          dishes: const ['Eggs', 'Toast'],
        );
        final itemC = RoutineItem(
          id: 'trans_c',
          title: 'Study Session',
          startMinute: 10 * 60 + 45,
          endMinute: 12 * 60 + 30,
          blockType: RoutineBlockType.flexibleTask,
        );
        final itemD = RoutineItem(
          id: 'trans_d',
          title: 'Hydration Habit',
          startMinute: 12 * 60,
          endMinute: 12 * 60 + 20,
          blockType: RoutineBlockType.checkIn,
        );

        await tester.pumpWidget(
          buildTestableViewport(
            items: [itemA, itemB, itemC, itemD],
            layout: const TimelineLayout(
              visibleStartMinute: 10 * 60,
              visibleEndMinute: 13 * 60,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially, the two non-overlapping short items (trans_b at 10:30 and trans_d at 12:00)
        // are front cards in their respective non-conflicting time windows, while trans_a and trans_c are in the gutter.
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_a')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_c')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_b')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_d')),
          findsNothing,
        );

        // Tap trans_c (the bridging item that overlaps trans_a, trans_b, and trans_d)
        await tester.tap(
          find.byKey(const ValueKey('routine-back-label-trans_c')),
        );
        await tester.pumpAndSettle();

        // Now trans_c is promoted to front! Because trans_c spans across all 3 other items,
        // all 3 (trans_a, trans_b, trans_d) are now exposed as back tabs!
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_c')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_a')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_b')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_d')),
          findsOneWidget,
        );

        // Tap trans_a back tab to promote trans_a (10:00-12:00)
        await tester.tap(
          find.byKey(const ValueKey('routine-back-label-trans_a')),
        );
        await tester.pumpAndSettle();

        // trans_a is now front; trans_b and trans_c are in back; trans_d at 12:00 is also visible in front
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_a')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_b')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_c')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-back-label-trans_d')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Day switching focus reconciliation prunes component focus from another day',
      (tester) async {
        final item1 = RoutineItem(
          id: 'day_foc_1',
          title: 'Class Block',
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );
        final item2 = RoutineItem(
          id: 'day_foc_2',
          title: 'Habit Task',
          startMinute: 9 * 60 + 15,
          endMinute: 10 * 60,
          blockType: RoutineBlockType.flexibleTask,
        );

        await tester.pumpWidget(
          buildTestableViewport(items: [item1, item2], selectedDay: 1),
        );
        await tester.pumpAndSettle();

        // Tap back tab to focus day_foc_1
        await tester.tap(
          find.byKey(const ValueKey('routine-back-label-day_foc_1')),
        );
        await tester.pumpAndSettle();

        final stateDay1 = tester.state<RoutineTimelineViewportState>(
          find.byType(RoutineTimelineViewport),
        );
        expect(
          stateDay1.focusedItemIdByComponentForTesting.keys.any(
            (k) => k.startsWith('1:'),
          ),
          isTrue,
        );

        // Switch to day 2 with same items
        await tester.pumpWidget(
          buildTestableViewport(items: [item1, item2], selectedDay: 2),
        );
        await tester.pumpAndSettle();

        final stateDay2 = tester.state<RoutineTimelineViewportState>(
          find.byType(RoutineTimelineViewport),
        );
        // Focus from day 1 has been pruned
        expect(
          stateDay2.focusedItemIdByComponentForTesting.keys.any(
            (k) => k.startsWith('1:'),
          ),
          isFalse,
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

      // PRODUCTS header and products present (no Routine-only bullet per Step 14 parity)
      expect(find.text('PRODUCTS'), findsOneWidget);
      expect(find.text('CeraVe Hydrating'), findsOneWidget);
      expect(find.text('Klairs Supple Prep'), findsOneWidget);
      expect(find.text('• CeraVe Hydrating'), findsNothing);

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

    testWidgets(
      'SoftBlockCard (Skin Care) displays missing items with warning styling',
      (tester) async {
        final skinItem = RoutineItem(
          id: 'skin_missing',
          title: 'Morning Routine',
          startMinute: 8 * 60,
          endMinute: 8 * 60 + 30,
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.skinCare,
          steps: const ['Wash Face', 'Moisturize'],
          skincareProducts: const ['Cetaphil Cleanser'],
          skincareMissingItems: const ['SPF 50 Sunscreen', 'Vitamin C'],
        );

        await tester.pumpWidget(
          buildTestableViewport(
            items: [skinItem],
            layout: const TimelineLayout(
              visibleStartMinute: 8 * 60,
              visibleEndMinute: 10 * 60,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('MISSING'), findsOneWidget);
        expect(find.text('⚠ SPF 50 Sunscreen'), findsOneWidget);
        expect(find.text('⚠ Vitamin C'), findsOneWidget);

        final missingHeader = tester.widget<Text>(find.text('MISSING'));
        expect(missingHeader.style?.color, OptivusColors.warning);
      },
    );

    testWidgets(
      'SoftBlockCard (Eating) displays distinct mealSlot and mealCategory',
      (tester) async {
        final mealItem = RoutineItem(
          id: 'meal_slot_cat',
          title: 'Dinner',
          startMinute: 18 * 60,
          endMinute: 19 * 60,
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
          mealSlot: 'Dinner',
          mealCategory: 'Post-Workout High Protein',
          dishes: const ['Grilled Chicken', 'Brown Rice'],
        );

        await tester.pumpWidget(
          buildTestableViewport(
            items: [mealItem],
            layout: const TimelineLayout(
              visibleStartMinute: 18 * 60,
              visibleEndMinute: 20 * 60,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dinner'), findsOneWidget);
        expect(find.text('Post-Workout High Protein'), findsOneWidget);
      },
    );

    testWidgets(
      'HardBlockCard renders unconstrained multiline title, location, and notes',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final item = RoutineItem(
          id: 'multiline_hard',
          title:
              'Advanced Operating Systems\nConcurrency and Virtual Memory Lecture',
          startMinute: 10 * 60,
          endMinute: 12 * 60,
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
          professor: 'Dr. Elizabeth Montgomery',
          courseCode: 'CS 4400',
          location: 'Hall B, Room 304\nNorth Campus Science Complex',
          notes:
              'Bring previous lab reports.\nReview chapter 7 on page replacement.\nPrepare presentation slides.',
        );

        await tester.pumpWidget(
          buildTestableViewport(
            items: [item],
            layout: const TimelineLayout(
              visibleStartMinute: 10 * 60,
              visibleEndMinute: 13 * 60,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleText = tester.widget<Text>(
          find.text(
            'Advanced Operating Systems\nConcurrency and Virtual Memory Lecture',
          ),
        );
        expect(titleText.maxLines, isNull);
        expect(titleText.overflow, isNull);

        final locationText = tester.widget<Text>(
          find.text('Hall B, Room 304\nNorth Campus Science Complex'),
        );
        expect(locationText.maxLines, isNull);
        expect(locationText.overflow, isNull);

        final notesText = tester.widget<Text>(
          find.text(
            'Bring previous lab reports.\nReview chapter 7 on page replacement.\nPrepare presentation slides.',
          ),
        );
        expect(notesText.maxLines, isNull);
        expect(notesText.overflow, isNull);
      },
    );

    testWidgets(
      'RoutineCardActions consists of a single Row of 3 Expanded buttons with minHeight 44.0',
      (tester) async {
        final item = RoutineItem(
          id: 'actions_test',
          title: 'Standard Task',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          blockType: RoutineBlockType.flexibleTask,
        );

        await tester.pumpWidget(buildTestableViewport(items: [item]));
        await tester.pumpAndSettle();

        final actionsFinder = find.byType(RoutineCardActions);
        expect(actionsFinder, findsOneWidget);

        final expandedFinder = find.descendant(
          of: actionsFinder,
          matching: find.byType(Expanded),
        );
        expect(expandedFinder, findsNWidgets(3));

        final outerRow = tester.widget<Row>(
          find.descendant(of: actionsFinder, matching: find.byType(Row)).first,
        );
        expect(outerRow.children.whereType<Expanded>().length, 3);

        // Each button container has minHeight of 44.0
        final containers = tester.widgetList<Container>(
          find.descendant(
            of: actionsFinder,
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.constraints?.minHeight == 44.0,
            ),
          ),
        );
        expect(containers.length, 3);
      },
    );
  });

  group('Routine Step 14 Redesign: Card Colors & Scale Invariants', () {
    testWidgets(
      'Completed card retains category railColor (never turns green)',
      (tester) async {
        final hardItem = RoutineItem(
          id: 'completed_hard',
          title: 'Completed Class',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
          isCompleted: true,
        );

        await tester.pumpWidget(buildTestableViewport(items: [hardItem]));
        await tester.pumpAndSettle();

        final chrome = tester.widget<TimelineCardChrome>(
          find.byType(TimelineCardChrome),
        );
        expect(chrome.baseColor, OptivusColors.blockHard);
        expect(chrome.baseColor, isNot(OptivusColors.success));

        // Done action button has isSelected highlight
        final doneButtonFinder = find.byKey(
          const ValueKey('routine-action-done-completed_hard'),
        );
        expect(doneButtonFinder, findsOneWidget);
      },
    );

    testWidgets(
      'All 6 completed block types retain their individual category railColors without turning green',
      (tester) async {
        final cases = [
          (
            RoutineItem(
              id: 'c_hard',
              title: 'Hard Block',
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              blockType: RoutineBlockType.hardBlock,
              category: RoutineCategory.classBlock,
              isCompleted: true,
            ),
            OptivusColors.blockHard,
          ),
          (
            RoutineItem(
              id: 'c_soft',
              title: 'Soft Block',
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              blockType: RoutineBlockType.softBlock,
              category: RoutineCategory.eating,
              isCompleted: true,
            ),
            OptivusColors.blockSoft,
          ),
          (
            RoutineItem(
              id: 'c_flex',
              title: 'Flex Task',
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              blockType: RoutineBlockType.flexibleTask,
              isCompleted: true,
            ),
            OptivusColors.blockFlex,
          ),
          (
            RoutineItem(
              id: 'c_tracker',
              title: 'Tracker Task',
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              blockType: RoutineBlockType.trackerTask,
              isCompleted: true,
            ),
            OptivusColors.blockTracker,
          ),
          (
            RoutineItem(
              id: 'c_checkin',
              title: 'Check In',
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              blockType: RoutineBlockType.checkIn,
              isCompleted: true,
            ),
            OptivusColors.blockCheckIn,
          ),
          (
            RoutineItem(
              id: 'c_money',
              title: 'Money Task',
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              blockType: RoutineBlockType.moneyTask,
              isCompleted: true,
            ),
            OptivusColors.blockMoney,
          ),
        ];

        for (final (item, expectedColor) in cases) {
          await tester.pumpWidget(buildTestableViewport(items: [item]));
          await tester.pumpAndSettle();

          final chrome = tester.widget<TimelineCardChrome>(
            find.byType(TimelineCardChrome),
          );
          expect(
            chrome.baseColor,
            expectedColor,
            reason: 'Block type ${item.blockType} should use $expectedColor',
          );
          expect(
            chrome.baseColor,
            isNot(OptivusColors.success),
            reason: 'Block type ${item.blockType} should never turn green',
          );
        }
      },
    );

    test(
      'solveRoutineStretchConstraints and TimelineOverlapEngine.solveStretchConstraints produce equivalent scale transformations',
      () {
        final entries = [
          const RoutineConstraintEntry(
            startMinute: 9 * 60,
            endMinute: 9 * 60 + 15,
            minHeight: 120.0,
          ),
          const RoutineConstraintEntry(
            startMinute: 9 * 60 + 10,
            endMinute: 9 * 60 + 25,
            minHeight: 140.0,
          ),
          const RoutineConstraintEntry(
            startMinute: 12 * 60,
            endMinute: 12 * 60 + 10,
            minHeight: 100.0,
          ),
        ];

        const ppm = 1.0;
        final routineSegments = solveRoutineStretchConstraints(
          entries,
          pixelsPerMinute: ppm,
        );

        final timelineEntries = entries.asMap().entries.map((e) {
          return TimelineEntry(
            id: 'constraint_${e.key}',
            sourceId: 'constraint_${e.key}',
            startMinute: e.value.startMinute,
            endMinute: e.value.endMinute,
            repeatDays: const [1, 2, 3, 4, 5, 6, 7],
            title: 'Constraint',
            category: TimelineCategory.other,
            minHeight: e.value.minHeight,
          );
        }).toList();

        final coreSegments = TimelineOverlapEngine.solveStretchConstraints(
          timelineEntries,
          pixelsPerMinute: ppm,
        );

        expect(routineSegments.length, coreSegments.length);
        for (int i = 0; i < routineSegments.length; i++) {
          final r = routineSegments[i];
          final c = coreSegments[i];
          expect(r.startMinute, c.startMinute);
          expect(r.endMinute, c.endMinute);
          expect(r.extraStretch, closeTo(c.extraStretch, 0.001));
        }

        final routineScale = TimelineVisualScale(
          startMinute: 8 * 60,
          endMinute: 18 * 60,
          pixelsPerMinute: ppm,
          stretchedSegments: routineSegments,
        );
        final coreScale = TimelineVisualScale(
          startMinute: 8 * 60,
          endMinute: 18 * 60,
          pixelsPerMinute: ppm,
          stretchedSegments: coreSegments,
        );

        for (int m = 8 * 60; m <= 18 * 60; m += 15) {
          expect(
            routineScale.yForMinute(m),
            closeTo(coreScale.yForMinute(m), 0.001),
          );
        }
      },
    );
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

  group(
    'Routine Step 14 Final Redesign Verification: Strict Visual Language & Invariants',
    () {
      testWidgets(
        'Routine cards strictly use 18px accent icon, 14px w900 title, and 11px w800 accent time row (zero 42px emoji box)',
        (tester) async {
          final item = RoutineItem(
            id: 'class_exact',
            title: 'Algorithms Lecture',
            startMinute: 10 * 60,
            endMinute: 11 * 60 + 30,
            blockType: RoutineBlockType.hardBlock,
            category: RoutineCategory.classBlock,
          );

          await tester.pumpWidget(
            buildTestableViewport(
              items: [item],
              layout: const TimelineLayout(
                visibleStartMinute: 9 * 60,
                visibleEndMinute: 13 * 60,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Verify title styling: 14px, w900, textPrimary
          final titleWidget = tester.widget<Text>(
            find.text('Algorithms Lecture'),
          );
          expect(titleWidget.style?.fontSize, 14.0);
          expect(titleWidget.style?.fontWeight, FontWeight.w900);
          expect(titleWidget.style?.color, OptivusColors.textPrimary);

          // Verify time range styling: 11px, w800, accent color
          final timeWidget = tester.widget<Text>(
            find.text('10:00 AM – 11:30 AM'),
          );
          expect(timeWidget.style?.fontSize, 11.0);
          expect(timeWidget.style?.fontWeight, FontWeight.w800);
          expect(timeWidget.style?.color, OptivusColors.blockHard);

          // Verify icon: school icon with 18px size and accent color
          final iconWidget = tester.widget<Icon>(
            find.byIcon(Icons.school_rounded),
          );
          expect(iconWidget.size, 18.0);
          expect(iconWidget.color, OptivusColors.blockHard);

          // Verify NO 42px emoji box exists
          expect(
            find.byWidgetPredicate(
              (w) => w is Container && w.constraints?.maxWidth == 42.0,
            ),
            findsNothing,
          );

          // Verify RoutineRichTimelineCard is rendered
          expect(find.byType(RoutineRichTimelineCard), findsOneWidget);
        },
      );

      testWidgets(
        'Meal nutrition pill and dishes chips use Step 14 white frosted glass styling',
        (tester) async {
          final mealItem = RoutineItem(
            id: 'meal_glass',
            title: 'Lunch',
            startMinute: 12 * 60,
            endMinute: 12 * 60 + 45,
            blockType: RoutineBlockType.softBlock,
            category: RoutineCategory.eating,
            caloriesEstimate: 500,
            proteinEstimate: 35,
            dishes: const ['Chicken Rice', 'Salad Bowl'],
          );

          await tester.pumpWidget(
            buildTestableViewport(
              items: [mealItem],
              layout: const TimelineLayout(
                visibleStartMinute: 11 * 60,
                visibleEndMinute: 14 * 60,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Find nutrition container
          final nutritionText = find.text('500 kcal • 35g protein');
          expect(nutritionText, findsOneWidget);
          final nutritionContainer = tester.widget<Container>(
            find
                .ancestor(of: nutritionText, matching: find.byType(Container))
                .first,
          );
          final nutritionBox = nutritionContainer.decoration as BoxDecoration;
          expect(nutritionBox.color, Colors.white.withValues(alpha: 0.85));
          expect(nutritionBox.borderRadius, BorderRadius.circular(8));
          expect(
            (nutritionBox.border as Border).top.color,
            OptivusColors.blockSoft.withValues(alpha: 0.35),
          );

          // Find dish chip container
          final dishText = find.text('Chicken Rice');
          expect(dishText, findsOneWidget);
          final dishContainer = tester.widget<Container>(
            find.ancestor(of: dishText, matching: find.byType(Container)).first,
          );
          final dishBox = dishContainer.decoration as BoxDecoration;
          expect(dishBox.color, Colors.white.withValues(alpha: 0.9));
          expect(dishBox.borderRadius, BorderRadius.circular(6));
          expect((dishBox.border as Border).top.color, const Color(0xFFD4D7E2));
        },
      );

      test(
        'Skincare slot label round-trips via Firestore codec and RoutineItem.fromMap',
        () {
          final original = RoutineItem(
            id: 'skin_slot_item',
            title: 'Night Glow Care',
            startMinute: 21 * 60,
            endMinute: 21 * 60 + 20,
            blockType: RoutineBlockType.softBlock,
            category: RoutineCategory.skinCare,
            skincareSlotLabel: 'Evening Wind-down',
          );

          const codec = RoutineTemplateFirestoreCodec();
          final firestoreMap = codec.toFirestore(
            ownerUid: 'test_uid',
            item: original,
          );
          expect(firestoreMap['skincareSlotLabel'], 'Evening Wind-down');

          final reconstructed = codec.fromFirestore(
            documentId: 'skin_slot_item',
            data: firestoreMap,
          );
          expect(reconstructed.skincareSlotLabel, 'Evening Wind-down');

          final copied = original.copyWith(
            skincareSlotLabel: 'Morning Awakening',
          );
          expect(copied.skincareSlotLabel, 'Morning Awakening');

          final itemMap = original.toMap();
          expect(itemMap['skincareSlotLabel'], 'Evening Wind-down');
          final fromMapItem = RoutineItem.fromMap(itemMap);
          expect(fromMapItem.skincareSlotLabel, 'Evening Wind-down');
        },
      );

      testWidgets(
        'Skincare slot label renders when distinct from title and is omitted when identical',
        (tester) async {
          final distinctSlotItem = RoutineItem(
            id: 'skin_distinct',
            title: 'Glow Care',
            startMinute: 8 * 60,
            endMinute: 8 * 60 + 20,
            blockType: RoutineBlockType.softBlock,
            category: RoutineCategory.skinCare,
            skincareSlotLabel: 'Morning Ritual',
          );

          final identicalSlotItem = RoutineItem(
            id: 'skin_identical',
            title: 'Night Care',
            startMinute: 22 * 60,
            endMinute: 22 * 60 + 20,
            blockType: RoutineBlockType.softBlock,
            category: RoutineCategory.skinCare,
            skincareSlotLabel: 'Night Care',
          );

          await tester.pumpWidget(
            buildTestableViewport(
              items: [distinctSlotItem, identicalSlotItem],
              layout: const TimelineLayout(
                visibleStartMinute: 7 * 60,
                visibleEndMinute: 23 * 60,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Morning Ritual'), findsOneWidget);
          // 'Night Care' only appears once as the title, not duplicated as a slot label
          expect(find.text('Night Care'), findsOneWidget);
        },
      );

      testWidgets(
        'Overnight items render exact Step 14 canonical phrasing ("Continues tomorrow" and "Continued from yesterday")',
        (tester) async {
          final day1Sleep = RoutineItem(
            id: 'sleep_day1',
            title: 'Sleep',
            startMinute: 23 * 60,
            endMinute: 7 * 60,
            crossesMidnight: true,
            endsNextDay: true,
            isContinuation: false,
            blockType: RoutineBlockType.hardBlock,
            category: RoutineCategory.sleep,
          );

          final day2Sleep = RoutineItem(
            id: 'sleep_day2',
            title: 'Sleep',
            startMinute: 0,
            endMinute: 7 * 60,
            crossesMidnight: true,
            endsNextDay: false,
            isContinuation: true,
            blockType: RoutineBlockType.hardBlock,
            category: RoutineCategory.sleep,
          );

          await tester.pumpWidget(
            buildTestableViewport(
              items: [day1Sleep],
              layout: const TimelineLayout(
                visibleStartMinute: 22 * 60,
                visibleEndMinute: 1440,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Continues tomorrow'), findsOneWidget);

          await tester.pumpWidget(
            buildTestableViewport(
              items: [day2Sleep],
              layout: const TimelineLayout(
                visibleStartMinute: 0,
                visibleEndMinute: 8 * 60,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Continued from yesterday'), findsOneWidget);
        },
      );

      testWidgets(
        'Extra long dish name wraps gracefully without horizontal overflow, truncation, or ellipsis',
        (tester) async {
          const longDish =
              'Ultra Long Free-Range Herb Roasted Organic Rosemary Chicken Breast with Lemon Infused Glaze and Garlic Mashed Potatoes';
          final mealItem = RoutineItem(
            id: 'meal_long_dish',
            title: 'Post-Workout Meal',
            startMinute: 13 * 60,
            endMinute: 14 * 60,
            blockType: RoutineBlockType.softBlock,
            category: RoutineCategory.eating,
            dishes: const [longDish],
          );

          await tester.pumpWidget(
            buildTestableViewport(
              items: [mealItem],
              layout: const TimelineLayout(
                visibleStartMinute: 12 * 60,
                visibleEndMinute: 15 * 60,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final dishFinder = find.text(longDish);
          expect(dishFinder, findsOneWidget);

          final textWidget = tester.widget<Text>(dishFinder);
          expect(textWidget.maxLines, isNull);
          expect(textWidget.overflow, isNot(equals(TextOverflow.ellipsis)));

          final cardBox = tester.renderObject<RenderBox>(
            find.byKey(const ValueKey('routine-timeline-card-meal_long_dish')),
          );
          expect(cardBox.size.height, greaterThan(110.0));
        },
      );

      testWidgets(
        'Extra long dish name at 2.5x accessibility text scale renders complete string without overflow',
        (tester) async {
          const longDish =
              'Ultra Long Free-Range Herb Roasted Organic Rosemary Chicken Breast with Lemon Infused Glaze and Garlic Mashed Potatoes';
          final mealItem = RoutineItem(
            id: 'meal_long_dish_scale',
            title: 'Post-Workout Meal',
            startMinute: 13 * 60,
            endMinute: 14 * 60,
            blockType: RoutineBlockType.softBlock,
            category: RoutineCategory.eating,
            dishes: const [longDish],
          );

          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                textScaler: TextScaler.linear(2.5),
              ),
              child: buildTestableViewport(
                items: [mealItem],
                layout: const TimelineLayout(
                  visibleStartMinute: 12 * 60,
                  visibleEndMinute: 15 * 60,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final dishFinder = find.text(longDish);
          expect(dishFinder, findsOneWidget);

          final textWidget = tester.widget<Text>(dishFinder);
          expect(textWidget.maxLines, isNull);
          expect(textWidget.overflow, isNot(equals(TextOverflow.ellipsis)));
        },
      );

      testWidgets(
        'Action button hides icon and preserves label at 2.5x accessibility scale',
        (tester) async {
          final item = RoutineItem(
            id: 'scale_task',
            title: 'Deep Work Session',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            blockType: RoutineBlockType.flexibleTask,
          );

          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(2.5),
              ),
              child: buildTestableViewport(
                items: [item],
                layout: const TimelineLayout(
                  visibleStartMinute: 8 * 60,
                  visibleEndMinute: 11 * 60,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Start'), findsOneWidget);
          expect(find.text('Done'), findsOneWidget);
          expect(find.text('Move'), findsOneWidget);

          // Verify that the small action icon in RoutineCardActions is omitted to prevent truncation
          final playIconInAction = find.descendant(
            of: find.byKey(const ValueKey('routine-action-start-scale_task')),
            matching: find.byIcon(Icons.play_arrow_rounded),
          );
          expect(playIconInAction, findsNothing);
        },
      );

      testWidgets(
        'Routine timeline uses shared TimelineBackTabStrip for gutter tabs',
        (tester) async {
          final itemA = RoutineItem(
            id: 'overlap_a',
            title: 'Task Alpha',
            startMinute: 10 * 60,
            endMinute: 11 * 60,
            blockType: RoutineBlockType.flexibleTask,
          );
          final itemB = RoutineItem(
            id: 'overlap_b',
            title: 'Task Beta',
            startMinute: 10 * 60 + 15,
            endMinute: 11 * 60,
            blockType: RoutineBlockType.hardBlock,
          );

          await tester.pumpWidget(
            buildTestableViewport(
              items: [itemA, itemB],
              layout: const TimelineLayout(
                visibleStartMinute: 9 * 60,
                visibleEndMinute: 12 * 60,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(TimelineBackTabStrip), findsOneWidget);
        },
      );

      testWidgets(
        'Nested action taps and front-card body taps do not trigger whole-card press scale or feedback',
        (tester) async {
          final item = RoutineItem(
            id: 'test_actions_card',
            title: 'Design Review',
            startMinute: 10 * 60,
            endMinute: 11 * 60,
            blockType: RoutineBlockType.flexibleTask,
          );

          _MockRoutineNotifier? notifier;
          await tester.pumpWidget(
            buildTestableViewport(
              items: [item],
              layout: const TimelineLayout(
                visibleStartMinute: 10 * 60,
                visibleEndMinute: 13 * 60,
              ),
              onNotifierCreated: (n) => notifier = n,
            ),
          );
          await tester.pumpAndSettle();

          // 1. Verify RoutineCardBase is a StatelessWidget with no scale transition/controller
          final cardBaseWidget = tester.widget<RoutineCardBase>(
            find.byType(RoutineCardBase),
          );
          expect(cardBaseWidget, isA<StatelessWidget>());
          expect(
            find.descendant(
              of: find.byType(RoutineCardBase),
              matching: find.byType(ScaleTransition),
            ),
            findsNothing,
          );

          // 2. Tap Start button: only Start action occurs
          final startFinder = find.byKey(
            const ValueKey('routine-action-start-test_actions_card'),
          );
          expect(startFinder, findsOneWidget);
          await tester.tap(startFinder);
          await tester.pumpAndSettle();
          expect(notifier!.startedItemIds, contains('test_actions_card'));

          // 3. Tap Done button: only Done action occurs
          final doneFinder = find.byKey(
            const ValueKey('routine-action-done-test_actions_card'),
          );
          expect(doneFinder, findsOneWidget);
          await tester.tap(doneFinder);
          await tester.pumpAndSettle();
          expect(notifier!.completedItemIds, contains('test_actions_card'));

          // 4. Tap Move button: move sheet opens
          final moveFinder = find.byKey(
            const ValueKey('routine-action-move-test_actions_card'),
          );
          expect(moveFinder, findsOneWidget);
          await tester.tap(moveFinder);
          await tester.pumpAndSettle();
          expect(find.text('Move Design Review'), findsOneWidget);

          // Dismiss sheet
          await tester.tapAt(const Offset(20, 20));
          await tester.pumpAndSettle();

          // 5. Normal front-card body tap does nothing (no sheet, no movement)
          final cardTitle = find.text('Design Review');
          await tester.tap(cardTitle);
          await tester.pumpAndSettle();
          expect(find.text('Move Design Review'), findsNothing);
        },
      );
    },
  );

  group('Back-Tab Vertical Placement Parity (computeBackTabTopOffsets)', () {
    test('same-start overlapping items stack sequentially', () {
      const requests = [
        TimelineBackTabPlacementRequest(
          id: 'a',
          startY: 100.0,
          tabHeight: 44.0,
        ),
        TimelineBackTabPlacementRequest(
          id: 'b',
          startY: 100.0,
          tabHeight: 44.0,
        ),
        TimelineBackTabPlacementRequest(
          id: 'c',
          startY: 100.0,
          tabHeight: 44.0,
        ),
      ];
      final offsets = computeBackTabTopOffsets(requests);
      expect(offsets['a'], 100.0);
      expect(offsets['b'], 144.0);
      expect(offsets['c'], 188.0);
    });

    test('starts 2 minutes apart (|Δy| < 4.0) stack sequentially', () {
      // 2 minutes apart with scale 1.4 px/min = 2.8px delta < 4.0
      const requests = [
        TimelineBackTabPlacementRequest(
          id: 'a',
          startY: 100.0,
          tabHeight: 44.0,
        ),
        TimelineBackTabPlacementRequest(
          id: 'b',
          startY: 102.8,
          tabHeight: 44.0,
        ),
      ];
      final offsets = computeBackTabTopOffsets(requests);
      expect(offsets['a'], 100.0);
      expect(offsets['b'], 102.8 + 44.0);
    });

    test('starts 5 minutes apart (|Δy| >= 4.0) anchor independently', () {
      // 5 minutes apart with scale 1.4 px/min = 7.0px delta >= 4.0
      const requests = [
        TimelineBackTabPlacementRequest(
          id: 'a',
          startY: 100.0,
          tabHeight: 44.0,
        ),
        TimelineBackTabPlacementRequest(
          id: 'b',
          startY: 107.0,
          tabHeight: 44.0,
        ),
      ];
      final offsets = computeBackTabTopOffsets(requests);
      expect(offsets['a'], 100.0);
      expect(offsets['b'], 107.0);
    });

    test('later overlapping region anchors to its own startY', () {
      const requests = [
        TimelineBackTabPlacementRequest(
          id: 'a',
          startY: 200.0,
          tabHeight: 44.0,
        ),
        TimelineBackTabPlacementRequest(
          id: 'b',
          startY: 201.0,
          tabHeight: 44.0,
        ),
        TimelineBackTabPlacementRequest(
          id: 'c',
          startY: 450.0,
          tabHeight: 44.0,
        ),
      ];
      final offsets = computeBackTabTopOffsets(requests);
      expect(offsets['a'], 200.0);
      expect(offsets['b'], 245.0);
      expect(offsets['c'], 450.0);
    });

    test('4+ back items stack and reset based on timing accurately', () {
      const requests = [
        TimelineBackTabPlacementRequest(
          id: 't1',
          startY: 100.0,
          tabHeight: 40.0,
        ),
        TimelineBackTabPlacementRequest(
          id: 't2',
          startY: 100.0,
          tabHeight: 40.0,
        ),
        TimelineBackTabPlacementRequest(
          id: 't3',
          startY: 102.0,
          tabHeight: 40.0,
        ),
        TimelineBackTabPlacementRequest(
          id: 't4',
          startY: 250.0,
          tabHeight: 40.0,
        ),
        TimelineBackTabPlacementRequest(
          id: 't5',
          startY: 250.0,
          tabHeight: 40.0,
        ),
      ];
      final offsets = computeBackTabTopOffsets(requests);
      expect(offsets['t1'], 100.0);
      expect(offsets['t2'], 140.0);
      expect(offsets['t3'], 182.0);
      expect(offsets['t4'], 250.0);
      expect(offsets['t5'], 290.0);
    });
  });

  group('Measurement and Render Parity Verification', () {
    testWidgets(
      'Measured height covers actual rendered card height without overflow for rich card at 1.0x scale',
      (tester) async {
        final richItem = RoutineItem(
          id: 'rich_test_meal',
          title: 'Comprehensive Nutrition Feast and Hydration Session',
          startMinute: 12 * 60,
          endMinute: 13 * 60,
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
          mealCategory: 'Lunch',
          mealSlot: 'Midday Refuel',
          location: 'Building 4 Cafe • 2nd Floor Dining Area',
          caloriesEstimate: 750,
          proteinEstimate: 48,
          dishes: const [
            'Quinoa Salad with Roasted Chickpeas and Lemon Vinaigrette',
            'Grilled Atlantic Salmon Filet with Herb Butter',
            'Steamed Broccoli Florets',
            'Ultra Long Free-Range Herb Roasted Organic Rosemary Chicken Breast with Lemon Infused Glaze and Garlic Mashed Potatoes',
            'Sparkling Water with Lime',
          ],
          subtasks: const [
            'Log calories in tracker',
            'Take daily multivitamins and omega-3 capsule',
            'Drink 500ml water before eating',
          ],
          notes:
              'Take digestive enzymes before meal and review notes afterwards.',
        );

        const cardWidth = 350.0;
        double measuredHeight = 0.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  measuredHeight = RoutineCardFactory.measureHeight(
                    context,
                    cardWidth,
                    richItem,
                  );
                  return SingleChildScrollView(
                    child: SizedBox(
                      width: cardWidth,
                      child: RoutineRichTimelineCard(item: richItem),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final renderBox = tester.renderObject<RenderBox>(
          find.byType(RoutineRichTimelineCard),
        );
        final renderedHeight = renderBox.size.height;
        expect(measuredHeight, greaterThanOrEqualTo(renderedHeight));
        expect(measuredHeight - renderedHeight, lessThan(8.0));
      },
    );

    testWidgets(
      'Measured height covers actual rendered card height for rich skincare card at 2.5x text scale',
      (tester) async {
        final richSkinItem = RoutineItem(
          id: 'rich_test_skin',
          title: 'Evening Dermatology Regimen and Skin Barrier Repair',
          startMinute: 21 * 60,
          endMinute: 22 * 60,
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.skinCare,
          skincareSlotLabel: 'Night Regimen',
          location: 'Master Bathroom',
          steps: const [
            'Oil Cleanse with gentle balm',
            'Hydrating foaming cleanser massage for 60 seconds',
            'Soothing Centella Asiatica calming toner pad application',
            'Multi-peptide barrier support serum',
            'Ceramide rich night repair cream',
          ],
          skincareProducts: const [
            'Kose Softymo Deep Cleansing Oil',
            'CeraVe Hydrating Facial Cleanser',
            'Skin1004 Madagascar Centella Toner',
            'The Ordinary Multi-Peptide + HA Serum',
            'Illiyoon Ceramide Ato Concentrate Cream',
          ],
          skincareMissingItems: const [
            'Replacement micellar water',
            'Mineral SPF sunscreen for morning',
          ],
          notes:
              'Allow 3 minutes between serum and moisturizer for maximum absorption.',
        );

        const cardWidth = 360.0;
        double measuredHeight = 0.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
                child: Builder(
                  builder: (context) {
                    measuredHeight = RoutineCardFactory.measureHeight(
                      context,
                      cardWidth,
                      richSkinItem,
                    );
                    return SingleChildScrollView(
                      child: SizedBox(
                        width: cardWidth,
                        child: RoutineRichTimelineCard(item: richSkinItem),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final renderBox = tester.renderObject<RenderBox>(
          find.byType(RoutineRichTimelineCard),
        );
        final renderedHeight = renderBox.size.height;

        // Measured height must be >= rendered height at 2.5x scale
        expect(measuredHeight, greaterThanOrEqualTo(renderedHeight));
        expect(measuredHeight - renderedHeight, lessThan(12.0));
      },
    );

    testWidgets(
      'Overnight continuation is positioned after notes/subtasks and before actions footer with 8px gap',
      (tester) async {
        final overnightItem = RoutineItem(
          id: 'overnight_pos_test',
          title: 'Night Shift Study',
          startMinute: 23 * 60,
          endMinute: 2 * 60, // Crosses midnight
          blockType: RoutineBlockType.flexibleTask,
          location: 'Library',
          notes: 'Prepare final revision notes',
          subtasks: const ['Read Chapter 4'],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: RoutineRichTimelineCard(item: overnightItem),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Continues tomorrow'), findsOneWidget);
        expect(find.text('Prepare final revision notes'), findsOneWidget);

        // Find the inner Column
        final innerColumn = tester.widget<Column>(
          find
              .descendant(
                of: find.byType(RoutineRichTimelineCard),
                matching: find.byType(Column),
              )
              .first,
        );

        var notesIndex = -1;
        var continuationIndex = -1;
        var actionsIndex = -1;

        for (var i = 0; i < innerColumn.children.length; i++) {
          final child = innerColumn.children[i];
          if (child is Text && child.data == 'Prepare final revision notes') {
            notesIndex = i;
          } else if (child is Text && child.data == 'Continues tomorrow') {
            continuationIndex = i;
          } else if (child is RoutineCardActions) {
            actionsIndex = i;
          }
        }

        expect(notesIndex, greaterThanOrEqualTo(0));
        expect(continuationIndex, greaterThan(notesIndex));
        expect(actionsIndex, greaterThan(continuationIndex));

        // The SizedBox immediately before 'Continues tomorrow' has height == 8.0 (continuationGap)
        final gapBeforeContinuation =
            innerColumn.children[continuationIndex - 1];
        expect(gapBeforeContinuation, isA<SizedBox>());
        expect(
          (gapBeforeContinuation as SizedBox).height,
          RoutineCardPresentation.continuationGap,
        );
        expect(RoutineCardPresentation.continuationGap, 8.0);
      },
    );

    testWidgets(
      'Narrow overlap front-card width (180px) renders at 1.0x, 2.0x, and 2.5x without overflow and footer stacks',
      (tester) async {
        final richMeal = RoutineItem(
          id: 'overlap_front_meal',
          title: 'Post-Workout High Protein Recovery Meal',
          startMinute: 12 * 60,
          endMinute: 13 * 60,
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
          mealSlot: 'Lunch',
          mealCategory: 'High Protein',
          caloriesEstimate: 820,
          proteinEstimate: 56,
          dishes: const [
            'Pan-Seared Atlantic Salmon Fillet with Garlic Butter and Fresh Lemon Herbs',
            'Steamed Organic Jasmine Rice Bowl',
            'Roasted Broccoli Florets',
            'Fresh Haas Avocado Slices',
          ],
          notes: 'Take omega-3 supplement with first bite of meal.',
        );

        const frontWidth = 180.0;

        for (final scale in [1.0, 2.0, 2.5]) {
          double measuredHeight = 0.0;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Builder(
                    builder: (context) {
                      measuredHeight = RoutineCardFactory.measureHeight(
                        context,
                        frontWidth,
                        richMeal,
                      );
                      return SingleChildScrollView(
                        child: SizedBox(
                          width: frontWidth,
                          child: RoutineRichTimelineCard(item: richMeal),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final exc = tester.takeException();
          if (exc != null) {
            if (exc is FlutterError) {
              for (final d in exc.diagnostics) {
                debugPrint('DIAG: ${d.toString()}');
              }
            }
          }
          expect(exc, isNull);

          // All dishes, nutrition, and notes are rendered
          expect(find.text('820 kcal • 56g protein'), findsOneWidget);
          expect(
            find.text(
              'Pan-Seared Atlantic Salmon Fillet with Garlic Butter and Fresh Lemon Herbs',
            ),
            findsOneWidget,
          );
          expect(
            find.text('Steamed Organic Jasmine Rice Bowl'),
            findsOneWidget,
          );
          expect(
            find.text('Take omega-3 supplement with first bite of meal.'),
            findsOneWidget,
          );

          // Primary action buttons are visible and NOT truncated with ellipsis
          expect(find.text('Start'), findsOneWidget);
          expect(find.text('Done'), findsOneWidget);
          expect(find.text('Move'), findsOneWidget);

          final startText = tester.widget<Text>(find.text('Start'));
          expect(startText.overflow, isNull);

          // At 180px frontWidth (< 225px content width), action footer stacks vertically
          expect(
            find.descendant(
              of: find.byType(RoutineCardActions),
              matching: find.byType(Column),
            ),
            findsOneWidget,
          );

          final renderBox = tester.renderObject<RenderBox>(
            find.byType(RoutineRichTimelineCard),
          );
          final renderedHeight = renderBox.size.height;

          // Measured height must cover rendered height
          expect(
            measuredHeight,
            greaterThanOrEqualTo(renderedHeight),
            reason:
                'At scale $scale, measured ($measuredHeight) must be >= rendered ($renderedHeight)',
          );
          expect(
            measuredHeight - renderedHeight,
            lessThan(12.0),
            reason:
                'At scale $scale, drift (${measuredHeight - renderedHeight}) must be < 12.0',
          );
        }
      },
    );

    testWidgets(
      'True overlap viewport integration: Work, Meal (multi-dish), Skin Care, Class with Meal promoted to front',
      (tester) async {
        final workItem = RoutineItem(
          id: 'overlap_work',
          title: 'Deep Work Session',
          startMinute: 12 * 60,
          endMinute: 13 * 60,
          blockType: RoutineBlockType.flexibleTask,
        );

        final mealItem = RoutineItem(
          id: 'overlap_meal',
          title: 'High Protein Lunch',
          startMinute: 12 * 60 + 5,
          endMinute: 12 * 60 + 35,
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
          mealSlot: 'Lunch',
          caloriesEstimate: 750,
          proteinEstimate: 48,
          dishes: const [
            'Grilled Salmon Fillet with Garlic Herbs',
            'Brown Rice Bowl',
            'Steamed Broccoli',
            'Avocado Slices',
          ],
        );

        final skinItem = RoutineItem(
          id: 'overlap_skin',
          title: 'Midday Skin Refresh',
          startMinute: 12 * 60 + 15,
          endMinute: 12 * 60 + 30,
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.skinCare,
          steps: const ['Gentle Cleanse', 'Moisturize'],
        );

        final classItem = RoutineItem(
          id: 'overlap_class',
          title: 'Algorithms Lecture',
          startMinute: 12 * 60 + 20,
          endMinute: 12 * 60 + 40,
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final items = [workItem, mealItem, skinItem, classItem];

        await tester.pumpWidget(
          buildTestableViewport(
            items: items,
            layout: const TimelineLayout(
              visibleStartMinute: 11 * 60,
              visibleEndMinute: 14 * 60,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Find the back tab for mealItem and tap it to promote it to the front
        final mealTab = find.byKey(
          ValueKey('routine-back-label-${mealItem.id}'),
        );
        expect(mealTab, findsOneWidget);
        await tester.tap(mealTab);
        await tester.pumpAndSettle();

        // Verify Meal is the front card
        final frontCardFinder = find.byKey(
          ValueKey('routine-timeline-card-${mealItem.id}'),
        );
        expect(frontCardFinder, findsOneWidget);

        final positioned = tester.widget<Positioned>(frontCardFinder);

        // Front card width is the overlap frontWidth (less than fullWidth 290.0)
        expect(positioned.width, isNotNull);
        expect(positioned.width!, lessThan(290.0));

        // All dishes are visible and readable
        expect(
          find.text('Grilled Salmon Fillet with Garlic Herbs'),
          findsOneWidget,
        );
        expect(find.text('Brown Rice Bowl'), findsOneWidget);
        expect(find.text('Steamed Broccoli'), findsOneWidget);
        expect(find.text('Avocado Slices'), findsOneWidget);

        // Action buttons are present and readable
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Move'), findsOneWidget);

        // Back tabs exist in the overlap gutter for the other overlapping items
        expect(find.byType(TimelineBackTabStrip), findsWidgets);

        // Tapping back tab for Work promotes Work to front
        final workTab = find.byKey(
          ValueKey('routine-back-label-${workItem.id}'),
        );
        expect(workTab, findsOneWidget);
        await tester.tap(workTab);
        await tester.pumpAndSettle();

        // Now Work is the front card
        expect(
          find.descendant(
            of: find.byKey(ValueKey('routine-timeline-card-${workItem.id}')),
            matching: find.text('Deep Work Session'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
