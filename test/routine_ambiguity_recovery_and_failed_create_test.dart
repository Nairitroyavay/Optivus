import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/models/add_routine_draft.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/add_routine_validator.dart';
import 'package:optivus/features/routine/sheets/add_routine_sheet.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

class _AmbiguousRoutineRepository extends FakeRoutineRepository {
  bool shouldThrowOnCreateAfterPersisting = false;
  bool shouldThrowOnCreateWithoutPersisting = false;

  _AmbiguousRoutineRepository({super.database});

  @override
  Future<RoutineItem> createRoutineItem(String uid, RoutineItem item) async {
    if (shouldThrowOnCreateWithoutPersisting) {
      throw TimeoutException('Network timed out before reaching server');
    }
    if (shouldThrowOnCreateAfterPersisting) {
      // Item reached Firestore, but connection dropped before response arrived
      await super.createRoutineItem(uid, item);
      throw TimeoutException('Network timed out waiting for server ack _SKIP_ROLLBACK');
    }
    return await super.createRoutineItem(uid, item);
  }
}

class _AmbiguousTransactionRepository extends FakeRoutineTransactionRepository {
  final RoutineHistoryRepository historyRepo;
  bool shouldThrowOnRecordAfterPersisting = false;

  _AmbiguousTransactionRepository(
    this.historyRepo, {
    RoutineRepository? routineRepository,
  }) : super(
          historyRepository: historyRepo,
          routineRepository: routineRepository,
        );

  @override
  Future<void> commitWrite({
    required String uid,
    RoutineItem? setItem,
    List<RoutineItem>? setItems,
    String? deleteItemId,
    List<String>? deleteItemIds,
    Map<String, dynamic>? setBaseTimelineSetupDoc,
    RoutineOccurrenceRecord? setOccurrence,
    String? deleteOccurrenceId,
    RoutineEventRecord? addEvent,
    List<RoutineEventRecord>? addEvents,
    List<ConflictAcceptance>? setConflictAcceptances,
  }) async {
    if (shouldThrowOnRecordAfterPersisting) {
      if (setOccurrence != null) {
        await historyRepo.appendHistory(uid, setOccurrence);
      }
      throw TimeoutException('Network timed out waiting for transaction ack _SKIP_ROLLBACK');
    }
    return await super.commitWrite(
      uid: uid,
      setItem: setItem,
      setItems: setItems,
      deleteItemId: deleteItemId,
      deleteItemIds: deleteItemIds,
      setBaseTimelineSetupDoc: setBaseTimelineSetupDoc,
      setOccurrence: setOccurrence,
      deleteOccurrenceId: deleteOccurrenceId,
      addEvent: addEvent,
      addEvents: addEvents,
      setConflictAcceptances: setConflictAcceptances,
    );
  }
}

