import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';

abstract final class TimelineErrorMapper {
  /// Maps missing timetable / schedule requirements to a validation error.
  static RecoverableError missingRequiredBlocks(String message) {
    return RecoverableError(
      category: RecoverableErrorCategory.validation,
      publicMessage: message,
      severity: RecoverableErrorSeverity.error,
      isBlocking: true,
      retryAction: RecoverableRetryAction.none,
      retrySafe: false,
      diagnosticCode: DiagnosticCodes.validationMissingTimetable,
    );
  }

  /// Maps unresolved blocking conflicts to a conflict error.
  static RecoverableError unresolvedConflict(String message) {
    return RecoverableError(
      category: RecoverableErrorCategory.conflict,
      publicMessage: message.isNotEmpty
          ? message
          : 'These times overlap and need your decision.',
      severity: RecoverableErrorSeverity.error,
      isBlocking: true,
      retryAction: RecoverableRetryAction.none,
      retrySafe: false,
      diagnosticCode: DiagnosticCodes.timelineUnresolvedConflict,
    );
  }
}
