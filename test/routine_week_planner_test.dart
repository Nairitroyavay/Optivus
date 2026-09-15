import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/models/routine_week_day_summary.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/features/routine/sheets/week_planner_sheet.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/routine/services/routine_day_availability.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

RoutineItem _item({
  required String id,
  required String title,
  required int startMinute,
  required int endMinute,
  RoutineBlockType blockType = RoutineBlockType.flexibleTask,
  List<int> repeatDays = const [],
  DateTime? date,
  bool crossesMidnight = false,
  bool endsNextDay = false,
  RoutineStatus status = RoutineStatus.planned,
  RoutineSource source = RoutineSource.manual,
  String? baseTimelineSection,
  RoutineCategory category = RoutineCategory.fixed,
}) {
  return RoutineItem(
    id: id,
    userId: 'user_week_test',
    title: title,
    startMinute: startMinute,
    endMinute: endMinute,
    blockType: blockType,
    repeatDays: repeatDays,
    repeatRule: repeatDays.isNotEmpty ? 'weekly' : 'once',
    date: date,
    crossesMidnight: crossesMidnight,
    endsNextDay: endsNextDay,
    status: status,
    source: source,
    baseTimelineSection: baseTimelineSection,
    category: category,
  );
}

RoutineOccurrenceRecord _occurrence({
  required String id,
  required String routineItemId,
  required String occurrenceDateKey,
  required RoutineStatus status,
  String? movedToDateKey,
  int? movedStartMinute,
  int? movedEndMinute,
}) {
  return RoutineOccurrenceRecord(
    id: id,
    ownerUid: 'user_week_test',
    routineItemId: routineItemId,
    occurrenceDateKey: occurrenceDateKey,
    status: status,
    source: 'routine',
    action: 'move',
    operationKey: 'op_$id',
    movedToDateKey: movedToDateKey,
    movedStartMinute: movedStartMinute,
    movedEndMinute: movedEndMinute,
    createdAt: DateTime(2026, 9, 14),
    updatedAt: DateTime(2026, 9, 14),
  );
}

class _WeekTestNotifier extends RoutineNotifier {
  bool loadForOwnerCalled = false;

  _WeekTestNotifier(
    Ref ref, {
    List<RoutineItem> initialItems = const [],
    List<RoutineOccurrenceRecord> initialOccurrences = const [],
    DateTime? initialSelectedDay,
    bool loading = false,
    String? error,
  }) : super(
         FakeRoutineRepository(),
         FakeRoutineHistoryRepository(),
         FakeRoutineTransactionRepository(),
         ref,
       ) {
    state = state.copyWith(
      items: initialItems,
      occurrences: initialOccurrences,
      selectedDay: initialSelectedDay ?? DateTime(2026, 9, 14), // Monday
      loading: loading,
      error: error,
    );
  }

