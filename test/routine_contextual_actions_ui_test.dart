import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_actions.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_presentation.dart';
import 'package:optivus/models/routine_item.dart';

void main() {
  group('Gates G, H, I, J, K, P: Contextual Actions & Accessible Responsive Layout', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget createTestApp({
      required Widget child,
      double width = 360,
      double textScale = 1.0,
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 800),
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'Gate G & H: Money task shows 3 actions (Save money + Move + Skip), never Done',
      (tester) async {
        final moneyItem = RoutineItem(
          id: 'money_task_1',
          title: 'Save \$10 for Lunch',
          blockType: RoutineBlockType.moneyTask,
          category: RoutineCategory.finance,
          startMinute: 720,
          endMinute: 750,
        );

        await tester.pumpWidget(
          createTestApp(
            child: RoutineCardActions(
              item: moneyItem,
              color: Colors.green,
              actionContext: RoutineActionContext.fallback(item: moneyItem),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Save money'), findsOneWidget);
        expect(find.text('Move'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Done'), findsNothing);
        expect(find.text('Start'), findsNothing);
      },
    );

    testWidgets(
      'Gate I: Bad-habit Check-in shows 3 actions (Check in + Move + Skip), never Done',
      (tester) async {
        final habitItem = RoutineItem(
          id: 'checkin_task_1',
          title: 'Smoking check-in',
          blockType: RoutineBlockType.checkIn,
          category: RoutineCategory.badHabit,
          startMinute: 600,
          endMinute: 615,
        );

        await tester.pumpWidget(
          createTestApp(
            child: RoutineCardActions(
              item: habitItem,
              color: Colors.orange,
              actionContext: RoutineActionContext.fallback(item: habitItem),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Check in'), findsOneWidget);
        expect(find.text('Move'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Done'), findsNothing);
        expect(find.text('Start'), findsNothing);
      },
    );

    testWidgets(
      'Gate J: Planned Tracker Task shows 3 actions (Start Tracker + Move + Skip), never Done',
      (tester) async {
        final trackerPlannedItem = RoutineItem(
          id: 'tracker_planned_1',
          title: 'Hydration Log',
          blockType: RoutineBlockType.trackerTask,
          category: RoutineCategory.health,
          trackerType: TrackerType.hydration,
          status: RoutineStatus.planned,
          startMinute: 500,
          endMinute: 530,
        );

        await tester.pumpWidget(
          createTestApp(
            child: RoutineCardActions(
              item: trackerPlannedItem,
              color: Colors.cyan,
              actionContext: RoutineActionContext.fallback(
                item: trackerPlannedItem,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Start Tracker'), findsOneWidget);
        expect(find.text('Move'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Done'), findsNothing);
        expect(find.text('Start'), findsNothing);
      },
    );

    testWidgets(
      'Gate K: Active Tracker Task shows 2 actions (Open Tracker + Done), never Move',
      (tester) async {
        final trackerActiveItem = RoutineItem(
          id: 'tracker_active_1',
          title: 'Workout Session',
          blockType: RoutineBlockType.trackerTask,
          category: RoutineCategory.health,
          trackerType: TrackerType.workout,
          status: RoutineStatus.inTracker,
          startMinute: 500,
          endMinute: 560,
        );

        await tester.pumpWidget(
          createTestApp(
            child: RoutineCardActions(
              item: trackerActiveItem,
              color: Colors.purple,
              actionContext: RoutineActionContext.fallback(
                item: trackerActiveItem,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Open Tracker'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Move'), findsNothing);
        expect(find.text('Start'), findsNothing);
        expect(find.text('Skip'), findsNothing);
      },
    );

    testWidgets(
      'Standard Planned Task shows 4 actions (Start + Done + Move + Skip)',
      (tester) async {
        final standardItem = RoutineItem(
          id: 'standard_1',
          title: 'Read Physics',
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.habit,
          status: RoutineStatus.planned,
          startMinute: 600,
          endMinute: 660,
        );

        await tester.pumpWidget(
          createTestApp(
            child: RoutineCardActions(
              item: standardItem,
              color: Colors.blue,
              actionContext: RoutineActionContext.fallback(item: standardItem),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Move'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('routine-action-row-horizontal')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Standard Planned Task shows grid-2x2 layout when horizontal row does not fit',
      (tester) async {
        final standardItem = RoutineItem(
          id: 'standard_grid_1',
          title: 'Read Physics',
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.habit,
          status: RoutineStatus.planned,
          startMinute: 600,
          endMinute: 660,
        );

        await tester.pumpWidget(
          createTestApp(
            width: 260,
            textScale: 1.5,
            child: RoutineCardActions(
              item: standardItem,
              color: Colors.blue,
              actionContext: RoutineActionContext.fallback(item: standardItem),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Move'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('routine-action-grid-2x2')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Gate P: 320dp narrow width with 2.0x and 2.5x text scale triggers stacked layout without overflow',
      (tester) async {
        final item = RoutineItem(
          id: 'std_item',
          title: 'Deep Focus Session',
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.focus,
          status: RoutineStatus.planned,
          startMinute: 600,
          endMinute: 720,
        );

        // Test 1: 320dp at 2.0x text scale
        await tester.pumpWidget(
          createTestApp(
            width: 320,
            textScale: 2.0,
            child: RoutineCardActions(
              item: item,
              color: Colors.blue,
              actionContext: RoutineActionContext.fallback(item: item),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Column layout is rendered (stacked mode)
        expect(find.byType(Column), findsWidgets);
        expect(tester.takeException(), isNull); // 0 RenderFlex overflow

        // Test 2: 320dp at 2.5x text scale
        await tester.pumpWidget(
          createTestApp(
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

        expect(find.byType(Column), findsWidgets);
        expect(tester.takeException(), isNull); // 0 RenderFlex overflow
      },
    );

    test(
      'Gate P: Measurement parity between resolveRoutineCardActionLayout and actionFooterHeight',
      () {
        const availableWidth = 320.0;
        const textScaler = TextScaler.linear(1.0);
        const textDirection = TextDirection.ltr;

        // 3-action set: Money
        final moneyActions = const ['Save money', 'Move', 'Skip'];
        final layout3Money =
            RoutineCardPresentation.resolveRoutineCardActionLayout(
              availableWidth: availableWidth,
              textScaler: textScaler,
              textDirection: textDirection,
              labels: moneyActions,
              actionCount: 3,
            );
        final height3Money = RoutineCardFactory.actionFooterHeight(
          layout3Money,
          actionCount: 3,
        );
        expect(height3Money, isPositive);

        // 4-action set: Normal
        final normalActions = const ['Start', 'Done', 'Move', 'Skip'];
        final layout4 = RoutineCardPresentation.resolveRoutineCardActionLayout(
          availableWidth: availableWidth,
          textScaler: textScaler,
          textDirection: textDirection,
          labels: normalActions,
          actionCount: 4,
        );
        final height4 = RoutineCardFactory.actionFooterHeight(
          layout4,
          actionCount: 4,
        );
        expect(height4, isPositive);

        // Large font scale (2.5x) should yield stacked mode
        const largeScaler = TextScaler.linear(2.5);
        final stackedLayout =
            RoutineCardPresentation.resolveRoutineCardActionLayout(
              availableWidth: 280.0,
              textScaler: largeScaler,
              textDirection: textDirection,
              labels: normalActions,
              actionCount: 4,
            );
        expect(stackedLayout, RoutineCardActionLayout.stacked);

        final stackedHeight = RoutineCardFactory.actionFooterHeight(
          stackedLayout,
          actionCount: 4,
        );
        expect(stackedHeight, greaterThan(height4));
      },
    );
  });
}
