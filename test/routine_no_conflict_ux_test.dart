import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/routine_tab.dart';
import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/features/routine/sheets/add_routine_sheet.dart';
import 'package:optivus/features/routine/sheets/ai_assistant_sheet.dart';
import 'package:optivus/features/routine/sheets/routine_move_sheet.dart';
import 'package:optivus/features/routine/sheets/week_planner_sheet.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/flexible_task_card.dart';
import 'package:optivus/features/routine/widgets/cards/hard_block_card.dart';
import 'package:optivus/features/routine/widgets/cards/soft_block_card.dart';
import 'package:optivus/features/routine/widgets/cards/tracker_task_card.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/repositories/conflict_acceptance_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

class _ThrowingConflictAcceptanceRepository
    implements ConflictAcceptanceRepository {
  int fetchCallCount = 0;
  int upsertCallCount = 0;

  @override
  Future<List<ConflictAcceptance>> fetchForOwner(String uid) async {
    fetchCallCount++;
    throw StateError(
      'ConflictAcceptanceRepository must NEVER be called by Routine loading!',
    );
  }

  @override
  Future<void> upsert(String uid, ConflictAcceptance acceptance) async {
    upsertCallCount++;
    throw StateError(
      'ConflictAcceptanceRepository must NEVER be called by Routine!',
    );
  }
}

const _ownerUid = 'local-development-user';

class _FakeNotifier extends RoutineNotifier {
  _FakeNotifier(Ref ref, {List<RoutineItem> initialItems = const []})
    : super(
        FakeRoutineRepository(),
        FakeRoutineHistoryRepository(),
        FakeRoutineTransactionRepository(),
        ref,
      ) {
    state = state.copyWith(
      items: initialItems,
      selectedDay: DateTime(2026, 7, 27),
    );
  }

  @override
  Future<RoutineWriteResult> addItem(RoutineItem item) async {
    state = state.copyWith(items: [...state.items, item]);
    return RoutineWriteResult.saved(
      operationId: 'op-${item.id}',
      message: 'Item saved',
    );
  }

