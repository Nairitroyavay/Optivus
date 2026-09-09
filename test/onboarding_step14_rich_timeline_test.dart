import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_14_today_ready.dart';
import 'package:optivus/features/onboarding/timeline/layout/timeline_overlap_engine.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/step14_final_timeline.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('full timeline initial day follows the current weekday', () {
    expect(step14InitialTimelineDay(DateTime(2026, 9, 9)), DateTime.wednesday);
    expect(step14InitialTimelineDay(DateTime(2026, 9, 13)), DateTime.sunday);
  });

  test('Class and Work identities reuse Step 4 canonical color cycles', () {
    const classBlock = TimelineBlockDraft(
      id: 'class',
      section: 'classes',
      title: 'Class',
      startMinute: 540,
      endMinute: 600,
      repeatDays: [1],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const workBlock = TimelineBlockDraft(
      id: 'work',
      section: 'job_work_business',
      title: 'Work',
      startMinute: 540,
      endMinute: 600,
      repeatDays: [1],
      blockType: TimelineBlockDraft.hardBlockKey,
    );

    for (var index = 0; index < 7; index++) {
      expect(
        Step14TimelineVisualIdentity.resolve(
          classBlock,
          classOrdinal: index,
          workOrdinal: 0,
        ).accent,
        ScheduleSetupConfig.classSetup.colorCycle[index %
            ScheduleSetupConfig.classSetup.colorCycle.length],
      );
      expect(
        Step14TimelineVisualIdentity.resolve(
          workBlock,
          classOrdinal: 0,
          workOrdinal: index,
        ).accent,
        ScheduleSetupConfig.workSetup.colorCycle[index %
            ScheduleSetupConfig.workSetup.colorCycle.length],
      );
    }
  });

  test(
    'constraint stretch uses maximum deficiency for identical intervals',
    () {
      final layout = TimelineOverlapEngine.computeLayout(
        entries: const [
          TimelineEntry(
            id: 'a',
            sourceId: 'a',
            startMinute: 540,
            endMinute: 555,
            repeatDays: [1],
            title: 'A',
            category: TimelineCategory.classes,
            minHeight: 180,
          ),
          TimelineEntry(
            id: 'b',
            sourceId: 'b',
            startMinute: 540,
            endMinute: 555,
            repeatDays: [1],
            title: 'B',
            category: TimelineCategory.work,
            minHeight: 260,
          ),
        ],
        availableWidth: 390,
        selectedDay: 1,
        config: const TimelineGeometryConfig(pixelsPerMinute: 1),
        stretchPolicy: TimelineStretchPolicy.constraintBased,
        visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
      );

      final height = layout.scale.heightForRange(540, 555);
      expect(height, closeTo(260, 0.1));
      expect(height, lessThan(300));
    },
  );

  test('constraint stretch keeps touching short tasks separate', () {
    final layout = TimelineOverlapEngine.computeLayout(
      entries: const [
        TimelineEntry(
          id: 'a',
          sourceId: 'a',
          startMinute: 420,
          endMinute: 425,
          repeatDays: [1],
          title: 'Medicine',
          category: TimelineCategory.fixed,
          minHeight: 80,
        ),
        TimelineEntry(
          id: 'b',
          sourceId: 'b',
          startMinute: 425,
          endMinute: 430,
          repeatDays: [1],
          title: 'Water',
          category: TimelineCategory.fixed,
          minHeight: 80,
        ),
        TimelineEntry(
          id: 'c',
          sourceId: 'c',
          startMinute: 430,
          endMinute: 435,
          repeatDays: [1],
          title: 'Journal',
          category: TimelineCategory.fixed,
          minHeight: 80,
        ),
      ],
      availableWidth: 390,
      selectedDay: 1,
      config: const TimelineGeometryConfig(pixelsPerMinute: 1),
      stretchPolicy: TimelineStretchPolicy.constraintBased,
      visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
    );
    final a = layout.entryMap['a']!;
    final b = layout.entryMap['b']!;
    final c = layout.entryMap['c']!;
    expect(b.top, closeTo(a.bottom, 0.1));
    expect(c.top, closeTo(b.bottom, 0.1));
    expect([a.columnCount, b.columnCount, c.columnCount], everyElement(1));
  });

  test('partially overlapping height constraints are both satisfied', () {
    final layout = TimelineOverlapEngine.computeLayout(
      entries: const [
        TimelineEntry(
          id: 'a',
          sourceId: 'a',
          startMinute: 540,
          endMinute: 555,
          repeatDays: [1],
          title: 'A',
          category: TimelineCategory.classes,
          minHeight: 180,
        ),
        TimelineEntry(
          id: 'b',
          sourceId: 'b',
          startMinute: 545,
          endMinute: 560,
          repeatDays: [1],
          title: 'B',
          category: TimelineCategory.work,
          minHeight: 220,
        ),
      ],
      availableWidth: 390,
      selectedDay: 1,
      config: const TimelineGeometryConfig(pixelsPerMinute: 1),
      stretchPolicy: TimelineStretchPolicy.constraintBased,
      visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
    );
    expect(layout.scale.heightForRange(540, 555), greaterThanOrEqualTo(179.9));
    expect(layout.scale.heightForRange(545, 560), greaterThanOrEqualTo(219.9));
    expect(layout.scale.minuteForY(layout.scale.yForMinute(557)), 557);
  });

  test('adaptive range rounds with padding and keeps a three-hour minimum', () {
    final broad = TimelineOverlapEngine.computeLayout(
      entries: const [
        TimelineEntry(
          id: 'early',
          sourceId: 'early',
          startMinute: 8 * 60 + 17,
          endMinute: 9 * 60,
          repeatDays: [1],
          title: 'Early',
          category: TimelineCategory.classes,
        ),
        TimelineEntry(
          id: 'late',
          sourceId: 'late',
          startMinute: 18 * 60,
          endMinute: 18 * 60 + 42,
          repeatDays: [1],
          title: 'Late',
          category: TimelineCategory.work,
        ),
      ],
      availableWidth: 390,
      selectedDay: 1,
      visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
    );
    expect(broad.visibleStartMinute, 7 * 60 + 30);
    expect(broad.visibleEndMinute, 19 * 60 + 30);

    final short = TimelineOverlapEngine.computeLayout(
      entries: const [
        TimelineEntry(
          id: 'short',
          sourceId: 'short',
          startMinute: 600,
          endMinute: 605,
          repeatDays: [1],
          title: 'Medicine',
          category: TimelineCategory.fixed,
        ),
      ],
      availableWidth: 390,
      selectedDay: 1,
      visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
    );
    expect(short.visibleEndMinute - short.visibleStartMinute, 180);
  });

  test(
    'atomic overlap regions do not turn a chain into one global overlap',
    () {
      final regions = buildStep14OverlapRegions(const [
        TimelineEntry(
          id: 'a',
          sourceId: 'a',
          startMinute: 540,
          endMinute: 600,
          repeatDays: [1],
          title: 'A',
          category: TimelineCategory.classes,
        ),
        TimelineEntry(
          id: 'b',
          sourceId: 'b',
          startMinute: 570,
          endMinute: 630,
          repeatDays: [1],
          title: 'B',
          category: TimelineCategory.work,
        ),
        TimelineEntry(
          id: 'c',
          sourceId: 'c',
          startMinute: 615,
          endMinute: 660,
          repeatDays: [1],
          title: 'C',
          category: TimelineCategory.meal,
        ),
      ]);

      expect(
        regions
            .where((region) => region.entryIds.length > 1)
            .map((region) => region.entryIds),
        containsAll(<List<String>>[
          ['a', 'b'],
          ['b', 'c'],
        ]),
      );
      expect(
        regions.any(
          (region) =>
              region.entryIds.contains('a') && region.entryIds.contains('c'),
        ),
        isFalse,
      );
    },
  );

  test(
    'cross-midnight projection keeps one source identity and continuation',
    () {
      final bundle = _bundle(const [
        TimelineBlockDraft(
          id: 'sleep',
          section: 'fixed',
          title: 'Sleep',
          startMinute: 23 * 60 + 30,
          endMinute: 7 * 60,
          repeatDays: [1],
          blockType: TimelineBlockDraft.hardBlockKey,
          crossesMidnight: true,
          endsNextDay: true,
        ),
      ]);
      final items = buildStep14FinalTimelineItems(bundle);
      expect(items, hasLength(2));
      expect(items.map((item) => item.entry.sourceId).toSet(), {'sleep'});
      expect(items.first.entry.specificDay, 1);
      expect(items.last.entry.specificDay, 2);
      expect(items.first.continuation, Step14Continuation.continuesTomorrow);
      expect(
        items.last.continuation,
        Step14Continuation.continuedFromYesterday,
      );
      expect(items.first.identity.accent, items.last.identity.accent);
    },
  );

  testWidgets('rich Meal and Skin cards render every canonical detail', (
    tester,
  ) async {
    const meal = TimelineBlockDraft(
      id: 'meal',
      section: 'eating',
      title: 'Breakfast',
      startMinute: 480,
      endMinute: 485,
      repeatDays: [1],
      blockType: TimelineBlockDraft.hardBlockKey,
      calories: 520,
      protein: 28,
      dishes: [
        'Eggs',
        'Oats',
        'Banana',
        'Milk',
        'Peanut Butter',
        'Bread',
        'Berries',
        'Yogurt',
        'Seeds',
        'Honey',
      ],
    );
    const skin = TimelineBlockDraft(
      id: 'skin',
      section: 'skin_care',
      title: 'Night Skin Care',
      startMinute: 1260,
      endMinute: 1275,
      repeatDays: [1],
      blockType: TimelineBlockDraft.hardBlockKey,
      skincareSteps: ['Cleanse', 'Niacinamide', 'Retinol', 'Moisturize'],
      skincareProducts: ['CeraVe Cleanser', 'Retinol Serum'],
      skincareMissingItems: ['Sunscreen', 'Lip balm'],
    );
    final items = buildStep14FinalTimelineItems(_bundle(const [meal, skin]));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final item in items)
                  Builder(
                    builder: (context) => SizedBox(
                      width: 220,
                      height: Step14FinalTimelineCard.measureHeight(
                        context,
                        220,
                        item,
                      ),
                      child: Step14FinalTimelineCard(item: item),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final text in [
      ...meal.dishes,
      ...skin.skincareProducts,
      '520 kcal • 28g protein',
      'STEPS',
      'PRODUCTS',
      'MISSING',
    ]) {
      expect(find.textContaining(text), findsOneWidget);
    }
    for (var index = 0; index < skin.skincareSteps.length; index++) {
      expect(
        find.text('${index + 1}. ${skin.skincareSteps[index]}'),
        findsOneWidget,
      );
    }
    for (final missing in skin.skincareMissingItems) {
      expect(find.text('⚠ $missing'), findsOneWidget);
    }
    expect(find.textContaining('more'), findsNothing);
    expect(find.text('View full details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposed overlap tab promotes without changing rail geometry', (
    tester,
  ) async {
    final bundle = _bundle(const [
      TimelineBlockDraft(
        id: 'class',
        section: 'classes',
        title: 'Class',
        startMinute: 540,
        endMinute: 600,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      TimelineBlockDraft(
        id: 'work',
        section: 'job_work_business',
        title: 'Work',
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
    expect(find.byKey(const ValueKey('step14-rail-half-570')), findsOneWidget);
    expect(find.byKey(const ValueKey('step14-rail-minor-550')), findsOneWidget);
    expect(find.text('9:10 AM'), findsNothing);
    final railBefore = tester.getTopLeft(
      find.byKey(const ValueKey('step14-rail-hour-540')),
    );
    final workTab = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'step14-timeline-back-tab-work-',
          ),
    );
    expect(workTab, findsOneWidget);
    await tester.tap(workTab);
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'step14-timeline-front-work-',
            ),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('step14-rail-hour-540'))),
      railBefore,
    );
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('four overlaps expose three independent 44px promotion tabs', (
    tester,
  ) async {
    final bundle = _bundle(const [
      TimelineBlockDraft(
        id: 'class',
        section: 'classes',
        title: 'Class',
        startMinute: 540,
        endMinute: 545,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      TimelineBlockDraft(
        id: 'work',
        section: 'job_work_business',
        title: 'Work',
        startMinute: 540,
        endMinute: 545,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      TimelineBlockDraft(
        id: 'meal',
        section: 'eating',
        title: 'Meal',
        startMinute: 540,
        endMinute: 545,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      TimelineBlockDraft(
        id: 'skin',
        section: 'skin_care',
        title: 'Skin Care',
        startMinute: 540,
        endMinute: 545,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
        skincareSteps: ['Cleanse'],
      ),
    ]);

    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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

    final tabs = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'step14-timeline-back-tab-',
          ),
    );
    expect(tabs, findsNWidgets(3));
    for (final element in tabs.evaluate()) {
      expect(tester.getSize(find.byWidget(element.widget)).height, 44);
    }
    expect(find.textContaining('more'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

OnboardingCompletionBundle _bundle(List<TimelineBlockDraft> blocks) {
  final now = DateTime(2026, 9, 9);
  return OnboardingCompletionBundle(
    uid: 'step14-test',
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
