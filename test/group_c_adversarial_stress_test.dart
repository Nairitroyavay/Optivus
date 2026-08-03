import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/services/habit_system_onboarding_projection.dart';
import 'package:optivus/services/habit_system_schedule_reconciler.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';

import 'helpers/fake_habit_systems_repository.dart';

void main() {
  group('Adversarial Test Suite — Group C (Issues 12–15)', () {
    // =========================================================================
    // ISSUE 12: OWNER UID SECURITY & MISMATCH STRESS TESTING
    // =========================================================================
    group('Issue 12: Owner UID Validation & Mismatch Security', () {
      test(
        'Adversarial: Constructor rejects empty, whitespace, and slash UIDs',
        () {
          final invalidUids = ['', '   ', '\t\n', 'user/123', 'user/sub/id'];
          for (final uid in invalidUids) {
            expect(
              () => HabitSystemRecord(
                systemId: 'sys_1',
                ownerUid: uid,
                title: 'Adversarial Test',
                category: RoutineCategory.habit,
                systemType: HabitSystemType.goodHabit,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
              throwsA(isA<ArgumentError>()),
              reason: 'Failed to reject invalid UID: "$uid"',
            );
          }
        },
      );

      test('Adversarial: fromMap rejects invalid ownerUid inputs', () {
        final invalidMaps = [
          {'systemId': 'sys_1', 'ownerUid': '', 'title': 'T'},
          {'systemId': 'sys_1', 'ownerUid': '   ', 'title': 'T'},
          {'systemId': 'sys_1', 'ownerUid': 'uid/slash', 'title': 'T'},
          {'systemId': 'sys_1', 'title': 'T'}, // missing ownerUid
        ];

        for (final map in invalidMaps) {
          expect(
            () => HabitSystemRecord.fromMap(map),
            throwsA(isA<ArgumentError>()),
            reason: 'fromMap failed to reject map with invalid ownerUid: $map',
          );
        }
      });

      test(
        'Adversarial: HabitSystemOnboardingProjection rejects corrupt bundle UID',
        () {
          final corruptUids = ['', '  ', 'user/admin'];
          for (final uid in corruptUids) {
            final bundle = OnboardingCompletionBundle.fromMap({'uid': uid});
            expect(
              () => HabitSystemOnboardingProjection.build(bundle, []),
              throwsA(isA<ArgumentError>()),
              reason: 'Projection failed to reject corrupt bundle UID: "$uid"',
            );
          }
        },
      );

      test(
        'Adversarial: Controller loadForOwner rejects empty or slash UID',
        () async {
          final repo = FakeHabitSystemsRepository();
          final container = ProviderContainer(
            overrides: [habitSystemsRepositoryProvider.overrideWithValue(repo)],
          );
          addTearDown(container.dispose);

          final notifier = container.read(
            habitSystemsNotifierProvider.notifier,
          );

          expect(
            () => notifier.loadForOwnerWithFallback(''),
            throwsA(isA<ArgumentError>()),
          );

          expect(
            () => notifier.loadForOwnerWithFallback('bad/uid'),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test(
        'Adversarial: Cross-user update attack in Controller is rejected',
        () async {
          final repo = FakeHabitSystemsRepository();
          final container = ProviderContainer(
            overrides: [habitSystemsRepositoryProvider.overrideWithValue(repo)],
          );
          addTearDown(container.dispose);

          final notifier = container.read(
            habitSystemsNotifierProvider.notifier,
          );
          await notifier.loadForOwner('user_victim');

          await notifier.createSystem(
            title: 'Victim System',
            category: RoutineCategory.habit,
            systemType: HabitSystemType.goodHabit,
          );

          final victimSystem = container
              .read(habitSystemsNotifierProvider)
              .systems
              .first;

          // Attacker creates a record with user_attacker UID trying to modify victim's systemId
          final attackerRecord = victimSystem.copyWith(
            ownerUid: 'user_attacker',
            title: 'Hacked Title',
          );

          final result = await notifier.updateSystem(attackerRecord);
          expect(result, isFalse);

          final systemAfterAttack = container
              .read(habitSystemsNotifierProvider)
              .systems
              .first;
          expect(systemAfterAttack.title, equals('Victim System'));
          expect(systemAfterAttack.ownerUid, equals('user_victim'));
        },
      );

      test(
        'Adversarial: Cross-user reconcileProjectedSystems is rejected',
        () async {
          final repo = FakeHabitSystemsRepository();
          final now = DateTime.now().toUtc();

          final attackerSystem = HabitSystemRecord(
            systemId: 'sys_attack_1',
            ownerUid: 'attacker_uid',
            title: 'Malicious System',
            category: RoutineCategory.habit,
            systemType: HabitSystemType.goodHabit,
            createdAt: now,
            updatedAt: now,
          );

          expect(
            () => repo.reconcileProjectedSystems(
              ownerUid: 'target_victim_uid',
              projectionId: 'proj_test_123',
              systems: [attackerSystem],
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
      );
    });

    // =========================================================================
    // ISSUE 13: BATCH RECONCILIATION INTEGRITY & SCALE (0, 1, 10 SYSTEMS)
    // =========================================================================
    group('Issue 13: Batch Reconciliation Scale & Boundary Tests', () {
      test(
        'Boundary: Batch reconciliation with 0 habit systems succeeds',
        () async {
          final repo = FakeHabitSystemsRepository();
          final result = await repo.reconcileProjectedSystems(
            ownerUid: 'user_scale_0',
            projectionId: 'proj_0_systems',
            systems: [],
          );

          expect(result.success, isTrue);
          expect(result.system, isNull);

          final saved = await repo.fetchHabitSystems('user_scale_0');
          expect(saved, isEmpty);
        },
      );

      test(
        'Boundary: Batch reconciliation with 1 habit system succeeds',
        () async {
          final repo = FakeHabitSystemsRepository();
          final now = DateTime.now().toUtc();

          final sys = HabitSystemRecord(
            systemId: 'sys_single_1',
            ownerUid: 'user_scale_1',
            title: 'Single Habit System',
            category: RoutineCategory.habit,
            systemType: HabitSystemType.goodHabit,
            createdAt: now,
            updatedAt: now,
          );

          final result = await repo.reconcileProjectedSystems(
            ownerUid: 'user_scale_1',
            projectionId: 'proj_1_system',
            systems: [sys],
          );

          expect(result.success, isTrue);
          expect(result.system?.systemId, equals('sys_single_1'));

          final saved = await repo.fetchHabitSystems('user_scale_1');
          expect(saved.length, equals(1));
          expect(saved.first.title, equals('Single Habit System'));
        },
      );

      test(
        'Scale Test: Batch reconciliation with 10 habit systems executes atomically',
        () async {
          final repo = FakeHabitSystemsRepository();
          final now = DateTime.now().toUtc();
          final uid = 'user_scale_10';

          final tenSystems = List.generate(
            10,
            (i) => HabitSystemRecord(
              systemId: 'sys_batch_10_$i',
              ownerUid: uid,
              title: 'Habit System #$i',
              category: RoutineCategory.habit,
              systemType: i % 2 == 0
                  ? HabitSystemType.goodHabit
                  : HabitSystemType.badHabit,
              onboardingProjectionId: 'proj_scale_10',
              createdAt: now,
              updatedAt: now,
            ),
          );

          final result = await repo.reconcileProjectedSystems(
            ownerUid: uid,
            projectionId: 'proj_scale_10',
            systems: tenSystems,
          );

          expect(result.success, isTrue);

          final saved = await repo.fetchHabitSystems(uid);
          expect(saved.length, equals(10));
          final savedIds = saved.map((s) => s.systemId).toSet();
          for (var i = 0; i < 10; i++) {
            expect(savedIds.contains('sys_batch_10_$i'), isTrue);
          }
        },
      );

      test(
        'Idempotency: Re-reconciling same 10 habit systems does not duplicate',
        () async {
          final repo = FakeHabitSystemsRepository();
          final now = DateTime.now().toUtc();
          final uid = 'user_scale_idem';

          final tenSystems = List.generate(
            10,
            (i) => HabitSystemRecord(
              systemId: 'sys_idem_$i',
              ownerUid: uid,
              title: 'Habit System #$i',
              category: RoutineCategory.habit,
              systemType: HabitSystemType.goodHabit,
              source: 'onboarding',
              onboardingSourceId: 'source_idem_$i',
              onboardingProjectionId: 'proj_idem',
              sourceFingerprint: 'a' * 64,
              createdAt: now,
              updatedAt: now,
            ),
          );

          // First pass
          await repo.reconcileProjectedSystems(
            ownerUid: uid,
            projectionId: 'proj_idem',
            systems: tenSystems,
          );

          // Second pass
          final result2 = await repo.reconcileProjectedSystems(
            ownerUid: uid,
            projectionId: 'proj_idem',
            systems: tenSystems,
          );

          expect(result2.success, isTrue);

          final saved = await repo.fetchHabitSystems(uid);
          expect(saved.length, equals(10));
        },
      );
    });

    // =========================================================================
    // ISSUE 14: FALLBACK HYDRATION & MERGE DEDUPLICATION
    // =========================================================================
    group('Issue 14: Fallback Hydration & Merging Edge Cases', () {
      test(
        'Fallback: Renders in-memory projection when remote returns empty',
        () async {
          final repo = FakeHabitSystemsRepository();
          final container = ProviderContainer(
            overrides: [habitSystemsRepositoryProvider.overrideWithValue(repo)],
          );
          addTearDown(container.dispose);

          final bundle = OnboardingCompletionBundle.fromMap({
            'uid': 'user_pending_remote',
            'goodHabitTemplates': [
              {
                'id': 'ght_1',
                'systemKey': 'hydration_test',
                'title': 'Hydration Habit',
                'durationMinutes': 10,
              },
            ],
          });

          final notifier = container.read(
            habitSystemsNotifierProvider.notifier,
          );
          await notifier.loadForOwnerWithFallback(
            'user_pending_remote',
            bundle: bundle,
          );

          final state = container.read(habitSystemsNotifierProvider);
          expect(state.loading, isFalse);
          expect(state.error, isNull);
          expect(state.systems.length, equals(1));
          expect(state.systems.first.title, equals('Hydration Habit'));
        },
      );

      test(
        'Merge Precedence: Remote data overrides matching in-memory projection',
        () async {
          final repo = FakeHabitSystemsRepository();
          final container = ProviderContainer(
            overrides: [habitSystemsRepositoryProvider.overrideWithValue(repo)],
          );
          addTearDown(container.dispose);

          final bundle = OnboardingCompletionBundle.fromMap({
            'uid': 'user_prec_test',
            'goodHabitTemplates': [
              {
                'id': 'ght_prec',
                'systemKey': 'meditation',
                'title': 'Original Bundle Title',
                'durationMinutes': 15,
              },
            ],
          });

          // Compute stable system ID that projection generates
          final projectedSystems = HabitSystemOnboardingProjection.build(
            bundle,
            [],
          );
          expect(projectedSystems, isNotEmpty);
          final projSystem = projectedSystems.first;

          // Remote database already has an updated version of this system
          final remoteVersion = projSystem.copyWith(
            title: 'User Customized Remote Title',
            description: 'Customized description',
            version: 2,
          );
          await repo.createSystem(
            system: remoteVersion,
            operationId: 'op_remote_seed',
          );

          final notifier = container.read(
            habitSystemsNotifierProvider.notifier,
          );
          await notifier.loadForOwnerWithFallback(
            'user_prec_test',
            bundle: bundle,
          );

          final state = container.read(habitSystemsNotifierProvider);
          expect(state.systems.length, equals(1));
          expect(
            state.systems.first.title,
            equals('User Customized Remote Title'),
          );
          expect(state.systems.first.version, equals(2));
        },
      );
    });

    // =========================================================================
    // ISSUE 15: SCHEDULE RECONCILER & R11 ZERO DATA DELETION VERIFICATION
    // =========================================================================
    group('Issue 15: Schedule Frequency Reconciler & R11 Zero Deletion', () {
      const reconciler = HabitSystemScheduleReconciler();

      test(
        'R11 Compliance: Pausing habit system updates schedule without deleting routine items',
        () {
          final now = DateTime.now().toUtc();
          final routine1 = RoutineItem(
            id: 'r_item_1',
            title: 'Routine Item 1',
            startMinute: 300,
            endMinute: 330,
            blockType: RoutineBlockType.flexibleTask,
            category: RoutineCategory.habit,
            repeatDays: const [1, 2, 3, 4, 5],
          );
          final routine2 = RoutineItem(
            id: 'r_item_2',
            title: 'Routine Item 2',
            startMinute: 360,
            endMinute: 390,
            blockType: RoutineBlockType.flexibleTask,
            category: RoutineCategory.habit,
            repeatDays: const [6, 7],
          );

          final activeSystem = HabitSystemRecord(
            systemId: 'sys_pause_test',
            ownerUid: 'user_r11',
            title: 'Test System',
            category: RoutineCategory.habit,
            systemType: HabitSystemType.goodHabit,
            status: HabitSystemStatus.paused,
            linkedRoutineIds: const ['r_item_1', 'r_item_2'],
            createdAt: now,
            updatedAt: now,
          );

          final updatedRoutines = reconciler.propagateStatusToRoutines(
            system: activeSystem,
            routines: [routine1, routine2],
          );

          // ZERO DATA DELETION CHECK: Number of routines MUST remain 2!
          expect(updatedRoutines.length, equals(2));
          for (final r in updatedRoutines) {
            expect(r.repeatDays, isEmpty);
            expect(r.status, equals(RoutineStatus.planned));
          }
        },
      );

      test(
        'R11 Compliance: Archiving habit system updates schedule without deleting routine items',
        () {
          final now = DateTime.now().toUtc();
          final routine1 = RoutineItem(
            id: 'r_archive_1',
            title: 'Routine Item Archive',
            startMinute: 400,
            endMinute: 430,
            blockType: RoutineBlockType.flexibleTask,
            category: RoutineCategory.habit,
            repeatDays: const [1, 3, 5],
          );

          final archivedSystem = HabitSystemRecord(
            systemId: 'sys_archive_test',
            ownerUid: 'user_r11',
            title: 'Archived System',
            category: RoutineCategory.habit,
            systemType: HabitSystemType.goodHabit,
            status: HabitSystemStatus.archived,
            linkedRoutineIds: const ['r_archive_1'],
            createdAt: now,
            updatedAt: now,
          );

          final updatedRoutines = reconciler.propagateStatusToRoutines(
            system: archivedSystem,
            routines: [routine1],
          );

          // ZERO DATA DELETION CHECK: Routine item must still exist!
          expect(updatedRoutines.length, equals(1));
          expect(updatedRoutines.first.id, equals('r_archive_1'));
          expect(updatedRoutines.first.repeatDays, isEmpty);
          expect(updatedRoutines.first.status, equals(RoutineStatus.planned));
        },
      );

      test(
        'Orphan Pruning: Deleting a routine item prunes ID from habit system linkedRoutineIds',
        () {
          final now = DateTime.now().toUtc();
          final system = HabitSystemRecord(
            systemId: 'sys_orphan_test',
            ownerUid: 'user_orphan',
            title: 'System With Orphan',
            category: RoutineCategory.habit,
            systemType: HabitSystemType.goodHabit,
            linkedRoutineIds: const ['r_kept', 'r_deleted'],
            createdAt: now,
            updatedAt: now,
          );

          // Only r_kept exists in the routine store now
          final existingRoutineIds = {'r_kept'};

          final pruned = reconciler.pruneOrphanedRoutineIds(
            system,
            existingRoutineIds,
          );

          expect(pruned.linkedRoutineIds, equals(['r_kept']));
          expect(pruned.systemId, equals('sys_orphan_test'));
        },
      );
    });
  });
}
