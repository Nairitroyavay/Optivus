import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

void main() {
  group('Base Timeline Concurrency and Revision Tests', () {
    late FakeRoutineRepository routineRepo;
    late FakeOnboardingRepository onboardingRepo;
    late FakeBaseTimelineSetupRepository setupRepo;
    late FakeRoutineTransactionRepository txRepo;
    late BaseTimelineTransactionCoordinator coordinator;

    setUp(() {
      routineRepo = FakeRoutineRepository();
      onboardingRepo = FakeOnboardingRepository();
      setupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: onboardingRepo,
      );
      txRepo = FakeRoutineTransactionRepository(
        routineRepository: routineRepo,
        setupRepository: setupRepo,
      );
      coordinator = BaseTimelineTransactionCoordinator(
        routineRepo: routineRepo,
        setupRepo: setupRepo,
        transactionRepo: txRepo,
      );
    });

    test('Initial setup has current schemaVersion and revision 1', () async {
      final setup = BaseTimelineSetup(
        uid: 'user-rev-1',
        updatedAt: DateTime.now(),
      );
      expect(setup.schemaVersion, BaseTimelineSetup.currentSchemaVersion);
      expect(setup.revision, 1);
      await setupRepo.saveSetup('user-rev-1', setup);

      final fetched = await setupRepo.fetchSetup('user-rev-1');
      expect(fetched.schemaVersion, BaseTimelineSetup.currentSchemaVersion);
      expect(fetched.revision, 1);
    });

    test('replaceSection monotonically increments revision', () async {
      final initialSetup = BaseTimelineSetup(
        uid: 'user-rev-inc',
        updatedAt: DateTime.now(),
      );
      await setupRepo.saveSetup('user-rev-inc', initialSetup);

      final blocks1 = [
        const TimelineBlockDraft(
          id: 'c-1',
          section: 'classes',
          title: 'Class 1',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [1],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ];

      await coordinator.replaceSection(
        uid: 'user-rev-inc',
        section: BaseTimelineSection.classes,
        newBlocks: blocks1,
        updateSetup: (current) => current.copyWith(classBlocks: blocks1),
      );

      final setupAfterFirst = await setupRepo.fetchSetup('user-rev-inc');
      expect(setupAfterFirst.revision, 2);

      final blocks2 = [
        const TimelineBlockDraft(
          id: 'w-1',
          section: 'work',
          title: 'Work Shift',
          startMinute: 800,
          endMinute: 900,
          repeatDays: [1, 2],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ];

      await coordinator.replaceSection(
        uid: 'user-rev-inc',
        section: BaseTimelineSection.work,
        newBlocks: blocks2,
        updateSetup: (current) => current.copyWith(workBlocks: blocks2),
      );

      final setupAfterSecond = await setupRepo.fetchSetup('user-rev-inc');
      expect(setupAfterSecond.revision, 3);
    });

    test(
      'Authoritative invariant: updatedSetup.<section>RoutineItemIds == written item IDs',
      () async {
        final setup = BaseTimelineSetup(
          uid: 'user-auth-ids',
          updatedAt: DateTime.now(),
        );
        await setupRepo.saveSetup('user-auth-ids', setup);

        final blocks = [
          const TimelineBlockDraft(
            id: 'b-1',
            section: 'classes',
            title: 'Math',
            startMinute: 540,
            endMinute: 600,
            repeatDays: [1, 3, 5],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          const TimelineBlockDraft(
            id: 'b-2',
            section: 'classes',
            title: 'Physics',
            startMinute: 660,
            endMinute: 720,
            repeatDays: [2, 4],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        await coordinator.replaceSection(
          uid: 'user-auth-ids',
          section: BaseTimelineSection.classes,
          newBlocks: blocks,
          updateSetup: (current) => current.copyWith(classBlocks: blocks),
        );

        final updatedSetup = await setupRepo.fetchSetup('user-auth-ids');
        final allItems = await routineRepo.fetchRoutineItems('user-auth-ids');
        final writtenClassItemIds = allItems
            .where((i) => i.source == RoutineSource.baseTimeline)
            .map((i) => i.id)
            .toList();

        expect(updatedSetup.classRoutineItemIds, isNotEmpty);
        expect(
          updatedSetup.classRoutineItemIds.toSet(),
          writtenClassItemIds.toSet(),
        );
      },
    );

    test(
      'Optimistic concurrency control: stale revision throws StateError',
      () async {
        final initialSetup = BaseTimelineSetup(
          uid: 'user-occ',
          updatedAt: DateTime.now(),
        );
        await setupRepo.saveSetup('user-occ', initialSetup);

        // Mutate via another path to increment revision in DB to 2
        final concurrentSetup = initialSetup.copyWith(
          revision: 2,
          mealPlanningGoal: 'concurrent_change',
        );
        await setupRepo.saveSetup('user-occ', concurrentSetup);

        // Attempting atomic transaction with expectedRevision = 1 must fail
        expect(
          () async => txRepo.replaceBaseTimelineSection(
            uid: 'user-occ',
            section: BaseTimelineSection.classes,
            expectedRevision: 1, // Stale! Current in DB is 2
            newRoutineItems: [],
            buildUpdatedSetup: (curr) => curr.copyWith(classBlocks: []),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('revision mismatch'),
            ),
          ),
        );
      },
    );

    test('Atomic failure leaves database completely untouched', () async {
      final initialSetup = BaseTimelineSetup(
        uid: 'user-atomic-fail',
        updatedAt: DateTime.now(),
        classRoutineItemIds: const ['existing-class-item'],
      );
      await setupRepo.saveSetup('user-atomic-fail', initialSetup);
      await routineRepo.createRoutineItem(
        'user-atomic-fail',
        RoutineItem(
          id: 'existing-class-item',
          userId: 'user-atomic-fail',
          title: 'Existing Class',
          category: RoutineCategory.classBlock,
          blockType: RoutineBlockType.hardBlock,
          startMinute: 540,
          endMinute: 600,
          repeatDays: const [1],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          source: RoutineSource.baseTimeline,
        ),
      );

      txRepo.onBeforeMutation = () async {
        throw StateError('Simulated network/Firestore outage');
      };

      expect(
        () async => coordinator.replaceSection(
          uid: 'user-atomic-fail',
          section: BaseTimelineSection.classes,
          newBlocks: const [
            TimelineBlockDraft(
              id: 'c-failing',
              section: 'classes',
              title: 'Should Never Commit',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
          updateSetup: (curr) => curr,
        ),
        throwsA(isA<StateError>()),
      );

      // Verify no changes to routine items
      final items = await routineRepo.fetchRoutineItems('user-atomic-fail');
      expect(items.length, 1);
      expect(items.first.id, 'existing-class-item');

      // Verify no changes to setup document
      final setup = await setupRepo.fetchSetup('user-atomic-fail');
      expect(setup.classRoutineItemIds, const ['existing-class-item']);
      expect(setup.revision, 1);
    });

    test('coordinator rejects a stale editor base revision', () async {
      const uid = 'stale-editor';
      final initial = BaseTimelineSetup(
        uid: uid,
        updatedAt: DateTime.utc(2026, 9, 13),
      );
      await setupRepo.saveSetup(uid, initial);
      await setupRepo.saveSetup(
        uid,
        initial.copyWith(revision: 2, mealPlanningGoal: 'remote change'),
      );

      await expectLater(
        coordinator.replaceSection(
          uid: uid,
          section: BaseTimelineSection.classes,
          expectedRevision: 1,
          newBlocks: const [],
          updateSetup: (current) => current.copyWith(classBlocks: const []),
        ),
        throwsA(isA<BaseTimelineConcurrencyException>()),
      );

      final committed = await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.classes,
        expectedRevision: 2,
        newBlocks: const [],
        updateSetup: (current) => current.copyWith(classBlocks: const []),
      );
      expect(committed.revision, 3);
    });

    test('notifier publishes only after a durable save succeeds', () async {
      const uid = 'durable-first';
      final initial = BaseTimelineSetup(
        uid: uid,
        updatedAt: DateTime.utc(2026, 9, 13),
      );
      final repo = _ControllableSetupRepository(initial);
      final notifier = BaseTimelineSetupNotifier(repo, uid);
      addTearDown(notifier.dispose);
      await notifier.load();

      final updated = initial.copyWith(
        revision: 2,
        mealPlanningGoal: 'should not publish',
      );
      repo.failSaves = true;
      await expectLater(notifier.save(updated), throwsStateError);
      expect(notifier.state.requireValue.revision, 1);
      expect(notifier.state.requireValue.mealPlanningGoal, isNull);

      repo.failSaves = false;
      await notifier.save(updated);
      expect(notifier.state.requireValue.revision, 2);
    });

    test('live setup streams are isolated by owner', () async {
      final repo = FakeBaseTimelineSetupRepository();
      final a = BaseTimelineSetupNotifier(repo, 'owner-a');
      final b = BaseTimelineSetupNotifier(repo, 'owner-b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await Future.wait([a.load(), b.load()]);

      await repo.saveSetup(
        'owner-a',
        a.state.requireValue.copyWith(
          revision: 2,
          mealPlanningGoal: 'owner-a-only',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(a.state.requireValue.mealPlanningGoal, 'owner-a-only');
      expect(b.state.requireValue.uid, 'owner-b');
      expect(b.state.requireValue.mealPlanningGoal, isNull);
    });
  });
}

class _ControllableSetupRepository implements BaseTimelineSetupRepository {
  BaseTimelineSetup setup;
  bool failSaves = false;

  _ControllableSetupRepository(this.setup);

  @override
  Future<BaseTimelineSetup> fetchSetup(String uid) async => setup;

  @override
  Future<void> saveSetup(String uid, BaseTimelineSetup updated) async {
    if (failSaves) throw StateError('simulated durable save failure');
    setup = updated;
  }

  @override
  Stream<BaseTimelineSetup?> watchSetup(String uid) => const Stream.empty();
}
