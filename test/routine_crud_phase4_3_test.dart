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

  final Completer<void> _createCompleter = Completer<void>();
  final Completer<void> _updateCompleter = Completer<void>();

  bool pauseCreate = false;
  bool pauseUpdate = false;

  FailingFakeRoutineRepository(FakeRoutineDatabase database) : super(database: database);

  @override
  Future<RoutineItem> createRoutineItem(String uid, RoutineItem item) async {
    if (pauseCreate) {
      await _createCompleter.future;
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
          routineHistoryRepositoryProvider.overrideWithValue(FakeRoutineHistoryRepository()),
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
        ],
      );
      notifier = container.read(routineNotifierProvider.notifier);
      await notifier.loadForOwner('user-a');
    });

    test('create failure enters not-saved state, then retry succeeds', () async {
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
      expect(state.failedIntentsByItemId['item-1']!.action, RoutineWriteAction.create);

      // Retry
      await notifier.retryFailedOperation('item-1');
      final retryState = container.read(routineNotifierProvider);
      expect(retryState.failedIntentsByItemId, isEmpty);
      final saved = await repo.fetchRoutineItems('user-a');
      expect(saved.length, 1);
      expect(saved.first.title, 'New Item');
    });

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
      expect(state.failedIntentsByItemId['item-2']!.action, RoutineWriteAction.update);
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

    test('reload during a pending write preserves local optimistic item', () async {
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
    });
  });
}
