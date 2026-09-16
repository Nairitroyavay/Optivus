import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/sheets/routine_move_sheet.dart';
import 'package:optivus/features/routine/services/routine_action_executor.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_actions.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
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
    await repo.createRoutineItem(uid, createTemplate(uid, 't2'));
    await repo.createRoutineItem(uid, createTemplate(uid, 't3'));
    await notifier.loadForOwner(uid);

    notifier.startFlexibleTask('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    var occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'start').length, 1);

    notifier.markCompleted('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'complete').length, 1);

    notifier.markSkipped('t2');
    await Future.delayed(const Duration(milliseconds: 50));
    occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'skip').length, 1);

    notifier.markMissed('t3');
    await Future.delayed(const Duration(milliseconds: 50));
    occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'miss').length, 1);

    final state = container.read(routineNotifierProvider);
    expect(state.items.length, 3);
    expect(state.items.map((i) => i.id), containsAll(['t1', 't2', 't3']));
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
      expect(recordsByItemId['t_start']!.action, 'project');
      expect(recordsByItemId['t_done']!.action, 'complete');
      expect(recordsByItemId['t_move']!.action, 'move');
      expect(recordsByItemId['t_reschedule']!.action, 'reschedule');
      expect(recordsByItemId['t_tracker']!.action, 'project');
      expect(recordsByItemId['t_money']!.action, 'complete');
      expect(recordsByItemId['t_checkin']!.action, 'checkIn');

      final eventsByItemId = {
        for (final event in state.events) event.routineItemId: event,
      };
      expect(eventsByItemId['t_start'], isNull);
      expect(eventsByItemId['t_done']!.source, 'routine');
      expect(eventsByItemId['t_done']!.eventType, RoutineEventType.completed);
      expect(eventsByItemId['t_move']!.source, 'routine');
      expect(eventsByItemId['t_move']!.eventType, RoutineEventType.moved);
      expect(eventsByItemId['t_reschedule']!.source, 'routine');
      expect(
        eventsByItemId['t_reschedule']!.eventType,
        RoutineEventType.rescheduled,
      );
      expect(eventsByItemId['t_tracker'], isNull);
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

    notifier.startFlexibleTask('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    expect(
      container
          .read(routineNotifierProvider)
          .occurrences
          .last
          .undoToPlannedAllowed,
      true,
    );

    notifier.markCompleted('t1');
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
      'complete',
    );

    await notifier.undoOccurrenceAction('t1');
    await Future.delayed(const Duration(milliseconds: 50));

    expect(
      container.read(routineNotifierProvider).occurrences.last.action,
      'complete',
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
    historyRepo.delayMs = 50;
    final notifier = container.read(routineNotifierProvider.notifier);
    const ownerA = 'user_1';
    const ownerB = 'user_2';
    await repo.createRoutineItem(ownerA, createTemplate(ownerA, 't1'));
    await notifier.loadForOwner(ownerA);

    final pending = notifier.markCompleted('t1');

    notifier.resetForSignedOut();
    final result = await pending;
    await notifier.loadForOwner(ownerB);

    expect(result.outcome, RoutineWriteOutcome.superseded);
    expect(result.failureCategory, RoutineFailureCategory.ownerSuperseded);
    expect(result.resultingStatus, isNull);
    expect(notifier.ownerUid, ownerB);
    expect(
      container
          .read(routineNotifierProvider)
          .occurrences
          .where((entry) => entry.ownerUid == ownerA),
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

  test('Start on active item returns noOp with alreadyActive', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    final first = await notifier.startFlexibleTask('t1');
    await waitForPending();
    expect(first.outcome, RoutineWriteOutcome.saved);

    final second = await notifier.startFlexibleTask('t1');
    expect(second.outcome, RoutineWriteOutcome.noOp);
    expect(second.failureCategory, RoutineFailureCategory.alreadyActive);
    expect(second.resultingStatus, RoutineStatus.active);
  });

  test('Active occurrence without timer metadata cannot Start again', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    final item = createTemplate(uid, 't_active_legacy');
    final date = DateTime(2026, 9, 10);
    await repo.createRoutineItem(uid, item);
    await historyRepo.appendHistory(
      uid,
      RoutineOccurrenceRecord(
        id: stableRoutineOccurrenceId(
          ownerUid: uid,
          routineItemId: item.id,
          occurrenceDateKey: routineLocalDateKey(date),
        ),
        ownerUid: uid,
        routineItemId: item.id,
        occurrenceDateKey: routineLocalDateKey(date),
        status: RoutineStatus.active,
        source: 'routine',
        action: 'start',
        operationKey: 'legacy-active-no-timer',
        createdAt: DateTime.utc(2026, 9, 10),
        updatedAt: DateTime.utc(2026, 9, 10),
      ),
    );
    await notifier.loadForOwner(uid);
    final eventsBefore = container.read(routineNotifierProvider).events.length;

    final result = await notifier.startRoutineItem(
      item.id,
      occurrenceDate: date,
    );

    expect(result.outcome, RoutineWriteOutcome.noOp);
    expect(result.failureCategory, RoutineFailureCategory.alreadyActive);
    expect(result.resultingStatus, RoutineStatus.active);
    expect(container.read(routineNotifierProvider).events.length, eventsBefore);
    final occurrence = container
        .read(routineNotifierProvider)
        .occurrences
        .single;
    expect(occurrence.startedAt, isNull);
    expect(occurrence.countdownDurationSeconds, isNull);
  });

  testWidgets('Executor observes immutable exact-operation metadata', (
    tester,
  ) async {
    const uid = 'user_a';
    final item = createTemplate(uid, 't_observed');
    await repo.createRoutineItem(uid, item);
    await container.read(routineNotifierProvider.notifier).loadForOwner(uid);
    RoutineActionExecutionObservation? observation;
    RoutineActionExecutor.observer = (value) => observation = value;
    addTearDown(() => RoutineActionExecutor.observer = null);
    final actionContext = RoutineActionContext(
      instanceId: 's:t_observed:2026-09-20',
      templateId: item.id,
      occurrenceDateKey: '2026-09-20',
      displayDateKey: '2026-09-20',
      kind: RoutineDayEntryKind.scheduled,
      item: item,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () {
                  RoutineActionExecutor.execute(
                    ref: ref,
                    actionContext: actionContext,
                    action: RoutineOccurrenceAction.start,
                    perform: () => Future.value(
                      const RoutineWriteResult.saved(
                        operationId: 'op-observed',
                        resultingStatus: RoutineStatus.active,
                      ),
                    ),
                    showFeedback: false,
                  );
                },
                child: const Text('Execute'),
              ),
            ),
          ),
        ),
      ),
    );
    await container.read(routineNotifierProvider.notifier).loadForOwner(uid);
    await tester.tap(find.text('Execute'));
    await tester.pumpAndSettle();

    expect(observation?.ownerUidAtStart, uid);
    expect(observation?.instanceId, actionContext.instanceId);
    expect(observation?.occurrenceDateKey, '2026-09-20');
    expect(observation?.oldStatus, RoutineStatus.planned);
    expect(observation?.requestedAction, RoutineOccurrenceAction.start);
    expect(observation?.operationId, isNotEmpty);
    expect(observation?.writeOutcome, RoutineWriteOutcome.saved);
    expect(observation?.resultingStatus, RoutineStatus.active);
  });

  testWidgets('Executor exposes the canonical user-safe outcome messages', (
    tester,
  ) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    Future<void> expectMessage(
      RoutineWriteResult result,
      String expected,
    ) async {
      RoutineActionExecutor.showOutcomeFeedbackWithMessenger(
        messengerKey.currentState,
        result,
      );
      await tester.pump();
      expect(find.text(expected), findsOneWidget);
      messengerKey.currentState!.clearSnackBars();
      await tester.pumpAndSettle();
    }

    await expectMessage(const RoutineWriteResult.saved(), 'Saved');
    await expectMessage(
      const RoutineWriteResult.noOp(
        failureCategory: RoutineFailureCategory.alreadyCompleted,
      ),
      'Already completed',
    );
    await expectMessage(
      const RoutineWriteResult.noOp(
        failureCategory: RoutineFailureCategory.alreadyActive,
      ),
      'Already active',
    );
    await expectMessage(
      const RoutineWriteResult(
        outcome: RoutineWriteOutcome.validationFailed,
        message: 'Safe validation reason',
      ),
      'Safe validation reason',
    );
    await expectMessage(
      const RoutineWriteResult.retryRequired(
        failureCategory: RoutineFailureCategory.offlineOrUnavailable,
      ),
      'Offline / sync pending',
    );
    await expectMessage(
      const RoutineWriteResult.retryRequired(),
      'Retry needed',
    );
    await expectMessage(
      const RoutineWriteResult.superseded(),
      'Operation superseded',
    );
  });

  testWidgets(
    'Executor keeps starting-owner attribution for a pending superseded result',
    (tester) async {
      const ownerA = 'user_a';
      const ownerB = 'user_b';
      final item = createTemplate(ownerA, 't_pending_owner');
      await repo.createRoutineItem(ownerA, item);
      await container
          .read(routineNotifierProvider.notifier)
          .loadForOwner(ownerA);
      final resultCompleter = Completer<RoutineWriteResult>();
      final observed = Completer<RoutineActionExecutionObservation>();
      RoutineActionExecutor.observer = (value) {
        if (!observed.isCompleted) observed.complete(value);
      };
      addTearDown(() => RoutineActionExecutor.observer = null);
      final context = RoutineActionContext.fallback(
        item: item,
        occurrenceDate: DateTime(2026, 9, 20),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (_, ref, child) => TextButton(
                  onPressed: () => RoutineActionExecutor.execute(
                    ref: ref,
                    actionContext: context,
                    action: RoutineOccurrenceAction.complete,
                    perform: () => resultCompleter.future,
                    showFeedback: false,
                  ),
                  child: const Text('Pending execute'),
                ),
              ),
            ),
          ),
        ),
      );
      await container
          .read(routineNotifierProvider.notifier)
          .loadForOwner(ownerA);
      await tester.tap(find.text('Pending execute'));
      await tester.pump();
      container.read(routineNotifierProvider.notifier).resetForSignedOut();
      await container
          .read(routineNotifierProvider.notifier)
          .loadForOwner(ownerB);
      resultCompleter.complete(
        const RoutineWriteResult.superseded(operationId: 'op-superseded'),
      );
      await tester.pumpAndSettle();
      final observation = await observed.future;

      expect(observation.ownerUidAtStart, ownerA);
      expect(observation.writeOutcome, RoutineWriteOutcome.superseded);
      expect(
        observation.failureCategory,
        RoutineFailureCategory.ownerSuperseded,
      );
      expect(observation.resultingStatus, isNull);
      expect(container.read(routineNotifierProvider.notifier).ownerUid, ownerB);
      expect(
        container
            .read(routineNotifierProvider)
            .occurrences
            .where((entry) => entry.ownerUid == ownerA),
        isEmpty,
      );
    },
  );

  test(
    'Done twice on completed item returns noOp and creates no duplicate event',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
      await notifier.loadForOwner(uid);

      final first = await notifier.completeRoutineItem('t1');
      await waitForPending();
      expect(first.outcome, RoutineWriteOutcome.saved);
      final eventsAfterFirst = container
          .read(routineNotifierProvider)
          .events
          .length;

      final second = await notifier.completeRoutineItem('t1');
      expect(second.outcome, RoutineWriteOutcome.noOp);
      expect(second.failureCategory, RoutineFailureCategory.alreadyCompleted);
      final eventsAfterSecond = container
          .read(routineNotifierProvider)
          .events
          .length;
      expect(eventsAfterSecond, equals(eventsAfterFirst));
    },
  );

  test('Start on completed item is rejected with invalidTransition', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    final done = await notifier.completeRoutineItem('t1');
    await waitForPending();
    expect(done.outcome, RoutineWriteOutcome.saved);

    final restart = await notifier.startRoutineItem('t1');
    expect(restart.outcome, RoutineWriteOutcome.validationFailed);
    expect(restart.failureCategory, RoutineFailureCategory.invalidTransition);
    expect(restart.message, contains('Completed routine cannot be restarted'));
  });

  test('Move on completed item is rejected with invalidTransition', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    final done = await notifier.completeRoutineItem('t1');
    await waitForPending();
    expect(done.outcome, RoutineWriteOutcome.saved);

    final move = await notifier.moveItem(
      itemId: 't1',
      date: DateTime(2026, 9, 20),
      startMinute: 700,
      durationMinutes: 60,
    );
    expect(move.outcome, RoutineWriteOutcome.validationFailed);
    expect(move.failureCategory, RoutineFailureCategory.invalidTransition);
    expect(move.message, contains('Completed routine cannot be moved'));
  });

  test(
    'moveToTomorrow anchors to displayDate + 1 day instead of DateTime.now()',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      final targetItem = createTemplate(uid, 't_future');
      await repo.createRoutineItem(uid, targetItem);
      await notifier.loadForOwner(uid);

      final viewingDate = DateTime(2026, 11, 15);
      final result = await notifier.moveToTomorrow(
        targetItem,
        occurrenceDate: viewingDate,
        displayDate: viewingDate,
      );
      await waitForPending();

      expect(result.outcome, RoutineWriteOutcome.saved);
      final state = container.read(routineNotifierProvider);
      final moved = state.occurrences.firstWhere(
        (o) => o.routineItemId == 't_future',
      );
      expect(moved.movedToDateKey, '2026-11-16');
    },
  );

  test(
    'Overnight move persists minute-of-day range and re-move keeps source identity',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      final item = createTemplate(uid, 't_overnight').copyWith(
        startMinute: 23 * 60,
        endMinute: 6 * 60 + 30,
        crossesMidnight: true,
        endsNextDay: true,
      );
      final source = DateTime(2026, 9, 15);
      await repo.createRoutineItem(uid, item);
      await notifier.loadForOwner(uid);

      final first = await notifier.moveItem(
        itemId: item.id,
        date: DateTime(2026, 9, 20),
        startMinute: 23 * 60,
        durationMinutes: 450,
        occurrenceDate: source,
      );
      expect(first.outcome, RoutineWriteOutcome.saved);
      expect(first.resultingStatus, RoutineStatus.moved);
      var occurrence = container
          .read(routineNotifierProvider)
          .occurrences
          .single;
      expect(occurrence.occurrenceDateKey, '2026-09-15');
      expect(occurrence.movedToDateKey, '2026-09-20');
      expect(occurrence.movedStartMinute, 1380);
      expect(occurrence.movedEndMinute, 390);

      final second = await notifier.moveItem(
        itemId: item.id,
        date: DateTime(2026, 9, 22),
        startMinute: 23 * 60,
        durationMinutes: 450,
        occurrenceDate: source,
      );
      expect(second.outcome, RoutineWriteOutcome.saved);
      occurrence = container.read(routineNotifierProvider).occurrences.single;
      expect(occurrence.occurrenceDateKey, '2026-09-15');
      expect(occurrence.movedToDateKey, '2026-09-22');
    },
  );

  test(
    'Native and moved overnight continuation actions target source occurrences',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      RoutineItem overnight(String id) => createTemplate(uid, id).copyWith(
        startMinute: 23 * 60,
        endMinute: 6 * 60 + 30,
        crossesMidnight: true,
        endsNextDay: true,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
      );
      final native = overnight('native_overnight');
      final moved = overnight('moved_overnight');
      await repo.createRoutineItem(uid, native);
      await repo.createRoutineItem(uid, moved);
      await notifier.loadForOwner(uid);

      final nativeEntry = RoutineOccurrenceProjector.entriesForDay(
        [native],
        const [],
        DateTime(2026, 9, 16),
      ).firstWhere((entry) => entry.kind == RoutineDayEntryKind.continuation);
      final nativeContext = RoutineActionContext.fromDayEntry(nativeEntry);
      await notifier.startRoutineItem(
        native.id,
        occurrenceDate: nativeContext.occurrenceDate,
      );
      await notifier.completeRoutineItem(
        native.id,
        occurrenceDate: nativeContext.occurrenceDate,
      );

      await notifier.moveItem(
        itemId: moved.id,
        date: DateTime(2026, 9, 20),
        startMinute: 23 * 60,
        durationMinutes: 450,
        occurrenceDate: DateTime(2026, 9, 10),
      );
      final movedEntry = RoutineOccurrenceProjector.entriesForDay(
        [moved],
        container.read(routineNotifierProvider).occurrences,
        DateTime(2026, 9, 21),
      ).firstWhere((entry) => entry.occurrenceId != null);
      final movedContext = RoutineActionContext.fromDayEntry(movedEntry);
      await notifier.startRoutineItem(
        moved.id,
        occurrenceDate: movedContext.occurrenceDate,
      );
      await notifier.completeRoutineItem(
        moved.id,
        occurrenceDate: movedContext.occurrenceDate,
      );

      final records = {
        for (final occurrence
            in container.read(routineNotifierProvider).occurrences)
          occurrence.routineItemId: occurrence,
      };
      expect(records[native.id]?.occurrenceDateKey, '2026-09-15');
      expect(records[native.id]?.status, RoutineStatus.completed);
      expect(records[moved.id]?.occurrenceDateKey, '2026-09-10');
      expect(records[moved.id]?.movedToDateKey, '2026-09-20');
      expect(records[moved.id]?.status, RoutineStatus.completed);
    },
  );

  test(
    'Firebase unavailable error produces offlineOrUnavailable failureCategory',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
      await notifier.loadForOwner(uid);

      transactionRepo.onBeforeMutation = () async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'The service is currently unavailable.',
        );
      };

      final res = await notifier.completeRoutineItem('t1');
      expect(res.outcome, RoutineWriteOutcome.retryRequired);
      expect(res.failureCategory, RoutineFailureCategory.offlineOrUnavailable);
      expect(res.message, 'Offline / sync pending.');

      // Clean up test hook
      transactionRepo.onBeforeMutation = null;
    },
  );

  test(
    'Offline Undo uses the shared failure classification and preserves state',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      await repo.createRoutineItem(uid, createTemplate(uid, 't_undo_offline'));
      await notifier.loadForOwner(uid);
      final started = await notifier.startRoutineItem('t_undo_offline');
      expect(started.outcome, RoutineWriteOutcome.saved);
      transactionRepo.onBeforeMutation = () async {
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      };

      final result = await notifier.undoOccurrenceAction('t_undo_offline');

      expect(result.outcome, RoutineWriteOutcome.retryRequired);
      expect(
        result.failureCategory,
        RoutineFailureCategory.offlineOrUnavailable,
      );
      expect(result.resultingStatus, RoutineStatus.active);
      expect(
        container.read(routineNotifierProvider).occurrences.single.status,
        RoutineStatus.active,
      );
      transactionRepo.onBeforeMutation = null;
    },
  );

  test(
    'Past and future explicit actions preserve exact occurrence dates',
    () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user_1';
      for (final id in [
        'past_start',
        'past_done',
        'past_move',
        'future_start',
      ]) {
        await repo.createRoutineItem(uid, createTemplate(uid, id));
      }
      await notifier.loadForOwner(uid);
      final past = DateTime(2026, 9, 10);
      final future = DateTime(2026, 9, 20);

      await notifier.startRoutineItem('past_start', occurrenceDate: past);
      await notifier.completeRoutineItem('past_done', occurrenceDate: past);
      await notifier.moveItem(
        itemId: 'past_move',
        date: DateTime(2026, 9, 11),
        startMinute: 700,
        durationMinutes: 60,
        occurrenceDate: past,
      );
      await notifier.startRoutineItem('future_start', occurrenceDate: future);

      final byItem = {
        for (final occurrence
            in container.read(routineNotifierProvider).occurrences)
          occurrence.routineItemId: occurrence,
      };
      expect(byItem['past_start']?.occurrenceDateKey, '2026-09-10');
      expect(byItem['past_done']?.occurrenceDateKey, '2026-09-10');
      expect(byItem['past_move']?.occurrenceDateKey, '2026-09-10');
      expect(byItem['past_move']?.movedToDateKey, '2026-09-11');
      expect(byItem['future_start']?.occurrenceDateKey, '2026-09-20');
    },
  );

  testWidgets(
    'Completed card disables Done and does not render active running countdown',
    (tester) async {
      final completedItem = createTemplate('user_1', 't_completed').copyWith(
        status: RoutineStatus.completed,
        isCompleted: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        countdownDurationSeconds: 1800,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: RoutineCardActions(
                item: completedItem,
                color: Colors.blue,
                actionContext: RoutineActionContext.fallback(
                  item: completedItem,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      final done = find.byKey(
        const ValueKey('routine-action-done-t_completed'),
      );
      final start = find.byKey(
        const ValueKey('routine-action-start-t_completed'),
      );
      expect(
        tester
            .widget<GestureDetector>(
              find.descendant(of: done, matching: find.byType(GestureDetector)),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<GestureDetector>(
              find.descendant(
                of: start,
                matching: find.byType(GestureDetector),
              ),
            )
            .onTap,
        isNull,
      );
      expect(find.textContaining(RegExp(r'^\d{2}:\d{2}:\d{2}$')), findsNothing);
      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: done, matching: find.byType(Opacity)),
            )
            .opacity,
        0.45,
      );
    },
  );

  testWidgets(
    'RoutineMoveSheet initializes date to displayDate when provided',
    (tester) async {
      final item = createTemplate('user_1', 't_recurring').copyWith(date: null);
      final displayDate = DateTime(2026, 10, 20);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => showRoutineMoveSheet(
                    context,
                    ref,
                    item,
                    displayDate: displayDate,
                  ),
                  child: const Text('Open Move Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Move Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('TUE 20/10'), findsOneWidget);
    },
  );

  test('Moved-in entry preserves source occurrence date on Done', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    final sourceDate = DateTime(2026, 9, 10);
    final targetDate = DateTime(2026, 9, 12);
    final item = createTemplate(uid, 't_moved');
    await repo.createRoutineItem(uid, item);
    await notifier.loadForOwner(uid);

    await notifier.moveItem(
      itemId: 't_moved',
      date: targetDate,
      startMinute: 600,
      durationMinutes: 60,
      occurrenceDate: sourceDate,
    );
    await waitForPending();

    final context = RoutineActionContext(
      instanceId: 'm:t_moved:2026-09-12',
      templateId: 't_moved',
      occurrenceDateKey: '2026-09-10',
      displayDateKey: '2026-09-12',
      kind: RoutineDayEntryKind.movedIn,
      item: item,
    );

    await notifier.completeRoutineItem(
      't_moved',
      occurrenceDate: context.occurrenceDate,
    );
    await waitForPending();

    final state = container.read(routineNotifierProvider);
    final occ = state.occurrences.firstWhere(
      (o) => o.routineItemId == 't_moved',
    );
    expect(occ.occurrenceDateKey, '2026-09-10');
    expect(occ.movedToDateKey, '2026-09-12');
    expect(occ.status, RoutineStatus.completed);
  });
}
