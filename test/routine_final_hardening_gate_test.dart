import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/models/routine_action_availability.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_actions.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_presentation.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

/// Test repository that simulates a transport drop immediately after remote commit.
class AmbiguousTransportTransactionRepository
    extends FakeRoutineTransactionRepository {
  bool failAfterSet = false;
  bool failAfterDelete = false;

  AmbiguousTransportTransactionRepository({
    required super.routineRepository,
    required super.historyRepository,
  });

  @override
  Future<void> commitWrite({
    required String uid,
    RoutineItem? setItem,
    List<RoutineItem>? setItems,
    String? deleteItemId,
    List<String>? deleteItemIds,
    Map<String, dynamic>? setBaseTimelineSetupDoc,
    RoutineOccurrenceRecord? setOccurrence,
    String? deleteOccurrenceId,
    RoutineEventRecord? addEvent,
    List<RoutineEventRecord>? addEvents,
    List<ConflictAcceptance>? setConflictAcceptances,
  }) async {
    // Perform real underlying commit first so remote data is modified
    await super.commitWrite(
      uid: uid,
      setItem: setItem,
      setItems: setItems,
      deleteItemId: deleteItemId,
      deleteItemIds: deleteItemIds,
      setBaseTimelineSetupDoc: setBaseTimelineSetupDoc,
      setOccurrence: setOccurrence,
      deleteOccurrenceId: deleteOccurrenceId,
      addEvent: addEvent,
      addEvents: addEvents,
      setConflictAcceptances: setConflictAcceptances,
    );

    // Then simulate connection drop before ACK reaches client
    if (setOccurrence != null && failAfterSet) {
      failAfterSet = false;
      throw Exception('transport_error: network timeout waiting for ACK');
    }
    if (deleteOccurrenceId != null && failAfterDelete) {
      failAfterDelete = false;
      throw Exception(
        'transport_error: network timeout waiting for delete ACK',
      );
    }
  }
}

/// Test repository that fails during write execution (before committing).
class FailingTransactionRepository extends FakeRoutineTransactionRepository {
  bool shouldFail = false;

  FailingTransactionRepository({
    required super.routineRepository,
    required super.historyRepository,
  });

  @override
  Future<void> commitWrite({
    required String uid,
    RoutineItem? setItem,
    List<RoutineItem>? setItems,
    String? deleteItemId,
    List<String>? deleteItemIds,
    Map<String, dynamic>? setBaseTimelineSetupDoc,
    RoutineOccurrenceRecord? setOccurrence,
    String? deleteOccurrenceId,
    RoutineEventRecord? addEvent,
    List<RoutineEventRecord>? addEvents,
    List<ConflictAcceptance>? setConflictAcceptances,
  }) async {
    if (shouldFail) {
      throw Exception('simulated_network_failure');
    }
    return super.commitWrite(
      uid: uid,
      setItem: setItem,
      setItems: setItems,
      deleteItemId: deleteItemId,
      deleteItemIds: deleteItemIds,
      setBaseTimelineSetupDoc: setBaseTimelineSetupDoc,
      setOccurrence: setOccurrence,
      deleteOccurrenceId: deleteOccurrenceId,
      addEvent: addEvent,
      addEvents: addEvents,
      setConflictAcceptances: setConflictAcceptances,
    );
  }
}

