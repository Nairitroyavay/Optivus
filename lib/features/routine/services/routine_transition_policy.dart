import 'package:flutter/foundation.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';

/// Decision result of evaluating a requested occurrence transition.
@immutable
class RoutineTransitionDecision {
  final bool isAllowed;
  final bool isNoOp;
  final String? message;
  final RoutineFailureCategory failureCategory;

  const RoutineTransitionDecision.allow()
    : isAllowed = true,
      isNoOp = false,
      message = null,
      failureCategory = RoutineFailureCategory.none;

  const RoutineTransitionDecision.noOp({
    required this.message,
    this.failureCategory = RoutineFailureCategory.none,
  }) : isAllowed = false,
       isNoOp = true;

  const RoutineTransitionDecision.reject({
    required this.message,
    this.failureCategory = RoutineFailureCategory.invalidTransition,
  }) : isAllowed = false,
       isNoOp = false;

  bool get isRejected => !isAllowed && !isNoOp;
}

/// Pure, deterministic transition policy for Routine occurrences.
class RoutineTransitionPolicy {
  const RoutineTransitionPolicy._();

  /// Evaluates whether [requestedAction] is legally executable given [existingRecord].
  static RoutineTransitionDecision evaluate({
    required RoutineOccurrenceRecord? existingRecord,
    required RoutineOccurrenceAction requestedAction,
    RoutineStatus? projectedStatus,
  }) {
    final status = existingRecord?.status ?? projectedStatus;

    switch (requestedAction) {
      case RoutineOccurrenceAction.complete:
        if (status == RoutineStatus.completed) {
          return const RoutineTransitionDecision.noOp(
            message: 'Already completed.',
            failureCategory: RoutineFailureCategory.alreadyCompleted,
          );
        }
        if (status == RoutineStatus.skipped) {
          return const RoutineTransitionDecision.reject(
            message: 'Skipped routine cannot be completed.',
          );
        }
        if (status == RoutineStatus.missed) {
          return const RoutineTransitionDecision.reject(
            message: 'Missed routine cannot be completed.',
          );
        }
        return const RoutineTransitionDecision.allow();

      case RoutineOccurrenceAction.start:
      case RoutineOccurrenceAction.startTracker:
        if (status == RoutineStatus.active ||
            status == RoutineStatus.inTracker) {
          return const RoutineTransitionDecision.noOp(
            message: 'Already active.',
            failureCategory: RoutineFailureCategory.alreadyActive,
          );
        }
        if (status == RoutineStatus.completed) {
          return const RoutineTransitionDecision.reject(
            message: 'Completed routine cannot be restarted.',
          );
        }
        if (status == RoutineStatus.skipped) {
          return const RoutineTransitionDecision.reject(
            message: 'Skipped routine cannot be restarted.',
          );
        }
        if (status == RoutineStatus.missed) {
          return const RoutineTransitionDecision.reject(
            message: 'Missed routine cannot be restarted.',
          );
        }
        return const RoutineTransitionDecision.allow();

      case RoutineOccurrenceAction.move:
      case RoutineOccurrenceAction.reschedule:
      case RoutineOccurrenceAction.makeTiny:
        final isActiveTask = status == RoutineStatus.active &&
            (existingRecord == null ||
                existingRecord.action != 'project' ||
                existingRecord.startedAt != null);
        if (isActiveTask) {
          return const RoutineTransitionDecision.reject(
            message: 'Active routine cannot be moved. Stop or undo start first.',
          );
        }
        if (status == RoutineStatus.inTracker) {
          return const RoutineTransitionDecision.reject(
            message:
                'Routine running in tracker cannot be moved. Complete or stop tracker session first.',
          );
        }
        if (status == RoutineStatus.completed) {
          return const RoutineTransitionDecision.reject(
            message: 'Completed routine cannot be moved.',
          );
        }
        if (status == RoutineStatus.skipped) {
          return const RoutineTransitionDecision.reject(
            message: 'Skipped routine cannot be moved.',
          );
        }
        if (status == RoutineStatus.missed) {
          return const RoutineTransitionDecision.reject(
            message: 'Missed routine cannot be moved.',
          );
        }
        return const RoutineTransitionDecision.allow();

      case RoutineOccurrenceAction.undo:
        if (existingRecord == null) {
          return const RoutineTransitionDecision.noOp(
            message: 'No occurrence action to undo.',
          );
        }
        if (!existingRecord.undoToPlannedAllowed) {
          return const RoutineTransitionDecision.reject(
            message: 'This action can no longer be undone.',
          );
        }
        return const RoutineTransitionDecision.allow();

      case RoutineOccurrenceAction.skip:
        if (status == RoutineStatus.completed) {
          return const RoutineTransitionDecision.reject(
            message: 'Completed routine cannot be skipped.',
          );
        }
        if (status == RoutineStatus.skipped) {
          return const RoutineTransitionDecision.noOp(
            message: 'Already skipped.',
          );
        }
        if (status == RoutineStatus.missed) {
          return const RoutineTransitionDecision.reject(
            message: 'Missed routine cannot be skipped.',
          );
        }
        return const RoutineTransitionDecision.allow();

      case RoutineOccurrenceAction.miss:
        if (status == RoutineStatus.completed) {
          return const RoutineTransitionDecision.reject(
            message: 'Completed routine cannot be marked missed.',
          );
        }
        if (status == RoutineStatus.skipped) {
          return const RoutineTransitionDecision.reject(
            message: 'Skipped routine cannot be marked missed.',
          );
        }
        if (status == RoutineStatus.missed) {
          return const RoutineTransitionDecision.noOp(
            message: 'Already marked missed.',
          );
        }
        return const RoutineTransitionDecision.allow();

      case RoutineOccurrenceAction.checkIn:
        if (status == RoutineStatus.completed) {
          return const RoutineTransitionDecision.noOp(
            message: 'Already completed.',
            failureCategory: RoutineFailureCategory.alreadyCompleted,
          );
        }
        if (status == RoutineStatus.skipped) {
          return const RoutineTransitionDecision.reject(
            message: 'Skipped routine cannot be checked in.',
          );
        }
        if (status == RoutineStatus.missed) {
          return const RoutineTransitionDecision.reject(
            message: 'Missed routine cannot be checked in.',
          );
        }
        return const RoutineTransitionDecision.allow();

      case RoutineOccurrenceAction.toggleSubtask:
        return const RoutineTransitionDecision.allow();
    }
  }
}
