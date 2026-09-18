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

    if (lower.contains('timeout')) {
      return 'The request timed out. Please check your connection and try again.';
    }

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

    if (lower.contains('missing_worker_url') ||
        lower.contains('worker_disabled') ||
        lower.contains('service is unavailable') ||
        lower.contains('unavailable')) {
      return 'AI generation service is currently unavailable. Please try again later.';
    }

    if (lower.contains('body basics')) {
      return 'Complete Body Basics before generating a personalized eating plan.';
    }

    if (lower.contains('ai returned empty') ||
        lower.contains('no meals detected') ||
        lower.contains('dropped_no_dishes') ||
        lower.contains('not return specific dishes')) {
      return 'AI was unable to generate specific meals. Please try again or adjust your preferences.';
    }

    if (lower.contains('tolerance') ||
        lower.contains('calorie target') ||
        lower.contains('protein target') ||
        lower.contains('macro')) {
      return 'Generated meal plan could not meet required nutritional tolerances. Please adjust preferences and try again.';
    }

    if (lower.contains('diversity') || lower.contains('variety')) {
      return 'Generated meal plan did not meet weekly diversity requirements. Please try again.';
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
