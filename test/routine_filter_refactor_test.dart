import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/models/routine_week_day_summary.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_entry_filter.dart';
import 'package:optivus/features/routine/widgets/routine_title_filter_row.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

RoutineItem _createTestItem({
  required String id,
  required String title,
  required int startMinute,
  required int endMinute,
  RoutineBlockType blockType = RoutineBlockType.flexibleTask,
  RoutineCategory category = RoutineCategory.fixed,
  RoutineStatus status = RoutineStatus.planned,
  RoutineSource source = RoutineSource.manual,
  bool isTrackerLinked = false,
  bool isCompleted = false,
  bool isMissed = false,
  List<int> repeatDays = const [1],
  String? baseTimelineSection,
}) {
  return RoutineItem(
    id: id,
    userId: 'user_filter_test',
    title: title,
    startMinute: startMinute,
    endMinute: endMinute,
    blockType: blockType,
    category: category,
    status: status,
    source: source,
    isTrackerLinked: isTrackerLinked,
    isCompleted: isCompleted,
    isMissed: isMissed,
    repeatDays: repeatDays,
    repeatRule: repeatDays.isNotEmpty ? 'weekly' : 'once',
    baseTimelineSection: baseTimelineSection,
  );
}

RoutineDayEntry _createDayEntry(
  RoutineItem item, {
  String dateKey = '2026-09-14',
}) {
  return RoutineDayEntry(
    item: item,
    instanceId: 'inst_${item.id}',
    templateId: item.id,
    occurrenceDateKey: dateKey,
    displayDateKey: dateKey,
    kind: RoutineDayEntryKind.scheduled,
  );
}

class _FilterTestNotifier extends RoutineNotifier {
  _FilterTestNotifier(
    Ref ref, {
    List<RoutineItem> initialItems = const [],
    List<RoutineOccurrenceRecord> initialOccurrences = const [],
    DateTime? initialSelectedDay,
    String primaryFilter = 'all',
    String statusFilter = 'any',
    String categoryFilter = 'all',
  }) : super(
         FakeRoutineRepository(),
         FakeRoutineHistoryRepository(),
         FakeRoutineTransactionRepository(),
         ref,
       ) {
    state = state.copyWith(
      items: initialItems,
      occurrences: initialOccurrences,
      selectedDay: initialSelectedDay ?? DateTime(2026, 9, 14),
      selectedPrimaryFilter: primaryFilter,
      selectedStatusFilter: statusFilter,
      selectedCategoryFilter: categoryFilter,
      loading: false,
    );
  }

