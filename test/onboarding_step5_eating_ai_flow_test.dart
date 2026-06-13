import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/state/app_state.dart';

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

  group('Onboarding Step 5 AI Loading UI', () {
    testWidgets('shows AiThinkingCard during generated meal plan creation', (tester) async {
      // Set up a draft that leads directly to the create routine screen
      final draft = OnboardingDraft(
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        baseTimeline: const BaseTimelineDraft(
          eatingSetupPath: onboardingEatingPathCreate,
          eatingSetupStep: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockOnboardingProvider.overrideWith(
              (ref) => MockOnboardingNotifier()..loadSeedData(draft),
            ),
            // Provide a fake nutrition client that hangs
            nutritionAiClientProvider.overrideWithValue(FakeDelayedNutritionAiClient()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OnboardingStep5(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the generate button in the create path
      final generateButton = find.text('Generate meal routine');
      expect(generateButton, findsOneWidget);
      await tester.tap(generateButton);
      await tester.pump();

      // Now it should be generating
      expect(find.byType(AiThinkingCard), findsOneWidget);
      expect(find.text(onboarding5GeneratedMealLoadingMessages.first), findsOneWidget);
      expect(find.text('AI is generating your timeline.'), findsNothing);

      // Force cleanup of timers inside AiThinkingCard before test ends
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}

class FakeDelayedNutritionAiClient implements NutritionAiClient {
  @override
  Future<RoutineImportExtractionResult> generateEatingRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    // Hang forever
    return Completer<RoutineImportExtractionResult>().future;
  }
}
