import 'dart:async';
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

  const BaseTimelineRoutineRefreshResult({required this.status, this.message});

  bool get isRefreshed => status == BaseTimelineRoutineRefreshStatus.refreshed;
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
      routineRefreshStatus == BaseTimelineRoutineRefreshStatus.refreshPending;
}

/// Immutable snapshot pairing a durable Base Timeline revision with its
/// post-commit frontend Routine reconciliation status and message.
@immutable
class BaseTimelineRoutineRefreshState {
  final int revision;
  final BaseTimelineRoutineRefreshStatus status;
  final String? message;

  const BaseTimelineRoutineRefreshState({
    required this.revision,
    required this.status,
    this.message,
  });
}

class BaseTimelineTransactionCoordinator {
  final RoutineRepository _routineRepo;
  final RoutineTransactionRepository _transactionRepo;
  final BaseTimelineSetupRepository _setupRepo;
  final Ref? _ref;
  final Map<String, int> _latestCommittedRevisionByUid = {};
  final Map<String, BaseTimelineRoutineRefreshState> _latestRefreshStateByUid =
      {};
  final Map<String, Future<void>> _reconciliationTailByUid = {};

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
    return _latestRefreshStateByUid[uid]?.status ??
        BaseTimelineRoutineRefreshStatus.notAttempted;
  }

  int? latestRefreshRevisionFor(String uid) {
    return _latestRefreshStateByUid[uid]?.revision;
  }

  /// Centralized revision-monotonic reconciliation status publisher.
  ///
  /// Invariant:
  /// - Only updates shared latest state if [revision] belongs to the newest known
  ///   durable revision ([latestCommitted]) AND is monotonic with respect to
  ///   any currently published status revision ([currentStatusRev]).
  /// - An older revision cannot become current merely because it is newer than
  ///   an even older status record (requires BOTH monotonic conditions, never OR).
  bool _recordRefreshStatusIfCurrent({
    required String uid,
    required int revision,
    required BaseTimelineRoutineRefreshStatus status,
    String? message,
  }) {
    final latestCommitted = _latestCommittedRevisionByUid[uid] ?? 0;
    final currentState = _latestRefreshStateByUid[uid];
    final currentStatusRev = currentState?.revision ?? 0;

    if (revision < latestCommitted || revision < currentStatusRev) {
      return false;
    }

    _latestRefreshStateByUid[uid] = BaseTimelineRoutineRefreshState(
      revision: revision,
      status: status,
      message: message,
    );
    return true;
  }

  /// Canonical active session validation for post-commit coordinator paths.
  ///
  /// Authority rules:
  /// - The active profile UID ([userProfileProvider.uid]) MUST equal [targetUid].
  /// - If [RoutineNotifier.ownerUid] is non-null and non-empty, it MUST NOT
  ///   contradict [targetUid].
  bool _isSessionValidForOwner(String targetUid) {
    final ref = _ref;
    if (ref == null) return false;

    final activeProfileUid = ref.read(userProfileProvider).uid.trim();
    if (activeProfileUid.isEmpty || activeProfileUid != targetUid) {
      return false;
    }

    final routineOwner = ref
        .read(routineNotifierProvider.notifier)
        .ownerUid
        ?.trim();
    if (routineOwner != null &&
        routineOwner.isNotEmpty &&
        routineOwner != targetUid) {
      return false;
    }

    return true;
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
    _recordRefreshStatusIfCurrent(
      uid: uid,
      revision: commitRevision,
      status: BaseTimelineRoutineRefreshStatus.notAttempted,
    );

    // 6. Post-commit frontend reconciliation.
    //
    // Once replaceBaseTimelineSection returns successfully, the Base Timeline
    // transaction is durable. Post-commit local publication and Routine
    // reconciliation must NEVER convert a durable success into a thrown failure.
    if (_ref == null) {
      return BaseTimelineSectionReplaceResult(
        commit: commitResult,
        routineRefreshStatus: BaseTimelineRoutineRefreshStatus.notAttempted,
      );
    }

    // Verify current active account still matches commit UID before local publication
    if (!_isSessionValidForOwner(uid)) {
      _recordRefreshStatusIfCurrent(
        uid: uid,
        revision: commitRevision,
        status: BaseTimelineRoutineRefreshStatus.notAttempted,
        message:
            'Saved for the previous account; local refresh was skipped because the active account changed.',
      );
      return BaseTimelineSectionReplaceResult(
        commit: commitResult,
        routineRefreshStatus: BaseTimelineRoutineRefreshStatus.notAttempted,
        routineRefreshMessage:
            'Saved for the previous account; local refresh was skipped because the active account changed.',
      );
    }

    // Safe in-memory publication: ensure target notifier is bound to this UID
    try {
      final setupNotifier = _ref.read(
        baseTimelineSetupNotifierProvider.notifier,
      );
      if (setupNotifier.uid == uid) {
        setupNotifier.updateInMemory(commitResult.committedSetup);
      }
    } catch (_) {
      // In-memory update error must not throw as save failure
    }

    // Fresh Routine reconciliation
    final refreshResult = await _reconcileCommittedRoutine(
      uid: uid,
      committedRevision: commitRevision,
      accountSwitchedMessage:
          'Saved for the previous account; local refresh was skipped because the active account changed.',
    );

    return BaseTimelineSectionReplaceResult(
      commit: commitResult,
      routineRefreshStatus: refreshResult.status,
      routineRefreshMessage: refreshResult.message,
    );
  }

  /// Serializes Routine reconciliation per UID, ensuring that:
  /// - At least one Routine repository fetch begins after this commit became durable.
  /// - Any pre-commit load or concurrent older commit reconciliation completes before
  ///   this revision initiates its fetch.
  /// - A newer committed revision cannot have its latest status downgraded by an older
  ///   reconciliation.
  /// - The durable commit result is never converted into an exception if the active
  ///   session changes or the reload fails.
  Future<BaseTimelineRoutineRefreshResult> _reconcileCommittedRoutine({
    required String uid,
    required int committedRevision,
    String? accountSwitchedMessage,
  }) async {
    final ref = _ref;
    if (ref == null) {
      return const BaseTimelineRoutineRefreshResult(
        status: BaseTimelineRoutineRefreshStatus.notAttempted,
      );
    }

    // 1. Initial active session check before queuing
    if (!_isSessionValidForOwner(uid)) {
      _recordRefreshStatusIfCurrent(
        uid: uid,
        revision: committedRevision,
        status: BaseTimelineRoutineRefreshStatus.notAttempted,
        message:
            accountSwitchedMessage ??
            'Active session does not match requested owner.',
      );
      return BaseTimelineRoutineRefreshResult(
        status: BaseTimelineRoutineRefreshStatus.notAttempted,
        message:
            accountSwitchedMessage ??
            'Active session does not match requested owner.',
      );
    }

    // 2. Queue behind any active reconciliation for this UID
    final previousReconciliation = _reconciliationTailByUid[uid];
    final completer = Completer<void>();
    _reconciliationTailByUid[uid] = completer.future;

    try {
      if (previousReconciliation != null) {
        try {
          await previousReconciliation;
        } catch (_) {
          // Prior reconciliation failure must not prevent this revision's fresh reload
        }
      }

      // 3. Re-verify active session after awaiting prior reconciliation
      if (!_isSessionValidForOwner(uid)) {
        _recordRefreshStatusIfCurrent(
          uid: uid,
          revision: committedRevision,
          status: BaseTimelineRoutineRefreshStatus.notAttempted,
          message:
              accountSwitchedMessage ??
              'Active session does not match requested owner.',
        );
        return BaseTimelineRoutineRefreshResult(
          status: BaseTimelineRoutineRefreshStatus.notAttempted,
          message:
              accountSwitchedMessage ??
              'Active session does not match requested owner.',
        );
      }

      // 4. Perform fresh-after-commit reload using reloadForOwnerAfterCurrentLoad
      try {
        final reloadWon = await ref
            .read(routineNotifierProvider.notifier)
            .reloadForOwnerAfterCurrentLoad(uid);

        // Re-verify session and authoritative win after the fresh load completes
        if (!reloadWon || !_isSessionValidForOwner(uid)) {
          _recordRefreshStatusIfCurrent(
            uid: uid,
            revision: committedRevision,
            status: BaseTimelineRoutineRefreshStatus.notAttempted,
            message:
                accountSwitchedMessage ??
                'Saved, but local refresh was skipped because the active account changed.',
          );
          return BaseTimelineRoutineRefreshResult(
            status: BaseTimelineRoutineRefreshStatus.notAttempted,
            message:
                accountSwitchedMessage ??
                'Saved, but local refresh was skipped because the active account changed.',
          );
        }

        final recorded = _recordRefreshStatusIfCurrent(
          uid: uid,
          revision: committedRevision,
          status: BaseTimelineRoutineRefreshStatus.refreshed,
        );

        return BaseTimelineRoutineRefreshResult(
          status: recorded
              ? BaseTimelineRoutineRefreshStatus.refreshed
              : BaseTimelineRoutineRefreshStatus.notAttempted,
          message: recorded ? null : 'Superseded by newer revision.',
        );
      } catch (_) {
        final recorded = _recordRefreshStatusIfCurrent(
          uid: uid,
          revision: committedRevision,
          status: BaseTimelineRoutineRefreshStatus.refreshPending,
          message: 'Saved, but Routine needs to refresh.',
        );

        return BaseTimelineRoutineRefreshResult(
          status: recorded
              ? BaseTimelineRoutineRefreshStatus.refreshPending
              : BaseTimelineRoutineRefreshStatus.notAttempted,
          message: recorded
              ? 'Saved, but Routine needs to refresh.'
              : 'Superseded by newer revision.',
        );
      }
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (identical(_reconciliationTailByUid[uid], completer.future)) {
        _reconciliationTailByUid.remove(uid);
      }
    }
  }

  /// Safely retries Routine frontend reconciliation after a commit resulted in
  /// [BaseTimelineRoutineRefreshStatus.refreshPending].
  ///
  /// Invariants:
  /// - Only calls [RoutineNotifier.reloadForOwnerAfterCurrentLoad].
  /// - NEVER reruns [replaceSection] or [replaceBaseTimelineSection].
  /// - NEVER saves [BaseTimelineSetup] or increments revision.
  /// - NEVER retires photo assets.
  /// - Rejects retries if the active session UID no longer matches [uid].
  /// - If [targetRevision] is provided and older than the latest committed revision,
  ///   does not downgrade the latest reconciliation status.
  /// - If [targetRevision] is greater than the latest committed revision, rejects retry.
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
    if (!_isSessionValidForOwner(uid)) {
      return const BaseTimelineRoutineRefreshResult(
        status: BaseTimelineRoutineRefreshStatus.notAttempted,
        message: 'Active session does not match requested owner.',
      );
    }

    final latestRev = _latestCommittedRevisionByUid[uid];
    if (latestRev == null) {
      return const BaseTimelineRoutineRefreshResult(
        status: BaseTimelineRoutineRefreshStatus.notAttempted,
        message: 'No committed Base Timeline revision found to retry.',
      );
    }

    if (targetRevision != null) {
      if (targetRevision < latestRev) {
        return BaseTimelineRoutineRefreshResult(
          status: latestRefreshStatusFor(uid),
          message: 'Superseded by newer revision.',
        );
      }
      if (targetRevision > latestRev) {
        return const BaseTimelineRoutineRefreshResult(
          status: BaseTimelineRoutineRefreshStatus.notAttempted,
          message: 'Target revision exceeds latest committed revision.',
        );
      }
    }

    return await _reconcileCommittedRoutine(
      uid: uid,
      committedRevision: targetRevision ?? latestRev,
    );
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
