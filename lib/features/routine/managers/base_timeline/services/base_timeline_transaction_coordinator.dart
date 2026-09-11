import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

class BaseTimelineTransactionCoordinator {
  final RoutineRepository _routineRepo;
  final RoutineTransactionRepository? _transactionRepo;
  final BaseTimelineSetupRepository _setupRepo;
  final Ref? _ref;

  BaseTimelineTransactionCoordinator({
    required RoutineRepository routineRepo,
    RoutineTransactionRepository? transactionRepo,
    required BaseTimelineSetupRepository setupRepo,
    Ref? ref,
  }) : _routineRepo = routineRepo,
       _transactionRepo = transactionRepo,
       _setupRepo = setupRepo,
       _ref = ref;

  static bool isSectionRoutineItem(
    RoutineItem item,
    BaseTimelineSection section, {
    BaseTimelineSetup? setup,
  }) {
    // 1. Primary: explicitly tracked IDs in BaseTimelineSetup
    if (setup != null) {
      final trackedIds = switch (section) {
        BaseTimelineSection.classes => setup.classRoutineItemIds,
        BaseTimelineSection.work => setup.workRoutineItemIds,
        BaseTimelineSection.eating => setup.eatingRoutineItemIds,
        BaseTimelineSection.fixed => setup.fixedRoutineItemIds,
        BaseTimelineSection.skinCare => setup.skinCareRoutineItemIds,
      };
      if (trackedIds.contains(item.id)) return true;
    }

    // 2. Explicit baseTimeline provenance
    if (item.source == RoutineSource.baseTimeline &&
        item.baseTimelineSection == section.name) {
      return true;
    }

    // 3. Migration fallback: onboarding items belonging to this section
    // STRICT RULE: Never delete RoutineSource.manual or RoutineSource.imported items!
    if (item.source != RoutineSource.onboarding) return false;

    return switch (section) {
      BaseTimelineSection.classes =>
        item.category == RoutineCategory.classBlock,
      BaseTimelineSection.work => item.category == RoutineCategory.job,
      BaseTimelineSection.eating => item.category == RoutineCategory.eating,
      BaseTimelineSection.fixed =>
        item.category == RoutineCategory.fixed ||
            item.category == RoutineCategory.sleep ||
            item.id == BaseTimelineDraft.fixedSleepId ||
            item.id == BaseTimelineDraft.fixedBathId,
      BaseTimelineSection.skinCare => item.category == RoutineCategory.skinCare,
    };
  }

  static RoutineBlockType blockTypeForSection(
    BaseTimelineSection section,
    TimelineBlockDraft b,
  ) {
    return switch (section) {
      BaseTimelineSection.classes => RoutineBlockType.hardBlock,
      BaseTimelineSection.work => RoutineBlockType.hardBlock,
      BaseTimelineSection.eating => RoutineBlockType.softBlock,
      BaseTimelineSection.fixed => RoutineBlockType.hardBlock,
      BaseTimelineSection.skinCare => RoutineBlockType.softBlock,
    };
  }

  static RoutineCategory categoryForSection(
    BaseTimelineSection section,
    TimelineBlockDraft b,
  ) {
    return switch (section) {
      BaseTimelineSection.classes => RoutineCategory.classBlock,
      BaseTimelineSection.work => RoutineCategory.job,
      BaseTimelineSection.eating => RoutineCategory.eating,
      BaseTimelineSection.fixed =>
        (b.id == BaseTimelineDraft.fixedSleepId ||
                b.title.trim().toLowerCase() == 'sleep')
            ? RoutineCategory.sleep
            : RoutineCategory.fixed,
      BaseTimelineSection.skinCare => RoutineCategory.skinCare,
    };
  }

  static bool isHardBlockForSection(BaseTimelineSection section) {
    return section == BaseTimelineSection.classes ||
        section == BaseTimelineSection.work ||
        section == BaseTimelineSection.fixed;
  }

  static RoutinePriority priorityForSection(BaseTimelineSection section) {
    return isHardBlockForSection(section)
        ? RoutinePriority.mustDo
        : RoutinePriority.goodToDo;
  }

