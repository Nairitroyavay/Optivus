import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  group('Onboarding Role Change State Safety', () {
    test(
      'updateLifeRoleSelection clears class and work data when role removes them',
      () {
        final draft = OnboardingDraft(
          lifeRole: const LifeRoleDraft(
            lifeRole: LifeRoleDraft.studentWorkingKey,
          ),
          baseTimeline: BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'class-1',
                title: 'Math',
                section: 'classes',
                blockType: 'hard_block',
                startMinute: 600,
                endMinute: 660,
                repeatDays: [1, 2, 3],
              ),
              TimelineBlockDraft(
                id: 'work-1',
                title: 'Job',
                section: 'job_work_business',
                blockType: 'hard_block',
                startMinute: 720,
                endMinute: 800,
                repeatDays: [1, 2, 3],
              ),
            ],
          ),
        );

        final notifier = OnboardingNotifier()..loadSeedData(draft);

        final warnings = notifier.updateLifeRoleSelection(
          LifeRoleDraft.notStudentNotWorkingKey,
        );

        expect(warnings.isNotEmpty, true);

        final updatedDraft = notifier.state.draft;

        // Blocks should be removed
        expect(updatedDraft.baseTimeline.blocks.isEmpty, true);
      },
    );

    test(
      'updateLifeRoleSelection preserves eating blocks but invalidates Step 5 and downgrades review step',
      () {
        final eatingBlock = TimelineBlockDraft(
          id: 'eating-ai-d1-breakfast',
          section: 'eating',
          title: 'Breakfast Bowl',
          startMinute: 8 * 60,
          endMinute: 8 * 60 + 30,
          repeatDays: const [1],
          blockType: TimelineBlockDraft.hardBlockKey,
          source: onboardingEatingGeneratedSource,
          mealSlot: 'breakfast',
          dishes: const ['Oatmeal'],
          calories: 400,
          protein: 25,
        );

        final draft = OnboardingDraft(
          lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
          currentStep: 6,
          stepCompleted: [
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
          ],
          baseTimeline: BaseTimelineDraft(
            eatingSetupPath: onboardingEatingPathCreate,
            eatingSetupStep: 2,
            eatingGeneratedPlanVersion: 2,
            eatingGeneratedInputFingerprint: 'valid_for_student',
            blocks: [eatingBlock],
          ),
        );

        final notifier = OnboardingNotifier()..loadSeedData(draft);

        final warnings = notifier.updateLifeRoleSelection(
          LifeRoleDraft.workingKey,
        );

        expect(
          warnings.any((w) => w.contains('Nutrition targets updated')),
          isTrue,
        );

        final updatedDraft = notifier.state.draft;
        // Plan A preserved in draft
        expect(
          updatedDraft.baseTimeline.blocks
              .where((b) => b.section == 'eating')
              .length,
          1,
        );
        // Step 5 marked incomplete and dirty
        expect(updatedDraft.stepCompleted[5], isFalse);
        expect(notifier.state.stepDirty[5], isTrue);
        // eatingSetupStep downgraded to 1
        expect(updatedDraft.baseTimeline.eatingSetupStep, 1);
      },
    );
  });
}
