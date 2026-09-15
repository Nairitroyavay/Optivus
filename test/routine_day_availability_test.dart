import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/services/routine_day_availability.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/features/routine/sheets/ai_assistant_sheet.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';

RoutineItem _item({
  required String id,
  required String title,
  required int startMinute,
  required int endMinute,
  RoutineBlockType blockType = RoutineBlockType.flexibleTask,
  List<int> repeatDays = const [],
  bool isContinuation = false,
  bool crossesMidnight = false,
}) {
  return RoutineItem(
    id: id,
    title: title,
    startMinute: startMinute,
    endMinute: endMinute,
    blockType: blockType,
    repeatDays: repeatDays,
    isContinuation: isContinuation,
    crossesMidnight: crossesMidnight,
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
    ownerUid: 'user_test',
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

void main() {
  group('RoutineDayAvailability Canonical Engine', () {
    test('A. Empty day reports canonical 17h (1020m) free time', () {
      final availability = RoutineDayAvailability.computeFromEntries([]);

      expect(availability.windowStartMinute, 360);
      expect(availability.windowEndMinute, 1380);
      expect(availability.occupiedMinutes, 0);
      expect(availability.freeMinutes, 1020);
      expect(availability.occupiedIntervals, isEmpty);
      expect(availability.freeIntervals.length, 1);
      expect(
        availability.freeIntervals.first,
        const RoutineTimeInterval(startMinute: 360, endMinute: 1380),
      );
      expect(
        availability.largestFreeInterval,
        const RoutineTimeInterval(startMinute: 360, endMinute: 1380),
      );
    });

    test('B. Non-overlapping intervals sum up accurately', () {
      final entry1 = RoutineDayEntry(
        item: _item(
          id: 'i1',
          title: 'Morning Study',
          startMinute: 8 * 60, // 480
          endMinute: 9 * 60, // 540
        ),
        instanceId: 's:i1:2026-09-14',
        templateId: 'i1',
        occurrenceDateKey: '2026-09-14',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.scheduled,
      );
      final entry2 = RoutineDayEntry(
        item: _item(
          id: 'i2',
          title: 'Coffee Break',
          startMinute: 10 * 60, // 600
          endMinute: 11 * 60, // 660
        ),
        instanceId: 's:i2:2026-09-14',
        templateId: 'i2',
        occurrenceDateKey: '2026-09-14',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.scheduled,
      );

      final availability = RoutineDayAvailability.computeFromEntries([
        entry1,
        entry2,
      ]);

      expect(availability.occupiedMinutes, 120);
      expect(availability.freeMinutes, 1020 - 120);
      expect(availability.occupiedIntervals, [
        const RoutineTimeInterval(startMinute: 480, endMinute: 540),
        const RoutineTimeInterval(startMinute: 600, endMinute: 660),
      ]);
      expect(availability.freeIntervals, [
        const RoutineTimeInterval(startMinute: 360, endMinute: 480), // 120m
        const RoutineTimeInterval(startMinute: 540, endMinute: 600), // 60m
        const RoutineTimeInterval(startMinute: 660, endMinute: 1380), // 720m
      ]);
      expect(
        availability.largestFreeInterval,
        const RoutineTimeInterval(startMinute: 660, endMinute: 1380),
      );
    });

    test('C. Overlap union does not double-count overlapping time', () {
      // 10:00–12:00 (600–720) and 11:00–13:00 (660–780)
      final entry1 = RoutineDayEntry(
        item: _item(
          id: 'i1',
          title: 'Class A',
          startMinute: 10 * 60,
          endMinute: 12 * 60,
          blockType: RoutineBlockType.hardBlock,
        ),
        instanceId: 's:i1:2026-09-14',
        templateId: 'i1',
        occurrenceDateKey: '2026-09-14',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.scheduled,
      );
      final entry2 = RoutineDayEntry(
        item: _item(
          id: 'i2',
          title: 'Meeting B',
          startMinute: 11 * 60,
          endMinute: 13 * 60,
        ),
        instanceId: 's:i2:2026-09-14',
        templateId: 'i2',
        occurrenceDateKey: '2026-09-14',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.scheduled,
      );

      final availability = RoutineDayAvailability.computeFromEntries([
        entry1,
        entry2,
      ]);

      // Busy must equal 180 minutes (10:00–13:00), NOT 240!
      expect(availability.occupiedMinutes, 180);
      expect(availability.freeMinutes, 1020 - 180);
      expect(availability.occupiedIntervals, [
        const RoutineTimeInterval(startMinute: 600, endMinute: 780),
      ]);
    });

    test('D. Nested overlaps are merged into outer interval', () {
      // 09:00–14:00 (540–840), with nested 10:00–11:00 and 12:00–13:00
      final entryOuter = RoutineDayEntry(
        item: _item(
          id: 'i1',
          title: 'Long Workshop',
          startMinute: 9 * 60,
          endMinute: 14 * 60,
        ),
        instanceId: 's:i1:2026-09-14',
        templateId: 'i1',
        occurrenceDateKey: '2026-09-14',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.scheduled,
      );
      final entryNested1 = RoutineDayEntry(
        item: _item(
          id: 'i2',
          title: 'Inner 1',
          startMinute: 10 * 60,
          endMinute: 11 * 60,
        ),
        instanceId: 's:i2:2026-09-14',
        templateId: 'i2',
        occurrenceDateKey: '2026-09-14',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.scheduled,
      );
      final entryNested2 = RoutineDayEntry(
        item: _item(
          id: 'i3',
          title: 'Inner 2',
          startMinute: 12 * 60,
          endMinute: 13 * 60,
        ),
        instanceId: 's:i3:2026-09-14',
        templateId: 'i3',
        occurrenceDateKey: '2026-09-14',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.scheduled,
      );

      final availability = RoutineDayAvailability.computeFromEntries([
        entryOuter,
        entryNested1,
        entryNested2,
      ]);

      expect(availability.occupiedMinutes, 300); // 5 hours
      expect(availability.occupiedIntervals, [
        const RoutineTimeInterval(startMinute: 540, endMinute: 840),
      ]);
    });

    test(
      'E. Directly touching intervals merge without zero-minute free gaps',
      () {
        // 09:00–10:00 (540–600) and 10:00–11:00 (600–660)
        final entry1 = RoutineDayEntry(
          item: _item(
            id: 'i1',
            title: 'Block 1',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
          instanceId: 's:i1:2026-09-14',
          templateId: 'i1',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.scheduled,
        );
        final entry2 = RoutineDayEntry(
          item: _item(
            id: 'i2',
            title: 'Block 2',
            startMinute: 10 * 60,
            endMinute: 11 * 60,
          ),
          instanceId: 's:i2:2026-09-14',
          templateId: 'i2',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.scheduled,
        );

        final availability = RoutineDayAvailability.computeFromEntries([
          entry1,
          entry2,
        ]);

        expect(availability.occupiedIntervals, [
          const RoutineTimeInterval(startMinute: 540, endMinute: 660),
        ]);
        // Free intervals before 540 and after 660, no 600-600 gap!
        expect(availability.freeIntervals, [
          const RoutineTimeInterval(startMinute: 360, endMinute: 540),
          const RoutineTimeInterval(startMinute: 660, endMinute: 1380),
        ]);
      },
    );

    test('F. Interval before planning window is clipped to 06:00', () {
      // 05:00–07:00 (300–420) -> clipped to 06:00–07:00 (360–420)
      final entry = RoutineDayEntry(
        item: _item(
          id: 'i1',
          title: 'Early Run',
          startMinute: 5 * 60,
          endMinute: 7 * 60,
        ),
        instanceId: 's:i1:2026-09-14',
        templateId: 'i1',
        occurrenceDateKey: '2026-09-14',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.scheduled,
      );

      final availability = RoutineDayAvailability.computeFromEntries([entry]);
      expect(availability.occupiedMinutes, 60);
      expect(availability.occupiedIntervals, [
        const RoutineTimeInterval(startMinute: 360, endMinute: 420),
      ]);
    });

    test('G. Interval after planning window is clipped to 23:00', () {
      // 22:00–00:00 (1320–1440) -> clipped to 22:00–23:00 (1320–1380)
      final entry = RoutineDayEntry(
        item: _item(
          id: 'i1',
          title: 'Late Movie',
          startMinute: 22 * 60,
          endMinute: 24 * 60,
        ),
        instanceId: 's:i1:2026-09-14',
        templateId: 'i1',
        occurrenceDateKey: '2026-09-14',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.scheduled,
      );

      final availability = RoutineDayAvailability.computeFromEntries([entry]);
      expect(availability.occupiedMinutes, 60);
      expect(availability.occupiedIntervals, [
        const RoutineTimeInterval(startMinute: 1320, endMinute: 1380),
      ]);
    });

    test(
      'H. Overnight continuation from yesterday blocks 06:00–07:00 on continuation day',
      () {
        // Sleep started yesterday at 22:00 and continues to 07:00 today
        final continuationEntry = RoutineDayEntry(
          item: _item(
            id: 'sleep_1',
            title: 'Sleep',
            startMinute: 0,
            endMinute: 7 * 60, // 420
            isContinuation: true,
          ),
          instanceId: 'c:sleep_1:2026-09-13',
          templateId: 'sleep_1',
          occurrenceDateKey: '2026-09-13',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.continuation,
        );

        final availability = RoutineDayAvailability.computeFromEntries([
          continuationEntry,
        ]);

        // Window is 360-1380. Continuation is 0-420, clipped to 360-420 (60 minutes).
        expect(availability.occupiedMinutes, 60);
        expect(availability.occupiedIntervals, [
          const RoutineTimeInterval(startMinute: 360, endMinute: 420),
        ]);
        expect(availability.freeIntervals, [
          const RoutineTimeInterval(startMinute: 420, endMinute: 1380),
        ]);
      },
    );

    test('I. Moved-in occurrence blocks availability on destination day', () {
      final movedInEntry = RoutineDayEntry(
        item: _item(
          id: 't1',
          title: 'Rescheduled Task',
          startMinute: 14 * 60,
          endMinute: 15 * 60,
        ),
        instanceId: 'm:t1:2026-09-12',
        templateId: 't1',
        occurrenceDateKey: '2026-09-12',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.movedIn,
      );

      final availability = RoutineDayAvailability.computeFromEntries([
        movedInEntry,
      ]);
      expect(availability.occupiedMinutes, 60);
      expect(availability.occupiedIntervals, [
        const RoutineTimeInterval(startMinute: 840, endMinute: 900),
      ]);
    });

    test(
      'J. Moved-away occurrence frees up original source day slot via projection',
      () {
        final template = _item(
          id: 't1',
          title: 'Original Monday Task',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1], // Monday
        );
        final occurrence = _occurrence(
          id: 'occ_1',
          routineItemId: 't1',
          occurrenceDateKey: '2026-09-14', // Monday
          movedToDateKey: '2026-09-15', // Moved to Tuesday
          status: RoutineStatus.moved,
        );

        // On Monday (2026-09-14): projector excludes the moved-away occurrence
        final mondayEntries = RoutineOccurrenceProjector.entriesForDay(
          [template],
          [occurrence],
          DateTime(2026, 9, 14),
        );
        final mondayAvailability = RoutineDayAvailability.computeFromEntries(
          mondayEntries,
        );

        expect(mondayEntries, isEmpty);
        expect(mondayAvailability.occupiedMinutes, 0);
        expect(mondayAvailability.freeMinutes, 1020);

        // On Tuesday (2026-09-15): projector includes the moved-in occurrence
        final tuesdayEntries = RoutineOccurrenceProjector.entriesForDay(
          [template],
          [occurrence],
          DateTime(2026, 9, 15),
        );
        final tuesdayAvailability = RoutineDayAvailability.computeFromEntries(
          tuesdayEntries,
        );

        expect(tuesdayEntries, hasLength(1));
        expect(tuesdayAvailability.occupiedMinutes, 60);
      },
    );

    test(
      'K. Multiple instances of same template participate independently in availability',
      () {
        // Native occurrence at 08:00-09:00 + moved-in sibling at 14:00-15:00
        final nativeEntry = RoutineDayEntry(
          item: _item(
            id: 'tpl_1',
            title: 'Daily Gym',
            startMinute: 8 * 60,
            endMinute: 9 * 60,
          ),
          instanceId: 's:tpl_1:2026-09-14',
          templateId: 'tpl_1',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.scheduled,
        );
        final movedInSibling = RoutineDayEntry(
          item: _item(
            id: 'tpl_1',
            title: 'Daily Gym (Moved)',
            startMinute: 14 * 60,
            endMinute: 15 * 60,
          ),
          instanceId: 'm:tpl_1:2026-09-13',
          templateId: 'tpl_1',
          occurrenceDateKey: '2026-09-13',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.movedIn,
        );

        final availability = RoutineDayAvailability.computeFromEntries([
          nativeEntry,
          movedInSibling,
        ]);

        expect(availability.occupiedMinutes, 120);
        expect(availability.occupiedIntervals, [
          const RoutineTimeInterval(startMinute: 480, endMinute: 540),
          const RoutineTimeInterval(startMinute: 840, endMinute: 900),
        ]);
      },
    );

    test('L. 5-minute placement ceiling-snaps non-aligned free gaps', () {
      // Free gap starts at 07:03 (423 min), ends at 09:00 (540 min)
      final availability = RoutineDayAvailability.computeFromIntervals([
        const RoutineTimeInterval(startMinute: 360, endMinute: 423),
      ]);

      // Asking for a 30-minute slot with snap=5
      final slot = availability.findFirstFreeSlot(
        durationMinutes: 30,
        snapMinutes: 5,
      );

      // 423 ceiling snapped to 5 is 425 (07:05), NOT 420 (07:00)!
      expect(slot, 425);
      expect(slot! % 5, 0);
    });

    test('M. 1-minute precision places exactly at start of gap', () {
      // Free gap starts at 07:03 (423 min)
      final availability = RoutineDayAvailability.computeFromIntervals([
        const RoutineTimeInterval(startMinute: 360, endMinute: 423),
      ]);

      final slot = availability.findFirstFreeSlot(
        durationMinutes: 30,
        snapMinutes: 1,
      );

      expect(slot, 423);
    });

    test(
      'N. AI Assistant delegates calculateLargestFreeGap to shared engine',
      () {
        final items = <RoutineItem>[
          _item(
            id: 'i1',
            title: 'Class',
            startMinute: 8 * 60, // 480
            endMinute: 10 * 60, // 600
          ),
        ];

        final freeGap = calculateLargestFreeGap(items);

        // Window 360-1380. Gaps: [360, 480] (120m), [600, 1380] (780m).
        // Largest is [600, 1380].
        expect(freeGap.start, 600);
        expect(freeGap.end, 1380);
        expect(freeGap.duration, 780);
      },
    );

    test(
      'O. Interval completely before window produces 0 occupied minutes',
      () {
        final entry = RoutineDayEntry(
          item: _item(
            id: 'early',
            title: 'Night Sleep',
            startMinute: 60, // 01:00
            endMinute: 240, // 04:00
          ),
          instanceId: 's:early:2026-09-14',
          templateId: 'early',
          occurrenceDateKey: '2026-09-14',
          displayDateKey: '2026-09-14',
          kind: RoutineDayEntryKind.scheduled,
        );

        final availability = RoutineDayAvailability.computeFromEntries([entry]);
        expect(availability.occupiedMinutes, 0);
        expect(availability.freeMinutes, 1020);
        expect(availability.occupiedIntervals, isEmpty);
        expect(availability.occupiedMinutes + availability.freeMinutes, 1020);
      },
    );

    test('P. Interval completely after window produces 0 occupied minutes', () {
      final entry = RoutineDayEntry(
        item: _item(
          id: 'late',
          title: 'Late Night reading',
          startMinute: 1390, // 23:10
          endMinute: 1430, // 23:50
        ),
        instanceId: 's:late:2026-09-14',
        templateId: 'late',
        occurrenceDateKey: '2026-09-14',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.scheduled,
      );

      final availability = RoutineDayAvailability.computeFromEntries([entry]);
      expect(availability.occupiedMinutes, 0);
      expect(availability.freeMinutes, 1020);
      expect(availability.occupiedIntervals, isEmpty);
      expect(availability.occupiedMinutes + availability.freeMinutes, 1020);
    });

    test('Q. Interval straddling entire window clips to 1020m occupied', () {
      final entry = RoutineDayEntry(
        item: _item(
          id: 'all_day',
          title: 'Full Day Conference',
          startMinute: 240, // 04:00
          endMinute: 1440, // 24:00
        ),
        instanceId: 's:all_day:2026-09-14',
        templateId: 'all_day',
        occurrenceDateKey: '2026-09-14',
        displayDateKey: '2026-09-14',
        kind: RoutineDayEntryKind.scheduled,
      );

      final availability = RoutineDayAvailability.computeFromEntries([entry]);
      expect(availability.occupiedMinutes, 1020);
      expect(availability.freeMinutes, 0);
      expect(availability.occupiedIntervals, [
        const RoutineTimeInterval(startMinute: 360, endMinute: 1380),
      ]);
      expect(availability.freeIntervals, isEmpty);
      expect(availability.largestFreeInterval, isNull);
      expect(availability.occupiedMinutes + availability.freeMinutes, 1020);
    });

    test(
      'R. Invariant occupiedMinutes + freeMinutes == windowSize holds strictly',
      () {
        // Test across arbitrary intervals
        final intervals = [
          const RoutineTimeInterval(startMinute: 200, endMinute: 500),
          const RoutineTimeInterval(startMinute: 550, endMinute: 700),
          const RoutineTimeInterval(startMinute: 650, endMinute: 900),
          const RoutineTimeInterval(startMinute: 1200, endMinute: 1400),
        ];
        final availability = RoutineDayAvailability.computeFromIntervals(
          intervals,
        );

        expect(
          availability.occupiedMinutes + availability.freeMinutes,
          availability.windowEndMinute - availability.windowStartMinute,
        );
      },
    );

    test(
      'S. Custom window validates windowStartMinute < windowEndMinute throws ArgumentError',
      () {
        expect(
          () => RoutineDayAvailability.computeFromIntervals(
            [],
            windowStartMinute: 600,
            windowEndMinute: 500,
          ),
          throwsArgumentError,
        );
        expect(
          () => RoutineDayAvailability.computeFromIntervals(
            [],
            windowStartMinute: 600,
            windowEndMinute: 600,
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
