import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/sheets/add_routine_sheet.dart';
import 'package:optivus/models/routine_item.dart';

void main() {
  group('Gate F: Weekly Free Slot Edge Cases & Sleep Explanation', () {
    late ProviderContainer container;
    late RoutineNotifier notifier;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        ],
      );
      notifier = container.read(routineNotifierProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('findWeeklyFreeSlot with fully packed day returns null', () {
      // Create a solid block covering 6:00 AM (360) to 11:00 PM (1380) on Tuesdays
      final packedTuesday = RoutineItem(
        id: 'solid_block',
        title: 'Full Day Event',
        startMinute: 360,
        endMinute: 1380,
        repeatDays: const [DateTime.tuesday],
        repeatRule: 'weekly',
        blockType: RoutineBlockType.hardBlock,
      );

      notifier.state = notifier.state.copyWith(items: [packedTuesday]);

      final slot = notifier.findWeeklyFreeSlot(
        item: RoutineItem(
          id: 'new_item',
          title: 'Study',
          startMinute: 0,
          endMinute: 30,
          blockType: RoutineBlockType.flexibleTask,
        ),
        repeatDays: const [DateTime.monday, DateTime.tuesday],
        durationMinutes: 30,
        baseDate: DateTime(2026, 9, 14),
      );

      expect(slot, isNull);
    });

    test('findWeeklyFreeSlot across 7 days finds mutually free common slot', () {
      // Day 1 (Mon): Busy 360-600 (6 AM - 10 AM)
      // Day 2 (Tue): Busy 600-800 (10 AM - 1:20 PM)
      // Day 3 (Wed): Busy 800-1000 (1:20 PM - 4:40 PM)
      // Day 4 (Thu): Busy 1000-1200 (4:40 PM - 8:00 PM)
      // Day 5 (Fri): Busy 360-600
      // Day 6 (Sat): Busy 600-800
      // Day 7 (Sun): Busy 800-1000
      // Common free slot exists: 1200-1380 (8:00 PM - 11:00 PM)
      final items = [
        RoutineItem(
          id: 'mon',
          title: 'Morning',
          startMinute: 360,
          endMinute: 600,
          repeatDays: const [DateTime.monday, DateTime.friday],
          repeatRule: 'weekly',
          blockType: RoutineBlockType.hardBlock,
        ),
        RoutineItem(
          id: 'tue',
          title: 'Midday',
          startMinute: 600,
          endMinute: 800,
          repeatDays: const [DateTime.tuesday, DateTime.saturday],
          repeatRule: 'weekly',
          blockType: RoutineBlockType.hardBlock,
        ),
        RoutineItem(
          id: 'wed',
          title: 'Afternoon',
          startMinute: 800,
          endMinute: 1000,
          repeatDays: const [DateTime.wednesday, DateTime.sunday],
          repeatRule: 'weekly',
          blockType: RoutineBlockType.hardBlock,
        ),
        RoutineItem(
          id: 'thu',
          title: 'Late Afternoon',
          startMinute: 1000,
          endMinute: 1200,
          repeatDays: const [DateTime.thursday],
          repeatRule: 'weekly',
          blockType: RoutineBlockType.hardBlock,
        ),
      ];

      notifier.state = notifier.state.copyWith(items: items);

      final slot = notifier.findWeeklyFreeSlot(
        item: RoutineItem(
          id: 'daily_habit',
          title: 'Night Reflection',
          startMinute: 0,
          endMinute: 60,
          blockType: RoutineBlockType.flexibleTask,
        ),
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        durationMinutes: 60,
        baseDate: DateTime(2026, 9, 14),
      );

      expect(slot, isNotNull);
      expect(slot! >= 1200, isTrue);
      expect(slot + 60 <= 1380, isTrue);
    });

    test('findWeeklyFreeSlot with empty repeatDays delegates to findFreeSlot for baseDate', () {
      final itemOnDate = RoutineItem(
        id: 'date_item',
        title: 'One-off item',
        date: DateTime(2026, 9, 14),
        startMinute: 360,
        endMinute: 480,
        repeatDays: const [],
        repeatRule: 'once',
        blockType: RoutineBlockType.hardBlock,
      );

      notifier.state = notifier.state.copyWith(items: [itemOnDate]);

      final slot = notifier.findWeeklyFreeSlot(
        item: RoutineItem(
          id: 'test_item',
          title: 'Test',
          startMinute: 0,
          endMinute: 60,
          blockType: RoutineBlockType.flexibleTask,
        ),
        repeatDays: const [], // empty
        durationMinutes: 60,
        baseDate: DateTime(2026, 9, 14),
      );

      expect(slot, isNotNull);
      expect(slot! >= 480, isTrue); // after the blocking item
    });

    test('findWeeklyFreeSlot with duration exceeding entire 17-hour window returns null', () {
      final slot = notifier.findWeeklyFreeSlot(
        item: RoutineItem(
          id: 'mammoth_task',
          title: 'Mammoth Task',
          startMinute: 0,
          endMinute: 1200,
          blockType: RoutineBlockType.flexibleTask,
        ),
        repeatDays: const [1, 2],
        durationMinutes: 18 * 60, // 18 hours (window is 17 hours: 6 AM to 11 PM)
        baseDate: DateTime(2026, 9, 14),
      );

      expect(slot, isNull);
    });

    testWidgets('AddRoutineSheet shows helpful Sleep explanation when slot not found', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pack the schedule so findFreeSlot cannot find a slot
      final packedItem = RoutineItem(
        id: 'full_day',
        title: 'Busy Day',
        startMinute: 360,
        endMinute: 1380,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        repeatRule: 'weekly',
        blockType: RoutineBlockType.hardBlock,
      );

      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        ],
      );
      addTearDown(container.dispose);
      container.read(routineNotifierProvider.notifier).state =
          container.read(routineNotifierProvider).copyWith(items: [packedItem]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (ctx, ref, _) => ElevatedButton(
                  onPressed: () {
                    showAddRoutineSheet(ctx, ref);
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap 'Fixed Block' category
      final fixedCategory = find.text('Fixed Block');
      if (fixedCategory.evaluate().isNotEmpty) {
        await tester.tap(fixedCategory);
        await tester.pumpAndSettle();
      }

      // Switch kind to Sleep
      final typeDropdown = find.text('Type: Class');
      await tester.ensureVisible(typeDropdown);
      expect(typeDropdown, findsOneWidget);
      await tester.tap(typeDropdown);
      await tester.pumpAndSettle();

      final sleepOption = find.text('Type: Sleep').last;
      await tester.tap(sleepOption);
      await tester.pumpAndSettle();

      // Tap 'Find free slot'
      final findSlotBtn = find.text('Find free slot');
      await tester.ensureVisible(findSlotBtn);
      expect(findSlotBtn, findsOneWidget);
      await tester.tap(findSlotBtn);
      await tester.pumpAndSettle();

      // Expect specific explanation for Sleep blocks
      expect(
        find.text(
          'Sleep blocks are typically scheduled during overnight rest hours outside the daytime planning window. Please choose your sleep hours manually.',
        ),
        findsOneWidget,
      );
    });
  });
}