void main() {
  group('Gates A, B, C, O, Q: Ambiguity Recovery & Failed Create Form', () {
    late _AmbiguousRoutineRepository routineRepo;
    late FakeRoutineHistoryRepository historyRepo;
    late _AmbiguousTransactionRepository txRepo;
    late ProviderContainer container;
    late RoutineNotifier notifier;

    const testUid = 'user-ambiguity-test';

    setUp(() async {
      routineRepo = _AmbiguousRoutineRepository();
      historyRepo = FakeRoutineHistoryRepository();
      txRepo = _AmbiguousTransactionRepository(
        historyRepo,
        routineRepository: routineRepo,
      );

      container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
          routineRepositoryProvider.overrideWithValue(routineRepo),
          routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
          routineTransactionRepositoryProvider.overrideWithValue(txRepo),
        ],
      );
      notifier = container.read(routineNotifierProvider.notifier);
      await notifier.loadForOwner(testUid);
    });

    tearDown(() {
      container.dispose();
    });

    test('Gate A: Ambiguity recovery on addItem succeeds when item reached remote repository', () async {
      routineRepo.shouldThrowOnCreateAfterPersisting = true;

      final newItem = RoutineItem(
        id: 'ambig_item_1',
        userId: testUid,
        title: 'Morning Yoga',
        startMinute: 420,
        endMinute: 450,
        repeatDays: const [1, 2, 3],
        repeatRule: 'weekly',
        blockType: RoutineBlockType.flexibleTask,
      );

      final result = await notifier.addItem(newItem);

      // Ambiguity recovery should have detected the item in fetchRoutineItems
      expect(result.closesUserFlow, isTrue);
      expect(result.outcome, RoutineWriteOutcome.saved);
      expect(notifier.state.items.any((i) => i.id == 'ambig_item_1'), isTrue);
      expect(notifier.state.failedIntentsByItemId.containsKey('ambig_item_1'), isFalse);
    });

    test('Gate A & B: Unambiguous network error flags failed intent for retry', () async {
      routineRepo.shouldThrowOnCreateWithoutPersisting = true;

      final newItem = RoutineItem(
        id: 'fail_item_1',
        userId: testUid,
        title: 'Evening Walk',
        date: DateTime(2026, 9, 15),
        startMinute: 1100,
        endMinute: 1130,
        repeatDays: const [],
        repeatRule: 'once',
        blockType: RoutineBlockType.flexibleTask,
      );

      final result = await notifier.addItem(newItem);

      expect(result.closesUserFlow, isFalse);
      expect(result.outcome, RoutineWriteOutcome.retryRequired);
      expect(notifier.state.failedIntentsByItemId.containsKey('fail_item_1'), isTrue);

      // Retry when network is restored succeeds
      routineRepo.shouldThrowOnCreateWithoutPersisting = false;
      final retryResult = await notifier.retryFailedOperation('fail_item_1');
      expect(retryResult.closesUserFlow, isTrue);
      expect(notifier.state.failedIntentsByItemId.containsKey('fail_item_1'), isFalse);
      expect(notifier.state.items.any((i) => i.id == 'fail_item_1'), isTrue);
    });

    test('Gate C: discardFailedCreate clears failed intent and safely cleans up remote item if existed', () async {
      routineRepo.shouldThrowOnCreateWithoutPersisting = true;

      final newItem = RoutineItem(
        id: 'discard_item_1',
        userId: testUid,
        title: 'Read Magazine',
        date: DateTime(2026, 9, 15),
        startMinute: 800,
        endMinute: 830,
        repeatDays: const [],
        repeatRule: 'once',
        blockType: RoutineBlockType.flexibleTask,
      );

      await notifier.addItem(newItem);
      expect(notifier.state.failedIntentsByItemId.containsKey('discard_item_1'), isTrue);

      await notifier.discardFailedCreate('discard_item_1');
      expect(notifier.state.failedIntentsByItemId.containsKey('discard_item_1'), isFalse);
      expect(notifier.state.items.any((i) => i.id == 'discard_item_1'), isFalse);
    });

    test('Gate O & Q: Ambiguity recovery on occurrence action succeeds when record reached history', () async {
      final existingItem = RoutineItem(
        id: 'active_item_1',
        userId: testUid,
        title: 'Coding Sprint',
        startMinute: 600,
        endMinute: 660,
        repeatDays: const [1, 2, 3, 4, 5],
        repeatRule: 'weekly',
        blockType: RoutineBlockType.flexibleTask,
      );
      await routineRepo.createRoutineItem(testUid, existingItem);
      notifier.state = notifier.state.copyWith(items: [existingItem]);

      txRepo.shouldThrowOnRecordAfterPersisting = true;

      final startResult = await notifier.startRoutineItem(
        existingItem.id,
        occurrenceDate: DateTime(2026, 9, 15),
      );

      // Ambiguity recovery detects record in fetchHistory
      expect(startResult.closesUserFlow, isTrue);
      expect(startResult.outcome, RoutineWriteOutcome.saved);
      expect(notifier.state.failedOccurrenceIntentsById.isEmpty, isTrue);
    });

    testWidgets('Gate B (UI): Add Routine Sheet freezes inputs and displays warning banner when save fails', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      routineRepo.shouldThrowOnCreateWithoutPersisting = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (ctx, ref, _) => ElevatedButton(
                  onPressed: () => showAddRoutineSheet(ctx, ref),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap 'Flexible Task' in type grid
      await tester.tap(find.text('Flexible Task'));
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      // ignore: avoid_print
      print('DEBUG: fields count=${fields.length}, labels=${fields.map((f) => f.decoration?.labelText).toList()}');

      // Enter title
      await tester.enterText(find.byType(TextField).first, 'Save-Failed Task');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 100));

      final testDraft = AddRoutineDraft.initial().copyWith(title: 'Save-Failed Task');
      // ignore: avoid_print
      print('DEBUG: validator on initial draft: ${AddRoutineValidator.validate(testDraft)}');
      // ignore: avoid_print
      print('DEBUG: draft scheduleMode: ${testDraft.scheduleMode}, repeatDays: ${testDraft.repeatDays}');

      final titleEntered = tester.widget<TextField>(find.byType(TextField).first).controller?.text;
      // ignore: avoid_print
      print('DEBUG: titleEntered="$titleEntered"');

      // Tap 'Save at this time' (will fail due to shouldThrowOnCreateWithoutPersisting)
      final saveBtn = find.text('Save at this time');
      await tester.ensureVisible(saveBtn);
      final btn = tester.widget<ElevatedButton>(find.ancestor(of: saveBtn, matching: find.byType(ElevatedButton)));
      btn.onPressed!();

      await tester.idle();
      await tester.pump();

      // 1. Verify warning banner appears
      expect(find.byKey(const ValueKey('add-routine-failed-warning')), findsOneWidget);

      // 2. Verify Retry button is visible
      expect(find.byKey(const ValueKey('add-routine-retry-button')), findsOneWidget);

      // 3. Verify Discard button is visible
      expect(find.byKey(const ValueKey('add-routine-discard-button')), findsOneWidget);

      // 4. Verify form is protected with AbsorbPointer
      final absorbPointer = tester.widget<AbsorbPointer>(
        find.ancestor(
          of: find.byType(TextField).first,
          matching: find.byType(AbsorbPointer),
        ),
      );
      expect(absorbPointer.absorbing, isTrue);

      // 5. Tap Discard button -> sheet closes and failed intent is discarded
      await tester.tap(find.byKey(const ValueKey('add-routine-discard-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('add-routine-failed-warning')), findsNothing);
    });
  });
}
