import 'dart:async';

/// Categorized failure types for Eating AI generation and operations.
enum NutritionAiFailureType {
  rateLimited,
  highDemand,
  modelConfig,
  incompleteWeek,
  targetMismatch,
  insufficientDiversity,
  dietViolation,
  timeout,
  auth,
  network,
  cancelled,
  unknown,
}

/// Typed, user-actionable representation of a nutrition generation failure.
class NutritionAiFailure {
  final NutritionAiFailureType type;
  final String safeMessage;
  final String? detailedMessage;
  final bool canRetry;
  final bool requiresPreferenceAdjustment;
  final String? requestId;

  const NutritionAiFailure({
    required this.type,
    required this.safeMessage,
    this.detailedMessage,
    required this.canRetry,
    this.requiresPreferenceAdjustment = false,
    this.requestId,
  });

  factory NutritionAiFailure.fromObject(Object error) {
    if (error is TimeoutException) {
      return const NutritionAiFailure(
        type: NutritionAiFailureType.timeout,
        safeMessage:
            'Meal generation took longer than expected. Please check your connection and try again.',
        canRetry: true,
      );
    }

    final raw = error.toString();
    final lower = raw.toLowerCase();

    String? extractedReqId;
    final reqIdMatch = RegExp(r'request_id:([a-zA-Z0-9_-]+)').firstMatch(raw);
    if (reqIdMatch != null) {
      extractedReqId = reqIdMatch.group(1);
    }

    if (lower.contains('provider_cancelled') ||
        lower.contains('request was cancelled') ||
        lower.contains('operation cancelled')) {
      return NutritionAiFailure(
        type: NutritionAiFailureType.cancelled,
        safeMessage: 'Meal generation was cancelled.',
        detailedMessage: raw,
        canRetry: false,
        requestId: extractedReqId,
      );
    }

    if (lower.contains('provider_quota_exceeded') ||
        lower.contains('rate_limit') ||
        lower.contains('quota exceeded') ||
        lower.contains('429')) {
      return NutritionAiFailure(
        type: NutritionAiFailureType.rateLimited,
        safeMessage: 'AI is busy right now. Try again shortly.',
        detailedMessage: raw,
        canRetry: true,
        requestId: extractedReqId,
      );
    }

    if (lower.contains('provider_high_demand') ||
        lower.contains('high_demand') ||
        lower.contains('temporarily unavailable') ||
        lower.contains('503')) {
      return NutritionAiFailure(
        type: NutritionAiFailureType.highDemand,
        safeMessage:
            'The meal planner is temporarily experiencing high demand. Please try again in a moment.',
        detailedMessage: raw,
        canRetry: true,
        requestId: extractedReqId,
      );
    }

    if (lower.contains('provider_model_not_found') ||
        lower.contains('model_not_found')) {
      return NutritionAiFailure(
        type: NutritionAiFailureType.modelConfig,
        safeMessage:
            'The meal planning service configuration needs an update. Please try again later.',
        detailedMessage: raw,
        canRetry: false,
        requestId: extractedReqId,
      );
    }

    if (lower.contains('provider_timeout') || lower.contains('timeout')) {
      return NutritionAiFailure(
        type: NutritionAiFailureType.timeout,
        safeMessage:
            'Meal generation took longer than expected. Please check your connection and try again.',
        detailedMessage: raw,
        canRetry: true,
        requestId: extractedReqId,
      );
    }

    if (lower.contains('unauthenticated') ||
        lower.contains('session expired') ||
        lower.contains('active account changed') ||
        lower.contains('auth')) {
      return NutritionAiFailure(
        type: NutritionAiFailureType.auth,
        safeMessage:
            'Your session needs to be refreshed. Please reload Eating setup.',
        detailedMessage: raw,
        canRetry: true,
        requestId: extractedReqId,
      );
    }

    if (lower.contains('provider_network_error') ||
        lower.contains('network') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup')) {
      return NutritionAiFailure(
        type: NutritionAiFailureType.network,
        safeMessage:
            'Unable to connect to the server. Please check your internet connection.',
        detailedMessage: raw,
        canRetry: true,
        requestId: extractedReqId,
      );
    }

    if (lower.contains('provider_incomplete_week') ||
        lower.contains('incomplete') ||
        lower.contains('missing meal') ||
        lower.contains('missing day') ||
        lower.contains('ai returned empty') ||
        lower.contains('no meals detected') ||
        lower.contains('dropped_no_dishes')) {
      return NutritionAiFailure(
        type: NutritionAiFailureType.incompleteWeek,
        safeMessage:
            'The generated meal plan was incomplete. Please try again.',
        detailedMessage: raw,
        canRetry: true,
        requestId: extractedReqId,
      );
    }

    if (lower.contains('provider_target_mismatch') ||
        lower.contains('tolerance') ||
        lower.contains('calorie target') ||
        lower.contains('protein target') ||
        lower.contains('macro')) {
      return NutritionAiFailure(
        type: NutritionAiFailureType.targetMismatch,
        safeMessage:
            'The meal plan could not meet your nutritional targets. Try adjusting your schedule or targets.',
        detailedMessage: raw,
        canRetry: true,
        requiresPreferenceAdjustment: true,
        requestId: extractedReqId,
      );
    }

    if (lower.contains('provider_insufficient_diversity') ||
        lower.contains('diversity') ||
        lower.contains('variety')) {
      return NutritionAiFailure(
        type: NutritionAiFailureType.insufficientDiversity,
        safeMessage:
            'The generated meal plan was not varied enough across the week. Please try again.',
        detailedMessage: raw,
        canRetry: true,
        requestId: extractedReqId,
      );
    }

    if (lower.contains('provider_diet_violation') ||
        lower.contains('dietary rule') ||
        lower.contains('diet violation') ||
        lower.contains('contains non-veg') ||
        lower.contains('contains meat') ||
        lower.contains('contains seafood') ||
        lower.contains('contains dairy')) {
      return NutritionAiFailure(
        type: NutritionAiFailureType.dietViolation,
        safeMessage:
            'The generated plan conflicted with your dietary preferences. Please try again.',
        detailedMessage: raw,
        canRetry: true,
        requestId: extractedReqId,
      );
    }

    return NutritionAiFailure(
      type: NutritionAiFailureType.unknown,
      safeMessage:
          'Something went wrong while generating your meal plan. Please try again.',
      detailedMessage: raw,
      canRetry: true,
      requestId: extractedReqId,
    );
  }

  @override
  String toString() =>
      'NutritionAiFailure(type: $type, message: $safeMessage, canRetry: $canRetry)';
}
