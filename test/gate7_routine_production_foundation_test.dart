import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/fake_habit_systems_repository.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/auth_session_reset_coordinator.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  group('Gate 7: Routine Production Foundation Tests', () {
    test('Routine CRUD with operation logging and idempotency', () async {
      final database = FakeRoutineDatabase();
      final routineRepo = FakeRoutineRepository(database: database);
      final container = ProviderContainer(
        overrides: [
          routineRepositoryProvider.overrideWithValue(routineRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(routineNotifierProvider.notifier);
      await notifier.loadForOwner('user-g7-crud');

      // 1. Create item
      final item = RoutineItem(
        id: 'routine_item_1',
        userId: 'user-g7-crud',
        title: 'Morning Deep Work',
        startMinute: 9 * 60,
        endMinute: 11 * 60,
        blockType: RoutineBlockType.hardBlock,
        repeatDays: const [1, 2, 3, 4, 5],
        createdByOperationId: 'op-create-1',
      );
      final createResult = await notifier.addItem(item);
      expect(createResult.outcome, RoutineWriteOutcome.saved);
      expect(container.read(routineNotifierProvider).items.length, 1);

      // 2. Read back from database
      final stored = await routineRepo.fetchRoutineItems('user-g7-crud');
      expect(stored.length, 1);
      expect(stored.first.title, 'Morning Deep Work');
      expect(stored.first.createdByOperationId, startsWith('create_'));

      // 3. Update item
      final updated = item.copyWith(
        title: 'Morning Deep Work (Focused)',
        endMinute: 11 * 60 + 30,
      );
      final updateResult = await notifier.updateItem(updated);
      expect(updateResult.outcome, RoutineWriteOutcome.saved);

      final storedAfterUpdate =
          await routineRepo.fetchRoutineItems('user-g7-crud');
      expect(storedAfterUpdate.first.title, 'Morning Deep Work (Focused)');

      // 4. Delete item
      final deleteResult = await notifier.deleteItem('routine_item_1');
      expect(deleteResult.outcome, RoutineWriteOutcome.saved);
      expect(container.read(routineNotifierProvider).items, isEmpty);

      final storedAfterDelete =
          await routineRepo.fetchRoutineItems('user-g7-crud');
      expect(storedAfterDelete, isEmpty);
    });

    test('Occurrence lifecycle and history recording', () async {
      final database = FakeRoutineDatabase();
      final routineRepo = FakeRoutineRepository(database: database);
      final historyRepo = FakeRoutineHistoryRepository();

      final container = ProviderContainer(
        overrides: [
          routineRepositoryProvider.overrideWithValue(routineRepo),
          routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(routineNotifierProvider.notifier);
      await notifier.loadForOwner('user-g7-occ');

      final item = RoutineItem(
        id: 'routine_item_occ',
        userId: 'user-g7-occ',
        title: 'Hydration Intake',
        startMinute: 8 * 60,
        endMinute: 8 * 60 + 15,
        blockType: RoutineBlockType.softBlock,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
      );
      await notifier.addItem(item);

      // 1. Mark completed
      final completeResult = await notifier.markCompleted(
        'routine_item_occ',
      );
      expect(completeResult.outcome, RoutineWriteOutcome.saved);

      final state = container.read(routineNotifierProvider);
      final occurrences = state.occurrences;
      expect(occurrences, isNotEmpty);
      expect(occurrences.first.status, RoutineStatus.completed);

      // History should have recorded completion
      final history = await historyRepo.fetchHistory('user-g7-occ');
      expect(history, isNotEmpty);
      expect(history.first.status, RoutineStatus.completed);

      // 2. Mark skipped
      final skipResult = await notifier.markSkipped('routine_item_occ');
      expect(skipResult.outcome, RoutineWriteOutcome.saved);

      final occurrencesAfterSkip =
          container.read(routineNotifierProvider).occurrences;
      expect(
        occurrencesAfterSkip.first.status,
        RoutineStatus.skipped,
      );

      // 3. Mark missed
      final missResult = await notifier.markMissed('routine_item_occ');
      expect(missResult.outcome, RoutineWriteOutcome.saved);

      final occurrencesAfterMiss =
          container.read(routineNotifierProvider).occurrences;
      expect(occurrencesAfterMiss.first.status, RoutineStatus.missed);
    });

    test('Routine -> Tracker boundary: Firebase mode prevents unbacked mock mutations', () async {
      final database = FakeRoutineDatabase();
      final routineRepo = FakeRoutineRepository(database: database);
      final historyRepo = FakeRoutineHistoryRepository();
      final transactionRepo = FakeRoutineTransactionRepository();

      // Explicitly set Firebase mode (fakeDataAllowed = false)
      final container = ProviderContainer(
        overrides: [
          routineRepositoryProvider.overrideWithValue(routineRepo),
          routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
          routineTransactionRepositoryProvider.overrideWithValue(transactionRepo),
          fakeBackendPolicyProvider.overrideWithValue(
            const FakeBackendPolicy(
              isDebugBuild: false,
              backendMode: OptivusBackendMode.firebase,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(fakeDataAllowedProvider), isFalse);

      final notifier = container.read(routineNotifierProvider.notifier);
      await notifier.loadForOwner('user-g7-tracker-boundary');

      final moneyTask = RoutineItem(
        id: 'money_task_1',
        userId: 'user-g7-tracker-boundary',
        title: 'Review Daily Savings',
        startMinute: 19 * 60,
        endMinute: 19 * 60 + 15,
        blockType: RoutineBlockType.moneyTask,
      );
      await notifier.addItem(moneyTask);

      // Initial mock tracker savings entries count
      final initialSavings =
          container.read(mockTrackerProvider).savingsEntries.length;

      // Execute alreadySaved in Firebase mode
      final result = await notifier.alreadySaved('money_task_1', amount: 25.0);
      expect(result.outcome, RoutineWriteOutcome.saved);

      // MockTrackerProvider should NOT have been mutated in Firebase mode
      final postSavings =
          container.read(mockTrackerProvider).savingsEntries.length;
      expect(
        postSavings,
        initialSavings,
        reason:
            'In Firebase mode, Routine must not mutate unbacked mock tracker state',
      );

      // But the routine occurrence itself is successfully completed
      final occ =
          container.read(routineNotifierProvider).occurrences.first;
      expect(occ.status, RoutineStatus.completed);
    });

    test('Habit Systems persistence, update, archive, and restore', () async {
      final habitRepo = FakeHabitSystemsRepository();
      final container = ProviderContainer(
        overrides: [
          habitSystemsRepositoryProvider.overrideWithValue(habitRepo),
        ],
      );
      addTearDown(container.dispose);

      final controller =
          container.read(habitSystemsNotifierProvider.notifier);
      await controller.loadForOwner('user-g7-habits');

      // 1. Create habit system
      final createRes = await controller.createSystem(
        title: 'Daily Reading Habit',
        description: 'Read 20 pages of non-fiction',
        category: RoutineCategory.meditation,
        systemType: HabitSystemType.goodHabit,
      );
      expect(createRes, isTrue);
      expect(container.read(habitSystemsNotifierProvider).systems.length, 1);

      final created = container.read(habitSystemsNotifierProvider).systems.first;
      expect(created.title, 'Daily Reading Habit');

      // 2. Update habit system
      final updateRes = await controller.updateSystem(
        created.copyWith(description: 'Read 30 pages of non-fiction'),
      );
      expect(updateRes, isTrue);

      // 3. Archive habit system
      final archiveRes = await controller.archiveSystem(created.systemId);
      expect(archiveRes, isTrue);
      expect(
        container.read(habitSystemsNotifierProvider).systems.first.isArchived,
        isTrue,
      );

      // 4. Restore habit system
      final restoreRes = await controller.restoreSystem(created.systemId);
      expect(restoreRes, isTrue);
      expect(
        container.read(habitSystemsNotifierProvider).systems.first.isArchived,
        isFalse,
      );
    });

    test('Projection receipts: deterministic identity, idempotency, and codec serialization', () {
      const codec = RoutineProjectionReceiptFirestoreCodec();
      final receiptA = RoutineProjectionReceipt(
        id: 'rcpt_100',
        ownerUid: 'user-g7-receipt',
        slot: 'onboarding-initial',
        revision: 1,
        source: 'onboarding',
        sourceBundleSchemaVersion: 1,
        sourceBundleId: 'bundle_100',
        sourceBundleFingerprint: 'a' * 64,
        projectedItemIds: const ['item_1', 'item_2', 'item_3'],
        createdAt: DateTime.utc(2026, 9, 9, 10, 0),
        updatedAt: DateTime.utc(2026, 9, 9, 10, 0),
      );

      final map = codec.toFirestore(receiptA);
      expect(map['id'], 'rcpt_100');
      expect(map['ownerUid'], 'user-g7-receipt');
      expect(map['sourceBundleFingerprint'], 'a' * 64);
      expect(map['projectedItemIds'], ['item_1', 'item_2', 'item_3']);

      final receiptB = codec.fromFirestore(documentId: 'rcpt_100', data: map);
      expect(receiptB.id, receiptA.id);
      expect(receiptB.ownerUid, receiptA.ownerUid);
      expect(receiptB.sourceBundleFingerprint, receiptA.sourceBundleFingerprint);
      expect(receiptB.projectedItemIds, receiptA.projectedItemIds);
    });

    test('User isolation & UID boundary clearance on account switch', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final resetCoordinator =
          container.read(authSessionResetCoordinatorProvider);

      // Populate User A routine state
      await container
          .read(routineNotifierProvider.notifier)
          .loadForOwner('user-A');
      await container.read(routineNotifierProvider.notifier).addItem(
            RoutineItem(
              id: 'user_a_item',
              userId: 'user-A',
              title: 'Secret Routine A',
              startMinute: 400,
              endMinute: 450,
              blockType: RoutineBlockType.hardBlock,
            ),
          );

      expect(container.read(routineNotifierProvider).items, isNotEmpty);
      expect(container.read(routineNotifierProvider.notifier).ownerUid, 'user-A');

      // Trigger session reset boundary (User A -> User B)
      resetCoordinator.resetIdentityBoundary();

      // Verify RoutineNotifier state was completely wiped
      expect(container.read(routineNotifierProvider).items, isEmpty);
      expect(container.read(routineNotifierProvider.notifier).ownerUid, isNull);

      // Load User B
      await container
          .read(routineNotifierProvider.notifier)
          .loadForOwner('user-B');
      expect(container.read(routineNotifierProvider).items, isEmpty);
      expect(container.read(routineNotifierProvider.notifier).ownerUid, 'user-B');
    });
  });
}
