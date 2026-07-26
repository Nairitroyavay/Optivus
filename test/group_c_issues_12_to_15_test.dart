import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/habit_system_operation.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/habit_system_onboarding_projection.dart';
import 'package:optivus/services/habit_system_schedule_reconciler.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';

import 'helpers/fake_habit_systems_repository.dart';

void main() {
  group('Issue 12: Habit system record owner UID matching and validation', () {
    test(
      'HabitSystemRecord constructor validates non-empty valid ownerUid',
      () {
        expect(
          () => HabitSystemRecord(
            systemId: 'sys_1',
            ownerUid: '',
            title: 'Test',
            category: RoutineCategory.habit,
            systemType: HabitSystemType.goodHabit,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => HabitSystemRecord(
            systemId: 'sys_1',
            ownerUid: 'invalid/uid',
            title: 'Test',
            category: RoutineCategory.habit,
            systemType: HabitSystemType.goodHabit,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('HabitSystemRecord.fromMap validates ownerUid', () {
      final map = {
        'systemId': 'sys_1',
        'ownerUid': '',
        'title': 'Test',
        'category': 'habit',
        'systemType': 'goodHabit',
        'status': 'active',
      };
      expect(
        () => HabitSystemRecord.fromMap(map),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('HabitSystemOnboardingProjection.build validates bundle.uid', () {
      final bundle = OnboardingCompletionBundle.fromMap({'uid': ' '});

      expect(
        () => HabitSystemOnboardingProjection.build(bundle, []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'FakeHabitSystemsRepository rejects owner UID mismatch on update',
      () async {
        final repo = FakeHabitSystemsRepository();
        final record = HabitSystemRecord(
          systemId: 'sys_1',
          ownerUid: 'user_1',
          title: 'Original',
          category: RoutineCategory.habit,
          systemType: HabitSystemType.goodHabit,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repo.createSystem(system: record, operationId: 'op_1');

        final mismatchedRecord = record.copyWith(
          ownerUid: 'user_2',
          title: 'Mutated',
        );

        expect(
          repo.updateSystem(
            system: mismatchedRecord,
            expectedVersion: 1,
            operationId: 'op_2',
          ),
          throwsA(isA<HabitSystemWriteConflict>()),
        );
      },
    );

    test(
      'HabitSystemsNotifier updateSystem rejects mismatched ownerUid',
      () async {
        final repo = FakeHabitSystemsRepository();
        final container = ProviderContainer(
          overrides: [habitSystemsRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(habitSystemsNotifierProvider.notifier);
        await notifier.loadForOwner('user_1');

        await notifier.createSystem(
          title: 'User 1 Habit',
          category: RoutineCategory.habit,
          systemType: HabitSystemType.goodHabit,
        );

        final created = container
            .read(habitSystemsNotifierProvider)
            .systems
            .first;
        final leakedRecord = created.copyWith(ownerUid: 'user_2');

        final success = await notifier.updateSystem(leakedRecord);
        expect(success, isFalse);
      },
    );
  });

  group('Issue 13: Habit system batch operation transactional integrity', () {
    test(
      'reconcileProjectedSystems batch reconciles all systems atomically',
      () async {
        final repo = FakeHabitSystemsRepository();
        final now = DateTime.now().toUtc();

        final sys1 = HabitSystemRecord(
          systemId: 'sys_batch_1',
          ownerUid: 'user_batch',
          title: 'System 1',
          category: RoutineCategory.habit,
          systemType: HabitSystemType.goodHabit,
          onboardingProjectionId: 'proj_batch_123',
          createdAt: now,
          updatedAt: now,
        );

        final sys2 = HabitSystemRecord(
          systemId: 'sys_batch_2',
          ownerUid: 'user_batch',
          title: 'System 2',
          category: RoutineCategory.badHabit,
          systemType: HabitSystemType.badHabit,
          onboardingProjectionId: 'proj_batch_123',
          createdAt: now,
          updatedAt: now,
        );

        final result = await repo.reconcileProjectedSystems(
          ownerUid: 'user_batch',
          projectionId: 'proj_batch_123',
          systems: [sys1, sys2],
        );

        expect(result.success, isTrue);

        final savedSystems = await repo.fetchHabitSystems('user_batch');
        expect(savedSystems.length, equals(2));
        expect(
          savedSystems.map((s) => s.systemId).toSet(),
          containsAll(['sys_batch_1', 'sys_batch_2']),
        );
      },
    );

    test(
      'OnboardingFrontendHydrationService invokes reconcileProjectedSystems',
      () async {
        final routineRepo = FakeRoutineRepository();
        final container = ProviderContainer(
          overrides: [
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.fake,
            ),
            habitSystemsRepositoryProvider.overrideWithValue(
              FakeHabitSystemsRepository(),
            ),
            routineRepositoryProvider.overrideWithValue(routineRepo),
          ],
        );
        addTearDown(container.dispose);

        final bundle = OnboardingCompletionBundle.fromMap({
          'uid': 'user_hydration',
          'goodHabitTemplates': [
            {
              'id': 'g_1',
              'systemKey': 'exercise',
              'title': 'Morning Exercise',
              'durationMinutes': 30,
            },
          ],
        });

        final projection = RoutineOnboardingProjection.build(bundle);
        routineRepo.database.receiptsByUid.putIfAbsent(
          'user_hydration',
          () => {},
        )[projection.projectionId] = projection.receipt;

        const service = OnboardingFrontendHydrationService();
        await service.hydrate(read: container.read, bundle: bundle);

        final repo = container.read(habitSystemsRepositoryProvider);
        final systems = await repo.fetchHabitSystems('user_hydration');
        expect(systems.isNotEmpty, isTrue);
        expect(systems.first.title, equals('Morning Exercise'));
      },
    );
  });

  group(
    'Issue 14: Habit system hydration fallback when remote projection is pending',
    () {
      test(
        'loadForOwnerWithFallback renders in-memory projected systems when remote is empty',
        () async {
          final repo = FakeHabitSystemsRepository();
          final container = ProviderContainer(
            overrides: [habitSystemsRepositoryProvider.overrideWithValue(repo)],
          );
          addTearDown(container.dispose);

          final bundle = OnboardingCompletionBundle.fromMap({
            'uid': 'user_fallback',
            'goodHabitTemplates': [
              {
                'id': 'g_fb_1',
                'systemKey': 'reading',
                'title': 'Daily Reading',
                'durationMinutes': 20,
              },
            ],
          });

          final notifier = container.read(
            habitSystemsNotifierProvider.notifier,
          );
          await notifier.loadForOwnerWithFallback(
            'user_fallback',
            bundle: bundle,
          );

          final state = container.read(habitSystemsNotifierProvider);
          expect(state.systems.length, equals(1));
          expect(state.systems.first.title, equals('Daily Reading'));
        },
      );

      test(
        'loadForOwnerWithFallback merges remote and fallback systems without duplicates',
        () async {
          final repo = FakeHabitSystemsRepository();
          final container = ProviderContainer(
            overrides: [habitSystemsRepositoryProvider.overrideWithValue(repo)],
          );
          addTearDown(container.dispose);

          final bundle = OnboardingCompletionBundle.fromMap({
            'uid': 'user_merge',
            'goodHabitTemplates': [
              {
                'id': 'g_m1',
                'systemKey': 'journaling',
                'title': 'Evening Journaling',
                'durationMinutes': 15,
              },
            ],
          });

          final projectedSystems = HabitSystemOnboardingProjection.build(
            bundle,
            [],
          );
          expect(projectedSystems.isNotEmpty, isTrue);
          final projSystem = projectedSystems.first;

          await repo.createSystem(system: projSystem, operationId: 'op_remote');

          final notifier = container.read(
            habitSystemsNotifierProvider.notifier,
          );
          await notifier.loadForOwnerWithFallback('user_merge', bundle: bundle);

          final state = container.read(habitSystemsNotifierProvider);
          expect(state.systems.length, equals(1));
          expect(state.systems.first.systemId, equals(projSystem.systemId));
        },
      );
    },
  );

  group('Issue 15: Habit system schedule frequency update reconciliation', () {
    const reconciler = HabitSystemScheduleReconciler();

    test(
      'pruneOrphanedRoutineIds removes routine IDs that no longer exist',
      () {
        final now = DateTime.now();
        final system = HabitSystemRecord(
          systemId: 'sys_prune',
          ownerUid: 'user_1',
          title: 'Prune Test',
          category: RoutineCategory.habit,
          systemType: HabitSystemType.goodHabit,
          linkedRoutineIds: const ['routine_exist', 'routine_orphan'],
          createdAt: now,
          updatedAt: now,
        );

        final pruned = reconciler.pruneOrphanedRoutineIds(system, {
          'routine_exist',
        });
        expect(pruned.linkedRoutineIds, equals(['routine_exist']));
      },
    );

    test(
      'propagateStatusToRoutines updates linked routine status and repeatDays',
      () {
        final now = DateTime.now();
        final routine = RoutineItem(
          id: 'r_1',
          title: 'Meditation Task',
          startMinute: 480,
          endMinute: 510,
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.meditation,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        );

        final activeSystem = HabitSystemRecord(
          systemId: 'sys_act',
          ownerUid: 'user_1',
          title: 'Active System',
          category: RoutineCategory.habit,
          systemType: HabitSystemType.goodHabit,
          status: HabitSystemStatus.paused,
          linkedRoutineIds: const ['r_1'],
          createdAt: now,
          updatedAt: now,
        );

        final pausedRoutines = reconciler.propagateStatusToRoutines(
          system: activeSystem,
          routines: [routine],
        );

        expect(pausedRoutines.first.repeatDays, isEmpty);
        expect(pausedRoutines.first.status, equals(RoutineStatus.planned));
        // Routine item itself is NOT hard-deleted (R11 compliance)
        expect(pausedRoutines.length, equals(1));
      },
    );

    test('synchronizeFrequency updates repeatDays without data deletion', () {
      final now = DateTime.now();
      final routine = RoutineItem(
        id: 'r_freq',
        title: 'Workout',
        startMinute: 420,
        endMinute: 480,
        blockType: RoutineBlockType.trackerTask,
        category: RoutineCategory.health,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
      );

      final system = HabitSystemRecord(
        systemId: 'sys_freq',
        ownerUid: 'user_1',
        title: 'Workout System',
        category: RoutineCategory.habit,
        systemType: HabitSystemType.goodHabit,
        linkedRoutineIds: const ['r_freq'],
        createdAt: now,
        updatedAt: now,
      );

      final updatedRoutines = reconciler.synchronizeFrequency(
        system: system,
        routines: [routine],
        repeatDays: const [1, 3, 5],
      );

      expect(updatedRoutines.first.repeatDays, equals([1, 3, 5]));
      expect(updatedRoutines.first.id, equals('r_freq'));
    });
  });
}
