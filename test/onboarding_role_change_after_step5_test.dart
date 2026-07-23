import 'package:flutter_test/flutter_test.dart';
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

        final notifier = MockOnboardingNotifier()..loadSeedData(draft);

        final warnings = notifier.updateLifeRoleSelection(
          LifeRoleDraft.notStudentNotWorkingKey,
        );

        expect(warnings.isNotEmpty, true);

        final updatedDraft = notifier.state.draft;

        // Blocks should be removed
        expect(updatedDraft.baseTimeline.blocks.isEmpty, true);
      },
    );
  });
}