void main() {
  group('Routine Final Hardening Gates Suite', () {
    late ProviderContainer container;
    late FakeRoutineDatabase database;
    late FakeRoutineRepository routineRepo;
    late FakeRoutineHistoryRepository historyRepo;
    late AmbiguousTransportTransactionRepository txRepo;

    setUp(() {
      database = FakeRoutineDatabase();
      routineRepo = FakeRoutineRepository(database: database);
      historyRepo = FakeRoutineHistoryRepository();
      txRepo = AmbiguousTransportTransactionRepository(
        routineRepository: routineRepo,
        historyRepository: historyRepo,
      );

      container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
          fakeDataAllowedProvider.overrideWithValue(true),
          routineRepositoryProvider.overrideWithValue(routineRepo),
          routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
          routineTransactionRepositoryProvider.overrideWithValue(txRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    // ------------------------------------------------------------------------
    // GATE 1: Sentinel Null-Clearing & Multi-step Undo
    // Planned -> Move -> Skip -> Undo Skip -> Undo Move
    // ------------------------------------------------------------------------
    test(
      'Gate 1: Sentinel null-clearing and multi-step Undo restores planned state',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_test_1');

        final date = DateTime(2026, 9, 20);
        final item = RoutineItem(
          id: 'task_step_undo',
          userId: 'user_test_1',
          title: 'Deep Focus',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_test_1', item);
        await notifier.loadForOwner('user_test_1');

        // 1. Move to tomorrow
        final moveRes = await notifier.moveItem(
          itemId: item.id,
          date: date.add(const Duration(days: 1)),
          startMinute: 700,
          durationMinutes: 60,
          occurrenceDate: date,
        );
        expect(moveRes.outcome, RoutineWriteOutcome.saved);

        var state = container.read(routineNotifierProvider);
        var occ = state.occurrences.firstWhere(
          (o) => o.routineItemId == item.id,
        );
        expect(occ.status, RoutineStatus.moved);
        expect(occ.action, 'reschedule');
        expect(occ.previousStatus, isNull);

        // 2. Skip the moved occurrence
        final skipRes = await notifier.markSkipped(
          item.id,
          occurrenceDate: date,
        );
        expect(skipRes.outcome, RoutineWriteOutcome.saved);

        state = container.read(routineNotifierProvider);
        occ = state.occurrences.firstWhere((o) => o.routineItemId == item.id);
        expect(occ.status, RoutineStatus.skipped);
        expect(occ.previousStatus, RoutineStatus.moved);
        expect(occ.previousAction, 'reschedule');

        // Sentinel verification on RoutineOccurrenceRecord directly
        final testRecord = occ.copyWith(
          previousStatus: null,
          previousAction: null,
        );
        expect(testRecord.previousStatus, isNull);
        expect(testRecord.previousAction, isNull);

        final clearedRecord = occ.clearPreviousStatusAndAction();
        expect(clearedRecord.previousStatus, isNull);
        expect(clearedRecord.previousAction, isNull);

        // 3. Undo Skip -> restores Moved record with cleared previous fields
        final undoSkipRes = await notifier.undoOccurrenceAction(
          item.id,
          occurrenceDate: date,
        );
        expect(undoSkipRes.outcome, RoutineWriteOutcome.saved);

        state = container.read(routineNotifierProvider);
        occ = state.occurrences.firstWhere((o) => o.routineItemId == item.id);
        expect(occ.status, RoutineStatus.moved);
        expect(occ.previousStatus, isNull);
        expect(occ.previousAction, isNull);

        final availability = RoutineActionAvailability.forOccurrence(
          existingRecord: occ,
          status: occ.status,
          blockType: item.blockType,
        );
        expect(availability.canUndo, isTrue);

        // 4. Undo Move -> deletes occurrence and restores Planned state
        final undoMoveRes = await notifier.undoOccurrenceAction(
          item.id,
          occurrenceDate: date,
        );
        expect(undoMoveRes.outcome, RoutineWriteOutcome.saved);

        state = container.read(routineNotifierProvider);
        final remainingOccs = state.occurrences.where(
          (o) => o.routineItemId == item.id,
        );
        expect(remainingOccs, isEmpty);
      },
    );

    // ------------------------------------------------------------------------
    // GATE 2: Failed Undo Skip Retry restores Moved record (mutationType == setRecord)
    // ------------------------------------------------------------------------
    test(
      'Gate 2: Failed Undo Skip preserves setRecord mutationType on Retry',
      () async {
        final failingTx = FailingTransactionRepository(
          routineRepository: routineRepo,
          historyRepository: historyRepo,
        );
        final failContainer = ProviderContainer(
          overrides: [
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.fake,
            ),
            fakeDataAllowedProvider.overrideWithValue(true),
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
            routineTransactionRepositoryProvider.overrideWithValue(failingTx),
          ],
        );
        addTearDown(failContainer.dispose);

        final notifier = failContainer.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_test_2');

        final date = DateTime(2026, 9, 20);
        final item = RoutineItem(
          id: 'task_retry_undo',
          userId: 'user_test_2',
          title: 'Study Session',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_test_2', item);
        await notifier.loadForOwner('user_test_2');

        // Move, then Skip
        await notifier.moveItem(
          itemId: item.id,
          date: date.add(const Duration(days: 1)),
          startMinute: 700,
          durationMinutes: 60,
          occurrenceDate: date,
        );
        await notifier.markSkipped(item.id, occurrenceDate: date);

        // Enable network failure for the undo attempt
        failingTx.shouldFail = true;
        final undoFailRes = await notifier.undoOccurrenceAction(
          item.id,
          occurrenceDate: date,
        );
        expect(undoFailRes.outcome, RoutineWriteOutcome.retryRequired);

        // Verify the write intent is recorded as setRecord (NOT deleteRecord)
        final state = failContainer.read(routineNotifierProvider);
        expect(state.failedOccurrenceIntentsById.isNotEmpty, isTrue);
        final failedIntent = state.failedOccurrenceIntentsById.values.first;
        expect(
          failedIntent.mutationType,
          RoutineOccurrenceMutationType.setRecord,
        );
        expect(failedIntent.attemptedRecord.status, RoutineStatus.moved);

        // Network recovers -> Retry executes setRecord successfully
        failingTx.shouldFail = false;
        final retryRes = await notifier.retryFailedOccurrenceAction(
          failedIntent.occurrenceId,
        );
        expect(retryRes.outcome, RoutineWriteOutcome.saved);

        final finalState = failContainer.read(routineNotifierProvider);
        final restoredOcc = finalState.occurrences.firstWhere(
          (o) => o.routineItemId == item.id,
        );
        expect(restoredOcc.status, RoutineStatus.moved);
      },
    );

    // ------------------------------------------------------------------------
    // GATE 3: Remote Ambiguity Recovery on Transport Drop (SET and DELETE)
    // ------------------------------------------------------------------------
    test(
      'Gate 3: Ambiguity recovery on transport drop recovers SET and DELETE without error',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_test_3');

        final date = DateTime(2026, 9, 20);
        final item = RoutineItem(
          id: 'task_ambiguous_drop',
          userId: 'user_test_3',
          title: 'Work Sprint',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_test_3', item);
        await notifier.loadForOwner('user_test_3');

        // SET ambiguity: remote server commits write, but network drops before ACK
        txRepo.failAfterSet = true;
        final setRes = await notifier.startRoutineItem(
          item.id,
          occurrenceDate: date,
        );
        // Recovery must verify remote history and succeed
        expect(setRes.outcome, RoutineWriteOutcome.saved);
        expect(setRes.resultingStatus, RoutineStatus.active);

        var state = container.read(routineNotifierProvider);
        expect(
          state.occurrences
              .firstWhere((o) => o.routineItemId == item.id)
              .status,
          RoutineStatus.active,
        );

        // DELETE ambiguity: remote server commits delete on undo, but network drops before ACK
        txRepo.failAfterDelete = true;
        final delRes = await notifier.undoOccurrenceAction(
          item.id,
          occurrenceDate: date,
        );
        // Recovery must confirm document absence in remote history and succeed
        expect(delRes.outcome, RoutineWriteOutcome.saved);
        expect(delRes.resultingStatus, RoutineStatus.planned);

        state = container.read(routineNotifierProvider);
        expect(
          state.occurrences.where((o) => o.routineItemId == item.id),
          isEmpty,
        );
      },
    );

    // ------------------------------------------------------------------------
    // GATE 4: Deterministic FIFO Queue Processing
    // ------------------------------------------------------------------------
    test(
      'Gate 4: Rapid user actions are sequenced FIFO and validate against state',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_test_4');

        final date = DateTime(2026, 9, 20);
        final item = RoutineItem(
          id: 'task_fifo',
          userId: 'user_test_4',
          title: 'Gym Workout',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_test_4', item);
        await notifier.loadForOwner('user_test_4');

        // Rapidly trigger Start, then Complete
        final futureStart = notifier.startRoutineItem(
          item.id,
          occurrenceDate: date,
        );
        final futureComplete = notifier.completeRoutineItem(
          item.id,
          occurrenceDate: date,
        );

        final results = await Future.wait([futureStart, futureComplete]);
        expect(results[0].outcome, RoutineWriteOutcome.saved);
        expect(results[1].outcome, RoutineWriteOutcome.saved);
        expect(results[1].resultingStatus, RoutineStatus.completed);

        final state = container.read(routineNotifierProvider);
        final finalOcc = state.occurrences.firstWhere(
          (o) => o.routineItemId == item.id,
        );
        expect(finalOcc.status, RoutineStatus.completed);
      },
    );

    // ------------------------------------------------------------------------
    // GATE 5: Domain-level Money Invariant
    // ------------------------------------------------------------------------
    test(
      'Gate 5: completeRoutineItem rejects moneyTask without savings; alreadySaved satisfies contract',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_test_5');

        final date = DateTime.now();
        final moneyItem = RoutineItem(
          id: 'money_task_inv',
          userId: 'user_test_5',
          title: 'Save \$20 for Dinner',
          startMinute: 720,
          endMinute: 750,
          blockType: RoutineBlockType.moneyTask,
          category: RoutineCategory.finance,
        );
        await routineRepo.createRoutineItem('user_test_5', moneyItem);
        await notifier.loadForOwner('user_test_5');

        // Direct complete without savings MUST be rejected by domain invariant
        final invalidCompleteRes = await notifier.completeRoutineItem(
          moneyItem.id,
          occurrenceDate: date,
        );
        expect(
          invalidCompleteRes.outcome,
          RoutineWriteOutcome.validationFailed,
        );
        expect(invalidCompleteRes.message, contains('confirmed save'));

        // Executing through alreadySaved records savings and completes
        final saveRes = await notifier.alreadySaved(
          moneyItem.id,
          occurrenceDate: date,
          amount: 20.0,
        );
        expect(saveRes.outcome, RoutineWriteOutcome.saved);

        final state = container.read(routineNotifierProvider);
        final occ = state.occurrences.firstWhere(
          (o) => o.routineItemId == moneyItem.id,
        );
        expect(occ.status, RoutineStatus.completed);
        expect(occ.action, 'complete');
        expect(occ.source, 'money');

        // Once confirmed, completeRoutineItem delegates safely
        expect(
          notifier.hasConfirmedMoneySaveForRoutine(moneyItem.id, date: date),
          isTrue,
        );
        final secondCompleteRes = await notifier.completeRoutineItem(
          moneyItem.id,
          occurrenceDate: date,
        );
        expect(secondCompleteRes.outcome, RoutineWriteOutcome.noOp);
      },
    );

    // ------------------------------------------------------------------------
    // GATE 6: Tracker Resume & Reconstruction
    // ------------------------------------------------------------------------
    test(
      'Gate 6: loadForOwner reconstructs activeTrackerLaunchIntent and openTrackerSession sets route',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);

        final date = DateTime(2026, 9, 20);
        final dateKey = routineLocalDateKey(date);
        final trackerItem = RoutineItem(
          id: 'tracker_task_rec',
          userId: 'user_test_6',
          title: 'Hydration Tracker',
          startMinute: 500,
          endMinute: 530,
          blockType: RoutineBlockType.trackerTask,
          trackerType: TrackerType.hydration,
        );
        await routineRepo.createRoutineItem('user_test_6', trackerItem);

        // Pre-seed an inTracker occurrence in history
        final inTrackerOcc = RoutineOccurrenceRecord(
          id: 'occ_rec_1',
          ownerUid: 'user_test_6',
          routineItemId: trackerItem.id,
          occurrenceDateKey: dateKey,
          status: RoutineStatus.inTracker,
          source: 'routine',
          action: 'startTracker',
          operationKey: 'op_rec_1',
          trackerType: TrackerType.hydration.name,
          trackerSessionId: 'session_hydro_99',
          createdAt: date,
          updatedAt: date,
        );
        await historyRepo.appendHistory('user_test_6', inTrackerOcc);

        // Reconstruct on loadForOwner
        await notifier.loadForOwner('user_test_6');

        final state = container.read(routineNotifierProvider);
        expect(state.activeTrackerLaunchIntent, isNotNull);
        expect(state.activeTrackerLaunchIntent!.routineTaskId, trackerItem.id);
        expect(
          state.activeTrackerLaunchIntent!.trackerType,
          TrackerType.hydration,
        );
        expect(state.activeTrackerLaunchIntent!.sessionId, 'session_hydro_99');

        // openTrackerSession verifies intent is maintained
        notifier.openTrackerSession(trackerItem.id, occurrenceDate: date);
        final updatedState = container.read(routineNotifierProvider);
        expect(
          updatedState.activeTrackerLaunchIntent?.routineTaskId,
          trackerItem.id,
        );
      },
    );

    // ------------------------------------------------------------------------
    // GATE 7: UI Actions Layout (Horizontal, 2x2 Grid, Stacked) & Keys
    // ------------------------------------------------------------------------
    testWidgets('Gate 7: UI actions render correct layouts and stable keys', (
      tester,
    ) async {
      Widget createApp(
        Widget child, {
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

      final normalItem = RoutineItem(
        id: 'normal_ui_1',
        title: 'Review PRs',
        blockType: RoutineBlockType.flexibleTask,
        startMinute: 600,
        endMinute: 660,
      );

      // 1. Normal width (360dp) -> Horizontal Row
      await tester.pumpWidget(
        createApp(
          RoutineCardActions(
            item: normalItem,
            color: Colors.blue,
            actionContext: RoutineActionContext.fallback(item: normalItem),
          ),
          width: 360,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('routine-action-row-horizontal')),
        findsOneWidget,
      );
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // 2. Narrow width (260dp, 1.5x scale) -> 2x2 Grid
      await tester.pumpWidget(
        createApp(
          RoutineCardActions(
            item: normalItem,
            color: Colors.blue,
            actionContext: RoutineActionContext.fallback(item: normalItem),
          ),
          width: 260,
          textScale: 1.5,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('routine-action-grid-2x2')),
        findsOneWidget,
      );

      // 3. Narrow width (300dp, 2.5x scale) -> Stacked Column
      await tester.pumpWidget(
        createApp(
          RoutineCardActions(
            item: normalItem,
            color: Colors.blue,
            actionContext: RoutineActionContext.fallback(item: normalItem),
          ),
          width: 300,
          textScale: 2.5,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('routine-action-column-stacked')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull); // 0 RenderFlex overflow
    });

    // ------------------------------------------------------------------------
    // GATE 8: Overnight Midnight Continuation
    // ------------------------------------------------------------------------
    test(
      'Gate 8: Overnight continuation spanning midnight anchors to source occurrence date',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_test_8');

        final anchorDate = DateTime(2026, 9, 20);

        // Item starting at 23:30 (1410 min) and ending at 01:00 next day (60 min)
        final overnightItem = RoutineItem(
          id: 'night_shift_1',
          userId: 'user_test_8',
          title: 'Night Shift Focus',
          startMinute: 23 * 60 + 30, // 1410
          endMinute: 1 * 60, // 01:00 next day
          crossesMidnight: true,
          endsNextDay: true,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_test_8', overnightItem);
        await notifier.loadForOwner('user_test_8');

        // Action executed on the continuation day passing explicit anchor occurrenceDate
        final completeRes = await notifier.completeRoutineItem(
          overnightItem.id,
          occurrenceDate: anchorDate,
        );
        expect(completeRes.outcome, RoutineWriteOutcome.saved);

        final state = container.read(routineNotifierProvider);
        final occ = state.occurrences.firstWhere(
          (o) => o.routineItemId == overnightItem.id,
        );
        // Must be anchored to the 2026-09-20 anchor date, not the 2026-09-21 continuation date
        expect(occ.occurrenceDateKey, routineLocalDateKey(anchorDate));
        expect(occ.status, RoutineStatus.completed);
      },
    );

    // ------------------------------------------------------------------------
    // GATE 9: Measurement Parity across Layouts
    // ------------------------------------------------------------------------
    test(
      'Gate 9: Action footer height measurement parity matches rendering geometry',
      () {
        const singleButton = RoutineCardPresentation.actionButtonMinHeight;
        const gap = RoutineCardPresentation.actionGap;

        // 4 actions:
        // Horizontal: 1 row
        expect(
          RoutineCardPresentation.actionFooterHeight(
            RoutineCardActionLayout.horizontal,
            actionCount: 4,
          ),
          singleButton,
        );
        // Grid 2x2: 2 rows
        expect(
          RoutineCardPresentation.actionFooterHeight(
            RoutineCardActionLayout.grid2x2,
            actionCount: 4,
          ),
          (singleButton * 2) + gap,
        );
        // Stacked 4 actions: 4 rows
        expect(
          RoutineCardPresentation.actionFooterHeight(
            RoutineCardActionLayout.stacked,
            actionCount: 4,
          ),
          (singleButton * 4) + (gap * 3),
        );
        // Stacked 3 actions (Money / Bad Habit / Planned Tracker): 3 rows
        expect(
          RoutineCardPresentation.actionFooterHeight(
            RoutineCardActionLayout.stacked,
            actionCount: 3,
          ),
          (singleButton * 3) + (gap * 2),
        );
        // Terminal with canUndo: 2 rows regardless of original action count
        expect(
          RoutineCardPresentation.actionFooterHeight(
            RoutineCardActionLayout.stacked,
            canUndo: true,
          ),
          (singleButton * 2) + gap,
        );
      },
    );
  });
}
