import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';

abstract final class AuthErrorMapper {
  static const String emailAlreadyInUseMessage =
      'An account already exists with this email. Please log in. If your email is not verified yet, we’ll help you resend the verification email.';

  /// Maps an authentication or login/signup error into a safe RecoverableError.
  static RecoverableError map(
    Object error, {
    bool isBlocking = true,
  }) {
    if (error is RecoverableError) {
      return error;
    }

    if (error is firebase_auth.FirebaseAuthException) {
      return _fromFirebaseAuthCode(error.code, isBlocking: isBlocking);
    }

    if (error is SocketException ||
        error is HttpException) {
      return const RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage:
            'We couldn’t connect right now. Check your connection and try again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkUnavailable,
      );
    }

    final raw = error.toString().toLowerCase();

    if (raw.contains('socketexception') ||
        raw.contains('timeoutexception') ||
        raw.contains('network') ||
        raw.contains('connection refused') ||
        raw.contains('connection abort') ||
        raw.contains('network-request-failed')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage:
            'We couldn’t connect right now. Check your connection and try again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkUnavailable,
      );
    }

    if (raw.contains('email-already-in-use')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage: emailAlreadyInUseMessage,
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.reauthenticate,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authEmailInUse,
      );
    }

    if (raw.contains('wrong-password') ||
        raw.contains('user-not-found') ||
        raw.contains('invalid-credential') ||
        raw.contains('invalid-login-credentials')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage: 'Incorrect email or password. Please try again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.authInvalidCredentials,
      );
    }

    if (raw.contains('too-many-requests')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage:
            'Too many attempts. Please wait a little before trying again.',
        severity: RecoverableErrorSeverity.warning,
        isBlocking: true,
        retryAction: RecoverableRetryAction.none,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authRateLimited,
      );
    }

    if (raw.contains('user-disabled')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage:
            'This account has been disabled. Please contact support.',
        severity: RecoverableErrorSeverity.critical,
        isBlocking: true,
        retryAction: RecoverableRetryAction.none,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authUserDisabled,
      );
    }

    if (raw.contains('weak-password')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.validation,
        publicMessage:
            'Password must be at least 8 characters and include both letters and numbers.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.none,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authWeakPassword,
      );
    }

    if (raw.contains('requires-recent-login')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage: 'Please sign in again to complete this action.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.reauthenticate,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authRequiresRecentLogin,
      );
    }

    // Safe firewall default: no raw error strings leaked to production UI
    return const RecoverableError(
      category: RecoverableErrorCategory.authentication,
      publicMessage:
          'Could not complete sign in right now. Please try again.',
      severity: RecoverableErrorSeverity.error,
      isBlocking: true,
      retryAction: RecoverableRetryAction.retry,
      retrySafe: true,
      diagnosticCode: DiagnosticCodes.authInvalidCredentials,
    );
  }

  /// Maps Verify Email lifecycle failures into safe RecoverableErrors.
  static RecoverableError mapVerifyEmailError(
    Object error, {
    required bool isResend,
  }) {
    if (error is RecoverableError) return error;

    final raw = error.toString().toLowerCase();

    if (error is SocketException ||
        raw.contains('socketexception') ||
        raw.contains('network') ||
        raw.contains('connection refused')) {
      return RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage: isResend
            ? 'Couldn’t resend the email. Check your connection and try again.'
            : 'Couldn’t check verification. Check your connection and try again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkUnavailable,
      );
    }

    if (raw.contains('too-many-requests')) {
      return const RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage:
            'Too many verification attempts. Please wait a little before trying again.',
        severity: RecoverableErrorSeverity.warning,
        isBlocking: true,
        retryAction: RecoverableRetryAction.none,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.verifyEmailRateLimited,
      );
    }

    return RecoverableError(
      category: RecoverableErrorCategory.authentication,
      publicMessage: isResend
          ? 'Couldn’t resend the verification email. Please try again.'
          : 'Couldn’t check verification status. Please try again.',
      severity: RecoverableErrorSeverity.error,
      isBlocking: true,
      retryAction: RecoverableRetryAction.retry,
      retrySafe: true,
      diagnosticCode: isResend
          ? DiagnosticCodes.verifyEmailResendFailed
          : DiagnosticCodes.verifyEmailCheckFailed,
    );
  }

  static RecoverableError _fromFirebaseAuthCode(
    String code, {
    required bool isBlocking,
  }) {
    switch (code) {
      case 'email-already-in-use':
        return RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage: emailAlreadyInUseMessage,
          severity: RecoverableErrorSeverity.error,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.reauthenticate,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authEmailInUse,
        );
      case 'invalid-email':
        return RecoverableError(
          category: RecoverableErrorCategory.validation,
          publicMessage: 'Please enter a valid email address.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.none,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.validationInvalidFormat,
        );
      case 'user-disabled':
        return RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage:
              'This account has been disabled. Please contact support.',
          severity: RecoverableErrorSeverity.critical,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.none,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authUserDisabled,
        );
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage: 'Incorrect email or password. Please try again.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.retry,
          retrySafe: true,
          diagnosticCode: DiagnosticCodes.authInvalidCredentials,
        );
      case 'weak-password':
        return RecoverableError(
          category: RecoverableErrorCategory.validation,
          publicMessage:
              'Password must be at least 8 characters and include both letters and numbers.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.none,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authWeakPassword,
        );
      case 'too-many-requests':
        return RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage:
              'Too many attempts. Please wait a little before trying again.',
          severity: RecoverableErrorSeverity.warning,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.none,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authRateLimited,
        );
      case 'network-request-failed':
        return RecoverableError(
          category: RecoverableErrorCategory.network,
          publicMessage:
              'We couldn’t connect right now. Check your connection and try again.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.retry,
          retrySafe: true,
          diagnosticCode: DiagnosticCodes.networkUnavailable,
        );
      case 'requires-recent-login':
        return RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage: 'Please sign in again to complete this action.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.reauthenticate,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authRequiresRecentLogin,
        );
      default:
        return RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage:
              'Could not complete sign in right now. Please try again.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.retry,
          retrySafe: true,
          diagnosticCode: DiagnosticCodes.authInvalidCredentials,
        );
    }
  }
}
