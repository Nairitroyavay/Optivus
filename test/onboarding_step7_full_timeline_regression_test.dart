import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_action_bridge.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

List<TimelineBlockDraft> _tagSkinCareBlocks(
  List<TimelineBlockDraft> blocks,
  String fingerprint,
) {
  final token = 'skin-care-generation:$fingerprint';
  return blocks
      .map(
        (block) => block.section == 'skin_care'
            ? block.copyWith(
                provenanceSourceIds: {
                  ...block.provenanceSourceIds,
                  token,
                }.toList(),
              )
            : block,
      )
      .toList(growable: false);
}

OnboardingDraft _hasProductsDraftWithBlocks({
  String uid = 'user-timeline-test',
  int desiredApplicationsPerDay = 2,
}) {
  final blocks = [
    BaseTimelineDraft.defaultBathBlock(),
    TimelineBlockDraft(
      id: 'skin-morning',
      section: 'skin_care',
      title: 'Morning Skin Care',
      startMinute: 480,
      endMinute: 495,
      repeatDays: onboarding7EveryDay,
      blockType: TimelineBlockDraft.softBlockKey,
      skincareProducts: const ['Gentle Cleanser', 'Barrier Moisturizer'],
      skincareSteps: const ['Cleanse', 'Moisturize'],
      skincareSlotLabel: 'Morning',
    ),
    TimelineBlockDraft(
      id: 'skin-night',
      section: 'skin_care',
      title: 'Night Skin Care',
      startMinute: 1260,
      endMinute: 1275,
      repeatDays: onboarding7EveryDay,
      blockType: TimelineBlockDraft.softBlockKey,
      skincareProducts: const ['Gentle Cleanser', 'Barrier Moisturizer'],
      skincareSteps: const ['Cleanse', 'Moisturize'],
      skincareSlotLabel: 'Night',
    ),
  ];

  const productNames = 'Gentle Cleanser\nBarrier Moisturizer';
  final draftBase = BaseTimelineDraft(
    skinCareSetupStep: 1,
    skinCareSetupPath: 'has_products',
    skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
    skinCareProductNames: productNames,
    skinCareReviewedProducts: onboarding7ParseTypedProductDetails(productNames),
    blocks: blocks,
  );
  final fingerprint = draftBase.computeSkinCareRoutineFingerprint();
  return OnboardingDraft(
    uid: uid,
    currentStep: 7,
    baseTimeline: draftBase.copyWith(
      skinCareRoutineFingerprint: fingerprint,
      blocks: _tagSkinCareBlocks(blocks, fingerprint),
    ),
  );
}

void main() {
  testWidgets(
    'Step 7 Full-Screen Timeline Scaffold and Weekday Navigation Regression Test',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final draft = _hasProductsDraftWithBlocks();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStateProvider.overrideWith((ref) {
              final notifier = OnboardingNotifier();
              notifier.loadSeedData(draft);
              return notifier;
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: OnboardingStep7())),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );

      // 1. In review mode, Step 7 does NOT publish a custom footer CTA (Next Step belongs to shell)
      final bridgeState = container.read(step7ActionBridgeProvider);
      expect(bridgeState.action, isNull);

      // 2. Full-screen timeline scaffold key is strictly preserved
      expect(
        find.byKey(const ValueKey('onboarding-step7-full-timeline')),
        findsOneWidget,
      );

      // 3. Unified review header is displayed
      expect(find.text('Skin Care Routine'), findsOneWidget);
      expect(find.text('Review your weekly routine'), findsOneWidget);

      // 4. Weekday chips exist (Mon-Sun)
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);

      // 5. Timeline blocks for the day are rendered
      expect(find.text('Morning Skin Care'), findsWidgets);

      // 6. Switching weekday chip works and does not crash
      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();
      expect(find.text('Morning Skin Care'), findsWidgets);

      // 7. Whole-routine rebuilding is owned by Back.
      expect(find.text('Rebuild / Edit'), findsNothing);
      expect(find.text('Close editor'), findsNothing);
    },
  );
}
