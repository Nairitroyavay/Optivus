import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

import 'package:optivus/services/routine_projection_receipt_validator.dart';

typedef RoutineProjectorReader = T Function<T>(ProviderListenable<T> provider);

enum RoutineProjectionFailureReason {
  receiptMissing,
  ownerMismatch,
  fingerprintMismatch,
  invalidStatus,
  invalidCursor,
  malformedReceipt,
  retryRequired,
}

class RoutineProjectionFailureException implements Exception {
  final RoutineProjectionFailureReason reason;
  final String message;

  const RoutineProjectionFailureException({
    required this.reason,
    required this.message,
  });

  @override
  String toString() => 'RoutineProjectionFailureException($reason): $message';
}

class RoutineOnboardingEventProjectionResult {
  final String projectionId;
  final int attemptedCount;
  final List<String> expectedEventIds;
  final List<String> appliedEventIds;
  final List<String> existingEventIds;
  final List<String> repairedEventIds;
  final List<String> failedEventIds;

  const RoutineOnboardingEventProjectionResult({
    required this.projectionId,
    required this.attemptedCount,
    this.expectedEventIds = const [],
    this.appliedEventIds = const [],
    this.existingEventIds = const [],
    this.repairedEventIds = const [],
    this.failedEventIds = const [],
  });
}

class RoutineOnboardingEventProjector {
  static const int batchSize = 100;

  const RoutineOnboardingEventProjector();

  List<RoutineEventRecord> computeEventRecords({
    required OnboardingCompletionBundle bundle,
    DateTime? occurredAt,
  }) {
    final plan = RoutineOnboardingProjection.build(bundle);
    final now = occurredAt ?? DateTime.now().toUtc();
    return [
      for (final item in plan.items)
        _eventRecord(
          ownerUid: bundle.uid,
          projectionId: plan.projectionId,
          item: item,
          eventType: RoutineEventType.created,
          occurredAt: now,
        ),
    ];
  }

  List<String> computeExpectedEventIds(OnboardingCompletionBundle bundle) {
    return _historyRecords(bundle).map((record) => record.id).toList()..sort();
  }

