import 'package:flutter/foundation.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_transition_policy.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';

/// Immutable action availability presentation model for Routine occurrences.
///
/// Evaluates action availability independently using [RoutineTransitionPolicy]
/// so the UI never infers Done from Move or Move from Done/completed alone.
@immutable
class RoutineActionAvailability {
  final RoutineTransitionDecision startDecision;
  final RoutineTransitionDecision completeDecision;
  final RoutineTransitionDecision moveDecision;
  final RoutineTransitionDecision undoDecision;
  final RoutineTransitionDecision skipDecision;
  final RoutineTransitionDecision missDecision;

  const RoutineActionAvailability({
    required this.startDecision,
    required this.completeDecision,
    required this.moveDecision,
    required this.undoDecision,
    required this.skipDecision,
    required this.missDecision,
  });

  /// Factory creating an availability model for an occurrence given its
  /// existing record (if any), status, and block type.
  factory RoutineActionAvailability.forOccurrence({
    required RoutineOccurrenceRecord? existingRecord,
    required RoutineStatus status,
    required RoutineBlockType blockType,
  }) {
    final startAction = blockType == RoutineBlockType.trackerTask
        ? RoutineOccurrenceAction.startTracker
        : RoutineOccurrenceAction.start;

    return RoutineActionAvailability(
      startDecision: RoutineTransitionPolicy.evaluate(
        existingRecord: existingRecord,
        requestedAction: startAction,
        projectedStatus: status,
      ),
      completeDecision: RoutineTransitionPolicy.evaluate(
        existingRecord: existingRecord,
        requestedAction: RoutineOccurrenceAction.complete,
        projectedStatus: status,
      ),
      moveDecision: RoutineTransitionPolicy.evaluate(
        existingRecord: existingRecord,
        requestedAction: RoutineOccurrenceAction.move,
        projectedStatus: status,
      ),
      undoDecision: RoutineTransitionPolicy.evaluate(
        existingRecord: existingRecord,
        requestedAction: RoutineOccurrenceAction.undo,
        projectedStatus: status,
      ),
      skipDecision: RoutineTransitionPolicy.evaluate(
        existingRecord: existingRecord,
        requestedAction: RoutineOccurrenceAction.skip,
        projectedStatus: status,
      ),
      missDecision: RoutineTransitionPolicy.evaluate(
        existingRecord: existingRecord,
        requestedAction: RoutineOccurrenceAction.miss,
        projectedStatus: status,
      ),
    );
  }

  bool get canStart => startDecision.isAllowed;
  bool get canComplete => completeDecision.isAllowed;
  bool get canMove => moveDecision.isAllowed;
  bool get canUndo => undoDecision.isAllowed;
  bool get canSkip => skipDecision.isAllowed;
  bool get canMiss => missDecision.isAllowed;
}
