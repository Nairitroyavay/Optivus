import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
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

  const RoutineOnboardingEventProjectionResult({
    required this.projectionId,
    required this.attemptedCount,
  });
}

class RoutineOnboardingEventProjector {
  static const int batchSize = 100;

  const RoutineOnboardingEventProjector();

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
        sourceBundleSchemaVersion: OnboardingCompletionBundle.schemaVersion,
        sourceBundleId: bundle.uid,
        sourceBundleFingerprint: plan.fingerprint,
        status: 'pending',
        cursor: 0,
        totalCount: plan.items.length,
        createdItemIds: plan.items.map((i) => i.id).toList(),
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

    if (receipt.status == 'completed') {
      if (receipt.cursor != receipt.totalCount) {
        throw const RoutineProjectionFailureException(
          reason: RoutineProjectionFailureReason.invalidCursor,
          message: 'Completed receipt cursor mismatch.',
        );
      }
      return RoutineOnboardingEventProjectionResult(
        projectionId: plan.projectionId,
        attemptedCount: 0,
      );
    }

    final itemById = {for (final item in plan.items) item.id: item};
    final targetIds = receipt.createdItemIds.isNotEmpty
        ? receipt.createdItemIds
        : receipt.projectedItemIds;
    final createdIds =
        targetIds.where(itemById.containsKey).toSet().toList(growable: false)
          ..sort();
    final events = [
      for (final itemId in createdIds)
        _createdEvent(
          ownerUid: bundle.uid,
          projectionId: plan.projectionId,
          item: itemById[itemId]!,
          occurredAt: receipt.createdAt,
        ),
    ];

    final transactionRepository = read(routineTransactionRepositoryProvider);
    final createdEventsOffset = receipt.createdItemIds.isNotEmpty
        ? receipt.existingItemIds.length
        : 0;
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

    if (events.isEmpty && currentReceipt.status != 'completed') {
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
    );
  }

  RoutineEventRecord _createdEvent({
    required String ownerUid,
    required String projectionId,
    required RoutineItem item,
    required DateTime occurredAt,
  }) {
    final operationKey = _stableId('onboarding-created-operation-v1', [
      ownerUid,
      projectionId,
      item.id,
      RoutineEventType.created.name,
    ]);
    final eventId = _stableId('routine-event-v1', [
      operationKey,
      item.id,
      RoutineEventType.created.name,
    ]);
    return RoutineEventRecord(
      eventId: 'evt_${eventId.substring(0, 40)}',
      ownerUid: ownerUid,
      routineItemId: item.id,
      eventType: RoutineEventType.created,
      operationKey: 'onboarding_${operationKey.substring(0, 40)}',
      source: 'onboarding',
      occurredAt: occurredAt.toUtc(),
      itemSnapshot: _boundedHistorySnapshot(item, ownerUid),
    );
  }

  Map<String, dynamic> _boundedHistorySnapshot(RoutineItem item, String uid) {
    return {
      'id': item.id,
      'title': item.title,
      'startMinute': item.startMinute,
      'durationMinutes': item.durationMinutes,
      'blockType': item.blockType.name,
      'trackerTaskType': item.trackerType.name,
      'hardBlock': item.hardBlock,
      'onboardingProjectionId': 'onboarding-initial-v1',
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
