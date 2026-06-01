import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/timeline_layout.dart';

void main() {
  // Spec example sleep item: 28 May 10:30 PM → 29 May 7:30 AM
  RoutineItem makeSleep() {
    return RoutineItem(
      id: 'sleep-test',
      title: 'Sleep',
      date: DateTime(2026, 5, 28),
      endDate: DateTime(2026, 5, 29),
      startMinute: 1350, // 22:30
      endMinute: 450, // 07:30
      blockType: RoutineBlockType.hardBlock,
      category: RoutineCategory.sleep,
      crossesMidnight: true,
      endsNextDay: true,
      hardBlock: true,
    );
  }

  group('overnight sleep duration and normalization', () {
    test('sleep 28 May 22:30 → 29 May 07:30 has duration 540 minutes', () {
      final sleep = makeSleep();
      expect(sleep.durationMinutes, 540);
    });

    test('normalizedEndMinute = 450 + 1440 = 1890', () {
      final sleep = makeSleep();
      expect(TimelineUtils.normalizedEndMinute(sleep), 1890);
    });

    test('model helper normalizedEndMinuteForLayout matches TimelineUtils', () {
      final sleep = makeSleep();
      expect(sleep.normalizedEndMinuteForLayout, 1890);
      expect(
        sleep.normalizedEndMinuteForLayout,
        TimelineUtils.normalizedEndMinute(sleep),
      );
    });

    test('model helper durationMinutesForLayout = 540', () {
      final sleep = makeSleep();
      expect(sleep.durationMinutesForLayout, 540);
    });

    test('isOvernight is true', () {
      final sleep = makeSleep();
      expect(sleep.isOvernight, isTrue);
    });
  });

  group('overnight sleep day segmentation', () {
    test('28 May shows original sleep starting at 1350', () {
      final sleep = makeSleep();
      final may28 = DateTime(2026, 5, 28);
      final items = RoutineMaterializer.itemsForDay([sleep], may28);

      expect(items, hasLength(1));
      expect(items.first.startMinute, 1350);
      expect(items.first.isContinuation, isFalse);
    });

    test('29 May shows continuation segment from 0 to 450', () {
      final sleep = makeSleep();
      final may29 = DateTime(2026, 5, 29);
      final items = RoutineMaterializer.itemsForDay([sleep], may29);

      // Should include continuation (yesterday's overnight item reaching into today)
      final continuations = items.where((item) => item.isContinuation).toList();
      expect(continuations, hasLength(1));
      expect(continuations.first.startMinute, 0);
      expect(continuations.first.endMinute, 450);
      expect(continuations.first.isContinuation, isTrue);
    });

    test('sleep continuation appears on 29 May even without repeatDays', () {
      final sleep = makeSleep().copyWith(repeatDays: const []);
      final may29 = DateTime(2026, 5, 29);
      final items = RoutineMaterializer.itemsForDay([sleep], may29);

      // The continuation segment should still appear because the item
      // started on the previous day (28 May) and crosses midnight.
      // Note: with empty repeatDays and date=28 May, _startsOnDay(previous)
      // checks DateUtils.isSameDay(date, 27 May) which is false, but also
      // checks repeatDays.contains(28.weekday) which is false for empty.
      // The item has date=28 May, so _startsOnDay for previous=27 May is false.
      // We need date=28 May and previous=28 May to match.
      // Actually for may29, previous = may28, and item.date = may28, so
      // _startsOnDay(item, may28) = true via DateUtils.isSameDay.
      final continuations = items.where((item) => item.isContinuation).toList();
      expect(continuations, hasLength(1));
    });
  });

  group('overnight sleep display formatting', () {
    test('display time is "10:30 PM - 7:30 AM", not "10:30 PM - 31:30"', () {
      final display = TimelineUtils.formatTimeRange(1350, 450);
      expect(display, '10:30 PM - 7:30 AM');
      // Must never contain "31:30"
      expect(display.contains('31'), isFalse);
    });

    test('sleepDisplayLabel returns "Sleep continues" for continuation', () {
      final sleep = makeSleep().copyWith(isContinuation: true);
      expect(TimelineUtils.sleepDisplayLabel(sleep), 'Sleep continues');
    });

    test('sleepDisplayLabel returns "Sleep" for original', () {
      final sleep = makeSleep();
      expect(TimelineUtils.sleepDisplayLabel(sleep), 'Sleep');
    });
  });

  group('same-day nap is not overnight', () {
    test('nap 14:00 → 15:00 is not treated as overnight', () {
      final nap = RoutineItem(
        id: 'nap',
        title: 'Afternoon Nap',
        startMinute: 14 * 60, // 2:00 PM
        endMinute: 15 * 60, // 3:00 PM
        blockType: RoutineBlockType.softBlock,
      );

      expect(nap.isOvernight, isFalse);
      expect(nap.normalizedEndMinuteForLayout, 15 * 60);
      expect(nap.durationMinutes, 60);
      expect(TimelineUtils.normalizedEndMinute(nap), 15 * 60);
    });
  });

  group('timeline layout math for overnight sleep', () {
    test('taskTop and taskHeight use exact minuteHeight', () {
      const minuteHeight = 5.0;
      const layout = TimelineLayout(
        visibleStartMinute: 1320, // 10:00 PM
        visibleEndMinute: 1890, // extended past midnight
        minuteHeight: minuteHeight,
      );

      final sleep = makeSleep();
      final normalizedEnd = TimelineUtils.normalizedEndMinute(sleep);

      // taskTop = (1350 - 1320) * 5 = 150
      expect(layout.topForMinute(sleep.startMinute), 150.0);

      // taskHeight = (1890 - 1350) * 5 = 2700
      expect(layout.heightForRange(sleep.startMinute, normalizedEnd), 2700.0);

      // No negative height
      expect(
        layout.heightForRange(sleep.startMinute, normalizedEnd),
        greaterThan(0),
      );
    });

    test('continuation segment layout math is correct', () {
      const minuteHeight = 5.0;
      const layout = TimelineLayout(
        visibleStartMinute: 0,
        visibleEndMinute: 480, // 8:00 AM
        minuteHeight: minuteHeight,
      );

      // Continuation: 0 → 450
      // taskTop = (0 - 0) * 5 = 0
      expect(layout.topForMinute(0), 0.0);

      // taskHeight = (450 - 0) * 5 = 2250
      expect(layout.heightForRange(0, 450), 2250.0);
    });
  });

  group('RoutineCategory.sleep', () {
    test('sleep category exists and is used correctly', () {
      final sleep = makeSleep();
      expect(sleep.category, RoutineCategory.sleep);
    });

    test('sleep category round-trips through toMap/fromMap', () {
      final sleep = makeSleep();
      final map = sleep.toMap();
      expect(map['category'], 'sleep');

      final restored = RoutineItem.fromMap(map);
      expect(restored.category, RoutineCategory.sleep);
    });

    test('isContinuation round-trips through toMap/fromMap', () {
      final sleep = makeSleep().copyWith(isContinuation: true);
      final map = sleep.toMap();
      expect(map['isContinuation'], true);

      final restored = RoutineItem.fromMap(map);
      expect(restored.isContinuation, true);
    });

    test('endDate round-trips through toMap/fromMap', () {
      final sleep = makeSleep();
      final map = sleep.toMap();
      expect(map['endDate'], isNotNull);

      final restored = RoutineItem.fromMap(map);
      expect(restored.endDate, DateTime(2026, 5, 29));
    });
  });

  group('integration pipeline for overnight sleep', () {
    test('calculateVisibleRange handles startMinute=0 for continuation', () {
      final sleep = makeSleep().copyWith(
        date: DateTime(2026, 5, 29),
        startMinute: 0,
        endMinute: 450,
        crossesMidnight: false,
        endsNextDay: false,
        isContinuation: true,
      );

      final layout = TimelineUtils.calculateVisibleRange([sleep]);
      expect(layout.visibleStartMinute, 0); // clamped max(0, -30) -> 0
      // normalized end is 450. 450 + 30 = 480.
      expect(layout.visibleEndMinute, 480);
    });

    test('RoutineConflictEngine ignores self-conflict for continuation', () {
      final sleepStart = makeSleep();
      final sleepContinuation = sleepStart.copyWith(
        date: DateTime(2026, 5, 29),
        startMinute: 0,
        endMinute: 450,
        crossesMidnight: false,
        endsNextDay: false,
        isContinuation: true,
      );

      // Even if both somehow end up in the same list (unlikely since day filtered),
      // they don't overlap in minute time (1350-1890 vs 0-450)
      final conflicts = RoutineConflictEngine.detect([
        sleepStart,
        sleepContinuation,
      ], day: DateTime(2026, 5, 29));
      expect(
        conflicts
            .where((c) => c.type == RoutineConflictType.sleepConflict)
            .isEmpty,
        isTrue,
      );
    });

    test('base_timeline filter includes continuation sleep items', () {
      final sleepContinuation = makeSleep().copyWith(
        date: DateTime(2026, 5, 29),
        startMinute: 0,
        endMinute: 450,
        crossesMidnight: false,
        endsNextDay: false,
        isContinuation: true,
      );

      final filtered = RoutineFilters.applyCategory([sleepContinuation], 'all');
      final baseTimeline = TimelineUtils.filterItems(filtered, 'base_timeline');

      expect(baseTimeline, hasLength(1));
      expect(baseTimeline.first.id, sleepContinuation.id);
    });
  });
}
