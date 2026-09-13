import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

void main() {
  group('Base Timeline Survivors and Zero Conflict Tests', () {
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

    test(
      'Manual items and imported items survive section replacement',
      () async {
        const uid = 'user-survivor-1';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classRoutineItemIds: const ['old-class-item'],
        );
        await setupRepo.saveSetup(uid, initialSetup);

        // Seed: 1 old base timeline item, 1 manual item, 1 imported item
        final oldClass = RoutineItem(
          id: 'old-class-item',
          userId: uid,
          title: 'Old Chemistry',
          category: RoutineCategory.classBlock,
          blockType: RoutineBlockType.hardBlock,
          startMinute: 540,
          endMinute: 600,
          repeatDays: const [1, 3],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          source: RoutineSource.baseTimeline,
        );

        final manualItem = RoutineItem(
          id: 'manual-meditation',
          userId: uid,
          title: 'Morning Meditation',
          category: RoutineCategory.meditation,
          blockType: RoutineBlockType.softBlock,
          startMinute: 420,
          endMinute: 450,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          source: RoutineSource.manual,
        );

        final importedItem = RoutineItem(
          id: 'imported-gym',
          userId: uid,
          title: 'Gym Workout Plan',
          category: RoutineCategory.health,
          blockType: RoutineBlockType.hardBlock,
          startMinute: 1020,
          endMinute: 1100,
          repeatDays: const [2, 4, 6],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          source: RoutineSource.imported,
        );

        await routineRepo.createRoutineItem(uid, oldClass);
        await routineRepo.createRoutineItem(uid, manualItem);
        await routineRepo.createRoutineItem(uid, importedItem);

        // Replace classes section with new block
        final newClassBlocks = [
          const TimelineBlockDraft(
            id: 'new-math',
            section: 'classes',
            title: 'Advanced Calculus',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1, 3, 5],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        await coordinator.replaceSection(
          uid: uid,
          section: BaseTimelineSection.classes,
          newBlocks: newClassBlocks,
          updateSetup: (curr) => curr.copyWith(classBlocks: newClassBlocks),
        );

        final remaining = await routineRepo.fetchRoutineItems(uid);

        // Old class should be deleted
        expect(remaining.any((i) => i.id == 'old-class-item'), isFalse);

        // Manual item and imported item MUST survive
        expect(remaining.any((i) => i.id == 'manual-meditation'), isTrue);
        expect(remaining.any((i) => i.id == 'imported-gym'), isTrue);

        // New class item should exist
        expect(remaining.any((i) => i.title == 'Advanced Calculus'), isTrue);
      },
    );

    test(
      'Other base timeline sections survive when one section is replaced',
      () async {
        const uid = 'user-survivor-sections';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classRoutineItemIds: const ['class-item-1'],
          eatingRoutineItemIds: const ['eating-lunch-item'],
          skinCareRoutineItemIds: const ['skin-night-item'],
        );
        await setupRepo.saveSetup(uid, initialSetup);

        await routineRepo.createRoutineItem(
          uid,
          RoutineItem(
            id: 'class-item-1',
            userId: uid,
            title: 'Class 1',
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
        await routineRepo.createRoutineItem(
          uid,
          RoutineItem(
            id: 'eating-lunch-item',
            userId: uid,
            title: 'Lunch',
            category: RoutineCategory.eating,
            blockType: RoutineBlockType.softBlock,
            startMinute: 720,
            endMinute: 760,
            repeatDays: const [1],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            source: RoutineSource.baseTimeline,
          ),
        );
        await routineRepo.createRoutineItem(
          uid,
          RoutineItem(
            id: 'skin-night-item',
            userId: uid,
            title: 'Night Skin Care',
            category: RoutineCategory.skinCare,
            blockType: RoutineBlockType.softBlock,
            startMinute: 1300,
            endMinute: 1320,
            repeatDays: const [1],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            source: RoutineSource.baseTimeline,
          ),
        );

        // Replace only Eating section
        final newEatingBlocks = [
          const TimelineBlockDraft(
            id: 'new-lunch',
            section: 'eating',
            title: 'Power Lunch Bowl',
            startMinute: 750,
            endMinute: 800,
            repeatDays: [1, 2, 3, 4, 5],
            blockType: TimelineBlockDraft.softBlockKey,
          ),
        ];

        await coordinator.replaceSection(
          uid: uid,
          section: BaseTimelineSection.eating,
          newBlocks: newEatingBlocks,
          updateSetup: (curr) => curr.copyWith(eatingBlocks: newEatingBlocks),
        );

        final items = await routineRepo.fetchRoutineItems(uid);

        // Class and Skin Care items are untouched
        expect(items.any((i) => i.id == 'class-item-1'), isTrue);
        expect(items.any((i) => i.id == 'skin-night-item'), isTrue);

        // Eating old item replaced by new
        expect(items.any((i) => i.id == 'eating-lunch-item'), isFalse);
        expect(items.any((i) => i.title == 'Power Lunch Bowl'), isTrue);

        final updatedSetup = await setupRepo.fetchSetup(uid);
        expect(updatedSetup.classRoutineItemIds, const ['class-item-1']);
        expect(updatedSetup.skinCareRoutineItemIds, const ['skin-night-item']);
        expect(updatedSetup.eatingRoutineItemIds.isNotEmpty, isTrue);
        expect(
          updatedSetup.authorityFor(BaseTimelineSection.eating),
          BaseTimelineSectionAuthority.baseTimeline,
        );
        expect(
          updatedSetup.authorityFor(BaseTimelineSection.classes),
          BaseTimelineSectionAuthority.onboardingSeed,
        );
      },
    );

    test(
      'Initial setup persists onboardingSeed authority for all sections',
      () {
        final setup = BaseTimelineSetup(
          uid: 'authority-defaults',
          updatedAt: DateTime.now(),
        );
        final restored = BaseTimelineSetup.fromMap(
          setup.toMap(),
          uid: 'authority-defaults',
        );

        for (final section in BaseTimelineSection.values) {
          expect(
            restored.authorityFor(section),
            BaseTimelineSectionAuthority.onboardingSeed,
          );
        }
        expect(restored.schemaVersion, BaseTimelineSetup.currentSchemaVersion);
      },
    );

    test(
      'Successful Classes save changes only Classes authority to baseTimeline',
      () async {
        const uid = 'authority-classes';
        await setupRepo.saveSetup(
          uid,
          BaseTimelineSetup(
            uid: uid,
            updatedAt: DateTime.now(),
            classRoutineItemIds: const ['old-class'],
            workRoutineItemIds: const ['old-work'],
          ),
        );
        await routineRepo.createRoutineItem(
          uid,
          _routineItem(
            uid: uid,
            id: 'old-class',
            title: 'Old Class',
            category: RoutineCategory.classBlock,
            source: RoutineSource.onboarding,
          ),
        );
        await routineRepo.createRoutineItem(
          uid,
          _routineItem(
            uid: uid,
            id: 'old-work',
            title: 'Old Work',
            category: RoutineCategory.job,
            source: RoutineSource.onboarding,
          ),
        );

        final replacement = [
          const TimelineBlockDraft(
            id: 'class-b',
            section: 'classes',
            title: 'Class B',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            repeatDays: [1, 3],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];

        await coordinator.replaceSection(
          uid: uid,
          section: BaseTimelineSection.classes,
          newBlocks: replacement,
          updateSetup: (current) => current.copyWith(classBlocks: replacement),
        );

        final setup = await setupRepo.fetchSetup(uid);
        expect(
          setup.authorityFor(BaseTimelineSection.classes),
          BaseTimelineSectionAuthority.baseTimeline,
        );
        expect(
          setup.authorityFor(BaseTimelineSection.work),
          BaseTimelineSectionAuthority.onboardingSeed,
        );
        expect(setup.workRoutineItemIds, const ['old-work']);
      },
    );

    test(
      'Failed Classes transaction does not change authority or data',
      () async {
        const uid = 'authority-failure';
        final initial = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classRoutineItemIds: const ['old-class'],
        );
        await setupRepo.saveSetup(uid, initial);
        await routineRepo.createRoutineItem(
          uid,
          _routineItem(
            uid: uid,
            id: 'old-class',
            title: 'Old Class',
            category: RoutineCategory.classBlock,
            source: RoutineSource.onboarding,
          ),
        );
        txRepo.onBeforeMutation = () async => throw StateError('boom');

        await expectLater(
          coordinator.replaceSection(
            uid: uid,
            section: BaseTimelineSection.classes,
            newBlocks: const [
              TimelineBlockDraft(
                id: 'class-b',
                section: 'classes',
                title: 'Class B',
                startMinute: 600,
                endMinute: 660,
                repeatDays: [1],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
            updateSetup: (current) => current.copyWith(classBlocks: const []),
          ),
          throwsStateError,
        );

        final setup = await setupRepo.fetchSetup(uid);
        final items = await routineRepo.fetchRoutineItems(uid);
        expect(
          setup.authorityFor(BaseTimelineSection.classes),
          BaseTimelineSectionAuthority.onboardingSeed,
        );
        expect(setup.classRoutineItemIds, const ['old-class']);
        expect(items.map((item) => item.id), contains('old-class'));
        expect(items.any((item) => item.title == 'Class B'), isFalse);
      },
    );

    test(
      'Stale revision does not partially mutate section authority',
      () async {
        const uid = 'authority-stale';
        await setupRepo.saveSetup(
          uid,
          BaseTimelineSetup(
            uid: uid,
            updatedAt: DateTime.now(),
            revision: 2,
            classRoutineItemIds: const ['old-class'],
          ),
        );
        await routineRepo.createRoutineItem(
          uid,
          _routineItem(
            uid: uid,
            id: 'old-class',
            title: 'Old Class',
            category: RoutineCategory.classBlock,
            source: RoutineSource.onboarding,
          ),
        );

        await expectLater(
          txRepo.replaceBaseTimelineSection(
            uid: uid,
            section: BaseTimelineSection.classes,
            expectedRevision: 1,
            newRoutineItems: [
              _routineItem(
                uid: uid,
                id: 'new-class',
                title: 'New Class',
                category: RoutineCategory.classBlock,
                source: RoutineSource.baseTimeline,
              ),
            ],
            buildUpdatedSetup: (current) =>
                current.copyWith(classBlocks: const []),
          ),
          throwsA(isA<BaseTimelineConcurrencyException>()),
        );

        final setup = await setupRepo.fetchSetup(uid);
        final items = await routineRepo.fetchRoutineItems(uid);
        expect(setup.revision, 2);
        expect(
          setup.authorityFor(BaseTimelineSection.classes),
          BaseTimelineSectionAuthority.onboardingSeed,
        );
        expect(items.map((item) => item.id), contains('old-class'));
        expect(items.map((item) => item.id), isNot(contains('new-class')));
      },
    );

    test('Intentional empty Classes marks Classes as baseTimeline', () async {
      const uid = 'authority-empty';
      await setupRepo.saveSetup(
        uid,
        BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          classRoutineItemIds: const ['old-class'],
        ),
      );
      await routineRepo.createRoutineItem(
        uid,
        _routineItem(
          uid: uid,
          id: 'old-class',
          title: 'Old Class',
          category: RoutineCategory.classBlock,
          source: RoutineSource.onboarding,
        ),
      );

      await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.classes,
        newBlocks: const [],
        updateSetup: (current) => current.copyWith(classBlocks: const []),
      );

      final setup = await setupRepo.fetchSetup(uid);
      final items = await routineRepo.fetchRoutineItems(uid);
      expect(setup.classRoutineItemIds, isEmpty);
      expect(
        setup.authorityFor(BaseTimelineSection.classes),
        BaseTimelineSectionAuthority.baseTimeline,
      );
      expect(items.map((item) => item.id), isNot(contains('old-class')));
    });

    test(
      'Manual class-like Routine task survives Classes replacement',
      () async {
        const uid = 'authority-manual-class';
        await setupRepo.saveSetup(
          uid,
          BaseTimelineSetup(
            uid: uid,
            updatedAt: DateTime.now(),
            classRoutineItemIds: const ['old-class'],
          ),
        );
        await routineRepo.createRoutineItem(
          uid,
          _routineItem(
            uid: uid,
            id: 'old-class',
            title: 'Old Class',
            category: RoutineCategory.classBlock,
            source: RoutineSource.onboarding,
          ),
        );
        await routineRepo.createRoutineItem(
          uid,
          _routineItem(
            uid: uid,
            id: 'manual-class-like',
            title: 'Manual Seminar Prep',
            category: RoutineCategory.classBlock,
            source: RoutineSource.manual,
          ),
        );

        await coordinator.replaceSection(
          uid: uid,
          section: BaseTimelineSection.classes,
          newBlocks: const [
            TimelineBlockDraft(
              id: 'class-b',
              section: 'classes',
              title: 'Class B',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
          updateSetup: (current) => current.copyWith(classBlocks: const []),
        );

        final items = await routineRepo.fetchRoutineItems(uid);
        expect(items.map((item) => item.id), contains('manual-class-like'));
        expect(items.map((item) => item.id), isNot(contains('old-class')));
        expect(items.where((item) => item.title == 'Class B'), hasLength(1));
      },
    );

    test(
      'Live self-heal respects Classes takeover while repairing Work onboarding seed',
      () async {
        const uid = 'live-self-heal';
        final database = FakeRoutineDatabase();
        final routineRepo = FakeRoutineRepository(database: database);
        final historyRepo = FakeRoutineHistoryRepository();
        final onboardingRepo = FakeOnboardingRepository(
          routineDatabase: database,
        );
        final setupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: onboardingRepo,
        );
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          historyRepository: historyRepo,
          setupRepository: setupRepo,
        );
        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
            onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
            baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
          ],
        );
        addTearDown(container.dispose);

        final draft = OnboardingDraft(
          uid: uid,
          currentStep: OnboardingDraft.lastStepIndex,
          onboardingCompleted: true,
          baseTimeline: const BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'class-a',
                section: 'classes',
                title: 'Class A',
                startMinute: 9 * 60,
                endMinute: 10 * 60,
                repeatDays: [1, 3],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'work-a',
                section: 'job_work_business',
                title: 'Work A',
                startMinute: 13 * 60,
                endMinute: 14 * 60,
                repeatDays: [1, 2, 3],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          ),
        );
        final bundle = OnboardingCompletionService.buildBundle(draft);
        await onboardingRepo.saveCompletionBundle(bundle);
        final plan = RoutineOnboardingProjection.build(bundle);
        final classA = plan.items.singleWhere(
          (item) => item.category == RoutineCategory.classBlock,
        );
        final workA = plan.items.singleWhere(
          (item) => item.category == RoutineCategory.job,
        );
        final classB = _routineItem(
          uid: uid,
          id: 'base-class-b',
          title: 'Class B',
          category: RoutineCategory.classBlock,
          source: RoutineSource.baseTimeline,
        ).copyWith(baseTimelineSection: BaseTimelineSection.classes.name);
        await routineRepo.createRoutineItem(uid, classB);
        await setupRepo.saveSetup(
          uid,
          BaseTimelineSetup(
            uid: uid,
            updatedAt: DateTime.now(),
            classBlocks: const [
              TimelineBlockDraft(
                id: 'class-b',
                section: 'classes',
                title: 'Class B',
                startMinute: 10 * 60,
                endMinute: 11 * 60,
                repeatDays: [2, 4],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
            classRoutineItemIds: const ['base-class-b'],
            workRoutineItemIds: [workA.id],
            classAuthority: BaseTimelineSectionAuthority.baseTimeline,
            workAuthority: BaseTimelineSectionAuthority.onboardingSeed,
          ),
        );

        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner(uid);
        await notifier.inFlightProjectionRepair;

        final items = await routineRepo.fetchRoutineItems(uid);
        expect(items.map((item) => item.id), contains('base-class-b'));
        expect(items.map((item) => item.id), contains(workA.id));
        expect(items.map((item) => item.id), isNot(contains(classA.id)));

        await notifier.loadForOwner(uid);
        await notifier.inFlightProjectionRepair;

        final reloaded = await routineRepo.fetchRoutineItems(uid);
        expect(reloaded.where((item) => item.id == classA.id), isEmpty);
        expect(reloaded.where((item) => item.id == workA.id), hasLength(1));
        expect(
          reloaded.where((item) => item.id == 'base-class-b'),
          hasLength(1),
        );
      },
    );

    test(
      'baseTimeline authority rebuilds missing class routine templates without reupload',
      () async {
        const uid = 'foundation-repair-classes';
        final historyRepo = FakeRoutineHistoryRepository();
        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
            onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
            baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
          ],
        );
        addTearDown(container.dispose);

        const classBlocks = [
          TimelineBlockDraft(
            id: 'class-b-1',
            section: 'classes',
            title: 'Physics B',
            startMinute: 8 * 60,
            endMinute: 9 * 60,
            repeatDays: [1, 3, 5],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'class-b-2',
            section: 'classes',
            title: 'Lab B',
            startMinute: 10 * 60,
            endMinute: 11 * 60 + 30,
            repeatDays: [2],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];
        await setupRepo.saveSetup(
          uid,
          BaseTimelineSetup(
            uid: uid,
            updatedAt: DateTime.now(),
            classBlocks: classBlocks,
            workBlocks: const [
              TimelineBlockDraft(
                id: 'work-existing',
                section: 'job_work_business',
                title: 'Work Existing',
                startMinute: 13 * 60,
                endMinute: 17 * 60,
                repeatDays: [1, 2, 3],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
            classAuthority: BaseTimelineSectionAuthority.baseTimeline,
            workAuthority: BaseTimelineSectionAuthority.onboardingSeed,
          ),
        );
        await routineRepo.createRoutineItem(
          uid,
          _routineItem(
            uid: uid,
            id: 'manual-gym',
            title: 'Manual Gym',
            category: RoutineCategory.health,
            source: RoutineSource.manual,
          ),
        );

        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner(uid);
        await notifier.inFlightBaseTimelineFoundationRepair;

        final items = await routineRepo.fetchRoutineItems(uid);
        expect(items.where((item) => item.title == 'Physics B'), hasLength(1));
        expect(items.where((item) => item.title == 'Lab B'), hasLength(1));
        expect(items.where((item) => item.id == 'manual-gym'), hasLength(1));
        expect(
          items
              .where(
                (item) =>
                    item.source == RoutineSource.baseTimeline &&
                    item.baseTimelineSection ==
                        BaseTimelineSection.classes.name,
              )
              .map((item) => item.id),
          hasLength(2),
        );

        final repairedSetup = await setupRepo.fetchSetup(uid);
        expect(
          repairedSetup.authorityFor(BaseTimelineSection.classes),
          BaseTimelineSectionAuthority.baseTimeline,
        );
        expect(repairedSetup.classRoutineItemIds, hasLength(2));
        expect(repairedSetup.workBlocks.single.title, 'Work Existing');
      },
    );

    test(
      'v2 changed class setup is promoted by strong evidence and repaired from setup',
      () async {
        const uid = 'v2-diff-repair';
        final database = FakeRoutineDatabase();
        final routineRepo = FakeRoutineRepository(database: database);
        final historyRepo = FakeRoutineHistoryRepository();
        final onboardingRepo = FakeOnboardingRepository(
          routineDatabase: database,
        );
        final setupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: onboardingRepo,
        );
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          historyRepository: historyRepo,
          setupRepository: setupRepo,
        );
        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
            onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
            baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
          ],
        );
        addTearDown(container.dispose);

        final draft = OnboardingDraft(
          uid: uid,
          currentStep: OnboardingDraft.lastStepIndex,
          onboardingCompleted: true,
          baseTimeline: const BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'class-a',
                section: 'classes',
                title: 'Class A',
                startMinute: 9 * 60,
                endMinute: 10 * 60,
                repeatDays: [1, 3],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          ),
        );
        final bundle = OnboardingCompletionService.buildBundle(draft);
        await onboardingRepo.saveFinalDraftImmediately(draft);
        await onboardingRepo.saveCompletionBundle(bundle);

        const classBBlocks = [
          TimelineBlockDraft(
            id: 'class-b',
            section: 'classes',
            title: 'Class B',
            startMinute: 11 * 60,
            endMinute: 12 * 60,
            repeatDays: [2, 4],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];
        await setupRepo.saveSetup(
          uid,
          BaseTimelineSetup(
            uid: uid,
            updatedAt: DateTime.now(),
            schemaVersion: 2,
            revision: 2,
            classLogicalAssetId: 'photo-b',
            classBlocks: classBBlocks,
            classRoutineItemIds: const ['legacy-missing-class-b'],
          ),
        );

        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner(uid);
        await notifier.inFlightBaseTimelineFoundationRepair;
        await notifier.inFlightProjectionRepair;

        final items = await routineRepo.fetchRoutineItems(uid);
        expect(items.where((item) => item.title == 'Class B'), hasLength(1));
        expect(items.where((item) => item.title == 'Class A'), isEmpty);

        final repairedSetup = await setupRepo.fetchSetup(uid);
        expect(
          repairedSetup.authorityFor(BaseTimelineSection.classes),
          BaseTimelineSectionAuthority.baseTimeline,
        );
        expect(repairedSetup.classRoutineItemIds, hasLength(1));
        expect(
          repairedSetup.classRoutineItemIds.single,
          isNot('legacy-missing-class-b'),
        );
      },
    );

    test(
      'ambiguous empty v2 class setup does not blindly resurrect onboarding classes',
      () async {
        const uid = 'v2-empty-ambiguous';
        final database = FakeRoutineDatabase();
        final routineRepo = FakeRoutineRepository(database: database);
        final historyRepo = FakeRoutineHistoryRepository();
        final onboardingRepo = FakeOnboardingRepository(
          routineDatabase: database,
        );
        final setupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: onboardingRepo,
        );
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
          historyRepository: historyRepo,
          setupRepository: setupRepo,
        );
        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
            onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
            baseTimelineSetupRepositoryProvider.overrideWithValue(setupRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
          ],
        );
        addTearDown(container.dispose);

        final draft = OnboardingDraft(
          uid: uid,
          currentStep: OnboardingDraft.lastStepIndex,
          onboardingCompleted: true,
          baseTimeline: const BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'class-a',
                section: 'classes',
                title: 'Class A',
                startMinute: 9 * 60,
                endMinute: 10 * 60,
                repeatDays: [1, 3],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          ),
        );
        final bundle = OnboardingCompletionService.buildBundle(draft);
        await onboardingRepo.saveFinalDraftImmediately(draft);
        await onboardingRepo.saveCompletionBundle(bundle);
        await setupRepo.saveSetup(
          uid,
          BaseTimelineSetup(
            uid: uid,
            updatedAt: DateTime.now(),
            schemaVersion: 2,
            revision: 2,
            classBlocks: const [],
            classRoutineItemIds: const [],
          ),
        );

        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner(uid);
        await notifier.inFlightBaseTimelineFoundationRepair;
        await notifier.inFlightProjectionRepair;

        final items = await routineRepo.fetchRoutineItems(uid);
        expect(items.where((item) => item.title == 'Class A'), isEmpty);
      },
    );

    test(
      'Eating, Fixed, and Skin Care independently take baseTimeline authority',
      () async {
        const uid = 'authority-other-sections';
        await setupRepo.saveSetup(
          uid,
          BaseTimelineSetup(uid: uid, updatedAt: DateTime.now()),
        );

        final cases = [
          (
            section: BaseTimelineSection.eating,
            blocks: const [
              TimelineBlockDraft(
                id: 'eat-b',
                section: 'eating',
                title: 'Lunch B',
                startMinute: 12 * 60,
                endMinute: 13 * 60,
                repeatDays: [1, 2, 3],
                blockType: TimelineBlockDraft.softBlockKey,
              ),
            ],
            update:
                (BaseTimelineSetup current, List<TimelineBlockDraft> blocks) =>
                    current.copyWith(eatingBlocks: blocks),
          ),
          (
            section: BaseTimelineSection.fixed,
            blocks: const [
              TimelineBlockDraft(
                id: BaseTimelineDraft.fixedSleepId,
                section: 'fixed',
                title: 'Sleep',
                startMinute: 23 * 60,
                endMinute: 7 * 60,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.hardBlockKey,
                crossesMidnight: true,
                endsNextDay: true,
              ),
            ],
            update:
                (BaseTimelineSetup current, List<TimelineBlockDraft> blocks) =>
                    current.copyWith(fixedBlocks: blocks),
          ),
          (
            section: BaseTimelineSection.skinCare,
            blocks: const [
              TimelineBlockDraft(
                id: 'skin-b',
                section: 'skin_care',
                title: 'Night Care B',
                startMinute: 21 * 60,
                endMinute: 21 * 60 + 20,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.softBlockKey,
              ),
            ],
            update:
                (BaseTimelineSetup current, List<TimelineBlockDraft> blocks) =>
                    current.copyWith(skinCareBlocks: blocks),
          ),
        ];

        for (final entry in cases) {
          await coordinator.replaceSection(
            uid: uid,
            section: entry.section,
            newBlocks: entry.blocks,
            updateSetup: (current) => entry.update(current, entry.blocks),
          );
          final setup = await setupRepo.fetchSetup(uid);
          expect(
            setup.authorityFor(entry.section),
            BaseTimelineSectionAuthority.baseTimeline,
          );
          for (final other in BaseTimelineSection.values.where(
            (section) => section != entry.section,
          )) {
            if (cases
                .take(cases.indexOf(entry))
                .any((prior) => prior.section == other)) {
              continue;
            }
            expect(
              setup.authorityFor(other),
              BaseTimelineSectionAuthority.onboardingSeed,
            );
          }
        }
      },
    );

    test(
      'five-section product contract: drafts/failures preserve old state and save replaces only selected section',
      () async {
        for (final section in BaseTimelineSection.values) {
          final uid = 'gate6-${section.name}';
          final routineRepo = FakeRoutineRepository();
          final historyRepo = FakeRoutineHistoryRepository();
          final setupRepo = FakeBaseTimelineSetupRepository();
          final txRepo = FakeRoutineTransactionRepository(
            routineRepository: routineRepo,
            historyRepository: historyRepo,
            setupRepository: setupRepo,
          );
          final coordinator = BaseTimelineTransactionCoordinator(
            routineRepo: routineRepo,
            setupRepo: setupRepo,
            transactionRepo: txRepo,
          );

          final oldBlocks = {
            for (final candidate in BaseTimelineSection.values)
              candidate: [_gate6Block(candidate, 'old')],
          };
          var setup = BaseTimelineSetup(
            uid: uid,
            updatedAt: DateTime.utc(2026, 9, 13),
            revision: 7,
            classBlocks: oldBlocks[BaseTimelineSection.classes]!,
            workBlocks: oldBlocks[BaseTimelineSection.work]!,
            eatingBlocks: oldBlocks[BaseTimelineSection.eating]!,
            fixedBlocks: oldBlocks[BaseTimelineSection.fixed]!,
            skinCareBlocks: oldBlocks[BaseTimelineSection.skinCare]!,
            classRoutineItemIds: [_gate6OldItemId(BaseTimelineSection.classes)],
            workRoutineItemIds: [_gate6OldItemId(BaseTimelineSection.work)],
            eatingRoutineItemIds: [_gate6OldItemId(BaseTimelineSection.eating)],
            fixedRoutineItemIds: [_gate6OldItemId(BaseTimelineSection.fixed)],
            skinCareRoutineItemIds: [
              _gate6OldItemId(BaseTimelineSection.skinCare),
            ],
            classAuthority: BaseTimelineSectionAuthority.baseTimeline,
            workAuthority: BaseTimelineSectionAuthority.baseTimeline,
            eatingAuthority: BaseTimelineSectionAuthority.baseTimeline,
            fixedAuthority: BaseTimelineSectionAuthority.baseTimeline,
            skinCareAuthority: BaseTimelineSectionAuthority.baseTimeline,
          );
          await setupRepo.saveSetup(uid, setup);

          for (final candidate in BaseTimelineSection.values) {
            final item =
                BaseTimelineTransactionCoordinator.routineItemForSectionBlock(
                  uid: uid,
                  section: candidate,
                  block: oldBlocks[candidate]!.single,
                  index: 0,
                  now: DateTime.utc(2026, 9, 13),
                ).copyWith(id: _gate6OldItemId(candidate));
            await routineRepo.createRoutineItem(uid, item);
          }
          await routineRepo.createRoutineItem(
            uid,
            _routineItem(
              uid: uid,
              id: 'manual-${section.name}',
              title: 'Manual ${section.name}',
              category: RoutineCategory.habit,
              source: RoutineSource.manual,
            ),
          );
          await routineRepo.createRoutineItem(
            uid,
            _routineItem(
              uid: uid,
              id: 'imported-${section.name}',
              title: 'Imported ${section.name}',
              category: RoutineCategory.eating,
              source: RoutineSource.imported,
            ),
          );
          await historyRepo.appendHistory(
            uid,
            RoutineOccurrenceRecord(
              id: 'occ-${section.name}',
              ownerUid: uid,
              routineItemId: _gate6OldItemId(section),
              occurrenceDateKey: '2026-09-13',
              status: RoutineStatus.completed,
              source: 'routine',
              action: 'complete',
              operationKey: 'op-${section.name}',
              createdAt: DateTime.utc(2026, 9, 13),
              updatedAt: DateTime.utc(2026, 9, 13),
            ),
          );

          final beforeDraftCancelOrAiFailure = await _gate6Snapshot(
            uid,
            routineRepo,
            setupRepo,
            historyRepo,
          );
          final candidateBlocks = [_gate6Block(section, 'new')];

          // Editing, Back, cancel, upload failure, and AI failure are all
          // pre-commit states: without a successful Save transaction, the live
          // Routine/setup/history state must not change.
          expect(
            await _gate6Snapshot(uid, routineRepo, setupRepo, historyRepo),
            beforeDraftCancelOrAiFailure,
          );

          txRepo.onBeforeMutation = () async {
            throw StateError('simulated failed save');
          };
          await expectLater(
            coordinator.replaceSection(
              uid: uid,
              section: section,
              newBlocks: candidateBlocks,
              updateSetup: (current) =>
                  _gate6SetupWithBlocks(current, section, candidateBlocks),
            ),
            throwsStateError,
          );
          txRepo.onBeforeMutation = null;
          expect(
            await _gate6Snapshot(uid, routineRepo, setupRepo, historyRepo),
            beforeDraftCancelOrAiFailure,
          );

          final staleItems =
              BaseTimelineTransactionCoordinator.routineItemsForSectionBlocks(
                uid: uid,
                section: section,
                blocks: candidateBlocks,
                now: DateTime.utc(2026, 9, 13, 1),
              );
          await expectLater(
            txRepo.replaceBaseTimelineSection(
              uid: uid,
              section: section,
              expectedRevision: setup.revision - 1,
              newRoutineItems: staleItems,
              buildUpdatedSetup: (live) =>
                  _gate6SetupWithBlocks(live, section, candidateBlocks),
            ),
            throwsA(isA<BaseTimelineConcurrencyException>()),
          );
          expect(
            await _gate6Snapshot(uid, routineRepo, setupRepo, historyRepo),
            beforeDraftCancelOrAiFailure,
          );

          final result = await coordinator.replaceSection(
            uid: uid,
            section: section,
            newBlocks: candidateBlocks,
            updateSetup: (current) =>
                _gate6SetupWithBlocks(current, section, candidateBlocks),
          );
          setup = result.committedSetup;

          final items = await routineRepo.fetchRoutineItems(uid);
          final ids = items.map((item) => item.id).toSet();
          expect(ids, isNot(contains(_gate6OldItemId(section))));
          expect(
            items.where((item) => item.title.contains('new')),
            hasLength(1),
          );
          expect(ids, contains('manual-${section.name}'));
          expect(ids, contains('imported-${section.name}'));
          for (final other in BaseTimelineSection.values.where(
            (candidate) => candidate != section,
          )) {
            expect(ids, contains(_gate6OldItemId(other)));
            expect(
              setup.blocksFor(other).single.title,
              _gate6Block(other, 'old').title,
            );
          }
          expect(
            setup.blocksFor(section).single.title,
            candidateBlocks.single.title,
          );
          expect(
            setup.authorityFor(section),
            BaseTimelineSectionAuthority.baseTimeline,
          );
          expect(await historyRepo.fetchHistory(uid), hasLength(1));
        }
      },
    );

    test('Skin Care skipped remains configurable later', () async {
      const uid = 'gate6-skin-skipped';
      await setupRepo.saveSetup(
        uid,
        BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.utc(2026, 9, 13),
        ).asSkinCareSkipped(),
      );

      const blocks = [
        TimelineBlockDraft(
          id: 'skin-configured-later',
          section: 'skin_care',
          title: 'Evening Skin Care',
          startMinute: 21 * 60,
          endMinute: 21 * 60 + 15,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareSlotLabel: 'Evening',
        ),
      ];

      await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.skinCare,
        newBlocks: blocks,
        updateSetup: (current) => current.copyWith(
          skinCareSetupPath: 'products',
          skinCareSkipped: false,
          skinCareBlocks: blocks,
        ),
      );

      final setup = await setupRepo.fetchSetup(uid);
      final items = await routineRepo.fetchRoutineItems(uid);
      expect(setup.skinCareSkipped, isFalse);
      expect(setup.skinCareBlocks.single.title, 'Evening Skin Care');
      expect(
        setup.authorityFor(BaseTimelineSection.skinCare),
        BaseTimelineSectionAuthority.baseTimeline,
      );
      expect(items.single.title, 'Evening Skin Care');
      expect(items.single.skincareSlotLabel, 'Evening');
    });

    test(
      'Cross-domain overlapping schedules save with zero conflict errors',
      () async {
        const uid = 'user-zero-conflict';
        final initialSetup = BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
        );
        await setupRepo.saveSetup(uid, initialSetup);

        // 1. Add Class 10:00 - 11:30
        final classBlocks = [
          const TimelineBlockDraft(
            id: 'class-overlap',
            section: 'classes',
            title: 'History Lecture',
            startMinute: 10 * 60,
            endMinute: 11 * 60 + 30,
            repeatDays: [1, 3, 5],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ];
        await coordinator.replaceSection(
          uid: uid,
          section: BaseTimelineSection.classes,
          newBlocks: classBlocks,
          updateSetup: (curr) => curr.copyWith(classBlocks: classBlocks),
        );

        // 2. Add Eating Snack overlapping inside class: 10:30 - 11:00
        final eatingBlocks = [
          const TimelineBlockDraft(
            id: 'eating-overlap',
            section: 'eating',
            title: 'Mid-Morning Snack',
            startMinute: 10 * 60 + 30,
            endMinute: 11 * 60,
            repeatDays: [1, 3, 5],
            blockType: TimelineBlockDraft.softBlockKey,
          ),
        ];

        // Saving must succeed without throwing any conflict errors or requiring conflict tokens
        await coordinator.replaceSection(
          uid: uid,
          section: BaseTimelineSection.eating,
          newBlocks: eatingBlocks,
          updateSetup: (curr) => curr.copyWith(eatingBlocks: eatingBlocks),
        );

        final items = await routineRepo.fetchRoutineItems(uid);
        expect(items.any((i) => i.title == 'History Lecture'), isTrue);
        expect(items.any((i) => i.title == 'Mid-Morning Snack'), isTrue);
      },
    );
  });
}

