import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';

abstract final class PersistenceErrorMapper {
  /// Maps step sync and Firestore draft save failures to a truthful RecoverableError.
  static RecoverableError mapStepSyncFailure({int? step, Object? error}) {
    return const RecoverableError(
      category: RecoverableErrorCategory.cloudPersistence,
      publicMessage:
          'Couldn’t sync your changes. Your changes are still open here. Retry before leaving this step.',
      severity: RecoverableErrorSeverity.error,
      isBlocking: true,
      retryAction: RecoverableRetryAction.retrySave,
      retrySafe: true,
      diagnosticCode: DiagnosticCodes.firestoreDraftWriteFailed,
    );
  }

  /// Maps profile write failures.
  static RecoverableError mapProfileSaveFailure({Object? error}) {
    return const RecoverableError(
      category: RecoverableErrorCategory.cloudPersistence,
      publicMessage: 'We couldn’t save your profile changes yet. Please retry.',
      severity: RecoverableErrorSeverity.warning,
      isBlocking: false,
      retryAction: RecoverableRetryAction.retrySave,
      retrySafe: true,
      diagnosticCode: DiagnosticCodes.firestoreProfileWriteFailed,
    );
  }
}