  Future<RoutineOnboardingEventProjectionResult> projectCreatedEvents({
    required RoutineProjectorReader read,
    required OnboardingCompletionBundle bundle,
    bool requireExistingReceipt = false,
  }) async {
    final plan = RoutineOnboardingProjection.build(bundle);
    final routineRepo = read(routineRepositoryProvider);
    final fetchedReceipt = await routineRepo.fetchProjectionReceipt(
      bundle.uid,
      plan.projectionId,
    );

    final RoutineProjectionReceipt receipt;
    if (fetchedReceipt == null) {
      if (requireExistingReceipt) {
        throw const RoutineProjectionFailureException(
          reason: RoutineProjectionFailureReason.receiptMissing,
          message: 'Projection receipt not found.',
        );
      }
      final now = DateTime.now().toUtc();
      receipt = RoutineProjectionReceipt(
        id: plan.projectionId,
        ownerUid: bundle.uid,
        slot: plan.slot,
        revision: plan.revision,
        sourceBundleSchemaVersion: OnboardingCompletionBundle.schemaVersion,
        sourceBundleId: plan.sourceBundleId,
        sourceBundleFingerprint: plan.fingerprint,
        expectedItemIds: plan.items.map((i) => i.id).toList(),
        status: 'pending',
        cursor: 0,
        totalCount: plan.items.length,
        createdItemIds: plan.items.map((i) => i.id).toList(),
        projectedItemIds: plan.items.map((i) => i.id).toList(),
        createdAt: now,
        updatedAt: now,
      );
    } else {
      receipt = fetchedReceipt;
    }
    if (receipt.ownerUid != bundle.uid) {
      throw const RoutineProjectionFailureException(
        reason: RoutineProjectionFailureReason.ownerMismatch,
        message: 'Receipt owner UID mismatch.',
      );
    }
    if (receipt.sourceBundleFingerprint != plan.fingerprint) {
      throw const RoutineProjectionFailureException(
        reason: RoutineProjectionFailureReason.fingerprintMismatch,
        message: 'Receipt fingerprint mismatch.',
      );
    }
    if (receipt.status != 'pending' && receipt.status != 'completed') {
      throw const RoutineProjectionFailureException(
        reason: RoutineProjectionFailureReason.invalidStatus,
        message: 'Invalid receipt status.',
      );
    }
    if (receipt.cursor < 0 || receipt.cursor > receipt.totalCount) {
      throw const RoutineProjectionFailureException(
        reason: RoutineProjectionFailureReason.invalidCursor,
        message: 'Invalid receipt cursor.',
      );
    }

    final actualItems = await routineRepo.fetchRoutineItems(bundle.uid);
    final validationResult = const RoutineProjectionReceiptValidator().validate(
      receipt: receipt,
      actualItems: actualItems,
      ownerUid: bundle.uid,
      plan: plan,
    );
    if (!validationResult.isValid) {
      throw RoutineProjectionFailureException(
        reason: RoutineProjectionFailureReason.malformedReceipt,
        message:
            validationResult.failureReason ?? 'Malformed receipt or items.',
      );
    }

    final historyResult = await _reconcileAndVerifyHistory(
      read: read,
      bundle: bundle,
      plan: plan,
    );

    final events = generateEventRecords(
      ownerUid: bundle.uid,
      plan: plan,
      receipt: receipt,
    );
    if (receipt.status == 'completed') {
      if (receipt.cursor != receipt.totalCount) {
        throw const RoutineProjectionFailureException(
          reason: RoutineProjectionFailureReason.invalidCursor,
          message: 'Completed receipt cursor mismatch.',
        );
      }
      return historyResult;
    }

    final transactionRepository = read(routineTransactionRepositoryProvider);
    final createdEventsOffset = receipt.existingItemIds.length;
    var currentReceipt = receipt;
    var attempted = 0;
    for (
      var index = (currentReceipt.cursor - createdEventsOffset).clamp(
        0,
        events.length,
      );
      index < events.length;
      index = (currentReceipt.cursor - createdEventsOffset).clamp(
        0,
        events.length,
      )
    ) {
      final end = (index + batchSize).clamp(0, events.length);
      final nextCursor = (createdEventsOffset + end).clamp(
        0,
        currentReceipt.totalCount,
      );
      final isDone =
          end == events.length || nextCursor >= currentReceipt.totalCount;
      final finalCursor = isDone ? currentReceipt.totalCount : nextCursor;
      final now = DateTime.now().toUtc();
      final nextReceipt = currentReceipt.copyWith(
        cursor: finalCursor,
        status: isDone ? 'completed' : 'pending',
        updatedAt: now,
        completedAt: isDone ? now : null,
        clearCompletedAt: !isDone,
        clearLastSafeError: true,
      );
      try {
        await transactionRepository.commitProjectionEventBatch(
          uid: bundle.uid,
          fromReceipt: currentReceipt,
          toReceipt: nextReceipt,
          addEvents: events.sublist(index, end),
        );
      } catch (error) {
        throw RoutineProjectionRetryRequiredException(error);
      }
      attempted += end - index;
      currentReceipt = nextReceipt;
    }

    if ((events.isEmpty ||
            currentReceipt.cursor == currentReceipt.totalCount) &&
        currentReceipt.status != 'completed') {
      final now = DateTime.now().toUtc();
      final nextReceipt = currentReceipt.copyWith(
        cursor: currentReceipt.totalCount,
        status: 'completed',
        updatedAt: now,
        completedAt: now,
        clearLastSafeError: true,
      );
      try {
        await transactionRepository.commitProjectionEventBatch(
          uid: bundle.uid,
          fromReceipt: currentReceipt,
          toReceipt: nextReceipt,
          addEvents: const [],
        );
      } catch (error) {
        throw RoutineProjectionRetryRequiredException(error);
      }
      currentReceipt = nextReceipt;
    }

    return RoutineOnboardingEventProjectionResult(
      projectionId: plan.projectionId,
      attemptedCount: attempted,
      expectedEventIds: historyResult.expectedEventIds,
      appliedEventIds: historyResult.appliedEventIds,
      existingEventIds: historyResult.existingEventIds,
      repairedEventIds: historyResult.repairedEventIds,
      failedEventIds: historyResult.failedEventIds,
    );
  }

