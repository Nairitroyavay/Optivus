import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  Widget buildTestWidget({
    OnboardingDraft draft = const OnboardingDraft(currentStep: 7),
    bool pumpFlow = false,
  }) {
    return ProviderScope(
      overrides: [
        mockOnboardingProvider.overrideWith((ref) {
          final notifier = MockOnboardingNotifier();
          notifier.loadSeedData(draft);
          return notifier;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: pumpFlow ? const OnboardingFlow() : const OnboardingStep7(),
        ),
      ),
    );
  }

  testWidgets('Test 1: initial choice screen', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Skin Care'), findsOneWidget);
    expect(find.text('Face and skin routine setup.'), findsOneWidget);
    expect(find.text('I have products'), findsOneWidget);
    expect(find.text('Build routine for me'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    expect(find.text('Face photo'), findsNothing);
    expect(find.text('Optional photo upload'), findsNothing);
    expect(find.text('Review skin care routine'), findsNothing);
    expect(find.text('Open review'), findsNothing);
    expect(find.text('Reopen review'), findsNothing);
    expect(find.text('Skin care skipped for now.'), findsNothing);
    expect(find.text('Suggested set'), findsNothing);
  });

  testWidgets('Test 2: no old stage screens', (tester) async {
    for (int step = 2; step <= 7; step++) {
      await tester.pumpWidget(
        buildTestWidget(
          draft: OnboardingDraft(
            currentStep: 7,
            baseTimeline: BaseTimelineDraft(
              skinCareSetupStep: step,
              skinCareSetupPath: 'no_products',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Build routine for me'), findsOneWidget);
      expect(find.text('Face photo'), findsNothing);
      expect(find.text('Optional photo upload'), findsNothing);
      expect(find.text('Review skin care routine'), findsNothing);
      expect(find.text('Open review'), findsNothing);
    }
  });

  testWidgets('Test 3: no green/circle selected UI', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.circle_outlined), findsNothing);

    final fileContent = File(
      'lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart',
    ).readAsStringSync();
    expect(fileContent.contains('Color(0xFF63B885)'), isFalse);
    expect(fileContent.contains('Icons.check_circle_outline_rounded'), isFalse);
    expect(fileContent.contains('Icons.circle_outlined'), isFalse);
  });

  testWidgets('Test 4: no full page scroll', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsNothing);

    await tester.pumpWidget(
      buildTestWidget(
        draft: const OnboardingDraft(
          currentStep: 7,
          baseTimeline: BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'no_products',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final finder = find.byType(SingleChildScrollView);
    final headerFinder = find.text('Skin Care');
    final ancestor = find.ancestor(of: headerFinder, matching: finder);
    expect(ancestor, findsNothing);
  });

  testWidgets('Test 5: Back logic matches Eating', (tester) async {
    await tester.pumpWidget(buildTestWidget(pumpFlow: true));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Build routine for me'));
    await tester.pump(const Duration(seconds: 1));

    var container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingFlow)),
    );
    expect(container.read(mockOnboardingProvider).draft.currentStep, 7);
    expect(
      container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .skinCareSetupStep,
      0,
    );
    expect(find.text('Build skin routine'), findsNothing);

    await tester.tap(find.text('Next Step'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Build skin routine'), findsOneWidget);
    expect(
      container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .skinCareSetupStep,
      1,
    );

    await tester.tap(find.byKey(const Key('onboarding-step7-back')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Build skin routine'), findsNothing);
    expect(find.text('I have products'), findsOneWidget);
    expect(container.read(mockOnboardingProvider).draft.currentStep, 7);
    expect(
      container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .skinCareSetupStep,
      0,
    );

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));

    container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingFlow)),
    );
    expect(container.read(mockOnboardingProvider).draft.currentStep, 6);
  });

  testWidgets('Test 6: Next without choice', (tester) async {
    await tester.pumpWidget(buildTestWidget(pumpFlow: true));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Next Step'));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Skin Care'), findsOneWidget);
    expect(find.text('Choose skin care setup or skip.'), findsOneWidget);
  });

  testWidgets('Test 7: Skip path', (tester) async {
    await tester.pumpWidget(buildTestWidget(pumpFlow: true));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(seconds: 1));

    var container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingFlow)),
    );
    expect(
      container.read(mockOnboardingProvider).draft.baseTimeline.skinCareSkipped,
      isTrue,
    );

    await tester.tap(find.text('Next Step'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Skin care will be skipped for now.'), findsOneWidget);
    container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingFlow)),
    );
    expect(
      container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .skinCareSetupStep,
      1,
    );

    await tester.tap(find.text('Next Step'));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('Drop Bad Habits'), findsOneWidget); // Step 8
  });

  testWidgets('Test 8: build routine from products', (tester) async {
    await tester.pumpWidget(buildTestWidget(pumpFlow: true));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('I have products'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Next Step'));
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(
      find.byType(TextField),
      'Cleanser, moisturizer, sunscreen',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));

    final btnFinder = find.text('Build skin routine');
    await tester.ensureVisible(btnFinder);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(btnFinder);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Morning skin care'), findsOneWidget);
    expect(find.text('Night skin care'), findsOneWidget);
    var container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingFlow)),
    );
    expect(
      container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care')
          .length,
      greaterThanOrEqualTo(2),
    );

    await tester.tap(find.text('Next Step'));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('Drop Bad Habits'), findsOneWidget);
  });

  testWidgets('Test 9: build routine from skin details', (tester) async {
    await tester.pumpWidget(buildTestWidget(pumpFlow: true));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Build routine for me'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Next Step'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Combination'));
    await tester.tap(find.text('Acne'));
    await tester.ensureVisible(find.text('Medium'));
    await tester.tap(find.text('Medium'));
    await tester.ensureVisible(find.text('Minimal'));
    await tester.tap(find.text('Minimal'));
    await tester.pump(const Duration(seconds: 1));

    final btnFinder = find.text('Build skin routine');
    await tester.ensureVisible(btnFinder);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(btnFinder);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Morning skin care'), findsOneWidget);
    expect(find.text('Night skin care'), findsOneWidget);
    var container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingFlow)),
    );
    final skinBlocks = container
        .read(mockOnboardingProvider)
        .draft
        .baseTimeline
        .confirmedBlocksForSection('skin_care');
    expect(skinBlocks, isNotEmpty);
    expect(skinBlocks.expand((block) => block.skincareProducts), isNotEmpty);

    await tester.tap(find.text('Next Step'));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('Drop Bad Habits'), findsOneWidget);
  });

  testWidgets('Test 10: invalid selected mode', (tester) async {
    await tester.pumpWidget(buildTestWidget(pumpFlow: true));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Build routine for me'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Next Step'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Next Step'));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Build routine for me'), findsOneWidget);
    expect(find.text('Build skin care routine or skip.'), findsOneWidget);
  });

  testWidgets('Test 11: data safety', (tester) async {
    const eatingBlock = TimelineBlockDraft(
      id: 'eating_block',
      section: 'eating',
      title: 'Breakfast',
      startMinute: 480,
      endMinute: 510,
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.softBlockKey,
    );
    const classBlock = TimelineBlockDraft(
      id: 'class_block',
      section: 'classes',
      title: 'Math',
      startMinute: 540,
      endMinute: 600,
      repeatDays: [1, 3, 5],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const workBlock = TimelineBlockDraft(
      id: 'work_block',
      section: 'job_work_business',
      title: 'Work',
      startMinute: 600,
      endMinute: 720,
      repeatDays: [2, 4],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const fixedBlock = TimelineBlockDraft(
      id: 'fixed_block',
      section: 'fixed',
      title: 'Commute',
      startMinute: 780,
      endMinute: 810,
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    final draft = OnboardingDraft(
      currentStep: 7,
      baseTimeline: const BaseTimelineDraft(
        blocks: [classBlock, workBlock, eatingBlock, fixedBlock],
      ),
    );

    await tester.pumpWidget(buildTestWidget(draft: draft, pumpFlow: true));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Next Step'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Next Step'));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    final context = tester.element(find.text('Drop Bad Habits'));
    final state = ProviderScope.containerOf(
      context,
    ).read(mockOnboardingProvider);
    final nonSkinBlocks = state.draft.baseTimeline.blocks
        .where((block) => block.section != 'skin_care')
        .toList(growable: false);
    expect(nonSkinBlocks, [classBlock, workBlock, eatingBlock, fixedBlock]);
  });

  testWidgets('Test 12: restore/rebuild', (tester) async {
    final draft = OnboardingDraft(
      currentStep: 7,
      baseTimeline: const BaseTimelineDraft(
        skinCareSetupStep: 1,
        skinCareSetupPath: 'no_products',
        blocks: [
          TimelineBlockDraft(
            id: 'skin-morning',
            section: 'skin_care',
            title: 'Morning skin care',
            startMinute: 450,
            endMinute: 465,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.softBlockKey,
          ),
        ],
      ),
    );

    await tester.pumpWidget(buildTestWidget(draft: draft));
    await tester.pumpAndSettle();

    expect(find.text('Morning skin care'), findsOneWidget);
    expect(find.text('Routine built'), findsOneWidget);
    final context = tester.element(find.text('Routine built'));
    final state = ProviderScope.containerOf(
      context,
    ).read(mockOnboardingProvider);
    expect(
      state.draft.baseTimeline.confirmedBlocksForSection('skin_care').length,
      1,
    );
  });
}
