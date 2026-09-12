import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_adapter.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_viewport.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/timeline_layout.dart';

void main() {
  group('Routine Day Occurrence Identity & Dual-Instance Rendering', () {
    final overnightSleepTemplate = RoutineItem(
      id: 'onb_sleep_template_abc123',
      title: 'Sleep',
      startMinute: 22 * 60 + 30, // 22:30 (10:30 PM)
      endMinute: 6 * 60 + 30, // 06:30 (6:30 AM)
      crossesMidnight: true,
      blockType: RoutineBlockType.hardBlock,
      category: RoutineCategory.sleep,
      repeatDays: const [1, 2, 3, 4, 5, 6, 7], // Every day
    );

    test('Overnight recurring template produces two entries on the same day with distinct instanceIds', () {
      final selectedDay = DateTime(2026, 9, 16); // Wednesday
      final entries = RoutineOccurrenceProjector.entriesForDay(
        [overnightSleepTemplate],
        const [],
        selectedDay,
      );

      expect(entries.length, 2);

      final continuationEntry = entries.firstWhere(
        (e) => e.kind == RoutineDayEntryKind.continuation,
      );
      final scheduledEntry = entries.firstWhere(
        (e) => e.kind == RoutineDayEntryKind.scheduled,
      );

      // Same durable template ID
      expect(continuationEntry.templateId, overnightSleepTemplate.id);
      expect(scheduledEntry.templateId, overnightSleepTemplate.id);

      // Different instance IDs
      expect(continuationEntry.instanceId, isNot(equals(scheduledEntry.instanceId)));
      expect(continuationEntry.instanceId, 'c:${overnightSleepTemplate.id}:2026-09-15');
      expect(scheduledEntry.instanceId, 's:${overnightSleepTemplate.id}:2026-09-16');

      // Occurrence date keys target respective anchor days
      expect(continuationEntry.occurrenceDateKey, '2026-09-15');
      expect(scheduledEntry.occurrenceDateKey, '2026-09-16');

      // Display properties
      expect(continuationEntry.item.isContinuation, isTrue);
      expect(continuationEntry.item.startMinute, 0);
      expect(continuationEntry.item.endMinute, 6 * 60 + 30);

      expect(scheduledEntry.item.isContinuation, isFalse);
      expect(scheduledEntry.item.startMinute, 22 * 60 + 30);
      expect(scheduledEntry.item.endMinute, 6 * 60 + 30);
    });

    test('Moved-in occurrence alongside native template produces distinct instanceIds', () {
      final workoutTemplate = RoutineItem(
        id: 'workout_template_xyz',
        title: 'Workout',
        startMinute: 8 * 60,
        endMinute: 9 * 60,
        blockType: RoutineBlockType.trackerTask,
        repeatDays: const [1, 2, 3, 4, 5],
      );

      // Moved-in occurrence of workout from Monday to Wednesday
      final movedOccurrence = RoutineOccurrenceRecord(
        id: 'occ_workout_monday_to_wednesday',
        ownerUid: 'user_1',
        routineItemId: workoutTemplate.id,
        source: 'routine',
        action: 'move',
        operationKey: 'op_1',
        occurrenceDateKey: '2026-09-14', // Monday
        movedToDateKey: '2026-09-16', // Wednesday
        movedStartMinute: 15 * 60,
        movedEndMinute: 16 * 60,
        status: RoutineStatus.moved,
        createdAt: DateTime(2026, 9, 14),
        updatedAt: DateTime(2026, 9, 14),
      );

      final selectedDay = DateTime(2026, 9, 16); // Wednesday
      final entries = RoutineOccurrenceProjector.entriesForDay(
        [workoutTemplate],
        [movedOccurrence],
        selectedDay,
      );

      expect(entries.length, 2);

      final nativeEntry = entries.firstWhere((e) => e.kind == RoutineDayEntryKind.scheduled);
      final movedEntry = entries.firstWhere((e) => e.kind == RoutineDayEntryKind.movedIn);

      expect(nativeEntry.templateId, workoutTemplate.id);
      expect(movedEntry.templateId, workoutTemplate.id);

      expect(nativeEntry.instanceId, 's:${workoutTemplate.id}:2026-09-16');
      expect(movedEntry.instanceId, 'm:${movedOccurrence.id}');
      expect(nativeEntry.instanceId, isNot(equals(movedEntry.instanceId)));

      expect(nativeEntry.occurrenceDateKey, '2026-09-16');
      expect(movedEntry.occurrenceDateKey, '2026-09-14'); // Targets source date
    });

    testWidgets('RoutinePreparedTimelineLayout prepares duplicate template entries without assertion or map overwrite', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final selectedDay = DateTime(2026, 9, 16);
                final entries = RoutineOccurrenceProjector.entriesForDay(
                  [overnightSleepTemplate],
                  const [],
                  selectedDay,
                );

                final layout = RoutinePreparedTimelineLayout.prepare(
                  context: context,
                  rawItems: entries,
                  timelineLayout: const TimelineLayout(
                    visibleStartMinute: 0,
                    visibleEndMinute: 1440,
                  ),
                  availableWidth: 390.0,
                );

                expect(layout.items.length, 2);
                expect(layout.itemById.length, 2);

                final continuationId = 'c:${overnightSleepTemplate.id}:2026-09-15';
                final scheduledId = 's:${overnightSleepTemplate.id}:2026-09-16';

                expect(layout.itemById.containsKey(continuationId), isTrue);
                expect(layout.itemById.containsKey(scheduledId), isTrue);

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('RoutineTimelineViewport renders both instances of overnight template with NO red screen or duplicate key exception', (tester) async {
      final selectedDay = DateTime(2026, 9, 16);
      final entries = RoutineOccurrenceProjector.entriesForDay(
        [overnightSleepTemplate],
        const [],
        selectedDay,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390.0,
                height: 844.0,
                child: RoutineTimelineViewport(
                  items: entries,
                  layout: const TimelineLayout(
                    visibleStartMinute: 0,
                    visibleEndMinute: 1440,
                  ),
                  isToday: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure NO Flutter exception occurred (e.g. "Duplicate keys found. Stack has multiple children with key...")
      expect(tester.takeException(), isNull);

      final continuationId = 'c:${overnightSleepTemplate.id}:2026-09-15';
      final scheduledId = 's:${overnightSleepTemplate.id}:2026-09-16';

      // Both cards are present in the widget tree with their unique instance keys
      expect(find.byKey(ValueKey('routine-timeline-card-$continuationId')), findsOneWidget);
      expect(find.byKey(ValueKey('routine-timeline-card-$scheduledId')), findsOneWidget);

      // Both cards show 'Sleep'
      expect(find.text('Sleep'), findsNWidgets(2));
    });

    test('InstanceId derivation is strictly deterministic and stable across multiple invocations', () {
      final id1 = RoutineDayEntry.deriveInstanceId(
        kind: RoutineDayEntryKind.scheduled,
        templateId: 'test_item_1',
        occurrenceDateKey: '2026-09-16',
      );
      final id2 = RoutineDayEntry.deriveInstanceId(
        kind: RoutineDayEntryKind.scheduled,
        templateId: 'test_item_1',
        occurrenceDateKey: '2026-09-16',
      );
      expect(id1, id2);
      expect(id1, 's:test_item_1:2026-09-16');

      final contId1 = RoutineDayEntry.deriveInstanceId(
        kind: RoutineDayEntryKind.continuation,
        templateId: 'test_item_1',
        occurrenceDateKey: '2026-09-15',
      );
      expect(contId1, 'c:test_item_1:2026-09-15');
    });
  });
}
