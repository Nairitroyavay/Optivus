import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/core/timeline/widgets/timeline_card_chrome.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/cards/routine_rich_timeline_card.dart';
import 'package:optivus/features/routine/widgets/routine_current_time_line.dart';
import 'package:optivus/features/routine/widgets/routine_time_ruler.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_adapter.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_viewport.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

void main() {
  group('onboarding projection integrity', () {
    test(
      'load restores a missing Class and preserves manual data/history idempotently',
      () async {
        const uid = 'routine-integrity-user';
        final database = FakeRoutineDatabase();
        final routineRepo = FakeRoutineRepository(database: database);
        final onboardingRepo = FakeOnboardingRepository(
          routineDatabase: database,
        );
        final historyRepo = FakeRoutineHistoryRepository();
        final bundle = _bundle(uid);
        await onboardingRepo.saveCompletionBundle(bundle);
        final plan = RoutineOnboardingProjection.build(bundle);
        expect(
          await routineRepo.reconcileOnboardingProjection(uid, plan),
          isTrue,
        );

        final classItem = plan.items.firstWhere(
          (item) => item.category == RoutineCategory.classBlock,
        );
        final identityItem = plan.items.firstWhere(
          (item) => item.category == RoutineCategory.identity,
        );
        await routineRepo.deleteRoutineItem(uid, classItem.id);
        // Simulate a document written by the legacy projection contract.
        database.itemsByUid[uid]![identityItem.id] = identityItem;
        final manual = RoutineItem(
          id: 'manual-survivor',
          userId: uid,
          title: 'Manual survivor',
          startMinute: 800,
          endMinute: 830,
          repeatDays: const [DateTime.monday],
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem(uid, manual);
        final occurrence = RoutineOccurrenceRecord(
          id: stableRoutineOccurrenceId(
            ownerUid: uid,
            routineItemId: plan.items.last.id,
            occurrenceDateKey: '2026-09-14',
          ),
          ownerUid: uid,
          routineItemId: plan.items.last.id,
          occurrenceDateKey: '2026-09-14',
          status: RoutineStatus.completed,
          source: 'routine',
          action: 'complete',
          operationKey: 'integrity-history-op',
          createdAt: DateTime.utc(2026, 9, 14),
          updatedAt: DateTime.utc(2026, 9, 14),
        );
        await historyRepo.appendHistory(uid, occurrence);

        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
            routineTransactionRepositoryProvider.overrideWithValue(
              FakeRoutineTransactionRepository(),
            ),
            onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner(uid);
        await notifier.inFlightProjectionRepair;

        final state = container.read(routineNotifierProvider);
        expect(
          state.items.where((item) => item.id == classItem.id),
          hasLength(1),
        );
        expect(state.items.any((item) => item.id == manual.id), isTrue);
        expect(state.occurrences.single.id, occurrence.id);
        final restoredClass = state.items.firstWhere(
          (item) => item.id == classItem.id,
        );
        expect(restoredClass.repeatDays, const [DateTime.monday]);
        expect(restoredClass.professor, 'Professor Ada');
        expect(restoredClass.courseCode, 'CS101');
        expect(
          state.items.firstWhere((item) => item.id == identityItem.id).notes,
          isNull,
        );
        expect(
          RoutineOccurrenceProjector.entriesForDay(
            state.items,
            state.occurrences,
            DateTime(2026, 9, 14),
          ).any((entry) => entry.templateId == classItem.id),
          isTrue,
        );
        expect(
          RoutineOccurrenceProjector.entriesForDay(
            state.items,
            state.occurrences,
            DateTime(2026, 9, 15),
          ).any((entry) => entry.templateId == classItem.id),
          isFalse,
        );

        await notifier.loadForOwner(uid);
        await notifier.inFlightProjectionRepair;
        final second = container.read(routineNotifierProvider);
        expect(
          second.items.where((item) => item.id == classItem.id),
          hasLength(1),
        );
        expect(
          second.items.where((item) => item.id == manual.id),
          hasLength(1),
        );
        expect(second.occurrences.single.id, occurrence.id);
      },
    );
  });

  test('source palettes resolve exactly and manual items retain fallback', () {
    final classes = ScheduleSetupConfig.classSetup.colorCycle;
    final work = ScheduleSetupConfig.workSetup.colorCycle;
    for (var index = 0; index < classes.length; index++) {
      expect(
        RoutineCardFactory.colorForItem(_projected('class:$index')),
        classes[index],
      );
    }
    for (var index = 0; index < work.length; index++) {
      expect(
        RoutineCardFactory.colorForItem(
          _projected('work:$index', category: RoutineCategory.job),
        ),
        work[index],
      );
    }
    expect(
      RoutineCardFactory.colorForItem(
        _projected('eating:default', category: RoutineCategory.eating),
      ),
      OptivusColors.roseAccent,
    );
    expect(
      RoutineCardFactory.colorForItem(_projected('fixed:default')),
      OptivusColors.purpleAccent,
    );
    expect(
      RoutineCardFactory.colorForItem(
        _projected('skin:has-products', category: RoutineCategory.skinCare),
      ),
      OptivusColors.roseAccent,
    );
    expect(
      RoutineCardFactory.colorForItem(
        _projected('skin:no-products', category: RoutineCategory.skinCare),
      ),
      OptivusColors.purpleAccent,
    );
    expect(
      RoutineCardFactory.colorForItem(
        RoutineItem(
          id: 'manual',
          title: 'Manual',
          startMinute: 60,
          endMinute: 90,
          blockType: RoutineBlockType.softBlock,
        ),
      ),
      OptivusColors.blockSoft,
    );
  });

  test(
    'source-aware icons and exposed labels are structured and humanized',
    () {
      final classItem = _projected('class:0').copyWith(courseCode: 'CS101');
      final workItem = _projected(
        'work:0',
        category: RoutineCategory.job,
      ).copyWith(title: 'office hours');
      final mealItem = _projected(
        'eating:default',
        category: RoutineCategory.eating,
      ).copyWith(title: 'meal', mealSlot: 'breakfast');
      final skinItem = _projected(
        'skin:has-products',
        category: RoutineCategory.skinCare,
      );
      final commuteItem = _projected(
        'fixed:default',
        category: RoutineCategory.fixed,
      ).copyWith(title: 'commute', baseTimelineSection: 'fixed');

      expect(backTabIcon(classItem), Icons.school_rounded);
      expect(shortBackLabel(classItem), 'CS101');
      expect(backTabIcon(workItem), Icons.business_center_rounded);
      expect(shortBackLabel(workItem), 'Office');
      expect(backTabIcon(mealItem), Icons.wb_sunny_rounded);
      expect(shortBackLabel(mealItem), 'Breakfast');
      expect(backTabIcon(skinItem), Icons.spa_rounded);
      expect(shortBackLabel(skinItem), 'Skin Care');
      expect(backTabIcon(commuteItem), Icons.directions_transit_rounded);
      expect(shortBackLabel(commuteItem), 'Commute');
    },
  );

  testWidgets(
    'Today line renders at required minute; non-Today owner omits it',
    (tester) async {
      const minute = 17 * 60 + 13; // 5:13 PM
      final layout = TimelineUtils.calculateVisibleRange([
        RoutineItem(
          id: 'morning',
          title: 'Morning',
          startMinute: 8 * 60,
          endMinute: 9 * 60,
          blockType: RoutineBlockType.hardBlock,
        ),
      ], requiredMinute: minute);
      expect(layout.isMinuteVisible(minute), isTrue);
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 400,
            height: 900,
            child: RoutineCurrentTimeLine(
              layout: TimelineLayout(
                visibleStartMinute: 480,
                visibleEndMinute: 1080,
              ),
              currentMinute: minute,
            ),
          ),
        ),
      );
      expect(find.text('5:13'), findsOneWidget);
      expect(find.textContaining('Now'), findsNothing);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SizedBox(
              width: 400,
              height: 900,
              child: RoutineTimelineViewport(
                items: const [],
                layout: layout,
                isToday: false,
                currentMinute: minute,
              ),
            ),
          ),
        ),
      );
      expect(find.text('5:13'), findsNothing);
    },
  );

  testWidgets(
    'current time between ticks (10:13): renders 10:13 left of rail, no Now, no AM/PM, exact Y, dashed line begins at rail',
    (tester) async {
      const minute = 10 * 60 + 13; // 613
      const layout = TimelineLayout(
        visibleStartMinute: 480,
        visibleEndMinute: 1080,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 400,
            height: 900,
            child: RoutineCurrentTimeLine(
              layout: layout,
              currentMinute: minute,
            ),
          ),
        ),
      );

      // Label assertions
      expect(find.text('10:13'), findsOneWidget);
      expect(find.textContaining('Now'), findsNothing);
      expect(find.textContaining('AM'), findsNothing);
      expect(find.textContaining('PM'), findsNothing);

      final labelRect = tester.getRect(find.text('10:13'));
      // Label sits strictly to the left of the rail
      expect(labelRect.right, lessThanOrEqualTo(kTimelineTimeRailWidth));
      expect(labelRect.right, lessThanOrEqualTo(kTimelineLabelRight));
      // Exact minute Y position is preserved
      final expectedY = layout.topForMinute(minute);
      expect(labelRect.center.dy, closeTo(expectedY, 1.0));

      // Live dot assertions
      final dotFinder = find.descendant(
        of: find.byType(RoutineCurrentTimeLine),
        matching: find.byType(Container),
      );
      expect(dotFinder, findsOneWidget);
      final dotRect = tester.getRect(dotFinder);
      // Small live dot aligned with vertical rail
      expect(dotRect.center.dx, closeTo(kTimelineRailX, 0.5));
      expect(dotRect.center.dy, closeTo(expectedY, 0.5));

      // Dashed line assertions
      final linePaintFinder = find.descendant(
        of: find.byType(RoutineCurrentTimeLine),
        matching: find.byType(CustomPaint),
      );
      expect(linePaintFinder, findsOneWidget);
      final lineRect = tester.getRect(linePaintFinder);
      // Begins at the vertical rail and extends right
      expect(lineRect.left, closeTo(kTimelineRailX, 0.5));
      expect(lineRect.right, greaterThan(kTimelineRailX));
      expect(lineRect.center.dy, closeTo(expectedY, 1.0));
    },
  );

  testWidgets(
    'current time exactly on a tick (10:20): no duplicate 10:20, no Now, exact Y preserved',
    (tester) async {
      const minute = 10 * 60 + 20; // 620
      const layout = TimelineLayout(
        visibleStartMinute: 480,
        visibleEndMinute: 1080,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 400,
            height: 900,
            child: RoutineCurrentTimeLine(
              layout: layout,
              currentMinute: minute,
            ),
          ),
        ),
      );

      // Must not render a separate live label (no duplicate 10:20)
      expect(
        find.descendant(
          of: find.byType(RoutineCurrentTimeLine),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(find.text('10:20'), findsNothing);
      expect(find.textContaining('Now'), findsNothing);

      // Dot and dashed line still render at exact Y position aligned with rail
      final expectedY = layout.topForMinute(minute);
      final dotFinder = find.descendant(
        of: find.byType(RoutineCurrentTimeLine),
        matching: find.byType(Container),
      );
      expect(dotFinder, findsOneWidget);
      final dotRect = tester.getRect(dotFinder);
      expect(dotRect.center.dx, closeTo(kTimelineRailX, 0.5));
      expect(dotRect.center.dy, closeTo(expectedY, 0.5));

      final linePaintFinder = find.descendant(
        of: find.byType(RoutineCurrentTimeLine),
        matching: find.byType(CustomPaint),
      );
      expect(linePaintFinder, findsOneWidget);
      final lineRect = tester.getRect(linePaintFinder);
      expect(lineRect.left, closeTo(kTimelineRailX, 0.5));
      expect(lineRect.center.dy, closeTo(expectedY, 1.0));
    },
  );

  test(
    'collision detection suppresses neighbouring tick labels only on visual overlap',
    () {
      const layout = TimelineLayout(
        visibleStartMinute: 480,
        visibleEndMinute: 1080,
      );

      // At 10:13 (613): distance to 10:10 (610) is 15px >= ~14px threshold -> false (not suppressed)
      expect(
        RoutineTimeRuler.shouldSuppressTickLabel(
          tickMinute: 610,
          currentMinute: 613,
          layout: layout,
        ),
        isFalse,
      );
      // At 10:13 (613): distance to 10:20 (620) is 35px >= ~14px threshold -> false (not suppressed)
      expect(
        RoutineTimeRuler.shouldSuppressTickLabel(
          tickMinute: 620,
          currentMinute: 613,
          layout: layout,
        ),
        isFalse,
      );

      // At 10:11 (611): distance to 10:10 (610) is 5px < threshold -> true (suppressed)
      expect(
        RoutineTimeRuler.shouldSuppressTickLabel(
          tickMinute: 610,
          currentMinute: 611,
          layout: layout,
        ),
        isTrue,
      );

      // At 10:19 (619): distance to 10:20 (620) is 5px < threshold -> true (suppressed)
      expect(
        RoutineTimeRuler.shouldSuppressTickLabel(
          tickMinute: 620,
          currentMinute: 619,
          layout: layout,
        ),
        isTrue,
      );

      // At 10:20 (620, on tick): is live tick -> false (not suppressed)
      expect(
        RoutineTimeRuler.shouldSuppressTickLabel(
          tickMinute: 620,
          currentMinute: 620,
          layout: layout,
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'viewport renders dashed line behind routine cards in background layer',
    (tester) async {
      final entry = legacyRoutineDayEntriesForTesting([
        RoutineItem(
          id: 'card-10am',
          title: 'Card at 10 AM',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.hardBlock,
        ),
      ]).single;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SizedBox(
              width: 400,
              height: 800,
              child: RoutineTimelineViewport(
                items: [entry],
                layout: const TimelineLayout(
                  visibleStartMinute: 540,
                  visibleEndMinute: 720,
                ),
                isToday: true,
                currentMinute: 613,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the inner Stack that holds ruler, current time line, and cards
      final stackFinder = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Stack),
      );
      expect(stackFinder, findsWidgets);
      final stack = tester.widget<Stack>(stackFinder.first);

      var liveLineIndex = -1;
      var cardIndex = -1;
      for (var i = 0; i < stack.children.length; i++) {
        final child = stack.children[i];
        if (child is Positioned) {
          final inner = child.child;
          if (inner is RepaintBoundary && inner.child is IgnorePointer) {
            final target = (inner.child as IgnorePointer).child;
            if (target is RoutineCurrentTimeLine) {
              liveLineIndex = i;
            }
          }
        }
        if (child.key == const ValueKey('routine-timeline-card-card-10am')) {
          cardIndex = i;
        }
      }

      expect(liveLineIndex, isNot(-1));
      expect(cardIndex, isNot(-1));
      expect(
        liveLineIndex,
        lessThan(cardIndex),
        reason: 'Live time line must render before routine cards in Stack',
      );
    },
  );

  testWidgets(
    'routine timeline blocks and current time indicator have zero shadow',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoutineCardBase(
              railColor: Colors.blue,
              child: Text('Routine Card'),
            ),
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(TimelineCardChrome),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);
      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.boxShadow,
        isNull,
        reason: 'Routine timeline cards must not have any boxShadow',
      );

      // Verify RoutineCurrentTimeLine dot has no shadow
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoutineCurrentTimeLine(
              layout: TimelineLayout(
                visibleStartMinute: 480,
                visibleEndMinute: 1080,
              ),
              currentMinute: 500,
            ),
          ),
        ),
      );

      final dotContainerFinder = find.descendant(
        of: find.byType(RoutineCurrentTimeLine),
        matching: find.byType(Container),
      );
      expect(dotContainerFinder, findsOneWidget);
      final dotContainer = tester.widget<Container>(dotContainerFinder);
      final dotDecoration = dotContainer.decoration as BoxDecoration;
      expect(
        dotDecoration.boxShadow,
        isNull,
        reason: 'Current time dot must not have any boxShadow',
      );

      // Verify Onboarding accentTinted mode still preserves shadow
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TimelineCardChrome(
              baseColor: Colors.blue,
              surfaceMode: TimelineCardSurfaceMode.accentTinted,
              child: Text('Onboarding Card'),
            ),
          ),
        ),
      );

      final onboardingContainerFinder = find.descendant(
        of: find.byType(TimelineCardChrome),
        matching: find.byType(Container),
      );
      final onboardingContainer = tester.widget<Container>(
        onboardingContainerFinder.first,
      );
      final onboardingDecoration =
          onboardingContainer.decoration as BoxDecoration;
      expect(
        onboardingDecoration.boxShadow,
        isNotNull,
        reason: 'Onboarding cards should retain their boxShadow',
      );
    },
  );

  testWidgets('verified source tokens hide while legitimate notes render', (
    tester,
  ) async {
    final leaked = _projected(
      'fixed:default',
      category: RoutineCategory.identity,
    ).copyWith(notes: 'identity_system');
    final legitimate = leaked.copyWith(
      id: 'legitimate',
      onboardingSourceItemId: 'legitimate-source',
      notes: 'Practice before dinner',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Expanded(child: RoutineRichTimelineCard(item: leaked)),
            Expanded(child: RoutineRichTimelineCard(item: legitimate)),
          ],
        ),
      ),
    );
    expect(find.text('identity_system'), findsNothing);
    expect(find.text('Practice before dinner'), findsOneWidget);
  });

  testWidgets('unrelated pending-state rebuild reuses prepared layout', (
    tester,
  ) async {
    RoutinePreparedTimelineLayout.resetDebugInstrumentation();
    final notifierKey = GlobalKey<_PendingHarnessState>();
    final entry = legacyRoutineDayEntriesForTesting([
      RoutineItem(
        id: 'cached-card',
        title: 'Cached card',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
      ),
    ]).single;
    await tester.pumpWidget(_PendingHarness(key: notifierKey, entry: entry));
    await tester.pumpAndSettle();
    expect(RoutinePreparedTimelineLayout.debugPreparationCount, 1);
    notifierKey.currentState!.rebuild();
    await tester.pump();
    expect(RoutinePreparedTimelineLayout.debugPreparationCount, 1);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('last card scrolls fully above floating navigation reserve', (
    tester,
  ) async {
    final entry = legacyRoutineDayEntriesForTesting([
      RoutineItem(
        id: 'last-card',
        userId: 'scroll-user',
        title: 'Last card',
        startMinute: 22 * 60,
        endMinute: 23 * 60,
        blockType: RoutineBlockType.flexibleTask,
      ),
    ]).single;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: RoutineTimelineViewport(
              items: [entry],
              layout: const TimelineLayout(
                visibleStartMinute: 8 * 60,
                visibleEndMinute: 24 * 60,
              ),
              isToday: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();

    final cardBottom = tester
        .getBottomLeft(
          find.byKey(const ValueKey('routine-timeline-card-last-card')),
        )
        .dy;
    expect(cardBottom, lessThanOrEqualTo(440));
  });
}

class _PendingHarness extends StatefulWidget {
  final RoutineDayEntry entry;
  const _PendingHarness({super.key, required this.entry});

  @override
  State<_PendingHarness> createState() => _PendingHarnessState();
}

class _PendingHarnessState extends State<_PendingHarness> {
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: RoutineTimelineViewport(
            items: [widget.entry],
            layout: const TimelineLayout(
              visibleStartMinute: 540,
              visibleEndMinute: 720,
            ),
            isToday: false,
          ),
        ),
      ),
    );
  }
}

