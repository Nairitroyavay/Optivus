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
  });
}
