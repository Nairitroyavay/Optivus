import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';

void main() {
  Widget buildTestWidget({
    OnboardingDraft draft = const OnboardingDraft(currentStep: 7),
    bool pumpFlow = false,
  }) {
    return ProviderScope(
      overrides: [
        mockOnboardingProvider.overrideWith(
          (ref) {
            final notifier = MockOnboardingNotifier();
            notifier.loadSeedData(draft);
            return notifier;
          },
        ),
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
    }
  });

  testWidgets('Test 3: no green/circle selected UI', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.circle_outlined), findsNothing);

    final fileContent = File('lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart').readAsStringSync();
    expect(fileContent.contains('Color(0xFF63B885)'), isFalse);
  });

  testWidgets('Test 4: no full page scroll', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();
    
    final finder = find.byType(SingleChildScrollView);
    final singleChildScrollViews = tester.widgetList<SingleChildScrollView>(finder);
    
    final headerFinder = find.text('Skin Care');
    final ancestor = find.ancestor(of: headerFinder, matching: finder);
    expect(ancestor, findsNothing);
  });

  testWidgets('Test 5: Back logic matches Eating', (tester) async {
    await tester.pumpWidget(buildTestWidget(pumpFlow: true));
    await tester.pump(const Duration(seconds: 1)); 

    await tester.tap(find.text('Build routine for me'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Build routine for me'), findsOneWidget);
    expect(find.text('Build skin routine'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Build skin routine'), findsNothing);
    expect(find.text('I have products'), findsOneWidget);
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

    expect(find.text('Skin care will be skipped for now.'), findsOneWidget);
    
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

    await tester.enterText(find.byType(TextField), 'Cleanser, moisturizer, sunscreen');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));

    final btnFinder = find.text('Build skin routine');
    await tester.ensureVisible(btnFinder);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(btnFinder);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Morning skin care'), findsOneWidget);
    expect(find.text('Night skin care'), findsOneWidget);

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

    await tester.tap(find.text('Combination'));
    await tester.tap(find.text('Acne'));
    await tester.tap(find.text('Medium'));
    await tester.tap(find.text('Minimal'));
    await tester.pump(const Duration(seconds: 1));

    final btnFinder = find.text('Build skin routine');
    await tester.ensureVisible(btnFinder);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(btnFinder);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Morning skin care'), findsOneWidget);
    expect(find.text('Night skin care'), findsOneWidget);

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
    final draft = OnboardingDraft(
      currentStep: 7,
      baseTimeline: const BaseTimelineDraft(
        blocks: [eatingBlock],
      ),
    );

    await tester.pumpWidget(buildTestWidget(draft: draft, pumpFlow: true));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Next Step'));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    final context = tester.element(find.text('Drop Bad Habits'));
    final notifier = ProviderScope.containerOf(context).read(mockOnboardingProvider);
    expect(notifier.draft.baseTimeline.blocks.contains(eatingBlock), isTrue);
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
  });
}
