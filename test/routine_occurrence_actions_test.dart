import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

class FailingRoutineHistoryRepository extends FakeRoutineHistoryRepository {
  int failCount;
  int failStartAt;
  int delayMs;
  int _currentFails = 0;
  int appendCallCount = 0;

  FailingRoutineHistoryRepository(
    this.failCount, {
    this.failStartAt = 0,
    this.delayMs = 0,
  });

  @override
  Future<void> appendHistory(String uid, RoutineOccurrenceRecord record) async {
    final callIndex = appendCallCount;
    appendCallCount++;
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    if (callIndex >= failStartAt && _currentFails < failCount) {
      _currentFails++;
      throw Exception('network error');
    }
    return super.appendHistory(uid, record);
  }

  @override
  Future<void> deleteHistory(String uid, String occurrenceId) async {
    final callIndex = appendCallCount;
    appendCallCount++;
    if (callIndex >= failStartAt && _currentFails < failCount) {
      _currentFails++;
      throw Exception('network error');
    }
    return super.deleteHistory(uid, occurrenceId);
  }
}

void main() {
  late ProviderContainer container;
  late FakeRoutineRepository repo;
  late FakeRoutineDatabase database;
  late FailingRoutineHistoryRepository historyRepo;

  setUp(() {
    database = FakeRoutineDatabase();
    repo = FakeRoutineRepository(database: database);
    historyRepo = FailingRoutineHistoryRepository(0);

    container = ProviderContainer(
      overrides: [
        optivusBackendModeProvider.overrideWithValue(
          OptivusBackendMode.firebase,
        ),
        routineRepositoryProvider.overrideWithValue(repo),
        routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
        routineTransactionRepositoryProvider.overrideWith(
          (ref) => FakeRoutineTransactionRepository(
            routineRepository: ref.read(routineRepositoryProvider),
            historyRepository: ref.read(routineHistoryRepositoryProvider),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  RoutineItem createTemplate(String uid, String id) {
    return RoutineItem(
      id: id,
      userId: uid,
      title: 'T',
      startMinute: 600,
      endMinute: 660,
      blockType: RoutineBlockType.flexibleTask,
    );
  }

  Future<void> waitForPending() async {
    while (container
        .read(routineNotifierProvider)
        .pendingOccurrenceIds
        .isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  test('Start, complete, skip, missed actions', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.startFlexibleTask('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    var occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'start').length, 1);

    notifier.markCompleted('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'complete').length, 1);

    notifier.markSkipped('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'skip').length, 1);

    notifier.markMissed('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.action == 'miss').length, 1);

    final state = container.read(routineNotifierProvider);
    expect(state.items.length, 1);
    expect(state.items.first.id, 't1');
  });

  test('Move later (same date)', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    final item = container.read(routineNotifierProvider).items.first;
    notifier.moveItem(
      itemId: item.id,
      date: container.read(routineNotifierProvider).selectedDay,
      startMinute: 60,
      durationMinutes: 60,
    );
    await Future.delayed(const Duration(milliseconds: 50));

    final occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.length, 1);
    expect(occurrences.first.action, 'move');
    expect(occurrences.first.movedToDateKey, isNotNull);
  });

  test('Reschedule (different date)', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.moveToTomorrow(
      container.read(routineNotifierProvider).items.first,
    );
    await Future.delayed(const Duration(milliseconds: 50));

    final occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.length, 1);
    expect(occurrences.first.action, 'reschedule');
    expect(occurrences.first.movedToDateKey, isNotNull);
  });

  test('Undo-to-planned', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.startFlexibleTask('t1');
    await Future.delayed(const Duration(milliseconds: 50));

    expect(container.read(routineNotifierProvider).occurrences.length, 1);

    await notifier.undoOccurrenceAction('t1');
    await Future.delayed(const Duration(milliseconds: 50));

    expect(container.read(routineNotifierProvider).occurrences.length, 0);

    await notifier.loadForOwner(uid);
    expect(container.read(routineNotifierProvider).occurrences.length, 0);
  });

  test('Undo blocked when not undoToPlannedAllowed', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    expect(
      container
          .read(routineNotifierProvider)
          .occurrences
          .last
          .undoToPlannedAllowed,
      true,
    );

    notifier.markSkipped('t1');
    await Future.delayed(const Duration(milliseconds: 50));
    expect(
      container
          .read(routineNotifierProvider)
          .occurrences
          .last
          .undoToPlannedAllowed,
      false,
    );
    expect(
      container.read(routineNotifierProvider).occurrences.last.action,
      'skip',
    );

    await notifier.undoOccurrenceAction('t1');
    await Future.delayed(const Duration(milliseconds: 50));

    expect(
      container.read(routineNotifierProvider).occurrences.last.action,
      'skip',
    );
  });

  test('Duplicate tap serialization', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');
    notifier.markCompleted('t1');
    await Future.delayed(const Duration(milliseconds: 50));

    expect(container.read(routineNotifierProvider).occurrences.length, 1);
  });

  test('Failure and retry', () async {
    historyRepo.failCount = 1;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');
    await Future.delayed(const Duration(milliseconds: 50));

    final state = container.read(routineNotifierProvider);
    expect(state.failedOccurrenceIntentsById, isNotEmpty);

    final intent = state.failedOccurrenceIntentsById.values.first;
    await notifier.retryFailedOccurrenceAction(intent.occurrenceId);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(
      container.read(routineNotifierProvider).failedOccurrenceIntentsById,
      isEmpty,
    );
    expect(container.read(routineNotifierProvider).occurrences.length, 1);
  });

  test('deleteHistory idempotent', () async {
    const uid = 'user_1';
    await expectLater(
      historyRepo.deleteHistory(uid, 'nonexistent_id'),
      completes,
    );
  });

  test('Account switch during pending', () async {
    historyRepo.failCount = 999;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');
    // Don't wait for completion

    notifier.resetForSignedOut();
    expect(
      container.read(routineNotifierProvider).pendingOccurrenceIds,
      isEmpty,
    );
  });

  test('Reload during pending', () async {
    historyRepo.failCount = 0;
    historyRepo.delayMs = 100;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');

    await notifier.loadForOwner(uid);
    expect(
      container.read(routineNotifierProvider).pendingOccurrenceIds,
      isNotEmpty,
    );
    await waitForPending();
  });

  test('Two identical rapid completion actions', () async {
    historyRepo.delayMs = 50;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.markCompleted('t1');
    notifier.markCompleted('t1');
    await waitForPending();

    expect(historyRepo.appendCallCount, 1);
  });

  test('Two different rapid move actions', () async {
    historyRepo.delayMs = 50;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    final item = container.read(routineNotifierProvider).items.first;

    notifier.moveToTomorrow(item);
    notifier.moveItem(
      itemId: item.id,
      date: container.read(routineNotifierProvider).selectedDay,
      startMinute: 60,
      durationMinutes: 60,
    );
    await waitForPending();

    final occurrences = container.read(routineNotifierProvider).occurrences;
    expect(occurrences.where((o) => o.routineItemId == 't1').length, 1);
    expect(occurrences.last.action, 'move');
  });

  test('Account switch while queued actions exist', () async {
    historyRepo.delayMs = 50;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.startFlexibleTask('t1');
    notifier.resetForSignedOut();

    await waitForPending();
    final state = container.read(routineNotifierProvider);
    expect(state.queuedOccurrenceIntentsById, isEmpty);
  });

  test('First action fails and a newer queued action succeeds', () async {
    historyRepo.failCount = 1;
    historyRepo.failStartAt = 0;
    historyRepo.delayMs = 50;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.startFlexibleTask('t1');
    notifier.markCompleted('t1');
    await waitForPending();

    final state = container.read(routineNotifierProvider);
    expect(state.failedOccurrenceIntentsById, isEmpty);
    final occurrences = state.occurrences.where((o) => o.routineItemId == 't1');
    expect(occurrences.last.action, 'complete');
  });

  test('Latest queued action fails', () async {
    historyRepo.failCount = 1;
    historyRepo.failStartAt = 1;
    historyRepo.delayMs = 50;
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(uid, createTemplate(uid, 't1'));
    await notifier.loadForOwner(uid);

    notifier.startFlexibleTask('t1');
    notifier.markCompleted('t1');
    await waitForPending();

    final state = container.read(routineNotifierProvider);
    expect(state.failedOccurrenceIntentsById, isNotEmpty);

    final occurrences = state.occurrences.where((o) => o.routineItemId == 't1');
    expect(occurrences.last.action, 'start');
  });
}