  @override
  Future<void> loadForOwner(String uid, {bool force = false}) async {
    loadForOwnerCalled = true;
    state = state.copyWith(loading: false, error: null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoutineWeekDaySummary Unit Logic', () {
    test('1. Empty day produces canonical 17h free time, 0 counts', () {
      final summary = RoutineWeekDaySummary.fromEntries(
        day: DateTime(2026, 9, 14),
        entries: const [],
      );

      expect(summary.entries, isEmpty);
      expect(summary.routineTotal, 0);
      expect(summary.completed, 0);
      expect(summary.progress, 0.0);
      expect(summary.freeMinutes, 1020);
      expect(summary.freeTimeFormatted, '17h free');
      expect(summary.baseBlockCount, 0);
      expect(summary.flexibleTaskCount, 0);
      expect(summary.hasRoutines, isFalse);
      expect(summary.continuationCount, 0);
    });

    test(
      '2. All routine occurrences (hard, soft, flexible) are counted in routineTotal & completed count',
      () {
        final hardBlock1 = RoutineDayEntry(
          item: _item(
            id: 'hb1',
            title: 'Morning Class',
            startMinute: 9 * 60,
            endMinute: 11 * 60,
            blockType: RoutineBlockType.hardBlock,
            source: RoutineSource.baseTimeline,
            baseTimelineSection: 'classes',
            status: RoutineStatus.completed,
          ),
          instanceId: 'hb1',
          templateId: 'hb1',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.scheduled,
        );

        final flexTask1 = RoutineDayEntry(
          item: _item(
            id: 'ft1',
            title: 'Coding Exercise',
            startMinute: 14 * 60,
            endMinute: 15 * 60,
            blockType: RoutineBlockType.flexibleTask,
            status: RoutineStatus.completed,
          ),
          instanceId: 'ft1',
          templateId: 'ft1',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.scheduled,
        );

        final flexTask2 = RoutineDayEntry(
          item: _item(
            id: 'ft2',
            title: 'Review PR',
            startMinute: 16 * 60,
            endMinute: 17 * 60,
            blockType: RoutineBlockType.flexibleTask,
            status: RoutineStatus.planned,
          ),
          instanceId: 'ft2',
          templateId: 'ft2',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.scheduled,
        );

        final summary = RoutineWeekDaySummary.fromEntries(
          day: DateTime(2026, 9, 14),
          entries: [hardBlock1, flexTask1, flexTask2],
        );

        expect(summary.entries.length, 3);
        expect(summary.baseBlockCount, 1);
        expect(summary.flexibleTaskCount, 2);
        // All non-continuation routines are counted in routineTotal
        expect(summary.routineTotal, 3);
        // hardBlock1 is completed, flexTask1 is completed -> 2 of 3
        expect(summary.completed, 2);
        expect(summary.progress, 2 / 3);
        // Occupied: 2h (hardBlock) + 1h (flex1) + 1h (flex2) = 4h (240m)
        expect(summary.availability.occupiedMinutes, 240);
        expect(summary.freeMinutes, 1020 - 240); // 780m = 13h
        expect(summary.freeTimeFormatted, '13h free');
      },
    );

    test(
      '3. Continuation segments do NOT inflate task counts, but DO occupy time',
      () {
        final continuation = RoutineDayEntry(
          item: _item(
            id: 'sleep',
            title: 'Sleep (continuation)',
            startMinute: 0,
            endMinute: 7 * 60,
            blockType: RoutineBlockType.hardBlock,
          ),
          instanceId: 'sleep_cont',
          templateId: 'sleep',
          occurrenceDateKey: '2026-09-13',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.continuation,
        );

        final summary = RoutineWeekDaySummary.fromEntries(
          day: DateTime(2026, 9, 14),
          entries: [continuation],
        );

        // Continuation segment does NOT increment routine counts
        expect(summary.baseBlockCount, 0);
        expect(summary.flexibleTaskCount, 0);
        expect(summary.routineTotal, 0);
        expect(summary.continuationCount, 1);
        expect(summary.hasRoutines, isFalse);

        // But inside 06:00-23:00 window, 06:00-07:00 (60 mins) is occupied
        expect(summary.availability.occupiedMinutes, 60);
        expect(summary.freeMinutes, 1020 - 60); // 960m = 16h
        expect(summary.freeTimeFormatted, '16h free');
      },
    );

    test(
      '4. Overlapping blocks union occupied time in summary availability',
      () {
        final blockA = RoutineDayEntry(
          item: _item(
            id: 'b1',
            title: 'Block A',
            startMinute: 10 * 60,
            endMinute: 11 * 60 + 30, // 10:00 - 11:30 (90m)
            blockType: RoutineBlockType.hardBlock,
          ),
          instanceId: 'b1',
          templateId: 'b1',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.scheduled,
        );

        final blockB = RoutineDayEntry(
          item: _item(
            id: 'b2',
            title: 'Block B',
            startMinute: 11 * 60,
            endMinute: 12 * 60, // 11:00 - 12:00 (60m, overlaps 11:00-11:30)
            blockType: RoutineBlockType.hardBlock,
          ),
          instanceId: 'b2',
          templateId: 'b2',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.scheduled,
        );

        final summary = RoutineWeekDaySummary.fromEntries(
          day: DateTime(2026, 9, 14),
          entries: [blockA, blockB],
        );

        // Union of 10:00-11:30 and 11:00-12:00 is 10:00-12:00 = 120m
        expect(summary.availability.occupiedMinutes, 120);
        expect(summary.freeMinutes, 1020 - 120); // 900m = 15h
        expect(summary.freeTimeFormatted, '15h free');
      },
    );

    test(
      '5. Occurrence projection moves tasks correctly across days in summaries',
      () {
        final template = _item(
          id: 'task_repeat',
          title: 'Weekly Sync',
          startMinute: 10 * 60,
          endMinute: 11 * 60,
          repeatDays: const [1], // Monday
        );

        final occurrence = _occurrence(
          id: 'occ_move_1',
          routineItemId: 'task_repeat',
          occurrenceDateKey: '2026-09-14', // Monday
          movedToDateKey: '2026-09-15', // Tuesday
          status: RoutineStatus.moved,
        );

        // Monday projection excludes moved-away occurrence
        final mondayEntries = RoutineOccurrenceProjector.entriesForDay(
          [template],
          [occurrence],
          DateTime(2026, 9, 14),
        );
        final mondaySummary = RoutineWeekDaySummary.fromEntries(
          day: DateTime(2026, 9, 14),
          entries: mondayEntries,
        );

        expect(mondaySummary.entries, isEmpty);
        expect(mondaySummary.freeMinutes, 1020);

        // Tuesday projection includes moved-in occurrence
        final tuesdayEntries = RoutineOccurrenceProjector.entriesForDay(
          [template],
          [occurrence],
          DateTime(2026, 9, 15),
        );
        final tuesdaySummary = RoutineWeekDaySummary.fromEntries(
          day: DateTime(2026, 9, 15),
          entries: tuesdayEntries,
        );

        expect(tuesdaySummary.entries.length, 1);
        expect(tuesdaySummary.flexibleTaskCount, 1);
        expect(tuesdaySummary.routineTotal, 1);
        expect(tuesdaySummary.freeMinutes, 1020 - 60);
        expect(tuesdaySummary.freeTimeFormatted, '16h free');
      },
    );

    test('6. Moved time overrides template times in summary availability', () {
      final template = _item(
        id: 'task_orig',
        title: 'Project Review',
        startMinute: 9 * 60, // 09:00
        endMinute: 10 * 60, // 10:00 (60m)
        repeatDays: const [1], // Monday
      );

      final occurrence = _occurrence(
        id: 'occ_move_time',
        routineItemId: 'task_orig',
        occurrenceDateKey: '2026-09-14',
        movedToDateKey: '2026-09-14', // same day
        movedStartMinute: 14 * 60, // moved to 14:00
        movedEndMinute: 16 * 60, // moved to 16:00 (120m)
        status: RoutineStatus.moved,
      );

      final entries = RoutineOccurrenceProjector.entriesForDay(
        [template],
        [occurrence],
        DateTime(2026, 9, 14),
      );
      final summary = RoutineWeekDaySummary.fromEntries(
        day: DateTime(2026, 9, 14),
        entries: entries,
      );

      expect(summary.availability.occupiedMinutes, 120);
      expect(summary.availability.occupiedIntervals, [
        const RoutineTimeInterval(startMinute: 840, endMinute: 960),
      ]);
      expect(summary.freeMinutes, 1020 - 120);
      expect(summary.freeTimeFormatted, '15h free');
    });

    test(
      '7. Overnight routine crosses midnight, occupying time across both days in summary',
      () {
        final sleepItem = _item(
          id: 'sleep_1',
          title: 'Sleep',
          startMinute: 22 * 60, // 22:00
          endMinute: 7 * 60, // 07:00 next day
          crossesMidnight: true,
          repeatDays: const [1], // Monday night into Tuesday morning
          blockType: RoutineBlockType.hardBlock,
          source: RoutineSource.baseTimeline,
          baseTimelineSection: 'sleep',
        );

        // Day 1: Monday (2026-09-14)
        final mondayEntries = RoutineOccurrenceProjector.entriesForDay(
          [sleepItem],
          [],
          DateTime(2026, 9, 14),
        );
        final mondaySummary = RoutineWeekDaySummary.fromEntries(
          day: DateTime(2026, 9, 14),
          entries: mondayEntries,
        );

        // Window 06:00-23:00 (360-1380). 22:00-23:00 is 60m occupied.
        expect(mondaySummary.availability.occupiedMinutes, 60);
        expect(mondaySummary.baseBlockCount, 1);

        // Day 2: Tuesday (2026-09-15)
        final tuesdayEntries = RoutineOccurrenceProjector.entriesForDay(
          [sleepItem],
          [],
          DateTime(2026, 9, 15),
        );
        final tuesdaySummary = RoutineWeekDaySummary.fromEntries(
          day: DateTime(2026, 9, 15),
          entries: tuesdayEntries,
        );

        // Continuation segment 00:00-07:00. Clipped to window 06:00-07:00 (60m).
        expect(tuesdaySummary.availability.occupiedMinutes, 60);
        // Continuation segment does NOT increment baseBlockCount!
        expect(tuesdaySummary.baseBlockCount, 0);
      },
    );

    test(
      '8. Skipped and Missed counts are independently tracked in summary',
      () {
        final itemSkipped = RoutineDayEntry(
          item: _item(
            id: 'sk1',
            title: 'Skipped Habit',
            startMinute: 600,
            endMinute: 630,
            status: RoutineStatus.skipped,
          ),
          instanceId: 'sk1',
          templateId: 'sk1',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.scheduled,
        );
        final itemMissed = RoutineDayEntry(
          item: _item(
            id: 'ms1',
            title: 'Missed Habit',
            startMinute: 700,
            endMinute: 730,
            status: RoutineStatus.missed,
          ),
          instanceId: 'ms1',
          templateId: 'ms1',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.scheduled,
        );

        final summary = RoutineWeekDaySummary.fromEntries(
          day: DateTime(2026, 9, 14),
          entries: [itemSkipped, itemMissed],
        );

        expect(summary.routineTotal, 2);
        expect(summary.completed, 0);
        expect(summary.skipped, 1);
        expect(summary.missed, 1);
      },
    );

    test(
      '9. All six block types count in routineTotal and derive completion metrics',
      () {
        final entries = [
          RoutineDayEntry(
            item: _item(
              id: 'b_hard',
              title: 'Class',
              startMinute: 540,
              endMinute: 600,
              blockType: RoutineBlockType.hardBlock,
              source: RoutineSource.baseTimeline,
              baseTimelineSection: 'classes',
              status: RoutineStatus.completed,
            ),
            instanceId: 'i_hard',
            templateId: 't_hard',
            occurrenceDateKey: '2026-09-14',
            displayDateKey: '2026-09-14',
            kind: RoutineDayEntryKind.scheduled,
          ),
          RoutineDayEntry(
            item: _item(
              id: 'b_soft',
              title: 'Lunch',
              startMinute: 720,
              endMinute: 760,
              blockType: RoutineBlockType.softBlock,
              source: RoutineSource.baseTimeline,
              baseTimelineSection: 'eating',
              status: RoutineStatus.planned,
            ),
            instanceId: 'i_soft',
            templateId: 't_soft',
            occurrenceDateKey: '2026-09-14',
            displayDateKey: '2026-09-14',
            kind: RoutineDayEntryKind.scheduled,
          ),
          RoutineDayEntry(
            item: _item(
              id: 'b_flex',
              title: 'Exercise',
              startMinute: 800,
              endMinute: 860,
              blockType: RoutineBlockType.flexibleTask,
              status: RoutineStatus.completed,
            ),
            instanceId: 'i_flex',
            templateId: 't_flex',
            occurrenceDateKey: '2026-09-14',
            displayDateKey: '2026-09-14',
            kind: RoutineDayEntryKind.scheduled,
          ),
          RoutineDayEntry(
            item: _item(
              id: 'b_track',
              title: 'Water Log',
              startMinute: 900,
              endMinute: 915,
              blockType: RoutineBlockType.trackerTask,
              status: RoutineStatus.planned,
            ),
            instanceId: 'i_track',
            templateId: 't_track',
            occurrenceDateKey: '2026-09-14',
            displayDateKey: '2026-09-14',
            kind: RoutineDayEntryKind.scheduled,
          ),
          RoutineDayEntry(
            item: _item(
              id: 'b_check',
              title: 'Reflection',
              startMinute: 1000,
              endMinute: 1015,
              blockType: RoutineBlockType.checkIn,
              status: RoutineStatus.missed,
            ),
            instanceId: 'i_check',
            templateId: 't_check',
            occurrenceDateKey: '2026-09-14',
            displayDateKey: '2026-09-14',
            kind: RoutineDayEntryKind.scheduled,
          ),
          RoutineDayEntry(
            item: _item(
              id: 'b_money',
              title: 'Budget',
              startMinute: 1100,
              endMinute: 1120,
              blockType: RoutineBlockType.moneyTask,
              status: RoutineStatus.skipped,
            ),
            instanceId: 'i_money',
            templateId: 't_money',
            occurrenceDateKey: '2026-09-14',
            displayDateKey: '2026-09-14',
            kind: RoutineDayEntryKind.scheduled,
          ),
        ];

        final summary = RoutineWeekDaySummary.fromEntries(
          day: DateTime(2026, 9, 14),
          entries: entries,
        );

        expect(summary.routineTotal, 6);
        expect(summary.completed, 2);
        expect(summary.missed, 1);
        expect(summary.skipped, 1);
        expect(summary.progress, 2 / 6);
        expect(summary.hasRoutines, isTrue);
      },
    );

    test(
      '10. Native and moved-in sibling occurrences from same template count separately',
      () {
        final template = _item(
          id: 'tpl_repeat',
          title: 'Study Session',
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [1, 2],
        );

        final nativeEntry = RoutineDayEntry(
          item: template,
          instanceId: 'inst_native',
          templateId: 'tpl_repeat',
          occurrenceDateKey: '2026-09-15',
          displayDateKey: '2026-09-15',
          kind: RoutineDayEntryKind.scheduled,
        );

        final movedInEntry = RoutineDayEntry(
          item: template,
          instanceId: 'inst_moved_in',
          templateId: 'tpl_repeat',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-15',
          kind: RoutineDayEntryKind.movedIn,
        );

        final summary = RoutineWeekDaySummary.fromEntries(
          day: DateTime(2026, 9, 15),
          entries: [nativeEntry, movedInEntry],
        );

        expect(summary.routineTotal, 2);
        expect(summary.hasRoutines, isTrue);
      },
    );
  });

