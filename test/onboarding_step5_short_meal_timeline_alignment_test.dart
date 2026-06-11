import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  testWidgets('Onboarding 5 Eating Setup short meal block renders without errors', (tester) async {
    final draft = OnboardingDraft(
      baseTimeline: BaseTimelineDraft(
        eatingSetupStep: 1,
        eatingSetupPath: 'has_routine',
        blocks: [
          TimelineBlockDraft(
            id: 'short-snack',
            title: 'Snack',
            section: 'eating',
            blockType: 'hard_block',
            startMinute: 600, // 10:00 AM
            endMinute: 605,   // 10:05 AM (5 minutes duration)
            repeatDays: [1, 2, 3, 4, 5],
            dishes: ['Apple'],
          ),
          TimelineBlockDraft(
            id: 'long-dinner',
            title: 'Dinner',
            section: 'eating',
            blockType: 'hard_block',
            startMinute: 1080, // 6:00 PM
            endMinute: 1200,   // 8:00 PM (120 minutes duration)
            repeatDays: [1, 2, 3, 4, 5],
            dishes: ['Steak', 'Salad', 'Potatoes'],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(child: OnboardingStep5()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Snack'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Steak'), findsOneWidget);
    expect(find.text('10:00 AM - 10:05 AM'), findsOneWidget); // Start time
    expect(find.text('6:00 PM - 8:00 PM'), findsOneWidget);
  });
}