  Future<void> replaceSection({
    required String uid,
    required BaseTimelineSection section,
    required List<TimelineBlockDraft> newBlocks,
    required BaseTimelineSetup Function(BaseTimelineSetup current) updateSetup,
  }) async {
    // 1. Fetch current setup and routine items
    final currentSetup = await _setupRepo.fetchSetup(uid);
    final allItems = await _routineRepo.fetchRoutineItems(uid);

    // 2. Identify items belonging to this section
    // Note: manual user items, imported meal plans, habits, and trackers are STRICTLY preserved.
    final itemsToDelete = allItems
        .where(
          (item) => isSectionRoutineItem(item, section, setup: currentSetup),
        )
        .toList(growable: false);

    // 3. Convert newBlocks to RoutineItem with baseTimeline provenance
    final newRoutineItems = <RoutineItem>[];
    for (var index = 0; index < newBlocks.length; index++) {
      final b = newBlocks[index];
      final isOvernight =
          b.crossesMidnight || b.endsNextDay || b.endMinute <= b.startMinute;
      final sourceKey =
          'base_${section.name}_${b.id.isNotEmpty ? b.id : index}';
      final docId = RoutineOnboardingProjection.stableRoutineDocumentId(
        ownerUid: uid,
        sourceItemId: sourceKey,
      );

      final item = RoutineItem(
        id: docId,
        userId: uid,
        title: b.title,
        startMinute: b.startMinute,
        endMinute: b.endMinute,
        crossesMidnight: isOvernight,
        endsNextDay: isOvernight,
        repeatDays:
            b.repeatDays.isEmpty
                  ? const [1, 2, 3, 4, 5, 6, 7]
                  : b.repeatDays.toSet().toList()
              ..sort(),
        blockType: blockTypeForSection(section, b),
        category: categoryForSection(section, b),
        source: RoutineSource.baseTimeline,
        baseTimelineSection: section.name,
        priority: priorityForSection(section),
        hardBlock: isHardBlockForSection(section),
        location: b.location,
        mealCategory: b.mealCategory,
        mealSlot: b.mealSlot,
        dishes: b.dishes,
        caloriesEstimate: b.calories,
        proteinEstimate: b.protein,
        steps: b.skincareSteps.isNotEmpty
            ? b.skincareSteps
            : b.skincareProducts,
        skincareProducts: b.skincareProducts,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      newRoutineItems.add(item);
    }

    // 4. Update BaseTimelineSetup with tracked IDs
    final intermediateSetup = updateSetup(currentSetup);
    final newIds = newRoutineItems.map((i) => i.id).toList();
    final updatedSetup = switch (section) {
      BaseTimelineSection.classes => intermediateSetup.copyWith(
        classRoutineItemIds: newIds,
      ),
      BaseTimelineSection.work => intermediateSetup.copyWith(
        workRoutineItemIds: newIds,
      ),
      BaseTimelineSection.eating => intermediateSetup.copyWith(
        eatingRoutineItemIds: newIds,
      ),
      BaseTimelineSection.fixed => intermediateSetup.copyWith(
        fixedRoutineItemIds: newIds,
      ),
      BaseTimelineSection.skinCare => intermediateSetup.copyWith(
        skinCareRoutineItemIds: newIds,
      ),
    };

    // 5. Commit atomically via RoutineTransactionRepository if available
    if (_transactionRepo != null) {
      await _transactionRepo.commitWrite(
        uid: uid,
        deleteItemIds: itemsToDelete.map((i) => i.id).toList(),
        setItems: newRoutineItems,
        setBaseTimelineSetupDoc: updatedSetup.toMap(),
      );
    } else {
      // Fallback for isolated mocks without transaction repository
      for (final oldItem in itemsToDelete) {
        await _routineRepo.deleteRoutineItem(uid, oldItem.id);
      }
      for (final newItem in newRoutineItems) {
        await _routineRepo.createRoutineItem(uid, newItem);
      }
      await _setupRepo.saveSetup(uid, updatedSetup);
    }

    // 6. Update in-memory state
    if (_ref != null) {
      _ref
          .read(baseTimelineSetupNotifierProvider.notifier)
          .updateInMemory(updatedSetup);

      try {
        await _ref.read(routineNotifierProvider.notifier).loadForOwner(uid);
      } catch (_) {}
    }
  }
}

final baseTimelineTransactionCoordinatorProvider =
    Provider<BaseTimelineTransactionCoordinator>((ref) {
      return BaseTimelineTransactionCoordinator(
        routineRepo: ref.watch(routineRepositoryProvider),
        transactionRepo: ref.watch(routineTransactionRepositoryProvider),
        setupRepo: ref.watch(baseTimelineSetupRepositoryProvider),
        ref: ref,
      );
    });