RoutineItem _routineItem({
  required String uid,
  required String id,
  required String title,
  required RoutineCategory category,
  required RoutineSource source,
}) {
  return RoutineItem(
    id: id,
    userId: uid,
    title: title,
    category: category,
    blockType: RoutineBlockType.hardBlock,
    startMinute: 9 * 60,
    endMinute: 10 * 60,
    repeatDays: const [1],
    createdAt: DateTime.utc(2026, 9, 12),
    updatedAt: DateTime.utc(2026, 9, 12),
    source: source,
  );
}

String _gate6OldItemId(BaseTimelineSection section) => 'old-${section.name}';

TimelineBlockDraft _gate6Block(BaseTimelineSection section, String label) {
  return TimelineBlockDraft(
    id: '${section.name}-$label',
    section: switch (section) {
      BaseTimelineSection.classes => 'classes',
      BaseTimelineSection.work => 'job_work_business',
      BaseTimelineSection.eating => 'eating',
      BaseTimelineSection.fixed => 'fixed',
      BaseTimelineSection.skinCare => 'skin_care',
    },
    title: '${_gate6SectionLabel(section)} $label',
    startMinute: 9 * 60,
    endMinute: 10 * 60,
    repeatDays: const [1, 2, 3],
    blockType:
        section == BaseTimelineSection.eating ||
            section == BaseTimelineSection.skinCare
        ? TimelineBlockDraft.softBlockKey
        : TimelineBlockDraft.hardBlockKey,
    mealSlot: section == BaseTimelineSection.eating ? 'lunch' : null,
    mealCategory: section == BaseTimelineSection.eating ? 'balanced' : null,
    skincareSlotLabel: section == BaseTimelineSection.skinCare ? 'AM' : null,
  );
}

