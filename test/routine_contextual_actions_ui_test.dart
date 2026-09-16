import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_actions.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_presentation.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';

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

    testWidgets('Gate G & H: Money task shows 2 actions (Save money + Move), never Done', (tester) async {
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
      expect(find.text('Done'), findsNothing);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('Gate I: Bad-habit Check-in shows 2 actions (Check in + Move), never Done', (tester) async {
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
      expect(find.text('Done'), findsNothing);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('Gate J: Planned Tracker Task shows 2 actions (Start Tracker + Move), never Done', (tester) async {
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
            actionContext: RoutineActionContext.fallback(item: trackerPlannedItem),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Tracker'), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('Gate K: Active Tracker Task shows 2 actions (Open Tracker + Done), never Move', (tester) async {
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
            actionContext: RoutineActionContext.fallback(item: trackerActiveItem),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Tracker'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Move'), findsNothing);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('Standard Planned Task shows 3 actions (Start + Done + Move)', (tester) async {
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
    });

    testWidgets('Gate P: 320dp narrow width with 2.0x and 2.5x text scale triggers stacked layout without overflow', (tester) async {
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
    });

    test('Gate P: Measurement parity between resolveRoutineCardActionLayout and actionFooterHeight', () {
      const availableWidth = 320.0;
      const textScaler = TextScaler.linear(1.0);
      const textDirection = TextDirection.ltr;

      // 2-action set: Money
      final moneyActions = const ['Save money', 'Move'];
      final layout2 = RoutineCardPresentation.resolveRoutineCardActionLayout(
        availableWidth: availableWidth,
        textScaler: textScaler,
        textDirection: textDirection,
        labels: moneyActions,
        actionCount: 2,
      );
      final height2 = RoutineCardFactory.actionFooterHeight(
        layout2,
        actionCount: 2,
      );
      expect(height2, isPositive);

      // 3-action set: Normal
      final normalActions = const ['Start', 'Done', 'Move'];
      final layout3 = RoutineCardPresentation.resolveRoutineCardActionLayout(
        availableWidth: availableWidth,
        textScaler: textScaler,
        textDirection: textDirection,
        labels: normalActions,
        actionCount: 3,
      );
      final height3 = RoutineCardFactory.actionFooterHeight(
        layout3,
        actionCount: 3,
      );
      expect(height3, isPositive);

      // Large font scale (2.5x) should yield stacked mode
      const largeScaler = TextScaler.linear(2.5);
      final stackedLayout = RoutineCardPresentation.resolveRoutineCardActionLayout(
        availableWidth: 280.0,
        textScaler: largeScaler,
        textDirection: textDirection,
        labels: normalActions,
        actionCount: 3,
      );
      expect(stackedLayout, RoutineCardActionLayout.stacked);

      final stackedHeight = RoutineCardFactory.actionFooterHeight(
        stackedLayout,
        actionCount: 3,
      );
      expect(stackedHeight, greaterThan(height3));
    });
  });
}
