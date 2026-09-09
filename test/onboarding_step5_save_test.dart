import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  group('Step 5 Save Behavior', () {
    test('saveStep replaces eating blocks and preserves others', () {
      final draft = OnboardingDraft(
        uid: 'user-1',
        baseTimeline: BaseTimelineDraft(
          eatingSetupStep: 1, // Let's say we reached stage 1
          blocks: [
            TimelineBlockDraft(
              id: 'b1',
              section: 'classes',
              title: 'Math',
              startMinute: 600,
              endMinute: 660,
              blockType: 'hard_block',
              repeatDays: const [1],
            ),
            TimelineBlockDraft(
              id: 'b2',
              section: 'eating',
              title: 'Lunch',
              startMinute: 720,
              endMinute: 780,
              blockType: 'hard_block',
              repeatDays: const [1],
            ),
          ],
        ),
      );

      final notifier = OnboardingNotifier()..loadSeedData(draft);

      notifier.saveStep(5, uid: 'user-1');

      final state = notifier.state;
      expect(state.draft.baseTimeline.eatingSetupStep, 1);
      expect(state.stepDirty[5], false);
      expect(state.stepCompleted[5], true);

      final blocks = state.draft.baseTimeline.blocks;
      expect(blocks.length, 2);
      expect(blocks.any((b) => b.section == 'classes'), true);
      expect(blocks.any((b) => b.section == 'eating'), true);
    });
  });
}
