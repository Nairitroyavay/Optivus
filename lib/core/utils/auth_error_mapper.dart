import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

String friendlyAuthError(Object error) {
  if (error is firebase_auth.FirebaseAuthException) {
    return _messageForCode(error.code);
  }

  final raw = error.toString();
  for (final code in _codeMessages.keys) {
    if (raw.contains(code)) return _messageForCode(code);
  }

  if (raw.startsWith('Exception: ')) {
    return raw.replaceFirst('Exception: ', '');
  }

  return 'Something went wrong. Please try again.';
}

String _messageForCode(String code) {
  return _codeMessages[code] ?? 'Something went wrong. Please try again.';
}

const _codeMessages = <String, String>{
  'email-already-in-use':
      'An account already exists for this email. Please log in instead.',
  'invalid-email': 'Please enter a valid email address.',
  'weak-password': 'Please choose a stronger password.',
  'wrong-password': 'The email or password is incorrect.',
  'user-not-found': 'No account was found for this email.',
  'invalid-credential': 'The email or password is incorrect.',
  'network-request-failed': 'Network error. Check your connection and retry.',
  'too-many-requests': 'Too many attempts. Please wait and try again.',
  'user-disabled': 'This account has been disabled.',
  'missing-user': 'No signed-in user was found. Please log in again.',
};
