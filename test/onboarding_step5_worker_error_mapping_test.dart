import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';

void main() {
  group('Worker Error Mapping Tests', () {
    test('onboarding5FriendlyAiMessage maps provider errors correctly', () {
      final message1 = onboarding5FriendlyAiMessage(
        'provider_empty_candidates',
        const [],
      );
      expect(message1, 'AI could not read meals clearly. Try a clearer photo.');

      final message2 = onboarding5FriendlyAiMessage(
        'provider_invalid_api_key',
        const [],
      );
      expect(message2, 'AI key is invalid or unauthorized.');

      final message3 = onboarding5FriendlyAiMessage(
        'provider_rate_limit_exceeded',
        const [],
      );
      expect(message3, 'AI quota/rate limit reached. Try again later.');

      expect(
        onboarding5FriendlyAiMessage('missing_worker_url', const []),
        'Real AI is not configured. Missing nutrition worker URL.',
      );
    });

    test('onboarding5FriendlyAiMessage maps generatedPlan content errors', () {
      expect(
        onboarding5FriendlyAiMessage(
          'provider_incomplete_week',
          const [],
          operation: Onboarding5AiOperation.generatedPlan,
        ),
        "AI couldn't complete all 7 days for the updated meal plan.",
      );

      expect(
        onboarding5FriendlyAiMessage(
          'provider_duplicate_meal_slot',
          const [],
          operation: Onboarding5AiOperation.generatedPlan,
        ),
        'AI returned duplicate meals for the same day. Try generating again.',
      );

      expect(
        onboarding5FriendlyAiMessage(
          'provider_unexpected_meal_slot',
          const [],
          operation: Onboarding5AiOperation.generatedPlan,
        ),
        'AI returned an invalid meal schedule. Try generating again.',
      );

      expect(
        onboarding5FriendlyAiMessage(
          'provider_target_mismatch',
          const [],
          operation: Onboarding5AiOperation.generatedPlan,
        ),
        "AI couldn't match your updated calorie and protein targets closely enough.",
      );

      expect(
        onboarding5FriendlyAiMessage(
          'provider_insufficient_diversity',
          const [],
          operation: Onboarding5AiOperation.generatedPlan,
        ),
        'AI repeated meals in the updated weekly routine.',
      );

      expect(
        onboarding5FriendlyAiMessage(
          'invalid_eating_request',
          const [],
          operation: Onboarding5AiOperation.generatedPlan,
        ),
        'Meal routine preferences were invalid. Try adjusting them and generating again.',
      );

      expect(
        onboarding5FriendlyAiMessage(
          'provider_empty_candidates',
          const [],
          operation: Onboarding5AiOperation.generatedPlan,
        ),
        "AI couldn't build the updated weekly meal routine.",
      );

      expect(
        onboarding5FriendlyAiMessage(
          'provider_invalid_json',
          const [],
          operation: Onboarding5AiOperation.generatedPlan,
        ),
        'AI returned an invalid meal routine.',
      );
    });
  });
}
