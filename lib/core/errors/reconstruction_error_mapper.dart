import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/services/server_reconstructor.dart';

abstract final class ReconstructionErrorMapper {
  /// Maps a session reconstruction recovery reason into a typed [RecoverableError].
  static RecoverableError fromRecoveryReason(
    ReconstructionRecoveryReason reason, {
    String? code,
  }) {
    final diagnosticCode = switch (reason) {
      ReconstructionRecoveryReason.schemaUnsupported =>
        DiagnosticCodes.recoverySchemaUnsupported,
      ReconstructionRecoveryReason.ownerMismatch =>
        DiagnosticCodes.recoveryOwnerMismatch,
      ReconstructionRecoveryReason.missingCurrentRun =>
        DiagnosticCodes.recoveryMissingCurrentRun,
      ReconstructionRecoveryReason.danglingRunReference =>
        DiagnosticCodes.recoveryDanglingRunReference,
      ReconstructionRecoveryReason.durableStateConflict =>
        DiagnosticCodes.recoveryDurableStateConflict,
      ReconstructionRecoveryReason.invalidCompletionBundle =>
        DiagnosticCodes.recoveryInvalidCompletionBundle,
      ReconstructionRecoveryReason.completionFatalFailure =>
        DiagnosticCodes.recoveryCompletionFatal,
      ReconstructionRecoveryReason.invalidDraft ||
      ReconstructionRecoveryReason.missingProfile =>
        DiagnosticCodes.recoveryCorruptDraft,
      ReconstructionRecoveryReason.unknown =>
        DiagnosticCodes.recoveryDurableStateConflict,
    };

    return RecoverableError(
      category: RecoverableErrorCategory.recoveryRequired,
      publicMessage:
          'We found inconsistent saved setup data that needs recovery before continuing.',
      severity: RecoverableErrorSeverity.critical,
      isBlocking: true,
      retryAction: RecoverableRetryAction.restartRecovery,
      retrySafe: false,
      diagnosticCode: diagnosticCode,
    );
  }

  /// Maps a bootstrap exception during initial server reconstruction.
  static RecoverableError fromBootstrapException(
    ReconstructionBootstrapException exception,
  ) {
    return switch (exception.reason) {
      ReconstructionBootstrapFailureReason.permissionDenied =>
        const RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage:
              'Your session has expired. Please sign in again.',
          severity: RecoverableErrorSeverity.critical,
          isBlocking: true,
          retryAction: RecoverableRetryAction.reauthenticate,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authSessionExpired,
        ),
      ReconstructionBootstrapFailureReason.backendUnavailable ||
      ReconstructionBootstrapFailureReason.timeout =>
        const RecoverableError(
          category: RecoverableErrorCategory.network,
          publicMessage:
              'We couldn’t connect right now. Check your connection and try again.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.retry,
          retrySafe: true,
          diagnosticCode: DiagnosticCodes.networkUnavailable,
        ),
      ReconstructionBootstrapFailureReason.unknown =>
        const RecoverableError(
          category: RecoverableErrorCategory.network,
          publicMessage:
              'We couldn’t connect right now. Check your connection and try again.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.retry,
          retrySafe: true,
          diagnosticCode: DiagnosticCodes.networkUnavailable,
        ),
    };
  }
}
