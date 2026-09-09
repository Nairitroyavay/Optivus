import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/models/routine_item.dart';

void main() {
  late ProviderContainer container;
  late FakeRoutineRepository repo;
  late FakeRoutineDatabase database;
  late FakeRoutineHistoryRepository historyRepo;

  setUp(() {
    database = FakeRoutineDatabase();
    repo = FakeRoutineRepository(database: database);
    historyRepo = FakeRoutineHistoryRepository();

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

  test('Source-level ownership audit', () {
    final dir = Directory('lib');
    final violatingFiles = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final content = entity.readAsStringSync();
        if (content.contains('mockRoutineProvider')) {
          final normalizedPath = entity.path.replaceAll('\\', '/');
          violatingFiles.add(normalizedPath);
        }
      }
    }
    expect(
      violatingFiles,
      isEmpty,
      reason: 'mockRoutineProvider must have ZERO references in lib/',
    );

    // AuthSessionResetCoordinator resets routineNotifierProvider and cannot leak
    final coordinatorContent = File(
      'lib/services/auth_session_reset_coordinator.dart',
    ).readAsStringSync();
    expect(coordinatorContent, contains('routineNotifierProvider.notifier'));
    expect(coordinatorContent, contains('resetForSignedOut()'));
    expect(
      coordinatorContent,
      isNot(contains('ref.watch(mockRoutineProvider)')),
    );
    expect(
      coordinatorContent,
      isNot(contains('ref.read(mockRoutineProvider)')),
    );
  });

  test('Firebase-mode provider test', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid = 'user_1';
    await repo.createRoutineItem(
      uid,
      RoutineItem(
        id: 'item_1',
        userId: uid,
        title: 'Test',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
      ),
    );
    await notifier.loadForOwner(uid);

    final state = container.read(routineNotifierProvider);
    expect(state.items.length, 1);
    expect(state.items.first.id, 'item_1');
  });

  test('Sign-in loads only owner data', () async {
    final notifier = container.read(routineNotifierProvider.notifier);

    const uid1 = 'user_1';
    await repo.createRoutineItem(
      uid1,
      RoutineItem(
        id: 'item_1',
        userId: uid1,
        title: 'Test 1',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
      ),
    );

    const uid2 = 'user_2';
    await repo.createRoutineItem(
      uid2,
      RoutineItem(
        id: 'item_2',
        userId: uid2,
        title: 'Test 2',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
      ),
    );

    await notifier.loadForOwner(uid1);
    expect(container.read(routineNotifierProvider).items.map((i) => i.id), [
      'item_1',
    ]);

    await notifier.loadForOwner(uid2);
    expect(container.read(routineNotifierProvider).items.map((i) => i.id), [
      'item_2',
    ]);
  });

  test('Sign-out clears everything', () async {
    final notifier = container.read(routineNotifierProvider.notifier);
    const uid1 = 'user_1';
    final template = RoutineItem(
      id: 'item_1',
      userId: uid1,
      title: 'Test 1',
      startMinute: 600,
      endMinute: 660,
      blockType: RoutineBlockType.flexibleTask,
    );
    await repo.createRoutineItem(uid1, template);

    await notifier.loadForOwner(uid1);
    notifier.startFlexibleTask('item_1');
    await Future.delayed(const Duration(milliseconds: 50));

    var state = container.read(routineNotifierProvider);
    expect(state.items, isNotEmpty);
    expect(state.occurrences, isNotEmpty);

    notifier.resetForSignedOut();
    state = container.read(routineNotifierProvider);
    expect(state.items, isEmpty);
    expect(state.occurrences, isEmpty);
    expect(state.pendingItemIds, isEmpty);
    expect(state.pendingOccurrenceIds, isEmpty);
    expect(state.failedIntentsByItemId, isEmpty);
    expect(state.failedOccurrenceIntentsById, isEmpty);
    expect(state.error, isNull);
  });

  test('Account switch isolation', () async {
    final notifier = container.read(routineNotifierProvider.notifier);

    const uid1 = 'user_1';
    await repo.createRoutineItem(
      uid1,
      RoutineItem(
        id: 'item_1',
        userId: uid1,
        title: 'Test 1',
        startMinute: 600,
        endMinute: 660,
        blockType: RoutineBlockType.flexibleTask,
      ),
    );

    await notifier.loadForOwner(uid1);
    expect(container.read(routineNotifierProvider).items.length, 1);

    notifier.resetForSignedOut();

    const uid2 = 'user_2';
    await notifier.loadForOwner(uid2);
    expect(container.read(routineNotifierProvider).items, isEmpty);
  });
}
