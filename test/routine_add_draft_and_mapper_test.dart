import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/models/add_routine_draft.dart';
import 'package:optivus/features/routine/services/add_routine_mapper.dart';
import 'package:optivus/features/routine/services/add_routine_validator.dart';
import 'package:optivus/features/routine/sheets/add_routine_sheet.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

void main() {
  group('AddRoutineDraft and Mapper Matrix', () {
    test('Draft has stable ID and copyWith preserves ID', () {
      final draft = AddRoutineDraft.initial(initialType: AddRoutineType.flexible);
      expect(draft.id, isNotEmpty);
      final initialId = draft.id;

      final updated = draft.copyWith(title: 'Updated title');
      expect(updated.id, initialId);
      expect(updated.title, 'Updated title');

      final explicitIdDraft = AddRoutineDraft.initial(
        id: 'stable-fixed-id-123',
        initialType: AddRoutineType.flexible,
      );
      expect(explicitIdDraft.id, 'stable-fixed-id-123');
    });

    test('Maps all 6 types to corresponding RoutineItem', () {
      // 1. Fixed Block (Class / Custom)
      final fixedDraft = AddRoutineDraft.initial(
        id: 'fixed-1',
        initialType: AddRoutineType.fixed,
      ).copyWith(
        title: 'Deep Work',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        durationMinutes: 120,
        fixedState: const AddRoutineFixedState(
          kind: 'Work',
          hardBlock: true,
          workLocation: 'Office Room 3',
        ),
      );
      final fixedItem = AddRoutineMapper.toRoutineItem(fixedDraft);
      expect(fixedItem.id, 'fixed-1');
      expect(fixedItem.title, 'Deep Work');
      expect(fixedItem.startMinute, 540);
      expect(fixedItem.endMinute, 660);
      expect(fixedItem.hardBlock, true);
      expect(fixedItem.blockType, RoutineBlockType.hardBlock);
      expect(fixedItem.location, 'Office Room 3');

      // 2. Flexible Task
      final flexDraft = AddRoutineDraft.initial(
        id: 'flex-1',
        initialType: AddRoutineType.flexible,
      ).copyWith(
        title: 'Read Book',
        durationMinutes: 45,
        bestTime: 'evening',
        flexibleState: const AddRoutineFlexibleState(
          category: RoutineCategory.habit,
          subtasks: ['Chapter 1', 'Chapter 2'],
        ),
      );
      final flexItem = AddRoutineMapper.toRoutineItem(flexDraft);
      expect(flexItem.id, 'flex-1');
      expect(flexItem.title, 'Read Book');
      expect(flexItem.startMinute, 480);
      expect(flexItem.endMinute, 525);
      expect(flexItem.hardBlock, false);
      expect(flexItem.bestTime, 'evening');
      expect(flexItem.blockType, RoutineBlockType.flexibleTask);
      expect(flexItem.subtasks, ['Chapter 1', 'Chapter 2']);

      // 3. Habit
      final habitDraft = AddRoutineDraft.initial(
        id: 'habit-1',
        initialType: AddRoutineType.habit,
      ).copyWith(
        title: 'Morning Meditation',
        habitState: const AddRoutineHabitState(
          category: RoutineCategory.habit,
          steps: ['Breathe in', 'Breathe out'],
        ),
      );
      final habitItem = AddRoutineMapper.toRoutineItem(habitDraft);
      expect(habitItem.id, 'habit-1');
      expect(habitItem.blockType, RoutineBlockType.flexibleTask);
      expect(habitItem.steps, ['Breathe in', 'Breathe out']);
      expect(habitItem.hardBlock, false);

      // 4. Tracker
      final trackerDraft = AddRoutineDraft.initial(
        id: 'track-1',
        initialType: AddRoutineType.tracker,
      ).copyWith(
        title: 'Daily Workout',
        trackerState: const AddRoutineTrackerState(
          trackerType: TrackerType.workout,
        ),
      );
      final trackerItem = AddRoutineMapper.toRoutineItem(trackerDraft);
      expect(trackerItem.id, 'track-1');
      expect(trackerItem.blockType, RoutineBlockType.trackerTask);
      expect(trackerItem.trackerType, TrackerType.workout);
      expect(trackerItem.hardBlock, false);

      // 5. Check-in
      final checkInDraft = AddRoutineDraft.initial(
        id: 'check-1',
        initialType: AddRoutineType.checkin,
      ).copyWith(
        title: 'Smoking check-in',
        checkInState: const AddRoutineCheckInState(
          checkInType: 'Smoking',
        ),
      );
      final checkInItem = AddRoutineMapper.toRoutineItem(checkInDraft);
      expect(checkInItem.id, 'check-1');
      expect(checkInItem.blockType, RoutineBlockType.checkIn);
      expect(checkInItem.hardBlock, false);

      // 6. Money Saving
      final moneyDraft = AddRoutineDraft.initial(
        id: 'money-1',
        initialType: AddRoutineType.money,
      ).copyWith(
        title: 'Cook at Home',
        moneyState: const AddRoutineMoneyState(
          defaultTitle: 'Cook at Home',
        ),
      );
      final moneyItem = AddRoutineMapper.toRoutineItem(moneyDraft);
      expect(moneyItem.id, 'money-1');
      expect(moneyItem.blockType, RoutineBlockType.moneyTask);
      expect(moneyItem.hardBlock, false);
    });

    test('Zero state leakage on type switching', () {
      // Create draft configured with Fixed details (hardBlock, custom location)
      var draft = AddRoutineDraft.initial(
        id: 'switch-test',
        initialType: AddRoutineType.fixed,
      ).copyWith(
        title: 'Sprint Planning',
        startTime: const TimeOfDay(hour: 10, minute: 0),
        durationMinutes: 60,
        fixedState: const AddRoutineFixedState(
          kind: 'Work',
          hardBlock: true,
          workLocation: 'Room 101',
        ),
      );

      // Verify Fixed produces hardBlock: true
      var item = AddRoutineMapper.toRoutineItem(draft);
      expect(item.hardBlock, true);
      expect(item.blockType, RoutineBlockType.hardBlock);
      expect(item.location, 'Room 101');

      // Switch type to Flexible
      draft = draft.switchType(AddRoutineType.flexible);
      item = AddRoutineMapper.toRoutineItem(draft);
      // HardBlock MUST NOT leak to Flexible
      expect(item.hardBlock, false);
      expect(item.blockType, RoutineBlockType.flexibleTask);
      expect(item.location, isNull);

      // Switch type to Tracker
      draft = draft.switchType(AddRoutineType.tracker).copyWith(
        trackerState: const AddRoutineTrackerState(trackerType: TrackerType.hydration),
      );
      item = AddRoutineMapper.toRoutineItem(draft);
      expect(item.hardBlock, false);
      expect(item.blockType, RoutineBlockType.trackerTask);
      expect(item.trackerType, TrackerType.hydration);

      // Switch to Money
      draft = draft.switchType(AddRoutineType.money);
      item = AddRoutineMapper.toRoutineItem(draft);
      expect(item.hardBlock, false);
      expect(item.blockType, RoutineBlockType.moneyTask);
      expect(item.trackerType, TrackerType.money);

      // Switch back to Fixed: fixedState sub-model was preserved independently
      draft = draft.copyWith(
        type: AddRoutineType.fixed,
        fixedState: const AddRoutineFixedState(
          kind: 'Work',
          hardBlock: true,
          workLocation: 'Room 101',
        ),
      );
      item = AddRoutineMapper.toRoutineItem(draft);
      expect(item.hardBlock, true);
      expect(item.location, 'Room 101');
    });

    test('bestTime roundtrip for Flexible Tasks', () {
      for (final bestTime in const ['morning', 'afternoon', 'evening', 'anytime']) {
        final draft = AddRoutineDraft.initial(initialType: AddRoutineType.flexible).copyWith(
          title: 'Task for $bestTime',
          bestTime: bestTime,
        );
        final item = AddRoutineMapper.toRoutineItem(draft);
        expect(item.bestTime, bestTime);
      }
    });

    test('One-time date vs weekly repeat days contract', () {
      // One-time: scheduleMode once
      final oneTimeDraft = AddRoutineDraft.initial(initialType: AddRoutineType.flexible).copyWith(
        title: 'Doctor Appointment',
        scheduleMode: AddRoutineScheduleMode.once,
        date: DateTime(2026, 9, 25),
        repeatDays: [1, 2, 3], // should be ignored when scheduleMode is once
      );
      final oneTimeItem = AddRoutineMapper.toRoutineItem(oneTimeDraft);
      expect(oneTimeItem.date, DateTime(2026, 9, 25));
      expect(oneTimeItem.repeatDays, isEmpty);
      expect(oneTimeItem.repeatRule, 'once');

      // Weekly: scheduleMode weekly
      final weeklyDraft = AddRoutineDraft.initial(initialType: AddRoutineType.flexible).copyWith(
        title: 'Weekly Standup',
        scheduleMode: AddRoutineScheduleMode.weekly,
        date: DateTime(2026, 9, 25), // should be ignored when scheduleMode is weekly
        repeatDays: [1, 3, 5],
      );
      final weeklyItem = AddRoutineMapper.toRoutineItem(weeklyDraft);
      expect(weeklyItem.date, isNull);
      expect(weeklyItem.repeatDays, [1, 3, 5]);
      expect(weeklyItem.repeatRule, 'weekly');
    });
  });

  group('AddRoutineValidator Invariants', () {
    test('Validates title is non-empty and non-whitespace', () {
      final emptyTitleDraft = AddRoutineDraft.initial(initialType: AddRoutineType.flexible).copyWith(
        title: '   ',
      );
      final emptyResult = AddRoutineValidator.validate(emptyTitleDraft);
      expect(emptyResult, isNotNull);
      expect(emptyResult, 'Title is required.');

      final validTitleDraft = AddRoutineDraft.initial(initialType: AddRoutineType.flexible).copyWith(
        title: 'Morning Jog',
      );
      final validResult = AddRoutineValidator.validate(validTitleDraft);
      expect(validResult, isNull);
    });

    test('Validates duration must be positive', () {
      final zeroDurationDraft = AddRoutineDraft.initial(initialType: AddRoutineType.flexible).copyWith(
        title: 'Quick Stretch',
        durationMinutes: 0,
      );
      final result = AddRoutineValidator.validate(zeroDurationDraft);
      expect(result, isNotNull);
      expect(result, contains('Duration must be greater than 0'));
    });

    test('Validates repeatDays for weekly routine', () {
      final noDaysDraft = AddRoutineDraft.initial(initialType: AddRoutineType.flexible).copyWith(
        title: 'Weekly Task',
        scheduleMode: AddRoutineScheduleMode.weekly,
        repeatDays: const [],
      );
      final result = AddRoutineValidator.validate(noDaysDraft);
      expect(result, isNotNull);
      expect(result, contains('Please select at least one day'));

      final invalidDayDraft = AddRoutineDraft.initial(initialType: AddRoutineType.flexible).copyWith(
        title: 'Weekly Task',
        scheduleMode: AddRoutineScheduleMode.weekly,
        repeatDays: const [0, 8],
      );
      final invalidResult = AddRoutineValidator.validate(invalidDayDraft);
      expect(invalidResult, isNotNull);
      expect(invalidResult, contains('Repeat days must be between 1 (Monday) and 7 (Sunday).'));
    });

    test('Overnight Sleep block is valid', () {
      final sleepDraft = AddRoutineDraft.initial(initialType: AddRoutineType.fixed).copyWith(
        title: 'Sleep',
        startTime: const TimeOfDay(hour: 23, minute: 0),
        durationMinutes: 480, // 8 hours -> crosses midnight to 07:00
        fixedState: const AddRoutineFixedState(
          kind: 'Sleep',
          hardBlock: true,
        ),
      );
      final result = AddRoutineValidator.validate(sleepDraft);
      expect(result, isNull);
    });

    test('Non-sleep overnight block without overnight support is rejected', () {
      final nonSleepOvernight = AddRoutineDraft.initial(initialType: AddRoutineType.fixed).copyWith(
        title: 'Gym Session',
        startTime: const TimeOfDay(hour: 23, minute: 0),
        durationMinutes: 120, // 2 hours -> crosses midnight to 01:00
        fixedState: const AddRoutineFixedState(
          kind: 'Custom',
          hardBlock: false,
        ),
      );
      final result = AddRoutineValidator.validate(nonSleepOvernight);
      expect(result, isNotNull);
      expect(result, contains('Only Sleep blocks typically cross midnight'));
    });
  });

  group('AddRoutineSheet UI Responsiveness', () {
    late ProviderContainer container;
    late FakeRoutineRepository repo;
    late FakeRoutineDatabase database;
    late FakeRoutineHistoryRepository historyRepo;
    late FakeRoutineTransactionRepository transactionRepo;

    setUp(() {
      database = FakeRoutineDatabase();
      repo = FakeRoutineRepository(database: database);
      historyRepo = FakeRoutineHistoryRepository();
      transactionRepo = FakeRoutineTransactionRepository(
        routineRepository: repo,
        historyRepository: historyRepo,
      );

      container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
          routineRepositoryProvider.overrideWithValue(repo),
          routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
          routineTransactionRepositoryProvider.overrideWithValue(transactionRepo),
        ],
      );
    });

    tearDown(() => container.dispose());

    testWidgets('Renders at 320dp width and 2.5x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2.5),
              ),
              child: const Scaffold(
                body: AddRoutineSheet(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no RenderFlex overflow exceptions occurred on initial grid
      expect(tester.takeException(), isNull);
      expect(find.text('Add to Routine'), findsOneWidget);
      expect(find.text('Flexible Task'), findsOneWidget);

      // Select Flexible Task to open form
      await tester.tap(find.text('Flexible Task'));
      await tester.pumpAndSettle();

      // Verify form rendered without overflow
      expect(tester.takeException(), isNull);
      expect(find.text('Find free slot'), findsOneWidget);
      expect(find.text('One time'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);

      // Switch to Weekly
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Navigate back to grid
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Add to Routine'), findsOneWidget);
    });
  });
}
