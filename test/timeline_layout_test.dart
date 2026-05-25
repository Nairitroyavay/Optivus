import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/timeline_layout.dart';

void main() {
  group('routine timeline layout math', () {
    test('positions a 4:50 PM to 6:30 PM item exactly', () {
      const layout = TimelineLayout(
        visibleStartMinute: 16 * 60,
        visibleEndMinute: 20 * 60,
        minuteHeight: 5,
      );

      const taskStart = 16 * 60 + 50;
      const taskEnd = 18 * 60 + 30;

      expect(layout.topForMinute(taskStart), 250);
      expect(layout.heightForRange(taskStart, taskEnd), 500);
    });

    test('keeps a 5-minute task rail exactly 5 minutes tall', () {
      const layout = TimelineLayout(
        visibleStartMinute: 7 * 60,
        visibleEndMinute: 8 * 60,
        minuteHeight: 5,
      );
      final item = RoutineItem(
        id: 'meditation',
        title: 'Meditation',
        startMinute: 7 * 60 + 40,
        endMinute: 7 * 60 + 45,
        blockType: RoutineBlockType.trackerTask,
      );

      final normalizedEnd = TimelineUtils.normalizedEndMinute(item);

      expect(normalizedEnd, 7 * 60 + 45);
      expect(layout.heightForRange(item.startMinute, normalizedEnd), 25);
    });

    test('places current time 4:37 PM at the exact minute position', () {
      const layout = TimelineLayout(
        visibleStartMinute: 16 * 60,
        visibleEndMinute: 18 * 60,
        minuteHeight: 5,
      );

      const currentMinute = 16 * 60 + 37;

      expect(layout.isMinuteVisible(currentMinute), isTrue);
      expect(layout.topForMinute(currentMinute), 185);
    });

    test('rounds dynamic visible range around routine items', () {
      final layout = TimelineUtils.calculateVisibleRange([
        RoutineItem(
          id: 'morning',
          title: 'Morning task',
          startMinute: 7 * 60 + 40,
          endMinute: 7 * 60 + 45,
          blockType: RoutineBlockType.flexibleTask,
        ),
        RoutineItem(
          id: 'night',
          title: 'Night task',
          startMinute: 23 * 60,
          endMinute: 23 * 60 + 30,
          blockType: RoutineBlockType.flexibleTask,
        ),
      ]);

      expect(layout.visibleStartMinute, 7 * 60 + 10);
      expect(layout.visibleEndMinute, 24 * 60);
    });

    test('supports full 24h mode', () {
      final layout = TimelineUtils.calculateVisibleRange(
        const [],
        showFullDay: true,
      );

      expect(layout.visibleStartMinute, 0);
      expect(layout.visibleEndMinute, 1440);
      expect(layout.showFullDay, isTrue);
      expect(layout.totalHeight, 7200);
    });

    test('normalizes overnight sleep only for layout', () {
      const layout = TimelineLayout(
        visibleStartMinute: 23 * 60,
        visibleEndMinute: 31 * 60 + 30,
        minuteHeight: 5,
      );
      final sleep = RoutineItem(
        id: 'sleep',
        title: 'Sleep',
        startMinute: 23 * 60 + 30,
        endMinute: 7 * 60,
        blockType: RoutineBlockType.hardBlock,
        crossesMidnight: true,
        endsNextDay: true,
      );

      final normalizedEnd = TimelineUtils.normalizedEndMinute(sleep);

      expect(normalizedEnd, 31 * 60);
      expect(layout.heightForRange(sleep.startMinute, normalizedEnd), 2250);
      expect(
        TimelineUtils.formatTimeRange(sleep.startMinute, sleep.endMinute),
        '11:30 PM - 7:00 AM',
      );
    });
  });
}
