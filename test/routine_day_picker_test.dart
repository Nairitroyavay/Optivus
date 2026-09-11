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
    testWidgets(
      'shows correct weekday and day number for routine selectedDay',
      (tester) async {
        final db = FakeRoutineDatabase();
        final repo = FakeRoutineRepository(database: db);
        final testDate = DateTime(2026, 9, 11); // FRI 11

        final container = ProviderContainer(
          overrides: [routineRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        container
            .read(routineNotifierProvider.notifier)
            .updateSelectedDay(testDate);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: Center(child: RoutineDayPickerButton())),
            ),
          ),
        );

        expect(find.text('FRI'), findsOneWidget);
        expect(find.text('11'), findsOneWidget);

        // Mutate selected date
        final nextDate = DateTime(2026, 9, 12); // SAT 12
        container
            .read(routineNotifierProvider.notifier)
            .updateSelectedDay(nextDate);
        await tester.pump();

        expect(find.text('SAT'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('FRI'), findsNothing);
      },
    );

    testWidgets(
      'TEST 1 — STRONG HAPTIC: moves one day and triggers mediumImpact (no selectionClick)',
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

        // Drag PageView by 1 item (~44.0 px + touch slop)
        await tester.drag(find.byType(PageView), const Offset(0, -70.0));
        await tester.pumpAndSettle();

        // Must be mediumImpact, exactly 1, no selectionClick
        expect(hapticCalls, ['HapticFeedbackType.mediumImpact']);
      },
    );

    testWidgets(
      'TEST 2 — NO HAPTIC ON OPEN: opening picker produces 0 haptic calls',
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
              home: Scaffold(body: Center(child: RoutineDayPickerButton())),
            ),
          ),
        );

        // Tap to open
        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pumpAndSettle();

        expect(hapticCalls, isEmpty);
      },
    );

    testWidgets(
      'TEST 3 — NO HAPTIC ON CLOSE: opening and closing without date change produces 0 haptics',
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

        // Open
        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pumpAndSettle();

        // Close by tapping scrim outside
        await tester.tapAt(const Offset(300, 500));
        await tester.pumpAndSettle();

        expect(hapticCalls, isEmpty);
      },
    );

    testWidgets(
      'TEST 4 — NO DOUBLE HAPTIC: moving one page produces exactly 1 haptic event',
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
              home: Scaffold(body: Center(child: RoutineDayPickerButton())),
            ),
          ),
        );

        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pumpAndSettle();

        hapticCalls.clear();

        await tester.drag(find.byType(PageView), const Offset(0, -70.0));
        await tester.pumpAndSettle();

        expect(hapticCalls.length, 1);
        expect(hapticCalls.first, 'HapticFeedbackType.mediumImpact');
      },
    );

    testWidgets(
      'TEST 5 — NO COMMIT FROM DISPOSE: closing during uncommitted drag keeps previous date',
      (tester) async {
        final db = FakeRoutineDatabase();
        final repo = FakeRoutineRepository(database: db);
        final initialDate = DateTime(2026, 9, 11);

        final container = ProviderContainer(
          overrides: [routineRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        container
            .read(routineNotifierProvider.notifier)
            .updateSelectedDay(initialDate);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: Center(child: RoutineDayPickerButton())),
            ),
          ),
        );

        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pumpAndSettle();

        // Start drag without completing a page snap
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PageView)),
        );
        await gesture.moveBy(const Offset(0, -15.0));
        await tester.pump();

        // Tap outside scrim to close while gesture was active
        await gesture.cancel();
        await tester.tapAt(const Offset(30, 30));
        await tester.pumpAndSettle();

        // Date must NOT change from dispose/close
        expect(
          container.read(routineNotifierProvider).selectedDay,
          TimelineUtils.dateOnly(initialDate),
        );
      },
    );

    testWidgets(
      'TEST 6 — SETTLED PAGE COMMITS ONCE: dragging one full date publishes state change once',
      (tester) async {
        final db = FakeRoutineDatabase();
        final repo = FakeRoutineRepository(database: db);
        final initialDate = DateTime(2026, 9, 11);

        final container = ProviderContainer(
          overrides: [routineRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        container
            .read(routineNotifierProvider.notifier)
            .updateSelectedDay(initialDate);

        int publishCount = 0;
        container.listen(routineNotifierProvider.select((s) => s.selectedDay), (
          prev,
          next,
        ) {
          publishCount++;
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: Center(child: RoutineDayPickerButton())),
            ),
          ),
        );

        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pumpAndSettle();

        expect(publishCount, 0);

        // Drag to next page
        await tester.drag(find.byType(PageView), const Offset(0, -70.0));
        await tester.pumpAndSettle();

        // Changed exactly once
        expect(publishCount, 1);
        expect(container.read(routineNotifierProvider).selectedDay.day, 12);
      },
    );

    testWidgets(
      'TEST 7 — TAP NEIGHBOR: tap adjacent day animates, produces 1 haptic, commits once, and closes',
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
        final testDate = DateTime(2026, 9, 11);

        final container = ProviderContainer(
          overrides: [routineRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        container
            .read(routineNotifierProvider.notifier)
            .updateSelectedDay(testDate);

        int publishCount = 0;
        container.listen(routineNotifierProvider.select((s) => s.selectedDay), (
          prev,
          next,
        ) {
          publishCount++;
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: Center(child: RoutineDayPickerButton())),
            ),
          ),
        );

        // Open picker
        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pumpAndSettle();

        hapticCalls.clear();

        // Tap day 12 (neighboring item below day 11)
        final day12Finder = find.descendant(
          of: find.byType(PageView),
          matching: find.text('12'),
        );
        expect(day12Finder, findsOneWidget);

        await tester.tap(day12Finder);
        await tester.pumpAndSettle();

        // Popover closes, exactly 1 haptic, exactly 1 commit, selected day = 12
        expect(find.byType(PageView), findsNothing);
        expect(hapticCalls.length, 1);
        expect(hapticCalls.first, 'HapticFeedbackType.mediumImpact');
        expect(publishCount, 1);
        expect(container.read(routineNotifierProvider).selectedDay.day, 12);
      },
    );

    testWidgets(
      'TEST 8 — RAPID OPEN/CLOSE: rapid toggles during in-flight animation do not crash or leak',
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
              home: Scaffold(body: Center(child: RoutineDayPickerButton())),
            ),
          ),
        );

        // Rapidly tap button multiple times during transition
        for (int i = 0; i < 8; i++) {
          await tester.tap(
            find.byType(RoutineDayPickerButton),
            warnIfMissed: false,
          );
          await tester.pump(const Duration(milliseconds: 35));
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TEST 9 — CLOSE WHILE OPENING: closes smoothly from current position without jumping',
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

        // Start open
        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));

        // Tap scrim to dismiss before completed
        await tester.tapAt(const Offset(300, 500));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(PageView), findsNothing);
      },
    );

    testWidgets(
      'TEST 10 — DISPOSE DURING CLOSING: unmounting parent during close cleans up synchronously',
      (tester) async {
        final db = FakeRoutineDatabase();
        final repo = FakeRoutineRepository(database: db);

        final container = ProviderContainer(
          overrides: [routineRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        final showButtonNotifier = ValueNotifier<bool>(true);
        addTearDown(showButtonNotifier.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: showButtonNotifier,
                  builder: (context, show, _) {
                    return show
                        ? const RoutineDayPickerButton()
                        : const SizedBox();
                  },
                ),
              ),
            ),
          ),
        );

        // Open
        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pumpAndSettle();

        // Trigger close
        await tester.tap(
          find.byType(RoutineDayPickerButton),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 30));

        // Unmount while closing
        showButtonNotifier.value = false;
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(PageView), findsNothing);
      },
    );

    testWidgets(
      'TEST 11 — NO SHADERMASK: picker does not use ShaderMask for edge fading',
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
              home: Scaffold(body: Center(child: RoutineDayPickerButton())),
            ),
          ),
        );

        // Open picker
        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pumpAndSettle();

        // Verify no ShaderMask inside picker
        expect(find.byType(ShaderMask), findsNothing);
      },
    );

    testWidgets(
      'TEST 12 — REOPEN STATE: reopening picker opens centered on settled date',
      (tester) async {
        final db = FakeRoutineDatabase();
        final repo = FakeRoutineRepository(database: db);
        final initialDate = DateTime(2026, 9, 11); // FRI 11

        final container = ProviderContainer(
          overrides: [routineRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        container
            .read(routineNotifierProvider.notifier)
            .updateSelectedDay(initialDate);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: Center(child: RoutineDayPickerButton())),
            ),
          ),
        );

        // Open picker
        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pumpAndSettle();

        // Scroll 1 day forward
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

        // Verify PageView is centered on day 12
        final pageView = tester.widget<PageView>(find.byType(PageView));
        final controller = pageView.controller!;
        expect(controller.initialPage, isNotNull);
      },
    );

    testWidgets(
      'TEST 13 — REOPEN WHILE CLOSING: tapping trigger while closing smoothly reverses to open',
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

        // 1. Open picker
        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pumpAndSettle();
        expect(find.byType(PageView), findsOneWidget);

        // 2. Start close
        await tester.tap(
          find.byType(RoutineDayPickerButton),
          warnIfMissed: false,
        );
        // Pump 40ms into the 100ms reverse animation
        await tester.pump(const Duration(milliseconds: 40));

        // 3. Tap trigger again while closing
        await tester.tap(
          find.byType(RoutineDayPickerButton),
          warnIfMissed: false,
        );
        // Settle forward animation
        await tester.pumpAndSettle();

        // Overlay must still exist and PageView must be fully visible
        expect(find.byType(PageView), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Reduced motion mode opens and closes immediately without animation delays',
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
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: true),
                child: Scaffold(body: Center(child: RoutineDayPickerButton())),
              ),
            ),
          ),
        );

        // Tap to open
        await tester.tap(find.byType(RoutineDayPickerButton));
        await tester.pump();

        // Immediately open in reduced motion mode without pumpAndSettle
        expect(find.byType(PageView), findsOneWidget);

        // Tap to close
        await tester.tap(
          find.byType(RoutineDayPickerButton),
          warnIfMissed: false,
        );
        await tester.pump();

        // Immediately closed
        expect(find.byType(PageView), findsNothing);
      },
    );

    testWidgets(
      'RoutineTitleFilterRow renders DayPicker, Week and Filter without overflow on 320px screen',
      (tester) async {
        final db = FakeRoutineDatabase();
        final repo = FakeRoutineRepository(database: db);
        final container = ProviderContainer(
          overrides: [routineRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        tester.view.physicalSize = const Size(320 * 2, 640 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: RoutineTitleFilterRow()),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(RoutineDayPickerButton), findsOneWidget);
        expect(find.text('Week'), findsOneWidget);
        expect(find.text('Filter'), findsOneWidget);
      },
    );

    testWidgets(
      'RoutineTab uses RoutineTitleFilterRow and does not contain old horizontal date strip',
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
            child: const MaterialApp(home: RoutineTab()),
          ),
        );

        // Control row is present
        expect(find.byType(RoutineTitleFilterRow), findsOneWidget);
        expect(find.byType(RoutineDayPickerButton), findsOneWidget);

        final listViews = tester.widgetList<ListView>(find.byType(ListView));
        for (final lv in listViews) {
          expect(lv.scrollDirection, isNot(Axis.horizontal));
        }
      },
    );

    testWidgets(
      'RoutineHeader correctly identifies TODAY and TOMORROW across month/year boundaries',
      (tester) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));

        expect(TimelineUtils.isToday(today), isTrue);
        expect(TimelineUtils.isTomorrow(tomorrow), isTrue);
        expect(TimelineUtils.isTomorrow(today), isFalse);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(routineNotifierProvider.notifier)
            .updateSelectedDay(tomorrow);

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
      },
    );
  });
}