RoutineItem _projected(
  String key, {
  RoutineCategory category = RoutineCategory.classBlock,
}) {
  return RoutineItem(
    id: 'projected-${key.replaceAll(':', '-')}',
    userId: 'visual-user',
    title: 'Projected',
    startMinute: 600,
    endMinute: 660,
    repeatDays: const [DateTime.monday],
    blockType: RoutineBlockType.hardBlock,
    category: category,
    source: RoutineSource.onboarding,
    onboardingProjectionId: 'onboarding-initial-v1',
    onboardingSourceItemId: 'source-$key',
    onboardingVisualStyleKey: key,
  );
}

OnboardingCompletionBundle _bundle(String uid) {
  final now = DateTime.utc(2026, 9, 14);
  final blocks = [
    const TimelineBlockDraft(
      id: 'class-source',
      section: 'classes',
      title: 'Algorithms',
      startMinute: 600,
      endMinute: 660,
      repeatDays: [DateTime.monday],
      blockType: TimelineBlockDraft.hardBlockKey,
      professor: 'Professor Ada',
      courseCode: 'CS101',
      classType: 'Lecture',
      sectionLabel: 'A',
    ),
    const TimelineBlockDraft(
      id: 'work-source',
      section: 'job_work_business',
      title: 'Office',
      startMinute: 720,
      endMinute: 780,
      repeatDays: [DateTime.monday],
      blockType: TimelineBlockDraft.hardBlockKey,
    ),
  ];
  final items = [
    RoutineItem(
      id: 'class-source',
      userId: uid,
      title: 'Algorithms',
      startMinute: 600,
      endMinute: 660,
      repeatDays: const [DateTime.monday],
      blockType: RoutineBlockType.hardBlock,
      category: RoutineCategory.classBlock,
      source: RoutineSource.onboarding,
      baseTimelineSection: 'classes',
      professor: 'Professor Ada',
      courseCode: 'CS101',
      classType: 'Lecture',
      sectionLabel: 'A',
    ),
    RoutineItem(
      id: 'work-source',
      userId: uid,
      title: 'Office',
      startMinute: 720,
      endMinute: 780,
      repeatDays: const [DateTime.monday],
      blockType: RoutineBlockType.hardBlock,
      category: RoutineCategory.job,
      source: RoutineSource.onboarding,
      baseTimelineSection: 'job_work_business',
    ),
    RoutineItem(
      id: 'identity-source',
      userId: uid,
      title: 'Language practice',
      startMinute: 840,
      endMinute: 850,
      repeatDays: const [DateTime.monday],
      blockType: RoutineBlockType.flexibleTask,
      category: RoutineCategory.identity,
      source: RoutineSource.onboarding,
      notes: 'identity_system',
    ),
  ];
  return OnboardingCompletionBundle(
    uid: uid,
    createdAt: now,
    updatedAt: now,
    userProfilePatch: const {'onboardingCompleted': true},
    baseTimelineBlocks: blocks,
    finalTimelineItems: const [],
    routineItemsForApp: items,
    goodHabitTemplates: const [],
    badHabitCheckIns: const [],
    identityGoalSystems: const [],
    notificationPreferences: NotificationPreferences(),
    coachPreferences: CoachPreferences(),
    moneyGoal: null,
    uploadedAssetReferences: const [],
    warnings: const [],
    duplicateSystemKeysMerged: const [],
  );
}
