import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

class FailingRoutineHistoryRepository extends FakeRoutineHistoryRepository {
  int failCount;
  int failStartAt;
  int delayMs;
  int _currentFails = 0;
  int appendCallCount = 0;

  FailingRoutineHistoryRepository(
    this.failCount, {
    this.failStartAt = 0,
    this.delayMs = 0,
  });

  @override
  Future<void> appendHistory(String uid, RoutineOccurrenceRecord record) async {
    final callIndex = appendCallCount;
    appendCallCount++;
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    if (callIndex >= failStartAt && _currentFails < failCount) {
      _currentFails++;
      throw Exception('network error');
    }
    return super.appendHistory(uid, record);
  }

  @override
  Future<void> deleteHistory(String uid, String occurrenceId) async {
    final callIndex = appendCallCount;
    appendCallCount++;
    if (callIndex >= failStartAt && _currentFails < failCount) {
      _currentFails++;
      throw Exception('network error');
    }
    return super.deleteHistory(uid, occurrenceId);
  }
}

void main() {
  late ProviderContainer container;
  late FakeRoutineRepository repo;
  late FakeRoutineDatabase database;
  late FailingRoutineHistoryRepository historyRepo;
  late FakeRoutineTransactionRepository transactionRepo;

  setUp(() {
    database = FakeRoutineDatabase();
    repo = FakeRoutineRepository(database: database);
    historyRepo = FailingRoutineHistoryRepository(0);
    transactionRepo = FakeRoutineTransactionRepository(
      routineRepository: repo,
      historyRepository: historyRepo,
    );

    container = ProviderContainer(
      overrides: [
        optivusBackendModeProvider.overrideWithValue(
          OptivusBackendMode.firebase,
        ),
        routineRepositoryProvider.overrideWithValue(repo),
        routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
        routineTransactionRepositoryProvider.overrideWithValue(transactionRepo),
      ],
    );
    addTearDown(container.dispose);
  });

  RoutineItem createTemplate(String uid, String id) {
    return RoutineItem(
      id: id,
      userId: uid,
      title: 'T',
      startMinute: 600,
      endMinute: 660,
      blockType: RoutineBlockType.flexibleTask,
    );
  }

  RoutineOccurrenceRecord onboardingOccurrence({
    required String uid,
    required String itemId,
    required DateTime date,
  }) {
    final dateKey = routineLocalDateKey(date);
    return RoutineOccurrenceRecord(
      id: stableRoutineOccurrenceId(
        ownerUid: uid,
        routineItemId: itemId,
        occurrenceDateKey: dateKey,
      ),
      ownerUid: uid,
      routineItemId: itemId,
      occurrenceDateKey: dateKey,
      status: RoutineStatus.active,
      source: 'onboarding',
      action: 'project',
      operationKey: 'onboarding_project_$itemId',
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
      onboardingProjectionId: 'onboarding-initial-v1',
      onboardingSourceItemId: 'source-$itemId',
      sourceFingerprint:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
  }

  Future<void> waitForPending() async {
    while (container
        .read(routineNotifierProvider)
        .pendingOccurrenceIds
        .isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  test('Start, complete, skip, missed actions', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.startFlexibleTask('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    var occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'start').length, 1);

    notifier.markCompleted('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'complete').length, 1);

    notifier.markSkipped('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'skip').length, 1);

    notifier.markMissed('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'miss').length, 1);

    final state = container.read(routineNotifierProvider);
    expect(state.items.length, 1);
    expect(state.items.first.id, 't1');
  });

  test('generic Start is idempotent after save', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    final first = await notifier.startFlexibleTask('t1');
    await waitForPending();
    final afterFirst = container.read(routineNotifierProvider);
    final started = afterFirst.occurrences.single;
    expect(first.outcome, RoutineWriteOutcome.saved);
    expect(started.status, RoutineStatus.active);
    expect(started.startedAt, isNotNull);
    expect(started.countdownDurationSeconds, 3600);

    final second = await notifier.startFlexibleTask('t1');
    await waitForPending();
    final afterSecond = container.read(routineNotifierProvider);

    expect(second.outcome, RoutineWriteOutcome.noOp);
    expect(afterSecond.occurrences, hasLength(1));
    expect(afterSecond.occurrences.single.startedAt, started.startedAt);
    expect(
      afterSecond.occurrences.single.countdownDurationSeconds,
      started.countdownDurationSeconds,
    );
    expect(
      afterSecond.events
          .where((event) => event.eventType == RoutineEventType.started)
          .length,
      1,
    );
  });

  void expectOnboardingProvenance(
    RoutineOccurrenceRecord record, {
    required String itemId,
  }) {
    expect(record.source, 'onboarding');
    expect(record.onboardingProjectionId, 'onboarding-initial-v1');
    expect(record.onboardingSourceItemId, 'source-$itemId');
    expect(
      record.sourceFingerprint,
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
  }

  test(
    'UI action paths preserve onboarding occurrence provenance and event origin',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      final date = DateTime(2026, 9, 16);
      final templates = {
        't_start': createTemplate(uid, 't_start'),
        't_done': createTemplate(uid, 't_done'),
        't_move': createTemplate(uid, 't_move'),
        't_reschedule': createTemplate(uid, 't_reschedule'),
        't_tracker': createTemplate(uid, 't_tracker').copyWith(
          blockType: RoutineBlockType.trackerTask,
          trackerType: TrackerType.focus,
        ),
        't_money': createTemplate(
          uid,
          't_money',
        ).copyWith(blockType: RoutineBlockType.moneyTask),
        't_checkin': createTemplate(uid, 't_checkin').copyWith(
          blockType: RoutineBlockType.checkIn,
          category: RoutineCategory.badHabit,
        ),
      };
      for (final entry in templates.entries) {
        await repo.createRoutineItem(uid, entry.value);
        await historyRepo.appendHistory(
          uid,
          onboardingOccurrence(uid: uid, itemId: entry.key, date: date),
        );
      }
      await notifier.loadForOwner(uid);

      await notifier.startFlexibleTask('t_start', occurrenceDate: date);
      await waitForPending();
      await notifier.markCompleted('t_done', occurrenceDate: date);
      await waitForPending();
      await notifier.moveItem(
        itemId: 't_move',
        date: date,
        startMinute: 13 * 60,
        durationMinutes: 30,
        occurrenceDate: date,
      );
      await waitForPending();
      await notifier.moveItem(
        itemId: 't_reschedule',
        date: date.add(const Duration(days: 1)),
        startMinute: 14 * 60,
        durationMinutes: 30,
        occurrenceDate: date,
      );
      await waitForPending();
      await notifier.startRoutineItem('t_tracker', occurrenceDate: date);
      await waitForPending();
      await notifier.completeRoutineItem('t_money', occurrenceDate: date);
      await waitForPending();
      await notifier.checkIn('t_checkin', 'Avoided', occurrenceDate: date);
      await waitForPending();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(routineNotifierProvider);
      final recordsByItemId = {
        for (final occurrence in state.occurrences)
          occurrence.routineItemId: occurrence,
      };
      for (final itemId in templates.keys) {
        expectOnboardingProvenance(recordsByItemId[itemId]!, itemId: itemId);
      }
      expect(recordsByItemId['t_start']!.action, 'start');
      expect(recordsByItemId['t_done']!.action, 'complete');
      expect(recordsByItemId['t_move']!.action, 'move');
      expect(recordsByItemId['t_reschedule']!.action, 'reschedule');
      expect(recordsByItemId['t_tracker']!.action, 'startTracker');
      expect(recordsByItemId['t_money']!.action, 'complete');
      expect(recordsByItemId['t_checkin']!.action, 'checkIn');

      final eventsByItemId = {
        for (final event in state.events) event.routineItemId: event,
      };
      expect(eventsByItemId['t_start']!.source, 'routine');
      expect(eventsByItemId['t_start']!.eventType, RoutineEventType.started);
      expect(eventsByItemId['t_done']!.source, 'routine');
      expect(eventsByItemId['t_done']!.eventType, RoutineEventType.completed);
      expect(eventsByItemId['t_move']!.source, 'routine');
      expect(eventsByItemId['t_move']!.eventType, RoutineEventType.moved);
      expect(eventsByItemId['t_reschedule']!.source, 'routine');
      expect(
        eventsByItemId['t_reschedule']!.eventType,
        RoutineEventType.rescheduled,
      );
      expect(eventsByItemId['t_tracker']!.source, 'tracker');
      expect(eventsByItemId['t_tracker']!.eventType, RoutineEventType.started);
      expect(eventsByItemId['t_money']!.source, 'money');
      expect(eventsByItemId['t_money']!.eventType, RoutineEventType.completed);
      expect(eventsByItemId['t_checkin']!.source, 'checkIn');
    },
  );

  test(
    'new non-onboarding occurrence does not fabricate projection metadata',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
      await notifier.loadForOwner(uid);

      await notifier.startRoutineItem('t1');
      await waitForPending();

      final occurrence = container
          .read(routineNotifierProvider)
          .occurrences
          .single;
      expect(occurrence.source, 'routine');
      expect(occurrence.onboardingProjectionId, isNull);
      expect(occurrence.onboardingSourceItemId, isNull);
      expect(occurrence.sourceFingerprint, isNull);
    },
  );

  test(
    'transient failure retry preserves onboarding occurrence provenance',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      final date = DateTime(2026, 9, 16);
      await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
      await historyRepo.appendHistory(
        uid,
        onboardingOccurrence(uid: uid, itemId: 't1', date: date),
      );
      await notifier.loadForOwner(uid);
      historyRepo.failCount = 1;

      final result = await notifier.markCompleted('t1', occurrenceDate: date);
      await waitForPending();
      expect(result.outcome, RoutineWriteOutcome.retryRequired);
      final failedIntent = container
          .read(routineNotifierProvider)
          .failedOccurrenceIntentsById
          .values
          .single;
      expectOnboardingProvenance(failedIntent.attemptedRecord, itemId: 't1');

      final retryResult = await notifier.retryFailedOccurrenceAction(
        failedIntent.occurrenceId,
      );
      await waitForPending();

      expect(retryResult.outcome, RoutineWriteOutcome.saved);
      final state = container.read(routineNotifierProvider);
      expect(state.failedOccurrenceIntentsById, isEmpty);
      expectOnboardingProvenance(state.occurrences.single, itemId: 't1');
      expect(state.occurrences.single.action, 'complete');
    },
  );

  test(
    'tracker links target moved-in and native occurrences independently',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      final template = createTemplate(uid, 'tracker-template').copyWith(
        blockType: RoutineBlockType.trackerTask,
        trackerType: TrackerType.focus,
        repeatDays: const [DateTime.wednesday],
      );
      await repo.createRoutineItem(uid, template);
      await notifier.loadForOwner(uid);

      final movedDate = DateTime(2026, 9, 15);
      final nativeDate = DateTime(2026, 9, 16);

      await notifier.startTrackerTask(template, occurrenceDate: movedDate);
      await waitForPending();
      await notifier.startTrackerTask(template, occurrenceDate: nativeDate);
      await waitForPending();

      var links = container.read(trackerSessionLinksProvider);
      expect(links, hasLength(2));
      expect(links.map((link) => link.occurrenceDateKey).toSet(), {
        '2026-09-15',
        '2026-09-16',
      });
      expect(
        container
            .read(routineNotifierProvider)
            .activeTrackerLaunchIntent
            ?.occurrenceDateKey,
        '2026-09-16',
      );

      await notifier.completeTrackerSession(
        template.id,
        occurrenceDate: movedDate,
      );
      await waitForPending();

      links = container.read(trackerSessionLinksProvider);
      expect(
        links
            .singleWhere((link) => link.occurrenceDateKey == '2026-09-15')
            .status,
        'completed',
      );
      expect(
        links
            .singleWhere((link) => link.occurrenceDateKey == '2026-09-16')
            .status,
        'active',
      );
      expect(
        container
            .read(routineNotifierProvider)
            .activeTrackerLaunchIntent
            ?.occurrenceDateKey,
        '2026-09-16',
      );

      await notifier.completeTrackerSession(
        template.id,
        occurrenceDate: nativeDate,
      );
      await waitForPending();

      expect(
        container.read(routineNotifierProvider).activeTrackerLaunchIntent,
        isNull,
      );
      expect(
        container
            .read(routineNotifierProvider)
            .occurrences
            .where(
              (occurrence) => occurrence.status == RoutineStatus.completed,
            ),
        hasLength(2),
      );
    },
  );

  test('failed tracker Start creates no ghost session state', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    final template = createTemplate(uid, 'tracker-template').copyWith(
      blockType: RoutineBlockType.trackerTask,
      trackerType: TrackerType.focus,
    );
    await repo.createRoutineItem(uid, template);
    await notifier.loadForOwner(uid);
    historyRepo.failCount = 1;

    final result = await notifier.startRoutineItem(template.id);
    await waitForPending();

    expect(result.outcome, RoutineWriteOutcome.retryRequired);
    expect(container.read(trackerSessionLinksProvider), isEmpty);
    expect(
      container.read(routineNotifierProvider).activeTrackerLaunchIntent,
      isNull,
    );
    expect(container.read(appNavigationProvider), 0);
  });

  test(
    'successful tracker Start creates session state after persistence',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      final template = createTemplate(uid, 'tracker-template').copyWith(
        blockType: RoutineBlockType.trackerTask,
        trackerType: TrackerType.focus,
      );
      await repo.createRoutineItem(uid, template);
      await notifier.loadForOwner(uid);

      final result = await notifier.startRoutineItem(template.id);
      await waitForPending();

      expect(result.outcome, RoutineWriteOutcome.saved);
      expect(container.read(trackerSessionLinksProvider), hasLength(1));
      expect(
        container.read(routineNotifierProvider).activeTrackerLaunchIntent,
        isNotNull,
      );
      expect(container.read(appNavigationProvider), 2);
    },
  );

  test('failed tracker completion leaves active link unchanged', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    final template = createTemplate(uid, 'tracker-template').copyWith(
      blockType: RoutineBlockType.trackerTask,
      trackerType: TrackerType.focus,
    );
    await repo.createRoutineItem(uid, template);
    await notifier.loadForOwner(uid);
    await notifier.startRoutineItem(template.id);
    await waitForPending();
    historyRepo.failCount = 1;
    historyRepo.failStartAt = historyRepo.appendCallCount;

    final result = await notifier.completeRoutineItem(template.id);
    await waitForPending();

    expect(result.outcome, RoutineWriteOutcome.retryRequired);
    final link = container.read(trackerSessionLinksProvider).single;
    expect(link.status, 'active');
    expect(link.completedAt, isNull);
    expect(
      container.read(routineNotifierProvider).activeTrackerLaunchIntent,
      isNotNull,
    );
  });

  test(
    'successful tracker completion completes link after persistence',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      final template = createTemplate(uid, 'tracker-template').copyWith(
        blockType: RoutineBlockType.trackerTask,
        trackerType: TrackerType.focus,
      );
      await repo.createRoutineItem(uid, template);
      await notifier.loadForOwner(uid);
      await notifier.startRoutineItem(template.id);
      await waitForPending();

      final result = await notifier.completeRoutineItem(template.id);
      await waitForPending();

      expect(result.outcome, RoutineWriteOutcome.saved);
      final link = container.read(trackerSessionLinksProvider).single;
      expect(link.status, 'completed');
      expect(link.completedAt, isNotNull);
      expect(
        container.read(routineNotifierProvider).activeTrackerLaunchIntent,
        isNull,
      );
    },
  );

  test('Move later (same date)', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    final item = container.read(routineNotifierProvider).items.first;
    notifier.moveItem(
      itemId: item.id,
      date: container.read(routineNotifierProvider).selectedDay,
      startMinute: 60,
      durationMinutes: 60,
    );
    await Future.delayed(const Duration(milliseconds: 50));

    final occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.length, 1);
    expect(occurrences.first.action, 'move');
    expect(occurrences.first.movedToDateKey, isNotNull);
  });

  test('Reschedule (different date)', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.moveToTomorrow(
      container.read(routineNotifierProvider).items.first,
    );
    await Future.delayed(const Duration(milliseconds: 50));

    final occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.length, 1);
    expect(occurrences.first.action, 'reschedule');
    expect(occurrences.first.movedToDateKey, isNotNull);
  });

  test(
    'find-free-slot excludes only the targeted occurrence, not a moved-in sibling',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      final template = createTemplate(
        uid,
        'same_template',
      ).copyWith(startMinute: 8 * 60, endMinute: 9 * 60, repeatDays: const [3]);
      await repo.createRoutineItem(uid, template);
      await historyRepo.appendHistory(
        uid,
        RoutineOccurrenceRecord(
          id: 'moved_sibling',
          ownerUid: uid,
          routineItemId: template.id,
          source: 'routine',
          action: 'move',
          operationKey: 'move_sibling',
          occurrenceDateKey: '2026-09-14',
          movedToDateKey: '2026-09-16',
          movedStartMinute: 6 * 60,
          movedEndMinute: 7 * 60,
          status: RoutineStatus.moved,
          createdAt: DateTime(2026, 9, 14),
          updatedAt: DateTime(2026, 9, 14),
        ),
      );
      await notifier.loadForOwner(uid);

      final slot = notifier.findFreeSlot(
        item: template,
        date: DateTime(2026, 9, 16),
        occurrenceDate: DateTime(2026, 9, 16),
      );

      expect(slot, 7 * 60);
    },
  );

  test('Undo-to-planned', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.startFlexibleTask('t1');
    await Future.delayed(const Duration(milliseconds: 50));

    expect(container.read(routineNotifierProvider).occurrences.length, 1);

    await notifier.undoOccurrenceAction('t1');
    await Future.delayed(const Duration(milliseconds: 50));

    expect(container.read(routineNotifierProvider).occurrences.length, 0);

    await notifier.loadForOwner(uid);
    expect(container.read(routineNotifierProvider).occurrences.length, 0);
  });

  test('Undo blocked when not undoToPlannedAllowed', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    expect(
      container
          .read(routineNotifierProvider)
          .occurrences
          .last
          .undoToPlannedAllowed,
      true,
    );

    notifier.markSkipped('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    expect(
      container
          .read(routineNotifierProvider)
          .occurrences
          .last
          .undoToPlannedAllowed,
      false,
    );
    expect(
      container.read(routineNotifierProvider).occurrences.last.action,
      'skip',
    );

    await notifier.undoOccurrenceAction('t1');
    await Future.delayed(const Duration(milliseconds: 50));

    expect(
      container.read(routineNotifierProvider).occurrences.last.action,
      'skip',
    );
  });

  test('Duplicate tap serialization', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');
    notifier.markCompleted('t1');
    await Future.delayed(const Duration(milliseconds: 50));

    expect(container.read(routineNotifierProvider).occurrences.length, 1);
  });

  test('Failure and retry', () async {
    historyRepo.failCount = 1;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');
    await Future.delayed(const Duration(milliseconds: 50));

    final state = container.read(routineNotifierProvider);
    expect(state.failedOccurrenceIntentsById, isNotEmpty);

    final intent = state.failedOccurrenceIntentsById.values.first;
    await notifier.retryFailedOccurrenceAction(intent.occurrenceId);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(
      container.read(routineNotifierProvider).failedOccurrenceIntentsById,
      isEmpty,
    );
    expect(container.read(routineNotifierProvider).occurrences.length, 1);
  });

  test('deleteHistory idempotent', () async {
    const uid = 'user_1';
    await expectLater(
      historyRepo.deleteHistory(uid, 'nonexistent_id'),
      completes,
    );
  });

  test('Account switch during pending', () async {
    historyRepo.failCount = 999;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');
    // Don't wait for completion

    notifier.resetForSignedOut();
    expect(
      container.read(routineNotifierProvider).pendingOccurrenceIds,
      isEmpty,
    );
  });

  test('Reload during pending', () async {
    historyRepo.failCount = 0;
    historyRepo.delayMs = 100;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');

    await notifier.loadForOwner(uid);
    expect(
      container.read(routineNotifierProvider).pendingOccurrenceIds,
      isNotEmpty,
    );
    await waitForPending();
  });

  test('Two identical rapid completion actions', () async {
    historyRepo.delayMs = 50;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');
    notifier.markCompleted('t1');
    await waitForPending();

    expect(historyRepo.appendCallCount, 1);
  });

  test('Two different rapid move actions', () async {
    historyRepo.delayMs = 50;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    final item = container.read(routineNotifierProvider).items.first;

    notifier.moveToTomorrow(item);
    notifier.moveItem(
      itemId: item.id,
      date: container.read(routineNotifierProvider).selectedDay,
      startMinute: 60,
      durationMinutes: 60,
    );
    await waitForPending();

    final occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.routineItemId == 't1').length, 1);
    expect(occurrences.last.action, 'move');
  });

  test('Account switch while queued actions exist', () async {
    historyRepo.delayMs = 50;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.startFlexibleTask('t1');
    notifier.resetForSignedOut();

    await waitForPending();
    final state = container.read(routineNotifierProvider);
    expect(state.queuedOccurrenceIntentsById, isEmpty);
  });

  test('First action fails and a newer queued action succeeds', () async {
    historyRepo.failCount = 1;
    historyRepo.failStartAt = 0;
    historyRepo.delayMs = 50;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.startFlexibleTask('t1');
    notifier.markCompleted('t1');
    await waitForPending();

    final state = container.read(routineNotifierProvider);
    expect(state.failedOccurrenceIntentsById, isEmpty);
    final occurrences = state.occurrences.where((o) => o.routineItemId == 't1');
    expect(occurrences.last.action, 'complete');
  });

  test('Latest queued action fails', () async {
    historyRepo.failCount = 1;
    historyRepo.failStartAt = 1;
    historyRepo.delayMs = 50;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.startFlexibleTask('t1');
    notifier.markCompleted('t1');
    await waitForPending();

    final state = container.read(routineNotifierProvider);
    expect(state.failedOccurrenceIntentsById, isNotEmpty);

    final occurrences = state.occurrences.where((o) => o.routineItemId == 't1');
    expect(occurrences.last.action, 'start');
  });
}
