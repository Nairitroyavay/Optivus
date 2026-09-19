import 'dart:async';
import 'package:optivus/features/routine/managers/base_timeline/models/nutrition_ai_failure.dart';

/// Maps raw exceptions and errors occurring during Eating setup operations
/// into clear, user-actionable error messages and typed failures.
class EatingSetupErrorMapper {
  const EatingSetupErrorMapper._();

  static NutritionAiFailure mapFailure(Object error) {
    return NutritionAiFailure.fromObject(error);
  }

  /// Product-safe copy for post-commit Routine reconciliation failures.
  static String mapRefreshError(Object? error) {
    return "Routine couldn't refresh yet. Please try again.";
  }

  static String mapError(Object error) {
    if (error is TimeoutException) {
      return 'The request timed out. Please check your connection and try again.';
    }

    final message = error.toString();
    final lower = message.toLowerCase();

    // Validation failures
    if (lower.contains('validation') || lower.contains('invalid argument')) {
      return 'Some information is incomplete or invalid. Please check your inputs and try again.';
    }

    // Permission denied / backend configuration
    if (lower.contains('permission-denied') ||
        lower.contains('permission denied')) {
      return 'You do not have permission to perform this action. Check your account permissions.';
    }

    // Network unavailable
    if (lower.contains('socketexception') ||
        lower.contains('network') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused')) {
      return 'Network unavailable. Please check your internet connection and try again.';
    }

    // Authentication / account mismatch
    if (lower.contains('unauthenticated') ||
        lower.contains('auth/user-not-found') ||
        lower.contains('auth/')) {
      return 'Authentication failed or account mismatch. Please sign in again.';
    }

    if (lower.contains('concurrency') ||
        lower.contains('conflict') ||
        lower.contains('revision mismatch')) {
      return 'This setup changed elsewhere. Reload the latest setup before saving again.';
    }

    if (lower.contains('missing_worker_url') ||
        lower.contains('worker_disabled')) {
      return 'AI generation service is currently unavailable. Please try again later.';
    }

    if (lower.contains('body basics')) {
      return 'Complete Body Basics before generating a personalized eating plan.';
    }

    return NutritionAiFailure.fromObject(error).safeMessage;
  }

  static String mapSaveError(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('revision mismatch') ||
        lower.contains('concurrency') ||
        lower.contains('conflict')) {
      return 'This setup changed elsewhere. Reload the latest setup before saving again.';
    }
    if (lower.contains('permission-denied') ||
        lower.contains('permission denied')) {
      return "Couldn't save this Eating setup because setup permissions are unavailable. Your edits are still here.";
    }
    if (lower.contains('unauthenticated') ||
        lower.contains('account mismatch') ||
        lower.contains('auth/')) {
      return 'Your session changed. Sign in again, then retry; your edits are still here.';
    }
    if (error is TimeoutException ||
        lower.contains('network') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('unavailable')) {
      return "Couldn't reach the server. Check your connection and retry; your edits are still here.";
    }
    if (lower.contains('argumenterror') || lower.contains('validation')) {
      return 'Some meal-plan information is invalid. Review the highlighted details and try again.';
    }
    return "Couldn't save your meal plan. Your edits are still here; please try again.";
  }
}
