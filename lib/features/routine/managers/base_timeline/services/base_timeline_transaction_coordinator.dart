import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

class BaseTimelineTransactionCoordinator {
  final RoutineRepository _routineRepo;
  final BaseTimelineSetupRepository _setupRepo;
  final Ref? _ref;

  BaseTimelineTransactionCoordinator({
    required RoutineRepository routineRepo,
    required BaseTimelineSetupRepository setupRepo,
    Ref? ref,
  })  : _routineRepo = routineRepo,
        _setupRepo = setupRepo,
        _ref = ref;

  static bool isSectionRoutineItem(
    RoutineItem item,
    BaseTimelineSection section,
  ) {
    final isBaseSource = item.source == RoutineSource.onboarding ||
        item.source == RoutineSource.imported;
    if (!isBaseSource) return false;

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
      BaseTimelineSection.skinCare =>
        item.category == RoutineCategory.skinCare,
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
      BaseTimelineSection.fixed => (b.id == BaseTimelineDraft.fixedSleepId ||
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
    // 1. Fetch current routine items
    final allItems = await _routineRepo.fetchRoutineItems(uid);

    // 2. Identify items belonging to this section from onboarding / import
    // Note: manual user items, habits, trackers, and occurrences are STRICTLY preserved.
    final itemsToDelete = allItems
        .where((item) => isSectionRoutineItem(item, section))
        .toList(growable: false);

    // 3. Convert newBlocks to RoutineItem
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
        repeatDays: b.repeatDays.isEmpty
            ? const [1, 2, 3, 4, 5, 6, 7]
            : b.repeatDays.toSet().toList()
          ..sort(),
        blockType: blockTypeForSection(section, b),
        category: categoryForSection(section, b),
        source: RoutineSource.imported,
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

    // 4. Delete old section items
    for (final oldItem in itemsToDelete) {
      await _routineRepo.deleteRoutineItem(uid, oldItem.id);
    }

    // 5. Create new section items
    for (final newItem in newRoutineItems) {
      await _routineRepo.createRoutineItem(uid, newItem);
    }

    // 6. Update BaseTimelineSetup
    final currentSetup = await _setupRepo.fetchSetup(uid);
    final updatedSetup = updateSetup(currentSetup);
    await _setupRepo.saveSetup(uid, updatedSetup);
    if (_ref != null) {
      _ref
          .read(baseTimelineSetupNotifierProvider.notifier)
          .updateInMemory(updatedSetup);

      // 7. Refresh in-memory RoutineNotifier so the changes are instantly visible
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
    setupRepo: ref.watch(baseTimelineSetupRepositoryProvider),
    ref: ref,
  );
});
