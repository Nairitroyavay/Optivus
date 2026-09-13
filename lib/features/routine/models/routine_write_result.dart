import 'package:optivus/features/routine/services/routine_validation_service.dart';

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

  const RoutineWriteResult({
    required this.outcome,
    this.validation,
    this.message,
    this.operationId,
    this.failureCategory,
  });

  const RoutineWriteResult.saved({
    this.validation,
    this.message,
    this.operationId,
    this.failureCategory = RoutineFailureCategory.none,
  }) : outcome = RoutineWriteOutcome.saved;

  const RoutineWriteResult.validationFailed(
    this.validation, {
    this.message,
    this.operationId,
    this.failureCategory = RoutineFailureCategory.validation,
  }) : outcome = RoutineWriteOutcome.validationFailed;

  const RoutineWriteResult.retryRequired({
    this.validation,
    this.message,
    this.operationId,
    this.failureCategory = RoutineFailureCategory.unknown,
  }) : outcome = RoutineWriteOutcome.retryRequired;

  const RoutineWriteResult.noOp({
    this.validation,
    this.message,
    this.operationId,
    this.failureCategory = RoutineFailureCategory.none,
  }) : outcome = RoutineWriteOutcome.noOp;

  const RoutineWriteResult.superseded({
    this.validation,
    this.message,
    this.operationId,
    this.failureCategory = RoutineFailureCategory.ownerSuperseded,
  }) : outcome = RoutineWriteOutcome.superseded;

  bool get closesUserFlow =>
      outcome == RoutineWriteOutcome.saved ||
      outcome == RoutineWriteOutcome.noOp;
}