  group('WeekPlannerSheet Widget Tests', () {
    testWidgets('Renders header, subtitle, navigation, and 7 day cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _WeekTestNotifier(
                ref,
                initialSelectedDay: DateTime(2026, 9, 14),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: WeekPlannerSheet())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Week Planner'), findsOneWidget);
      expect(
        find.text('Actual schedule • Free time uses 6 AM–11 PM'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Top day cards are immediately visible
      expect(find.textContaining('MON'), findsOneWidget);
      expect(find.textContaining('TUE'), findsOneWidget);
      expect(find.textContaining('WED'), findsOneWidget);

      // Scroll to verify the rest of the week (THU through SUN)
      await tester.scrollUntilVisible(
        find.textContaining('SUN'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('SUN'), findsOneWidget);
    });

    testWidgets(
      'Week navigation changes visible week without mutating selectedDay',
      (tester) async {
        late WidgetRef capturedRef;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineNotifierProvider.overrideWith(
                (ref) => _WeekTestNotifier(
                  ref,
                  initialSelectedDay: DateTime(2026, 9, 14), // Sep 14, 2026
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, child) {
                    capturedRef = ref;
                    return const WeekPlannerSheet();
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially Sep 14 - Sep 20
        expect(find.textContaining('Sep 14'), findsWidgets);

        // State selectedDay is Sep 14
        expect(
          capturedRef.read(routineNotifierProvider).selectedDay,
          DateTime(2026, 9, 14),
        );

        // Tap next week (chevron right)
        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pumpAndSettle();

        // "This week" shortcut appears now that we are viewing a different week
        expect(find.text('This week'), findsOneWidget);

        // Header now displays Sep 21 - Sep 27
        expect(find.textContaining('Sep 21'), findsWidgets);

        // Selected day in state is STILL Sep 14 (not mutated!)
        expect(
          capturedRef.read(routineNotifierProvider).selectedDay,
          DateTime(2026, 9, 14),
        );

        // Tap previous week (chevron left)
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pumpAndSettle();

        expect(find.textContaining('Sep 14'), findsWidgets);

        // Tap previous week again
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pumpAndSettle();

        expect(find.textContaining('Sep 7'), findsWidgets);

        // Tap "This week" to reset
        await tester.tap(find.text('This week'));
        await tester.pumpAndSettle();

        // Today's week is displayed
        final now = DateTime.now();
        final expectedMonday = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: (now.weekday - 1) % 7));
        expect(
          find.textContaining(expectedMonday.day.toString()),
          findsWidgets,
        );
      },
    );

    testWidgets('Tapping a day card updates selectedDay and pops sheet', (
      tester,
    ) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _WeekTestNotifier(
                ref,
                initialSelectedDay: DateTime(2026, 9, 14),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  capturedRef = ref;
                  return ElevatedButton(
                    onPressed: () => showRoutineWeekPlannerSheet(context, ref),
                    child: const Text('Open Planner'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Planner'));
      await tester.pumpAndSettle();

      expect(find.text('Week Planner'), findsOneWidget);

      // Tap Tuesday card
      await tester.tap(find.textContaining('TUE'));
      await tester.pumpAndSettle();

      // Sheet should have popped
      expect(find.text('Week Planner'), findsNothing);

      // selectedDay should now be Tuesday (2026-09-15)
      expect(
        capturedRef.read(routineNotifierProvider).selectedDay,
        DateTime(2026, 9, 15),
      );
    });

    testWidgets('Displays base, flexible, free time chips and progress bar', (
      tester,
    ) async {
      final hardBlock = _item(
        id: 'hb1',
        title: 'Deep Work',
        startMinute: 9 * 60,
        endMinute: 12 * 60,
        repeatDays: const [1], // Monday
        blockType: RoutineBlockType.hardBlock,
        source: RoutineSource.baseTimeline,
        baseTimelineSection: 'job_work_business',
      );
      final flexTask = _item(
        id: 'ft1',
        title: 'Daily Exercise',
        startMinute: 17 * 60,
        endMinute: 18 * 60,
        repeatDays: const [1], // Monday
        blockType: RoutineBlockType.flexibleTask,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _WeekTestNotifier(
                ref,
                initialItems: [hardBlock, flexTask],
                initialSelectedDay: DateTime(2026, 9, 14),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: WeekPlannerSheet())),
        ),
      );
      await tester.pumpAndSettle();

      // Monday has 1 base block, 1 flexible task, and 4h occupied -> 13h free
      expect(find.text('1 base'), findsOneWidget);
      expect(find.text('1 flexible'), findsOneWidget);
      expect(find.text('13h free'), findsOneWidget);

      // Monday has 2 routines (0 completed) -> shows 0/2 done (0%)
      expect(find.text('0/2 done'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Other days (e.g. Tuesday) have no routines -> displays 'No routines'
      expect(find.text('No routines'), findsWidgets);
      expect(find.text('17h free'), findsWidgets);
    });

    testWidgets(
      'Base-only day with 3 occurrences produces 1/3 done and 3 base chips in UI',
      (tester) async {
        final class1 = _item(
          id: 'c1',
          title: 'Physics',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          source: RoutineSource.baseTimeline,
          baseTimelineSection: 'classes',
          status: RoutineStatus.completed,
        );
        final class2 = _item(
          id: 'c2',
          title: 'Calculus',
          startMinute: 11 * 60,
          endMinute: 12 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          source: RoutineSource.baseTimeline,
          baseTimelineSection: 'classes',
          status: RoutineStatus.planned,
        );
        final work = _item(
          id: 'w1',
          title: 'Job Shift',
          startMinute: 14 * 60,
          endMinute: 18 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          source: RoutineSource.baseTimeline,
          baseTimelineSection: 'job_work_business',
          status: RoutineStatus.planned,
        );

        final occCompleted = _occurrence(
          id: 'occ_c1',
          routineItemId: 'c1',
          occurrenceDateKey: '2026-09-14',
          status: RoutineStatus.completed,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineNotifierProvider.overrideWith(
                (ref) => _WeekTestNotifier(
                  ref,
                  initialItems: [class1, class2, work],
                  initialOccurrences: [occCompleted],
                  initialSelectedDay: DateTime(2026, 9, 14),
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: WeekPlannerSheet())),
          ),
        );
        await tester.pumpAndSettle();

        // Must display 1/3 done and 3 base on Monday
        expect(find.text('1/3 done'), findsOneWidget);
        expect(find.text('33%'), findsOneWidget);
        expect(find.text('3 base'), findsOneWidget);
        // Must NOT display "No tasks"
        expect(find.text('No tasks'), findsNothing);
      },
    );

    testWidgets(
      'Continuation-only day displays No new routines and continuing chip',
      (tester) async {
        final sleepTemplate = _item(
          id: 'sleep_1',
          title: 'Sleep',
          startMinute: 22 * 60,
          endMinute: 7 * 60,
          repeatDays: const [1], // Monday night into Tuesday morning
          crossesMidnight: true,
          endsNextDay: true,
          blockType: RoutineBlockType.hardBlock,
          source: RoutineSource.baseTimeline,
          baseTimelineSection: 'sleep',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineNotifierProvider.overrideWith(
                (ref) => _WeekTestNotifier(
                  ref,
                  initialItems: [sleepTemplate],
                  initialSelectedDay: DateTime(2026, 9, 15), // Tuesday
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: WeekPlannerSheet())),
          ),
        );
        await tester.pumpAndSettle();

        // Tuesday has no starting routines, only continuation from Monday night
        expect(find.text('No new routines'), findsOneWidget);
        expect(find.text('1 continuing'), findsOneWidget);
      },
    );

    testWidgets('No RenderFlex overflow on narrow 320 px screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _WeekTestNotifier(
                ref,
                initialSelectedDay: DateTime(2026, 9, 14),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: WeekPlannerSheet())),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Week Planner'), findsOneWidget);
    });

