import 'dart:async';

/// Maps raw exceptions and errors occurring during Eating setup operations
/// into clear, user-actionable error messages.
class EatingSetupErrorMapper {
  const EatingSetupErrorMapper._();

  static String mapError(Object error) {
    if (error is TimeoutException) {
      return 'The request timed out. Please check your connection and try again.';
    }

    final message = error.toString();
    final lower = message.toLowerCase();

    if (lower.contains('concurrency') ||
        lower.contains('conflict') ||
        lower.contains('revision mismatch')) {
      return 'This setup changed elsewhere. Reload the latest setup before saving again.';
    }

    if (lower.contains('unauthenticated') ||
        lower.contains('session expired') ||
        lower.contains('active account changed') ||
        lower.contains('auth')) {
      return 'Your session has expired or account changed. Please reload Eating setup.';
    }

    if (lower.contains('network') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    if (lower.contains('ai returned empty') ||
        lower.contains('no meals detected') ||
        lower.contains('dropped_no_dishes')) {
      return 'AI was unable to generate specific meals. Please try again or adjust your preferences.';
    }

    if (lower.contains('body basics')) {
      return 'Complete Body Basics before generating a personalized eating plan.';
    }

    // Strip common Dart exception prefixes if present
    var clean = message
        .replaceAll(RegExp(r'^(Exception|StateError|ArgumentError):\s*'), '')
        .trim();

    if (clean.isEmpty) {
      return 'An unexpected error occurred. Please try again.';
    }

    return clean;
  }
}
