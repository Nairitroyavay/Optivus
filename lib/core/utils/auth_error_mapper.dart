import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

enum AuthFailureReason {
  networkFailure,
  invalidCredentials,
  invalidToken,
  emailAlreadyInUse,
  accountCollision,
  weakPassword,
  userDisabled,
  tooManyRequests,
  unknown,
}

class AuthFailureException implements Exception {
  final AuthFailureReason reason;
  final String message;
  final Object? originalError;

  const AuthFailureException({
    required this.reason,
    required this.message,
    this.originalError,
  });

  @override
  String toString() => 'AuthFailureException($reason): $message';
}

const emailAlreadyInUseMessage =
    'An account already exists with this email. Please log in. If your email is not verified yet, we’ll help you resend the verification email.';

AuthFailureException mapAuthError(Object error) {
  if (error is AuthFailureException) {
    return error;
  }

  if (error is firebase_auth.FirebaseAuthException) {
    final reason = _reasonForCode(error.code);
    final message = _messageForCode(error.code);
    return AuthFailureException(
      reason: reason,
      message: message,
      originalError: error,
    );
  }

  final raw = error.toString();

  // Check code substrings
  for (final entry in _codeReasons.entries) {
    if (raw.contains(entry.key)) {
      return AuthFailureException(
        reason: entry.value,
        message: _messageForCode(entry.key),
        originalError: error,
      );
    }
  }

  if (raw.contains('SocketException') ||
      raw.contains('TimeoutException') ||
      raw.contains('network') ||
      raw.contains('Connection refused') ||
      raw.contains('connection abort')) {
    return AuthFailureException(
      reason: AuthFailureReason.networkFailure,
      message: _codeMessages['network-request-failed']!,
      originalError: error,
    );
  }

  var message = raw;
  if (message.startsWith('Exception: ')) {
    message = message.replaceFirst('Exception: ', '');
  } else if (message.trim().isEmpty) {
    message = 'Something went wrong. Please try again.';
  }

  return AuthFailureException(
    reason: AuthFailureReason.unknown,
    message: message,
    originalError: error,
  );
}

String friendlyAuthError(Object error) {
  return mapAuthError(error).message;
}

bool isEmailAlreadyInUseError(Object error) {
  if (error is AuthFailureException) {
    return error.reason == AuthFailureReason.emailAlreadyInUse;
  }
  if (error is firebase_auth.FirebaseAuthException) {
    return error.code == 'email-already-in-use';
  }
  return error.toString().contains('email-already-in-use');
}

AuthFailureReason _reasonForCode(String code) {
  return _codeReasons[code] ?? AuthFailureReason.unknown;
}

String _messageForCode(String code) {
  return _codeMessages[code] ?? 'Something went wrong. Please try again.';
}

const _codeReasons = <String, AuthFailureReason>{
  'email-already-in-use': AuthFailureReason.emailAlreadyInUse,
  'invalid-email': AuthFailureReason.invalidCredentials,
  'weak-password': AuthFailureReason.weakPassword,
  'wrong-password': AuthFailureReason.invalidCredentials,
  'user-not-found': AuthFailureReason.invalidCredentials,
  'invalid-credential': AuthFailureReason.invalidCredentials,
  'network-request-failed': AuthFailureReason.networkFailure,
  'too-many-requests': AuthFailureReason.tooManyRequests,
  'user-disabled': AuthFailureReason.userDisabled,
  'missing-user': AuthFailureReason.invalidCredentials,
  'invalid-user-token': AuthFailureReason.invalidToken,
  'user-token-expired': AuthFailureReason.invalidToken,
  'auth-token-expired': AuthFailureReason.invalidToken,
};

const _codeMessages = <String, String>{
  'email-already-in-use': emailAlreadyInUseMessage,
  'invalid-email': 'Please enter a valid email address.',
  'weak-password': 'Please choose a stronger password.',
  'wrong-password': 'The email or password is incorrect.',
  'user-not-found': 'No account was found for this email.',
  'invalid-credential': 'The email or password is incorrect.',
  'network-request-failed': 'Network error. Check your connection and retry.',
  'too-many-requests': 'Too many attempts. Please wait and try again.',
  'user-disabled': 'This account has been disabled.',
  'missing-user': 'No signed-in user was found. Please log in again.',
  'invalid-user-token': 'Session expired. Please sign in again.',
  'user-token-expired': 'Session expired. Please sign in again.',
  'auth-token-expired': 'Session expired. Please sign in again.',
};
