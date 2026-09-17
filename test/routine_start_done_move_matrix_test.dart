import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/models/routine_action_availability.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_move_seed.dart';
import 'package:optivus/features/routine/services/routine_transition_policy.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

void main() {
  group('RoutineTransitionPolicy Complete Matrix', () {
    const testDate = '2026-09-20';

    RoutineOccurrenceRecord? buildRecord({
      required RoutineStatus status,
      required RoutineOccurrenceAction lastAction,
      bool undoToPlannedAllowed = true,
    }) {
      return RoutineOccurrenceRecord(
        id: 'occ-1',
        ownerUid: 'user-1',
        routineItemId: 'matrix-item-1',
        occurrenceDateKey: testDate,
        status: status,
        source: 'routine',
        action: lastAction.name,
        operationKey: 'op-1',
        createdAt: DateTime.utc(2026, 9, 20),
        updatedAt: DateTime.utc(2026, 9, 20),
        undoToPlannedAllowed: undoToPlannedAllowed,
      );
    }

    test('Planned status transition decisions', () {
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: null,
          requestedAction: RoutineOccurrenceAction.start,
          projectedStatus: RoutineStatus.planned,
        ).isAllowed,
        true,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: null,
          requestedAction: RoutineOccurrenceAction.complete,
          projectedStatus: RoutineStatus.planned,
        ).isAllowed,
        true,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: null,
          requestedAction: RoutineOccurrenceAction.move,
          projectedStatus: RoutineStatus.planned,
        ).isAllowed,
        true,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: null,
          requestedAction: RoutineOccurrenceAction.skip,
          projectedStatus: RoutineStatus.planned,
        ).isAllowed,
        true,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: null,
          requestedAction: RoutineOccurrenceAction.miss,
          projectedStatus: RoutineStatus.planned,
        ).isAllowed,
        true,
      );
      // Undo on planned without prior record is noOp
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: null,
          requestedAction: RoutineOccurrenceAction.undo,
          projectedStatus: RoutineStatus.planned,
        ).isNoOp,
        true,
      );
    });

    test('Active status transition decisions', () {
      final activeRecord = buildRecord(
        status: RoutineStatus.active,
        lastAction: RoutineOccurrenceAction.start,
      );

      // Start on already active is noOp
      final startDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: activeRecord,
        requestedAction: RoutineOccurrenceAction.start,
        projectedStatus: RoutineStatus.active,
      );
      expect(startDecision.isNoOp, true);
      expect(startDecision.message, 'Already active.');

      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: activeRecord,
          requestedAction: RoutineOccurrenceAction.complete,
          projectedStatus: RoutineStatus.active,
        ).isAllowed,
        true,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: activeRecord,
          requestedAction: RoutineOccurrenceAction.move,
          projectedStatus: RoutineStatus.active,
        ).isAllowed,
        false,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: activeRecord,
          requestedAction: RoutineOccurrenceAction.undo,
          projectedStatus: RoutineStatus.active,
        ).isAllowed,
        true,
      );
      final skipActiveDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: activeRecord,
        requestedAction: RoutineOccurrenceAction.skip,
        projectedStatus: RoutineStatus.active,
      );
      expect(skipActiveDecision.isAllowed, false);
      expect(
        skipActiveDecision.message,
        'Stop this routine before skipping it.',
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: activeRecord,
          requestedAction: RoutineOccurrenceAction.miss,
          projectedStatus: RoutineStatus.active,
        ).isAllowed,
        true,
      );
    });

    test('Completed terminal status strictly blocks start, move, skip, miss', () {
      final completedRecord = buildRecord(
        status: RoutineStatus.completed,
        lastAction: RoutineOccurrenceAction.complete,
      );

      // Complete on completed is noOp
      final completeDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: completedRecord,
        requestedAction: RoutineOccurrenceAction.complete,
        projectedStatus: RoutineStatus.completed,
      );
      expect(completeDecision.isNoOp, true);
      expect(completeDecision.message, 'Already completed.');

      // Start is rejected
      final startDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: completedRecord,
        requestedAction: RoutineOccurrenceAction.start,
        projectedStatus: RoutineStatus.completed,
      );
      expect(startDecision.isRejected, true);
      expect(startDecision.message, 'Completed routine cannot be restarted.');

      // Move is rejected
      final moveDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: completedRecord,
        requestedAction: RoutineOccurrenceAction.move,
        projectedStatus: RoutineStatus.completed,
      );
      expect(moveDecision.isRejected, true);
      expect(moveDecision.message, 'Completed routine cannot be moved.');

      // Skip is rejected (no direct completed -> skipped transition)
      final skipDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: completedRecord,
        requestedAction: RoutineOccurrenceAction.skip,
        projectedStatus: RoutineStatus.completed,
      );
      expect(skipDecision.isRejected, true);
      expect(skipDecision.message, 'Completed routine cannot be skipped.');

      // Miss is rejected
      final missDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: completedRecord,
        requestedAction: RoutineOccurrenceAction.miss,
        projectedStatus: RoutineStatus.completed,
      );
      expect(missDecision.isRejected, true);
      expect(missDecision.message, 'Completed routine cannot be marked missed.');

      // Undo is allowed when undoToPlannedAllowed is true
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: completedRecord,
          requestedAction: RoutineOccurrenceAction.undo,
          projectedStatus: RoutineStatus.completed,
        ).isAllowed,
        true,
      );
    });

    test('Skipped terminal status blocks forward mutations', () {
      final skippedRecord = buildRecord(
        status: RoutineStatus.skipped,
        lastAction: RoutineOccurrenceAction.skip,
      );

      // Skip on skipped is noOp
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: skippedRecord,
          requestedAction: RoutineOccurrenceAction.skip,
          projectedStatus: RoutineStatus.skipped,
        ).isNoOp,
        true,
      );

      // Start, Complete, Move, Miss are rejected
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: skippedRecord,
          requestedAction: RoutineOccurrenceAction.start,
          projectedStatus: RoutineStatus.skipped,
        ).isRejected,
        true,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: skippedRecord,
          requestedAction: RoutineOccurrenceAction.complete,
          projectedStatus: RoutineStatus.skipped,
        ).isRejected,
        true,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: skippedRecord,
          requestedAction: RoutineOccurrenceAction.move,
          projectedStatus: RoutineStatus.skipped,
        ).isRejected,
        true,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: skippedRecord,
          requestedAction: RoutineOccurrenceAction.miss,
          projectedStatus: RoutineStatus.skipped,
        ).isRejected,
        true,
      );

      // Undo allowed
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: skippedRecord,
          requestedAction: RoutineOccurrenceAction.undo,
          projectedStatus: RoutineStatus.skipped,
        ).isAllowed,
        true,
      );
    });

    test('Missed terminal status blocks forward mutations', () {
      final missedRecord = buildRecord(
        status: RoutineStatus.missed,
        lastAction: RoutineOccurrenceAction.miss,
      );

      // Miss on missed is noOp
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: missedRecord,
          requestedAction: RoutineOccurrenceAction.miss,
          projectedStatus: RoutineStatus.missed,
        ).isNoOp,
        true,
      );

      // Start, Complete, Move, Skip are rejected
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: missedRecord,
          requestedAction: RoutineOccurrenceAction.start,
          projectedStatus: RoutineStatus.missed,
        ).isRejected,
        true,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: missedRecord,
          requestedAction: RoutineOccurrenceAction.complete,
          projectedStatus: RoutineStatus.missed,
        ).isRejected,
        true,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: missedRecord,
          requestedAction: RoutineOccurrenceAction.move,
          projectedStatus: RoutineStatus.missed,
        ).isRejected,
        true,
      );
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: missedRecord,
          requestedAction: RoutineOccurrenceAction.skip,
          projectedStatus: RoutineStatus.missed,
        ).isRejected,
        true,
      );

      // Undo allowed
      expect(
        RoutineTransitionPolicy.evaluate(
          existingRecord: missedRecord,
          requestedAction: RoutineOccurrenceAction.undo,
          projectedStatus: RoutineStatus.missed,
        ).isAllowed,
        true,
      );
    });

    test('Undo blocked when undoToPlannedAllowed is false', () {
      final record = buildRecord(
        status: RoutineStatus.completed,
        lastAction: RoutineOccurrenceAction.complete,
        undoToPlannedAllowed: false,
      );

      final undoDecision = RoutineTransitionPolicy.evaluate(
        existingRecord: record,
        requestedAction: RoutineOccurrenceAction.undo,
        projectedStatus: RoutineStatus.completed,
      );
      expect(undoDecision.isRejected, true);
      expect(undoDecision.message, 'This action can no longer be undone.');
    });
  });

  group('RoutineActionAvailability Derivation', () {
    test('Correctly computes independent action availability for completed item', () {
      final record = RoutineOccurrenceRecord(
        id: 'occ-1',
        ownerUid: 'user-1',
        routineItemId: 'avail-item',
        occurrenceDateKey: '2026-09-20',
        status: RoutineStatus.completed,
        source: 'routine',
        action: 'complete',
        operationKey: 'op-1',
        createdAt: DateTime.utc(2026, 9, 20),
        updatedAt: DateTime.utc(2026, 9, 20),
        undoToPlannedAllowed: true,
      );

      final availability = RoutineActionAvailability.forOccurrence(
        existingRecord: record,
        status: RoutineStatus.completed,
        blockType: RoutineBlockType.flexibleTask,
      );

      // Can NOT start, move, skip, miss
      expect(availability.canStart, false);
      expect(availability.canMove, false);
      expect(availability.canSkip, false);
      expect(availability.canMiss, false);

      // Can NOT complete again (decision is noOp)
      expect(availability.canComplete, false);
      expect(availability.completeDecision.isNoOp, true);

      // CAN undo
      expect(availability.canUndo, true);
    });

    test('Correctly computes action availability for active item', () {
      final record = RoutineOccurrenceRecord(
        id: 'occ-2',
        ownerUid: 'user-1',
        routineItemId: 'avail-active',
        occurrenceDateKey: '2026-09-20',
        status: RoutineStatus.active,
        source: 'routine',
        action: 'start',
        operationKey: 'op-2',
        createdAt: DateTime.utc(2026, 9, 20),
        updatedAt: DateTime.utc(2026, 9, 20),
        undoToPlannedAllowed: true,
      );

      final availability = RoutineActionAvailability.forOccurrence(
        existingRecord: record,
        status: RoutineStatus.active,
        blockType: RoutineBlockType.flexibleTask,
      );

      // Can complete
      expect(availability.canComplete, true);
      // Cannot move while active (Gate G)
      expect(availability.canMove, false);
      // Cannot start again
      expect(availability.canStart, false);
      expect(availability.startDecision.isNoOp, true);
    });
  });

  group('Make Tiny Version Midnight Wrapping & Continuation', () {
    late ProviderContainer container;
    late FakeRoutineRepository repo;
    late FakeRoutineDatabase database;
    late FakeRoutineHistoryRepository historyRepo;
    late FakeRoutineTransactionRepository transactionRepo;

    setUp(() {
      database = FakeRoutineDatabase();
      repo = FakeRoutineRepository(database: database);
      historyRepo = FakeRoutineHistoryRepository();
      transactionRepo = FakeRoutineTransactionRepository(
        routineRepository: repo,
        historyRepository: historyRepo,
      );

      container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
          routineRepositoryProvider.overrideWithValue(repo),
          routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
          routineTransactionRepositoryProvider.overrideWithValue(transactionRepo),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('makeTinyVersion wraps across midnight and writes correct minute of day', () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'user-1';
      final lateItem = RoutineItem(
        id: 'late-1',
        userId: uid,
        title: 'Night Stretch',
        startMinute: 1438, // 23:58
        endMinute: 1440,
        blockType: RoutineBlockType.flexibleTask,
      );
      await repo.createRoutineItem(uid, lateItem);
      await notifier.loadForOwner(uid);

      // Tiny version of 5 min: starts at 1438, wraps past 1440 to minute 3!
      final result = await notifier.makeTinyVersion(
        lateItem,
        occurrenceDate: DateTime.utc(2026, 9, 20),
        startMinute: 1438,
        durationMinutes: 5,
      );

      expect(result.outcome, RoutineWriteOutcome.saved);
      final occurrence = container.read(routineNotifierProvider).occurrences.first;
      expect(occurrence.movedStartMinute, 1438);
      // 1438 + 5 = 1443 -> 1443 - 1440 = 3
      expect(occurrence.movedEndMinute, 3);
    });

    test('RoutineMoveSeedResolver resolves canonical start and duration from template for continuation', () {
      final sourceTemplate = RoutineItem(
        id: 'overnight-item',
        title: 'Overnight Shift',
        startMinute: 1380, // 23:00
        endMinute: 420, // 07:00
        blockType: RoutineBlockType.hardBlock,
      );

      // The continuation fragment on the next day has startMinute: 0, endMinute: 420
      final continuationItem = sourceTemplate.copyWith(
        startMinute: 0,
        endMinute: 420,
      );

      final actionContext = RoutineActionContext(
        instanceId: 'c:overnight-item:2026-09-20',
        templateId: 'overnight-item',
        occurrenceDateKey: '2026-09-20',
        displayDateKey: '2026-09-21',
        kind: RoutineDayEntryKind.continuation,
        item: continuationItem,
      );

      final seed = RoutineMoveSeedResolver.resolve(
        actionContext: actionContext,
        visibleItem: continuationItem,
        templates: [sourceTemplate],
        occurrences: const [],
      );

      // Seed start MUST be the canonical 1380 (23:00) from source template, not 0!
      expect(seed.startMinute, 1380);
      // Duration MUST be canonical 480 (8 hours), not 420!
      expect(seed.durationMinutes, 480);
    });
  });

  group('RoutineNotifier addItem Idempotency', () {
    late ProviderContainer container;
    late FakeRoutineRepository repo;
    late FakeRoutineDatabase database;
    late FakeRoutineHistoryRepository historyRepo;
    late FakeRoutineTransactionRepository transactionRepo;

    setUp(() {
      database = FakeRoutineDatabase();
      repo = FakeRoutineRepository(database: database);
      historyRepo = FakeRoutineHistoryRepository();
      transactionRepo = FakeRoutineTransactionRepository(
        routineRepository: repo,
        historyRepository: historyRepo,
      );

      container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
          routineRepositoryProvider.overrideWithValue(repo),
          routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
          routineTransactionRepositoryProvider.overrideWithValue(transactionRepo),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('addItem updates existing item on duplicate ID tap rather than creating duplicate', () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'test_user_id';
      await notifier.loadForOwner(uid);

      final item = RoutineItem(
        id: 'idempotent-item-1',
        userId: uid,
        title: 'Initial Title',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
      );

      // First add
      await notifier.addItem(item);
      expect(container.read(routineNotifierProvider).items.length, 1);
      expect(container.read(routineNotifierProvider).items.first.title, 'Initial Title');

      // Second add with same ID (e.g. rapid double tap or retry)
      final updatedItem = item.copyWith(title: 'Updated Title');
      await notifier.addItem(updatedItem);

      // MUST NOT duplicate in state.items
      final items = container.read(routineNotifierProvider).items;
      expect(items.length, 1);
      expect(items.first.id, 'idempotent-item-1');
      expect(items.first.title, 'Updated Title');
    });

    test('Rapid consecutive startFlexibleTask calls are serialized with only one occurrence', () async {
      final notifier = container.read(routineNotifierProvider.notifier);
      const uid = 'test_user_id';
      final item = RoutineItem(
        id: 'rapid-start',
        userId: uid,
        title: 'Rapid Task',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
      );
      await repo.createRoutineItem(uid, item);
      await notifier.loadForOwner(uid);

      // Fire twice simultaneously
      notifier.startFlexibleTask('rapid-start');
      notifier.startFlexibleTask('rapid-start');
      await Future.delayed(const Duration(milliseconds: 50));

      final occurrences = container.read(routineNotifierProvider).occurrences;
      expect(occurrences.where((o) => o.routineItemId == 'rapid-start' && o.action == 'start').length, 1);
    });
  });
}
