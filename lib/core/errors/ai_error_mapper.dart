import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';

abstract final class AiErrorMapper {
  /// Adapts an [AiGenerationError] (from AH-F016 lifecycle) into a [RecoverableError].
  static RecoverableError map(
    AiGenerationError error, {
    bool isRequired = true,
    String? operationType,
  }) {
    final (category, diagnosticCode, defaultMessage) = switch (error.category) {
      AiGenerationErrorCategory.timeout => (
        RecoverableErrorCategory.aiTimeout,
        _timeoutCode(operationType),
        'This is taking longer than expected. Try again.',
      ),
      AiGenerationErrorCategory.rateLimited => (
        RecoverableErrorCategory.aiQuota,
        _quotaCode(operationType),
        'AI generation is temporarily unavailable because the service limit was reached.',
      ),
      AiGenerationErrorCategory.responseInvalid => (
        RecoverableErrorCategory.aiMalformedResponse,
        _responseInvalidCode(operationType),
        'We couldn’t build a valid plan from that result. Try again.',
      ),
      AiGenerationErrorCategory.network => (
        RecoverableErrorCategory.network,
        DiagnosticCodes.networkUnavailable,
        'We couldn’t connect to the AI service. Check your connection and try again.',
      ),
      AiGenerationErrorCategory.unauthorized => (
        RecoverableErrorCategory.authentication,
        DiagnosticCodes.authSessionExpired,
        'Your session needs to be refreshed. Please sign in again.',
      ),
      AiGenerationErrorCategory.invalidInput => (
        RecoverableErrorCategory.validation,
        DiagnosticCodes.validationMissingTimetable,
        'Add your timetable photo before generating.',
      ),
      AiGenerationErrorCategory.serviceUnavailable => (
        RecoverableErrorCategory.aiMalformedResponse,
        DiagnosticCodes.aiServiceUnavailable,
        'AI service is temporarily unavailable. Try again after a moment.',
      ),
      AiGenerationErrorCategory.unknown => (
        RecoverableErrorCategory.aiMalformedResponse,
        DiagnosticCodes.aiServiceUnavailable,
        'Something went wrong while generating this. Try again.',
      ),
    };

    final isBlocking = isRequired;
    final retryAction = error.canRetry
        ? RecoverableRetryAction.retryGeneration
        : (category == RecoverableErrorCategory.authentication
            ? RecoverableRetryAction.reauthenticate
            : RecoverableRetryAction.none);

    final safeMessage = _isCleanPublicMessage(error.message)
        ? error.message
        : defaultMessage;

    return RecoverableError(
      category: category,
      publicMessage: safeMessage,
      severity: isBlocking
          ? RecoverableErrorSeverity.error
          : RecoverableErrorSeverity.warning,
      isBlocking: isBlocking,
      retryAction: retryAction,
      retrySafe: error.canRetry,
      diagnosticCode: diagnosticCode,
    );
  }

  static bool _isCleanPublicMessage(String? msg) {
    if (msg == null || msg.trim().isEmpty) return false;
    final lower = msg.toLowerCase();
    if (lower.contains('raw_') ||
        lower.contains('secret') ||
        lower.contains('exception:') ||
        lower.contains('token') ||
        lower.contains('{') ||
        lower.contains('}') ||
        lower.startsWith('provider_')) {
      return false;
    }
    return true;
  }

  static String _timeoutCode(String? op) => switch (op) {
        'nutrition' => DiagnosticCodes.aiNutritionTimeout,
        'skin-care' => DiagnosticCodes.aiSkinCareTimeout,
        'coach' => DiagnosticCodes.aiCoachTimeout,
        _ => DiagnosticCodes.aiRoutineTimeout,
      };

  static String _quotaCode(String? op) => switch (op) {
        'nutrition' => DiagnosticCodes.aiNutritionQuota,
        'skin-care' => DiagnosticCodes.aiSkinCareQuota,
        'coach' => DiagnosticCodes.aiCoachQuota,
        _ => DiagnosticCodes.aiRoutineQuota,
      };

  static String _responseInvalidCode(String? op) => switch (op) {
        'nutrition' => DiagnosticCodes.aiNutritionResponseInvalid,
        'skin-care' => DiagnosticCodes.aiSkinCareResponseInvalid,
        'coach' => DiagnosticCodes.aiCoachResponseInvalid,
        _ => DiagnosticCodes.aiRoutineResponseInvalid,
      };
}