  Future<RoutineOnboardingEventProjectionResult> _reconcileAndVerifyHistory({
    required RoutineProjectorReader read,
    required OnboardingCompletionBundle bundle,
    required RoutineOnboardingProjectionPlan plan,
  }) async {
    final repository = read(routineHistoryRepositoryProvider);
    final expected = _historyRecords(bundle);
    final before = {
      for (final record in await repository.fetchHistory(bundle.uid))
        record.id: record,
    };
    final created = <String>[];
    final existing = <String>[];
    final repaired = <String>[];
    final failed = <String>[];
    for (final record in expected) {
      final current = before[record.id];
      if (current != null && _matchesHistoryRecord(current, record)) {
        existing.add(record.id);
        continue;
      }
      try {
        final write = current == null
            ? record
            : record.copyWith(
                action: 'repair',
                operationKey: '${record.operationKey}_repair',
              );
        await repository.appendHistory(bundle.uid, write);
        (current == null ? created : repaired).add(record.id);
      } catch (_) {
        failed.add(record.id);
      }
    }

    final after = {
      for (final record in await repository.fetchHistory(bundle.uid))
        record.id: record,
    };
    for (final expectedRecord in expected) {
      final actual = after[expectedRecord.id];
      if (actual == null || !_matchesHistoryRecord(actual, expectedRecord)) {
        failed.add(expectedRecord.id);
      }
    }
    final failedSet = failed.toSet();
    created.removeWhere(failedSet.contains);
    existing.removeWhere(failedSet.contains);
    repaired.removeWhere(failedSet.contains);
    final expectedIds = expected.map((record) => record.id).toList()..sort();
    created.sort();
    existing.sort();
    repaired.sort();
    final failedIds = failedSet.toList()..sort();
    return RoutineOnboardingEventProjectionResult(
      projectionId: plan.projectionId,
      attemptedCount: created.length + repaired.length,
      expectedEventIds: expectedIds,
      appliedEventIds: created,
      existingEventIds: existing,
      repairedEventIds: repaired,
      failedEventIds: failedIds,
    );
  }

  List<RoutineOccurrenceRecord> _historyRecords(
    OnboardingCompletionBundle bundle,
  ) {
    final plan = RoutineOnboardingProjection.build(bundle);
    final dateKey = routineLocalDateKey(bundle.createdAt);
    return [
      for (final item in plan.items)
        RoutineOccurrenceRecord(
          id: stableRoutineOccurrenceId(
            ownerUid: bundle.uid,
            routineItemId: item.id,
            occurrenceDateKey: dateKey,
          ),
          ownerUid: bundle.uid,
          routineItemId: item.id,
          occurrenceDateKey: dateKey,
          status: RoutineStatus.active,
          source: 'onboarding',
          action: 'project',
          operationKey:
              'onboarding_history_${_stableId('history-v1', [bundle.uid, plan.projectionId, item.id]).substring(0, 40)}',
          createdAt: bundle.createdAt.toUtc(),
          updatedAt: bundle.updatedAt.toUtc(),
          displayTitleOverride: item.title,
          onboardingProjectionId: plan.projectionId,
          onboardingSourceItemId: item.onboardingSourceItemId ?? item.id,
          sourceFingerprint: bundle.sourceFingerprint,
        ),
    ];
  }

