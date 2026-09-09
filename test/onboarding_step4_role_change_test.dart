import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  testWidgets(
    'Step 4 role change from Student to Working resets local state and prevents proceed',
    (tester) async {
      // 1. Start as Student
      var draft = const OnboardingDraft(
        lifeRole: LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        baseTimeline: BaseTimelineDraft(),
      );

      final classBlocks = [
        ClassRoutineBlock(
          id: 'class1',
          subject: 'Math',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1],
          icon: Icons.school_rounded,
          color: Colors.blue,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStateProvider.overrideWith(
              (_) => OnboardingNotifier()..loadSeedData(draft),
            ),
            onboardingClassTimelineProvider.overrideWith((_) => classBlocks),
            onboardingWorkTimelineProvider.overrideWith((_) => []),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(child: OnboardingStep4Unified()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify it shows Math
      expect(find.text('Math'), findsOneWidget);

      // Verify it shows Math in review mode (upload card is hidden)
      expect(find.text('Upload your class timetable'), findsNothing);

      // 2. Change role to Working
      draft = draft.copyWith(
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.workingKey),
      );

      final context = tester.element(find.byType(OnboardingStep4Unified));
      final container = ProviderScope.containerOf(context);
      container
          .read(onboardingStateProvider.notifier)
          .updateDraft((_) => draft);

      await tester.pumpAndSettle();

      // Verify stale class provider is cleared and Math is gone
      expect(find.text('Math'), findsNothing);

      // Verify it asks for work photo upload now
      expect(find.text('Upload your work schedule'), findsOneWidget);

      // 3. Verify Step 4 is incomplete/dirty
      final validationError = draft.validateStep(
        4,
        List<bool>.filled(OnboardingDraft.stepCount, false),
      );

      // The work schedule should not exist yet, so it blocks Next Step
      expect(validationError, 'Generate your work timeline first.');
    },
  );
}
