import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_entry_filter.dart';
import 'package:optivus/features/routine/sheets/routine_filter_sheet.dart';
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

    testWidgets('RoutineFilterSheet staged edits apply only on confirmation', (
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

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FilterTestNotifier(
                ref,
                initialItems: [testItem],
                initialSelectedDay: DateTime(2026, 9, 14),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  capturedRef = ref;
                  return ElevatedButton(
                    onPressed: () => showRoutineFilterSheet(context, ref),
                    child: const Text('Open Filters'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Filter Routine'), findsOneWidget);
      expect(find.text('VIEW'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('CATEGORY'), findsOneWidget);

      // Staged state starts as all / any / all
      expect(
        capturedRef.read(routineNotifierProvider).selectedPrimaryFilter,
        'all',
      );

      // Tap 'Flexible Tasks' chip in the sheet
      await tester.tap(find.text('Flexible Tasks'));
      await tester.pumpAndSettle();

      // State is NOT yet modified before Apply
      expect(
        capturedRef.read(routineNotifierProvider).selectedPrimaryFilter,
        'all',
      );

      // Tap 'Done' status chip
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Since item is planned, 0 items match -> button says 'Show 0 routines'
      expect(find.text('Show 0 routines'), findsOneWidget);

      // Tap 'Reset' button
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      // Now 1 item matches again -> button says 'Show 1 routine'
      expect(find.text('Show 1 routine'), findsOneWidget);

      // Tap 'Flexible Tasks' again
      await tester.tap(find.text('Flexible Tasks'));
      await tester.pumpAndSettle();

      // Apply button
      await tester.tap(find.text('Show 1 routine'));
      await tester.pumpAndSettle();

      // Sheet popped
      expect(find.text('Filter Routine'), findsNothing);

      // Now state IS updated!
      expect(
        capturedRef.read(routineNotifierProvider).selectedPrimaryFilter,
        'flexible_tasks',
      );
    });
  });
}
