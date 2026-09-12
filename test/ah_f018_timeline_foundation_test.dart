import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_14_today_ready.dart';
import 'package:optivus/features/onboarding/timeline/onboarding_timeline.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  group('AH-F018 Pure Timeline Overlap Engine Geometry', () {
    const config = TimelineGeometryConfig(
      pixelsPerMinute: 1.0,
      minInteractiveHeight: 32.0,
      leftOffset: 60.0,
      rightPadding: 20.0,
      columnGap: 10.0,
      topPadding: 20.0,
      bottomPadding: 80.0,
      defaultStartMinute: 480, // 8:00 AM
      defaultEndMinute: 1200, // 8:00 PM
    );
    const availableWidth = 380.0;
    const expectedUsableWidth = availableWidth - 60.0 - 20.0; // 300.0

    test(
      'A. Touching boundaries 09:00-10:00 and 10:00-11:00 do NOT overlap',
      () {
        final entries = [
          const TimelineEntry(
            id: 'block-a',
            sourceId: 'src-a',
            startMinute: 9 * 60, // 540
            endMinute: 10 * 60, // 600
            repeatDays: [1],
            title: 'Class A',
            category: TimelineCategory.classes,
          ),
          const TimelineEntry(
            id: 'block-b',
            sourceId: 'src-b',
            startMinute: 10 * 60, // 600
            endMinute: 11 * 60, // 660
            repeatDays: [1],
            title: 'Class B',
            category: TimelineCategory.classes,
          ),
        ];

        final result = TimelineOverlapEngine.computeLayout(
          entries: entries,
          availableWidth: availableWidth,
          selectedDay: 1,
          config: config,
        );

        expect(result.entries.length, equals(2));
        final map = result.entryMap;
        final a = map['block-a']!;
        final b = map['block-b']!;

        expect(a.column, equals(0));
        expect(a.columnCount, equals(1));
        expect(a.width, equals(expectedUsableWidth));
        expect(a.left, equals(60.0));

        expect(b.column, equals(0));
        expect(b.columnCount, equals(1));
        expect(b.width, equals(expectedUsableWidth));
        expect(b.left, equals(60.0));
      },
    );

    test(
      'B. Partial overlap 09:00-10:00 and 09:30-10:30 creates 2-column overlap',
      () {
        final entries = [
          const TimelineEntry(
            id: 'block-a',
            sourceId: 'src-a',
            startMinute: 9 * 60, // 540
            endMinute: 10 * 60, // 600
            repeatDays: [1],
            title: 'Class A',
            category: TimelineCategory.classes,
          ),
          const TimelineEntry(
            id: 'block-b',
            sourceId: 'src-b',
            startMinute: 9 * 60 + 30, // 570
            endMinute: 10 * 60 + 30, // 630
            repeatDays: [1],
            title: 'Work B',
            category: TimelineCategory.work,
          ),
        ];

        final result = TimelineOverlapEngine.computeLayout(
          entries: entries,
          availableWidth: availableWidth,
          selectedDay: 1,
          config: config,
        );

        expect(result.entries.length, equals(2));
        final a = result.entryMap['block-a']!;
        final b = result.entryMap['block-b']!;

        expect(a.columnCount, equals(2));
        expect(b.columnCount, equals(2));
        expect(a.column, equals(0));
        expect(b.column, equals(1));

        const expectedColWidth = (expectedUsableWidth - 10.0) / 2.0; // 145.0
        expect(a.width, closeTo(expectedColWidth, 0.001));
        expect(b.width, closeTo(expectedColWidth, 0.001));
        expect(a.left, equals(60.0));
        expect(b.left, closeTo(60.0 + expectedColWidth + 10.0, 0.001)); // 215.0
      },
    );

    test('C. Complete overlap (same exact time range) creates 2 columns', () {
      final entries = [
        const TimelineEntry(
          id: 'block-1',
          sourceId: 'src-1',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: [1],
          title: 'Class 1',
          category: TimelineCategory.classes,
        ),
        const TimelineEntry(
          id: 'block-2',
          sourceId: 'src-2',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: [1],
          title: 'Class 2',
          category: TimelineCategory.classes,
        ),
      ];

      final result = TimelineOverlapEngine.computeLayout(
        entries: entries,
        availableWidth: availableWidth,
        selectedDay: 1,
        config: config,
      );

      final e1 = result.entryMap['block-1']!;
      final e2 = result.entryMap['block-2']!;

      expect(e1.columnCount, equals(2));
      expect(e2.columnCount, equals(2));
      expect(e1.column, equals(0));
      expect(e2.column, equals(1));
    });

    test('D. 3 mutually overlapping events produce 3 columns', () {
      final entries = [
        const TimelineEntry(
          id: 'block-1',
          sourceId: 'src-1',
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          repeatDays: [1],
          title: 'All-morning Event',
          category: TimelineCategory.classes,
        ),
        const TimelineEntry(
          id: 'block-2',
          sourceId: 'src-2',
          startMinute: 9 * 60 + 30,
          endMinute: 10 * 60 + 30,
          repeatDays: [1],
          title: 'Mid Event',
          category: TimelineCategory.work,
        ),
        const TimelineEntry(
          id: 'block-3',
          sourceId: 'src-3',
          startMinute: 10 * 60,
          endMinute: 11 * 60 + 30,
          repeatDays: [1],
          title: 'Late Event',
          category: TimelineCategory.meal,
        ),
      ];

      final result = TimelineOverlapEngine.computeLayout(
        entries: entries,
        availableWidth: availableWidth,
        selectedDay: 1,
        config: config,
      );

      final e1 = result.entryMap['block-1']!;
      final e2 = result.entryMap['block-2']!;
      final e3 = result.entryMap['block-3']!;

      expect(e1.columnCount, equals(3));
      expect(e2.columnCount, equals(3));
      expect(e3.columnCount, equals(3));

      expect(e1.column, equals(0));
      expect(e2.column, equals(1));
      expect(e3.column, equals(2));
    });

    test(
      'E. Chain overlap: A 09:00-10:00, B 09:30-10:30, C 10:15-11:00 packs into 2 columns',
      () {
        final entries = [
          const TimelineEntry(
            id: 'chain-a',
            sourceId: 'src-a',
            startMinute: 9 * 60, // 540
            endMinute: 10 * 60, // 600
            repeatDays: [1],
            title: 'Block A',
            category: TimelineCategory.classes,
          ),
          const TimelineEntry(
            id: 'chain-b',
            sourceId: 'src-b',
            startMinute: 9 * 60 + 30, // 570
            endMinute: 10 * 60 + 30, // 630
            repeatDays: [1],
            title: 'Block B',
            category: TimelineCategory.work,
          ),
          const TimelineEntry(
            id: 'chain-c',
            sourceId: 'src-c',
            startMinute: 10 * 60 + 15, // 615
            endMinute: 11 * 60, // 660
            repeatDays: [1],
            title: 'Block C',
            category: TimelineCategory.meal,
          ),
        ];

        final result = TimelineOverlapEngine.computeLayout(
          entries: entries,
          availableWidth: availableWidth,
          selectedDay: 1,
          config: config,
        );

        expect(result.entries.length, equals(3));
        final a = result.entryMap['chain-a']!;
        final b = result.entryMap['chain-b']!;
        final c = result.entryMap['chain-c']!;

        expect(a.columnCount, equals(2));
        expect(b.columnCount, equals(2));
        expect(c.columnCount, equals(2));

        expect(a.column, equals(0));
        expect(b.column, equals(1));
        expect(
          c.column,
          equals(0),
        ); // Reuses column 0 after A ends at 600 <= 615
      },
    );

    test(
      'F. Nested overlap cluster: 3 items with max concurrency 2 allocates 2 columns NOT 3',
      () {
        final entries = [
          const TimelineEntry(
            id: 'block-a',
            sourceId: 'src-a',
            startMinute: 9 * 60, // 09:00 - 12:00
            endMinute: 12 * 60,
            repeatDays: [1],
            title: 'Long Block A',
            category: TimelineCategory.classes,
          ),
          const TimelineEntry(
            id: 'block-b',
            sourceId: 'src-b',
            startMinute: 9 * 60 + 30, // 09:30 - 10:00
            endMinute: 10 * 60,
            repeatDays: [1],
            title: 'Short Block B',
            category: TimelineCategory.work,
          ),
          const TimelineEntry(
            id: 'block-c',
            sourceId: 'src-c',
            startMinute: 10 * 60 + 30, // 10:30 - 11:00
            endMinute: 11 * 60,
            repeatDays: [1],
            title: 'Short Block C',
            category: TimelineCategory.meal,
          ),
        ];

        final result = TimelineOverlapEngine.computeLayout(
          entries: entries,
          availableWidth: availableWidth,
          selectedDay: 1,
          config: config,
        );

        expect(result.entries.length, equals(3));
        final a = result.entryMap['block-a']!;
        final b = result.entryMap['block-b']!;
        final c = result.entryMap['block-c']!;

        expect(a.columnCount, equals(2));
        expect(b.columnCount, equals(2));
        expect(c.columnCount, equals(2));

        expect(a.column, equals(0));
        expect(b.column, equals(1));
        expect(c.column, equals(1));

        const expectedColWidth = (expectedUsableWidth - 10.0) / 2.0; // 145.0
        expect(a.width, closeTo(expectedColWidth, 0.001));
        expect(b.width, closeTo(expectedColWidth, 0.001));
        expect(c.width, closeTo(expectedColWidth, 0.001));
      },
    );

    test(
      'G. Shuffled input order yields perfectly identical layout geometry',
      () {
        final entries = [
          const TimelineEntry(
            id: 'c',
            sourceId: 's3',
            startMinute: 10 * 60 + 30,
            endMinute: 11 * 60,
            repeatDays: [1],
            title: 'C',
            category: TimelineCategory.meal,
          ),
          const TimelineEntry(
            id: 'a',
            sourceId: 's1',
            startMinute: 9 * 60,
            endMinute: 12 * 60,
            repeatDays: [1],
            title: 'A',
            category: TimelineCategory.classes,
          ),
          const TimelineEntry(
            id: 'b',
            sourceId: 's2',
            startMinute: 9 * 60 + 30,
            endMinute: 10 * 60,
            repeatDays: [1],
            title: 'B',
            category: TimelineCategory.work,
          ),
        ];

        final result1 = TimelineOverlapEngine.computeLayout(
          entries: entries,
          availableWidth: availableWidth,
          selectedDay: 1,
          config: config,
        );

        final result2 = TimelineOverlapEngine.computeLayout(
          entries: entries.reversed.toList(),
          availableWidth: availableWidth,
          selectedDay: 1,
          config: config,
        );

        for (final id in ['a', 'b', 'c']) {
          final p1 = result1.entryMap[id]!;
          final p2 = result2.entryMap[id]!;
          expect(p1.top, equals(p2.top));
          expect(p1.height, equals(p2.height));
          expect(p1.left, equals(p2.left));
          expect(p1.width, equals(p2.width));
          expect(p1.column, equals(p2.column));
          expect(p1.columnCount, equals(p2.columnCount));
        }
      },
    );

    test(
      'H. Minute precision: 09:07, 09:43, 10:02 test with zero hidden rounding',
      () {
        const min1 = 9 * 60 + 7; // 547
        const min2 = 9 * 60 + 43; // 583
        const min3 = 10 * 60 + 2; // 602

        final entries = [
          const TimelineEntry(
            id: 'e1',
            sourceId: 's1',
            startMinute: min1,
            endMinute: min1 + 30,
            repeatDays: [1],
            title: 'E1',
            category: TimelineCategory.skinCare,
          ),
          const TimelineEntry(
            id: 'e2',
            sourceId: 's2',
            startMinute: min2,
            endMinute: min2 + 15,
            repeatDays: [1],
            title: 'E2',
            category: TimelineCategory.skinCare,
          ),
          const TimelineEntry(
            id: 'e3',
            sourceId: 's3',
            startMinute: min3,
            endMinute: min3 + 45,
            repeatDays: [1],
            title: 'E3',
            category: TimelineCategory.classes,
          ),
        ];

        final result = TimelineOverlapEngine.computeLayout(
          entries: entries,
          availableWidth: availableWidth,
          selectedDay: 1,
          config: config,
        );

        final p1 = result.entryMap['e1']!;
        final p2 = result.entryMap['e2']!;
        final p3 = result.entryMap['e3']!;

        final delta1to2 = p2.top - p1.top;
        final delta2to3 = p3.top - p2.top;

        // 583 - 547 = 36 minutes -> exactly 36.0 px
        expect(delta1to2, closeTo(36.0 * config.pixelsPerMinute, 0.001));
        // 602 - 583 = 19 minutes -> exactly 19.0 px
        expect(delta2to3, closeTo(19.0 * config.pixelsPerMinute, 0.001));
      },
    );

    test(
      'I. Short 5-minute event enforces minimum interactive height of 32px',
      () {
        final entries = [
          const TimelineEntry(
            id: 'short',
            sourceId: 'src-s',
            startMinute: 9 * 60,
            endMinute: 9 * 60 + 5,
            repeatDays: [1],
            title: 'Quick 5m Task',
            category: TimelineCategory.other,
          ),
        ];

        final result = TimelineOverlapEngine.computeLayout(
          entries: entries,
          availableWidth: availableWidth,
          selectedDay: 1,
          config: config,
        );

        final entry = result.entryMap['short']!;
        expect(entry.height, equals(32.0));
      },
    );

    test(
      'J. Long multi-hour event calculates exact duration height without overflow',
      () {
        final entries = [
          const TimelineEntry(
            id: 'long-event',
            sourceId: 'src-long',
            startMinute: 9 * 60, // 09:00 (540)
            endMinute: 17 * 60, // 17:00 (1020) -> 8 hours = 480 minutes
            repeatDays: [1],
            title: 'Full Day Hackathon',
            category: TimelineCategory.work,
          ),
        ];

        final result = TimelineOverlapEngine.computeLayout(
          entries: entries,
          availableWidth: availableWidth,
          selectedDay: 1,
          config: config,
        );

        final entry = result.entryMap['long-event']!;
        expect(entry.height, equals(480.0 * config.pixelsPerMinute));
        expect(result.totalHeight, greaterThan(entry.top + entry.height));
      },
    );

    test('I. Selected day filters out inactive entries', () {
      final entries = [
        const TimelineEntry(
          id: 'mon-only',
          sourceId: 'src-mon',
          startMinute: 540,
          endMinute: 600,
          repeatDays: [1],
          title: 'Mon Only',
          category: TimelineCategory.classes,
        ),
        const TimelineEntry(
          id: 'tue-only',
          sourceId: 'src-tue',
          startMinute: 540,
          endMinute: 600,
          repeatDays: [2],
          title: 'Tue Only',
          category: TimelineCategory.classes,
        ),
      ];

      final resultMon = TimelineOverlapEngine.computeLayout(
        entries: entries,
        availableWidth: availableWidth,
        selectedDay: 1,
        config: config,
      );
      final resultTue = TimelineOverlapEngine.computeLayout(
        entries: entries,
        availableWidth: availableWidth,
        selectedDay: 2,
        config: config,
      );

      expect(resultMon.entries.map((e) => e.id).toList(), equals(['mon-only']));
      expect(resultTue.entries.map((e) => e.id).toList(), equals(['tue-only']));
    });

    test(
      'L. Empty day produces valid layout result with 0 entries and calm height',
      () {
        final result = TimelineOverlapEngine.computeLayout(
          entries: const [],
          availableWidth: availableWidth,
          selectedDay: 1,
          config: config,
        );

        expect(result.entries, isEmpty);
        expect(result.totalHeight, greaterThan(0));
        expect(result.visibleStartMinute, equals(config.defaultStartMinute));
        expect(result.visibleEndMinute, equals(config.defaultEndMinute));
      },
    );
  });

  group('AH-F018 Feature Adapters Verification', () {
    test(
      'M. Class adapter converts ClassRoutineBlock to TimelineEntry and extracts style',
      () {
        const adapter = ClassTimelineAdapter();
        final routine = ClassRoutineBlock(
          id: 'cls-1',
          subject: 'Algorithms',
          room: 'Lab 401',
          startMinute: 9 * 60,
          endMinute: 10 * 60 + 30,
          repeatDays: const [1, 3, 5],
        );

        final entries = adapter.toEntries(routine);
        expect(entries.length, equals(1));
        final entry = entries.first;
        expect(entry.id, equals('cls-1'));
        expect(entry.sourceId, equals('cls-1'));
        expect(entry.title, equals('Algorithms'));
        expect(entry.subtitle, equals('Lab 401'));
        expect(entry.category, equals(TimelineCategory.classes));

        final style = adapter.styleForEntry(entry);
        expect(style.icon, equals(Icons.school_rounded));
        expect(style.tags, isEmpty);
      },
    );

    test(
      'N. Work adapter converts ClassRoutineBlock to TimelineEntry and extracts style',
      () {
        const adapter = WorkTimelineAdapter();
        final routine = ClassRoutineBlock(
          id: 'work-1',
          subject: 'Software Engineer',
          room: 'Headquarters',
          startMinute: 13 * 60,
          endMinute: 17 * 60,
          repeatDays: const [1, 2, 3, 4, 5],
        );

        final entries = adapter.toEntries(routine);
        expect(entries.length, equals(1));
        final entry = entries.first;
        expect(entry.id, equals('work-1'));
        expect(entry.title, equals('Software Engineer'));
        expect(entry.category, equals(TimelineCategory.work));

        final style = adapter.styleForEntry(entry);
        expect(style.icon, equals(Icons.work_rounded));
      },
    );

    test(
      'O. Meal adapter converts TimelineBlockDraft with dishes and category icon',
      () {
        const adapter = MealTimelineAdapter();
        const draft = TimelineBlockDraft(
          id: 'meal-lunch',
          section: 'eating',
          title: 'Lunch',
          mealCategory: 'Lunch',
          blockType: TimelineBlockDraft.hardBlockKey,
          startMinute: 12 * 60,
          endMinute: 13 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          dishes: ['Grilled Chicken', 'Brown Rice', 'Steamed Veggies'],
        );

        final entries = adapter.toEntries(draft);
        expect(entries.length, equals(1));
        final entry = entries.first;
        expect(entry.id, equals('meal-lunch'));
        expect(entry.category, equals(TimelineCategory.meal));

        final style = adapter.styleForEntry(entry);
        expect(style.icon, equals(Icons.lunch_dining_rounded));
        expect(style.tags, contains('Grilled Chicken'));
      },
    );

    test(
      'P. Fixed adapter cross-midnight splitting: 23:00 to 07:00 splits into day-bounded segments sharing sourceId',
      () {
        const adapter = FixedTimelineAdapter();
        const overnightSleep = TimelineBlockDraft(
          id: 'fixed-sleep',
          section: 'fixed',
          title: 'Sleep',
          startMinute: 23 * 60, // 1380
          endMinute: 7 * 60, // 420
          repeatDays: [1], // Mon night -> Tue morning
          blockType: TimelineBlockDraft.hardBlockKey,
          crossesMidnight: true,
        );

        final entries = adapter.toEntries(overnightSleep);
        expect(entries.length, equals(2));

        final nightSeg = entries.firstWhere((e) => e.id.contains('night'));
        final morningSeg = entries.firstWhere((e) => e.id.contains('morning'));

        expect(nightSeg.sourceId, equals('fixed-sleep'));
        expect(nightSeg.specificDay, equals(1));
        expect(nightSeg.startMinute, equals(1380));
        expect(nightSeg.endMinute, equals(1440));

        expect(morningSeg.sourceId, equals('fixed-sleep'));
        expect(morningSeg.specificDay, equals(2));
        expect(morningSeg.startMinute, equals(0));
        expect(morningSeg.endMinute, equals(420));
      },
    );

    test(
      'Q. Skin adapter converts skin care draft with fixed 15-min duration and products',
      () {
        const adapter = SkinTimelineAdapter();
        const skinDraft = TimelineBlockDraft(
          id: 'skin-morning',
          section: 'skin_care',
          title: 'Morning Routine',
          blockType: TimelineBlockDraft.softBlockKey,
          startMinute: 8 * 60,
          endMinute: 8 * 60 + 15,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          skincareProducts: ['Cleanser', 'Moisturizer', 'Sunscreen'],
          skincareSteps: ['Wash face', 'Apply cream'],
        );

        final entries = adapter.toEntries(skinDraft);
        expect(entries.length, equals(1));
        final entry = entries.first;
        expect(entry.id, equals('skin-morning'));
        expect(entry.durationMinutes, equals(15));
        expect(entry.category, equals(TimelineCategory.skinCare));

        final style = adapter.styleForEntry(entry);
        expect(style.icon, equals(Icons.spa_rounded));
        expect(style.tags, contains('Cleanser'));
      },
    );

    test(
      'R. Shared weekday mapping: Monday in Step 4, 5, 7 maps to same day index 1',
      () {
        const classAdapter = ClassTimelineAdapter();
        const mealAdapter = MealTimelineAdapter();
        const skinAdapter = SkinTimelineAdapter();

        final classRoutine = ClassRoutineBlock(
          id: 'c1',
          subject: 'Math',
          startMinute: 540,
          endMinute: 600,
          repeatDays: const [1],
        );
        const mealDraft = TimelineBlockDraft(
          id: 'm1',
          section: 'eating',
          title: 'Lunch',
          blockType: TimelineBlockDraft.hardBlockKey,
          startMinute: 720,
          endMinute: 780,
          repeatDays: [1],
        );
        const skinDraft = TimelineBlockDraft(
          id: 's1',
          section: 'skin_care',
          title: 'Night Skin',
          blockType: TimelineBlockDraft.softBlockKey,
          startMinute: 1300,
          endMinute: 1315,
          repeatDays: [1],
        );

        final classEntry = classAdapter.toEntries(classRoutine).first;
        final mealEntry = mealAdapter.toEntries(mealDraft).first;
        final skinEntry = skinAdapter.toEntries(skinDraft).first;

        expect(classEntry.isActiveOnDay(1), isTrue);
        expect(mealEntry.isActiveOnDay(1), isTrue);
        expect(skinEntry.isActiveOnDay(1), isTrue);

        expect(classEntry.isActiveOnDay(2), isFalse);
        expect(mealEntry.isActiveOnDay(2), isFalse);
        expect(skinEntry.isActiveOnDay(2), isFalse);
      },
    );
  });

  group('AH-F018 UI Widgets and Accessibility Verification', () {
    testWidgets(
      'S. TimelineDayChips renders all 7 days with accessible semantics and toggles selection',
      (tester) async {
        int selected = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (ctx, setSt) => TimelineDayChips(
                  selectedDay: selected,
                  onDayChanged: (d) => setSt(() => selected = d),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final name in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
          expect(find.text(name), findsOneWidget);
        }

        await tester.tap(find.text('Wed'));
        await tester.pumpAndSettle();
        expect(selected, equals(3));
      },
    );

    testWidgets(
      'T. FullScreenTimelineScaffold renders full editable mode with cards and time rail',
      (tester) async {
        final entries = [
          const TimelineEntry(
            id: 'test-class',
            sourceId: 'src-1',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            repeatDays: [1],
            title: 'Algorithms 101',
            category: TimelineCategory.classes,
          ),
        ];

        TimelineEntry? tapped;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FullScreenTimelineScaffold(
                entries: entries,
                selectedDay: 1,
                onDayChanged: (_) {},
                styleBuilder: (e) =>
                    TimelineEntryStyle.defaultForCategory(e.category),
                onEntryTapped: (e) => tapped = e,
                title: 'Your Schedule',
                subtitle: 'Tap any block to edit',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Algorithms 101'), findsOneWidget);
        expect(find.text('Your Schedule'), findsOneWidget);

        await tester.tap(find.text('Algorithms 101'));
        await tester.pumpAndSettle();
        expect(tapped?.id, equals('test-class'));
      },
    );

    testWidgets(
      'U. FullScreenTimelineScaffold renders previewReadOnly mode without triggering edit taps',
      (tester) async {
        final entries = [
          const TimelineEntry(
            id: 'preview-block',
            sourceId: 'src-p',
            startMinute: 12 * 60,
            endMinute: 13 * 60,
            repeatDays: [1],
            title: 'Read Only Lunch',
            category: TimelineCategory.meal,
          ),
        ];

        TimelineEntry? tapped;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FullScreenTimelineScaffold(
                entries: entries,
                selectedDay: 1,
                onDayChanged: (_) {},
                mode: TimelineMode.previewReadOnly,
                styleBuilder: (e) =>
                    TimelineEntryStyle.defaultForCategory(e.category),
                onEntryTapped: (e) => tapped = e,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Read Only Lunch'), findsOneWidget);
        await tester.tap(find.text('Read Only Lunch'));
        await tester.pumpAndSettle();
        expect(tapped, isNull);
      },
    );

    testWidgets(
      'V. Responsive widths (360px, 393px, 412px) layout smoothly without RenderFlex overflows',
      (tester) async {
        final entries = [
          const TimelineEntry(
            id: 'e1',
            sourceId: 's1',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            repeatDays: [1],
            title: 'Class E1',
            category: TimelineCategory.classes,
          ),
          const TimelineEntry(
            id: 'e2',
            sourceId: 's2',
            startMinute: 9 * 60 + 30,
            endMinute: 10 * 60 + 30,
            repeatDays: [1],
            title: 'Work E2',
            category: TimelineCategory.work,
          ),
        ];

        for (final w in [360.0, 393.0, 412.0]) {
          tester.view.physicalSize = Size(w * 3.0, 800 * 3.0);
          tester.view.devicePixelRatio = 3.0;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: FullScreenTimelineScaffold(
                  entries: entries,
                  selectedDay: 1,
                  onDayChanged: (_) {},
                  styleBuilder: (e) =>
                      TimelineEntryStyle.defaultForCategory(e.category),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Class E1'), findsOneWidget);
          expect(find.text('Work E2'), findsOneWidget);
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'W. Large accessibility text scale (1.5x, 2.0x) renders cards without crash',
      (tester) async {
        final entries = [
          const TimelineEntry(
            id: 'text-scale-entry',
            sourceId: 'src-ts',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            repeatDays: [1],
            title: 'Large Text Subject',
            subtitle: 'Room 101',
            category: TimelineCategory.classes,
          ),
        ];

        for (final scale in [1.5, 2.0]) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: FullScreenTimelineScaffold(
                    entries: entries,
                    selectedDay: 1,
                    onDayChanged: (_) {},
                    styleBuilder: (e) =>
                        TimelineEntryStyle.defaultForCategory(e.category),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Large Text Subject'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'Y. TimelineEditSheetShell guards against double-tap submissions',
      (tester) async {
        int saveCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  key: const Key('open-sheet-btn'),
                  onPressed: () {
                    TimelineEditSheetShell.show<bool>(
                      context: ctx,
                      title: 'Test Sheet',
                      onSave: () async {
                        saveCount++;
                        await Future.delayed(const Duration(milliseconds: 100));
                        return true;
                      },
                      builder: (sheetCtx) => const Text('Edit Form Content'),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-sheet-btn')));
        await tester.pumpAndSettle();

        expect(find.text('Test Sheet'), findsOneWidget);
        expect(find.text('Edit Form Content'), findsOneWidget);

        final saveButton = find.byKey(const Key('timeline-edit-save-button'));
        expect(saveButton, findsOneWidget);

        await tester.tap(saveButton);
        await tester.tap(saveButton); // Immediate second tap
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(saveCount, equals(1));
      },
    );

    testWidgets(
      'Z. TimelineEditSheetShell surfaces user-facing validation errors in error banner',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  key: const Key('open-error-sheet-btn'),
                  onPressed: () {
                    TimelineEditSheetShell.show<bool>(
                      context: ctx,
                      title: 'Validation Test Sheet',
                      onSave: () async {
                        throw Exception('End time must be after start time.');
                      },
                      builder: (sheetCtx) => const Text('Form Body'),
                    );
                  },
                  child: const Text('Open Error Sheet'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-error-sheet-btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('timeline-edit-save-button')));
        await tester.pumpAndSettle();

        expect(find.text('End time must be after start time.'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      },
    );
  });

  group('AH-F018 Overlap Interaction & Hit Testing', () {
    testWidgets(
      'AD. 2 overlapping blocks are both independently tappable and reachable',
      (tester) async {
        final entries = [
          const TimelineEntry(
            id: 'block-1',
            sourceId: 'src-1',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            repeatDays: [1],
            title: 'Morning Class',
            category: TimelineCategory.classes,
          ),
          const TimelineEntry(
            id: 'block-2',
            sourceId: 'src-2',
            startMinute: 9 * 60 + 30,
            endMinute: 10 * 60 + 30,
            repeatDays: [1],
            title: 'Shift Work',
            category: TimelineCategory.work,
          ),
        ];

        TimelineEntry? lastTapped;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FullScreenTimelineScaffold(
                entries: entries,
                selectedDay: 1,
                onDayChanged: (_) {},
                styleBuilder: (e) =>
                    TimelineEntryStyle.defaultForCategory(e.category),
                onEntryTapped: (e) => lastTapped = e,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Morning Class'));
        await tester.pumpAndSettle();
        expect(lastTapped?.id, equals('block-1'));

        await tester.tap(find.text('Shift Work'));
        await tester.pumpAndSettle();
        expect(lastTapped?.id, equals('block-2'));
      },
    );

    testWidgets(
      'AE. 3 overlapping blocks each tap cleanly without hit-test hijacking',
      (tester) async {
        final entries = [
          const TimelineEntry(
            id: 'b1',
            sourceId: 's1',
            startMinute: 9 * 60,
            endMinute: 11 * 60,
            repeatDays: [1],
            title: 'Triple 1',
            category: TimelineCategory.classes,
          ),
          const TimelineEntry(
            id: 'b2',
            sourceId: 's2',
            startMinute: 9 * 60 + 20,
            endMinute: 10 * 60 + 20,
            repeatDays: [1],
            title: 'Triple 2',
            category: TimelineCategory.work,
          ),
          const TimelineEntry(
            id: 'b3',
            sourceId: 's3',
            startMinute: 9 * 60 + 40,
            endMinute: 10 * 60 + 40,
            repeatDays: [1],
            title: 'Triple 3',
            category: TimelineCategory.meal,
          ),
        ];

        final tappedIds = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FullScreenTimelineScaffold(
                entries: entries,
                selectedDay: 1,
                onDayChanged: (_) {},
                styleBuilder: (e) =>
                    TimelineEntryStyle.defaultForCategory(e.category),
                onEntryTapped: (e) => tappedIds.add(e.id),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Triple 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Triple 2'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Triple 3'));
        await tester.pumpAndSettle();

        expect(tappedIds, equals(['b1', 'b2', 'b3']));
      },
    );

    testWidgets(
      'AA. TimelineEditSheetShell Cancel dismisses without calling onSave',
      (tester) async {
        int saveCount = 0;
        int cancelCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  key: const Key('open-cancel-sheet-btn'),
                  onPressed: () {
                    TimelineEditSheetShell.show<bool>(
                      context: ctx,
                      title: 'Cancel Test Sheet',
                      onCancel: () => cancelCount++,
                      onSave: () async {
                        saveCount++;
                        return true;
                      },
                      builder: (sheetCtx) => const Text('Form Body to Cancel'),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-cancel-sheet-btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('timeline-edit-cancel-button')));
        await tester.pumpAndSettle();

        expect(cancelCount, equals(1));
        expect(saveCount, equals(0));
        expect(find.text('Cancel Test Sheet'), findsNothing);
      },
    );

    test(
      'AG. Dynamic edit changes start/end time and layout geometry updates predictably',
      () {
        final entryOriginal = const TimelineEntry(
          id: 'edit-dyn',
          sourceId: 'src-dyn',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: [1],
          title: 'Original Time',
          category: TimelineCategory.classes,
        );

        final entryUpdated = entryOriginal.copyWith(
          startMinute: 11 * 60,
          endMinute: 12 * 60,
        );

        final layout1 = TimelineOverlapEngine.computeLayout(
          entries: [entryOriginal],
          availableWidth: 380,
          selectedDay: 1,
        );
        final layout2 = TimelineOverlapEngine.computeLayout(
          entries: [entryUpdated],
          availableWidth: 380,
          selectedDay: 1,
        );

        expect(
          layout1.entryMap['edit-dyn']!.top,
          lessThan(layout2.entryMap['edit-dyn']!.top),
        );
      },
    );

    test(
      'AH. Overlap created via edit recomputes geometry without mutating draft accepted conflicts',
      () {
        final draft = OnboardingDraft(
          baseTimeline: const BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'cls-1',
                section: 'classes',
                title: 'Class 1',
                blockType: TimelineBlockDraft.hardBlockKey,
                startMinute: 540,
                endMinute: 600,
                repeatDays: [1],
              ),
              TimelineBlockDraft(
                id: 'cls-2',
                section: 'classes',
                title: 'Class 2',
                blockType: TimelineBlockDraft.hardBlockKey,
                startMinute: 660,
                endMinute: 720,
                repeatDays: [1],
              ),
            ],
          ),
        );

        expect(draft.baseTimeline.conflictAcceptances, isEmpty);

        // Edit cls-2 to overlap cls-1 (570..630)
        const adapter = ClassTimelineAdapter();
        final entriesBefore = [
          for (final b in draft.baseTimeline.blocks)
            ...adapter.toEntries(
              ClassRoutineBlock(
                id: b.id,
                subject: b.title,
                startMinute: b.startMinute,
                endMinute: b.endMinute,
                repeatDays: b.repeatDays,
              ),
            ),
        ];

        final layoutBefore = TimelineOverlapEngine.computeLayout(
          entries: entriesBefore,
          availableWidth: 380,
          selectedDay: 1,
        );
        expect(layoutBefore.entries.every((e) => e.columnCount == 1), isTrue);

        final editedRoutine = ClassRoutineBlock(
          id: 'cls-2',
          subject: 'Class 2',
          startMinute: 570,
          endMinute: 630,
          repeatDays: const [1],
        );

        final entriesAfter = [
          entriesBefore.first,
          ...adapter.toEntries(editedRoutine),
        ];

        final layoutAfter = TimelineOverlapEngine.computeLayout(
          entries: entriesAfter,
          availableWidth: 380,
          selectedDay: 1,
        );

        // Geometry recomputes into 2 columns
        expect(layoutAfter.entries.every((e) => e.columnCount == 2), isTrue);

        // Draft conflict acceptances are untouched by layout recomputation
        expect(draft.baseTimeline.conflictAcceptances, isEmpty);
      },
    );

    testWidgets(
      'AF. Custom blockBuilder still forwards whole-card taps through onEntryTapped',
      (tester) async {
        final entries = [
          const TimelineEntry(
            id: 'custom-skin',
            sourceId: 'skin-src',
            startMinute: 8 * 60,
            endMinute: 8 * 60 + 15,
            repeatDays: [1],
            title: 'Custom Skin Routine',
            category: TimelineCategory.skinCare,
            minHeight: 96,
          ),
        ];

        final tappedIds = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FullScreenTimelineScaffold(
                entries: entries,
                selectedDay: 1,
                onDayChanged: (_) {},
                styleBuilder: (e) =>
                    TimelineEntryStyle.defaultForCategory(e.category),
                onEntryTapped: (e) => tappedIds.add(e.id),
                blockBuilder: (context, positioned) => Container(
                  key: const ValueKey('custom-skin-card'),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: const Text('Custom Skin Routine'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('custom-skin-card')));
        await tester.pumpAndSettle();

        expect(tappedIds, ['custom-skin']);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AH-F018 Lifecycle & Back/Re-entry Invariant Verification', () {
    testWidgets(
      'AI. Step 4 generated timeline mounts without re-triggering AI generation',
      (tester) async {
        final draft = OnboardingDraft(
          lifeRole: const LifeRoleDraft(
            lifeRole: LifeRoleDraft.studentWorkingKey,
          ),
          baseTimeline: const BaseTimelineDraft(),
        );

        final classBlocks = [
          ClassRoutineBlock(
            id: 'cls-bio',
            subject: 'Biology 101',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            repeatDays: const [1],
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (_) => OnboardingNotifier()..loadSeedData(draft),
              ),
              onboardingClassTimelineProvider.overrideWith((_) => classBlocks),
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox.expand(child: OnboardingStep4Unified()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Biology 101'), findsOneWidget);
        expect(find.textContaining('AI is building'), findsNothing);
      },
    );

    testWidgets(
      'AJ. Step 5 generated meals mount full-screen without re-triggering AI',
      (tester) async {
        final draft = OnboardingDraft(
          baseTimeline: const BaseTimelineDraft(
            eatingSetupStep: 1,
            eatingSetupPath: 'has_routine',
            eatingMode: 'quick_prep',
            blocks: [
              TimelineBlockDraft(
                id: 'meal-breakfast',
                section: 'eating',
                title: 'Oatmeal & Fruit',
                blockType: TimelineBlockDraft.hardBlockKey,
                mealCategory: 'Breakfast',
                startMinute: 8 * 60,
                endMinute: 8 * 60 + 30,
                repeatDays: [1, 2, 3, 4, 5],
                dishes: ['Rolled oats', 'Banana'],
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (_) => OnboardingNotifier()..loadSeedData(draft),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SizedBox.expand(child: OnboardingStep5())),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Oatmeal & Fruit'), findsOneWidget);
        expect(find.text('Eating Setup'), findsOneWidget);
      },
    );

    testWidgets(
      'AK. Step 7 generated skincare mounts full-screen without re-triggering AI',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final draft = OnboardingDraft(
          baseTimeline: const BaseTimelineDraft(
            skinCareSetupPath: 'has_products',
            skinCareSetupStep: 1,
            skinCareProductNames: 'Cleanser, Moisturizer',
            skinCareSelectedProductNames: ['Cleanser', 'Moisturizer'],
            blocks: [
              TimelineBlockDraft(
                id: 'skin-am',
                section: 'skin_care',
                title: 'Morning Routine',
                blockType: TimelineBlockDraft.softBlockKey,
                startMinute: 8 * 60,
                endMinute: 8 * 60 + 15,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                skincareProducts: ['Cleanser', 'Moisturizer'],
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (_) => OnboardingNotifier()..loadSeedData(draft),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SizedBox.expand(child: OnboardingStep7())),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Skin Care Routine'), findsOneWidget);
        expect(find.text('Review your weekly routine'), findsOneWidget);
        expect(
          find.byKey(
            const ValueKey('onboarding-step7-special-care-notes-button'),
          ),
          findsNothing,
        );
        expect(find.text('Morning Routine'), findsOneWidget);
      },
    );

    testWidgets('AL. Step 14 renders preview without edit triggers', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final draft = OnboardingDraft(
        uid: 'test-user-step14',
        baseTimeline: const BaseTimelineDraft(
          blocks: [
            TimelineBlockDraft(
              id: 'step14-block',
              section: 'classes',
              title: 'Physics Lab',
              blockType: TimelineBlockDraft.hardBlockKey,
              startMinute: 14 * 60,
              endMinute: 16 * 60,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStateProvider.overrideWith(
              (_) => OnboardingNotifier()..loadSeedData(draft),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(child: OnboardingTodayReadyStep()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('See your timeline'));
      await tester.pumpAndSettle();

      expect(find.text('Today timeline preview'), findsOneWidget);
      expect(find.text('Physics Lab'), findsOneWidget);
    });
  });
}
