import 'package:optivus/features/routine/services/routine_validation_service.dart';

enum RoutineWriteOutcome {
  saved,
  validationFailed,
  retryRequired,
  noOp,
  superseded,
}

class RoutineWriteResult {
  final RoutineWriteOutcome outcome;
  final RoutineValidationResult? validation;
  final String? message;
  final String? operationId;

  const RoutineWriteResult({
    required this.outcome,
    this.validation,
    this.message,
    this.operationId,
  });

  const RoutineWriteResult.saved({
    this.validation,
    this.message,
    this.operationId,
  }) : outcome = RoutineWriteOutcome.saved;

  const RoutineWriteResult.validationFailed(
    this.validation, {
    this.message,
    this.operationId,
  }) : outcome = RoutineWriteOutcome.validationFailed;

  const RoutineWriteResult.retryRequired({
    this.validation,
    this.message,
    this.operationId,
  }) : outcome = RoutineWriteOutcome.retryRequired;

  const RoutineWriteResult.noOp({
    this.validation,
    this.message,
    this.operationId,
  }) : outcome = RoutineWriteOutcome.noOp;

  const RoutineWriteResult.superseded({
    this.validation,
    this.message,
    this.operationId,
  }) : outcome = RoutineWriteOutcome.superseded;

  bool get closesUserFlow =>
      outcome == RoutineWriteOutcome.saved ||
      outcome == RoutineWriteOutcome.noOp;
}
