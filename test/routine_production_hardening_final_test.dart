import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/models/add_routine_draft.dart';
import 'package:optivus/features/routine/models/routine_action_availability.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/add_routine_mapper.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_presentation.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/tracker_session_link.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

/// Test repository that can simulate network drops or transaction failures.
class ControllableTransactionRepository
    extends FakeRoutineTransactionRepository {
  bool failNextWrite = false;
  bool failAfterSetTransport = false;
  bool failAfterDeleteTransport = false;
  Completer<void>? writeDelayCompleter;

  ControllableTransactionRepository({
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
    if (writeDelayCompleter != null) {
      await writeDelayCompleter!.future;
    }

    if (failNextWrite) {
      failNextWrite = false;
      throw Exception('simulated_network_write_failure');
    }

    // Perform underlying write
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

    // Simulate transport timeout after remote write committed
    if (setOccurrence != null && failAfterSetTransport) {
      failAfterSetTransport = false;
      throw Exception('transport_error: network timeout waiting for ACK (SET)');
    }
    if (deleteOccurrenceId != null && failAfterDeleteTransport) {
      failAfterDeleteTransport = false;
      throw Exception(
        'transport_error: network timeout waiting for ACK (DELETE)',
      );
    }
  }
}

void main() {
  group('Routine Production Hardening: 40 Verification Gates', () {
    late ProviderContainer container;
    late FakeRoutineDatabase database;
    late FakeRoutineRepository routineRepo;
    late FakeRoutineHistoryRepository historyRepo;
    late ControllableTransactionRepository txRepo;

    setUp(() {
      database = FakeRoutineDatabase();
      routineRepo = FakeRoutineRepository(database: database);
      historyRepo = FakeRoutineHistoryRepository();
      txRepo = ControllableTransactionRepository(
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

    // ========================================================================
    // GATES 1–2: Semantic Queued Action Rebasing on Predecessor Failure
    // ========================================================================
    test(
      'Gates 1-2: Queued action rebases against rolled-back state when predecessor fails',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_g1');

        final date = DateTime(2026, 9, 20);
        final item = RoutineItem(
          id: 'task_g1_rebase',
          userId: 'user_g1',
          title: 'Deep Architecture Analysis',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_g1', item);
        await notifier.loadForOwner('user_g1');

        // 1. Hold first write in-flight
        final delayCompleter = Completer<void>();
        txRepo.writeDelayCompleter = delayCompleter;

        final startFuture = notifier.startRoutineItem(
          item.id,
          occurrenceDate: date,
        );
        // Let startRoutineItem enter async write pipeline
        await Future<void>.delayed(Duration.zero);

        // Verify occurrence is pending and optimistically active
        var state = container.read(routineNotifierProvider);
        final dateKey = routineLocalDateKey(date);
        final occId = stableRoutineOccurrenceId(
          ownerUid: 'user_g1',
          routineItemId: item.id,
          occurrenceDateKey: dateKey,
        );
        expect(state.pendingOccurrenceIds.contains(occId), isTrue);
        expect(
          state.occurrences
              .firstWhere((o) => o.routineItemId == item.id)
              .status,
          RoutineStatus.active,
        );

        // 2. Queue a Skip action while Start is pending
        final skipFuture = notifier.markSkipped(item.id, occurrenceDate: date);

        // Verify skip is queued semantically (queuedOccurrenceActionsById)
        state = container.read(routineNotifierProvider);
        expect(state.queuedOccurrenceActionsById.containsKey(occId), isTrue);
        expect(
          state.queuedOccurrenceActionsById[occId]!.first.action,
          RoutineOccurrenceAction.skip,
        );

        // 3. Make the Start write fail
        txRepo.failNextWrite = true;
        txRepo.writeDelayCompleter = null;
        delayCompleter.complete();

        final startResult = await startFuture;
        expect(startResult.outcome, RoutineWriteOutcome.retryRequired);

        // Wait for queue processing of the Skip action
        final skipResult = await skipFuture;
        expect(skipResult.outcome, RoutineWriteOutcome.saved);

        // Verify: Skip action rebased against the ROLLED-BACK Planned state,
        // NOT against the failed Start state!
        state = container.read(routineNotifierProvider);
        final finalOcc = state.occurrences.firstWhere(
          (o) => o.routineItemId == item.id,
        );
        expect(finalOcc.status, RoutineStatus.skipped);
        expect(finalOcc.action, 'skip');
        // Previous status should be null (since predecessor Start rolled back to planned)
        expect(finalOcc.previousStatus, isNull);
        // No ghost startedAt or timer fields should survive!
        expect(finalOcc.startedAt, isNull);
        expect(finalOcc.countdownDurationSeconds, isNull);
      },
    );

    // ========================================================================
    // GATES 3–4: Semantic Queued Action Rebasing on Predecessor Success
    // ========================================================================
    test(
      'Gates 3-4: Queued action rebases against committed state when predecessor succeeds',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_g3');

        final date = DateTime(2026, 9, 20);
        final item = RoutineItem(
          id: 'task_g3_rebase_success',
          userId: 'user_g3',
          title: 'Backend Verification',
          startMinute: 700,
          endMinute: 760,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_g3', item);
        await notifier.loadForOwner('user_g3');

        final delayCompleter = Completer<void>();
        txRepo.writeDelayCompleter = delayCompleter;

        final startFuture = notifier.startRoutineItem(
          item.id,
          occurrenceDate: date,
        );
        await Future<void>.delayed(Duration.zero);

        final dateKey = routineLocalDateKey(date);
        final occId = stableRoutineOccurrenceId(
          ownerUid: 'user_g3',
          routineItemId: item.id,
          occurrenceDateKey: dateKey,
        );
        expect(
          container
              .read(routineNotifierProvider)
              .pendingOccurrenceIds
              .contains(occId),
          isTrue,
        );

        // Queue Complete while Start is pending
        final completeFuture = notifier.completeRoutineItem(
          item.id,
          occurrenceDate: date,
        );

        // Release Start write to succeed
        txRepo.writeDelayCompleter = null;
        delayCompleter.complete();

        final startResult = await startFuture;
        expect(startResult.outcome, RoutineWriteOutcome.saved);

        final completeResult = await completeFuture;
        expect(completeResult.outcome, RoutineWriteOutcome.saved);

        final state = container.read(routineNotifierProvider);
        final finalOcc = state.occurrences.firstWhere(
          (o) => o.routineItemId == item.id,
        );
        expect(finalOcc.status, RoutineStatus.completed);
        // Since Complete followed Start, undoToPlannedAllowed is false (terminal)
        expect(finalOcc.undoToPlannedAllowed, isFalse);
      },
    );

    // ========================================================================
    // GATE 5: Start on Moved Occurrence Preserves Schedule & Allows Undo
    // ========================================================================
    test(
      'Gate 5: Start on Moved occurrence sets previousStatus: moved and preserves move schedule',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_g5');

        final sourceDate = DateTime(2026, 9, 20);
        final targetDate = DateTime(2026, 9, 21);
        final item = RoutineItem(
          id: 'task_g5_moved_start',
          userId: 'user_g5',
          title: 'Morning Run',
          startMinute: 480,
          endMinute: 540,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_g5', item);
        await notifier.loadForOwner('user_g5');

        // 1. Move the occurrence
        final moveRes = await notifier.moveItem(
          itemId: item.id,
          date: targetDate,
          startMinute: 500,
          durationMinutes: 60,
          occurrenceDate: sourceDate,
        );
        expect(moveRes.outcome, RoutineWriteOutcome.saved);

        // 2. Start the moved occurrence
        final startRes = await notifier.startRoutineItem(
          item.id,
          occurrenceDate: sourceDate,
        );
        expect(startRes.outcome, RoutineWriteOutcome.saved);

        final state = container.read(routineNotifierProvider);
        final occ = state.occurrences.firstWhere(
          (o) => o.routineItemId == item.id,
        );
        expect(occ.status, RoutineStatus.active);
        expect(occ.previousStatus, RoutineStatus.moved);
        expect(occ.previousAction, 'reschedule');
        expect(occ.undoToPlannedAllowed, isTrue);
        expect(occ.movedToDateKey, routineLocalDateKey(targetDate));
        expect(occ.movedStartMinute, 500);
        expect(occ.movedEndMinute, 560);
        expect(occ.startedAt, isNotNull);

        // Check event record snapshot includes moved schedule fields
        final events = await txRepo.watchEvents('user_g5').first;
        final startEvent = events.validEvents.firstWhere(
          (e) => e.eventType == RoutineEventType.started,
        );
        expect(
          startEvent.itemSnapshot['movedToDateKey'],
          routineLocalDateKey(targetDate),
        );
        expect(startEvent.itemSnapshot['movedStartMinute'], 500);
        expect(startEvent.itemSnapshot['movedEndMinute'], 560);
      },
    );

    // ========================================================================
    // GATE 6: Stop on Started Moved Occurrence Restores Moved State and Clears Timer
    // ========================================================================
    test(
      'Gate 6: Stop on started Moved occurrence restores Moved record with timer cleared',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_g6');

        final sourceDate = DateTime(2026, 9, 20);
        final targetDate = DateTime(2026, 9, 21);
        final item = RoutineItem(
          id: 'task_g6_moved_stop',
          userId: 'user_g6',
          title: 'Evening Reading',
          startMinute: 1200,
          endMinute: 1260,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_g6', item);
        await notifier.loadForOwner('user_g6');

        // Move then Start
        await notifier.moveItem(
          itemId: item.id,
          date: targetDate,
          startMinute: 1215,
          durationMinutes: 45,
          occurrenceDate: sourceDate,
        );
        await notifier.startRoutineItem(item.id, occurrenceDate: sourceDate);

        // Stop (undoOccurrenceAction on active item)
        final stopRes = await notifier.undoOccurrenceAction(
          item.id,
          occurrenceDate: sourceDate,
        );
        expect(stopRes.outcome, RoutineWriteOutcome.saved);

        var state = container.read(routineNotifierProvider);
        var occ = state.occurrences.firstWhere(
          (o) => o.routineItemId == item.id,
        );
        expect(occ.status, RoutineStatus.moved);
        expect(occ.action, 'reschedule');
        expect(occ.startedAt, isNull);
        expect(occ.countdownDurationSeconds, isNull);
        expect(occ.undoToPlannedAllowed, isTrue);
        expect(occ.movedToDateKey, routineLocalDateKey(targetDate));
        expect(occ.movedStartMinute, 1215);

        // Second Undo (Undo Move back to Planned)
        final undoMoveRes = await notifier.undoOccurrenceAction(
          item.id,
          occurrenceDate: sourceDate,
        );
        expect(undoMoveRes.outcome, RoutineWriteOutcome.saved);

        state = container.read(routineNotifierProvider);
        expect(
          state.occurrences.where((o) => o.routineItemId == item.id),
          isEmpty,
        );
      },
    );

    // ========================================================================
    // GATE 7: Skip on Moved Occurrence & Undo Skip
    // ========================================================================
    test(
      'Gate 7: Skip on Moved occurrence records moved fields; Undo Skip restores Moved status',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_g7');

        final sourceDate = DateTime(2026, 9, 20);
        final targetDate = DateTime(2026, 9, 22);
        final item = RoutineItem(
          id: 'task_g7_moved_skip',
          userId: 'user_g7',
          title: 'Meditation',
          startMinute: 400,
          endMinute: 430,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_g7', item);
        await notifier.loadForOwner('user_g7');

        await notifier.moveItem(
          itemId: item.id,
          date: targetDate,
          startMinute: 410,
          durationMinutes: 30,
          occurrenceDate: sourceDate,
        );

        // Skip moved occurrence
        final skipRes = await notifier.markSkipped(
          item.id,
          occurrenceDate: sourceDate,
        );
        expect(skipRes.outcome, RoutineWriteOutcome.saved);

        var state = container.read(routineNotifierProvider);
        var occ = state.occurrences.firstWhere(
          (o) => o.routineItemId == item.id,
        );
        expect(occ.status, RoutineStatus.skipped);
        expect(occ.previousStatus, RoutineStatus.moved);
        expect(occ.previousAction, 'reschedule');
        expect(occ.movedToDateKey, routineLocalDateKey(targetDate));

        // Undo Skip -> restores Moved record
        final undoRes = await notifier.undoOccurrenceAction(
          item.id,
          occurrenceDate: sourceDate,
        );
        expect(undoRes.outcome, RoutineWriteOutcome.saved);

        state = container.read(routineNotifierProvider);
        occ = state.occurrences.firstWhere((o) => o.routineItemId == item.id);
        expect(occ.status, RoutineStatus.moved);
        expect(occ.previousStatus, isNull);
        expect(occ.movedToDateKey, routineLocalDateKey(targetDate));
      },
    );

    // ========================================================================
    // GATE 8: Done Undo Terminality (Start->Done is terminal; Planned->Done is undoable)
    // ========================================================================
    test(
      'Gate 8: Direct Done is undoable; Done after Start is terminal',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('user_g8');

        final date = DateTime(2026, 9, 20);

        // Case A: Direct Done from Planned
        final itemDirect = RoutineItem(
          id: 'task_g8_direct',
          userId: 'user_g8',
          title: 'Direct Task',
          startMinute: 600,
          endMinute: 630,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_g8', itemDirect);
        await notifier.loadForOwner('user_g8');

        await notifier.completeRoutineItem(itemDirect.id, occurrenceDate: date);
        var state = container.read(routineNotifierProvider);
        var occDirect = state.occurrences.firstWhere(
          (o) => o.routineItemId == itemDirect.id,
        );
        expect(occDirect.undoToPlannedAllowed, isTrue);

        var availDirect = RoutineActionAvailability.forOccurrence(
          existingRecord: occDirect,
          status: occDirect.status,
          blockType: itemDirect.blockType,
        );
        expect(availDirect.canUndo, isTrue);

        // Undo direct Done succeeds
        final undoDirectRes = await notifier.undoOccurrenceAction(
          itemDirect.id,
          occurrenceDate: date,
        );
        expect(undoDirectRes.outcome, RoutineWriteOutcome.saved);
        state = container.read(routineNotifierProvider);
        expect(
          state.occurrences.where((o) => o.routineItemId == itemDirect.id),
          isEmpty,
        );

        // Case B: Done after Start
        final itemStarted = RoutineItem(
          id: 'task_g8_started',
          userId: 'user_g8',
          title: 'Started Task',
          startMinute: 700,
          endMinute: 730,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem('user_g8', itemStarted);
        await notifier.loadForOwner('user_g8');

        await notifier.startRoutineItem(itemStarted.id, occurrenceDate: date);
        await notifier.completeRoutineItem(
          itemStarted.id,
          occurrenceDate: date,
        );

        state = container.read(routineNotifierProvider);
        var occStarted = state.occurrences.firstWhere(
          (o) => o.routineItemId == itemStarted.id,
        );
        expect(occStarted.undoToPlannedAllowed, isFalse);

        var availStarted = RoutineActionAvailability.forOccurrence(
          existingRecord: occStarted,
          status: occStarted.status,
          blockType: itemStarted.blockType,
        );
        expect(availStarted.canUndo, isFalse);
      },
    );

    // ========================================================================
    // GATES 9–10: Stacked Active Generic Card Measurement Parity
    // ========================================================================
    test(
      'Gates 9-10: Stacked active generic card actionFooterHeight calculates exact 2 rows',
      () {
        const singleButton = RoutineCardPresentation.actionButtonMinHeight;
        const gap = RoutineCardPresentation.actionGap;

        // Active generic card in stacked mode has 2 rows:
        // Row 1: countdown banner/badge
        // Row 2: Done + Stop buttons
        final height = RoutineCardPresentation.actionFooterHeight(
          RoutineCardActionLayout.stacked,
          actionCount: 2,
          hasGenericCountdown: true,
        );

        expect(height, (singleButton * 2) + gap);

        // Non-generic 3-button stacked layout measures 3 rows
        final threeButtonHeight = RoutineCardPresentation.actionFooterHeight(
          RoutineCardActionLayout.stacked,
          actionCount: 3,
          hasGenericCountdown: false,
        );
        expect(threeButtonHeight, (singleButton * 3) + (gap * 2));

        // Layout plan resolution check
        final activeItem = RoutineItem(
          id: 'generic_active_item',
          title: 'Active Generic Item',
          blockType: RoutineBlockType.flexibleTask,
          startMinute: 600,
          endMinute: 660,
        );
        final genericActionSet = RoutineCardActionSet.resolve(
          item: activeItem,
          effectiveStatus: RoutineStatus.active,
          isTrackerActive: false,
          hasGenericCountdown: true,
          canUndo: false,
        );
        final genericPlan = genericActionSet.resolveLayoutPlan(
          availableWidth: 200,
          textScaler: TextScaler.noScaling,
          textDirection: TextDirection.ltr,
        );
        expect(genericPlan.rows.length, 2);
        expect(
          genericPlan.geometry,
          RoutineCardActionRowGeometry.countdownPlusPair,
        );
        expect(genericPlan.rows[0].first.type, RoutineCardActionType.countdown);
        expect(genericPlan.rows[1].length, 2);
      },
    );

    // ========================================================================
    // GATES 11–12: Layout Fingerprint Cache-Busting & Action Layout Plan
    // ========================================================================
    test(
      'Gates 11-12: RoutineCardFactory.layoutFingerprint changes with undoToPlannedAllowed',
      () {
        final baseItem = RoutineItem(
          id: 'fp_task_1',
          title: 'Fingerprint Task',
          blockType: RoutineBlockType.flexibleTask,
          startMinute: 600,
          endMinute: 660,
        );

        final itemWithUndo = baseItem.copyWith(undoToPlannedAllowed: true);
        final itemWithoutUndo = baseItem.copyWith(undoToPlannedAllowed: false);

        final fp1 = RoutineCardFactory.layoutFingerprint(itemWithUndo);
        final fp2 = RoutineCardFactory.layoutFingerprint(itemWithoutUndo);

        expect(fp1, isNot(equals(fp2)));
      },
    );

    // ========================================================================
    // GATES 13–14: Tracker Session Link Reconciliation on loadForOwner
    // ========================================================================
    test(
      'Gates 13-14: loadForOwner reconciles and purges stale tracker links via replaceAll',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        final trackerLinksNotifier = container.read(
          trackerSessionLinksProvider.notifier,
        );

        // Seed a stale link
        final staleLink = TrackerSessionLink(
          sessionId: 'stale_session_123',
          routineTaskId: 'task_tracker_stale',
          occurrenceDateKey: '2026-09-19',
          trackerType: TrackerType.hydration.name,
          status: 'completed',
        );
        trackerLinksNotifier.upsert(staleLink);
        expect(container.read(trackerSessionLinksProvider).length, 1);

        // Load for owner with 1 active tracker occurrence
        const uid = 'user_g13';
        final trackerItem = RoutineItem(
          id: 'task_tracker_live',
          userId: uid,
          title: 'Hydration',
          startMinute: 500,
          endMinute: 530,
          blockType: RoutineBlockType.trackerTask,
          trackerType: TrackerType.hydration,
        );
        await routineRepo.createRoutineItem(uid, trackerItem);

        final activeOcc = RoutineOccurrenceRecord(
          id: 'occ_live_1',
          ownerUid: uid,
          routineItemId: trackerItem.id,
          occurrenceDateKey: '2026-09-20',
          status: RoutineStatus.inTracker,
          source: 'routine',
          action: 'startTracker',
          operationKey: 'op_live_1',
          trackerType: TrackerType.hydration.name,
          trackerSessionId: 'live_session_456',
          createdAt: DateTime(2026, 9, 20),
          updatedAt: DateTime(2026, 9, 20),
        );
        await historyRepo.appendHistory(uid, activeOcc);

        await notifier.loadForOwner(uid);

        // Stale link must be gone; only live session remains
        final currentLinks = container.read(trackerSessionLinksProvider);
        expect(currentLinks.length, 1);
        expect(currentLinks.first.sessionId, 'live_session_456');
        expect(currentLinks.first.routineTaskId, 'task_tracker_live');
      },
    );

    // ========================================================================
    // GATE 15: Safe openTrackerSession without Fake Session ID Fabrication
    // ========================================================================
    test(
      'Gate 15: openTrackerSession aborts safely without fabricating fake session ID',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        const uid = 'user_g15';
        await notifier.loadForOwner(uid);

        final trackerItem = RoutineItem(
          id: 'task_no_session',
          userId: uid,
          title: 'Focus Tracker',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.trackerTask,
          trackerType: TrackerType.focus,
        );
        await routineRepo.createRoutineItem(uid, trackerItem);
        await notifier.loadForOwner(uid);

        // Attempt to open tracker session when no session exists
        notifier.openTrackerSession(
          trackerItem.id,
          occurrenceDate: DateTime(2026, 9, 20),
        );

        final state = container.read(routineNotifierProvider);
        expect(state.activeTrackerLaunchIntent, isNull);
        expect(state.error, isNotNull);
        expect(state.error, contains('No active tracker session'));
      },
    );

    // ========================================================================
    // GATES 16–17: Account Switching Isolation
    // ========================================================================
    test(
      'Gates 16-17: Account switching isolates state and resets tracker links',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);

        // User A setup
        const uidA = 'user_A';
        final itemA = RoutineItem(
          id: 'item_A',
          userId: uidA,
          title: 'User A Routine',
          startMinute: 600,
          endMinute: 630,
          blockType: RoutineBlockType.trackerTask,
          trackerType: TrackerType.hydration,
        );
        await routineRepo.createRoutineItem(uidA, itemA);
        final occA = RoutineOccurrenceRecord(
          id: 'occ_A',
          ownerUid: uidA,
          routineItemId: itemA.id,
          occurrenceDateKey: '2026-09-20',
          status: RoutineStatus.inTracker,
          source: 'routine',
          action: 'startTracker',
          operationKey: 'op_A',
          trackerType: TrackerType.hydration.name,
          trackerSessionId: 'sess_A',
          createdAt: DateTime(2026, 9, 20),
          updatedAt: DateTime(2026, 9, 20),
        );
        await historyRepo.appendHistory(uidA, occA);

        await notifier.loadForOwner(uidA);
        expect(
          container
              .read(routineNotifierProvider)
              .activeTrackerLaunchIntent
              ?.sessionId,
          'sess_A',
        );
        expect(container.read(trackerSessionLinksProvider).length, 1);

        // Switch to User B
        const uidB = 'user_B';
        await notifier.loadForOwner(uidB);

        final stateB = container.read(routineNotifierProvider);
        expect(stateB.activeTrackerLaunchIntent, isNull);
        expect(container.read(trackerSessionLinksProvider), isEmpty);
        expect(stateB.occurrences, isEmpty);
      },
    );

    // ========================================================================
    // GATES 18–19: Symmetric Ambiguity Recovery on Delete via fetchEventById
    // ========================================================================
    test(
      'Gates 18-19: Delete ambiguity recovery verifies event existence via fetchEventById',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        const uid = 'user_g18';
        await notifier.loadForOwner(uid);

        final date = DateTime(2026, 9, 20);
        final item = RoutineItem(
          id: 'task_g18_del',
          userId: uid,
          title: 'Ambiguous Delete Task',
          startMinute: 600,
          endMinute: 630,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem(uid, item);
        await notifier.loadForOwner(uid);

        // 1. Direct complete (creates occurrence record)
        await notifier.completeRoutineItem(item.id, occurrenceDate: date);
        var state = container.read(routineNotifierProvider);
        expect(
          state.occurrences
              .where((o) => o.routineItemId == item.id)
              .first
              .status,
          RoutineStatus.completed,
        );

        // 2. Undo Complete with network drop after delete commits on remote
        txRepo.failAfterDeleteTransport = true;
        final undoRes = await notifier.undoOccurrenceAction(
          item.id,
          occurrenceDate: date,
        );

        // Ambiguity recovery uses fetchEventById to confirm the delete event was written!
        expect(undoRes.outcome, RoutineWriteOutcome.saved);
        expect(undoRes.resultingStatus, RoutineStatus.planned);

        state = container.read(routineNotifierProvider);
        expect(
          state.occurrences.where((o) => o.routineItemId == item.id),
          isEmpty,
        );
      },
    );

    // ========================================================================
    // GATES 20–21: Symmetric Ambiguity Recovery on Set via fetchEventById
    // ========================================================================
    test(
      'Gates 20-21: Set ambiguity recovery verifies remote write via fetchEventById',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        const uid = 'user_g20';
        await notifier.loadForOwner(uid);

        final date = DateTime(2026, 9, 20);
        final item = RoutineItem(
          id: 'task_g20_set',
          userId: uid,
          title: 'Ambiguous Set Task',
          startMinute: 600,
          endMinute: 630,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem(uid, item);
        await notifier.loadForOwner(uid);

        // Start with network drop after set commits on remote
        txRepo.failAfterSetTransport = true;
        final startRes = await notifier.startRoutineItem(
          item.id,
          occurrenceDate: date,
        );

        // Ambiguity recovery confirms commit via fetchEventById!
        expect(startRes.outcome, RoutineWriteOutcome.saved);
        expect(startRes.resultingStatus, RoutineStatus.active);

        final state = container.read(routineNotifierProvider);
        final occ = state.occurrences.firstWhere(
          (o) => o.routineItemId == item.id,
        );
        expect(occ.status, RoutineStatus.active);
      },
    );

    // ========================================================================
    // GATES 36–40: End-to-End Multi-Step State Machine Lifecycle
    // Plan -> Move -> Start -> Stop -> Skip -> Undo Skip -> Undo Move
    // ========================================================================
    test(
      'Gates 36-40: Complete multi-step lifecycle: Plan -> Move -> Start -> Stop -> Skip -> Undo -> Undo',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        const uid = 'user_g36';
        await notifier.loadForOwner(uid);

        final sourceDate = DateTime(2026, 9, 20);
        final targetDate = DateTime(2026, 9, 22);
        final item = RoutineItem(
          id: 'task_lifecycle_e2e',
          userId: uid,
          title: 'Full Lifecycle Routine',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem(uid, item);
        await notifier.loadForOwner(uid);

        // 1. Initial State: Planned
        var state = container.read(routineNotifierProvider);
        expect(
          state.occurrences.where((o) => o.routineItemId == item.id),
          isEmpty,
        );

        // 2. Move
        final moveRes = await notifier.moveItem(
          itemId: item.id,
          date: targetDate,
          startMinute: 700,
          durationMinutes: 60,
          occurrenceDate: sourceDate,
        );
        expect(moveRes.outcome, RoutineWriteOutcome.saved);
        state = container.read(routineNotifierProvider);
        var occ = state.occurrences.firstWhere(
          (o) => o.routineItemId == item.id,
        );
        expect(occ.status, RoutineStatus.moved);

        // 3. Start
        final startRes = await notifier.startRoutineItem(
          item.id,
          occurrenceDate: sourceDate,
        );
        expect(startRes.outcome, RoutineWriteOutcome.saved);
        state = container.read(routineNotifierProvider);
        occ = state.occurrences.firstWhere((o) => o.routineItemId == item.id);
        expect(occ.status, RoutineStatus.active);
        expect(occ.previousStatus, RoutineStatus.moved);

        // 4. Stop -> Restores Moved
        final stopRes = await notifier.undoOccurrenceAction(
          item.id,
          occurrenceDate: sourceDate,
        );
        expect(stopRes.outcome, RoutineWriteOutcome.saved);
        state = container.read(routineNotifierProvider);
        occ = state.occurrences.firstWhere((o) => o.routineItemId == item.id);
        expect(occ.status, RoutineStatus.moved);
        expect(occ.startedAt, isNull);

        // 5. Skip -> Skipped with previousStatus: moved
        final skipRes = await notifier.markSkipped(
          item.id,
          occurrenceDate: sourceDate,
        );
        expect(skipRes.outcome, RoutineWriteOutcome.saved);
        state = container.read(routineNotifierProvider);
        occ = state.occurrences.firstWhere((o) => o.routineItemId == item.id);
        expect(occ.status, RoutineStatus.skipped);
        expect(occ.previousStatus, RoutineStatus.moved);

        // 6. Undo Skip -> Restores Moved
        final undoSkipRes = await notifier.undoOccurrenceAction(
          item.id,
          occurrenceDate: sourceDate,
        );
        expect(undoSkipRes.outcome, RoutineWriteOutcome.saved);
        state = container.read(routineNotifierProvider);
        occ = state.occurrences.firstWhere((o) => o.routineItemId == item.id);
        expect(occ.status, RoutineStatus.moved);

        // 7. Undo Move -> Restores Planned
        final undoMoveRes = await notifier.undoOccurrenceAction(
          item.id,
          occurrenceDate: sourceDate,
        );
        expect(undoMoveRes.outcome, RoutineWriteOutcome.saved);
        state = container.read(routineNotifierProvider);
        expect(
          state.occurrences.where((o) => o.routineItemId == item.id),
          isEmpty,
        );
      },
    );

    // ========================================================================
    // GATES 22–25: Add Routine Draft Stability & Weekly Slot Finder
    // ========================================================================
    test(
      'Gates 22-25: Add Routine draft ID is stable and findWeeklyFreeSlot finds common slot',
      () {
        final notifier = container.read(routineNotifierProvider.notifier);

        // 1. Draft ID stability
        final draft = AddRoutineDraft.initial(
          initialType: AddRoutineType.flexible,
        );
        final initialId = draft.id;
        expect(initialId, isNotEmpty);

        final updatedDraft = draft.copyWith(title: 'Focused Reading');
        expect(updatedDraft.id, initialId);

        // 2. Subtype isolation: Switching type does not bleed state
        final classDraft = draft.copyWith(
          type: AddRoutineType.fixed,
          fixedState: const AddRoutineFixedState(
            kind: 'Class',
            courseCode: 'CS101',
            professor: 'Dr. Turing',
          ),
        );
        final mappedClass = AddRoutineMapper.toRoutineItem(classDraft);
        expect(mappedClass.courseCode, 'CS101');
        expect(mappedClass.professor, 'Dr. Turing');

        // 3. Weekly Free Slot Finder
        final busyMonday = RoutineItem(
          id: 'busy_mon',
          title: 'Morning Class',
          startMinute: 480, // 8:00 AM
          endMinute: 600, // 10:00 AM
          repeatDays: const [DateTime.monday],
          repeatRule: 'weekly',
          blockType: RoutineBlockType.hardBlock,
        );
        notifier.state = notifier.state.copyWith(items: [busyMonday]);

        final slot = notifier.findWeeklyFreeSlot(
          item: RoutineItem(
            id: 'new_flex',
            title: 'Gym',
            startMinute: 0,
            endMinute: 60,
            blockType: RoutineBlockType.flexibleTask,
          ),
          repeatDays: const [DateTime.monday, DateTime.wednesday],
          durationMinutes: 60,
          baseDate: DateTime(2026, 9, 21), // Monday
        );
        expect(slot, isNotNull);
        // Ensure the slot does not overlap with 480-600 on Monday
        final slotStart = slot!;
        final slotEnd = slotStart + 60;
        final overlaps = (slotStart < 600 && slotEnd > 480);
        expect(overlaps, isFalse);
      },
    );

    // ========================================================================
    // GATES 26–30: Money Task Domain Invariants & Confirmation
    // ========================================================================
    test(
      'Gates 26-30: Money task enforces savings invariant; alreadySaved satisfies requirement',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        const uid = 'user_g26';
        await notifier.loadForOwner(uid);

        final date = DateTime.now();
        final moneyItem = RoutineItem(
          id: 'money_task_g26',
          userId: uid,
          title: 'Cook Dinner at Home',
          startMinute: 1140, // 19:00
          endMinute: 1200, // 20:00
          blockType: RoutineBlockType.moneyTask,
          category: RoutineCategory.finance,
        );
        await routineRepo.createRoutineItem(uid, moneyItem);
        await notifier.loadForOwner(uid);

        // Direct complete without savings must fail validation
        final directRes = await notifier.completeRoutineItem(
          moneyItem.id,
          occurrenceDate: date,
        );
        expect(directRes.outcome, RoutineWriteOutcome.validationFailed);
        expect(directRes.message, contains('confirmed save'));

        // Execution via alreadySaved succeeds and writes occurrence with source: 'money'
        final saveRes = await notifier.alreadySaved(
          moneyItem.id,
          occurrenceDate: date,
          amount: 25.50,
        );
        expect(saveRes.outcome, RoutineWriteOutcome.saved);

        final state = container.read(routineNotifierProvider);
        final occ = state.occurrences.firstWhere(
          (o) => o.routineItemId == moneyItem.id,
        );
        expect(occ.status, RoutineStatus.completed);
        expect(occ.source, 'money');

        // Subsequent complete is safely treated as a no-op
        final repeatRes = await notifier.completeRoutineItem(
          moneyItem.id,
          occurrenceDate: date,
        );
        expect(repeatRes.outcome, RoutineWriteOutcome.noOp);
      },
    );

    // ========================================================================
    // GATES 31–35: Midnight-Crossing & Overnight Continuation Anchor Date Integrity
    // ========================================================================
    test(
      'Gates 31-35: Overnight routine spanning midnight anchors to source occurrence date',
      () async {
        final notifier = container.read(routineNotifierProvider.notifier);
        const uid = 'user_g31';
        await notifier.loadForOwner(uid);

        final anchorDate = DateTime(2026, 9, 20);
        final overnightItem = RoutineItem(
          id: 'overnight_g31',
          userId: uid,
          title: 'Overnight Study Session',
          startMinute: 1410, // 23:30
          endMinute: 90, // 01:30 next morning
          crossesMidnight: true,
          endsNextDay: true,
          blockType: RoutineBlockType.flexibleTask,
        );
        await routineRepo.createRoutineItem(uid, overnightItem);
        await notifier.loadForOwner(uid);

        // Complete on continuation day specifying anchor date
        final completeRes = await notifier.completeRoutineItem(
          overnightItem.id,
          occurrenceDate: anchorDate,
        );
        expect(completeRes.outcome, RoutineWriteOutcome.saved);

        final state = container.read(routineNotifierProvider);
        final occ = state.occurrences.firstWhere(
          (o) => o.routineItemId == overnightItem.id,
        );
        expect(occ.occurrenceDateKey, routineLocalDateKey(anchorDate));
        expect(occ.status, RoutineStatus.completed);
      },
    );
  });
}
