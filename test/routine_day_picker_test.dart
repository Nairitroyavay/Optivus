import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/routine_tab.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/routine_day_picker.dart';
import 'package:optivus/features/routine/widgets/routine_header.dart';
import 'package:optivus/features/routine/widgets/routine_title_filter_row.dart';
import 'package:optivus/repositories/routine_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoutineDayPickerButton Widget Tests', () {
    testWidgets('shows correct weekday and day number for routine selectedDay',
        (tester) async {
      final db = FakeRoutineDatabase();
      final repo = FakeRoutineRepository(database: db);
      final testDate = DateTime(2026, 9, 11); // FRI 11

      final container = ProviderContainer(
        overrides: [routineRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(routineNotifierProvider.notifier).updateSelectedDay(testDate);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: RoutineDayPickerButton(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('FRI'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      // Mutate selected date
      final nextDate = DateTime(2026, 9, 12); // SAT 12
      container.read(routineNotifierProvider.notifier).updateSelectedDay(nextDate);
      await tester.pump();

      expect(find.text('SAT'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('FRI'), findsNothing);
    });

    testWidgets('tap opens modern day wheel popover and tap centered closes it',
        (tester) async {
      final db = FakeRoutineDatabase();
      final repo = FakeRoutineRepository(database: db);
      final testDate = DateTime(2026, 9, 11);

      final container = ProviderContainer(
        overrides: [routineRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(routineNotifierProvider.notifier).updateSelectedDay(testDate);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: RoutineDayPickerButton(),
              ),
            ),
          ),
        ),
      );

      // Initially popover PageView is not open
      expect(find.byType(PageView), findsNothing);

      // Tap the date button
      await tester.tap(find.byType(RoutineDayPickerButton));
      await tester.pumpAndSettle();

      // Now PageView is open
      expect(find.byType(PageView), findsOneWidget);

      // Tap centered date item in the wheel (day 11)
      final day11Finder = find.descendant(
        of: find.byType(PageView),
        matching: find.text('11'),
      );
      expect(day11Finder, findsOneWidget);

      await tester.tap(day11Finder);
      await tester.pumpAndSettle();

      // Popover closes
      expect(find.byType(PageView), findsNothing);
      expect(container.read(routineNotifierProvider).selectedDay,
          TimelineUtils.dateOnly(testDate));
    });

    testWidgets('tapping neighboring day animates to it, commits, and closes',
        (tester) async {
      final db = FakeRoutineDatabase();
      final repo = FakeRoutineRepository(database: db);
      final testDate = DateTime(2026, 9, 11);

      final container = ProviderContainer(
        overrides: [routineRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(routineNotifierProvider.notifier).updateSelectedDay(testDate);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: RoutineDayPickerButton(),
              ),
            ),
          ),
        ),
      );

      // Open picker
      await tester.tap(find.byType(RoutineDayPickerButton));
      await tester.pumpAndSettle();

      // Tap day 12 (neighboring item below day 11)
      final day12Finder = find.descendant(
        of: find.byType(PageView),
        matching: find.text('12'),
      );
      expect(day12Finder, findsOneWidget);

      await tester.tap(day12Finder);
      await tester.pumpAndSettle();

      // Popover closes and selected day is now day 12
      expect(find.byType(PageView), findsNothing);
      expect(container.read(routineNotifierProvider).selectedDay.day, 12);
    });

    testWidgets('tapping scrim outside closes popover', (tester) async {
      final db = FakeRoutineDatabase();
      final repo = FakeRoutineRepository(database: db);

      final container = ProviderContainer(
        overrides: [routineRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: RoutineDayPickerButton(),
                ),
              ),
            ),
          ),
        ),
      );

      // Open picker
      await tester.tap(find.byType(RoutineDayPickerButton));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsOneWidget);

      // Tap outside (e.g. at bottom-right of screen)
      await tester.tapAt(const Offset(300, 500));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('triggers controlled selectionClick haptic feedback on date transition',
        (tester) async {
      final hapticCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final db = FakeRoutineDatabase();
      final repo = FakeRoutineRepository(database: db);
      final container = ProviderContainer(
        overrides: [routineRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: RoutineDayPickerButton(),
                ),
              ),
            ),
          ),
        ),
      );

      // Open picker
      await tester.tap(find.byType(RoutineDayPickerButton));
      await tester.pumpAndSettle();

      hapticCalls.clear();

      // Drag the vertical PageView by 1 item (~44.0 px + touch slop)
      await tester.drag(find.byType(PageView), const Offset(0, -70.0));
      await tester.pumpAndSettle();

      // Premium selectionClick was fired
      expect(
        hapticCalls.where((c) => c == 'HapticFeedbackType.selectionClick').length,
        greaterThanOrEqualTo(1),
      );
    });

    testWidgets('dragging does not prematurely commit date until scroll completes',
        (tester) async {
      final db = FakeRoutineDatabase();
      final repo = FakeRoutineRepository(database: db);
      final initialDate = DateTime(2026, 9, 11);

      final container = ProviderContainer(
        overrides: [routineRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(routineNotifierProvider.notifier).updateSelectedDay(initialDate);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: RoutineDayPickerButton(),
              ),
            ),
          ),
        ),
      );

      // Open picker
      await tester.tap(find.byType(RoutineDayPickerButton));
      await tester.pumpAndSettle();

      // Start drag gesture without ending it (exceed touch slop, drag partially)
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(0, -25.0));
      await tester.pump();

      // Selected day in provider must NOT change during active touch drag
      expect(container.read(routineNotifierProvider).selectedDay,
          TimelineUtils.dateOnly(initialDate));

      // Finish drag to next item
      await gesture.moveBy(const Offset(0, -45.0));
      await gesture.up();
      await tester.pumpAndSettle();

      // Now on scroll completion, date is committed
      expect(container.read(routineNotifierProvider).selectedDay.day, 12);
    });

    testWidgets('RoutineTitleFilterRow renders DayPicker, Week and Filter without overflow on 320px screen',
        (tester) async {
      final db = FakeRoutineDatabase();
      final repo = FakeRoutineRepository(database: db);
      final container = ProviderContainer(
        overrides: [routineRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      // Set viewport to narrow phone width 320px
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: RoutineTitleFilterRow(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(RoutineDayPickerButton), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
    });

    testWidgets('RoutineTab uses RoutineTitleFilterRow and does not contain old horizontal date strip',
        (tester) async {
      final db = FakeRoutineDatabase();
      final repo = FakeRoutineRepository(database: db);
      final container = ProviderContainer(
        overrides: [routineRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RoutineTab(),
          ),
        ),
      );

      // Control row is present
      expect(find.byType(RoutineTitleFilterRow), findsOneWidget);
      expect(find.byType(RoutineDayPickerButton), findsOneWidget);

      // Horizontal list view for dates is removed
      // There is only the vertical timeline
      final listViews = tester.widgetList<ListView>(find.byType(ListView));
      for (final lv in listViews) {
        expect(lv.scrollDirection, isNot(Axis.horizontal));
      }
    });

    testWidgets('reopening picker opens centered on newly selected date',
        (tester) async {
      final db = FakeRoutineDatabase();
      final repo = FakeRoutineRepository(database: db);
      final initialDate = DateTime(2026, 9, 11); // FRI 11

      final container = ProviderContainer(
        overrides: [routineRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(routineNotifierProvider.notifier).updateSelectedDay(initialDate);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: RoutineDayPickerButton(),
              ),
            ),
          ),
        ),
      );

      // Open picker
      await tester.tap(find.byType(RoutineDayPickerButton));
      await tester.pumpAndSettle();

      // Scroll 1 day forward (drag down by -70 to overcome touch slop)
      await tester.drag(find.byType(PageView), const Offset(0, -70.0));
      await tester.pumpAndSettle();

      // Close by tapping outside
      await tester.tapAt(const Offset(300, 500));
      await tester.pumpAndSettle();

      // Date state updated to 12
      final newDate = container.read(routineNotifierProvider).selectedDay;
      expect(newDate.day, 12);
      expect(find.text('12'), findsOneWidget);

      // Reopen picker
      await tester.tap(find.byType(RoutineDayPickerButton));
      await tester.pumpAndSettle();

      // Verify controller is present and centered
      final pageView = tester.widget<PageView>(find.byType(PageView));
      final controller = pageView.controller!;
      expect(controller.initialPage, isNotNull);
    });

    testWidgets('changing filter preserves selected date', (tester) async {
      final db = FakeRoutineDatabase();
      final repo = FakeRoutineRepository(database: db);
      final initialDate = DateTime(2026, 9, 11);

      final container = ProviderContainer(
        overrides: [routineRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(routineNotifierProvider.notifier).updateSelectedDay(initialDate);

      // Change filter
      container.read(routineNotifierProvider.notifier).setPrimaryFilter('deepWork');

      expect(container.read(routineNotifierProvider).selectedDay,
          TimelineUtils.dateOnly(initialDate));
      expect(container.read(routineNotifierProvider).selectedPrimaryFilter, 'deepWork');
    });

    testWidgets('rapid open/close does not throw exceptions or cause memory leak',
        (tester) async {
      final db = FakeRoutineDatabase();
      final repo = FakeRoutineRepository(database: db);

      final container = ProviderContainer(
        overrides: [routineRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: RoutineDayPickerButton(),
              ),
            ),
          ),
        ),
      );

      // Rapidly tap button multiple times
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('RoutineHeader correctly identifies TODAY and TOMORROW across month/year boundaries',
        (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      expect(TimelineUtils.isToday(today), isTrue);
      expect(TimelineUtils.isTomorrow(tomorrow), isTrue);
      expect(TimelineUtils.isTomorrow(today), isFalse);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(routineNotifierProvider.notifier).updateSelectedDay(tomorrow);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: RoutineHeader(
                onAITap: () {},
                onAddTap: () {},
                onSettingsTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('TOMORROW:'), findsOneWidget);
    });
  });
}
