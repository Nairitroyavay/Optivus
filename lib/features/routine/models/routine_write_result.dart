import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/models/routine_item.dart';

enum RoutineWriteOutcome {
  saved,
  validationFailed,
  retryRequired,
  noOp,
  superseded,
}

enum RoutineFailureCategory {
  none,
  offlineOrUnavailable,
  deadlineExceeded,
  permissionDenied,
  validation,
  ownerSuperseded,
  alreadyActive,
  alreadyCompleted,
  invalidTransition,
  unknown,
}

class RoutineWriteResult {
  final RoutineWriteOutcome outcome;
  final RoutineValidationResult? validation;
  final String? message;
  final String? operationId;
  final RoutineFailureCategory? failureCategory;

  /// Logical status produced by this exact operation. Null when it cannot be
  /// trusted (for example, an owner-superseded operation).
  final RoutineStatus? resultingStatus;

  const RoutineWriteResult({
    required this.outcome,
    this.validation,
    this.message,
    this.operationId,
    this.failureCategory,
    this.resultingStatus,
  });

  const RoutineWriteResult.saved({
    this.validation,
    this.message,
    this.operationId,
    this.failureCategory = RoutineFailureCategory.none,
    this.resultingStatus,
  }) : outcome = RoutineWriteOutcome.saved;

  const RoutineWriteResult.validationFailed(
    this.validation, {
    this.message,
    this.operationId,
    this.failureCategory = RoutineFailureCategory.validation,
    this.resultingStatus,
  }) : outcome = RoutineWriteOutcome.validationFailed;

  const RoutineWriteResult.retryRequired({
    this.validation,
    this.message,
    this.operationId,
    this.failureCategory = RoutineFailureCategory.unknown,
    this.resultingStatus,
  }) : outcome = RoutineWriteOutcome.retryRequired;

  const RoutineWriteResult.noOp({
    this.validation,
    this.message,
    this.operationId,
    this.failureCategory = RoutineFailureCategory.none,
    this.resultingStatus,
  }) : outcome = RoutineWriteOutcome.noOp;

  const RoutineWriteResult.superseded({
    this.validation,
    this.message,
    this.operationId,
    this.failureCategory = RoutineFailureCategory.ownerSuperseded,
    this.resultingStatus,
  }) : outcome = RoutineWriteOutcome.superseded;

  bool get closesUserFlow =>
      outcome == RoutineWriteOutcome.saved ||
      outcome == RoutineWriteOutcome.noOp;
}
