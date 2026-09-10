import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_controller.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/skin_care_product_draft.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Step 7 review is full-detail and Back enters durable rebuild', (
    tester,
  ) async {
    const uid = 'step7-device-test';
    final longSteps = List.generate(
      6,
      (index) =>
          'Long wrapped instruction ${index + 1} for device layout verification',
    );
    final longProducts = List.generate(
      6,
      (index) =>
          'Long product name ${index + 1} for device layout verification',
    );
    var base = BaseTimelineDraft(
      skinCareSetupPath: 'has_products',
      skinCareSetupStep: 2,
      skinCareStageContractVersion:
          BaseTimelineDraft.currentSkinCareStageContractVersion,
      skinCareProductNames: longProducts.join('\n'),
      skinCareReviewedProducts: [
        for (final product in longProducts)
          SkinCareDetectedProduct(name: product),
      ],
      blocks: [
        TimelineBlockDraft(
          id: 'device-long-card',
          section: 'skin_care',
          title: 'Long Skin Care Routine',
          startMinute: 480,
          endMinute: 495,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareSteps: longSteps,
          skincareProducts: longProducts,
          skincareMissingItems: const [
            'Missing item one with a long explanation',
            'Missing item two with a long explanation',
          ],
        ),
      ],
    );
    final fingerprint = base.computeSkinCareRoutineFingerprint();
    base = base.copyWith(
      skinCareRoutineFingerprint: fingerprint,
      blocks: [
        base.blocks.single.copyWith(
          provenanceSourceIds: ['skin-care-generation:$fingerprint'],
        ),
      ],
    );
    final notifier = OnboardingNotifier()
      ..loadSeedData(
        OnboardingDraft(uid: uid, currentStep: 7, baseTimeline: base),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [onboardingStateProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: Scaffold(body: OnboardingStep7())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Skin Care Routine'), findsOneWidget);
    expect(find.text('Review your weekly routine'), findsOneWidget);
    expect(find.text('Rebuild / Edit'), findsNothing);
    expect(find.text('Close editor'), findsNothing);
    expect(find.text('View full details'), findsNothing);
    expect(find.text('6. ${longSteps.last}'), findsOneWidget);
    expect(find.text('• ${longProducts.last}'), findsOneWidget);

    final context = tester.element(find.byType(OnboardingStep7));
    final container = ProviderScope.containerOf(context);
    expect(
      container.read(skinCareFlowControllerProvider.notifier).handleBack(),
      isTrue,
    );
    await tester.pumpAndSettle();

    expect(find.text('Build skin routine'), findsOneWidget);
    expect(
      container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .skinCareSetupStep,
      1,
    );
    expect(
      container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care'),
      isNotEmpty,
    );
  });
}
