import 'package:flutter/foundation.dart';
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
import 'package:optivus/state/app_state.dart';

/// Status of post-commit frontend Routine reconciliation.
enum BaseTimelineRoutineRefreshStatus {
  notAttempted,
  refreshed,
  refreshPending,
}

/// Typed result of an explicit Routine reconciliation refresh retry.
@immutable
class BaseTimelineRoutineRefreshResult {
  final BaseTimelineRoutineRefreshStatus status;
  final String? message;

  const BaseTimelineRoutineRefreshResult({
    required this.status,
    this.message,
  });

  bool get isRefreshed =>
      status == BaseTimelineRoutineRefreshStatus.refreshed;
  bool get isPending =>
      status == BaseTimelineRoutineRefreshStatus.refreshPending;
}

/// Typed result of a committed Base Timeline section replacement at the coordinator level,
/// pairing durable transaction results with frontend Routine reconciliation status.
@immutable
class BaseTimelineSectionReplaceResult {
  final BaseTimelineSectionCommitResult commit;
  final BaseTimelineRoutineRefreshStatus routineRefreshStatus;
  final String? routineRefreshMessage;

  const BaseTimelineSectionReplaceResult({
    required this.commit,
    required this.routineRefreshStatus,
    this.routineRefreshMessage,
  });

  BaseTimelineSetup get committedSetup => commit.committedSetup;
  List<String> get routineItemIds => commit.routineItemIds;
  int get revision => commit.revision;

  bool get routineRefreshPending =>
      routineRefreshStatus ==
      BaseTimelineRoutineRefreshStatus.refreshPending;
}

class BaseTimelineTransactionCoordinator {
  final RoutineRepository _routineRepo;
  final RoutineTransactionRepository _transactionRepo;
  final BaseTimelineSetupRepository _setupRepo;
  final Ref? _ref;
  final Map<String, int> _latestCommittedRevisionByUid = {};
  final Map<String, BaseTimelineRoutineRefreshStatus> _latestRefreshStatusByUid = {};

  BaseTimelineTransactionCoordinator({
    required RoutineRepository routineRepo,
    required RoutineTransactionRepository transactionRepo,
    required BaseTimelineSetupRepository setupRepo,
    Ref? ref,
  }) : _routineRepo = routineRepo,
       _transactionRepo = transactionRepo,
       _setupRepo = setupRepo,
       _ref = ref;

  BaseTimelineRoutineRefreshStatus latestRefreshStatusFor(String uid) {
    return _latestRefreshStatusByUid[uid] ??
        BaseTimelineRoutineRefreshStatus.notAttempted;
  }

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

  /// Enforces the strict Base Timeline repeat-day invariant for [TimelineBlockDraft].
  ///
  /// Invariant:
  /// - repeatDays must be non-empty
  /// - repeatDays length <= 7
  /// - days must be unique
  /// - every value must be 1..7 (Monday=1, Sunday=7)
  ///
  /// Returns a deterministically sorted copy. Never invents defaults.
  static List<int> validatedRepeatDays(TimelineBlockDraft block) {
    final days = block.repeatDays;
    if (days.isEmpty) {
      throw ArgumentError(
        'Base Timeline block "${block.id}" must specify at least one repeat day.',
      );
    }
    if (days.length > 7) {
      throw ArgumentError(
        'Base Timeline block "${block.id}" cannot specify more than 7 repeat days.',
      );
    }
    if (days.toSet().length != days.length) {
      throw ArgumentError(
        'Base Timeline block "${block.id}" contains duplicate repeat days.',
      );
    }
    for (final day in days) {
      if (day < 1 || day > 7) {
        throw ArgumentError(
          'Base Timeline block "${block.id}" repeat day $day is out of range 1..7.',
        );
      }
    }
    return List<int>.from(days)..sort();
  }

