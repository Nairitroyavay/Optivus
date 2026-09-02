import 'dart:io';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/models/onboarding_completion_job.dart';

abstract final class CompletionErrorMapper {
  /// Maps completion stage execution failures using structured evidence.
  static RecoverableError map({
    OnboardingCompletionJob? job,
    OnboardingCompletionStage? stage,
    Object? error,
    bool isContradiction = false,
  }) {
    if (error is RecoverableError) {
      return error;
    }

    // 1. Structured check for fatal failure or explicit contradiction
    if (isContradiction ||
        job?.status == OnboardingJobStatus.fatalFailure) {
      return const RecoverableError(
        category: RecoverableErrorCategory.recoveryRequired,
        publicMessage:
            'We found inconsistent saved setup data that needs recovery before continuing.',
        severity: RecoverableErrorSeverity.critical,
        isBlocking: true,
        retryAction: RecoverableRetryAction.restartRecovery,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.recoveryDurableStateConflict,
      );
    }

    // 2. Structured check for network transport failures
    if (error is SocketException || error is HttpException) {
      return const RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage:
            'We couldn’t connect right now. Check your connection and try again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.resumeCompletion,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkUnavailable,
      );
    }

    final raw = (error?.toString() ?? '').toLowerCase();

    if (raw.contains('socketexception') ||
        raw.contains('network') ||
        raw.contains('connection refused') ||
        raw.contains('connection abort')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage:
            'We couldn’t connect right now. Check your connection and try again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.resumeCompletion,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkUnavailable,
      );
    }

    if (raw.contains('permission-denied') ||
        raw.contains('unauthenticated') ||
        raw.contains('requires-recent-login') ||
        raw.contains('auth')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage:
            'Your session needs to be refreshed. Please sign in again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.reauthenticate,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authSessionExpired,
      );
    }

    if (raw.contains('firestore') ||
        raw.contains('commit') ||
        raw.contains('persistence')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.cloudPersistence,
        publicMessage:
            'We couldn’t save final completion state yet. Retry to continue.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.resumeCompletion,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.firestoreDraftWriteFailed,
      );
    }

    if (raw.contains('contradiction') ||
        raw.contains('owner mismatch') ||
        raw.contains('schema') ||
        raw.contains('corrupt') ||
        raw.contains('dangling')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.recoveryRequired,
        publicMessage:
            'We found inconsistent saved setup data that needs recovery before continuing.',
        severity: RecoverableErrorSeverity.critical,
        isBlocking: true,
        retryAction: RecoverableRetryAction.restartRecovery,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.recoveryDurableStateConflict,
      );
    }

    // Default for Step 14 recoverable verification / reconciliation failure
    return const RecoverableError(
      category: RecoverableErrorCategory.completionRetry,
      publicMessage:
          'Your setup is saved, but final preparation didn’t finish. Tap Enter Optivus to resume.',
      severity: RecoverableErrorSeverity.error,
      isBlocking: true,
      retryAction: RecoverableRetryAction.resumeCompletion,
      retrySafe: true,
      diagnosticCode: DiagnosticCodes.completionVerifyFailed,
    );
  }
}
