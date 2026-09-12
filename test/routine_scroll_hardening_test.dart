import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_viewport.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/timeline_layout.dart';

void main() {
  group('Routine Timeline Viewport Scroll Hardening', () {
    testWidgets('Scroll to current time handles early frame without throwing null check exception', (tester) async {
      // Set time inside visible range
      final now = DateTime.now();
      final currentMinute = now.hour * 60 + now.minute;

      final testItem = RoutineItem(
        id: 'scroll_test_item',
        title: 'Current Event',
        startMinute: (currentMinute - 30).clamp(0, 1400),
        endMinute: (currentMinute + 30).clamp(60, 1440),
        blockType: RoutineBlockType.flexibleTask,
      );

      final entry = RoutineDayEntry(
        item: testItem,
        instanceId: 's:${testItem.id}:2026-09-12',
        templateId: testItem.id,
        occurrenceDateKey: '2026-09-12',
        displayDateKey: '2026-09-12',
        kind: RoutineDayEntryKind.scheduled,
      );

      // Build viewport with isToday: true and layout encompassing currentMinute
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390.0,
                height: 844.0,
                child: RoutineTimelineViewport(
                  items: [entry],
                  layout: TimelineLayout(
                    visibleStartMinute: (currentMinute - 120).clamp(0, 1200),
                    visibleEndMinute: (currentMinute + 120).clamp(240, 1440),
                  ),
                  isToday: true,
                  showCurrentTimeLine: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Pump single frame to trigger postFrameCallbacks
      await tester.pump();

      // Ensure no Null check operator error occurred on position.maxScrollExtent
      expect(tester.takeException(), isNull);

      // Settle animations
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Transitioning from non-today to isToday does not trigger scroll exception', (tester) async {
      final now = DateTime.now();
      final currentMinute = now.hour * 60 + now.minute;

      final testItem = RoutineItem(
        id: 'scroll_transition_item',
        title: 'Transition Event',
        startMinute: (currentMinute - 15).clamp(0, 1400),
        endMinute: (currentMinute + 45).clamp(60, 1440),
        blockType: RoutineBlockType.hardBlock,
      );

      final entry = RoutineDayEntry(
        item: testItem,
        instanceId: 's:${testItem.id}:2026-09-12',
        templateId: testItem.id,
        occurrenceDateKey: '2026-09-12',
        displayDateKey: '2026-09-12',
        kind: RoutineDayEntryKind.scheduled,
      );

      // Start on a non-today date
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390.0,
                height: 844.0,
                child: RoutineTimelineViewport(
                  items: [entry],
                  layout: TimelineLayout(
                    visibleStartMinute: (currentMinute - 120).clamp(0, 1200),
                    visibleEndMinute: (currentMinute + 120).clamp(240, 1440),
                  ),
                  isToday: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Transition to isToday: true (user tapped 'Today' or selected current day)
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390.0,
                height: 844.0,
                child: RoutineTimelineViewport(
                  items: [entry],
                  layout: TimelineLayout(
                    visibleStartMinute: (currentMinute - 120).clamp(0, 1200),
                    visibleEndMinute: (currentMinute + 120).clamp(240, 1440),
                  ),
                  isToday: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
