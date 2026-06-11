import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';

void main() {
  group('Onboarding Step 5 Eating AI Flow Logic', () {
    test('onboarding5FriendlyAiMessage returns strict upload error for empty candidates', () {
      final message = onboarding5FriendlyAiMessage(
        'provider_empty_candidates',
        const [],
      );

      expect(
        message,
        'AI could not read meals clearly. Try a clearer photo.',
      );
    });

    test('onboarding5FriendlyAiMessage returns strict upload error as default fallback', () {
      final message = onboarding5FriendlyAiMessage(
        null,
        const [], // No clear error from AI
      );

      expect(
        message,
        'AI could not read this meal routine/menu image. Please upload a clearer image and try again.',
      );
    });

    test('onboarding5FriendlyAiMessage handles standard provider errors', () {
      final message = onboarding5FriendlyAiMessage(
        'provider_request_failed',
        const [],
      );

      expect(message, 'AI is busy right now. Try again in a moment.');
    });

    test('onboarding5FriendlyAiMessage surfaces missing worker url properly', () {
      final message = onboarding5FriendlyAiMessage(
        null,
        const ['worker is not configured'],
      );

      expect(message, 'Real AI is not configured. Missing nutrition worker URL.');
    });

    test('onboarding5FriendlyAiMessage handles incomplete R2 upload', () {
      final message = onboarding5FriendlyAiMessage(
        null,
        const ['r2_image_missing'],
      );

      expect(message, 'Uploaded meal photo could not be found. Please upload again.');
    });
  });
}