  @override
  Future<RoutineWriteResult> moveItem({
    required String itemId,
    required DateTime date,
    required int startMinute,
    required int durationMinutes,
  }) async {
    final updated = state.items.map((i) {
      if (i.id == itemId) {
        return i.copyWith(
          date: date,
          startMinute: startMinute,
          endMinute: (startMinute + durationMinutes) % 1440,
        );
      }
      return i;
    }).toList();
    state = state.copyWith(items: updated);
    return RoutineWriteResult.saved(
      operationId: 'op-$itemId',
      message: 'Item moved',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final monday = DateTime(2026, 7, 27);

  group('A-I: RoutineValidationService Overlap Permissiveness', () {
    test('A: Simultaneous hard blocks (Class 9-11 + Work 10-12) are valid', () {
      final classItem = RoutineItem(
        id: 'class_1',
        title: 'Math 101',
        startMinute: 9 * 60,
        endMinute: 11 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.classBlock,
      );
      final workItem = RoutineItem(
        id: 'work_1',
        title: 'Office Work',
        startMinute: 10 * 60,
        endMinute: 12 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.job,
      );

      final result = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: workItem,
          existingTemplates: [classItem],
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('B: Hard block + meal (Class 9-11 + Eating 9:30-9:45) is valid', () {
      final classItem = RoutineItem(
        id: 'class_1',
        title: 'Lecture',
        startMinute: 9 * 60,
        endMinute: 11 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.classBlock,
      );
      final meal = RoutineItem(
        id: 'snack_1',
        title: 'Quick Snack',
        startMinute: 9 * 60 + 30,
        endMinute: 9 * 60 + 45,
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
      );

      final result = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: meal,
          existingTemplates: [classItem],
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('C: Flexible task + hard block is valid', () {
      final hardBlock = RoutineItem(
        id: 'hard_1',
        title: 'Focus Block',
        startMinute: 14 * 60,
        endMinute: 16 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.fixed,
      );
      final task = RoutineItem(
        id: 'flex_1',
        title: 'Send Email',
        startMinute: 14 * 60 + 30,
        endMinute: 15 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.flexibleTask,
        category: RoutineCategory.habit,
      );

      final result = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: task,
          existingTemplates: [hardBlock],
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('D: Two flexible tasks at the same time are valid', () {
      final task1 = RoutineItem(
        id: 'task_1',
        title: 'Task A',
        startMinute: 15 * 60,
        endMinute: 16 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.flexibleTask,
      );
      final task2 = RoutineItem(
        id: 'task_2',
        title: 'Task B',
        startMinute: 15 * 60,
        endMinute: 16 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.flexibleTask,
      );

      final result = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: task2,
          existingTemplates: [task1],
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('E: Tracker task overlapping a class or fixed block is valid', () {
      final classBlock = RoutineItem(
        id: 'class_1',
        title: 'Lecture',
        startMinute: 10 * 60,
        endMinute: 11 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.classBlock,
      );
      final tracker = RoutineItem(
        id: 'tracker_1',
        title: 'Hydration Tracker',
        startMinute: 10 * 60 + 15,
        endMinute: 10 * 60 + 30,
        repeatDays: const [1],
        blockType: RoutineBlockType.trackerTask,
        trackerType: TrackerType.hydration,
      );

      final result = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: tracker,
          existingTemplates: [classBlock],
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('F: Skin care overlapping a meal is valid', () {
      final meal = RoutineItem(
        id: 'meal_1',
        title: 'Breakfast',
        startMinute: 8 * 60,
        endMinute: 8 * 60 + 30,
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
      );
      final skincare = RoutineItem(
        id: 'skin_1',
        title: 'Morning Routine',
        startMinute: 8 * 60 + 15,
        endMinute: 8 * 60 + 45,
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.skinCare,
      );

      final result = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: skincare,
          existingTemplates: [meal],
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('G: Sleep overlapping any other item is valid', () {
      final sleep = RoutineItem(
        id: 'sleep_1',
        title: 'Sleep',
        startMinute: 22 * 60,
        endMinute: 6 * 60,
        crossesMidnight: true,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.sleep,
      );
      final reading = RoutineItem(
        id: 'read_1',
        title: 'Night Reading',
        startMinute: 22 * 60 + 30,
        endMinute: 23 * 60 + 30,
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.habit,
      );

      final result = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: reading,
          existingTemplates: [sleep],
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('H: 3 or more items overlapping at the same time are valid', () {
      final item1 = RoutineItem(
        id: 'item_1',
        title: 'Class',
        startMinute: 10 * 60,
        endMinute: 12 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.classBlock,
      );
      final item2 = RoutineItem(
        id: 'item_2',
        title: 'Snack',
        startMinute: 10 * 60 + 30,
        endMinute: 11 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
      );
      final item3 = RoutineItem(
        id: 'item_3',
        title: 'Habit',
        startMinute: 10 * 60 + 45,
        endMinute: 11 * 60 + 15,
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.habit,
      );

      final result = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: item3,
          existingTemplates: [item1, item2],
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('I: Identical start and end times for 2+ items are valid', () {
      final item1 = RoutineItem(
        id: 'item_1',
        title: 'Work Session',
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.job,
      );
      final item2 = RoutineItem(
        id: 'item_2',
        title: 'Podcast',
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.habit,
      );

      final result = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: item2,
          existingTemplates: [item1],
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('J: Intrinsic validation invariants remain strictly enforced', () {
      // Empty title is invalid
      final emptyTitle = RoutineItem(
        id: 'bad_title',
        title: '   ',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.softBlock,
      );
      final r1 = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: emptyTitle,
          existingTemplates: const [],
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );
      expect(r1.isValid, isFalse);
      expect(r1.userSafeMessage?.toLowerCase(), contains('title'));

      // Start == End is invalid
      final equalTime = RoutineItem(
        id: 'bad_time',
        title: 'Zero Length',
        startMinute: 600,
        endMinute: 600,
        blockType: RoutineBlockType.softBlock,
      );
      final r2 = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: equalTime,
          existingTemplates: const [],
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );
      expect(r2.isValid, isFalse);

      // Max 6 meals cap is enforced
      final existing6Meals = List.generate(
        6,
        (i) => RoutineItem(
          id: 'meal_$i',
          title: 'Meal $i',
          startMinute: 300 + i * 100,
          endMinute: 350 + i * 100,
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
        ),
      );
      final seventhMeal = RoutineItem(
        id: 'meal_7',
        title: 'Meal 7',
        startMinute: 950,
        endMinute: 1000,
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
      );
      final r3 = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: seventhMeal,
          existingTemplates: existing6Meals,
          occurrences: const [],
          evaluationDate: monday,
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: _ownerUid,
        ),
      );
      expect(r3.isValid, isFalse);
      expect(r3.userSafeMessage, contains('6 meals'));
    });
  });

  group('K: Routine Cards Have Zero Conflict Styling or Badges', () {
    testWidgets('HardBlockCard renders without Conflict badge', (tester) async {
      final item = RoutineItem(
        id: 'hard_1',
        title: 'Deep Work',
        startMinute: 540,
        endMinute: 600,
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.job,
        hasConflict: true, // legacy property, should be ignored
        conflictMessage: 'Conflict message',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HardBlockCard(item: item)),
        ),
      );

      expect(find.text('Conflict'), findsNothing);
      expect(find.text('Conflict message'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.text('Deep Work'), findsOneWidget);
    });

    testWidgets('SoftBlockCard renders without Conflict badge', (tester) async {
      final item = RoutineItem(
        id: 'soft_1',
        title: 'Morning Snack',
        startMinute: 600,
        endMinute: 630,
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SoftBlockCard(item: item)),
        ),
      );

      expect(find.text('Conflict'), findsNothing);
      expect(find.text('Morning Snack'), findsOneWidget);
    });

    testWidgets('FlexibleTaskCard renders without Conflict badge', (
      tester,
    ) async {
      final item = RoutineItem(
        id: 'flex_1',
        title: 'Review PRs',
        startMinute: 660,
        endMinute: 720,
        blockType: RoutineBlockType.flexibleTask,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FlexibleTaskCard(item: item)),
        ),
      );

      expect(find.text('Conflict'), findsNothing);
      expect(find.text('Review PRs'), findsOneWidget);
    });

    testWidgets('TrackerTaskCard renders without Conflict badge', (
      tester,
    ) async {
      final item = RoutineItem(
        id: 'track_1',
        title: 'Water Log',
        startMinute: 720,
        endMinute: 750,
        blockType: RoutineBlockType.trackerTask,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackerTaskCard(item: item)),
        ),
      );

      expect(find.text('Conflict'), findsNothing);
      expect(find.text('Water Log'), findsOneWidget);
    });
  });

  group('M: AddRoutineSheet Saves Overlapping Items Without Conflict Box', () {
    testWidgets(
      'Save button is enabled and no conflict box appears when overlapping existing item',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final existingItem = RoutineItem(
          id: 'exist_1',
          title: 'Existing Hard Block',
          startMinute: 9 * 60, // 09:00
          endMinute: 11 * 60, // 11:00
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineNotifierProvider.overrideWith(
                (ref) => _FakeNotifier(ref, initialItems: [existingItem]),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    return ElevatedButton(
                      onPressed: () => showAddRoutineSheet(context, ref),
                      child: const Text('Open Add Sheet'),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Add Sheet'));
        await tester.pumpAndSettle();

        // Tap 'Fixed Block' category
        await tester.tap(find.text('Fixed Block'));
        await tester.pumpAndSettle();

        // Fill in title
        await tester.enterText(
          find.byType(TextField).first,
          'New Overlapping Meeting',
        );
        await tester.pumpAndSettle();

        // Check conflict box is NOT present
        expect(find.text('No conflict detected for this slot.'), findsNothing);
        expect(find.text('This item has a blocking conflict.'), findsNothing);
        expect(find.byIcon(Icons.block_rounded), findsNothing);

        // Save button is enabled
        final saveBtnFinder = find.widgetWithText(
          ElevatedButton,
          'Save at this time',
        );
        expect(saveBtnFinder, findsOneWidget);
        final saveBtn = tester.widget<ElevatedButton>(saveBtnFinder);
        expect(saveBtn.enabled, isTrue);

        // Tap save
        await tester.tap(saveBtnFinder);
        await tester.pumpAndSettle();

        // Sheet closed
        expect(find.text('New Overlapping Meeting'), findsNothing);
      },
    );
  });

  group('N: RoutineMoveSheet Has Neutral UI & Allows Overlap', () {
    testWidgets('Button says Move task and allows overlap', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final itemToMove = RoutineItem(
        id: 'move_me',
        title: 'Task to Move',
        startMinute: 8 * 60,
        endMinute: 9 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
      );
      final existingItem = RoutineItem(
        id: 'exist_1',
        title: 'Existing Item',
        startMinute: 10 * 60,
        endMinute: 12 * 60,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) =>
                  _FakeNotifier(ref, initialItems: [itemToMove, existingItem]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () =>
                        showRoutineMoveSheet(context, ref, itemToMove),
                    child: const Text('Open Move Sheet'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open move sheet
      await tester.tap(find.text('Open Move Sheet'));
      await tester.pumpAndSettle();

      // Button says "Move task", NEVER "Resolve blocking conflict"
      expect(find.text('Move task'), findsOneWidget);
      expect(find.text('Resolve blocking conflict'), findsNothing);
      expect(find.text('No conflicts in this slot.'), findsNothing);

      // Tap Move task
      await tester.tap(find.text('Move task'));
      await tester.pumpAndSettle();

      // Sheet closed
      expect(find.text('Move Task to Move'), findsNothing);
    });
  });

  group('O: AIAssistantSheet Has No Conflict Suggestions', () {
    testWidgets('Does not show Fix conflict suggestions or chips', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineNotifierProvider.overrideWith((ref) => _FakeNotifier(ref)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () => showAIAssistantSheet(context, ref),
                    child: const Text('Open AI'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open AI'));
      await tester.pumpAndSettle();

      expect(find.text('Fix conflict'), findsNothing);
      expect(find.text('Fix conflicts'), findsNothing);
    });
  });

  group('P: WeekPlannerSheet Has No Conflict Chips', () {
    testWidgets('Does not display conflict counts or warning colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineNotifierProvider.overrideWith((ref) => _FakeNotifier(ref)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () => showRoutineWeekPlannerSheet(context, ref),
                    child: const Text('Open Week Planner'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Week Planner'));
      await tester.pumpAndSettle();

      expect(find.textContaining('conflicts'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('Q: RoutineTab Zero Conflict UX', () {
    testWidgets('No conflict banner, no conflict filter, no resolver toggle', (
      tester,
    ) async {
      final item1 = RoutineItem(
        id: 'i1',
        title: 'Class 1',
        startMinute: 540,
        endMinute: 660,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
      );
      final item2 = RoutineItem(
        id: 'i2',
        title: 'Class 2',
        startMinute: 600,
        endMinute: 720,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineNotifierProvider.overrideWith(
              (ref) => _FakeNotifier(ref, initialItems: [item1, item2]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: RoutineTab())),
        ),
      );
      await tester.pumpAndSettle();

      // Zero conflict banner
      expect(find.textContaining('conflict found'), findsNothing);
      expect(find.textContaining('conflicts found'), findsNothing);

      // Filters list does not have 'conflicts'
      for (final f in primaryFilters) {
        expect(f.key, isNot('conflicts'));
      }

      // Filter utils behaves safely
      final allFiltered = TimelineUtils.filterItems([
        item1,
        item2,
      ], 'conflicts');
      expect(allFiltered.length, 2);
    });
  });

  group('R: Card Tap Directly Opens Detail Sheet', () {
    testWidgets(
      'Tapping overlapping card opens detail sheet directly without resolver',
      (tester) async {
        final itemA = RoutineItem(
          id: 'item_a',
          title: 'Morning Class',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          hasConflict: true, // legacy value
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineNotifierProvider.overrideWith(
                (ref) => _FakeNotifier(ref, initialItems: [itemA]),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: RoutineTab())),
          ),
        );
        await tester.pumpAndSettle();

        // Tap card
        await tester.tap(find.text('Morning Class'));
        await tester.pumpAndSettle();

        // Routine detail sheet is opened (title 'Morning Class' appears in detail view), NOT conflict resolver
        expect(find.text('Morning Class'), findsWidgets);
        expect(find.textContaining('conflict found'), findsNothing);
      },
    );
  });

  group(
    'A, B, C, F, G, H, I: Real RoutineNotifier Overlap Writes (No Fake)',
    () {
      test(
        'A & F: Add overlap with simultaneous hard blocks succeeds',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final controller = container.read(routineNotifierProvider.notifier);
          final classItem = RoutineItem(
            id: 'class_add_1',
            title: 'Class 9-11',
            startMinute: 9 * 60,
            endMinute: 11 * 60,
            repeatDays: const [1],
            blockType: RoutineBlockType.hardBlock,
            category: RoutineCategory.classBlock,
          );
          final workItem = RoutineItem(
            id: 'work_add_1',
            title: 'Work 9:30-10:30',
            startMinute: 9 * 60 + 30,
            endMinute: 10 * 60 + 30,
            repeatDays: const [1],
            blockType: RoutineBlockType.hardBlock,
            category: RoutineCategory.job,
          );

          final res1 = await controller.addItem(classItem);
          expect(res1.outcome, RoutineWriteOutcome.saved);

          final res2 = await controller.addItem(workItem);
          expect(res2.outcome, RoutineWriteOutcome.saved);

          final items = container.read(routineNotifierProvider).items;
          expect(items.any((i) => i.id == 'class_add_1'), isTrue);
          expect(items.any((i) => i.id == 'work_add_1'), isTrue);
        },
      );

      test('B: Edit into overlap via updateItem succeeds', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(routineNotifierProvider.notifier);
        final item1 = RoutineItem(
          id: 'edit_target_1',
          title: 'Morning Focus',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.fixed,
        );
        final item2 = RoutineItem(
          id: 'edit_target_2',
          title: 'Afternoon Job',
          startMinute: 14 * 60,
          endMinute: 15 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.job,
        );

        await controller.addItem(item1);
        await controller.addItem(item2);

        // Edit item2 to overlap directly with item1 (09:15 - 10:15)
        final edited = item2.copyWith(
          startMinute: 9 * 60 + 15,
          endMinute: 10 * 60 + 15,
        );
        final updateRes = await controller.updateItem(edited);
        expect(updateRes.outcome, RoutineWriteOutcome.saved);

        final current = container
            .read(routineNotifierProvider)
            .items
            .firstWhere((i) => i.id == 'edit_target_2');
        expect(current.startMinute, 9 * 60 + 15);
        expect(current.endMinute, 10 * 60 + 15);
      });

      test('C: Move into overlap via moveItem succeeds', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(routineNotifierProvider.notifier);
        final item1 = RoutineItem(
          id: 'move_base_1',
          title: 'Base Class',
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );
        final item2 = RoutineItem(
          id: 'move_cand_1',
          title: 'Gym',
          startMinute: 15 * 60,
          endMinute: 16 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.health,
        );

        await controller.addItem(item1);
        await controller.addItem(item2);

        // Move item2 right on top of item1 (09:30 - 10:30)
        final moveRes = await controller.moveItem(
          itemId: item2.id,
          date: monday,
          startMinute: 9 * 60 + 30,
          durationMinutes: 60,
        );
        expect(moveRes.outcome, RoutineWriteOutcome.saved);
      });

      test('G: Class and work overlap via addItem succeeds', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(routineNotifierProvider.notifier);
        final classItem = RoutineItem(
          id: 'class_g',
          title: 'Chemistry 201',
          startMinute: 10 * 60,
          endMinute: 12 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );
        final workItem = RoutineItem(
          id: 'work_g',
          title: 'Part-time Shift',
          startMinute: 11 * 60,
          endMinute: 13 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.job,
        );

        final r1 = await controller.addItem(classItem);
        final r2 = await controller.addItem(workItem);
        expect(r1.outcome, RoutineWriteOutcome.saved);
        expect(r2.outcome, RoutineWriteOutcome.saved);
      });

      test('H: Sleep and task overlap via addItem succeeds', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(routineNotifierProvider.notifier);
        final sleepItem = RoutineItem(
          id: 'sleep_h',
          title: 'Sleep Block',
          startMinute: 22 * 60,
          endMinute: 6 * 60,
          crossesMidnight: true,
          endsNextDay: true,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.sleep,
        );
        final routineTask = RoutineItem(
          id: 'task_h',
          title: 'Early Routine Task',
          startMinute: 5 * 60 + 30,
          endMinute: 6 * 60 + 30,
          repeatDays: const [1],
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.habit,
        );

        final r1 = await controller.addItem(sleepItem);
        final r2 = await controller.addItem(routineTask);
        expect(r1.outcome, RoutineWriteOutcome.saved);
        expect(r2.outcome, RoutineWriteOutcome.saved);
      });

      test(
        'I: Closely spaced and overlapping meals succeed without 120-min error',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final controller = container.read(routineNotifierProvider.notifier);
          final meal1 = RoutineItem(
            id: 'meal_i1',
            title: 'Breakfast',
            startMinute: 8 * 60,
            endMinute: 8 * 60 + 30,
            repeatDays: const [1],
            blockType: RoutineBlockType.softBlock,
            category: RoutineCategory.eating,
          );
          final meal2 = RoutineItem(
            id: 'meal_i2',
            title: 'Quick Snack',
            startMinute: 8 * 60 + 15,
            endMinute: 8 * 60 + 45,
            repeatDays: const [1],
            blockType: RoutineBlockType.softBlock,
            category: RoutineCategory.eating,
          );

          final r1 = await controller.addItem(meal1);
          final r2 = await controller.addItem(meal2);
          expect(r1.outcome, RoutineWriteOutcome.saved);
          expect(r2.outcome, RoutineWriteOutcome.saved);
        },
      );
    },
  );

  group('D: Move into Overlap Accepts Target Time', () {
    testWidgets(
      'Move action to overlapping position saves without error snackbar',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool moveCalled = false;
        final itemToDrag = RoutineItem(
          id: 'drag_item',
          title: 'Draggable Task',
          startMinute: 12 * 60, // 12:00 PM
          endMinute: 13 * 60, // 1:00 PM
          repeatDays: const [1],
          blockType: RoutineBlockType.flexibleTask,
        );
        final existingItem = RoutineItem(
          id: 'target_item',
          title: 'Target Block',
          startMinute: 9 * 60, // 9:00 AM
          endMinute: 11 * 60, // 11:00 AM
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineNotifierProvider.overrideWith(
                (ref) => _DragTestNotifier(
                  ref,
                  onMove: (itemId, startMinute) {
                    moveCalled = true;
                    expect(itemId, 'drag_item');
                  },
                  initialItems: [itemToDrag, existingItem],
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: RoutineTab())),
          ),
        );
        await tester.pumpAndSettle();

        final dragFinder = find.text('Draggable Task');
        expect(dragFinder, findsOneWidget);

        // Tap the canonical Move button on the card
        final moveActionFinder = find.byKey(
          const ValueKey('routine-action-move-drag_item'),
        );
        expect(moveActionFinder, findsOneWidget);
        await tester.tap(moveActionFinder);
        await tester.pumpAndSettle();

        // Move sheet opens, confirm move task
        final moveTaskButton = find.text('Move task');
        expect(moveTaskButton, findsOneWidget);
        await tester.tap(moveTaskButton);
        await tester.pumpAndSettle();

        expect(moveCalled, isTrue);
        // No conflict error snackbar
        expect(find.textContaining('Blocking conflict'), findsNothing);
        expect(find.textContaining('conflict detected'), findsNothing);
      },
    );
  });

  group('E: Multiple Simultaneous Items Materialization & Collision Layout', () {
    test(
      'At least 3-4 simultaneous overlapping activities remain materialized with no conflicts',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final item1 = RoutineItem(
          id: 'sim_1',
          title: 'Class',
          startMinute: 9 * 60, // 9:00 - 11:00
          endMinute: 11 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );
        final item2 = RoutineItem(
          id: 'sim_2',
          title: 'Eating',
          startMinute: 9 * 60 + 30, // 9:30 - 10:00
          endMinute: 10 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
        );
        final item3 = RoutineItem(
          id: 'sim_3',
          title: 'Work',
          startMinute: 9 * 60 + 45, // 9:45 - 12:00
          endMinute: 12 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.job,
        );
        final item4 = RoutineItem(
          id: 'sim_4',
          title: 'Skin Care',
          startMinute: 9 * 60 + 50, // 9:50 - 10:10
          endMinute: 10 * 60 + 10,
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.skinCare,
        );

        container.read(routineNotifierProvider.notifier).state = container
            .read(routineNotifierProvider)
            .copyWith(items: [item1, item2, item3, item4], selectedDay: monday);

        final dayItems = container.read(selectedDayRoutineItemsProvider);
        expect(dayItems.length, 4);

        // Verify all items are materialized cleanly without conflict decoration
        for (final item in dayItems) {
          expect(item.hasConflict, isFalse);
          expect(item.conflictMessage, isNull);
        }

        // Verify sorted by start time
        expect(dayItems[0].id, 'sim_1');
        expect(dayItems[1].id, 'sim_2');
        expect(dayItems[2].id, 'sim_3');
        expect(dayItems[3].id, 'sim_4');
      },
    );
  });

  group(
    'P: Routine Settings Automation Section Has No Conflict Resolver Switch',
    () {
      testWidgets(
        'Settings screen contains AI and Notification toggles but NO Conflict Resolver',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                routineNotifierProvider.overrideWith(
                  (ref) => _FakeNotifier(ref),
                ),
              ],
              child: const MaterialApp(home: Scaffold(body: RoutineTab())),
            ),
          );
          await tester.pumpAndSettle();

          // Open settings screen via routineDetailViewRequestProvider
          final container = ProviderScope.containerOf(
            tester.element(find.byType(RoutineTab)),
          );
          container
              .read(routineDetailViewRequestProvider.notifier)
              .state = const RoutineDetailTarget(
            view: RoutineDetailView.routineSettings,
          );
          await tester.pumpAndSettle();

          // Verify settings screen is opened
          expect(find.text('Routine Settings'), findsOneWidget);
          expect(find.text('TIMELINE VIEW'), findsOneWidget);
          expect(find.text('AUTOMATION'), findsOneWidget);
          expect(find.text('AI Suggestions'), findsOneWidget);
          expect(find.text('Notifications'), findsOneWidget);

          // Verify Conflict Resolver switch is completely gone
          expect(find.text('Conflict Resolver'), findsNothing);
          expect(
            find.textContaining(RegExp('conflict', caseSensitive: false)),
            findsNothing,
          );
        },
      );
    },
  );

  group('S: Legacy Conflict Metadata Neutralization', () {
    test(
      'Legacy hasConflict, conflictMessage, and allowedConflicts do not leak into materialized items',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final legacyItem = RoutineItem(
          id: 'legacy_1',
          title: 'Legacy Conflicted Task',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          hasConflict: true,
          conflictMessage: 'Old blocking conflict from database',
          allowedConflicts: const [
            RoutineConflictAllowance(
              canonicalPairId: 'pair-1',
              evaluatedDateKey: '2026-07-27',
              conflictType: 'timeOverlap',
              scheduleFingerprint: 'old-fp',
            ),
          ],
        );

        container.read(routineNotifierProvider.notifier).state = container
            .read(routineNotifierProvider)
            .copyWith(items: [legacyItem], selectedDay: monday);

        // selectedDayRoutineItemsProvider must scrub legacy conflict flags
        final selectedItems = container.read(selectedDayRoutineItemsProvider);
        expect(selectedItems.length, 1);
        expect(selectedItems.first.hasConflict, isFalse);
        expect(selectedItems.first.conflictMessage, isNull);

        // todayRoutineItemsProvider must also scrub legacy conflict flags
        final todayItems = container.read(todayRoutineItemsProvider);
        for (final item in todayItems) {
          expect(item.hasConflict, isFalse);
          expect(item.conflictMessage, isNull);
        }
      },
    );

    testWidgets(
      'Legacy conflict metadata in state does not produce conflict banner or badges in RoutineTab',
      (tester) async {
        final legacyItem = RoutineItem(
          id: 'legacy_ui_1',
          title: 'Legacy UI Item',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          hasConflict: true,
          conflictMessage: 'Legacy conflict message',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineNotifierProvider.overrideWith(
                (ref) => _FakeNotifier(ref, initialItems: [legacyItem]),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: RoutineTab())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Legacy UI Item'), findsOneWidget);
        expect(find.text('Conflict'), findsNothing);
        expect(find.text('Legacy conflict message'), findsNothing);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
        expect(find.textContaining('conflict found'), findsNothing);
      },
    );
  });

  group('R: Routine Conflict Decoupling Invariants & Regressions', () {
    test(
      '1. Routine loading succeeds when conflict acceptance repo fails or is absent',
      () async {
        final repo = FakeRoutineRepository();
        final history = FakeRoutineHistoryRepository();
        final transactions = FakeRoutineTransactionRepository();
        final testItem = RoutineItem(
          id: 'test_1',
          userId: 'test_owner',
          title: 'Morning Yoga',
          startMinute: 480,
          endMinute: 540,
          repeatDays: const [1],
          blockType: RoutineBlockType.flexibleTask,
        );
        await repo.createRoutineItem('test_owner', testItem);

        final throwingRepo = _ThrowingConflictAcceptanceRepository();
        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(repo),
            routineHistoryRepositoryProvider.overrideWithValue(history),
            routineTransactionRepositoryProvider.overrideWithValue(
              transactions,
            ),
            conflictAcceptanceRepositoryProvider.overrideWithValue(
              throwingRepo,
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner('test_owner');

        final state = container.read(routineNotifierProvider);
        expect(state.loading, isFalse);
        expect(state.error, isNull);
        expect(state.items, hasLength(1));
        expect(state.items.first.title, 'Morning Yoga');
        expect(throwingRepo.fetchCallCount, 0);
        expect(throwingRepo.upsertCallCount, 0);
      },
    );

    test('2. RoutineState has no conflict fields', () {
      final state = RoutineState(
        items: const [],
        selectedDay: DateTime(2026, 7, 27),
      );
      expect(state.items, isEmpty);
      expect(state.loading, isFalse);
      expect(state.selectedPrimaryFilter, 'all');
      expect(primaryFilters.any((f) => f.key == 'conflicts'), isFalse);
    });

    test('3. Unsupported legacy filter key falls back to all', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(routineNotifierProvider.notifier);

      notifier.setPrimaryFilter('conflicts');
      expect(
        container.read(routineNotifierProvider).selectedPrimaryFilter,
        'all',
      );

      notifier.setPrimaryFilter('non_existent_filter');
      expect(
        container.read(routineNotifierProvider).selectedPrimaryFilter,
        'all',
      );

      final item1 = RoutineItem(
        id: 'i1',
        title: 'Task 1',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
      );
      final filtered = TimelineUtils.filterItems([item1], 'conflicts');
      expect(filtered, hasLength(1));
    });

    test(
      '4. allowedOverlaps does not alter free gap calculation in AIAssistantSheet',
      () {
        final itemWithoutAllowance = RoutineItem(
          id: 'item_1',
          title: 'Item Without Allowance',
          startMinute: 8 * 60,
          endMinute: 9 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          allowedOverlaps: const [],
        );

        final itemWithAllowance = RoutineItem(
          id: 'item_1',
          title: 'Item With Allowance',
          startMinute: 8 * 60,
          endMinute: 9 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          allowedOverlaps: const ['overlap_candidate_id'],
        );

        final gap1 = calculateLargestFreeGap([itemWithoutAllowance]);
        final gap2 = calculateLargestFreeGap([itemWithAllowance]);

        expect(gap1.start, gap2.start);
        expect(gap1.end, gap2.end);
        expect(gap1.duration, gap2.duration);
      },
    );
  });
}

class _DragTestNotifier extends RoutineNotifier {
  final void Function(String itemId, int startMinute) onMove;

  _DragTestNotifier(
    Ref ref, {
    required this.onMove,
    List<RoutineItem> initialItems = const [],
  }) : super(
         FakeRoutineRepository(),
         FakeRoutineHistoryRepository(),
         FakeRoutineTransactionRepository(),
         ref,
       ) {
    state = state.copyWith(
      items: initialItems,
      selectedDay: DateTime(2026, 7, 27),
    );
  }

  @override
  Future<RoutineWriteResult> moveItem({
    required String itemId,
    required DateTime date,
    required int startMinute,
    required int durationMinutes,
  }) async {
    onMove(itemId, startMinute);
    final updated = state.items.map((i) {
      if (i.id == itemId) {
        return i.copyWith(
          date: date,
          startMinute: startMinute,
          endMinute: (startMinute + durationMinutes) % 1440,
        );
      }
      return i;
    }).toList();
    state = state.copyWith(items: updated);
    return RoutineWriteResult.saved(
      operationId: 'drag-$itemId',
      message: 'Item moved',
    );
  }
}
