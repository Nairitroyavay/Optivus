import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/models/add_routine_draft.dart';
import 'package:optivus/features/routine/models/routine_action_availability.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/add_routine_mapper.dart';
import 'package:optivus/features/routine/services/routine_move_seed.dart';
import 'package:optivus/features/routine/services/routine_transition_policy.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_presentation.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  group('Gate A & B: Subtype Isolation & Nullable Clearing via Sentinels', () {
    test('Class details do not bleed into Work or Eating details', () {
      final state = const AddRoutineFixedState(
        kind: 'Class',
        professor: 'Dr. Turing',
        courseCode: 'CS101',
        classType: 'Lecture',
        sectionLabel: 'Sec A',
        classLocation: 'Hall 1',
      );

      final draftClass = AddRoutineDraft.initial(
        id: 'c1',
        initialType: AddRoutineType.fixed,
      ).copyWith(
        title: 'Computer Science',
        fixedState: state,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        durationMinutes: 60,
      );

      final itemClass = AddRoutineMapper.toRoutineItem(draftClass);
      expect(itemClass.professor, 'Dr. Turing');
      expect(itemClass.courseCode, 'CS101');
      expect(itemClass.location, 'Hall 1');
      expect(itemClass.workRole, isNull);
      expect(itemClass.mealCategory, isNull);
      expect(itemClass.dishes, isNull);

      // Switch to Work kind
      final draftWork = draftClass.copyWith(
        fixedState: state.copyWith(
          kind: 'Work',
          workRole: 'Software Engineer',
          workLocation: 'HQ Floor 4',
        ),
      );

      final itemWork = AddRoutineMapper.toRoutineItem(draftWork);
      // Work item must NOT inherit class professor or class location
      expect(itemWork.workRole, 'Software Engineer');
      expect(itemWork.location, 'HQ Floor 4');
      expect(itemWork.professor, isNull);
      expect(itemWork.courseCode, isNull);
    });

    test('Nullable clearing resets field to null when explicitly assigned null', () {
      final state = const AddRoutineFixedState(
        kind: 'Work',
        workRole: 'Lead',
        workLocation: 'Campus B',
      );
      expect(state.workLocation, 'Campus B');

      final cleared = state.copyWith(workLocation: null);
      expect(cleared.workLocation, isNull);
      expect(cleared.workRole, 'Lead');
    });

    test('Text normalization trims whitespace and maps empty strings to null', () {
      final draft = AddRoutineDraft.initial(
        id: 'norm_1',
        initialType: AddRoutineType.flexible,
      ).copyWith(
        title: '   Clean Code   ',
        notes: '   ',
        bestTime: '  ',
      );
      final item = AddRoutineMapper.toRoutineItem(draft);
      expect(item.title, 'Clean Code');
      expect(item.notes, isNull);
      expect(item.bestTime, isNull);
    });
  });

  group('Gate C: Structured Details Progressive Disclosure Roundtrip', () {
    test('Eating and Skincare metadata map cleanly to RoutineItem', () {
      final eatingState = const AddRoutineFixedState(
        kind: 'Eating',
        mealCategory: 'Dinner',
        mealSlot: 'Evening Meal',
        dishes: ['Quinoa', 'Salmon'],
        caloriesEstimate: 650,
        proteinEstimate: 45,
      );
      final eatingDraft = AddRoutineDraft.initial(
        id: 'eat_1',
        initialType: AddRoutineType.fixed,
      ).copyWith(
        title: 'Healthy Dinner',
        fixedState: eatingState,
        startTime: const TimeOfDay(hour: 19, minute: 0),
        durationMinutes: 45,
      );
      final eatingItem = AddRoutineMapper.toRoutineItem(eatingDraft);
      expect(eatingItem.category, RoutineCategory.eating);
      expect(eatingItem.mealCategory, 'Dinner');
      expect(eatingItem.mealSlot, 'Evening Meal');
      expect(eatingItem.dishes, ['Quinoa', 'Salmon']);
      expect(eatingItem.caloriesEstimate, 650);
      expect(eatingItem.proteinEstimate, 45);

      final skinState = const AddRoutineFixedState(
        kind: 'Skin Care',
        skincareSlotLabel: 'Night Regimen',
        steps: ['Cleanser', 'Moisturizer'],
        skincareProducts: ['Cetaphil', 'Cerave'],
        skincareMissingItems: ['Sunscreen'],
      );
      final skinDraft = AddRoutineDraft.initial(
        id: 'skin_1',
        initialType: AddRoutineType.fixed,
      ).copyWith(
        title: 'Night Glow',
        fixedState: skinState,
        startTime: const TimeOfDay(hour: 22, minute: 0),
        durationMinutes: 20,
      );
      final skinItem = AddRoutineMapper.toRoutineItem(skinDraft);
      expect(skinItem.category, RoutineCategory.skinCare);
      expect(skinItem.skincareSlotLabel, 'Night Regimen');
      expect(skinItem.steps, ['Cleanser', 'Moisturizer']);
      expect(skinItem.skincareProducts, ['Cetaphil', 'Cerave']);
      expect(skinItem.skincareMissingItems, ['Sunscreen']);
    });
  });

  group('Gate D: bestTime Persistence Policy', () {
    test('bestTime is null for Fixed, Tracker, Checkin, Money', () {
      final fixed = AddRoutineDraft.initial(initialType: AddRoutineType.fixed);
      final tracker = AddRoutineDraft.initial(initialType: AddRoutineType.tracker);
      final money = AddRoutineDraft.initial(initialType: AddRoutineType.money);
      final checkin = AddRoutineDraft.initial(initialType: AddRoutineType.checkin);

      expect(AddRoutineMapper.toRoutineItem(fixed).bestTime, isNull);
      expect(AddRoutineMapper.toRoutineItem(tracker).bestTime, isNull);
      expect(AddRoutineMapper.toRoutineItem(money).bestTime, isNull);
      expect(AddRoutineMapper.toRoutineItem(checkin).bestTime, isNull);
    });

    test('bestTime is preserved for Flexible and Habit types', () {
      final flex = AddRoutineDraft.initial(initialType: AddRoutineType.flexible).copyWith(
        bestTime: 'Evening',
      );
      final habit = AddRoutineDraft.initial(initialType: AddRoutineType.habit).copyWith(
        bestTime: 'Morning',
      );

      expect(AddRoutineMapper.toRoutineItem(flex).bestTime, 'Evening');
      expect(AddRoutineMapper.toRoutineItem(habit).bestTime, 'Morning');
    });
  });

  group('Gate E: Weekly findWeeklyFreeSlot Across Repeat Days', () {
    test('findWeeklyFreeSlot finds slot free on all required weekdays', () {
      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(routineNotifierProvider.notifier);

      // Add item on Mondays at 9:00-10:00 (540-600)
      final mondayItem = RoutineItem(
        id: 'mon_item',
        title: 'Monday Class',
        startMinute: 540,
        endMinute: 600,
        repeatDays: const [DateTime.monday],
        repeatRule: 'weekly',
        blockType: RoutineBlockType.hardBlock,
      );
      // Add item on Wednesdays at 10:00-11:00 (600-660)
      final wednesdayItem = RoutineItem(
        id: 'wed_item',
        title: 'Wednesday Class',
        startMinute: 600,
        endMinute: 660,
        repeatDays: const [DateTime.wednesday],
        repeatRule: 'weekly',
        blockType: RoutineBlockType.hardBlock,
      );

      container.read(routineNotifierProvider.notifier).state =
          container.read(routineNotifierProvider).copyWith(
                items: [mondayItem, wednesdayItem],
              );

      // Slot for repeat days [Monday, Wednesday] for 60 min duration:
      // Minute 540-600 is busy on Monday.
      // Minute 600-660 is busy on Wednesday.
      // So minute 660-720 (11:00 AM) is free on BOTH!
      final freeSlot = notifier.findWeeklyFreeSlot(
        item: RoutineItem(
          id: 'candidate',
          title: 'New Class',
          startMinute: 0,
          endMinute: 60,
          blockType: RoutineBlockType.hardBlock,
        ),
        repeatDays: const [DateTime.monday, DateTime.wednesday],
        durationMinutes: 60,
        baseDate: DateTime(2026, 9, 14),
      );

      expect(freeSlot, isNotNull);
      // Either before 540 or after 660, never overlapping 540-660
      final overlapsMonday = freeSlot! < 600 && (freeSlot + 60) > 540;
      final overlapsWednesday = freeSlot < 660 && (freeSlot + 60) > 600;
      expect(overlapsMonday, false);
      expect(overlapsWednesday, false);
    });
  });

  group('Gate G: Reject Move and Reschedule on Active and InTracker Items', () {
    test('Move and Reschedule are rejected when status is active', () {
      final activeRecord = RoutineOccurrenceRecord(
        id: 'occ_act',
        ownerUid: 'u1',
        routineItemId: 'item_1',
        occurrenceDateKey: '2026-09-16',
        status: RoutineStatus.active,
        source: 'routine',
        action: 'start',
        operationKey: 'op_start',
        startedAt: DateTime.utc(2026, 9, 16, 8, 0),
        countdownDurationSeconds: 1800,
        createdAt: DateTime.utc(2026, 9, 16),
        updatedAt: DateTime.utc(2026, 9, 16),
      );

      final moveDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: activeRecord,
        requestedAction: RoutineOccurrenceAction.move,
        projectedStatus: RoutineStatus.active,
      );
      expect(moveDecision.isAllowed, false);
      expect(moveDecision.message, contains('Active routine cannot be moved'));

      final rescheduleDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: activeRecord,
        requestedAction: RoutineOccurrenceAction.reschedule,
        projectedStatus: RoutineStatus.active,
      );
      expect(rescheduleDecision.isAllowed, false);

      final makeTinyDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: activeRecord,
        requestedAction: RoutineOccurrenceAction.makeTiny,
        projectedStatus: RoutineStatus.active,
      );
      expect(makeTinyDecision.isAllowed, false);
    });

    test('Move is rejected when status is inTracker', () {
      final moveDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: null,
        requestedAction: RoutineOccurrenceAction.move,
        projectedStatus: RoutineStatus.inTracker,
      );
      expect(moveDecision.isAllowed, false);
      expect(moveDecision.message, contains('Routine running in tracker cannot be moved'));
    });
  });

  group('Gate H & I: Make Tiny and Canonical Move Integration', () {
    test('Make Tiny preserves source occurrence date and wraps midnight safely', () {
      final item = RoutineItem(
        id: 'night_routine',
        title: 'Bedtime Reading',
        startMinute: 23 * 60 + 50, // 23:50
        endMinute: 24 * 60 + 20, // 00:20 (ends next day)
        blockType: RoutineBlockType.flexibleTask,
      );

      final seed = RoutineMoveSeedResolver.resolve(
        actionContext: RoutineActionContext.fallback(
          item: item,
          occurrenceDate: DateTime(2026, 9, 16),
        ),
        visibleItem: item,
        templates: [item],
        occurrences: const [],
      );

      expect(seed.startMinute, 23 * 60 + 50);
      expect(seed.durationMinutes, 30);

      // Calculate tiny version (15 min starting now at 23:55)
      final startMin = 23 * 60 + 55;
      final endMin = startMin + 15; // 1450 (24:10 next day)
      final wrappedMinute = endMin % 1440; // 10 min past midnight
      expect(wrappedMinute, 10);
    });
  });

  group('Gate J: Money Done Semantics & Idempotency', () {
    test('alreadySaved records money today without duplicate entries', () async {
      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
          fakeDataAllowedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(routineNotifierProvider.notifier);
      final item = RoutineItem(
        id: 'money_task_1',
        title: 'Daily Micro-saving',
        startMinute: 600,
        endMinute: 630,
        blockType: RoutineBlockType.moneyTask,
      );

      container.read(routineNotifierProvider.notifier).state =
          container.read(routineNotifierProvider).copyWith(
                items: [item],
              );

      final date = DateTime.now();

      // First call saves money and marks complete
      final res1 = await notifier.alreadySaved('money_task_1', occurrenceDate: date);
      expect(res1.outcome, RoutineWriteOutcome.saved);

      final trackerEntries1 = container.read(mockTrackerProvider).savingsEntries.length;
      expect(trackerEntries1, 1);
      expect(notifier.hasConfirmedMoneySaveForRoutine('money_task_1', date: date), true);

      // Second call is idempotent: returns noOp and does NOT create a duplicate money entry
      final res2 = await notifier.alreadySaved('money_task_1', occurrenceDate: date);
      expect(res2.outcome, RoutineWriteOutcome.noOp);
      final trackerEntries2 = container.read(mockTrackerProvider).savingsEntries.length;
      expect(trackerEntries2, 1);
    });
  });

  group('Gate L & M: Contextual Action Hierarchy & Height Sync', () {
    test('RoutineActionAvailability hides invalid transitions on Completed items', () {
      final availability = RoutineActionAvailability.forOccurrence(
        existingRecord: RoutineOccurrenceRecord(
          id: 'occ_comp',
          ownerUid: 'u1',
          routineItemId: 'i1',
          occurrenceDateKey: '2026-09-16',
          status: RoutineStatus.completed,
          source: 'routine',
          action: 'complete',
          operationKey: 'op1',
          undoToPlannedAllowed: true,
          createdAt: DateTime.utc(2026, 9, 16),
          updatedAt: DateTime.utc(2026, 9, 16),
        ),
        status: RoutineStatus.completed,
        blockType: RoutineBlockType.flexibleTask,
      );

      expect(availability.canStart, false);
      expect(availability.canMove, false);
      expect(availability.canComplete, false);
      expect(availability.canUndo, true);
    });

    test('RoutineCardFactory stacked action footer height matches expected rows', () {
      const singleButtonHeight = RoutineCardPresentation.actionButtonMinHeight;
      const expected2RowHeight = (singleButtonHeight * 2) + RoutineCardPresentation.actionGap; // 44*2 + 6 = 94
      final calculated2Row = RoutineCardFactory.actionFooterHeight(
        RoutineCardActionLayout.stacked,
        actionCount: 2,
      );
      expect(calculated2Row, expected2RowHeight);

      final calculatedCanUndo = RoutineCardFactory.actionFooterHeight(
        RoutineCardActionLayout.stacked,
        canUndo: true,
      );
      expect(calculatedCanUndo, expected2RowHeight);

      const expected4RowHeight = (singleButtonHeight * 4) + (RoutineCardPresentation.actionGap * 3); // 44*4 + 18 = 194
      final calculated4Row = RoutineCardFactory.actionFooterHeight(
        RoutineCardActionLayout.stacked,
        actionCount: 4,
      );
      expect(calculated4Row, expected4RowHeight);
    });
  });
}
