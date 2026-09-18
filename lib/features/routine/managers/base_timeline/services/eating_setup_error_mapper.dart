import 'dart:async';
import 'package:optivus/features/routine/managers/base_timeline/models/nutrition_ai_failure.dart';

/// Maps raw exceptions and errors occurring during Eating setup operations
/// into clear, user-actionable error messages and typed failures.
class EatingSetupErrorMapper {
  const EatingSetupErrorMapper._();

  static NutritionAiFailure mapFailure(Object error) {
    return NutritionAiFailure.fromObject(error);
  }

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

    if (lower.contains('missing_worker_url') ||
        lower.contains('worker_disabled')) {
      return 'AI generation service is currently unavailable. Please try again later.';
    }

    if (lower.contains('body basics')) {
      return 'Complete Body Basics before generating a personalized eating plan.';
    }

    return NutritionAiFailure.fromObject(error).safeMessage;
  }
}
