import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';

abstract final class AuthErrorMapper {
  static const String emailAlreadyInUseMessage =
      'An account already exists with this email. Please log in. If your email is not verified yet, we’ll help you resend the verification email.';

  /// Maps an authentication or login/signup error into a safe RecoverableError.
  static RecoverableError map(Object error, {bool isBlocking = true}) {
    if (error is RecoverableError) {
      return error;
    }

    if (error is firebase_auth.FirebaseAuthException) {
      return _fromFirebaseAuthCode(error.code, isBlocking: isBlocking);
    }

    if (error is TimeoutException) {
      return RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage:
            'The request took too long. Check your connection and try again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: isBlocking,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkTimeout,
      );
    }

    if (error is SocketException || error is HttpException) {
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
    }

    final raw = error.toString().toLowerCase();

    if (raw.contains('timeoutexception') || raw.contains('timed out')) {
      return RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage:
            'The request took too long. Check your connection and try again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: isBlocking,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkTimeout,
      );
    }

    if (raw.contains('socketexception') ||
        raw.contains('network') ||
        raw.contains('connection refused') ||
        raw.contains('connection abort') ||
        raw.contains('network-request-failed')) {
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
    }

    if (raw.contains('email-already-in-use')) {
      return RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage: emailAlreadyInUseMessage,
        severity: RecoverableErrorSeverity.error,
        isBlocking: isBlocking,
        retryAction: RecoverableRetryAction.reauthenticate,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authEmailInUse,
      );
    }

    if (raw.contains('account-exists-with-different-credential') ||
        raw.contains('credential-already-in-use')) {
      return RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage:
            'An account already exists with this email. Sign in with your original method to continue.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: isBlocking,
        retryAction: RecoverableRetryAction.chooseAnother,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authAccountCollision,
      );
    }

    if (raw.contains('invalid-email')) {
      return RecoverableError(
        category: RecoverableErrorCategory.validation,
        publicMessage: 'Please enter a valid email address.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: isBlocking,
        retryAction: RecoverableRetryAction.none,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authInvalidEmail,
      );
    }

    if (raw.contains('wrong-password') ||
        raw.contains('user-not-found') ||
        raw.contains('invalid-credential') ||
        raw.contains('invalid-login-credentials')) {
      return RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage: 'Incorrect email or password. Please try again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: isBlocking,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.authInvalidCredentials,
      );
    }

    if (raw.contains('missing-user')) {
      return RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage: 'No signed-in user was found. Please log in again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: isBlocking,
        retryAction: RecoverableRetryAction.reauthenticate,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authMissingUser,
      );
    }

    if (raw.contains('invalid-user-token') ||
        raw.contains('user-token-expired') ||
        raw.contains('auth-token-expired')) {
      return RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage: 'Your session has expired. Please sign in again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: isBlocking,
        retryAction: RecoverableRetryAction.reauthenticate,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authSessionExpired,
      );
    }

    if (raw.contains('too-many-requests')) {
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
    }

    if (raw.contains('user-disabled')) {
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
    }

    if (raw.contains('weak-password')) {
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
    }

    if (raw.contains('requires-recent-login')) {
      return RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage: 'Please sign in again to complete this action.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: isBlocking,
        retryAction: RecoverableRetryAction.reauthenticate,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.authRequiresRecentLogin,
      );
    }

    // Safe firewall default: no raw error strings leaked to production UI
    return RecoverableError(
      category: RecoverableErrorCategory.authentication,
      publicMessage: 'Could not complete sign in right now. Please try again.',
      severity: RecoverableErrorSeverity.error,
      isBlocking: isBlocking,
      retryAction: RecoverableRetryAction.retry,
      retrySafe: true,
      diagnosticCode: DiagnosticCodes.authUnknown,
    );
  }

  /// Maps Verify Email lifecycle failures into safe RecoverableErrors.
  static RecoverableError mapVerifyEmailError(
    Object error, {
    required bool isResend,
  }) {
    // FirebaseAuthRepository deliberately normalizes backend exceptions before
    // they reach presentation code. Verify Email is a narrower context, so it
    // must refine both those structured errors and raw test/platform errors.
    final mapped = error is RecoverableError ? error : map(error);

    if (mapped.category == RecoverableErrorCategory.network) {
      return RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage: isResend
            ? 'Couldn’t resend the email. Check your connection and try again.'
            : 'Couldn’t check verification. Check your connection and try again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: mapped.diagnosticCode,
      );
    }

    if (mapped.diagnosticCode == DiagnosticCodes.authRateLimited ||
        mapped.diagnosticCode == DiagnosticCodes.verifyEmailRateLimited) {
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

    if (mapped.diagnosticCode == DiagnosticCodes.authSessionExpired ||
        mapped.diagnosticCode == DiagnosticCodes.verifyEmailSessionExpired) {
      return const RecoverableError(
        category: RecoverableErrorCategory.authentication,
        publicMessage:
            'Your verification session has expired. Please sign in again.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.reauthenticate,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.verifyEmailSessionExpired,
      );
    }

    return RecoverableError(
      category: RecoverableErrorCategory.authentication,
      publicMessage: isResend
          ? 'Couldn’t resend the email. Please try again.'
          : 'Couldn’t check verification. Please try again.',
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
          diagnosticCode: DiagnosticCodes.authInvalidEmail,
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
      case 'missing-user':
        return RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage: 'No signed-in user was found. Please log in again.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.reauthenticate,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authMissingUser,
        );
      case 'invalid-user-token':
      case 'user-token-expired':
      case 'auth-token-expired':
        return RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage: 'Your session has expired. Please sign in again.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.reauthenticate,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authSessionExpired,
        );
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage:
              'An account already exists with this email. Sign in with your original method to continue.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: isBlocking,
          retryAction: RecoverableRetryAction.chooseAnother,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authAccountCollision,
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
          diagnosticCode: DiagnosticCodes.authUnknown,
        );
    }
  }
}
