import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_class_setup_timeline.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  testWidgets(
    'Onboarding 4 timeline aligns non-hour blocks without flex errors',
    (tester) async {
      final draft = OnboardingDraft(
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        baseTimeline: const BaseTimelineDraft(),
      );
      final blocks = [
        _classBlock('noon', '12 PM block', 12 * 60, 13 * 60),
        _classBlock('one', '1 PM block', 13 * 60, 14 * 60),
        _classBlock('three-fifteen', '3:15 block', 15 * 60 + 15, 16 * 60 + 15),
        _classBlock('four-fifteen', '4:15 block', 16 * 60 + 15, 17 * 60 + 15),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockOnboardingProvider.overrideWith(
              (_) => MockOnboardingNotifier()..loadSeedData(draft),
            ),
            onboardingClassTimelineProvider.overrideWith((_) => blocks),
            onboardingWorkTimelineProvider.overrideWith((_) => const []),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(child: OnboardingStep4Unified()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('3:15'), findsOneWidget);
      expect(find.text('4:15'), findsOneWidget);
    },
  );
}

ClassRoutineBlock _classBlock(
  String id,
  String title,
  int startMinute,
  int endMinute,
) {
  return ClassRoutineBlock(
    id: id,
    subject: title,
    startMinute: startMinute,
    endMinute: endMinute,
    repeatDays: const [1],
    icon: ScheduleSetupConfig.classSetup.icon,
    color: OptivusColors.aquaAccent,
  );
}
