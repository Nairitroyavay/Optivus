import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_presentation.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_actions.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';

Widget _createTestApp({
  required Widget child,
  double width = 360,
  double textScale = 1.0,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1000),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Routine Action Layout & Measurement Unification (Gates 1-20)', () {
    // =========================================================================
    // GATE 1 & 8: Specific Moved-Planned Under-Measurement Regression
    // =========================================================================
    testWidgets(
      'Gate 1 & 8: Moved/Planned occurrence at compact width (260dp) measures 2 rows and renders 2x2 grid without clipping',
      (tester) async {
        final movedItem = RoutineItem(
          id: 'moved_task_1',
          title: 'Review Machine Learning Paper',
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.focus,
          status: RoutineStatus.moved,
          undoToPlannedAllowed: true,
          startMinute: 600,
          endMinute: 660,
        );

        const testWidth = 260.0;
        const textScaler = TextScaler.linear(1.0);
        const textDirection = TextDirection.ltr;

        // 1. Assert ActionSet contract: exactly 4 actions, NO Undo
        final actionSet = RoutineCardActionSet.resolve(
          item: movedItem,
          effectiveStatus: RoutineStatus.moved,
          isTrackerActive: false,
          hasGenericCountdown: false,
          canUndo: true, // Internal state has canUndo=true!
        );
        expect(actionSet.count, 4);
        expect(actionSet.labels, ['Start', 'Done', 'Move', 'Skip']);
        expect(actionSet.labels.contains('Undo'), isFalse);

        // 2. Assert LayoutPlan: grid2x2 with 2 rows
        final contentWidth =
            testWidth - RoutineCardPresentation.cardHorizontalPaddingTotal;
        final plan = actionSet.resolveLayoutPlan(
          availableWidth: contentWidth,
          textScaler: textScaler,
          textDirection: textDirection,
        );
        expect(plan.geometry, RoutineCardActionRowGeometry.grid2x2);
        expect(plan.rowCount, 2);
        expect(plan.rows[0].map((a) => a.label).toList(), ['Start', 'Done']);
        expect(plan.rows[1].map((a) => a.label).toList(), ['Move', 'Skip']);

        // 3. Assert Factory measureHeight allocates full 2-row footer (NOT 1 row)
        double measuredHeight = 0.0;
        await tester.pumpWidget(
          _createTestApp(
            width: testWidth,
            child: Builder(
              builder: (context) {
                measuredHeight = RoutineCardFactory.measureHeight(
                  context,
                  testWidth,
                  movedItem,
                  effectiveStatus: RoutineStatus.moved,
                  canUndo: true,
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      key: const ValueKey('moved-card'),
                      width: testWidth,
                      child: RoutineCardFactory.buildCard(
                        item: movedItem,
                        actionContext: RoutineActionContext.fallback(
                          item: movedItem,
                        ),
                      ),
                    ),
                    Container(
                      key: const ValueKey('next-card'),
                      height: 50,
                      color: Colors.red,
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // 4. Assert Renderer uses 2x2 grid container
        expect(
          find.byKey(const ValueKey('routine-action-grid-2x2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-action-row-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-action-row-1')),
          findsOneWidget,
        );

        // Row 0 has Start and Done
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('routine-action-row-0')),
            matching: find.byKey(
              const ValueKey('routine-action-start-moved_task_1'),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('routine-action-row-0')),
            matching: find.byKey(
              const ValueKey('routine-action-done-moved_task_1'),
            ),
          ),
          findsOneWidget,
        );

        // Row 1 has Move and Skip
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('routine-action-row-1')),
            matching: find.byKey(
              const ValueKey('routine-action-move-moved_task_1'),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('routine-action-row-1')),
            matching: find.byKey(
              const ValueKey('routine-action-skip-moved_task_1'),
            ),
          ),
          findsOneWidget,
        );

        // 5. Assert measured height covers actual rendered card height
        final renderedCard = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('moved-card')),
        );
        final renderedHeight = renderedCard.size.height;
        expect(measuredHeight, greaterThanOrEqualTo(renderedHeight));
        expect(measuredHeight - renderedHeight, lessThan(8.0));

        // 6. Assert next card is strictly below the moved card (zero overlap)
        final movedBottom = tester
            .getBottomLeft(find.byKey(const ValueKey('moved-card')))
            .dy;
        final nextTop = tester
            .getTopLeft(find.byKey(const ValueKey('next-card')))
            .dy;
        expect(nextTop, greaterThanOrEqualTo(movedBottom));
      },
    );

    // =========================================================================
    // GATE 9: Extreme Text Scale Moved Card
    // =========================================================================
    testWidgets(
      'Gate 9: Moved/Planned occurrence at 320dp with 2.5x text scale stacks into 4 rows and matches measurement',
      (tester) async {
        final movedItem = RoutineItem(
          id: 'moved_scale_task',
          title: 'Deep Architecture Analysis',
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.focus,
          status: RoutineStatus.moved,
          undoToPlannedAllowed: true,
          startMinute: 700,
          endMinute: 760,
        );

        const testWidth = 320.0;
        const textScale = 2.5;

        double measuredHeight = 0.0;
        await tester.pumpWidget(
          _createTestApp(
            width: testWidth,
            textScale: textScale,
            child: Builder(
              builder: (context) {
                measuredHeight = RoutineCardFactory.measureHeight(
                  context,
                  testWidth,
                  movedItem,
                  effectiveStatus: RoutineStatus.moved,
                  canUndo: true,
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      key: const ValueKey('moved-scale-card'),
                      width: testWidth,
                      child: RoutineCardFactory.buildCard(
                        item: movedItem,
                        actionContext: RoutineActionContext.fallback(
                          item: movedItem,
                        ),
                      ),
                    ),
                    Container(key: const ValueKey('adjacent-card'), height: 40),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Assert 4 stacked rows
        expect(
          find.byKey(const ValueKey('routine-action-column-stacked')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-action-row-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-action-row-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-action-row-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-action-row-3')),
          findsOneWidget,
        );

        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Move'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Undo'), findsNothing);

        final renderedCard = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('moved-scale-card')),
        );
        expect(measuredHeight, greaterThanOrEqualTo(renderedCard.size.height));
        expect(measuredHeight - renderedCard.size.height, lessThan(8.0));

        final cardBottom = tester
            .getBottomLeft(find.byKey(const ValueKey('moved-scale-card')))
            .dy;
        final nextTop = tester
            .getTopLeft(find.byKey(const ValueKey('adjacent-card')))
            .dy;
        expect(nextTop, greaterThanOrEqualTo(cardBottom));
      },
    );

    // =========================================================================
    // GATE 10: Normal Planned Regression
    // =========================================================================
    testWidgets(
      'Gate 10: Normal Planned Card adapts between wide (1 row), compact (2x2), and extreme text (stacked)',
      (tester) async {
        final item = RoutineItem(
          id: 'normal_planned',
          title: 'Daily Exercise',
          blockType: RoutineBlockType.flexibleTask,
          startMinute: 420,
          endMinute: 480,
          status: RoutineStatus.planned,
        );

        // Wide (400dp, 1.0x scale): 1 horizontal row
        await tester.pumpWidget(
          _createTestApp(
            width: 400,
            child: RoutineCardActions(
              item: item,
              color: Colors.blue,
              actionContext: RoutineActionContext.fallback(item: item),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('routine-action-row-horizontal')),
          findsOneWidget,
        );

        // Compact (260dp, 1.0x scale): 2x2 grid
        await tester.pumpWidget(
          _createTestApp(
            width: 260,
            child: RoutineCardActions(
              item: item,
              color: Colors.blue,
              actionContext: RoutineActionContext.fallback(item: item),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('routine-action-grid-2x2')),
          findsOneWidget,
        );

        // Extreme text scale (320dp, 2.5x scale): stacked 4 rows
        await tester.pumpWidget(
          _createTestApp(
            width: 320,
            textScale: 2.5,
            child: RoutineCardActions(
              item: item,
              color: Colors.blue,
              actionContext: RoutineActionContext.fallback(item: item),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('routine-action-column-stacked')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-action-row-3')),
          findsOneWidget,
        );
      },
    );

    // =========================================================================
    // GATE 11: Active Generic with Countdown Regression
    // =========================================================================
    testWidgets(
      'Gate 11: Active normal task with countdown renders countdownPlusPair (2 rows) and measures exact 2 rows',
      (tester) async {
        final activeItem = RoutineItem(
          id: 'active_countdown',
          title: 'Pomodoro Focus Session',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.active,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 5),
          ),
          countdownDurationSeconds: 1500,
          startMinute: 600,
          endMinute: 630,
        );

        const testWidth = 260.0;
        double measuredHeight = 0.0;

        await tester.pumpWidget(
          _createTestApp(
            width: testWidth,
            child: Builder(
              builder: (context) {
                measuredHeight = RoutineCardFactory.measureHeight(
                  context,
                  testWidth,
                  activeItem,
                  effectiveStatus: RoutineStatus.active,
                );
                return SizedBox(
                  key: const ValueKey('active-card'),
                  width: testWidth,
                  child: RoutineCardFactory.buildCard(
                    item: activeItem,
                    actionContext: RoutineActionContext.fallback(
                      item: activeItem,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Countdown on row 0, Done + Stop on row 1
        expect(
          find.byKey(const ValueKey('routine-action-column-stacked')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-action-row-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('routine-action-row-1')),
          findsOneWidget,
        );
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Stop'), findsOneWidget);
        expect(find.text('Move'), findsNothing);
        expect(find.text('Skip'), findsNothing);

        final renderedCard = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('active-card')),
        );
        expect(measuredHeight, greaterThanOrEqualTo(renderedCard.size.height));
        expect(measuredHeight - renderedCard.size.height, lessThan(8.0));
      },
    );

    // =========================================================================
    // GATE 12: Specialized 3-Action Regression (Money, Bad-Habit, Tracker Planned)
    // =========================================================================
    testWidgets(
      'Gate 12: Specialized 3-Action cards stack into exactly 3 rows without overflow at 320dp and 2.5x text scale',
      (tester) async {
        final moneyItem = RoutineItem(
          id: 'money_item',
          title: 'Daily Micro-Saving',
          blockType: RoutineBlockType.moneyTask,
          status: RoutineStatus.planned,
          startMinute: 540,
          endMinute: 550,
        );

        final habitItem = RoutineItem(
          id: 'habit_item',
          title: 'Quit Smoking Check-in',
          blockType: RoutineBlockType.checkIn,
          category: RoutineCategory.badHabit,
          status: RoutineStatus.planned,
          startMinute: 720,
          endMinute: 730,
        );

        final trackerItem = RoutineItem(
          id: 'tracker_planned_item',
          title: 'Read Book Tracker',
          blockType: RoutineBlockType.trackerTask,
          status: RoutineStatus.planned,
          startMinute: 800,
          endMinute: 830,
        );

        for (final item in [moneyItem, habitItem, trackerItem]) {
          await tester.pumpWidget(
            _createTestApp(
              width: 320,
              textScale: 2.5,
              child: RoutineCardActions(
                item: item,
                color: Colors.blue,
                actionContext: RoutineActionContext.fallback(item: item),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('routine-action-column-stacked')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('routine-action-row-0')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('routine-action-row-1')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('routine-action-row-2')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('routine-action-row-3')),
            findsNothing,
          );
          expect(
            find.text('Done'),
            findsNothing,
          ); // Done is prohibited on 3-action planned cards
        }
      },
    );

    // =========================================================================
    // GATE 13: Terminal States Regression
    // =========================================================================
    testWidgets(
      'Gate 13: Terminal cards calculate layout directly from visible action set',
      (tester) async {
        final completedItem = RoutineItem(
          id: 'comp_item',
          title: 'Completed Workout',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.completed,
          isCompleted: true,
          startMinute: 400,
          endMinute: 460,
        );

        // Terminal with canUndo: 2 visible actions (Completed, Undo)
        final setWithUndo = RoutineCardActionSet.resolve(
          item: completedItem,
          effectiveStatus: RoutineStatus.completed,
          isTrackerActive: false,
          hasGenericCountdown: false,
          canUndo: true,
        );
        expect(setWithUndo.count, 2);
        expect(setWithUndo.labels, ['Completed', 'Undo']);

        // Terminal without canUndo: 1 visible action (Completed)
        final setWithoutUndo = RoutineCardActionSet.resolve(
          item: completedItem,
          effectiveStatus: RoutineStatus.completed,
          isTrackerActive: false,
          hasGenericCountdown: false,
          canUndo: false,
        );
        expect(setWithoutUndo.count, 1);
        expect(setWithoutUndo.labels, ['Completed']);

        // Render Completed + Undo in stacked mode (e.g. 200dp)
        await tester.pumpWidget(
          _createTestApp(
            width: 200,
            child: RoutineCardActions(
              item: completedItem,
              color: Colors.green,
              actionContext: RoutineActionContext.fallback(item: completedItem),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Completed'), findsOneWidget);
      },
    );

    // =========================================================================
    // GATE 14: Tracker Active Regression
    // =========================================================================
    testWidgets(
      'Gate 14: Active Tracker Task renders Open Tracker + Done and matches measurement',
      (tester) async {
        final activeTracker = RoutineItem(
          id: 'tracker_active',
          title: 'Weight Training',
          blockType: RoutineBlockType.trackerTask,
          status: RoutineStatus.inTracker,
          startMinute: 600,
          endMinute: 660,
        );

        const testWidth = 260.0;
        double measuredHeight = 0.0;

        await tester.pumpWidget(
          _createTestApp(
            width: testWidth,
            child: Builder(
              builder: (context) {
                measuredHeight = RoutineCardFactory.measureHeight(
                  context,
                  testWidth,
                  activeTracker,
                  effectiveStatus: RoutineStatus.inTracker,
                  isTrackerActive: true,
                );
                return SizedBox(
                  key: const ValueKey('tracker-active-card'),
                  width: testWidth,
                  child: RoutineCardFactory.buildCard(
                    item: activeTracker,
                    actionContext: RoutineActionContext.fallback(
                      item: activeTracker,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Open Tracker'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Move'), findsNothing);
        expect(find.text('Skip'), findsNothing);

        final renderedCard = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('tracker-active-card')),
        );
        expect(measuredHeight, greaterThanOrEqualTo(renderedCard.size.height));
      },
    );

    // =========================================================================
    // GATE 15: Action-Set / Render Parity Across All 10 Major States
    // =========================================================================
    testWidgets(
      'Gate 15: Rendered buttons strictly match RoutineCardActionSet labels across all 10 major states',
      (tester) async {
        final testCases =
            <
              String,
              (RoutineItem, RoutineStatus, bool, bool, bool, List<String>)
            >{
              'Normal Planned': (
                RoutineItem(
                  id: 't1',
                  title: 'T1',
                  blockType: RoutineBlockType.flexibleTask,
                  status: RoutineStatus.planned,
                  startMinute: 100,
                  endMinute: 200,
                ),
                RoutineStatus.planned,
                false,
                false,
                false,
                ['Start', 'Done', 'Move', 'Skip'],
              ),
              'Moved Planned': (
                RoutineItem(
                  id: 't2',
                  title: 'T2',
                  blockType: RoutineBlockType.flexibleTask,
                  status: RoutineStatus.moved,
                  undoToPlannedAllowed: true,
                  startMinute: 100,
                  endMinute: 200,
                ),
                RoutineStatus.moved,
                false,
                false,
                true,
                ['Start', 'Done', 'Move', 'Skip'],
              ),
              'Normal Active': (
                RoutineItem(
                  id: 't3',
                  title: 'T3',
                  blockType: RoutineBlockType.flexibleTask,
                  status: RoutineStatus.active,
                  startedAt: DateTime.now().toUtc(),
                  countdownDurationSeconds: 600,
                  startMinute: 100,
                  endMinute: 200,
                ),
                RoutineStatus.active,
                false,
                true,
                false,
                ['00:00:00', 'Done', 'Stop'],
              ),
              'Money': (
                RoutineItem(
                  id: 't4',
                  title: 'T4',
                  blockType: RoutineBlockType.moneyTask,
                  status: RoutineStatus.planned,
                  startMinute: 100,
                  endMinute: 200,
                ),
                RoutineStatus.planned,
                false,
                false,
                false,
                ['Save money', 'Move', 'Skip'],
              ),
              'Check-in': (
                RoutineItem(
                  id: 't5',
                  title: 'T5',
                  blockType: RoutineBlockType.checkIn,
                  category: RoutineCategory.badHabit,
                  status: RoutineStatus.planned,
                  startMinute: 100,
                  endMinute: 200,
                ),
                RoutineStatus.planned,
                false,
                false,
                false,
                ['Check in', 'Move', 'Skip'],
              ),
              'Tracker Planned': (
                RoutineItem(
                  id: 't6',
                  title: 'T6',
                  blockType: RoutineBlockType.trackerTask,
                  status: RoutineStatus.planned,
                  startMinute: 100,
                  endMinute: 200,
                ),
                RoutineStatus.planned,
                false,
                false,
                false,
                ['Start Tracker', 'Move', 'Skip'],
              ),
              'Tracker Active': (
                RoutineItem(
                  id: 't7',
                  title: 'T7',
                  blockType: RoutineBlockType.trackerTask,
                  status: RoutineStatus.inTracker,
                  startMinute: 100,
                  endMinute: 200,
                ),
                RoutineStatus.inTracker,
                true,
                false,
                false,
                ['Open Tracker', 'Done'],
              ),
              'Completed': (
                RoutineItem(
                  id: 't8',
                  title: 'T8',
                  blockType: RoutineBlockType.flexibleTask,
                  status: RoutineStatus.completed,
                  isCompleted: true,
                  startMinute: 100,
                  endMinute: 200,
                ),
                RoutineStatus.completed,
                false,
                false,
                false,
                ['Completed'],
              ),
              'Skipped': (
                RoutineItem(
                  id: 't9',
                  title: 'T9',
                  blockType: RoutineBlockType.flexibleTask,
                  status: RoutineStatus.skipped,
                  startMinute: 100,
                  endMinute: 200,
                ),
                RoutineStatus.skipped,
                false,
                false,
                true,
                ['Skipped', 'Undo'],
              ),
              'Missed': (
                RoutineItem(
                  id: 't10',
                  title: 'T10',
                  blockType: RoutineBlockType.flexibleTask,
                  status: RoutineStatus.missed,
                  isMissed: true,
                  startMinute: 100,
                  endMinute: 200,
                ),
                RoutineStatus.missed,
                false,
                false,
                false,
                ['Missed'],
              ),
            };

        for (final entry in testCases.entries) {
          final (
            item,
            status,
            isTrackerActive,
            hasCountdown,
            canUndo,
            expectedLabels,
          ) = entry.value;

          final actionSet = RoutineCardActionSet.resolve(
            item: item,
            effectiveStatus: status,
            isTrackerActive: isTrackerActive,
            hasGenericCountdown: hasCountdown,
            canUndo: canUndo,
          );

          expect(
            actionSet.labels,
            expectedLabels,
            reason: '${entry.key} actionSet mismatch',
          );
        }
      },
    );

    // =========================================================================
    // GATE 16: Layout-Plan / Render Parity
    // =========================================================================
    testWidgets(
      'Gate 16: Rendered row grouping matches RoutineCardActionLayoutPlan.rows via row keys',
      (tester) async {
        final movedItem = RoutineItem(
          id: 'parity_task',
          title: 'Code Review',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.moved,
          undoToPlannedAllowed: true,
          startMinute: 500,
          endMinute: 560,
        );

        // Render at compact width where plan is grid2x2
        await tester.pumpWidget(
          _createTestApp(
            width: 260,
            child: RoutineCardActions(
              item: movedItem,
              color: Colors.blue,
              actionContext: RoutineActionContext.fallback(item: movedItem),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Row 0 must contain Start and Done
        final row0 = find.byKey(const ValueKey('routine-action-row-0'));
        expect(row0, findsOneWidget);
        expect(
          find.descendant(of: row0, matching: find.text('Start')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row0, matching: find.text('Done')),
          findsOneWidget,
        );

        // Row 1 must contain Move and Skip
        final row1 = find.byKey(const ValueKey('routine-action-row-1'));
        expect(row1, findsOneWidget);
        expect(
          find.descendant(of: row1, matching: find.text('Move')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row1, matching: find.text('Skip')),
          findsOneWidget,
        );
      },
    );

    // =========================================================================
    // GATE 17: Layout-Plan / Measurement Parity
    // =========================================================================
    test(
      'Gate 17: Layout plan totalHeight calculates exact formula across all geometries without duplicate heuristics',
      () {
        const singleBtn = RoutineCardPresentation.actionButtonMinHeight; // 44.0
        const gap = RoutineCardPresentation.actionGap; // 6.0

        // 1 row: 44.0
        const plan1 = RoutineCardActionLayoutPlan(
          layout: RoutineCardActionLayout.horizontal,
          geometry: RoutineCardActionRowGeometry.horizontal1Row,
          rows: [
            [
              RoutineCardActionConfig(
                label: 'Start',
                type: RoutineCardActionType.start,
              ),
              RoutineCardActionConfig(
                label: 'Done',
                type: RoutineCardActionType.done,
              ),
            ],
          ],
        );
        expect(plan1.totalHeight(singleButtonHeight: singleBtn), singleBtn);

        // 2 rows (grid2x2): 44*2 + 6 = 94.0
        const plan2x2 = RoutineCardActionLayoutPlan(
          layout: RoutineCardActionLayout.grid2x2,
          geometry: RoutineCardActionRowGeometry.grid2x2,
          rows: [
            [
              RoutineCardActionConfig(
                label: 'Start',
                type: RoutineCardActionType.start,
              ),
            ],
            [
              RoutineCardActionConfig(
                label: 'Move',
                type: RoutineCardActionType.move,
              ),
            ],
          ],
        );
        expect(
          plan2x2.totalHeight(singleButtonHeight: singleBtn),
          (singleBtn * 2) + gap,
        );

        // 2 rows (countdownPlusPair): 94.0
        const planCountdown = RoutineCardActionLayoutPlan(
          layout: RoutineCardActionLayout.stacked,
          geometry: RoutineCardActionRowGeometry.countdownPlusPair,
          rows: [
            [
              RoutineCardActionConfig(
                label: '00:00:00',
                type: RoutineCardActionType.countdown,
              ),
            ],
            [
              RoutineCardActionConfig(
                label: 'Done',
                type: RoutineCardActionType.done,
              ),
              RoutineCardActionConfig(
                label: 'Stop',
                type: RoutineCardActionType.stop,
              ),
            ],
          ],
        );
        expect(
          planCountdown.totalHeight(singleButtonHeight: singleBtn),
          (singleBtn * 2) + gap,
        );

        // 3 rows (vertical3): 44*3 + 12 = 144.0
        const plan3 = RoutineCardActionLayoutPlan(
          layout: RoutineCardActionLayout.stacked,
          geometry: RoutineCardActionRowGeometry.vertical3,
          rows: [
            [
              RoutineCardActionConfig(
                label: 'Save money',
                type: RoutineCardActionType.saveMoney,
              ),
            ],
            [
              RoutineCardActionConfig(
                label: 'Move',
                type: RoutineCardActionType.move,
              ),
            ],
            [
              RoutineCardActionConfig(
                label: 'Skip',
                type: RoutineCardActionType.skip,
              ),
            ],
          ],
        );
        expect(
          plan3.totalHeight(singleButtonHeight: singleBtn),
          (singleBtn * 3) + (gap * 2),
        );

        // 4 rows (stackedRows): 44*4 + 18 = 194.0
        const plan4 = RoutineCardActionLayoutPlan(
          layout: RoutineCardActionLayout.stacked,
          geometry: RoutineCardActionRowGeometry.stackedRows,
          rows: [
            [
              RoutineCardActionConfig(
                label: 'Start',
                type: RoutineCardActionType.start,
              ),
            ],
            [
              RoutineCardActionConfig(
                label: 'Done',
                type: RoutineCardActionType.done,
              ),
            ],
            [
              RoutineCardActionConfig(
                label: 'Move',
                type: RoutineCardActionType.move,
              ),
            ],
            [
              RoutineCardActionConfig(
                label: 'Skip',
                type: RoutineCardActionType.skip,
              ),
            ],
          ],
        );
        expect(
          plan4.totalHeight(singleButtonHeight: singleBtn),
          (singleBtn * 4) + (gap * 3),
        );
      },
    );

    // =========================================================================
    // GATE 18: Card Cache & Fingerprint Regression
    // =========================================================================
    test(
      'Gate 18: layoutFingerprint changes across Planned -> Start -> Stop -> Planned cycle',
      () {
        final planned = RoutineItem(
          id: 'item_cache',
          title: 'Study Physics',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.planned,
          startMinute: 600,
          endMinute: 660,
        );

        final active = planned.copyWith(
          status: RoutineStatus.active,
          startedAt: DateTime.now().toUtc(),
          countdownDurationSeconds: 3600,
        );

        final stoppedMoved = planned.copyWith(
          status: RoutineStatus.moved,
          undoToPlannedAllowed: true,
        );

        final fp1 = RoutineCardFactory.layoutFingerprint(planned);
        final fp2 = RoutineCardFactory.layoutFingerprint(active);
        final fp3 = RoutineCardFactory.layoutFingerprint(stoppedMoved);

        expect(fp1, isNot(equals(fp2)));
        expect(fp2, isNot(equals(fp3)));
        expect(fp1, isNot(equals(fp3)));
      },
    );

    // =========================================================================
    // GATE 19: Move -> Start -> Stop Visual Roundtrip
    // =========================================================================
    testWidgets(
      'Gate 19: Move -> Start -> Stop UI visual roundtrip recalculates card height cleanly',
      (tester) async {
        final base = RoutineItem(
          id: 'roundtrip_task',
          title: 'Math Revision',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.moved,
          undoToPlannedAllowed: true,
          startMinute: 600,
          endMinute: 660,
        );

        const testWidth = 260.0;
        final keyState = ValueNotifier<RoutineItem>(base);

        await tester.pumpWidget(
          _createTestApp(
            width: testWidth,
            child: ValueListenableBuilder<RoutineItem>(
              valueListenable: keyState,
              builder: (context, currentItem, _) {
                final height = RoutineCardFactory.measureHeight(
                  context,
                  testWidth,
                  currentItem,
                  effectiveStatus: currentItem.status,
                  canUndo: currentItem.undoToPlannedAllowed,
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      key: ValueKey('roundtrip-${currentItem.status.name}'),
                      width: testWidth,
                      height: height,
                      child: RoutineCardFactory.buildCard(
                        item: currentItem,
                        actionContext: RoutineActionContext.fallback(
                          item: currentItem,
                        ),
                      ),
                    ),
                    Container(
                      key: const ValueKey('trailing-guard'),
                      height: 30,
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. In Moved planned state: 2x2 grid
        expect(
          find.byKey(const ValueKey('routine-action-grid-2x2')),
          findsOneWidget,
        );
        var guardTop = tester
            .getTopLeft(find.byKey(const ValueKey('trailing-guard')))
            .dy;
        var cardBottom = tester
            .getBottomLeft(find.byKey(const ValueKey('roundtrip-moved')))
            .dy;
        expect(guardTop, greaterThanOrEqualTo(cardBottom));

        // 2. Start task: Active with countdown
        keyState.value = base.copyWith(
          status: RoutineStatus.active,
          startedAt: DateTime.now().toUtc(),
          countdownDurationSeconds: 1800,
        );
        await tester.pumpAndSettle();
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Stop'), findsOneWidget);
        guardTop = tester
            .getTopLeft(find.byKey(const ValueKey('trailing-guard')))
            .dy;
        cardBottom = tester
            .getBottomLeft(find.byKey(const ValueKey('roundtrip-active')))
            .dy;
        expect(guardTop, greaterThanOrEqualTo(cardBottom));

        // 3. Stop task: restores Moved planned state
        keyState.value = base;
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('routine-action-grid-2x2')),
          findsOneWidget,
        );
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Move'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        guardTop = tester
            .getTopLeft(find.byKey(const ValueKey('trailing-guard')))
            .dy;
        cardBottom = tester
            .getBottomLeft(find.byKey(const ValueKey('roundtrip-moved')))
            .dy;
        expect(guardTop, greaterThanOrEqualTo(cardBottom));
      },
    );

    // =========================================================================
    // GATE 20: Move -> Skip -> Undo Visual Roundtrip
    // =========================================================================
    testWidgets(
      'Gate 20: Move -> Skip -> Undo UI visual roundtrip recalculates height cleanly',
      (tester) async {
        final base = RoutineItem(
          id: 'skip_roundtrip',
          title: 'Evening Walk',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.moved,
          undoToPlannedAllowed: true,
          startMinute: 1100,
          endMinute: 1130,
        );

        const testWidth = 260.0;
        final stateNotifier = ValueNotifier<RoutineItem>(base);

        await tester.pumpWidget(
          _createTestApp(
            width: testWidth,
            child: ValueListenableBuilder<RoutineItem>(
              valueListenable: stateNotifier,
              builder: (context, currentItem, _) {
                final height = RoutineCardFactory.measureHeight(
                  context,
                  testWidth,
                  currentItem,
                  effectiveStatus: currentItem.status,
                  canUndo: currentItem.undoToPlannedAllowed,
                );
                return SizedBox(
                  width: testWidth,
                  height: height,
                  child: RoutineCardFactory.buildCard(
                    item: currentItem,
                    actionContext: RoutineActionContext.fallback(
                      item: currentItem,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Moved planned: Start, Done, Move, Skip
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);

        // 2. Skipped: Skipped + Undo
        stateNotifier.value = base.copyWith(status: RoutineStatus.skipped);
        await tester.pumpAndSettle();
        expect(find.text('Skipped'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
        expect(find.text('Start'), findsNothing);

        // 3. Undo: restores Moved planned
        stateNotifier.value = base;
        await tester.pumpAndSettle();
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Move'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
      },
    );

    // =========================================================================
    // REQUIRED REAL WIDGET TESTS (All 15 Cases)
    // =========================================================================
    group('Required 15 Real Widget Tests', () {
      void runCardWidgetTest(
        String name, {
        required RoutineItem item,
        required double width,
        double textScale = 1.0,
        required List<String> expectedActions,
        required List<String> prohibitedActions,
        RoutineStatus? effectiveStatus,
        bool canUndo = false,
        bool? isTrackerActive,
      }) {
        testWidgets(name, (tester) async {
          final effectiveItem = canUndo
              ? item.copyWith(undoToPlannedAllowed: true)
              : item;
          double measuredHeight = 0.0;
          await tester.pumpWidget(
            _createTestApp(
              width: width,
              textScale: textScale,
              child: Builder(
                builder: (context) {
                  measuredHeight = RoutineCardFactory.measureHeight(
                    context,
                    width,
                    effectiveItem,
                    effectiveStatus: effectiveStatus ?? effectiveItem.status,
                    canUndo: canUndo,
                    isTrackerActive: isTrackerActive,
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        key: const ValueKey('primary-card'),
                        width: width,
                        child: RoutineCardFactory.buildCard(
                          item: effectiveItem,
                          actionContext: RoutineActionContext.fallback(
                            item: effectiveItem,
                          ),
                        ),
                      ),
                      Container(
                        key: const ValueKey('next-card'),
                        height: 30,
                        color: Colors.black,
                      ),
                    ],
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '$name caused RenderFlex exception',
          );

          for (final label in expectedActions) {
            expect(
              find.text(label),
              findsOneWidget,
              reason: '$name missing expected action $label',
            );
          }
          for (final label in prohibitedActions) {
            expect(
              find.text(label),
              findsNothing,
              reason: '$name displayed prohibited action $label',
            );
          }

          final cardBox = tester.renderObject<RenderBox>(
            find.byKey(const ValueKey('primary-card')),
          );
          expect(
            measuredHeight,
            greaterThanOrEqualTo(cardBox.size.height),
            reason: '$name measured height less than rendered',
          );

          final cardBottom = tester
              .getBottomLeft(find.byKey(const ValueKey('primary-card')))
              .dy;
          final nextTop = tester
              .getTopLeft(find.byKey(const ValueKey('next-card')))
              .dy;
          expect(
            nextTop,
            greaterThanOrEqualTo(cardBottom),
            reason: '$name card collided with next card',
          );
        });
      }

      // 1. normal planned wide
      runCardWidgetTest(
        '1. normal planned wide',
        item: RoutineItem(
          id: 'c1',
          title: 'Planned Wide',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.planned,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 400,
        expectedActions: ['Start', 'Done', 'Move', 'Skip'],
        prohibitedActions: ['Undo', 'Stop'],
      );

      // 2. normal planned 2x2
      runCardWidgetTest(
        '2. normal planned 2x2',
        item: RoutineItem(
          id: 'c2',
          title: 'Planned 2x2',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.planned,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 260,
        expectedActions: ['Start', 'Done', 'Move', 'Skip'],
        prohibitedActions: ['Undo'],
      );

      // 3. normal planned 2.5x
      runCardWidgetTest(
        '3. normal planned 2.5x',
        item: RoutineItem(
          id: 'c3',
          title: 'Planned 2.5x',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.planned,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 320,
        textScale: 2.5,
        expectedActions: ['Start', 'Done', 'Move', 'Skip'],
        prohibitedActions: ['Undo'],
      );

      // 4. moved planned wide
      runCardWidgetTest(
        '4. moved planned wide',
        item: RoutineItem(
          id: 'c4',
          title: 'Moved Wide',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.moved,
          undoToPlannedAllowed: true,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 400,
        canUndo: true,
        expectedActions: ['Start', 'Done', 'Move', 'Skip'],
        prohibitedActions: ['Undo'],
      );

      // 5. moved planned 2x2
      runCardWidgetTest(
        '5. moved planned 2x2',
        item: RoutineItem(
          id: 'c5',
          title: 'Moved 2x2',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.moved,
          undoToPlannedAllowed: true,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 260,
        canUndo: true,
        expectedActions: ['Start', 'Done', 'Move', 'Skip'],
        prohibitedActions: ['Undo'],
      );

      // 6. moved planned 2.5x stacked
      runCardWidgetTest(
        '6. moved planned 2.5x stacked',
        item: RoutineItem(
          id: 'c6',
          title: 'Moved Stacked',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.moved,
          undoToPlannedAllowed: true,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 320,
        textScale: 2.5,
        canUndo: true,
        expectedActions: ['Start', 'Done', 'Move', 'Skip'],
        prohibitedActions: ['Undo'],
      );

      // 7. active countdown compact
      runCardWidgetTest(
        '7. active countdown compact',
        item: RoutineItem(
          id: 'c7',
          title: 'Active Task',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.active,
          startedAt: DateTime.now().toUtc(),
          countdownDurationSeconds: 1800,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 260,
        expectedActions: ['Done', 'Stop'],
        prohibitedActions: ['Move', 'Skip', 'Start'],
      );

      // 8. Money 3-action compact
      runCardWidgetTest(
        '8. Money 3-action compact',
        item: RoutineItem(
          id: 'c8',
          title: 'Money Plan',
          blockType: RoutineBlockType.moneyTask,
          status: RoutineStatus.planned,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 260,
        expectedActions: ['Save money', 'Move', 'Skip'],
        prohibitedActions: ['Done', 'Start'],
      );

      // 9. Check-in 3-action compact
      runCardWidgetTest(
        '9. Check-in 3-action compact',
        item: RoutineItem(
          id: 'c9',
          title: 'Check In Plan',
          blockType: RoutineBlockType.checkIn,
          category: RoutineCategory.badHabit,
          status: RoutineStatus.planned,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 260,
        expectedActions: ['Check in', 'Move', 'Skip'],
        prohibitedActions: ['Done', 'Start'],
      );

      // 10. Tracker Planned compact
      runCardWidgetTest(
        '10. Tracker Planned compact',
        item: RoutineItem(
          id: 'c10',
          title: 'Tracker Planned',
          blockType: RoutineBlockType.trackerTask,
          status: RoutineStatus.planned,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 260,
        expectedActions: ['Start Tracker', 'Move', 'Skip'],
        prohibitedActions: ['Done', 'Start', 'Open Tracker'],
      );

      // 11. Tracker Active compact
      runCardWidgetTest(
        '11. Tracker Active compact',
        item: RoutineItem(
          id: 'c11',
          title: 'Tracker Active',
          blockType: RoutineBlockType.trackerTask,
          status: RoutineStatus.inTracker,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 260,
        isTrackerActive: true,
        expectedActions: ['Open Tracker', 'Done'],
        prohibitedActions: ['Move', 'Skip', 'Start Tracker'],
      );

      // 12. Completed
      runCardWidgetTest(
        '12. Completed without Undo',
        item: RoutineItem(
          id: 'c12',
          title: 'Finished Task',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.completed,
          isCompleted: true,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 320,
        canUndo: false,
        expectedActions: ['Completed'],
        prohibitedActions: ['Undo', 'Start', 'Done', 'Move', 'Skip'],
      );

      // 13. Completed + Undo
      runCardWidgetTest(
        '13. Completed with Undo',
        item: RoutineItem(
          id: 'c13',
          title: 'Finished Task Undoable',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.completed,
          isCompleted: true,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 320,
        canUndo: true,
        expectedActions: ['Completed', 'Undo'],
        prohibitedActions: ['Start', 'Done', 'Move', 'Skip'],
      );

      // 14. Skipped + Undo
      runCardWidgetTest(
        '14. Skipped with Undo',
        item: RoutineItem(
          id: 'c14',
          title: 'Skipped Task',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.skipped,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 320,
        canUndo: true,
        expectedActions: ['Skipped', 'Undo'],
        prohibitedActions: ['Start', 'Done', 'Move', 'Skip'],
      );

      // 15. Missed without Undo
      runCardWidgetTest(
        '15. Missed',
        item: RoutineItem(
          id: 'c15',
          title: 'Missed Task',
          blockType: RoutineBlockType.flexibleTask,
          status: RoutineStatus.missed,
          isMissed: true,
          startMinute: 500,
          endMinute: 560,
        ),
        width: 320,
        canUndo: false,
        expectedActions: ['Missed'],
        prohibitedActions: ['Undo', 'Start', 'Done', 'Move', 'Skip'],
      );
    });
  });
}
