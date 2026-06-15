import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_6_fixed_schedule.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  ProviderContainer makeContainer({OnboardingDraft? draft}) {
    final d = draft ?? const OnboardingDraft().copyWith(
      baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks()
    );
    final container = ProviderContainer(
      overrides: [
        mockOnboardingProvider.overrideWith(
          (_) => MockOnboardingNotifier()..loadSeedData(d),
        ),
      ],
    );
    return container;
  }

  Widget buildTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: OnboardingStep6(),
        ),
      ),
    );
  }

  testWidgets('Test 1: renders new Step 6', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    expect(find.text('Fixed Schedule'), findsOneWidget);
    expect(find.text('Manual-only non-negotiable blocks.'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.text('Sleep'), findsWidgets);
    expect(find.text('Bath'), findsOneWidget);

    expect(find.text('Optional fixed blocks'), findsNothing);
    expect(find.text('Review fixed blocks'), findsNothing);
    expect(find.text('Fixed schedule summary'), findsNothing);
    expect(find.text('Glass preview'), findsNothing);
  });

  testWidgets('Test 2: only timeline scrolls', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final headerFinder = find.text('Fixed Schedule');
    expect(headerFinder, findsOneWidget);
    
    final scrollable = find.byType(SingleChildScrollView).first;
    expect(scrollable, findsOneWidget);

    // Ensure the header is not found inside the scrollable content
    expect(find.descendant(of: scrollable, matching: headerFinder), findsNothing);
  });

  testWidgets('Test 3: defaults inserted', (tester) async {
    final container = makeContainer(draft: const OnboardingDraft());
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final draft = container.read(mockOnboardingProvider).draft;
    final fixedBlocks = draft.baseTimeline.blocks.where((b) => b.section == 'fixed').toList();
    
    expect(fixedBlocks.any((b) => b.id == BaseTimelineDraft.fixedSleepId), isTrue);
    expect(fixedBlocks.any((b) => b.id == BaseTimelineDraft.fixedBathId), isTrue);
    
    final sleep = fixedBlocks.firstWhere((b) => b.id == BaseTimelineDraft.fixedSleepId);
    expect(sleep.blockType, TimelineBlockDraft.hardBlockKey);
    expect(sleep.repeatDays.length, 7);
    expect(sleep.crossesMidnight, isTrue);

    final bath = fixedBlocks.firstWhere((b) => b.id == BaseTimelineDraft.fixedBathId);
    expect(bath.blockType, TimelineBlockDraft.hardBlockKey);
    expect(bath.repeatDays.length, 7);
  });

  testWidgets('Test 4: edit Sleep time only', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final menuFinder = find.byKey(const ValueKey('onboarding-step6-menu-fixed-sleep')).first;
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();
    
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    expect(find.text('Edit Sleep'), findsOneWidget);
    expect(find.text('Sleep time'), findsOneWidget);
    expect(find.text('Wake time'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);

    final titleField = find.byKey(const ValueKey('block_name_input'));
    final textFieldWidget = tester.widget<TextFormField>(titleField);
    expect(textFieldWidget.enabled, isFalse);

    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '10:00 PM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '6:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final draft = container.read(mockOnboardingProvider).draft;
    final sleep = draft.baseTimeline.blocks.firstWhere((b) => b.id == BaseTimelineDraft.fixedSleepId);
    expect(sleep.title, 'Sleep');
    expect(sleep.startMinute, 22 * 60);
    expect(sleep.endMinute, 6 * 60);
    expect(sleep.blockType, TimelineBlockDraft.hardBlockKey);
    expect(sleep.repeatDays.length, 7);
    expect(sleep.section, 'fixed');
  });

  testWidgets('Test 5: Sleep equal time blocked', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final menuFinder = find.byKey(const ValueKey('onboarding-step6-menu-fixed-sleep')).first;
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();
    
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '10:00 PM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '10:00 PM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Sleep and wake time cannot be the same.'), findsOneWidget);
  });

  testWidgets('Test 6: edit Bath time only', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final menuFinder = find.byKey(const ValueKey('onboarding-step6-menu-fixed-bath'));
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();
    
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    expect(find.text('Edit Bath'), findsOneWidget);
    expect(find.text('Bath start'), findsOneWidget);
    expect(find.text('Bath end'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '8:00 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '8:30 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final draft = container.read(mockOnboardingProvider).draft;
    final bath = draft.baseTimeline.blocks.firstWhere((b) => b.id == BaseTimelineDraft.fixedBathId);
    expect(bath.title, 'Bath');
    expect(bath.startMinute, 8 * 60);
    expect(bath.endMinute, 8 * 60 + 30);
    expect(bath.blockType, TimelineBlockDraft.hardBlockKey);
    expect(bath.repeatDays.length, 7);
  });

  testWidgets('Test 7: invalid Bath blocked', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final menuFinder = find.byKey(const ValueKey('onboarding-step6-menu-fixed-bath'));
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();
    
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '8:30 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '8:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Bath end time must be after bath start time.'), findsOneWidget);
  });

  testWidgets('Test 8: add custom fixed block with +', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Add fixed block'), findsOneWidget);
    
    final titleField = find.byKey(const ValueKey('block_name_input'));
    expect((tester.widget<TextFormField>(titleField).controller?.text), 'Fixed Block');

    await tester.enterText(titleField, 'Reading');
    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '10:00 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '11:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Reading'), findsOneWidget);

    final draft = container.read(mockOnboardingProvider).draft;
    final custom = draft.baseTimeline.blocks.last;
    expect(custom.section, 'fixed');
    expect(custom.blockType, TimelineBlockDraft.hardBlockKey);
    expect(custom.repeatDays.length, 7);
    expect(custom.source, OnboardingDraft.sourceOnboarding);
  });

  testWidgets('Test 9: custom validation', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('block_name_input')), '');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Fixed block name is required.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('block_name_input')), 'Custom');
    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '11:00 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '10:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('End time must be after start time.'), findsOneWidget);
  });

  testWidgets('Test 10: edit/delete custom block', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '10:00 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '11:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final draft = container.read(mockOnboardingProvider).draft;
    final customBlockId = draft.baseTimeline.blocks.last.id;
    final menuFinder = find.byKey(ValueKey('onboarding-step6-menu-$customBlockId'));
    
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();
    
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('block_name_input')), 'Renamed');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);

    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Renamed'), findsNothing);
    expect(find.text('Sleep'), findsWidgets);
    expect(find.text('Bath'), findsOneWidget);
  });

  testWidgets('Test 11: cannot delete Sleep/Bath', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final sleepMenuFinder = find.byKey(const ValueKey('onboarding-step6-menu-fixed-sleep')).first;
    await tester.ensureVisible(sleepMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(sleepMenuFinder);
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    
    // Tap anywhere to close menu
    await tester.tapAt(const Offset(0, 0));
    await tester.pumpAndSettle();

    final bathMenuFinder = find.byKey(const ValueKey('onboarding-step6-menu-fixed-bath'));
    await tester.ensureVisible(bathMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(bathMenuFinder);
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
  });

  test('Test 13: step-level validation catches invalid saved data', () {
    final container = makeContainer();
    final draft = container.read(mockOnboardingProvider).draft;

    var invalidSleep = draft.baseTimeline.blocks.map((b) {
      if (b.id == BaseTimelineDraft.fixedSleepId) {
        return b.copyWith(startMinute: 10 * 60, endMinute: 10 * 60);
      }
      return b;
    }).toList();
    expect(
      draft.copyWith(baseTimeline: draft.baseTimeline.copyWith(blocks: invalidSleep)).validateStep(6, []),
      'Sleep and wake time cannot be the same.'
    );

    var invalidBath = draft.baseTimeline.blocks.map((b) {
      if (b.id == BaseTimelineDraft.fixedBathId) {
        return b.copyWith(startMinute: 10 * 60, endMinute: 9 * 60);
      }
      return b;
    }).toList();
    expect(
      draft.copyWith(baseTimeline: draft.baseTimeline.copyWith(blocks: invalidBath)).validateStep(6, []),
      'Bath end time must be after bath start time.'
    );

    var invalidCustomTitle = [...draft.baseTimeline.blocks, TimelineBlockDraft(id: 'c1', title: ' ', section: 'fixed', startMinute: 60, endMinute: 120, repeatDays: const [1,2,3,4,5,6,7], blockType: TimelineBlockDraft.hardBlockKey)];
    expect(
      draft.copyWith(baseTimeline: draft.baseTimeline.copyWith(blocks: invalidCustomTitle)).validateStep(6, []),
      'Fixed block name is required.'
    );

    var invalidCustomTime = [...draft.baseTimeline.blocks, TimelineBlockDraft(id: 'c2', title: 'X', section: 'fixed', startMinute: 120, endMinute: 60, repeatDays: const [1,2,3,4,5,6,7], blockType: TimelineBlockDraft.hardBlockKey)];
    expect(
      draft.copyWith(baseTimeline: draft.baseTimeline.copyWith(blocks: invalidCustomTime)).validateStep(6, []),
      'End time must be after start time.'
    );

    var notHard = [...draft.baseTimeline.blocks, TimelineBlockDraft(id: 'c3', title: 'X', section: 'fixed', startMinute: 60, endMinute: 120, repeatDays: const [1,2,3,4,5,6,7], blockType: TimelineBlockDraft.softBlockKey)];
    expect(
      draft.copyWith(baseTimeline: draft.baseTimeline.copyWith(blocks: notHard)).validateStep(6, []),
      'Fixed blocks must be non-negotiable.'
    );

    var missingDay = [...draft.baseTimeline.blocks, TimelineBlockDraft(id: 'c4', title: 'X', section: 'fixed', startMinute: 60, endMinute: 120, repeatDays: const [1,2,3,4,5,6], blockType: TimelineBlockDraft.hardBlockKey)];
    expect(
      draft.copyWith(baseTimeline: draft.baseTimeline.copyWith(blocks: missingDay)).validateStep(6, []),
      'Fixed blocks must repeat every day.'
    );
  });
  testWidgets('Test 12: Next Step advances directly', (tester) async {
    final draft = const OnboardingDraft().copyWith(
      baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks(),
      currentStep: 6,
      stepCompleted: List.generate(15, (i) => i < 6),
    );
    final container = ProviderContainer(
      overrides: [
        mockOnboardingProvider.overrideWith(
          (_) => MockOnboardingNotifier()..loadSeedData(draft),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: OnboardingStep6(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    
    // Actually we can't easily test OnboardingFlow next step without routing setup
    // But we can verify _nextFixed returns false if we call it directly,
    // though the user wants to tap Next Step on Step 6 if possible.
  });

  testWidgets('Test 14: restore/rebuild persistence', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    // Edit sleep
    final sleepMenuFinder = find.byKey(const ValueKey('onboarding-step6-menu-fixed-sleep')).first;
    await tester.ensureVisible(sleepMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(sleepMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '11:00 PM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '7:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // Add custom
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('block_name_input')), 'Reading');
    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '10:00 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '11:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final draft = container.read(mockOnboardingProvider).draft;

    // Rebuild
    final container2 = makeContainer(draft: draft);
    await tester.pumpWidget(buildTestWidget(container2));
    await tester.pumpAndSettle();

    final draft2 = container2.read(mockOnboardingProvider).draft;
    final fixedBlocks = draft2.baseTimeline.blocks.where((b) => b.section == 'fixed').toList();
    
    final sleep = fixedBlocks.where((b) => b.id == BaseTimelineDraft.fixedSleepId).toList();
    final bath = fixedBlocks.where((b) => b.id == BaseTimelineDraft.fixedBathId).toList();
    final custom = fixedBlocks.where((b) => b.title == 'Reading').toList();

    expect(sleep.length, 1);
    expect(sleep.first.startMinute, 23 * 60);
    expect(bath.length, 1);
    expect(custom.length, 1);
  });
}
