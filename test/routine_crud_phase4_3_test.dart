import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';

class FailingFakeRoutineRepository extends FakeRoutineRepository {
  bool failNextCreate = false;
  bool failNextUpdate = false;
  bool failNextDelete = false;
  bool simulateAmbiguousCreate = false;

  final Completer<void> _createCompleter = Completer<void>();
  final Completer<void> _updateCompleter = Completer<void>();

  bool pauseCreate = false;
  bool pauseUpdate = false;

  FailingFakeRoutineRepository(FakeRoutineDatabase database)
    : super(database: database);

  @override
  Future<RoutineItem> createRoutineItem(String uid, RoutineItem item) async {
    if (pauseCreate) {
      await _createCompleter.future;
    }
    if (simulateAmbiguousCreate) {
      simulateAmbiguousCreate = false;
      await super.createRoutineItem(uid, item);
      throw Exception('Ambiguous network timeout');
    }
    if (failNextCreate) {
      failNextCreate = false;
      throw Exception('Create failed');
    }
    return super.createRoutineItem(uid, item);
  }

  void unpauseCreate() {
    if (!_createCompleter.isCompleted) {
      _createCompleter.complete();
    }
  }

  @override
  Future<RoutineItem> updateRoutineItem(String uid, RoutineItem item) async {
    if (pauseUpdate) {
      await _updateCompleter.future;
    }
    if (failNextUpdate) {
      failNextUpdate = false;
      throw Exception('Update failed');
    }
    return super.updateRoutineItem(uid, item);
  }

  void unpauseUpdate() {
    if (!_updateCompleter.isCompleted) {
      _updateCompleter.complete();
    }
  }

  @override
  Future<void> deleteRoutineItem(String uid, String itemId) async {
    if (failNextDelete) {
      failNextDelete = false;
      throw Exception('Delete failed');
    }
    return super.deleteRoutineItem(uid, itemId);
  }
}

