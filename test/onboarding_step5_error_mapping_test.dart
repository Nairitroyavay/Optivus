import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';

void main() {
  group('Onboarding Step 5 Error Mapping - Context Awareness', () {
    test('generatedPlan errors never mention photos, images, or uploads', () {
      final generatedTestCases = [
        ('no_blocks_generated', <String>[]),
        (null, ['no_blocks_generated']),
        ('provider_empty_candidates', <String>[]),
        ('image too large', <String>[]),
        ('r2_image_missing', <String>[]),
        ('unsupported_content_type', <String>[]),
        ('unknown_ai_failure_unexpected_token', <String>[]),
        ('network_unavailable', <String>[]),
        ('provider_timeout', <String>[]),
        ('rate_limit', <String>[]),
        ('unauthorized', <String>[]),
      ];

      for (final testCase in generatedTestCases) {
        final error = testCase.$1;
        final warnings = testCase.$2;
        final message = onboarding5FriendlyAiMessage(
          error,
          warnings,
          operation: Onboarding5AiOperation.generatedPlan,
        );
        final lower = message.toLowerCase();
        expect(
          lower.contains('photo'),
          isFalse,
          reason: 'Message for ($error, $warnings) mentioned photo: $message',
        );
        expect(
          lower.contains('upload'),
          isFalse,
          reason: 'Message for ($error, $warnings) mentioned upload: $message',
        );
        expect(
          lower.contains('image'),
          isFalse,
          reason: 'Message for ($error, $warnings) mentioned image: $message',
        );
      }
    });

    test('generatedPlan produces clean meal plan copy for empty/failed candidates', () {
      final message = onboarding5FriendlyAiMessage(
        null,
        ['no_blocks_generated'],
        operation: Onboarding5AiOperation.generatedPlan,
      );
      expect(message, 'AI could not generate your meal routine. Please try again.');
    });

    test('uploadedMenu produces photo-specific instructions', () {
      final message = onboarding5FriendlyAiMessage(
        null,
        ['no_blocks_generated'],
        operation: Onboarding5AiOperation.uploadedMenu,
      );
      expect(message, contains('photo'));
    });

    test('generatedPlan produces clean fallback for unrecognized errors', () {
      final message = onboarding5FriendlyAiMessage(
        'Exception: something_completely_bizarre_12345',
        [],
        operation: Onboarding5AiOperation.generatedPlan,
      );
      expect(message, 'AI could not generate this meal routine. Please try again.');
    });
  });
}
