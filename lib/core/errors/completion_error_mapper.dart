import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
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

    // Durable failure evidence wins over incidental text in the thrown cause.
    if (job != null && job.lastFailureCode != null) {
      final auth =
          job.diagnosticCategory == 'authentication' ||
          job.publicMessageKey == 'error_unauthenticated';
      final persistence = job.diagnosticCategory == 'cloud_persistence';
      final network = job.lastFailureCode == 'COMPLETION_NETWORK_UNAVAILABLE';
      final retry =
          job.retryable == true &&
          job.status != OnboardingJobStatus.fatalFailure &&
          !isContradiction;
      return RecoverableError(
        category: auth
            ? RecoverableErrorCategory.authentication
            : network
            ? RecoverableErrorCategory.network
            : isContradiction || !retry
            ? RecoverableErrorCategory.recoveryRequired
            : persistence
            ? RecoverableErrorCategory.cloudPersistence
            : RecoverableErrorCategory.completionRetry,
        publicMessage: auth
            ? 'Your session needs to be refreshed. Please sign in again.'
            : persistence
            ? 'We couldn’t save final completion state yet. Retry to continue.'
            : !retry
            ? 'Your saved setup needs recovery before continuing.'
            : 'Final preparation didn’t finish. Try again to resume your setup.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: auth
            ? RecoverableRetryAction.reauthenticate
            : retry
            ? RecoverableRetryAction.resumeCompletion
            : RecoverableRetryAction.restartRecovery,
        retrySafe: retry && !auth,
        diagnosticCode: safeCode(job.lastFailureCode),
        supportHint: safeStage(job.lastFailureStage ?? stage?.name),
      );
    }

    if (error is FirebaseException) {
      final auth =
          error.code == 'unauthenticated' ||
          error.code == 'requires-recent-login' ||
          error.code == 'user-token-expired';
      return RecoverableError(
        category: auth
            ? RecoverableErrorCategory.authentication
            : RecoverableErrorCategory.cloudPersistence,
        publicMessage: auth
            ? 'Your session needs to be refreshed. Please sign in again.'
            : 'We couldn’t save final completion state yet. Retry to continue.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: auth
            ? RecoverableRetryAction.reauthenticate
            : RecoverableRetryAction.resumeCompletion,
        retrySafe: !auth,
        diagnosticCode: auth
            ? DiagnosticCodes.authSessionExpired
            : error.code == 'permission-denied'
            ? 'COMPLETION_PERSISTENCE_PERMISSION_DENIED'
            : 'COMPLETION_PERSISTENCE_FAILED',
        supportHint: safeStage(stage?.name),
      );
    }

    // 1. Structured check for fatal failure or explicit contradiction
    if (isContradiction || job?.status == OnboardingJobStatus.fatalFailure) {
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

    if (raw.contains('unauthenticated') ||
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

    if (raw.contains('permission-denied') ||
        raw.contains('firestore') ||
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

  static String safeStage(String? value) =>
      OnboardingCompletionStage.values.any((stage) => stage.name == value) ||
          value == 'authHandoff'
      ? value!
      : 'unknown';

  static String safeCode(String? value) => _publicCodes.contains(value)
      ? value!
      : DiagnosticCodes.completionVerifyFailed;

  static const _publicCodes = {
    DiagnosticCodes.completionVerifyFailed,
    DiagnosticCodes.completionRoutineAccountingFailed,
    DiagnosticCodes.completionHabitReadbackFailed,
    DiagnosticCodes.completionTerminalizationPending,
    DiagnosticCodes.completionResumeRequired,
    DiagnosticCodes.authSessionExpired,
    DiagnosticCodes.networkUnavailable,
    DiagnosticCodes.firestoreDraftWriteFailed,
    DiagnosticCodes.recoveryDurableStateConflict,
    'COMPLETION_ACTIVATION_PERMISSION_DENIED',
    'COMPLETION_PERSISTENCE_PERMISSION_DENIED',
    'COMPLETION_ACTIVATION_FAILED',
    'COMPLETION_PERSISTENCE_FAILED',
    'COMPLETION_UNAUTHENTICATED',
    'COMPLETION_NETWORK_UNAVAILABLE',
    'receiptMissing',
    'ownerMismatch',
    'fingerprintMismatch',
    'invalidStatus',
    'invalidCursor',
    'malformedReceipt',
    'retryRequired',
    'state_error',
    'argument_error',
    'unhandled_exception',
    'retry_required',
    'habit_system_projection_write_failed',
    'habit_system_projection_persistence_invalid',
    'habit_system_projection_controller_invalid',
  };
}
