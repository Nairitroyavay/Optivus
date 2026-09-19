import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/adapters/fixed_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/adapters/meal_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/adapters/skin_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/work_review_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/work_source_selection_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_timeline_card.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  group('Base Timeline Domain Visual & Layout Tests', () {
    test(
      'All 4 adapters use BaseTimelineDomainCard.minimumHeight as single source of truth',
      () {
        const workAdapter = BaseTimelineWorkAdapter();
        const mealAdapter = MealTimelineAdapter();
        const fixedAdapter = FixedTimelineAdapter();
        const skinAdapter = SkinTimelineAdapter();

        final workBlock = const TimelineBlockDraft(
          id: 'work-1',
          section: 'work',
          title: 'Deep Work Session',
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.softBlockKey,
          location: 'Office Room 4B',
          sectionLabel: 'Engineering',
          notes: 'Prepare sprint deliverables and review pull requests.',
        );
        final workExpectedMin = BaseTimelineDomainCard.minimumHeight(
          workBlock,
          BaseTimelineCardDomain.work,
        );
        final workEntries = workAdapter.toEntries(workBlock);
        expect(workEntries, isNotEmpty);
        expect(workEntries.first.minHeight, equals(workExpectedMin));

        final eatingBlock = const TimelineBlockDraft(
          id: 'meal-1',
          section: 'eating',
          title: 'Lunch Bowl',
          startMinute: 12 * 60,
          endMinute: 12 * 60 + 30,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          mealSlot: 'lunch',
          mealCategory: 'main',
          calories: 650,
          protein: 45,
          dishes: ['Quinoa Salad', 'Grilled Chicken', 'Avocado Slice'],
        );
        final eatingExpectedMin = BaseTimelineDomainCard.minimumHeight(
          eatingBlock,
          BaseTimelineCardDomain.eating,
        );
        final eatingEntries = mealAdapter.toEntries(eatingBlock);
        expect(eatingEntries, isNotEmpty);
        expect(eatingEntries.first.minHeight, equals(eatingExpectedMin));

        final fixedBlock = const TimelineBlockDraft(
          id: 'fixed-sleep-1',
          section: 'fixed',
          title: 'Sleep',
          startMinute: 23 * 60,
          endMinute: 7 * 60,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
          crossesMidnight: true,
          endsNextDay: true,
          location: 'Bedroom',
          notes: 'Wind down 30 minutes before sleep.',
        );
        final fixedExpectedMin = BaseTimelineDomainCard.minimumHeight(
          fixedBlock,
          BaseTimelineCardDomain.fixed,
        );
        final fixedEntries = fixedAdapter.toEntries(fixedBlock);
        expect(fixedEntries, isNotEmpty);
        expect(fixedEntries.first.minHeight, equals(fixedExpectedMin));

        final skinBlock = const TimelineBlockDraft(
          id: 'skin-1',
          section: 'skinCare',
          title: 'Morning Skincare Routine',
          startMinute: 7 * 60 + 30,
          endMinute: 7 * 60 + 45,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareSlotLabel: 'morning',
          skincareSteps: ['Cleanser', 'Toner', 'Vitamin C Serum', 'Sunscreen'],
          skincareProducts: ['Gentle Hydrating Cleanser', 'Pure Vitamin C 15%'],
          skincareMissingItems: ['Mineral Sunscreen SPF 50'],
        );
        final skinExpectedMin = BaseTimelineDomainCard.minimumHeight(
          skinBlock,
          BaseTimelineCardDomain.skinCare,
        );
        final skinEntries = skinAdapter.toEntries(skinBlock);
        expect(skinEntries, isNotEmpty);
        expect(skinEntries.first.minHeight, equals(skinExpectedMin));
      },
    );

    testWidgets(
      'BaseTimelineDomainCard renders across all 4 domains without overflow',
      (tester) async {
        const workAdapter = BaseTimelineWorkAdapter();
        const mealAdapter = MealTimelineAdapter();
        const fixedAdapter = FixedTimelineAdapter();
        const skinAdapter = SkinTimelineAdapter();

        final workBlock = const TimelineBlockDraft(
          id: 'work-1',
          section: 'work',
          title: 'Product Design Architecture Sync',
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.softBlockKey,
          location: 'Building B, 3rd Floor, Studio 12',
          sectionLabel: 'Product & Design Core Operations',
          notes:
              'Review detailed UI flows, accessibility audits, and state management lifecycle edge cases.',
        );
        final workEntry = workAdapter.toEntries(workBlock).first;
        final workPos = PositionedTimelineEntry(
          entry: workEntry,
          top: 0,
          height: 180,
          left: 0,
          width: 300,
          column: 0,
          columnCount: 1,
        );

        final eatingBlock = const TimelineBlockDraft(
          id: 'meal-1',
          section: 'eating',
          title: 'Post-Workout Balanced Recovery Meal',
          startMinute: 13 * 60,
          endMinute: 13 * 60 + 45,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          mealSlot: 'lunch',
          mealCategory: 'high_protein',
          calories: 820,
          protein: 55,
          dishes: [
            'Brown Rice & Lentils',
            'Tofu & Vegetable Stir Fry',
            'Mixed Green Salad with Seeds',
          ],
        );
        final eatingEntry = mealAdapter.toEntries(eatingBlock).first;
        final eatingPos = PositionedTimelineEntry(
          entry: eatingEntry,
          top: 0,
          height: 200,
          left: 0,
          width: 300,
          column: 0,
          columnCount: 1,
        );

        final fixedBlock = const TimelineBlockDraft(
          id: 'fixed-1',
          section: 'fixed',
          title: 'Core Rest & Recovery Sleep',
          startMinute: 23 * 60,
          endMinute: 7 * 60,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
          crossesMidnight: true,
          endsNextDay: true,
          location: 'Primary Residence',
          notes: 'Room temperature at 19°C, dark environment.',
        );
        final fixedEntry = fixedAdapter.toEntries(fixedBlock).first;
        final fixedPos = PositionedTimelineEntry(
          entry: fixedEntry,
          top: 0,
          height: 160,
          left: 0,
          width: 300,
          column: 0,
          columnCount: 1,
        );

        final skinBlock = const TimelineBlockDraft(
          id: 'skin-1',
          section: 'skinCare',
          title: 'Evening Dermatological Routine',
          startMinute: 22 * 60,
          endMinute: 22 * 60 + 20,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareSlotLabel: 'night',
          skincareSteps: [
            'Oil Cleanser',
            'Hydrating Cleanser',
            'Retinoid Treatment',
            'Barrier Moisturizer',
          ],
          skincareProducts: ['Micellar Water', 'Hyaluronic Acid 2%'],
          skincareMissingItems: ['Ceramide Repair Balm'],
        );
        final skinEntry = skinAdapter.toEntries(skinBlock).first;
        final skinPos = PositionedTimelineEntry(
          entry: skinEntry,
          top: 0,
          height: 240,
          left: 0,
          width: 300,
          column: 0,
          columnCount: 1,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: 180,
                      width: 300,
                      child: BaseTimelineDomainCard(
                        positioned: workPos,
                        block: workBlock,
                        domain: BaseTimelineCardDomain.work,
                        accent: OptivusColors.brandAccent,
                        isEditable: true,
                        onTap: () {},
                        onDelete: () {},
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      width: 300,
                      child: BaseTimelineDomainCard(
                        positioned: eatingPos,
                        block: eatingBlock,
                        domain: BaseTimelineCardDomain.eating,
                        accent: OptivusColors.roseAccent,
                        isEditable: true,
                        onTap: () {},
                        onDelete: () {},
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      width: 300,
                      child: BaseTimelineDomainCard(
                        positioned: fixedPos,
                        block: fixedBlock,
                        domain: BaseTimelineCardDomain.fixed,
                        accent: OptivusColors.purpleAccent,
                        isEditable: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 240,
                      width: 300,
                      child: BaseTimelineDomainCard(
                        positioned: skinPos,
                        block: skinBlock,
                        domain: BaseTimelineCardDomain.skinCare,
                        accent: OptivusColors.mintAccent,
                        isEditable: true,
                        onTap: () {},
                        onDelete: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Product Design Architecture Sync'), findsOneWidget);
        expect(
          find.text('Post-Workout Balanced Recovery Meal'),
          findsOneWidget,
        );
        expect(find.text('Core Rest & Recovery Sleep'), findsOneWidget);
        expect(find.text('Evening Dermatological Routine'), findsOneWidget);

        expect(find.text('820 kcal · 55 g protein'), findsOneWidget);
        expect(find.text('Continues overnight'), findsOneWidget);

        final err = tester.takeException();
        expect(err, isNull);
      },
    );

    testWidgets(
      'BaseTimelineCurrentSetupHeader renders cleanly at 320dp width and textScale 2.0',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool resetTapped = false;
        bool primaryTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 600),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: BaseTimelineCurrentSetupHeader(
                  title: 'Work / Business Schedule',
                  summary:
                      'Configured with 3 shifts per week across Monday, Wednesday, and Friday',
                  accent: OptivusColors.brandAccent,
                  onBack: () {},
                  primaryButtonLabel: 'Change setup',
                  onPrimaryAction: () => primaryTapped = true,
                  resetLabel: 'Remove Work Setup',
                  onReset: () => resetTapped = true,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Work / Business Schedule'), findsOneWidget);
        expect(find.text('Change setup'), findsOneWidget);
        expect(
          find.byKey(const Key('base-timeline-header-menu-button')),
          findsOneWidget,
        );

        await tester.tap(find.text('Change setup'));
        expect(primaryTapped, isTrue);

        await tester.tap(
          find.byKey(const Key('base-timeline-header-menu-button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Remove Work Setup'), findsOneWidget);
        await tester.tap(find.text('Remove Work Setup'));
        await tester.pumpAndSettle();
        expect(resetTapped, isTrue);

        final err = tester.takeException();
        expect(err, isNull);
      },
    );

    testWidgets(
      'BaseTimelineRefreshPendingBanner renders message and fires onRetry',
      (tester) async {
        bool retryClicked = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: BaseTimelineRefreshPendingBanner(
                message: 'Custom setup update requires routine rebuild.',
                onRetry: () => retryClicked = true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Custom setup update requires routine rebuild.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        expect(retryClicked, isTrue);
      },
    );

    testWidgets(
      'WorkTimelineCard renders complete metadata without overflow or trash can on card face',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'work-test-card-1',
          section: 'work',
          title: 'Executive Client Briefing',
          startMinute: 14 * 60,
          endMinute: 16 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
          location: 'Conference Room Alpha',
          sectionLabel: 'Q4 Strategy',
          notes: 'Deliver roadmap summary and action items.',
        );

        const adapter = BaseTimelineWorkAdapter();
        final entry = adapter.toEntries(block).first;
        final pos = PositionedTimelineEntry(
          entry: entry,
          top: 0,
          height: WorkTimelineCard.minimumHeight(block),
          left: 0,
          width: 320,
          column: 0,
          columnCount: 1,
        );

        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  height: WorkTimelineCard.minimumHeight(block),
                  child: WorkTimelineCard(
                    positioned: pos,
                    block: block,
                    accent: OptivusColors.warning,
                    isEditable: true,
                    onTap: () => tapped = true,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Metadata assertions
        expect(find.text('Executive Client Briefing'), findsOneWidget);
        expect(find.text('Conference Room Alpha'), findsOneWidget);
        expect(find.text('Q4 Strategy'), findsOneWidget);
        expect(
          find.text('Deliver roadmap summary and action items.'),
          findsOneWidget,
        );

        // Verification: NO trash can icon anywhere on card face
        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
        expect(find.byIcon(Icons.delete_rounded), findsNothing);

        // Tap triggers callback
        await tester.tap(find.text('Executive Client Briefing'));
        expect(tapped, isTrue);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'WorkTimelineCard renders exposed back card styling and triggers onTap to bring to front',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'work-back-card',
          section: 'work',
          title: 'Back Office Operations',
          startMinute: 10 * 60,
          endMinute: 12 * 60,
          repeatDays: [1, 2, 3],
          blockType: TimelineBlockDraft.hardBlockKey,
        );

        const adapter = BaseTimelineWorkAdapter();
        final entry = adapter.toEntries(block).first;
        // Positioned with overlap where it is NOT front
        final pos = PositionedTimelineEntry(
          entry: entry,
          top: 0,
          height: 80,
          left: 0,
          width: 300,
          column: 0,
          columnCount: 1,
          hasOverlap: true,
          isFront: false,
        );

        bool broughtToFront = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 80,
                  child: WorkTimelineCard(
                    positioned: pos,
                    block: block,
                    accent: OptivusColors.warning,
                    isEditable: false,
                    onTap: () => broughtToFront = true,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Back Office Operations'), findsOneWidget);
        await tester.tap(find.text('Back Office Operations'));
        expect(broughtToFront, isTrue);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('WorkSourceSelectionView renders cleanly at 320dp width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final setup = BaseTimelineSetup(
        uid: 'user-source-test',
        updatedAt: DateTime.now(),
        workBlocks: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkSourceSelectionView(
              setup: setup,
              lifeRole: LifeRoleDraft.workingKey,
              onCancel: () {},
              onPickPhoto: (_) {},
              onManualSetup: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Set up Work Schedule'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Set up manually'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'WorkReviewView renders cleanly at 320dp width with empty blocks',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: WorkReviewView(
                lifeRole: LifeRoleDraft.workingKey,
                workingBlocks: const [],
                workingAssetId: null,
                workingR2Key: null,
                workingLocalPreviewPath: null,
                selectedDay: 1,
                onDayChanged: (_) {},
                droppedCount: 0,
                droppedExamples: const [],
                errorMessage: null,
                onClearError: () {},
                isSaving: false,
                onCancel: () {},
                onScanAgain: () {},
                onAddBlock: () {},
                onEditBlock: (_) {},
                onSave: () {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Review Work Schedule'), findsOneWidget);
        expect(find.text('No work blocks scheduled'), findsOneWidget);
        expect(find.text('Add photo'), findsOneWidget);
        expect(find.text('Add work block'), findsOneWidget);
        expect(find.text('Use this work schedule'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
