import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_6_fixed_schedule.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  ProviderContainer makeContainer() {
    final draft = const OnboardingDraft().copyWith(
      baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks()
    );
    final container = ProviderContainer(
      overrides: [
        mockOnboardingProvider.overrideWith(
          (_) => MockOnboardingNotifier()..loadSeedData(draft),
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

  testWidgets('Renders OnboardingStep6 correctly', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    expect(find.text('Fixed Schedule'), findsOneWidget);
    expect(find.text('Manual-only non-negotiable blocks.'), findsOneWidget);
  });

  testWidgets('Renders mandatory Sleep and Bath blocks by default', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    expect(find.text('Sleep'), findsWidgets);
    expect(find.text('Bath'), findsOneWidget);
  });

  testWidgets('Sleep and Bath titles are disabled in edit dialog', (tester) async {
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

    final titleField = find.byKey(const ValueKey('block_name_input'));
    final textFieldWidget = tester.widget<TextFormField>(titleField);
    expect(textFieldWidget.enabled, isFalse);
  });

  testWidgets('Sleep and Bath blocks cannot be deleted', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final menuFinder = find.byKey(const ValueKey('onboarding-step6-menu-fixed-bath'));
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();

    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('Can add custom fixed block', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Add Fixed Block'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('block_name_input')), 'My Custom Block');
    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '10:00 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '11:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('My Custom Block'), findsOneWidget);
  });

  testWidgets('Can edit custom fixed block', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    // Add it first
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('block_name_input')), 'My Custom Block');
    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '10:00 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '11:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // Edit it
    final state = container.read(mockOnboardingProvider);
    final customBlockId = state.draft.baseTimeline.blocks.last.id;
    final menuFinder = find.byKey(ValueKey('onboarding-step6-menu-$customBlockId'));
    
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();
    
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('block_name_input')), 'Renamed Block');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed Block'), findsOneWidget);
  });

  testWidgets('Can delete custom fixed block', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    // Add it first
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('block_name_input')), 'My Custom Block');
    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '10:00 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '11:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('My Custom Block'), findsOneWidget);

    final state = container.read(mockOnboardingProvider);
    final customBlockId = state.draft.baseTimeline.blocks.last.id;
    final menuFinder = find.byKey(ValueKey('onboarding-step6-menu-$customBlockId'));
    
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();

    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('My Custom Block'), findsNothing);
  });

  testWidgets('Throws validation error if custom block end time is before start time', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('block_name_input')), 'Invalid Block');
    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '10:00 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '9:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('End time must be after start time.'), findsOneWidget);
  });

  testWidgets('Validation blocks Next/save when invalid data in dialog', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // Keep name empty
    await tester.enterText(find.byKey(const ValueKey('block_name_input')), '');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // Dialog stays open, validation shown (Title is required)
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('Shows validation error if missing mandatory blocks', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();
    
    container.read(mockOnboardingProvider.notifier).updateDraft((draft) {
      final base = draft.baseTimeline;
      final existingBlocks = base.blocks.where((b) => b.section != 'fixed').toList();
      return draft.copyWith(baseTimeline: base.copyWith(blocks: existingBlocks));
    });
    // Trigger validation since UI does not trigger it on direct draft change
    // We will just tap 'add' and 'save' to force a _setBlocks call which triggers _validate
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('block_name_input')), 'Valid Block');
    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '10:00 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '11:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    
    final state = container.read(mockOnboardingProvider);
    expect(state.validationMessage, isNotNull);
    expect(state.validationMessage, contains('Missing required Sleep or Bath block'));
  });

  testWidgets('Saved blocks persist required and custom fixed blocks correctly', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('block_name_input')), 'My Custom Block');
    await tester.enterText(find.byKey(const ValueKey('start_time_input')), '10:00 AM');
    await tester.enterText(find.byKey(const ValueKey('end_time_input')), '11:00 AM');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final draft = container.read(mockOnboardingProvider).draft;
    final fixedBlocks = draft.baseTimeline.blocks.where((p) => p.section == 'fixed').toList();
    expect(fixedBlocks.isNotEmpty, isTrue);
    
    // Sleep crosses midnight, so in UI it might split, but in draft it is 1 block!
    expect(fixedBlocks.length, 3); // Sleep, Bath, My Custom Block
    expect(fixedBlocks.any((b) => b.title == 'Sleep'), isTrue);
    expect(fixedBlocks.any((b) => b.title == 'Bath'), isTrue);
    expect(fixedBlocks.any((b) => b.title == 'My Custom Block'), isTrue);
  });
}