  @override
  Future<void> loadForOwner(String uid, {bool force = false}) async {
    state = state.copyWith(loading: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoutineEntryFilter Pure Service Logic', () {
    final baseItem = _createTestItem(
      id: 'hb1',
      title: 'Math Class',
      startMinute: 540,
      endMinute: 660,
      blockType: RoutineBlockType.hardBlock,
      category: RoutineCategory.classBlock,
      source: RoutineSource.baseTimeline,
      status: RoutineStatus.planned,
    );

    final flexItem = _createTestItem(
      id: 'flex1',
      title: 'Read Book',
      startMinute: 700,
      endMinute: 760,
      blockType: RoutineBlockType.flexibleTask,
      category: RoutineCategory.habit,
      status: RoutineStatus.completed,
    );

    final trackerItem = _createTestItem(
      id: 'track1',
      title: 'Gym Workout',
      startMinute: 800,
      endMinute: 860,
      blockType: RoutineBlockType.trackerTask,
      category: RoutineCategory.health,
      status: RoutineStatus.missed,
    );

    final checkInItem = _createTestItem(
      id: 'check1',
      title: 'Hydration Check',
      startMinute: 900,
      endMinute: 915,
      blockType: RoutineBlockType.checkIn,
      category: RoutineCategory.hydration,
      status: RoutineStatus.planned,
    );

    final entries = [
      _createDayEntry(baseItem),
      _createDayEntry(flexItem),
      _createDayEntry(trackerItem),
      _createDayEntry(checkInItem),
    ];

    test('1. View filter matches correct block types and sources', () {
      // all
      final all = RoutineEntryFilter.apply(
        entries,
        view: 'all',
        status: 'any',
        category: 'all',
      );
      expect(all.length, 4);

      // base_timeline
      final base = RoutineEntryFilter.apply(
        entries,
        view: 'base_timeline',
        status: 'any',
        category: 'all',
      );
      expect(base.length, 1);
      expect(base.first.item.id, 'hb1');

      // flexible_tasks
      final flex = RoutineEntryFilter.apply(
        entries,
        view: 'flexible_tasks',
        status: 'any',
        category: 'all',
      );
      expect(flex.length, 1);
      expect(flex.first.item.id, 'flex1');

      // tracker_tasks
      final tracker = RoutineEntryFilter.apply(
        entries,
        view: 'tracker_tasks',
        status: 'any',
        category: 'all',
      );
      expect(tracker.length, 1);
      expect(tracker.first.item.id, 'track1');

      // check_ins
      final checkIns = RoutineEntryFilter.apply(
        entries,
        view: 'check_ins',
        status: 'any',
        category: 'all',
      );
      expect(checkIns.length, 1);
      expect(checkIns.first.item.id, 'check1');

      // invalid key safely falls back to all
      final invalid = RoutineEntryFilter.apply(
        entries,
        view: 'unknown_view_key',
        status: 'any',
        category: 'all',
      );
      expect(invalid.length, 4);
    });

    test('2. Status filter matches todo, done, missed', () {
      // any
      final any = RoutineEntryFilter.apply(
        entries,
        view: 'all',
        status: 'any',
        category: 'all',
      );
      expect(any.length, 4);

      // todo (planned/active, not completed or missed)
      final todo = RoutineEntryFilter.apply(
        entries,
        view: 'all',
        status: 'todo',
        category: 'all',
      );
      expect(todo.length, 2);
      expect(todo.map((e) => e.item.id), containsAll(['hb1', 'check1']));

      // done
      final done = RoutineEntryFilter.apply(
        entries,
        view: 'all',
        status: 'done',
        category: 'all',
      );
      expect(done.length, 1);
      expect(done.first.item.id, 'flex1');

      // missed
      final missed = RoutineEntryFilter.apply(
        entries,
        view: 'all',
        status: 'missed',
        category: 'all',
      );
      expect(missed.length, 1);
      expect(missed.first.item.id, 'track1');

      // invalid key safely falls back to any
      final invalid = RoutineEntryFilter.apply(
        entries,
        view: 'all',
        status: 'invalid_status',
        category: 'all',
      );
      expect(invalid.length, 4);
    });

    test('3. Dynamic categories extract available categories from entries', () {
      final options = RoutineEntryFilter.dynamicCategoryOptions(entries);

      // Should extract matching categories ('classes', 'good_habits', 'hydration')
      final optionKeys = options.map((o) => o.key).toSet();
      expect(optionKeys, containsAll(['classes', 'good_habits', 'hydration']));

      // Filter by 'classes'
      final classEntries = RoutineEntryFilter.apply(
        entries,
        view: 'all',
        status: 'any',
        category: 'classes',
      );
      expect(classEntries.length, 1);
      expect(classEntries.first.item.id, 'hb1');
    });

    test(
      '4. Option A Health and Focus category filtering matches correctly',
      () {
        final healthItem = _createTestItem(
          id: 'hlth1',
          title: 'Vitamins & Health',
          startMinute: 480,
          endMinute: 500,
          category: RoutineCategory.health,
        );
        final focusItem = _createTestItem(
          id: 'foc1',
          title: 'Deep Coding',
          startMinute: 600,
          endMinute: 720,
          category: RoutineCategory.focus,
        );

        final testEntries = [
          _createDayEntry(healthItem),
          _createDayEntry(focusItem),
        ];

        final healthMatches = RoutineEntryFilter.apply(
          testEntries,
          view: 'all',
          status: 'any',
          category: 'health',
        );
        expect(healthMatches.length, 1);
        expect(healthMatches.first.item.id, 'hlth1');

        final focusMatches = RoutineEntryFilter.apply(
          testEntries,
          view: 'all',
          status: 'any',
          category: 'focus',
        );
        expect(focusMatches.length, 1);
        expect(focusMatches.first.item.id, 'foc1');
      },
    );
  });

