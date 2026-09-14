import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_spacing.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_style.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_day_chips.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_time_rail.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_viewport.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_current_setup_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  group('1. TimelineTimeRailBackground Hour Mark Lower-Bound Safety', () {
    testWidgets(
      'Does not render hour marks prior to scale.startMinute (e.g. 7 AM when startMinute is 7:30 AM / 450)',
      (tester) async {
        const scale = TimelineScale(
          startMinute: 450, // 7:30 AM
          endMinute: 720, // 12:00 PM
          pixelsPerMinute: 1.1,
          topPadding: 18.0,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                width: 300,
                child: TimelineTimeRailBackground(
                  scale: scale,
                  boundaryMinutes: [],
                ),
              ),
            ),
          ),
        );

        // 7 AM (minute 420) must NOT be rendered because 420 < 450
        expect(find.byKey(const ValueKey('timeline-hour-420')), findsNothing);
        expect(find.text('7 AM'), findsNothing);

        // 8 AM (minute 480) must be rendered because 480 >= 450
        expect(find.byKey(const ValueKey('timeline-hour-480')), findsOneWidget);
        expect(find.text('8 AM'), findsOneWidget);

        // Verify top position of 8 AM is strictly positive
        final hour8 = tester.widget<Positioned>(
          find.byKey(const ValueKey('timeline-hour-480')),
        );
        expect(hour8.top, isNotNull);
        expect(hour8.top!, greaterThan(0.0));
      },
    );

    testWidgets(
      'All hour mark labels have top >= 0 when startMinute is 420 (7 AM) and topPadding is 18',
      (tester) async {
        const scale = TimelineScale(
          startMinute: 420, // 7:00 AM
          endMinute: 1380, // 11:00 PM
          pixelsPerMinute: 1.1,
          topPadding: 18.0,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 800,
                width: 300,
                child: TimelineTimeRailBackground(
                  scale: scale,
                  boundaryMinutes: [],
                ),
              ),
            ),
          ),
        );

        // 7 AM is rendered
        expect(find.byKey(const ValueKey('timeline-hour-420')), findsOneWidget);
        final hour7 = tester.widget<Positioned>(
          find.byKey(const ValueKey('timeline-hour-420')),
        );
        // top = 18.0 - 18.0 / 2 = 9.0 >= 0
        expect(hour7.top, equals(9.0));
        expect(hour7.top!, greaterThanOrEqualTo(0.0));
      },
    );
  });

  group('2. Viewport Clipping & Structural Containment', () {
    testWidgets(
      'TimelineViewport has Clip.hardEdge on Container and Stack',
      (tester) async {
        const scale = TimelineScale(
          startMinute: 420,
          endMinute: 1380,
          pixelsPerMinute: 1.1,
          topPadding: 18.0,
        );
        const result = TimelineLayoutResult(
          scale: scale,
          entries: [],
          totalHeight: 1200,
          boundaryMinutes: [],
          visibleStartMinute: 420,
          visibleEndMinute: 1380,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimelineViewport(
                layoutResult: result,
                styleBuilder: (_) => const TimelineEntryStyle(
                  accentColor: Colors.blue,
                ),
              ),
            ),
          ),
        );

        final containerFinder = find.byType(Container);
        expect(containerFinder, findsWidgets);
        final viewportContainer = tester.widget<Container>(containerFinder.first);
        expect(viewportContainer.clipBehavior, equals(Clip.hardEdge));

        final stackFinder = find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Stack),
        );
        expect(stackFinder, findsWidgets);
        final innerStack = tester.widget<Stack>(stackFinder.first);
        expect(innerStack.clipBehavior, equals(Clip.hardEdge));
      },
    );
  });

  group('3. Explicit Vertical Regions in ClassesCurrentSetupView', () {
    testWidgets(
      'Header -> Photo Preview -> Weekday Selector -> intentional gap -> Timeline Viewport are distinct and sequential',
      (tester) async {
        final setup = BaseTimelineSetup(
          uid: 'test_user',
          updatedAt: DateTime.now(),
          classLogicalAssetR2Key: 'test_timetable_photo.jpg',
          classBlocks: const [
            TimelineBlockDraft(
              id: 'cls_1',
              section: 'classes',
              title: 'Algorithms',
              startMinute: 480,
              endMinute: 570,
              repeatDays: [1, 3, 5],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final blocks = [
          ClassRoutineBlock(
            id: 'cls_1',
            subject: 'Algorithms',
            section: 'CS101',
            startMinute: 480, // 8:00 AM
            endMinute: 570, // 9:30 AM
            repeatDays: const [1, 3, 5], // Mon, Wed, Fri
          ),
          ClassRoutineBlock(
            id: 'cls_2',
            subject: 'Operating Systems',
            section: 'CS201',
            startMinute: 600, // 10:00 AM
            endMinute: 690, // 11:30 AM
            repeatDays: const [2, 4], // Tue, Thu
          ),
        ];

        int currentDay = 1;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    return ClassesCurrentSetupView(
                      setup: setup,
                      routineBlocks: blocks,
                      selectedDay: currentDay,
                      onDayChanged: (day) => setState(() => currentDay = day),
                      onBack: () {},
                      onChangeSetup: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Header is present
        expect(find.text('Classes'), findsOneWidget);
        final headerRect = tester.getRect(find.text('Classes'));

        // 2. Photo preview is present and strictly below Header
        final photoCardFinder = find.byType(BaseTimelinePhotoPreviewCard);
        expect(photoCardFinder, findsOneWidget);
        final photoRect = tester.getRect(photoCardFinder);
        expect(photoRect.top, greaterThan(headerRect.bottom));

        // 3. Weekday selector is strictly below Photo preview
        final chipsFinder = find.byType(TimelineDayChips);
        expect(chipsFinder, findsOneWidget);
        final chipsRect = tester.getRect(chipsFinder);
        expect(chipsRect.top, greaterThanOrEqualTo(photoRect.bottom));

        // 4. Timeline viewport is strictly below Weekday selector with intentional gap
        final viewportFinder = find.byType(TimelineViewport);
        expect(viewportFinder, findsOneWidget);
        final viewportRect = tester.getRect(viewportFinder);

        // Conceptual check: weekday selector bottom + timelineTopGap == timeline viewport origin
        final measuredGap = viewportRect.top - chipsRect.bottom;
        expect(measuredGap, equals(OptivusSpacing.sm)); // 8.0px
        expect(viewportRect.top, equals(chipsRect.bottom + OptivusSpacing.sm));

        // 5. 7 AM label is entirely inside the timeline viewport
        final labelFinder = find.text('7 AM');
        expect(labelFinder, findsOneWidget);
        final labelRect = tester.getRect(labelFinder);

        // Must be inside the viewport
        expect(labelRect.top, greaterThan(viewportRect.top));
        expect(labelRect.bottom, lessThan(viewportRect.bottom));

        // Must NEVER geometrically share or overlap the weekday-chip row
        expect(labelRect.top, greaterThan(chipsRect.bottom));

        // 6. Safe Geometry: Visual gap between weekday chips bottom and 7 AM label is 12–20 logical px
        final visualGapToLabel = labelRect.top - chipsRect.bottom;
        expect(visualGapToLabel, greaterThanOrEqualTo(12.0));
        expect(visualGapToLabel, lessThanOrEqualTo(20.0));
      },
    );
  });

  group('4. Day-Invariance Across ALL 7 Weekdays (MON through SUN)', () {
    testWidgets(
      'Selecting MON, TUE, WED, THU, FRI, SAT, SUN preserves identical viewport origin, chip height, and 7 AM baseline',
      (tester) async {
        final setup = BaseTimelineSetup(
          uid: 'test_user_7days',
          updatedAt: DateTime.now(),
          classLogicalAssetR2Key: 'test_timetable.jpg',
          classBlocks: const [
            TimelineBlockDraft(
              id: 'cls_mon',
              section: 'classes',
              title: 'Early Math',
              startMinute: 480,
              endMinute: 540,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        // Classes on all 7 days with different start times (8 AM, 9 AM, 10 AM, 11 AM, 1 PM, 2 PM, 3 PM)
        final blocks = [
          ClassRoutineBlock(
            id: 'cls_mon',
            subject: 'Early Math',
            section: 'A',
            startMinute: 480, // 8:00 AM
            endMinute: 540,
            repeatDays: const [1], // Mon
          ),
          ClassRoutineBlock(
            id: 'cls_tue',
            subject: 'Biology',
            section: 'B',
            startMinute: 540, // 9:00 AM
            endMinute: 600,
            repeatDays: const [2], // Tue
          ),
          ClassRoutineBlock(
            id: 'cls_wed',
            subject: 'Physics',
            section: 'C',
            startMinute: 600, // 10:00 AM
            endMinute: 660,
            repeatDays: const [3], // Wed
          ),
          ClassRoutineBlock(
            id: 'cls_thu',
            subject: 'Chemistry',
            section: 'D',
            startMinute: 660, // 11:00 AM
            endMinute: 720,
            repeatDays: const [4], // Thu
          ),
          ClassRoutineBlock(
            id: 'cls_fri',
            subject: 'Art',
            section: 'E',
            startMinute: 780, // 1:00 PM
            endMinute: 840,
            repeatDays: const [5], // Fri
          ),
          ClassRoutineBlock(
            id: 'cls_sat',
            subject: 'Weekend Lab',
            section: 'F',
            startMinute: 840, // 2:00 PM
            endMinute: 900,
            repeatDays: const [6], // Sat
          ),
          ClassRoutineBlock(
            id: 'cls_sun',
            subject: 'Sunday Seminar',
            section: 'G',
            startMinute: 900, // 3:00 PM
            endMinute: 960,
            repeatDays: const [7], // Sun
          ),
        ];

        int selectedDay = 1;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    return ClassesCurrentSetupView(
                      setup: setup,
                      routineBlocks: blocks,
                      selectedDay: selectedDay,
                      onDayChanged: (day) => setState(() => selectedDay = day),
                      onBack: () {},
                      onChangeSetup: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        double? baselineViewportTop;
        double? baselineChipsHeight;
        double? baseline7AmLabelTop;

        for (int day = 1; day <= 7; day++) {
          // Tap the weekday chip
          await tester.tap(find.byKey(ValueKey('timeline-day-chip-$day')));
          await tester.pumpAndSettle();

          final chipsFinder = find.byType(TimelineDayChips);
          expect(chipsFinder, findsOneWidget);
          final chipsRect = tester.getRect(chipsFinder);

          // Check that chip container height doesn't shift between days
          if (baselineChipsHeight == null) {
            baselineChipsHeight = chipsRect.height;
          } else {
            expect(
              chipsRect.height,
              equals(baselineChipsHeight),
              reason: 'Day $day changed weekday chips height',
            );
          }

          // All days 1-7 have classes and render TimelineViewport
          final viewportFinder = find.byType(TimelineViewport);
          expect(viewportFinder, findsOneWidget);
          final viewportRect = tester.getRect(viewportFinder);

          if (baselineViewportTop == null) {
            baselineViewportTop = viewportRect.top;
          } else {
            expect(
              viewportRect.top,
              equals(baselineViewportTop),
              reason: 'Day $day shifted timeline viewport Y origin',
            );
          }

          // 7 AM label baseline check across all days
          final label7Am = find.text('7 AM');
          expect(
            label7Am,
            findsOneWidget,
            reason: 'Day $day must render 7 AM label at standard waking start',
          );
          final labelRect = tester.getRect(label7Am);

          if (baseline7AmLabelTop == null) {
            baseline7AmLabelTop = labelRect.top;
          } else {
            expect(
              labelRect.top,
              equals(baseline7AmLabelTop),
              reason: 'Day $day shifted 7 AM label baseline',
            );
          }

          // 7 AM label must be strictly inside viewport and not collide with chips
          expect(labelRect.top, greaterThan(viewportRect.top));
          expect(labelRect.top, greaterThan(chipsRect.bottom));

          // Gap between weekday chips bottom and 7 AM label must stay within 12-20px
          final gap = labelRect.top - chipsRect.bottom;
          expect(
            gap,
            greaterThanOrEqualTo(12.0),
            reason: 'Day $day gap to 7 AM label is below 12px',
          );
          expect(
            gap,
            lessThanOrEqualTo(20.0),
            reason: 'Day $day gap to 7 AM label is above 20px',
          );
        }
      },
    );
  });
}
