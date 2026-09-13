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
  final RoutineTransactionRepository _transactionRepo;
  final BaseTimelineSetupRepository _setupRepo;
  final Ref? _ref;

  BaseTimelineTransactionCoordinator({
    required RoutineRepository routineRepo,
    required RoutineTransactionRepository transactionRepo,
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

    // 3. Legacy migration fallback only. Schema-v3 steady state relies on
    // tracked IDs and explicit baseTimeline provenance.
    // STRICT RULE: Never delete RoutineSource.manual or RoutineSource.imported items!
    if (setup != null && setup.schemaVersion >= 3) return false;
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

  static String routineDocumentIdForSectionBlock({
    required String uid,
    required BaseTimelineSection section,
    required TimelineBlockDraft block,
    required int index,
  }) {
    final sourceKey =
        'base_${section.name}_${block.id.isNotEmpty ? block.id : index}';
    return RoutineOnboardingProjection.stableRoutineDocumentId(
      ownerUid: uid,
      sourceItemId: sourceKey,
    );
  }

  static RoutineItem routineItemForSectionBlock({
    required String uid,
    required BaseTimelineSection section,
    required TimelineBlockDraft block,
    required int index,
    required DateTime now,
  }) {
    final isOvernight =
        block.crossesMidnight ||
        block.endsNextDay ||
        block.endMinute <= block.startMinute;
    final repeatDays = block.repeatDays.isEmpty
        ? const [1, 2, 3, 4, 5, 6, 7]
        : (block.repeatDays.toSet().toList()..sort());

    return RoutineItem(
      id: routineDocumentIdForSectionBlock(
        uid: uid,
        section: section,
        block: block,
        index: index,
      ),
      userId: uid,
      title: block.title,
      startMinute: block.startMinute,
      endMinute: block.endMinute,
      crossesMidnight: isOvernight,
      endsNextDay: isOvernight,
      repeatDays: repeatDays,
      blockType: blockTypeForSection(section, block),
      category: categoryForSection(section, block),
      source: RoutineSource.baseTimeline,
      baseTimelineSection: section.name,
      priority: priorityForSection(section),
      hardBlock: isHardBlockForSection(section),
      location: block.location,
      notes: block.notes,
      professor: block.professor,
      courseCode: block.courseCode,
      classType: block.classType,
      sectionLabel: block.sectionLabel,
      mealCategory: block.mealCategory,
      mealSlot: block.mealSlot,
      dishes: block.dishes,
      caloriesEstimate: block.calories,
      proteinEstimate: block.protein,
      steps: block.skincareSteps.isNotEmpty
          ? block.skincareSteps
          : block.skincareProducts,
      skincareProducts: block.skincareProducts,
      skincareMissingItems: block.skincareMissingItems,
      skincareSlotLabel: block.skincareSlotLabel,
      createdAt: now,
      updatedAt: now,
    );
  }

  static List<RoutineItem> routineItemsForSectionBlocks({
    required String uid,
    required BaseTimelineSection section,
    required List<TimelineBlockDraft> blocks,
    required DateTime now,
  }) {
    return [
      for (var index = 0; index < blocks.length; index++)
        routineItemForSectionBlock(
          uid: uid,
          section: section,
          block: blocks[index],
          index: index,
          now: now,
        ),
    ];
  }

  Future<BaseTimelineSectionCommitResult> replaceSection({
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
    final trackedIds = currentSetup.trackedIdsFor(section);
    final legacyItemsToDelete = allItems
        .where(
          (item) =>
              !trackedIds.contains(item.id) &&
              isSectionRoutineItem(item, section, setup: currentSetup),
        )
        .map((item) => item.id)
        .toList(growable: false);

    // 3. Convert newBlocks to RoutineItem with baseTimeline provenance
    final newRoutineItems = routineItemsForSectionBlocks(
      uid: uid,
      section: section,
      blocks: newBlocks,
      now: DateTime.now(),
    );

    // 4. Atomic transaction with live revision optimistic concurrency check
    final commitResult = await _transactionRepo.replaceBaseTimelineSection(
      uid: uid,
      section: section,
      expectedRevision: currentSetup.revision,
      newRoutineItems: newRoutineItems,
      additionalDeleteIds: legacyItemsToDelete,
      buildUpdatedSetup: (liveSetup) {
        return updateSetup(liveSetup);
      },
    );

    // 5. Update in-memory state directly from the committed transaction result
    if (_ref != null) {
      _ref
          .read(baseTimelineSetupNotifierProvider.notifier)
          .updateInMemory(commitResult.committedSetup);

      try {
        await _ref.read(routineNotifierProvider.notifier).loadForOwner(uid);
      } catch (_) {
        // Routine refresh failure must NOT invalidate save success.
      }
    }

    return commitResult;
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
