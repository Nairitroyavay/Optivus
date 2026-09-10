import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/timeline/widgets/step14_final_timeline.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 14 Visual Stabilization Regression Suite', () {
    testWidgets(
      'Time rail has clean spine and short ticks with no full-width dividers',
      (tester) async {
        final bundle = _testBundle(const [
          TimelineBlockDraft(
            id: 'work',
            section: 'job_work_business',
            title: 'Work Block',
            startMinute: 540,
            endMinute: 660,
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'lunch',
            section: 'eating',
            title: 'Lunch',
            startMinute: 720,
            endMinute: 750,
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Step14FinalTimeline(
                bundle: bundle,
                selectedDay: 1,
                onDayChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Spine must be present
        expect(find.byKey(const ValueKey('step14-rail-spine')), findsOneWidget);

        // Major hour ticks present
        expect(
          find.byKey(const ValueKey('step14-rail-hour-540')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('step14-rail-hour-600')),
          findsOneWidget,
        );

        // Half-hour ticks present
        expect(
          find.byKey(const ValueKey('step14-rail-half-570')),
          findsOneWidget,
        );

        // Minor 10-minute ticks present
        expect(
          find.byKey(const ValueKey('step14-rail-minor-550')),
          findsOneWidget,
        );

        // Event boundary connectors present for exact event boundaries
        expect(
          find.byKey(const ValueKey('step14-rail-connector-540')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('step14-rail-connector-660')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('step14-rail-connector-720')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('step14-rail-connector-750')),
          findsOneWidget,
        );

        // CRITICAL: NO full-width Divider widgets across the screen
        expect(find.byType(Divider), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Multi-dish meal card measured height >= rendered content across scales and widths',
      (tester) async {
        const meal = TimelineBlockDraft(
          id: 'breakfast',
          section: 'eating',
          title: 'Power Breakfast Bowl',
          startMinute: 480,
          endMinute: 525,
          repeatDays: [1],
          blockType: TimelineBlockDraft.hardBlockKey,
          mealCategory: 'Breakfast',
          calories: 650,
          protein: 34,
          dishes: [
            'Scrambled Eggs with Spinach',
            'Avocado Whole Wheat Toast',
            'Greek Yogurt with Berries and Honey',
            'Black Coffee',
          ],
        );

        final items = buildStep14FinalTimelineItems(_testBundle(const [meal]));
        final item = items.first;

        for (final scale in [1.0, 1.3, 1.6]) {
          for (final width in [320.0, 360.0, 393.0, 412.0]) {
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: Builder(
                      builder: (context) {
                        final measured = Step14FinalTimelineCard.measureHeight(
                          context,
                          width,
                          item,
                        );
                        return Center(
                          child: SizedBox(
                            key: ValueKey('test-meal-box-$scale-$width'),
                            width: width,
                            height: measured,
                            child: Step14FinalTimelineCard(item: item),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            // Zero exceptions (no RenderFlex overflow whatsoever)
            expect(tester.takeException(), isNull);

            // All dishes rendered
            for (final dish in meal.dishes) {
              expect(find.text(dish), findsOneWidget);
            }

            // Nutrition rendered
            expect(find.text('650 kcal • 34g protein'), findsOneWidget);
          }
        }
      },
    );

    testWidgets(
      'Overlap isolation: rich back content is suppressed while continuous background surface remains mounted',
      (tester) async {
        final bundle = _testBundle(const [
          TimelineBlockDraft(
            id: 'office',
            section: 'job_work_business',
            title: 'Office Work Session',
            startMinute: 540,
            endMinute: 600,
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'meeting',
            section: 'classes',
            title: 'Team Sync Meeting',
            startMinute: 540,
            endMinute: 600,
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ]);
        final key = GlobalKey<Step14FinalTimelineState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Step14FinalTimeline(
                key: key,
                bundle: bundle,
                selectedDay: 1,
                onDayChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Both background surfaces MUST exist continuously
        expect(
          find.byKey(const ValueKey('step14-card-background-office')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('step14-card-background-meeting')),
          findsOneWidget,
        );

        bool isCardContentOffstage(String id) {
          final offstageFinder = find.descendant(
            of: find.byKey(ValueKey('step14-timeline-card-semantics-$id')),
            matching: find.byType(Offstage),
          );
          return tester.widget<Offstage>(offstageFinder).offstage;
        }

        // Exactly one card's rich content is offstage, the other is on stage
        expect(
          isCardContentOffstage('office') != isCardContentOffstage('meeting'),
          isTrue,
        );
        final initialOffstageId = isCardContentOffstage('office')
            ? 'office'
            : 'meeting';
        final initialVisibleId = initialOffstageId == 'office'
            ? 'meeting'
            : 'office';

        final prepared = key.currentState!.preparedLayoutForTesting!;
        final backCard = tester.widget<Positioned>(
          find.byKey(ValueKey('step14-timeline-card-$initialOffstageId')),
        );
        expect(backCard.width, prepared.fullWidth);
        expect(backCard.left, prepared.leftOffset);

        final frontCard = tester.widget<Positioned>(
          find.byKey(ValueKey('step14-timeline-card-$initialVisibleId')),
        );
        expect(frontCard.width, prepared.frontWidth);
        expect(frontCard.left, prepared.leftOffset + prepared.gutterWidth);

        // Exactly ONE back tab exists
        final backTabs = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'step14-timeline-back-tab-',
              ),
        );
        expect(backTabs, findsOneWidget);

        // Tapping back tab swaps foreground without destroying card backgrounds
        await tester.tap(backTabs);
        await tester.pumpAndSettle();

        expect(isCardContentOffstage(initialOffstageId), isFalse);
        expect(isCardContentOffstage(initialVisibleId), isTrue);

        // Background surfaces remain mounted
        expect(
          find.byKey(const ValueKey('step14-card-background-office')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('step14-card-background-meeting')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Section 26: Very long card Work 1 PM-5 PM overlapping Lunch 1:00-1:45 maintains continuous surface',
      (tester) async {
        final bundle = _testBundle(const [
          TimelineBlockDraft(
            id: 'work',
            section: 'job_work_business',
            title: 'Project Work',
            startMinute: 780, // 1:00 PM
            endMinute: 1020, // 5:00 PM
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'lunch',
            section: 'eating',
            title: 'Lunch',
            startMinute: 780, // 1:00 PM
            endMinute: 825, // 1:45 PM
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
            mealCategory: 'Lunch',
          ),
        ]);
        final key = GlobalKey<Step14FinalTimelineState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Step14FinalTimeline(
                key: key,
                bundle: bundle,
                selectedDay: 1,
                onDayChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final prepared = key.currentState!.preparedLayoutForTesting!;
        final scale = prepared.layout.scale;

        // Verify Work background surface exists continuously from 13:00 to 17:00
        final workCardFinder = find.byKey(
          const ValueKey('step14-timeline-card-work'),
        );
        final workBgFinder = find.byKey(
          const ValueKey('step14-card-background-work'),
        );
        expect(workCardFinder, findsOneWidget);
        expect(workBgFinder, findsOneWidget);

        final initialWorkCard = tester.widget<Positioned>(workCardFinder);
        expect(initialWorkCard.top, closeTo(scale.yForMinute(780), 0.5));
        expect(
          initialWorkCard.height,
          closeTo(scale.yForMinute(1020) - scale.yForMinute(780), 0.5),
        );
        // Initially Lunch is front (shorter duration), Work is back (full width)
        expect(initialWorkCard.width, prepared.fullWidth);
        expect(initialWorkCard.left, prepared.leftOffset);

        // Tap Work back tab to focus Work
        final workTab = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'step14-timeline-back-tab-work-',
              ),
        );
        expect(workTab, findsOneWidget);
        await tester.tap(workTab);
        await tester.pumpAndSettle();

        // Work is now front; background surface MUST still exist and have same top and height
        expect(workBgFinder, findsOneWidget);
        final focusedWorkCard = tester.widget<Positioned>(workCardFinder);
        expect(focusedWorkCard.top, initialWorkCard.top);
        expect(focusedWorkCard.height, initialWorkCard.height);
        expect(focusedWorkCard.width, prepared.frontWidth);
        expect(
          focusedWorkCard.left,
          prepared.leftOffset + prepared.gutterWidth,
        );

        // Tap Lunch back tab to restore Lunch to front
        final lunchTab = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'step14-timeline-back-tab-lunch-',
              ),
        );
        expect(lunchTab, findsOneWidget);
        await tester.tap(lunchTab);
        await tester.pumpAndSettle();

        // Restored state: Work background surface is identical to initial
        expect(workBgFinder, findsOneWidget);
        final restoredWorkCard = tester.widget<Positioned>(workCardFinder);
        expect(restoredWorkCard.top, initialWorkCard.top);
        expect(restoredWorkCard.height, initialWorkCard.height);
        expect(restoredWorkCard.width, initialWorkCard.width);
        expect(restoredWorkCard.left, initialWorkCard.left);
      },
    );

    testWidgets(
      'Section 27: Multi-region long card Office Work 9-12 with Classes A, B, C continuous fill',
      (tester) async {
        final bundle = _testBundle(const [
          TimelineBlockDraft(
            id: 'office',
            section: 'job_work_business',
            title: 'Office Work',
            startMinute: 540, // 9:00 AM
            endMinute: 720, // 12:00 PM
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'class-a',
            section: 'classes',
            title: 'Class A',
            startMinute: 540, // 9:00 AM
            endMinute: 600, // 10:00 AM
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'class-b',
            section: 'classes',
            title: 'Class B',
            startMinute: 600, // 10:00 AM
            endMinute: 660, // 11:00 AM
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'class-c',
            section: 'classes',
            title: 'Class C',
            startMinute: 660, // 11:00 AM
            endMinute: 720, // 12:00 PM
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ]);
        final key = GlobalKey<Step14FinalTimelineState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Step14FinalTimeline(
                key: key,
                bundle: bundle,
                selectedDay: 1,
                onDayChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final prepared = key.currentState!.preparedLayoutForTesting!;
        final scale = prepared.layout.scale;

        final officeCardFinder = find.byKey(
          const ValueKey('step14-timeline-card-office'),
        );
        final officeBgFinder = find.byKey(
          const ValueKey('step14-card-background-office'),
        );
        expect(officeCardFinder, findsOneWidget);
        expect(officeBgFinder, findsOneWidget);

        final initialOffice = tester.widget<Positioned>(officeCardFinder);
        expect(initialOffice.top, closeTo(scale.yForMinute(540), 0.5));
        expect(
          initialOffice.height,
          closeTo(scale.yForMinute(720) - scale.yForMinute(540), 0.5),
        );
        expect(initialOffice.width, prepared.fullWidth);
        expect(initialOffice.left, prepared.leftOffset);

        // Toggle focus 5 times and assert appearance determinism
        for (var i = 0; i < 5; i++) {
          final officeTab = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'step14-timeline-back-tab-office-',
                ),
          );
          if (officeTab.evaluate().isNotEmpty) {
            await tester.tap(officeTab);
          } else {
            await tester.tap(officeCardFinder);
          }
          await tester.pumpAndSettle();
        }

        // Background surface still firmly mounted with continuous geometry
        expect(officeBgFinder, findsOneWidget);
        final currentOffice = tester.widget<Positioned>(officeCardFinder);
        expect(currentOffice.top, initialOffice.top);
        expect(currentOffice.height, initialOffice.height);
      },
    );

    testWidgets(
      'Section 28: Short back card Snack 5:00-5:20 overlapping Skin 5:00-5:15 remains continuous',
      (tester) async {
        final bundle = _testBundle(const [
          TimelineBlockDraft(
            id: 'snack',
            section: 'eating',
            title: 'Snack',
            startMinute: 1020, // 5:00 PM
            endMinute: 1040, // 5:20 PM
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
            mealCategory: 'Snack',
          ),
          TimelineBlockDraft(
            id: 'skin',
            section: 'skin_care',
            title: 'After-lunch Skin Care',
            startMinute: 1020, // 5:00 PM
            endMinute: 1035, // 5:15 PM
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ]);
        final key = GlobalKey<Step14FinalTimelineState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Step14FinalTimeline(
                key: key,
                bundle: bundle,
                selectedDay: 1,
                onDayChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final prepared = key.currentState!.preparedLayoutForTesting!;
        final scale = prepared.layout.scale;

        // Snack background exists continuously through 5:00 to 5:20
        final snackCardFinder = find.byKey(
          const ValueKey('step14-timeline-card-snack'),
        );
        final snackBgFinder = find.byKey(
          const ValueKey('step14-card-background-snack'),
        );
        expect(snackCardFinder, findsOneWidget);
        expect(snackBgFinder, findsOneWidget);

        final snackCard = tester.widget<Positioned>(snackCardFinder);
        expect(snackCard.top, closeTo(scale.yForMinute(1020), 0.5));
        expect(
          snackCard.height,
          closeTo(scale.yForMinute(1040) - scale.yForMinute(1020), 0.5),
        );
        expect(snackCard.width, prepared.fullWidth);
        expect(snackCard.left, prepared.leftOffset);

        // Skin care is front
        final skinCard = tester.widget<Positioned>(
          find.byKey(const ValueKey('step14-timeline-card-skin')),
        );
        expect(skinCard.width, prepared.frontWidth);
        expect(skinCard.left, prepared.leftOffset + prepared.gutterWidth);
      },
    );

    testWidgets(
      'Section 29: Widget tree stability proves logical surface key does not disappear',
      (tester) async {
        final bundle = _testBundle(const [
          TimelineBlockDraft(
            id: 'job',
            section: 'job_work_business',
            title: 'Job',
            startMinute: 780,
            endMinute: 960,
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'lunch',
            section: 'eating',
            title: 'Lunch',
            startMinute: 780,
            endMinute: 825,
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Step14FinalTimeline(
                bundle: bundle,
                selectedDay: 1,
                onDayChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check key presence before tap
        expect(
          find.byKey(const ValueKey('step14-card-background-job')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('step14-card-background-lunch')),
          findsOneWidget,
        );

        final jobTab = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'step14-timeline-back-tab-job-',
              ),
        );
        await tester.tap(jobTab);
        await tester.pumpAndSettle();

        // Keys MUST NOT disappear
        expect(
          find.byKey(const ValueKey('step14-card-background-job')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('step14-card-background-lunch')),
          findsOneWidget,
        );

        final lunchTab = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'step14-timeline-back-tab-lunch-',
              ),
        );
        await tester.tap(lunchTab);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('step14-card-background-job')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('step14-card-background-lunch')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Back tabs are deduplicated: multi-region overlapping activity has exactly ONE back tab',
      (tester) async {
        final bundle = _testBundle(const [
          TimelineBlockDraft(
            id: 'long-block',
            section: 'job_work_business',
            title: 'Long Work Block',
            startMinute: 540,
            endMinute: 720,
            repeatDays: [1],
            blockType: TimelineBlockDraft.softBlockKey,
          ),
          TimelineBlockDraft(
            id: 'short-1',
            section: 'classes',
            title: 'Class 1',
            startMinute: 540,
            endMinute: 600,
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'short-2',
            section: 'classes',
            title: 'Class 2',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Step14FinalTimeline(
                bundle: bundle,
                selectedDay: 1,
                onDayChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final longBlockTabs = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'step14-timeline-back-tab-long-block-',
              ),
        );

        expect(longBlockTabs, findsOneWidget);
      },
    );
  });
}

OnboardingCompletionBundle _testBundle(List<TimelineBlockDraft> blocks) {
  final now = DateTime(2026, 9, 9);
  return OnboardingCompletionBundle(
    uid: 'step14-visual-test',
    createdAt: now,
    updatedAt: now,
    userProfilePatch: const {},
    baseTimelineBlocks: blocks,
    finalTimelineItems: const [],
    routineItemsForApp: const [],
    goodHabitTemplates: const [],
    badHabitCheckIns: const [],
    identityGoalSystems: const [],
    notificationPreferences: NotificationPreferences(),
    coachPreferences: CoachPreferences(),
    moneyGoal: null,
    uploadedAssetReferences: const [],
    warnings: const [],
    duplicateSystemKeysMerged: const [],
  );
}
