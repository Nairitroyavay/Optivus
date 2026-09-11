import 'package:flutter_test/flutter_test.dart';
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
      },
    );

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
