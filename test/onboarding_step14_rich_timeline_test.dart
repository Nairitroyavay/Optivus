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

  test('Class colors follow source IDs after completion time reordering', () {
    const classLate = TimelineBlockDraft(
      id: 'class-late',
      section: 'classes',
      title: 'Class Late',
      startMinute: 600,
      endMinute: 660,
      repeatDays: [1, 2],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const classEarly = TimelineBlockDraft(
      id: 'class-early',
      section: 'classes',
      title: 'Class Early',
      startMinute: 480,
      endMinute: 540,
      repeatDays: [1, 2],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const meal = TimelineBlockDraft(
      id: 'meal',
      section: 'eating',
      title: 'Lunch',
      startMinute: 720,
      endMinute: 750,
      repeatDays: [1],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const source = [classLate, classEarly, meal];
    final completionOrder = mergeOverlappingEatingBlocks([...source]);
    expect(
      completionOrder
          .where((block) => block.section == 'classes')
          .map((block) => block.id),
      ['class-early', 'class-late'],
    );

    final items = buildStep14FinalTimelineItems(
      _bundle(completionOrder),
      sourceVisualOrder: Step14SourceVisualOrder.fromBlocks(source),
    );
    final bySourceId = {for (final item in items) item.entry.sourceId: item};
    expect(
      bySourceId['class-late']!.identity.accent,
      ScheduleSetupConfig.classSetup.colorCycle[0],
    );
    expect(
      bySourceId['class-early']!.identity.accent,
      ScheduleSetupConfig.classSetup.colorCycle[1],
    );
    for (final day in [1, 2]) {
      expect(
        items
            .singleWhere(
              (item) =>
                  item.entry.sourceId == 'class-late' &&
                  item.entry.isActiveOnDay(day),
            )
            .identity
            .accent,
        ScheduleSetupConfig.classSetup.colorCycle[0],
      );
    }
  });

  test('Work colors follow source IDs after completion time reordering', () {
    const workLate = TimelineBlockDraft(
      id: 'work-late',
      section: 'job_work_business',
      title: 'Work Late',
      startMinute: 900,
      endMinute: 960,
      repeatDays: [1, 3],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const workEarly = TimelineBlockDraft(
      id: 'work-early',
      section: 'job_work_business',
      title: 'Work Early',
      startMinute: 420,
      endMinute: 480,
      repeatDays: [1, 3],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const meal = TimelineBlockDraft(
      id: 'meal',
      section: 'eating',
      title: 'Lunch',
      startMinute: 720,
      endMinute: 750,
      repeatDays: [1],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const source = [workLate, workEarly, meal];
    final completionOrder = mergeOverlappingEatingBlocks([...source]);
    expect(
      completionOrder
          .where((block) => block.section == 'job_work_business')
          .map((block) => block.id),
      ['work-early', 'work-late'],
    );

    final items = buildStep14FinalTimelineItems(
      _bundle(completionOrder),
      sourceVisualOrder: Step14SourceVisualOrder.fromBlocks(source),
    );
    final bySourceId = {for (final item in items) item.entry.sourceId: item};
    expect(
      bySourceId['work-late']!.identity.accent,
      ScheduleSetupConfig.workSetup.colorCycle[0],
    );
    expect(
      bySourceId['work-early']!.identity.accent,
      ScheduleSetupConfig.workSetup.colorCycle[1],
    );
    for (final day in [1, 3]) {
      expect(
        items
            .singleWhere(
              (item) =>
                  item.entry.sourceId == 'work-late' &&
                  item.entry.isActiveOnDay(day),
            )
            .identity
            .accent,
        ScheduleSetupConfig.workSetup.colorCycle[0],
      );
    }
  });

  test('source visual order matches confirmed Step 4 block eligibility', () {
    const source = [
      TimelineBlockDraft(
        id: 'unconfirmed',
        section: 'classes',
        title: 'Needs Review',
        startMinute: 420,
        endMinute: 480,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
        needsTimeConfirmation: true,
      ),
      TimelineBlockDraft(
        id: 'blank',
        section: 'classes',
        title: '   ',
        startMinute: 480,
        endMinute: 540,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      TimelineBlockDraft(
        id: 'confirmed-a',
        section: 'classes',
        title: 'Confirmed A',
        startMinute: 540,
        endMinute: 600,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      TimelineBlockDraft(
        id: 'confirmed-b',
        section: 'classes',
        title: 'Confirmed B',
        startMinute: 600,
        endMinute: 660,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ];

    final order = Step14SourceVisualOrder.fromBlocks(source);
    expect(order.classOrdinalById, {'confirmed-a': 0, 'confirmed-b': 1});
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

  test('connected overlap components preserve exact atomic active sets', () {
    const entries = [
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
    ];
    final components = buildStep14OverlapComponents(entries, selectedDay: 1);
    final regions = buildStep14OverlapRegions(entries);

    expect(components, hasLength(1));
    expect(components.single.entryIds, ['a', 'b', 'c']);
    expect(
      regions
          .where((region) => region.entryIds.length > 1)
          .map((region) => region.entryIds),
      [
        ['a', 'b'],
        ['b', 'c'],
      ],
    );
  });

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

  testWidgets('partial overlap renders one stable-width rich logical card', (
    tester,
  ) async {
    final key = GlobalKey<Step14FinalTimelineState>();
    final source = [
      const TimelineBlockDraft(
        id: 'long-class',
        section: 'classes',
        title: 'Very Long Data Structures Laboratory With Full Context',
        startMinute: 540,
        endMinute: 660,
        repeatDays: [1],
        location: 'Computer Science Building, Room C302',
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      const TimelineBlockDraft(
        id: 'work',
        section: 'job_work_business',
        title: 'Project Work',
        startMinute: 570,
        endMinute: 600,
        repeatDays: [1],
        location: 'Office',
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Step14FinalTimeline(
            key: key,
            bundle: _bundle(source),
            sourceBlocks: source,
            selectedDay: 1,
            onDayChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final longCard = find.byKey(
      const ValueKey('step14-timeline-card-long-class'),
    );
    expect(longCard, findsOneWidget);
    expect(
      find.byKey(const ValueKey('step14-card-background-long-class')),
      findsOneWidget,
    );
    final prepared = key.currentState!.preparedLayoutForTesting!;
    final positionedInitial = tester.widget<Positioned>(longCard);
    expect(positionedInitial.width, prepared.fullWidth);
    expect(positionedInitial.top, prepared.positionedById['long-class']!.top);
    expect(positionedInitial.height, prepared.positionedById['long-class']!.height);

    // Front card (work) is shifted by gutterWidth and has frontWidth
    final workCard = tester.widget<Positioned>(
      find.byKey(const ValueKey('step14-timeline-card-work')),
    );
    expect(workCard.width, prepared.frontWidth);
    expect(workCard.left, prepared.leftOffset + prepared.gutterWidth);

    // Promoting long-class via back tab brings it to front with rich content
    final longTab = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
                'step14-timeline-back-tab-long-class-',
              ),
    );
    expect(longTab, findsOneWidget);
    await tester.tap(longTab);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: longCard,
        matching: find.text(
          'Very Long Data Structures Laboratory With Full Context',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Computer Science Building, Room C302'), findsOneWidget);
    final positionedAfter = tester.widget<Positioned>(longCard);
    expect(positionedAfter.width, prepared.frontWidth);
    expect(positionedAfter.top, prepared.positionedById['long-class']!.top);
    expect(positionedAfter.height, prepared.positionedById['long-class']!.height);

    expect(
      find.descendant(of: longCard, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('promotion reuses prepared vertical layout and scroll state', (
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
    final key = GlobalKey<Step14FinalTimelineState>();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Step14FinalTimeline(
            key: key,
            bundle: bundle,
            selectedDay: 1,
            onDayChanged: (_) {},
            scrollController: scrollController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('step14-rail-half-570')), findsOneWidget);
    expect(find.byKey(const ValueKey('step14-rail-minor-550')), findsOneWidget);
    expect(find.text('9:10 AM'), findsNothing);
    final preparedBefore = key.currentState!.preparedLayoutForTesting!;
    final cardBefore = tester.widget<Positioned>(
      find.byKey(const ValueKey('step14-timeline-card-work')),
    );
    final railBefore = tester.getTopLeft(
      find.byKey(const ValueKey('step14-rail-hour-540')),
    );
    final totalHeightBefore = preparedBefore.layout.totalHeight;
    final scrollBefore = scrollController.offset;
    final workTab = _backTabsFor('work');
    expect(workTab, findsOneWidget);
    await tester.tap(workTab);
    await tester.pump();

    final preparedAfter = key.currentState!.preparedLayoutForTesting!;
    final cardAfter = tester.widget<Positioned>(
      find.byKey(const ValueKey('step14-timeline-card-work')),
    );
    expect(identical(preparedAfter, preparedBefore), isTrue);
    expect(cardAfter.top, cardBefore.top);
    expect(cardAfter.height, cardBefore.height);
    expect(preparedAfter.layout.totalHeight, totalHeightBefore);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('step14-rail-hour-540'))),
      railBefore,
    );
    expect(scrollController.offset, scrollBefore);
    expect(_backTabsFor('work'), findsNothing);
    expect(_backTabsFor('class'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('component focus follows active atomic regions in a chain', (
    tester,
  ) async {
    final bundle = _bundle(const [
      TimelineBlockDraft(
        id: 'a',
        section: 'classes',
        title: 'A',
        startMinute: 540,
        endMinute: 600,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      TimelineBlockDraft(
        id: 'b',
        section: 'job_work_business',
        title: 'B',
        startMinute: 570,
        endMinute: 630,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      TimelineBlockDraft(
        id: 'c',
        section: 'eating',
        title: 'C',
        startMinute: 615,
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

    expect(_backTabsFor('b'), findsOneWidget);
    await tester.tap(_backTabsFor('b'));
    await tester.pump();
    expect(_backTabsFor('b'), findsNothing);
    expect(_backTabsFor('a'), findsOneWidget);
    expect(_backTabsFor('c'), findsOneWidget);

    await tester.tap(_backTabsFor('a'));
    await tester.pump();
    expect(_backTabsFor('a'), findsNothing);
    expect(_backTabsFor('b'), findsOneWidget);
    expect(_backTabsFor('c'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal category renders only when meaningfully distinct', (
    tester,
  ) async {
    final items = buildStep14FinalTimelineItems(
      _bundle(const [
        TimelineBlockDraft(
          id: 'category-needed',
          section: 'eating',
          title: 'Chicken Rice',
          startMinute: 600,
          endMinute: 630,
          repeatDays: [1],
          blockType: TimelineBlockDraft.hardBlockKey,
          mealCategory: 'Lunch',
        ),
        TimelineBlockDraft(
          id: 'category-is-title',
          section: 'eating',
          title: 'Lunch',
          startMinute: 660,
          endMinute: 690,
          repeatDays: [1],
          blockType: TimelineBlockDraft.hardBlockKey,
          mealCategory: ' lunch ',
        ),
        TimelineBlockDraft(
          id: 'category-is-slot',
          section: 'eating',
          title: 'Vegetable Curry',
          startMinute: 720,
          endMinute: 750,
          repeatDays: [1],
          blockType: TimelineBlockDraft.hardBlockKey,
          mealSlot: 'Lunch',
          mealCategory: 'LUNCH',
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: Column(
            children: [
              for (final item in items)
                Builder(
                  builder: (context) => SizedBox(
                    width: 260,
                    height: Step14FinalTimelineCard.measureHeight(
                      context,
                      260,
                      item,
                    ),
                    child: Step14FinalTimelineCard(item: item),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Chicken Rice'), findsOneWidget);
    expect(find.text('Vegetable Curry'), findsOneWidget);
    expect(find.text('Lunch'), findsNWidgets(3));
    expect(find.text(' lunch '), findsNothing);
    expect(find.text('LUNCH'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('four overlaps remain reachable at 2.5x on a narrow phone', (
    tester,
  ) async {
    final source = [
      const TimelineBlockDraft(
        id: 'class',
        section: 'classes',
        title: 'Advanced Data Structures Class',
        startMinute: 540,
        endMinute: 545,
        repeatDays: [1],
        location: 'Room C302',
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      const TimelineBlockDraft(
        id: 'work',
        section: 'job_work_business',
        title: 'Client Project Work',
        startMinute: 540,
        endMinute: 545,
        repeatDays: [1],
        location: 'Office',
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      const TimelineBlockDraft(
        id: 'meal',
        section: 'eating',
        title: 'Chicken Rice Bowl',
        startMinute: 540,
        endMinute: 545,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
        mealCategory: 'Breakfast',
        calories: 520,
        protein: 28,
        dishes: ['Chicken', 'Rice', 'Vegetables'],
      ),
      TimelineBlockDraft(
        id: 'skin',
        section: 'skin_care',
        title: 'Morning Skin Care Routine',
        startMinute: 540,
        endMinute: 545,
        repeatDays: [1],
        blockType: TimelineBlockDraft.hardBlockKey,
        skincareSteps: ['Cleanse', 'Moisturize'],
        skincareProducts: ['Gentle Cleanser'],
        skincareMissingItems: ['Sunscreen'],
      ),
      const TimelineBlockDraft(
        id: 'late',
        section: 'fixed',
        title: 'Evening Walk',
        startMinute: 1080,
        endMinute: 1140,
        repeatDays: [1],
        blockType: TimelineBlockDraft.softBlockKey,
      ),
    ];
    final key = GlobalKey<Step14FinalTimelineState>();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
          child: Scaffold(
            body: Step14FinalTimeline(
              key: key,
              bundle: _bundle(source),
              sourceBlocks: source,
              selectedDay: 1,
              onDayChanged: (_) {},
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();

    final tabs = _allBackTabs();
    expect(tabs, findsNWidgets(3));
    var hasExpandedTab = false;
    for (final element in tabs.evaluate()) {
      final height = tester.getSize(find.byWidget(element.widget)).height;
      expect(height, greaterThanOrEqualTo(44));
      hasExpandedTab = hasExpandedTab || height > 44;
    }
    expect(hasExpandedTab, isTrue);
    expect(
      find.bySemanticsLabel(RegExp(r'^Show .+ in front, .+$')),
      findsNWidgets(3),
    );
    const overlapIds = {'class', 'work', 'meal', 'skin'};
    bool cardSemanticsExcluded(String id) {
      final excluding = find.byKey(
        ValueKey('step14-timeline-card-semantics-$id'),
      );
      return tester.widget<ExcludeSemantics>(excluding).excluding;
    }

    expect(cardSemanticsExcluded('class'), isFalse);
    expect(cardSemanticsExcluded('work'), isTrue);
    expect(cardSemanticsExcluded('meal'), isTrue);
    expect(cardSemanticsExcluded('skin'), isTrue);

    final prepared = key.currentState!.preparedLayoutForTesting!;
    expect(prepared.frontWidth, greaterThan(0));
    final railLabel = find.text('9 AM');
    expect(railLabel, findsOneWidget);
    expect(
      tester.getSize(railLabel).width,
      lessThanOrEqualTo(prepared.railLabelWidth + 0.1),
    );
    expect(
      tester.getSize(railLabel).height,
      lessThanOrEqualTo(prepared.railLabelHeight + 0.1),
    );
    expect(find.text('Chicken', skipOffstage: false), findsOneWidget);
    expect(find.text('Rice', skipOffstage: false), findsOneWidget);
    expect(find.text('Vegetables', skipOffstage: false), findsOneWidget);
    expect(find.text('1. Cleanse', skipOffstage: false), findsOneWidget);
    expect(find.text('2. Moisturize', skipOffstage: false), findsOneWidget);
    expect(find.text('Gentle Cleanser', skipOffstage: false), findsOneWidget);
    expect(find.text('⚠ Sunscreen', skipOffstage: false), findsOneWidget);

    scrollController.jumpTo(20);
    await tester.pump();
    final scrollBefore = scrollController.offset;
    final railBefore = tester.getTopLeft(
      find.byKey(const ValueKey('step14-rail-hour-540')),
    );
    final totalHeightBefore = prepared.layout.totalHeight;
    for (final id in ['work', 'meal', 'skin', 'class']) {
      final tab = _backTabsFor(id);
      expect(tab, findsOneWidget);
      await tester.tap(tab);
      await tester.pump();
      expect(_backTabsFor(id), findsNothing);
      expect(_allBackTabs(), findsNWidgets(3));
      expect(
        _paintedFrontCardId(tester, const {'class', 'work', 'meal', 'skin'}),
        id,
      );
      for (final candidateId in overlapIds) {
        expect(cardSemanticsExcluded(candidateId), candidateId != id);
      }
      expect(
        identical(key.currentState!.preparedLayoutForTesting, prepared),
        isTrue,
      );
      expect(
        key.currentState!.preparedLayoutForTesting!.layout.totalHeight,
        totalHeightBefore,
      );
      expect(scrollController.offset, scrollBefore);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('step14-rail-hour-540'))),
        railBefore,
      );
    }
    expect(find.textContaining('more'), findsNothing);
    expect(find.text('View full details'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Finder _allBackTabs() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith(
        'step14-timeline-back-tab-',
      ),
);

Finder _backTabsFor(String id) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith(
        'step14-timeline-back-tab-$id-',
      ),
);

String _paintedFrontCardId(WidgetTester tester, Set<String> candidateIds) {
  final stackFinder = find.byWidgetPredicate(
    (widget) =>
        widget is Stack &&
        widget.children.any(
          (child) =>
              child.key is ValueKey<String> &&
              (child.key! as ValueKey<String>).value.startsWith(
                'step14-timeline-card-',
              ),
        ),
  );
  final stack = tester.widget<Stack>(stackFinder);
  final cardKeys = stack.children
      .map((child) => child.key)
      .whereType<ValueKey<String>>()
      .map((key) => key.value)
      .where((value) => value.startsWith('step14-timeline-card-'))
      .where(
        (value) => candidateIds.contains(
          value.substring('step14-timeline-card-'.length),
        ),
      )
      .toList();
  return cardKeys.last.substring('step14-timeline-card-'.length);
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
