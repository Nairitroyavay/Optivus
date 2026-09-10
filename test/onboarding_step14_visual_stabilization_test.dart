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
    testWidgets('Time rail has clean spine and short ticks with no full-width dividers', (
      tester,
    ) async {
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
      expect(find.byKey(const ValueKey('step14-rail-hour-540')), findsOneWidget);
      expect(find.byKey(const ValueKey('step14-rail-hour-600')), findsOneWidget);

      // Half-hour ticks present
      expect(find.byKey(const ValueKey('step14-rail-half-570')), findsOneWidget);

      // Minor 10-minute ticks present
      expect(find.byKey(const ValueKey('step14-rail-minor-550')), findsOneWidget);

      // Event boundary connectors present for exact event boundaries
      expect(find.byKey(const ValueKey('step14-rail-connector-540')), findsOneWidget);
      expect(find.byKey(const ValueKey('step14-rail-connector-660')), findsOneWidget);
      expect(find.byKey(const ValueKey('step14-rail-connector-720')), findsOneWidget);
      expect(find.byKey(const ValueKey('step14-rail-connector-750')), findsOneWidget);

      // CRITICAL: NO full-width Divider widgets across the screen
      expect(find.byType(Divider), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Multi-dish meal card measured height >= rendered content across scales and widths', (
      tester,
    ) async {
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
    });

    testWidgets('Overlap isolation: completely covered cards are offstage and do not paint', (
      tester,
    ) async {
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

      bool isCardOffstage(String id) {
        final offstageFinder = find.descendant(
          of: find.byKey(ValueKey('step14-timeline-card-semantics-$id')),
          matching: find.byType(Offstage),
        );
        return tester.widget<Offstage>(offstageFinder).offstage;
      }

      // One card is offstage, the other is on stage
      expect(isCardOffstage('office') != isCardOffstage('meeting'), isTrue);
      final initialOffstageId = isCardOffstage('office') ? 'office' : 'meeting';
      final initialVisibleId = initialOffstageId == 'office' ? 'meeting' : 'office';

      // Exactly ONE back tab exists
      final backTabs = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('step14-timeline-back-tab-'),
      );
      expect(backTabs, findsOneWidget);

      // Tapping back tab swaps visibility
      await tester.tap(backTabs);
      await tester.pumpAndSettle();

      expect(isCardOffstage(initialOffstageId), isFalse);
      expect(isCardOffstage(initialVisibleId), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Back tabs are deduplicated: multi-region overlapping activity has exactly ONE back tab', (
      tester,
    ) async {
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
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('step14-timeline-back-tab-long-block-'),
      );

      expect(longBlockTabs, findsOneWidget);
    });
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