    testWidgets('Zero conflict UX: No conflict chips or warnings anywhere', (
      tester,
    ) async {
      // Create two overlapping hard blocks
      final item1 = _item(
        id: 'i1',
        title: 'Meeting 1',
        startMinute: 600,
        endMinute: 720,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
      );
      final item2 = _item(
        id: 'i2',
        title: 'Meeting 2',
        startMinute: 660,
        endMinute: 780,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _WeekTestNotifier(
                ref,
                initialItems: [item1, item2],
                initialSelectedDay: DateTime(2026, 9, 14),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: WeekPlannerSheet())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('conflict'), findsNothing);
      expect(find.textContaining('Conflict'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets(
      'Hides 0 base and 0 flexible chips, displays skipped and missed only when positive',
      (tester) async {
        // Monday has 1 flexible, 0 base, 1 skipped, 1 missed
        final flexItem = _item(
          id: 'f1',
          title: 'Exercise',
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [1], // Monday
          blockType: RoutineBlockType.flexibleTask,
        );
        final occSkipped = _occurrence(
          id: 'occ_sk',
          routineItemId: 'f1',
          occurrenceDateKey: '2026-09-14',
          status: RoutineStatus.skipped,
        );

        final missedItem = _item(
          id: 'f2',
          title: 'Missed Task',
          startMinute: 700,
          endMinute: 760,
          repeatDays: const [1], // Monday
          blockType: RoutineBlockType.flexibleTask,
        );
        final occMissed = _occurrence(
          id: 'occ_ms',
          routineItemId: 'f2',
          occurrenceDateKey: '2026-09-14',
          status: RoutineStatus.missed,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineNotifierProvider.overrideWith(
                (ref) => _WeekTestNotifier(
                  ref,
                  initialItems: [flexItem, missedItem],
                  initialOccurrences: [occSkipped, occMissed],
                  initialSelectedDay: DateTime(2026, 9, 14),
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: WeekPlannerSheet())),
          ),
        );
        await tester.pumpAndSettle();

        // Zero-count chips MUST be hidden
        expect(find.textContaining('0 base'), findsNothing);
        expect(find.textContaining('0 flexible'), findsNothing);

        // Positive chips MUST be shown
        expect(find.text('2 flexible'), findsOneWidget);
        expect(find.text('1 skipped'), findsOneWidget);
        expect(find.text('1 missed'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders loading spinner when loading is true and items is empty',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineNotifierProvider.overrideWith(
                (ref) => _WeekTestNotifier(
                  ref,
                  initialItems: const [],
                  loading: true,
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: WeekPlannerSheet())),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Day cards should not be shown during initial load
        expect(find.textContaining('MON'), findsNothing);
      },
    );

    testWidgets(
      'Renders error card with retry button when error is set and items is empty',
      (tester) async {
        late _WeekTestNotifier testNotifier;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) =>
                    UserProfileNotifier()
                      ..updateProfile(UserProfile.empty(uid: 'test_user_123')),
              ),
              routineNotifierProvider.overrideWith((ref) {
                testNotifier = _WeekTestNotifier(
                  ref,
                  initialItems: const [],
                  error: 'Network connection failed',
                );
                return testNotifier;
              }),
            ],
            child: const MaterialApp(home: Scaffold(body: WeekPlannerSheet())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Couldn't load your routine"), findsOneWidget);
        expect(find.text("Your schedule couldn't be loaded"), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Tapping retry triggers loadForOwner
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(testNotifier.loadForOwnerCalled, isTrue);
      },
    );

    testWidgets(
      'Renders true-empty banner when items is empty, not loading, and error is null',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineNotifierProvider.overrideWith(
                (ref) => _WeekTestNotifier(
                  ref,
                  initialItems: const [],
                  loading: false,
                  error: null,
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: WeekPlannerSheet())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No routines scheduled yet'), findsOneWidget);
        // Days are still visible to browse free time
        expect(find.textContaining('MON'), findsOneWidget);
      },
    );
  });
}