void main() {
  group('Phase 4.3 CRUD Tests', () {
    late FakeRoutineDatabase database;
    late FailingFakeRoutineRepository repo;
    late ProviderContainer container;
    late RoutineNotifier notifier;

    setUp(() async {
      database = FakeRoutineDatabase();
      repo = FailingFakeRoutineRepository(database);
      container = ProviderContainer(
        overrides: [
          routineRepositoryProvider.overrideWithValue(repo),
          routineHistoryRepositoryProvider.overrideWithValue(
            FakeRoutineHistoryRepository(),
          ),
          optivusBackendModeProvider.overrideWithValue(
            OptivusBackendMode.firebase,
          ),
        ],
      );
      notifier = container.read(routineNotifierProvider.notifier);
      addTearDown(container.dispose);
      await notifier.loadForOwner('user-a');
    });

    test(
      'create failure enters not-saved state, then retry succeeds',
      () async {
        repo.failNextCreate = true;
        final item = RoutineItem(
          id: 'item-1',
          title: 'New Item',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );

        await notifier.addItem(item);
        final state = container.read(routineNotifierProvider);
        expect(state.pendingItemIds, isEmpty);
        expect(state.failedIntentsByItemId, contains('item-1'));
        expect(
          state.failedIntentsByItemId['item-1']!.action,
          RoutineWriteAction.create,
        );

        // Retry
        await notifier.retryFailedOperation('item-1');
        final retryState = container.read(routineNotifierProvider);
        expect(retryState.failedIntentsByItemId, isEmpty);
        final saved = await repo.fetchRoutineItems('user-a');
        expect(saved.length, 1);
        expect(saved.first.title, 'New Item');
      },
    );

    test('update failure restores prior item and allows dismiss', () async {
      final item = RoutineItem(
        id: 'item-2',
        title: 'Original',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
      );
      await notifier.addItem(item);

      repo.failNextUpdate = true;
      final updatedItem = item.copyWith(title: 'Updated');
      await notifier.updateItem(updatedItem);

      final state = container.read(routineNotifierProvider);
      expect(state.failedIntentsByItemId, contains('item-2'));
      expect(
        state.failedIntentsByItemId['item-2']!.action,
        RoutineWriteAction.update,
      );
      expect(state.items.firstWhere((e) => e.id == 'item-2').title, 'Original');

      notifier.dismissFailedOperation('item-2');
      final dismissState = container.read(routineNotifierProvider);
      expect(dismissState.failedIntentsByItemId, isEmpty);
    });

    test('delete failure retains item', () async {
      final item = RoutineItem(
        id: 'item-3',
        title: 'ToDelete',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
      );
      await notifier.addItem(item);

      repo.failNextDelete = true;
      await notifier.deleteItem('item-3');

      final state = container.read(routineNotifierProvider);
      expect(state.failedIntentsByItemId, contains('item-3'));
      expect(state.items.any((e) => e.id == 'item-3'), isTrue);
    });

    test('account switch during a write ignores the result', () async {
      repo.pauseCreate = true;
      final item = RoutineItem(
        id: 'item-4',
        title: 'Account A Item',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
      );

      final createFuture = notifier.addItem(item);

      await notifier.loadForOwner('user-b');
      repo.unpauseCreate();
      await createFuture;

      final state = container.read(routineNotifierProvider);
      expect(state.items, isEmpty); // user-b has no items

      final dbA = await repo.fetchRoutineItems('user-a');
      expect(dbA.length, 1); // Saved to db, but ignored in UI state
    });

    test(
      'reload during a pending write preserves local optimistic item',
      () async {
        repo.pauseCreate = true;
        final item = RoutineItem(
          id: 'item-5',
          title: 'Pending Item',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );

        final createFuture = notifier.addItem(item);

        // Now reload while create is pending
        await notifier.loadForOwner('user-a');

        final state = container.read(routineNotifierProvider);
        expect(state.pendingItemIds, contains('item-5'));
        expect(state.items.length, 1);
        expect(state.items.first.title, 'Pending Item');

        repo.unpauseCreate();
        await createFuture;

        final finalState = container.read(routineNotifierProvider);
        expect(finalState.pendingItemIds, isEmpty);
      },
    );

    test(
      '1. update failure -> rollback -> retry succeeds -> Firestore/UI updated',
      () async {
        final item = RoutineItem(
          id: 'item-u1',
          title: 'Original',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await notifier.addItem(item);

        repo.failNextUpdate = true;
        final updatedItem = item.copyWith(title: 'Updated');
        await notifier.updateItem(updatedItem);

        // Retry succeeds
        await notifier.retryFailedOperation('item-u1');

        final state = container.read(routineNotifierProvider);
        expect(
          state.items.firstWhere((e) => e.id == 'item-u1').title,
          'Updated',
        );
        expect(state.failedIntentsByItemId, isEmpty);

        final saved = await repo.fetchRoutineItems('user-a');
        expect(saved.firstWhere((e) => e.id == 'item-u1').title, 'Updated');
      },
    );

    test(
      '2. delete failure -> item remains -> retry succeeds -> cleanup occurs',
      () async {
        final item = RoutineItem(
          id: 'item-d1',
          title: 'To Delete',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await notifier.addItem(item);

        repo.failNextDelete = true;
        await notifier.deleteItem('item-d1');

        // Retry succeeds
        await notifier.retryFailedOperation('item-d1');

        final state = container.read(routineNotifierProvider);
        expect(state.items.any((e) => e.id == 'item-d1'), isFalse);
        expect(state.failedIntentsByItemId, isEmpty);

        final saved = await repo.fetchRoutineItems('user-a');
        expect(saved.any((e) => e.id == 'item-d1'), isFalse);
      },
    );

    test(
      '3. duplicate action on one pending item is safely serialized',
      () async {
        final item = RoutineItem(
          id: 'item-dup',
          title: 'Dup',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        repo.pauseCreate = true;

        final future1 = notifier.addItem(item);
        final future2 = notifier.addItem(item);

        repo.unpauseCreate();
        await future1;
        await future2;

        final saved = await repo.fetchRoutineItems('user-a');
        expect(saved.where((e) => e.id == 'item-dup').length, 1);
      },
    );

    test(
      '4. ambiguous successful create recovery does not create duplicates',
      () async {
        repo.simulateAmbiguousCreate = true;
        final item = RoutineItem(
          id: 'item-ambig',
          title: 'Ambig',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await notifier.addItem(item);

        final state = container.read(routineNotifierProvider);
        expect(state.failedIntentsByItemId, isEmpty);
        expect(state.pendingItemIds, isEmpty);
        expect(state.items.where((e) => e.id == 'item-ambig').length, 1);

        final saved = await repo.fetchRoutineItems('user-a');
        expect(saved.where((e) => e.id == 'item-ambig').length, 1);
      },
    );

    test(
      '5. same-owner reload during pending update preserves correct local state',
      () async {
        final item = RoutineItem(
          id: 'item-5u',
          title: 'Original',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await notifier.addItem(item);

        repo.pauseUpdate = true;
        final updatedItem = item.copyWith(title: 'Updated Pending');
        final updateFuture = notifier.updateItem(updatedItem);

        await notifier.loadForOwner('user-a');

        final state = container.read(routineNotifierProvider);
        expect(state.pendingItemIds, contains('item-5u'));
        expect(
          state.items.firstWhere((e) => e.id == 'item-5u').title,
          'Updated Pending',
        );

        repo.unpauseUpdate();
        await updateFuture;
      },
    );

    test(
      '6. account switch during update cannot modify the new owner’s UI',
      () async {
        final item = RoutineItem(
          id: 'item-6u',
          title: 'Original',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await notifier.addItem(item);

        repo.pauseUpdate = true;
        final updatedItem = item.copyWith(title: 'Updated Pending');
        final updateFuture = notifier.updateItem(updatedItem);

        await notifier.loadForOwner('user-b');
        repo.unpauseUpdate();
        await updateFuture;

        final state = container.read(routineNotifierProvider);
        expect(state.items.any((e) => e.id == 'item-6u'), isFalse);
      },
    );

    test(
      '7. initial loading UI does not render the empty state prematurely',
      () async {
        repo.pauseCreate =
            true; // Use this to pause something else if we could, but we can just check state.loading immediately.
        expect(container.read(routineNotifierProvider).loading, isFalse);

        final loadFuture = notifier.loadForOwner('user-b');
        expect(container.read(routineNotifierProvider).loading, isTrue);
        expect(container.read(routineNotifierProvider).items, isEmpty);

        await loadFuture;
        expect(container.read(routineNotifierProvider).loading, isFalse);
      },
    );

    test(
      '8. Firestore update retry with the same lastMutationOperationId is idempotent',
      () async {
        final item = RoutineItem(
          id: 'item-8u',
          title: 'Original',
          startMinute: 600,
          endMinute: 660,
          blockType: RoutineBlockType.flexibleTask,
        );
        await notifier.addItem(item);

        final updatedItem = item.copyWith(title: 'Updated Idempotent');
        await notifier.updateItem(updatedItem);

        final saved = await repo.fetchRoutineItems('user-a');
        final actualItem = saved.firstWhere((e) => e.id == 'item-8u');

        // Attempt an update with the same operationId manually
        final duplicateUpdate = actualItem.copyWith(title: 'Should Be Ignored');
        final returnedItem = await repo.updateRoutineItem(
          'user-a',
          duplicateUpdate,
        );

        // Should return the canonical record without modifying it, so title is still 'Updated Idempotent'
        expect(returnedItem.title, 'Updated Idempotent');

        final verifySaved = await repo.fetchRoutineItems('user-a');
        expect(
          verifySaved.firstWhere((e) => e.id == 'item-8u').title,
          'Updated Idempotent',
        );
      },
    );
  });
}