  bool _matchesHistoryRecord(
    RoutineOccurrenceRecord actual,
    RoutineOccurrenceRecord expected,
  ) {
    return actual.id == expected.id &&
        actual.ownerUid == expected.ownerUid &&
        actual.routineItemId == expected.routineItemId &&
        actual.occurrenceDateKey == expected.occurrenceDateKey &&
        actual.status == expected.status &&
        actual.source == expected.source &&
        (actual.action == 'project' || actual.action == 'repair') &&
        actual.displayTitleOverride == expected.displayTitleOverride &&
        actual.onboardingProjectionId == expected.onboardingProjectionId &&
        actual.onboardingSourceItemId == expected.onboardingSourceItemId &&
        actual.sourceFingerprint == expected.sourceFingerprint &&
        actual.schemaVersion == RoutineOccurrenceRecord.currentSchemaVersion;
  }

  static List<RoutineEventRecord> generateEventRecords({
    required String ownerUid,
    required RoutineOnboardingProjectionPlan plan,
    required RoutineProjectionReceipt receipt,
  }) {
    final itemById = {for (final item in plan.items) item.id: item};
    final useProjectedFallback =
        receipt.createdItemIds.isEmpty &&
        receipt.repairedItemIds.isEmpty &&
        receipt.projectedItemIds.isNotEmpty;

    final createdTargetIds = useProjectedFallback
        ? receipt.projectedItemIds
        : receipt.createdItemIds;
    final createdIds =
        createdTargetIds
            .where(itemById.containsKey)
            .toSet()
            .toList(growable: false)
          ..sort();

    final repairedTargetIds = useProjectedFallback
        ? const <String>[]
        : receipt.repairedItemIds;
    final repairedIds =
        repairedTargetIds
            .where(itemById.containsKey)
            .toSet()
            .toList(growable: false)
          ..sort();

    const projector = RoutineOnboardingEventProjector();
    return [
      for (final itemId in createdIds)
        projector._eventRecord(
          ownerUid: ownerUid,
          projectionId: plan.projectionId,
          item: itemById[itemId]!,
          eventType: RoutineEventType.created,
          occurredAt: receipt.createdAt,
        ),
      for (final itemId in repairedIds)
        projector._eventRecord(
          ownerUid: ownerUid,
          projectionId: plan.projectionId,
          item: itemById[itemId]!,
          eventType: RoutineEventType.edited,
          occurredAt: receipt.createdAt,
        ),
    ];
  }

  RoutineEventRecord _eventRecord({
    required String ownerUid,
    required String projectionId,
    required RoutineItem item,
    required RoutineEventType eventType,
    required DateTime occurredAt,
  }) {
    final operationPrefix = eventType == RoutineEventType.created
        ? 'onboarding-created-operation-v1'
        : 'onboarding-edited-operation-v1';

    final operationKey = _stableId(operationPrefix, [
      ownerUid,
      projectionId,
      item.id,
      eventType.name,
    ]);
    final eventId = _stableId('routine-event-v1', [
      operationKey,
      item.id,
      eventType.name,
    ]);
    return RoutineEventRecord(
      eventId: 'evt_${eventId.substring(0, 40)}',
      ownerUid: ownerUid,
      routineItemId: item.id,
      eventType: eventType,
      operationKey: 'onboarding_${operationKey.substring(0, 40)}',
      source: 'onboarding',
      occurredAt: occurredAt.toUtc(),
      itemSnapshot: _boundedHistorySnapshot(item, projectionId),
    );
  }

  Map<String, dynamic> _boundedHistorySnapshot(
    RoutineItem item,
    String projectionId,
  ) {
    return {
      'id': item.id,
      'title': item.title,
      'startMinute': item.startMinute,
      'durationMinutes': item.durationMinutes,
      'blockType': item.blockType.name,
      'trackerTaskType': item.trackerType.name,
      'hardBlock': item.hardBlock,
      'onboardingProjectionId': projectionId,
    };
  }

  String _stableId(String prefix, List<Object?> parts) {
    return sha256
        .convert(
          utf8.encode(
            [
              prefix,
              ...parts.map((part) => part?.toString() ?? ''),
            ].join('\u001f'),
          ),
        )
        .toString();
  }
}
