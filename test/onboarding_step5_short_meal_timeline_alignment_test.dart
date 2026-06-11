import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  testWidgets('Onboarding 5 short meal timeline alignment test', (tester) async {
    final draft = OnboardingDraft(
      baseTimeline: BaseTimelineDraft(
        eatingSetupStep: 1,
        eatingSetupPath: 'create',
        blocks: [
          TimelineBlockDraft(
            id: 'short-snack',
            title: 'Snack',
            section: 'eating',
            blockType: 'hard_block',
            startMinute: 17 * 60, // 5:00 PM
            endMinute: 17 * 60 + 20, // 5:20 PM
            repeatDays: [1, 2, 3, 4, 5],
            dishes: [
              'Roasted Almonds',
              'Green Tea',
              'Protein Bar',
              'Apple Slices',
              'Greek Yogurt',
              'Dark Chocolate'
            ],
            source: 'ai_generated_meal_setup',
          ),
          TimelineBlockDraft(
            id: 'long-dinner',
            title: 'Dinner',
            section: 'eating',
            blockType: 'hard_block',
            startMinute: 19 * 60, // 7:00 PM
            endMinute: 20 * 60,   // 8:00 PM
            repeatDays: [1, 2, 3, 4, 5],
            dishes: ['Steak', 'Salad'],
            source: 'ai_generated_meal_setup',
          ),
        ],
      ),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(child: OnboardingStep5()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // 6 dishes should be visible inside the block
    expect(find.text('Snack'), findsOneWidget);
    expect(find.text('Roasted Almonds'), findsOneWidget);
    expect(find.text('Green Tea'), findsOneWidget);
    expect(find.text('Protein Bar'), findsOneWidget);
    expect(find.text('Apple Slices'), findsOneWidget);
    expect(find.text('Greek Yogurt'), findsOneWidget);
    expect(find.text('Dark Chocolate'), findsOneWidget);
    expect(find.text('5:00 PM - 5:20 PM'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('7:00 PM - 8:00 PM'), findsOneWidget);

    expect(find.textContaining('more'), findsNothing);
    expect(find.textContaining('+'), findsNothing);

    // Verify timeline layout logic alignment
    final blockFinder = find.ancestor(
      of: find.text('Snack'),
      matching: find.byType(Positioned),
    ).first;
    
    final positioned = tester.widget<Positioned>(blockFinder);
    
    // The required height for 6 dishes + title should be much larger than 20 minutes * 0.82 px/min (16.4px)
    expect(positioned.height, greaterThan(100.0));
    
    // Check that timeline stretches local segment but not unrelated downstream markers
    // To prove this, we can just check if Dinner start time marker exists and is below the block
    final dinnerBlockFinder = find.ancestor(
      of: find.text('Dinner'),
      matching: find.byType(Positioned),
    ).first;
    final dinnerPositioned = tester.widget<Positioned>(dinnerBlockFinder);
    
    expect(dinnerPositioned.top, greaterThan(positioned.top! + positioned.height!));
  });
}
