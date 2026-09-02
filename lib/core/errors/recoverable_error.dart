import 'package:flutter/foundation.dart';

/// User-level normalized categories for recoverable errors.
enum RecoverableErrorCategory {
  validation,
  network,
  authentication,
  permission,
  upload,
  aiTimeout,
  aiQuota,
  aiMalformedResponse,
  cloudPersistence,
  conflict,
  recoveryRequired,
  completionRetry,
}

/// Presentation/attention severity level (independent from retryability).
enum RecoverableErrorSeverity {
  info,
  warning,
  error,
  critical,
}

/// Semantic action describing how a failure can be addressed or retried.
enum RecoverableRetryAction {
  none,
  retry,
  retryUpload,
  retryGeneration,
  retrySave,
  reauthenticate,
  openSettings,
  chooseAnother,
  returnToStep,
  resumeCompletion,
  restartRecovery,
}

/// Typed recoverable error contract across Optivus.
///
/// Immutable contract containing normalized category, safe user-facing message,
/// severity, blocking semantics, retry semantics, and a stable diagnostic code.
@immutable
class RecoverableError {
  final RecoverableErrorCategory category;
  final String publicMessage;
  final RecoverableErrorSeverity severity;
  final bool isBlocking;
  final RecoverableRetryAction retryAction;
  final bool retrySafe;
  final String diagnosticCode;
  final String? title;
  final String? supportHint;

  const RecoverableError({
    required this.category,
    required this.publicMessage,
    required this.severity,
    required this.isBlocking,
    required this.retryAction,
    required this.retrySafe,
    required this.diagnosticCode,
    this.title,
    this.supportHint,
  });

  /// Alias for [isBlocking].
  bool get blocking => isBlocking;

  RecoverableError copyWith({
    RecoverableErrorCategory? category,
    String? publicMessage,
    RecoverableErrorSeverity? severity,
    bool? isBlocking,
    RecoverableRetryAction? retryAction,
    bool? retrySafe,
    String? diagnosticCode,
    String? title,
    String? supportHint,
  }) {
    return RecoverableError(
      category: category ?? this.category,
      publicMessage: publicMessage ?? this.publicMessage,
      severity: severity ?? this.severity,
      isBlocking: isBlocking ?? this.isBlocking,
      retryAction: retryAction ?? this.retryAction,
      retrySafe: retrySafe ?? this.retrySafe,
      diagnosticCode: diagnosticCode ?? this.diagnosticCode,
      title: title ?? this.title,
      supportHint: supportHint ?? this.supportHint,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecoverableError &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          publicMessage == other.publicMessage &&
          severity == other.severity &&
          isBlocking == other.isBlocking &&
          retryAction == other.retryAction &&
          retrySafe == other.retrySafe &&
          diagnosticCode == other.diagnosticCode &&
          title == other.title &&
          supportHint == other.supportHint;

  @override
  int get hashCode => Object.hash(
        category,
        publicMessage,
        severity,
        isBlocking,
        retryAction,
        retrySafe,
        diagnosticCode,
        title,
        supportHint,
      );

  @override
  String toString() =>
      'RecoverableError($diagnosticCode, category: ${category.name}, severity: ${severity.name}, blocking: $isBlocking, retrySafe: $retrySafe)';
}