String _gate6SectionLabel(BaseTimelineSection section) {
  return switch (section) {
    BaseTimelineSection.classes => 'Classes',
    BaseTimelineSection.work => 'Work / Business',
    BaseTimelineSection.eating => 'Eating',
    BaseTimelineSection.fixed => 'Fixed',
    BaseTimelineSection.skinCare => 'Skin Care',
  };
}

BaseTimelineSetup _gate6SetupWithBlocks(
  BaseTimelineSetup setup,
  BaseTimelineSection section,
  List<TimelineBlockDraft> blocks,
) {
  return switch (section) {
    BaseTimelineSection.classes => setup.copyWith(classBlocks: blocks),
    BaseTimelineSection.work => setup.copyWith(workBlocks: blocks),
    BaseTimelineSection.eating => setup.copyWith(eatingBlocks: blocks),
    BaseTimelineSection.fixed => setup.copyWith(fixedBlocks: blocks),
    BaseTimelineSection.skinCare => setup.copyWith(skinCareBlocks: blocks),
  };
}

Future<String> _gate6Snapshot(
  String uid,
  RoutineRepository routineRepo,
  BaseTimelineSetupRepository setupRepo,
  RoutineHistoryRepository historyRepo,
) async {
  final itemIds =
      (await routineRepo.fetchRoutineItems(uid))
          .map((item) => '${item.id}:${item.title}:${item.source.name}')
          .toList()
        ..sort();
  final historyIds =
      (await historyRepo.fetchHistory(uid))
          .map(
            (record) =>
                '${record.id}:${record.routineItemId}:${record.status.name}',
          )
          .toList()
        ..sort();
  final setup = await setupRepo.fetchSetup(uid);
  final setupParts = [
    'revision=${setup.revision}',
    for (final section in BaseTimelineSection.values)
      '${section.name}:${setup.authorityFor(section).name}:'
          '${setup.trackedIdsFor(section).join(",")}:'
          '${setup.blocksFor(section).map((block) => block.title).join(",")}',
  ];
  return [
    itemIds.join('|'),
    historyIds.join('|'),
    setupParts.join('|'),
  ].join('\n');
}
