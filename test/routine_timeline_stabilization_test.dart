import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/cards/routine_rich_timeline_card.dart';
import 'package:optivus/features/routine/widgets/routine_current_time_line.dart';
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
      const minute = 17 * 60;
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
      expect(find.text('Now — 5:00 PM'), findsOneWidget);

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
      expect(find.text('Now — 5:00 PM'), findsNothing);
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