  group('RoutineState Filter Methods & Providers', () {
    test(
      '1. setPrimaryFilter, setStatusFilter, setCategoryFilter update state safely',
      () {
        final container = ProviderContainer(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(ref),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(routineNotifierProvider.notifier);

        // Defaults
        var state = container.read(routineNotifierProvider);
        expect(state.selectedPrimaryFilter, 'all');
        expect(state.selectedStatusFilter, 'any');
        expect(state.selectedCategoryFilter, 'all');

        // Valid updates
        notifier.setPrimaryFilter('flexible_tasks');
        expect(
          container.read(routineNotifierProvider).selectedPrimaryFilter,
          'flexible_tasks',
        );

        notifier.setStatusFilter('done');
        expect(
          container.read(routineNotifierProvider).selectedStatusFilter,
          'done',
        );

        notifier.setCategoryFilter('classes');
        expect(
          container.read(routineNotifierProvider).selectedCategoryFilter,
          'classes',
        );

        // Invalid fallbacks
        notifier.setPrimaryFilter('invalid_foo');
        expect(
          container.read(routineNotifierProvider).selectedPrimaryFilter,
          'all',
        );

        notifier.setStatusFilter('invalid_bar');
        expect(
          container.read(routineNotifierProvider).selectedStatusFilter,
          'any',
        );

        notifier.setCategoryFilter('invalid_baz');
        expect(
          container.read(routineNotifierProvider).selectedCategoryFilter,
          'all',
        );
      },
    );

    test(
      '2. updateSelectedDay auto-resets unavailable category filter to all',
      () {
        final mondayItem = _createTestItem(
          id: 'm1',
          title: 'Work',
          startMinute: 540,
          endMinute: 660,
          category: RoutineCategory.job,
          repeatDays: const [1], // Monday only
        );

        final tuesdayItem = _createTestItem(
          id: 't1',
          title: 'Gym',
          startMinute: 600,
          endMinute: 720,
          category: RoutineCategory.health,
          repeatDays: const [2], // Tuesday only
        );

        final container = ProviderContainer(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(
                ref,
                initialItems: [mondayItem, tuesdayItem],
                initialSelectedDay: DateTime(2026, 9, 14), // Monday
                categoryFilter: 'job',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(routineNotifierProvider.notifier);

        expect(
          container.read(routineNotifierProvider).selectedCategoryFilter,
          'job',
        );

        // Move to Tuesday where 'job' does not exist
        notifier.updateSelectedDay(DateTime(2026, 9, 15));

        // Category filter should auto-reset to 'all'
        expect(
          container.read(routineNotifierProvider).selectedCategoryFilter,
          'all',
        );
      },
    );

    test('3. filteredRoutineEntriesProvider reflects combined filters', () {
      final item1 = _createTestItem(
        id: '1',
        title: 'Work Project',
        startMinute: 540,
        endMinute: 600,
        blockType: RoutineBlockType.flexibleTask,
        category: RoutineCategory.job,
        status: RoutineStatus.completed,
      );
      final item2 = _createTestItem(
        id: '2',
        title: 'Work Call',
        startMinute: 660,
        endMinute: 720,
        blockType: RoutineBlockType.flexibleTask,
        category: RoutineCategory.job,
        status: RoutineStatus.planned,
      );

      final occ1 = RoutineOccurrenceRecord(
        id: 'occ_1',
        ownerUid: 'user_filter_test',
        routineItemId: '1',
        occurrenceDateKey: '2026-09-14',
        status: RoutineStatus.completed,
        source: 'routine',
        action: 'complete',
        operationKey: 'op_1',
        createdAt: DateTime(2026, 9, 14),
        updatedAt: DateTime(2026, 9, 14),
      );

      final container = ProviderContainer(
        overrides: [
          routineNotifierProvider.overrideWith(
            (ref) => _FilterTestNotifier(
              ref,
              initialItems: [item1, item2],
              initialOccurrences: [occ1],
              initialSelectedDay: DateTime(2026, 9, 14),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(routineNotifierProvider.notifier);

      // Initially both show
      var filtered = container.read(filteredRoutineEntriesProvider);
      expect(filtered.length, 2);

      // Filter by done status
      notifier.setStatusFilter('done');
      filtered = container.read(filteredRoutineEntriesProvider);
      expect(filtered.length, 1);
      expect(filtered.first.item.id, '1');
    });

    test(
      '4. Same-day item deletion auto-resets unavailable category filter to all',
      () {
        final jobItem = _createTestItem(
          id: 'j1',
          title: 'Work Shift',
          startMinute: 540,
          endMinute: 660,
          category: RoutineCategory.job,
          repeatDays: const [1],
        );

        final container = ProviderContainer(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(
                ref,
                initialItems: [jobItem],
                initialSelectedDay: DateTime(2026, 9, 14),
                categoryFilter: 'job',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(
          container.read(routineNotifierProvider).selectedCategoryFilter,
          'job',
        );

        // Now mutate state items by removing jobItem
        container.read(routineNotifierProvider.notifier).state = container
            .read(routineNotifierProvider)
            .copyWith(items: const []);

        // Category filter should auto-reset to 'all' because job is no longer present!
        expect(
          container.read(routineNotifierProvider).selectedCategoryFilter,
          'all',
        );
      },
    );

    test(
      '8. Canonical Base Timeline classification provenance and section rules',
      () {
        // RoutineSource.baseTimeline + class -> Base true
        final base1 = _createTestItem(
          id: 'b1',
          title: 'Class',
          startMinute: 600,
          endMinute: 660,
          source: RoutineSource.baseTimeline,
          category: RoutineCategory.classBlock,
        );
        expect(RoutineEntryFilter.isBaseTimeline(base1), isTrue);

        // baseTimelineSection = eating + soft block -> Base true
        final base2 = _createTestItem(
          id: 'b2',
          title: 'Lunch',
          startMinute: 720,
          endMinute: 780,
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
        ).copyWith(baseTimelineSection: 'eating');
        expect(RoutineEntryFilter.isBaseTimeline(base2), isTrue);

        // legacy onboarding class -> Base true
        final obClass = _createTestItem(
          id: 'ob1',
          title: 'Math',
          startMinute: 500,
          endMinute: 560,
          source: RoutineSource.onboarding,
          category: RoutineCategory.classBlock,
        );
        expect(RoutineEntryFilter.isBaseTimeline(obClass), isTrue);

        // legacy onboarding work -> Base true
        final obWork = _createTestItem(
          id: 'ob2',
          title: 'Job',
          startMinute: 600,
          endMinute: 700,
          source: RoutineSource.onboarding,
          category: RoutineCategory.job,
        );
        expect(RoutineEntryFilter.isBaseTimeline(obWork), isTrue);

        // legacy onboarding eating -> Base true
        final obEat = _createTestItem(
          id: 'ob3',
          title: 'Dinner',
          startMinute: 1100,
          endMinute: 1160,
          source: RoutineSource.onboarding,
          category: RoutineCategory.eating,
        );
        expect(RoutineEntryFilter.isBaseTimeline(obEat), isTrue);

        // legacy onboarding fixed/sleep -> Base true
        final obSleep = _createTestItem(
          id: 'ob4',
          title: 'Sleep',
          startMinute: 1300,
          endMinute: 420,
          source: RoutineSource.onboarding,
          category: RoutineCategory.sleep,
        );
        expect(RoutineEntryFilter.isBaseTimeline(obSleep), isTrue);

        // legacy onboarding skin care -> Base true
        final obSkin = _createTestItem(
          id: 'ob5',
          title: 'Skincare',
          startMinute: 450,
          endMinute: 480,
          source: RoutineSource.onboarding,
          category: RoutineCategory.skinCare,
        );
        expect(RoutineEntryFilter.isBaseTimeline(obSkin), isTrue);

        // manual hard appointment -> Base false (NOT base timeline owned!)
        final manualAppt = _createTestItem(
          id: 'm1',
          title: 'Dentist Appointment',
          startMinute: 800,
          endMinute: 860,
          blockType: RoutineBlockType.hardBlock,
          source: RoutineSource.manual,
          category: RoutineCategory.health,
        );
        expect(RoutineEntryFilter.isBaseTimeline(manualAppt), isFalse);

        // imported hard event -> Base false
        final importedHard = _createTestItem(
          id: 'imp1',
          title: 'Flight',
          startMinute: 600,
          endMinute: 780,
          blockType: RoutineBlockType.hardBlock,
          source: RoutineSource.imported,
        );
        expect(RoutineEntryFilter.isBaseTimeline(importedHard), isFalse);

        // manual sleep with no Base provenance -> Base false
        final manualSleep = _createTestItem(
          id: 'ms1',
          title: 'Sleep',
          startMinute: 1320,
          endMinute: 420,
          blockType: RoutineBlockType.hardBlock,
          source: RoutineSource.manual,
          category: RoutineCategory.sleep,
        );
        expect(RoutineEntryFilter.isBaseTimeline(manualSleep), isFalse);
      },
    );

    test(
      '9. Cross-contract check: Week Planner baseBlockCount matches View -> Base',
      () {
        final baseItem = _createTestItem(
          id: 'b1',
          title: 'Class',
          startMinute: 500,
          endMinute: 600,
          source: RoutineSource.baseTimeline,
          baseTimelineSection: 'classes',
        );
        final manualHard = _createTestItem(
          id: 'm1',
          title: 'Dentist',
          startMinute: 700,
          endMinute: 760,
          blockType: RoutineBlockType.hardBlock,
          source: RoutineSource.manual,
        );
        final flexItem = _createTestItem(
          id: 'f1',
          title: 'Workout',
          startMinute: 800,
          endMinute: 860,
          blockType: RoutineBlockType.flexibleTask,
        );
        final entries = [
          _createDayEntry(baseItem),
          _createDayEntry(manualHard),
          _createDayEntry(flexItem),
        ];

        final summary = RoutineWeekDaySummary.fromEntries(
          day: DateTime(2026, 9, 14),
          entries: entries,
        );

        final matchingBaseEntries = RoutineEntryFilter.apply(
          entries,
          view: 'base_timeline',
        );

        expect(summary.baseBlockCount, 1);
        expect(matchingBaseEntries.length, 1);
        expect(summary.baseBlockCount, matchingBaseEntries.length);
      },
    );
  });

  group('RoutineTitleFilterRow & RoutineFilterSheet Widget Tests', () {
    testWidgets('RoutineTitleFilterRow displays compact count badges', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          routineNotifierProvider.overrideWith(
            (ref) => _FilterTestNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: RoutineTitleFilterRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 0 filters active -> 'Filter'
      expect(find.text('Filter'), findsOneWidget);

      // 1 filter active -> 'Filter • 1'
      container
          .read(routineNotifierProvider.notifier)
          .setPrimaryFilter('flexible_tasks');
      await tester.pumpAndSettle();
      expect(find.text('Filter • 1'), findsOneWidget);

      // 2 filters active -> 'Filter • 2'
      container.read(routineNotifierProvider.notifier).setStatusFilter('done');
      await tester.pumpAndSettle();
      expect(find.text('Filter • 2'), findsOneWidget);

      // 3 filters active -> 'Filter • 3'
      container
          .read(routineNotifierProvider.notifier)
          .setCategoryFilter('classes');
      await tester.pumpAndSettle();
      expect(find.text('Filter • 3'), findsOneWidget);
    });

    testWidgets('RoutineTitleFilterRow does not overflow on 320 px screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          routineNotifierProvider.overrideWith(
            (ref) => _FilterTestNotifier(
              ref,
              primaryFilter: 'flexible_tasks',
              statusFilter: 'done',
              categoryFilter: 'classes',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: RoutineTitleFilterRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Filter • 3'), findsOneWidget);
    });

    testWidgets(
      'Tapping Filter opens anchored glass overlay, not bottom sheet',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(ref),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: RoutineTitleFilterRow()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Filter pill
        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle();

        // Anchored dropdown content is visible
        expect(find.text('FILTER ROUTINE'), findsOneWidget);
        expect(find.text('VIEW'), findsOneWidget);
        expect(find.text('STATUS'), findsOneWidget);
        expect(find.text('CATEGORY'), findsOneWidget);

        // No modal bottom sheet or draggable scrollable sheet exists
        expect(find.byType(DraggableScrollableSheet), findsNothing);
      },
    );

    testWidgets(
      'Dropdown selections apply immediately and dropdown remains open',
      (tester) async {
        final testItem = _createTestItem(
          id: 'item_1',
          title: 'Task A',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.classBlock,
          status: RoutineStatus.planned,
        );

        final container = ProviderContainer(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(
                ref,
                initialItems: [testItem],
                initialSelectedDay: DateTime(2026, 9, 14),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: RoutineTitleFilterRow()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open dropdown
        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle();

        expect(find.text('FILTER ROUTINE'), findsOneWidget);

        // 1. Select 'Flexible Tasks'
        await tester.tap(find.text('Flexible Tasks'));
        await tester.pumpAndSettle();

        // Applied immediately in Riverpod state!
        expect(
          container.read(routineNotifierProvider).selectedPrimaryFilter,
          'flexible_tasks',
        );
        // Dropdown remains open!
        expect(find.text('FILTER ROUTINE'), findsOneWidget);
        // Pill text updated immediately to Filter • 1
        expect(find.text('Filter • 1'), findsOneWidget);

        // 2. Select 'Done' status
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Applied immediately!
        expect(
          container.read(routineNotifierProvider).selectedStatusFilter,
          'done',
        );
        // Dropdown remains open!
        expect(find.text('FILTER ROUTINE'), findsOneWidget);
        // Pill text updated to Filter • 2
        expect(find.text('Filter • 2'), findsOneWidget);

        // 3. Select 'Classes' category (which exists on this day)
        await tester.ensureVisible(find.text('Classes'));
        await tester.tap(find.text('Classes'));
        await tester.pumpAndSettle();

        // Applied immediately!
        expect(
          container.read(routineNotifierProvider).selectedCategoryFilter,
          'classes',
        );
        // Dropdown remains open!
        expect(find.text('FILTER ROUTINE'), findsOneWidget);
        // Pill text updated to Filter • 3
        expect(find.text('Filter • 3'), findsOneWidget);
      },
    );

    testWidgets('Reset filters immediately resets all 3 filter axes', (
      tester,
    ) async {
      final testItem = _createTestItem(
        id: 'item_1',
        title: 'Task A',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
        category: RoutineCategory.classBlock,
        status: RoutineStatus.planned,
      );

      final container = ProviderContainer(
        overrides: [
          routineNotifierProvider.overrideWith(
            (ref) => _FilterTestNotifier(
              ref,
              initialItems: [testItem],
              primaryFilter: 'flexible_tasks',
              statusFilter: 'done',
              categoryFilter: 'classes',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: RoutineTitleFilterRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Opens with activeCount == 3
      expect(find.text('Filter • 3'), findsOneWidget);

      // Open dropdown
      await tester.tap(find.text('Filter • 3'));
      await tester.pumpAndSettle();

      // 'Reset filters' action is displayed
      expect(find.text('Reset filters'), findsOneWidget);

      // Tap Reset filters
      await tester.ensureVisible(find.text('Reset filters'));
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();

      // All 3 filters reset immediately
      final state = container.read(routineNotifierProvider);
      expect(state.selectedPrimaryFilter, 'all');
      expect(state.selectedStatusFilter, 'any');
      expect(state.selectedCategoryFilter, 'all');

      // Pill text resets to 'Filter'
      expect(find.text('Filter'), findsOneWidget);
    });

    testWidgets('Outside tap closes the dropdown', (tester) async {
      final container = ProviderContainer(
        overrides: [
          routineNotifierProvider.overrideWith(
            (ref) => _FilterTestNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: RoutineTitleFilterRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dropdown
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      expect(find.text('FILTER ROUTINE'), findsOneWidget);

      // Tap outside (e.g. at (10, 10))
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dropdown closed
      expect(find.text('FILTER ROUTINE'), findsNothing);
    });

    testWidgets('Second tap on Filter pill toggles close', (tester) async {
      final container = ProviderContainer(
        overrides: [
          routineNotifierProvider.overrideWith(
            (ref) => _FilterTestNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: RoutineTitleFilterRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1st tap opens
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('FILTER ROUTINE'), findsOneWidget);

      // 2nd tap closes (scrim or pill tap closes)
      await tester.tap(find.text('Filter'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('FILTER ROUTINE'), findsNothing);
    });

    testWidgets(
      'Category collapses to 5 with +N more and auto-expands when selected category is past collapsed limit',
      (tester) async {
        final items = [
          _createTestItem(
            id: '1',
            title: 'Class',
            startMinute: 500,
            endMinute: 550,
            category: RoutineCategory.classBlock,
          ),
          _createTestItem(
            id: '2',
            title: 'Job',
            startMinute: 560,
            endMinute: 600,
            category: RoutineCategory.job,
          ),
          _createTestItem(
            id: '3',
            title: 'Eat',
            startMinute: 610,
            endMinute: 650,
            category: RoutineCategory.eating,
          ),
          _createTestItem(
            id: '4',
            title: 'Fixed',
            startMinute: 660,
            endMinute: 700,
            category: RoutineCategory.fixed,
          ),
          _createTestItem(
            id: '5',
            title: 'Skin',
            startMinute: 710,
            endMinute: 750,
            category: RoutineCategory.skinCare,
          ),
          _createTestItem(
            id: '6',
            title: 'Habit',
            startMinute: 760,
            endMinute: 800,
            category: RoutineCategory.habit,
          ),
          _createTestItem(
            id: '7',
            title: 'Finance',
            startMinute: 810,
            endMinute: 850,
            category: RoutineCategory.finance,
          ),
        ];

        // Case A: Opened without category selected -> collapses and shows '+2 more'
        final container = ProviderContainer(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(
                ref,
                initialItems: items,
                initialSelectedDay: DateTime(2026, 9, 14),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: RoutineTitleFilterRow()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle();

        expect(find.text('+2 more'), findsOneWidget);

        // Tap '+2 more' to expand
        await tester.ensureVisible(find.text('+2 more'));
        await tester.tap(find.text('+2 more'));
        await tester.pumpAndSettle();

        expect(find.text('Show less'), findsOneWidget);
        expect(find.text('Good Habits'), findsOneWidget);
        expect(find.text('Money System'), findsOneWidget);

        // Close dropdown
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Case B: Opened when 6th category ('good_habits') is already selected -> auto-expands
        container
            .read(routineNotifierProvider.notifier)
            .setCategoryFilter('good_habits');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Filter • 1'));
        await tester.pumpAndSettle();

        // Must auto-expand so selected category 'Good Habits' is visible!
        expect(find.text('Good Habits'), findsOneWidget);
      },
    );

    testWidgets('Large text scale (1.5x) does not cause RenderFlex overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(
        () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
      );

      final container = ProviderContainer(
        overrides: [
          routineNotifierProvider.overrideWith(
            (ref) => _FilterTestNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: RoutineTitleFilterRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('FILTER ROUTINE'), findsOneWidget);
    });

    testWidgets('Disposing with open dropdown causes no leaks or errors', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          routineNotifierProvider.overrideWith(
            (ref) => _FilterTestNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: RoutineTitleFilterRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dropdown
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('FILTER ROUTINE'), findsOneWidget);

      // Now navigate away or replace widget
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: Text('Replaced'))),
        ),
      );
      await tester.pumpAndSettle();

      // No exceptions thrown, overlay cleanly cleaned up
      expect(tester.takeException(), isNull);
      expect(find.text('FILTER ROUTINE'), findsNothing);
      expect(find.text('Replaced'), findsOneWidget);
    });

    testWidgets(
      'Static glass shell invariant: BackdropFilter is never scaled or transformed',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(ref),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: RoutineTitleFilterRow()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle();

        // Dropdown is open
        expect(find.text('FILTER ROUTINE'), findsOneWidget);

        // Find the CompositedTransformFollower for the dropdown
        final dropdownFollower = find.byType(CompositedTransformFollower).last;

        // Invariant: No ScaleTransition wraps the BackdropFilter or dropdown
        expect(
          find.descendant(
            of: dropdownFollower,
            matching: find.byType(ScaleTransition),
          ),
          findsNothing,
        );

        // Invariant: No AnimatedScale wraps the BackdropFilter or dropdown
        expect(
          find.descendant(
            of: dropdownFollower,
            matching: find.byType(AnimatedScale),
          ),
          findsNothing,
        );

        // Invariant: No SlideTransition wraps the BackdropFilter or dropdown
        expect(
          find.descendant(
            of: dropdownFollower,
            matching: find.byType(SlideTransition),
          ),
          findsNothing,
        );

        // Chevron uses synchronized RotationTransition
        expect(
          find.descendant(
            of: find.byType(RoutineTitleFilterRow),
            matching: find.byType(RotationTransition),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Frame-by-frame open: post-frame start, monotonic foreground animation, stable anchor',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(ref),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: RoutineTitleFilterRow()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Filter
        await tester.tap(find.text('Filter'));
        // Frame 0: pump initial frame where overlay is inserted
        await tester.pump();

        // Overlay entry is inserted
        final followerFinder = find.byType(CompositedTransformFollower);
        expect(followerFinder, findsAtLeastNWidgets(2)); // proxy + dropdown

        // Capture initial position of the glass shell
        final initialRect = tester.getRect(find.byType(BackdropFilter).last);

        // Foreground opacity at frame 0 is 0.0
        final opacityFinder = find.descendant(
          of: find.byType(BackdropFilter).last,
          matching: find.byType(Opacity),
        );
        expect(opacityFinder, findsOneWidget);
        expect(tester.widget<Opacity>(opacityFinder).opacity, 0.0);

        // Step forward in time: 16ms
        await tester.pump(const Duration(milliseconds: 16));
        final opacity16 = tester.widget<Opacity>(opacityFinder).opacity;
        expect(opacity16, greaterThanOrEqualTo(0.0));

        // Step forward: 32ms
        await tester.pump(const Duration(milliseconds: 32));
        final opacity48 = tester.widget<Opacity>(opacityFinder).opacity;
        expect(opacity48, greaterThan(opacity16));

        // Step forward: 64ms
        await tester.pump(const Duration(milliseconds: 64));
        final opacity112 = tester.widget<Opacity>(opacityFinder).opacity;
        expect(opacity112, greaterThan(opacity48));

        // Assert that the glass shell geometry remained completely static throughout
        final midRect = tester.getRect(find.byType(BackdropFilter).last);
        expect(midRect.top, initialRect.top);
        expect(midRect.right, initialRect.right);
        expect(midRect.size, initialRect.size);

        // Settle animation
        await tester.pumpAndSettle();
        final finalOpacity = tester.widget<Opacity>(opacityFinder).opacity;
        expect(finalOpacity, 1.0);

        final finalRect = tester.getRect(find.byType(BackdropFilter).last);
        expect(finalRect.top, initialRect.top);
        expect(finalRect.right, initialRect.right);
        expect(finalRect.size, initialRect.size);
      },
    );

    testWidgets(
      'Frame-by-frame close: overlay remains mounted during exit and unmounts only when dismissed',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(ref),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: RoutineTitleFilterRow()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open and settle
        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle();
        expect(find.text('FILTER ROUTINE'), findsOneWidget);

        final initialRect = tester.getRect(find.byType(BackdropFilter).last);

        // Tap scrim outside to close
        await tester.tapAt(const Offset(10, 10));
        await tester.pump(); // Start closing

        final opacityFinder = find.descendant(
          of: find.byType(BackdropFilter).last,
          matching: find.byType(Opacity),
        );
        expect(opacityFinder, findsOneWidget);

        // Midway through exit animation (e.g. 40ms into 120ms exit)
        await tester.pump(const Duration(milliseconds: 40));
        // Overlay must still be mounted
        expect(find.text('FILTER ROUTINE'), findsOneWidget);
        final opacity40 = tester.widget<Opacity>(opacityFinder).opacity;
        expect(opacity40, lessThan(1.0));
        expect(opacity40, greaterThan(0.0));

        // Glass geometry must remain identical
        final midRect = tester.getRect(find.byType(BackdropFilter).last);
        expect(midRect.top, initialRect.top);
        expect(midRect.right, initialRect.right);
        expect(midRect.size, initialRect.size);

        // Another 40ms
        await tester.pump(const Duration(milliseconds: 40));
        expect(find.text('FILTER ROUTINE'), findsOneWidget);
        final opacity80 = tester.widget<Opacity>(opacityFinder).opacity;
        expect(opacity80, lessThan(opacity40));

        // Settle to dismissed
        await tester.pumpAndSettle();
        // Now overlay is removed
        expect(find.text('FILTER ROUTINE'), findsNothing);
      },
    );

    testWidgets(
      'Rapid toggles during in-flight animation reverse smoothly without duplicate OverlayEntry',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(ref),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: RoutineTitleFilterRow()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Open
        await tester.tap(find.text('Filter'));
        await tester.pump(); // Frame 0: Overlay insert & post-frame schedule
        await tester.pump(); // Frame 1: Ticker start
        await tester.pump(
          const Duration(milliseconds: 40),
        ); // Frame 2: In-flight animation (40ms)

        // Exactly one dropdown content exists
        expect(find.text('FILTER ROUTINE'), findsOneWidget);

        // 2. Early close while opening
        await tester.tap(find.text('Filter'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('FILTER ROUTINE'), findsOneWidget);

        // 3. Re-open while closing
        await tester.tap(find.text('Filter'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('FILTER ROUTINE'), findsOneWidget);

        // 4. Settle open
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('FILTER ROUTINE'), findsOneWidget);

        // 5. Clean close
        await tester.tap(find.text('Filter'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text('FILTER ROUTINE'), findsNothing);
      },
    );

    testWidgets(
      'Reduced motion opens and closes immediately without animation delays',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(ref),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: true),
                child: Scaffold(body: RoutineTitleFilterRow()),
              ),
            ),
          ),
        );
        await tester.pump();

        // Tap to open
        await tester.tap(find.text('Filter'));
        await tester.pump();

        // Immediately open without pumpAndSettle
        expect(find.text('FILTER ROUTINE'), findsOneWidget);

        // Tap to close
        await tester.tap(find.text('Filter'), warnIfMissed: false);
        await tester.pump();

        // Immediately closed without pumpAndSettle
        expect(find.text('FILTER ROUTINE'), findsNothing);
      },
    );
  });
}