  static RoutineItem routineItemForSectionBlock({
    required String uid,
    required BaseTimelineSection section,
    required TimelineBlockDraft block,
    required int index,
    required DateTime now,
    BaseTimelineSetup? setup,
  }) {
    final isOvernight =
        block.crossesMidnight ||
        block.endsNextDay ||
        block.endMinute <= block.startMinute;
    final repeatDays = validatedRepeatDays(block);

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
      repeatRule: repeatDays.length == 7 ? 'daily' : 'weekly',
      blockType: blockTypeForSection(section, block),
      category: categoryForSection(section, block),
      source: RoutineSource.baseTimeline,
      baseTimelineSection: section.name,
      onboardingVisualStyleKey: visualStyleKeyForSectionBlock(
        section: section,
        index: index,
        setup: setup,
      ),
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

  static String visualStyleKeyForSectionBlock({
    required BaseTimelineSection section,
    required int index,
    BaseTimelineSetup? setup,
  }) {
    return switch (section) {
      BaseTimelineSection.classes => 'class:$index',
      BaseTimelineSection.work => 'work:$index',
      BaseTimelineSection.eating => 'eating:default',
      BaseTimelineSection.fixed => 'fixed:default',
      BaseTimelineSection.skinCare => switch (setup?.skinCareSetupPath) {
        'products' => 'skin:has-products',
        'build_for_me' => 'skin:no-products',
        'skip' => 'skin:default',
        _ => 'skin:default',
      },
    };
  }

  static List<RoutineItem> routineItemsForSectionBlocks({
    required String uid,
    required BaseTimelineSection section,
    required List<TimelineBlockDraft> blocks,
    required DateTime now,
    BaseTimelineSetup? setup,
  }) {
    return [
      for (var index = 0; index < blocks.length; index++)
        routineItemForSectionBlock(
          uid: uid,
          section: section,
          block: blocks[index],
          index: index,
          now: now,
          setup: setup,
        ),
    ];
  }

  Future<BaseTimelineSectionReplaceResult> replaceSection({
    required String uid,
    required BaseTimelineSection section,
    required List<TimelineBlockDraft> newBlocks,
    int? expectedRevision,
    required BaseTimelineSetup Function(BaseTimelineSetup current) updateSetup,
  }) async {
    // 0. Strict validation of all incoming blocks before any fetch or durable mutation
    for (final block in newBlocks) {
      validatedRepeatDays(block);
    }

    // 1. Fetch current setup and routine items
    final currentSetup = await _setupRepo.fetchSetup(uid);
    final editorRevision = expectedRevision ?? currentSetup.revision;
    if (currentSetup.revision != editorRevision) {
      throw BaseTimelineConcurrencyException(
        expectedRevision: editorRevision,
        actualRevision: currentSetup.revision,
      );
    }
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
      setup: currentSetup,
    );

    // 4. Atomic transaction with live revision optimistic concurrency check
    final commitResult = await _transactionRepo.replaceBaseTimelineSection(
      uid: uid,
      section: section,
      expectedRevision: editorRevision,
      newRoutineItems: newRoutineItems,
      additionalDeleteIds: legacyItemsToDelete,
      buildUpdatedSetup: (liveSetup) {
        return updateSetup(liveSetup);
      },
    );

    // 5. Commit succeeded! Record latest revision for monotonicity protection
    final commitRevision = commitResult.revision;
    _latestCommittedRevisionByUid[uid] = commitRevision;

    // 6. Update in-memory state directly from the committed transaction result
    // and reconcile Routine frontend.
    var refreshStatus = BaseTimelineRoutineRefreshStatus.notAttempted;
    String? refreshMessage;

    if (_ref != null) {
      _ref
          .read(baseTimelineSetupNotifierProvider.notifier)
          .updateInMemory(commitResult.committedSetup);

      try {
        await _ref.read(routineNotifierProvider.notifier).loadForOwner(uid);
        if ((_latestCommittedRevisionByUid[uid] ?? 0) <= commitRevision) {
          _latestRefreshStatusByUid[uid] =
              BaseTimelineRoutineRefreshStatus.refreshed;
        }
        refreshStatus = BaseTimelineRoutineRefreshStatus.refreshed;
      } catch (_) {
        if ((_latestCommittedRevisionByUid[uid] ?? 0) <= commitRevision) {
          _latestRefreshStatusByUid[uid] =
              BaseTimelineRoutineRefreshStatus.refreshPending;
        }
        refreshStatus = BaseTimelineRoutineRefreshStatus.refreshPending;
        refreshMessage = 'Saved, but Routine needs to refresh.';
      }
    }

    return BaseTimelineSectionReplaceResult(
      commit: commitResult,
      routineRefreshStatus: refreshStatus,
      routineRefreshMessage: refreshMessage,
    );
  }

  /// Safely retries Routine frontend reconciliation after a commit resulted in
  /// [BaseTimelineRoutineRefreshStatus.refreshPending].
  ///
  /// Invariants:
  /// - Only calls [RoutineNotifier.loadForOwner].
  /// - NEVER reruns [replaceSection] or [replaceBaseTimelineSection].
  /// - NEVER saves [BaseTimelineSetup] or increments revision.
  /// - NEVER retires photo assets.
  /// - Rejects retries if the active session UID no longer matches [uid].
  /// - If [targetRevision] is provided and older than the latest committed revision,
  ///   does not downgrade the latest reconciliation status.
  Future<BaseTimelineRoutineRefreshResult> retryRoutineRefresh({
    required String uid,
    int? targetRevision,
  }) async {
    final ref = _ref;
    if (ref == null) {
      return const BaseTimelineRoutineRefreshResult(
        status: BaseTimelineRoutineRefreshStatus.notAttempted,
      );
    }

    // Owner isolation guard: ensure active session matches requested UID
    final activeUid = ref.read(routineNotifierProvider.notifier).ownerUid ??
        ref.read(userProfileProvider).uid;
    if (activeUid.trim().isEmpty || activeUid != uid) {
      return const BaseTimelineRoutineRefreshResult(
        status: BaseTimelineRoutineRefreshStatus.notAttempted,
        message: 'Active session does not match requested owner.',
      );
    }

    // Revision monotonic guard: older retries cannot downgrade newer revisions
    final latestRev = _latestCommittedRevisionByUid[uid];
    if (targetRevision != null && latestRev != null && targetRevision < latestRev) {
      return BaseTimelineRoutineRefreshResult(
        status: _latestRefreshStatusByUid[uid] ??
            BaseTimelineRoutineRefreshStatus.refreshed,
        message: 'Superseded by newer revision.',
      );
    }

    try {
      await ref.read(routineNotifierProvider.notifier).loadForOwner(uid);
      if (targetRevision == null ||
          targetRevision >= (_latestCommittedRevisionByUid[uid] ?? 0)) {
        _latestRefreshStatusByUid[uid] =
            BaseTimelineRoutineRefreshStatus.refreshed;
      }
      return const BaseTimelineRoutineRefreshResult(
        status: BaseTimelineRoutineRefreshStatus.refreshed,
      );
    } catch (_) {
      if (targetRevision == null ||
          targetRevision >= (_latestCommittedRevisionByUid[uid] ?? 0)) {
        _latestRefreshStatusByUid[uid] =
            BaseTimelineRoutineRefreshStatus.refreshPending;
      }
      return const BaseTimelineRoutineRefreshResult(
        status: BaseTimelineRoutineRefreshStatus.refreshPending,
        message: 'Saved, but Routine needs to refresh.',
      );
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
