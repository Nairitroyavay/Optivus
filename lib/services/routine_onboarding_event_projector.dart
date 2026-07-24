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

typedef RoutineProjectorReader = T Function<T>(ProviderListenable<T> provider);

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
  }) async {
    final plan = RoutineOnboardingProjection.build(bundle);
    final receipt = await read(
      routineRepositoryProvider,
    ).fetchProjectionReceipt(bundle.uid, plan.projectionId);
    if (receipt == null ||
        receipt.ownerUid != bundle.uid ||
        receipt.sourceBundleFingerprint != plan.fingerprint) {
      return RoutineOnboardingEventProjectionResult(
        projectionId: plan.projectionId,
        attemptedCount: 0,
      );
    }
    if (receipt.status == 'completed') {
      return RoutineOnboardingEventProjectionResult(
        projectionId: plan.projectionId,
        attemptedCount: 0,
      );
    }

    final itemById = {for (final item in plan.items) item.id: item};
    final createdIds =
        receipt.projectedItemIds
            .where(itemById.containsKey)
            .toSet()
            .toList(growable: false)
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
    var currentReceipt = receipt;
    var attempted = 0;
    for (
      var start = currentReceipt.cursor.clamp(0, events.length);
      start < events.length;
      start = currentReceipt.cursor.clamp(0, events.length)
    ) {
      final end = (start + batchSize).clamp(0, events.length);
      final now = DateTime.now().toUtc();
      final nextReceipt = currentReceipt.copyWith(
        cursor: end,
        status: end == events.length ? 'completed' : 'pending',
        updatedAt: now,
        completedAt: end == events.length ? now : null,
        clearCompletedAt: end != events.length,
        clearLastSafeError: true,
      );
      try {
        await transactionRepository.commitProjectionEventBatch(
          uid: bundle.uid,
          fromReceipt: currentReceipt,
          toReceipt: nextReceipt,
          addEvents: events.sublist(start, end),
        );
      } catch (error) {
        throw RoutineProjectionRetryRequiredException(error);
      }
      attempted += end - start;
      currentReceipt = nextReceipt;
    }

    if (events.isEmpty && currentReceipt.status != 'completed') {
      final now = DateTime.now().toUtc();
      final nextReceipt = currentReceipt.copyWith(
        cursor: 0,
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
