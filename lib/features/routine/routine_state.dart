import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/services/routine_failure_classifier.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/tracker_session_link.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/routine_projection_receipt_validator.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/features/routine/services/routine_countdown_allocator.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/services/routine_transition_policy.dart';
import 'package:optivus/features/routine/services/routine_day_availability.dart';
import 'package:optivus/features/routine/services/routine_entry_filter.dart';
import 'package:optivus/features/routine/models/routine_filter_definitions.dart';
import 'package:optivus/features/routine/models/routine_filter_selection.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';

export 'package:optivus/features/routine/models/routine_filter_definitions.dart';
export 'package:optivus/features/routine/models/routine_filter_selection.dart';

enum RoutineWriteAction { create, update, delete, moveTemplate, batchCreate }

@immutable
class RoutineDiscardResult {
  final bool wasSaved;
  final bool discarded;
  final bool verificationUnavailable;
  final String? message;

  const RoutineDiscardResult({
    required this.wasSaved,
    required this.discarded,
    this.verificationUnavailable = false,
    this.message,
  });

  const RoutineDiscardResult.verificationUnavailable({
    this.message = 'Could not verify remote save status. Draft preserved.',
  }) : wasSaved = false,
       discarded = false,
       verificationUnavailable = true;
}

enum RoutineOccurrenceAction {
  start,
  startTracker,
  complete,
  skip,
  miss,
  move,
  reschedule,
  checkIn,
  toggleSubtask,
  makeTiny,
  undo,
}

enum RoutineOccurrenceMutationType { setRecord, deleteRecord }

class RoutineOccurrenceWriteIntent {
  final RoutineOccurrenceAction action;
  final RoutineOccurrenceMutationType mutationType;
  final String ownerUid;
  final String occurrenceId;
  final String operationId;
  final RoutineOccurrenceRecord attemptedRecord;
  final RoutineOccurrenceRecord? previousRecord;
  final DateTime createdAt;
  final RoutineEventRecord? event;
  final Completer<RoutineWriteResult>? completer;

  const RoutineOccurrenceWriteIntent({
    required this.action,
    this.mutationType = RoutineOccurrenceMutationType.setRecord,
    required this.ownerUid,
    required this.occurrenceId,
    required this.operationId,
    required this.attemptedRecord,
    this.previousRecord,
    required this.createdAt,
    this.event,
    this.completer,
  });
}

class RoutineWriteIntent {
  final RoutineWriteAction action;
  final String ownerUid;
  final String itemId;
  final String operationId;
  final RoutineItem? attemptedItem;
  final RoutineItem? previousItem;
  final DateTime createdAt;
  final RoutineEventRecord? event;

  const RoutineWriteIntent({
    required this.action,
    required this.ownerUid,
    required this.itemId,
    required this.operationId,
    this.attemptedItem,
    this.previousItem,
    required this.createdAt,
    this.event,
  });
}

class RoutineBatchWriteIntent {
  final String ownerUid;
  final String operationId;
  final RoutineWriteAction action;
  final List<RoutineItem> attemptedItems;
  final List<RoutineItem> previousItems;
  final List<RoutineEventRecord> events;
  final DateTime createdAt;

  const RoutineBatchWriteIntent({
    required this.ownerUid,
    required this.operationId,
    required this.action,
    required this.attemptedItems,
    this.previousItems = const [],
    required this.events,
    required this.createdAt,
  });
}

class RoutineQueuedOccurrenceAction {
  final String itemId;
  final RoutineOccurrenceAction action;
  final String actionString;
  final RoutineStatus? targetStatus;
  final String actionSource;
  final DateTime? occurrenceDate;
  final String? note;
  final String? displayTitleOverride;
  final String? movedToDateKey;
  final int? movedStartMinute;
  final int? movedEndMinute;
  final List<int>? completedSubtaskIndexes;
  final DateTime? startedAt;
  final int? countdownDurationSeconds;
  final String? trackerSessionId;
  final String? trackerType;
  final String? source;
  final Completer<RoutineWriteResult>? completer;
  final DateTime queuedAt;

  const RoutineQueuedOccurrenceAction({
    required this.itemId,
    required this.action,
    required this.actionString,
    this.targetStatus,
    this.actionSource = 'routine',
    this.occurrenceDate,
    this.note,
    this.displayTitleOverride,
    this.movedToDateKey,
    this.movedStartMinute,
    this.movedEndMinute,
    this.completedSubtaskIndexes,
    this.startedAt,
    this.countdownDurationSeconds,
    this.trackerSessionId,
    this.trackerType,
    this.source,
    this.completer,
    required this.queuedAt,
  });
}

class RoutineState {
  final List<RoutineItem> items;
  final List<RoutineOccurrenceRecord> occurrences;
  final List<RoutineEventRecord> events;
  final List<RoutineCorruptEvent> corruptEvents;
  final DateTime selectedDay;
  final String selectedPrimaryFilter;
  final String selectedStatusFilter;
  final String selectedCategoryFilter;
  final bool showFullDay;
  final bool compactMode;
  final bool showMinuteTicks;
  final bool showCurrentTimeLine;
  final bool precisionMode;
  final bool loading;
  final bool eventsLoading;
  final String? error;
  final String? eventsError;
  final TrackerLaunchIntent? activeTrackerLaunchIntent;
  final bool aiRoutineSuggestionsEnabled;
  final bool routineNotificationsEnabled;
  final bool refreshing;
  final Set<String> pendingItemIds;
  final Set<String> pendingOccurrenceIds;
  final Map<String, RoutineWriteIntent> failedIntentsByItemId;
  final Map<String, RoutineOccurrenceWriteIntent> failedOccurrenceIntentsById;
  final Map<String, List<RoutineQueuedOccurrenceAction>>
  queuedOccurrenceActionsById;
  final Map<String, RoutineBatchWriteIntent> failedBatchIntentsByOperationId;

  Map<String, List<RoutineOccurrenceWriteIntent>>
  get queuedOccurrenceIntentsById {
    if (queuedOccurrenceActionsById.isEmpty) return const {};
    final map = <String, List<RoutineOccurrenceWriteIntent>>{};
    for (final entry in queuedOccurrenceActionsById.entries) {
      map[entry.key] = const [];
    }
    return map;
  }

  const RoutineState({
    required this.items,
    this.occurrences = const [],
    this.events = const [],
    this.corruptEvents = const [],
    required this.selectedDay,
    this.selectedPrimaryFilter = 'all',
    this.selectedStatusFilter = 'any',
    this.selectedCategoryFilter = 'all',
    this.showFullDay = false,
    this.compactMode = false,
    this.showMinuteTicks = true,
    this.showCurrentTimeLine = true,
    this.precisionMode = false,
    this.loading = false,
    this.eventsLoading = false,
    this.error,
    this.eventsError,
    this.activeTrackerLaunchIntent,
    this.aiRoutineSuggestionsEnabled = true,
    this.routineNotificationsEnabled = false,
    this.refreshing = false,
    this.pendingItemIds = const {},
    this.pendingOccurrenceIds = const {},
    this.failedIntentsByItemId = const {},
    this.failedOccurrenceIntentsById = const {},
    this.queuedOccurrenceActionsById = const {},
    this.failedBatchIntentsByOperationId = const {},
  });

  RoutineState copyWith({
    List<RoutineItem>? items,
    List<RoutineOccurrenceRecord>? occurrences,
    List<RoutineEventRecord>? events,
    List<RoutineCorruptEvent>? corruptEvents,
    DateTime? selectedDay,
    String? selectedPrimaryFilter,
    String? selectedStatusFilter,
    String? selectedCategoryFilter,
    bool? showFullDay,
    bool? compactMode,
    bool? showMinuteTicks,
    bool? showCurrentTimeLine,
    bool? precisionMode,
    bool? loading,
    bool? eventsLoading,
    String? error,
    String? eventsError,
    bool clearError = false,
    bool clearEventsError = false,
    TrackerLaunchIntent? activeTrackerLaunchIntent,
    bool clearTrackerIntent = false,
    bool? aiRoutineSuggestionsEnabled,
    bool? routineNotificationsEnabled,
    bool? refreshing,
    Set<String>? pendingItemIds,
    Set<String>? pendingOccurrenceIds,
    Map<String, RoutineWriteIntent>? failedIntentsByItemId,
    Map<String, RoutineOccurrenceWriteIntent>? failedOccurrenceIntentsById,
    Map<String, List<RoutineQueuedOccurrenceAction>>?
    queuedOccurrenceActionsById,
    Map<String, List<RoutineOccurrenceWriteIntent>>?
    queuedOccurrenceIntentsById,
    Map<String, RoutineBatchWriteIntent>? failedBatchIntentsByOperationId,
  }) {
    return RoutineState(
      items: items ?? this.items,
      occurrences: occurrences ?? this.occurrences,
      events: events ?? this.events,
      corruptEvents: corruptEvents ?? this.corruptEvents,
      selectedDay: selectedDay ?? this.selectedDay,
      selectedPrimaryFilter:
          selectedPrimaryFilter ?? this.selectedPrimaryFilter,
      selectedStatusFilter: selectedStatusFilter ?? this.selectedStatusFilter,
      selectedCategoryFilter:
          selectedCategoryFilter ?? this.selectedCategoryFilter,
      showFullDay: showFullDay ?? this.showFullDay,
      compactMode: compactMode ?? this.compactMode,
      showMinuteTicks: showMinuteTicks ?? this.showMinuteTicks,
      showCurrentTimeLine: showCurrentTimeLine ?? this.showCurrentTimeLine,
      precisionMode: precisionMode ?? this.precisionMode,
      loading: loading ?? this.loading,
      eventsLoading: eventsLoading ?? this.eventsLoading,
      error: clearError ? null : error,
      eventsError: clearEventsError ? null : (eventsError ?? this.eventsError),
      activeTrackerLaunchIntent: clearTrackerIntent
          ? null
          : (activeTrackerLaunchIntent ?? this.activeTrackerLaunchIntent),
      aiRoutineSuggestionsEnabled:
          aiRoutineSuggestionsEnabled ?? this.aiRoutineSuggestionsEnabled,
      routineNotificationsEnabled:
          routineNotificationsEnabled ?? this.routineNotificationsEnabled,
      refreshing: refreshing ?? this.refreshing,
      pendingItemIds: pendingItemIds ?? this.pendingItemIds,
      pendingOccurrenceIds: pendingOccurrenceIds ?? this.pendingOccurrenceIds,
      failedIntentsByItemId:
          failedIntentsByItemId ?? this.failedIntentsByItemId,
      failedOccurrenceIntentsById:
          failedOccurrenceIntentsById ?? this.failedOccurrenceIntentsById,
      queuedOccurrenceActionsById:
          queuedOccurrenceActionsById ?? this.queuedOccurrenceActionsById,
      failedBatchIntentsByOperationId:
          failedBatchIntentsByOperationId ??
          this.failedBatchIntentsByOperationId,
    );
  }

  /// Canonical filter selection across View, Status, and Category axes.
  RoutineFilterSelection get filterSelection => RoutineFilterSelection(
    view: selectedPrimaryFilter,
    status: selectedStatusFilter,
    category: selectedCategoryFilter,
  );
}

class TrackerLaunchIntent {
  final TrackerType trackerType;
  final String routineTaskId;
  final String? occurrenceDateKey;
  final String sessionId;
  final DateTime startedAt;

  const TrackerLaunchIntent({
    required this.trackerType,
    required this.routineTaskId,
    this.occurrenceDateKey,
    required this.sessionId,
    required this.startedAt,
  });
}

class RoutineTrackerLinksNotifier
    extends StateNotifier<List<TrackerSessionLink>> {
  RoutineTrackerLinksNotifier() : super(const []);

  void upsert(TrackerSessionLink link) {
    state = [
      for (final existing in state)
        if (existing.routineTaskId == link.routineTaskId &&
            existing.occurrenceDateKey == link.occurrenceDateKey)
          link
        else
          existing,
      if (!state.any(
        (existing) =>
            existing.routineTaskId == link.routineTaskId &&
            existing.occurrenceDateKey == link.occurrenceDateKey,
      ))
        link,
    ];
  }

  void clearForRoutine(String routineTaskId) {
    state = state
        .where((link) => link.routineTaskId != routineTaskId)
        .toList(growable: false);
  }

  void replaceAll(List<TrackerSessionLink> links) {
    state = List.unmodifiable(links);
  }

  void reset() => state = const [];
  void resetForSignedOut() => reset();
}

final trackerSessionLinksProvider =
    StateNotifierProvider<
      RoutineTrackerLinksNotifier,
      List<TrackerSessionLink>
    >((ref) {
      return RoutineTrackerLinksNotifier();
    });

class RoutineNotifier extends StateNotifier<RoutineState> {
  final RoutineRepository _repository;
  final RoutineHistoryRepository _historyRepository;
  final RoutineTransactionRepository _transactionRepository;
  final Ref _ref;
  final OnboardingRepository? _onboardingRepository;
  Future<void> _initialLoad = Future<void>.value();
  String? _ownerUid;
  String? get ownerUid => _ownerUid;
  int _loadGeneration = 0;
  int _eventsGeneration = 0;
  StreamSubscription<RoutineEventFeed>? _eventsSubscription;
  String? _inFlightProjectionIntegritySignature;
  String? _lastSuccessfulProjectionIntegritySignature;
  final Map<String, int> _projectionIntegrityRetryCount = {};
  final Map<String, DateTime> _projectionIntegrityNextRetryAt = {};
  Future<bool>? _inFlightProjectionRepair;
  Future<bool>? _inFlightBaseTimelineFoundationRepair;
  String? _inFlightBaseTimelineFoundationRepairSignature;

  Future<bool>? get inFlightProjectionRepair => _inFlightProjectionRepair;
  Future<bool>? get inFlightBaseTimelineFoundationRepair =>
      _inFlightBaseTimelineFoundationRepair;

  BaseTimelineSection? _foundationSectionForItem(RoutineItem item) {
    if (item.baseTimelineSection != null) {
      for (final section in BaseTimelineSection.values) {
        if (item.baseTimelineSection == section.name) return section;
      }
    }
    return switch (item.category) {
      RoutineCategory.classBlock => BaseTimelineSection.classes,
      RoutineCategory.job => BaseTimelineSection.work,
      RoutineCategory.eating => BaseTimelineSection.eating,
      RoutineCategory.fixed ||
      RoutineCategory.sleep => BaseTimelineSection.fixed,
      RoutineCategory.skinCare => BaseTimelineSection.skinCare,
      _ => null,
    };
  }

  bool _isLiveOnboardingExpectation({
    required RoutineItem item,
    required BaseTimelineSetup setup,
  }) {
    final section = _foundationSectionForItem(item);
    if (section == null) return true;
    return setup.authorityFor(section) ==
        BaseTimelineSectionAuthority.onboardingSeed;
  }

  bool _hasGeneratedSourceNote(RoutineItem item) {
    if (item.source != RoutineSource.onboarding) return false;
    return switch (item.notes?.trim()) {
      'identity_system' => item.category == RoutineCategory.identity,
      'merged_habit_system' ||
      'good_habit' => item.category == RoutineCategory.habit,
      'bad_habit_check_in' => item.category == RoutineCategory.badHabit,
      'money' || 'money_task' => item.category == RoutineCategory.finance,
      _ => false,
    };
  }

  RoutineItem _liveRepairItem(RoutineItem item) {
    return _hasGeneratedSourceNote(item)
        ? item.copyWith(clearNotes: true)
        : item;
  }

  Future<BaseTimelineSetup?> _fetchBaseTimelineOnboardingSource({
    required String uid,
    OnboardingCompletionBundle? bundle,
    RoutineOnboardingProjectionPlan? plan,
  }) async {
    final onboarding = _onboardingRepository;
    if (onboarding == null) return null;
    try {
      final draft = await onboarding.fetchDraft(uid);
      final effectiveBundle =
          bundle ?? await onboarding.fetchCompletionBundle(uid);
      if (draft != null && effectiveBundle != null) {
        final effectivePlan =
            plan ?? RoutineOnboardingProjection.build(effectiveBundle);
        return BaseTimelineSetup.fromOnboardingCompletion(
          finalDraft: draft,
          bundle: effectiveBundle,
          projectedRoutineItems: effectivePlan.items,
        );
      }
      if (effectiveBundle != null) {
        final effectivePlan =
            plan ?? RoutineOnboardingProjection.build(effectiveBundle);
        return BaseTimelineSetup.fromCompletionBundle(
          uid,
          effectiveBundle,
          finalDraft: draft,
          projectedRoutineItems: effectivePlan.items,
        );
      }
      if (draft != null &&
          (draft.baseTimeline.blocks.isNotEmpty ||
              draft.baseTimeline.pendingFutureImports.isNotEmpty ||
              draft.baseTimeline.skinCareProductPhotoAssetId != null)) {
        return BaseTimelineSetup.fromOnboardingDraft(uid, draft);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'BaseTimelineFoundationRepair: onboarding source unavailable for $uid: $e',
        );
      }
    }
    return null;
  }

  bool _sameTimelineBlockList(
    List<TimelineBlockDraft> a,
    List<TimelineBlockDraft> b,
  ) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (jsonEncode(a[index].toMap()) != jsonEncode(b[index].toMap())) {
        return false;
      }
    }
    return true;
  }

  bool _sameStringListOrdered(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  bool _hasDurableBaseTimelineSectionEvidence(
    BaseTimelineSetup setup,
    BaseTimelineSection section,
  ) {
    if (setup.trackedIdsFor(section).isNotEmpty) return true;
    return switch (section) {
      BaseTimelineSection.classes =>
        setup.classLogicalAssetId != null ||
            setup.classLogicalAssetR2Key != null,
      BaseTimelineSection.work =>
        setup.workLogicalAssetId != null || setup.workLogicalAssetR2Key != null,
      BaseTimelineSection.eating =>
        setup.eatingSetupPath != null ||
            setup.eatingPhotoAssetId != null ||
            setup.eatingPhotoR2Key != null,
      BaseTimelineSection.fixed => setup.revision > 1,
      BaseTimelineSection.skinCare =>
        setup.skinCareSetupPath != null ||
            setup.skinCareSkipped ||
            setup.skinCareProductPhotoAssetId != null ||
            setup.skinCareProductPhotoR2Key != null ||
            setup.skinCareFacePhotoAssetId != null ||
            setup.skinCareFacePhotoR2Key != null,
    };
  }

  BaseTimelineSetup _setupWithStrongEvidenceAuthorities({
    required BaseTimelineSetup setup,
    required BaseTimelineSetup? onboardingSource,
    required List<RoutineItem> liveItems,
    required Set<BaseTimelineSection> ambiguousSections,
  }) {
    final liveIds = liveItems.map((item) => item.id).toSet();
    var migrated = setup;

    for (final section in BaseTimelineSection.values) {
      if (setup.authorityFor(section) ==
          BaseTimelineSectionAuthority.baseTimeline) {
        continue;
      }

      final hasBaseTimelineTemplates = liveItems.any(
        (item) =>
            item.source == RoutineSource.baseTimeline &&
            item.baseTimelineSection == section.name,
      );
      if (hasBaseTimelineTemplates) {
        migrated = migrated.withSectionAuthority(
          section,
          BaseTimelineSectionAuthority.baseTimeline,
        );
        continue;
      }

      final source = onboardingSource;
      if (source == null) continue;

      final currentBlocks = setup.blocksFor(section);
      final sourceBlocks = source.blocksFor(section);
      final matchesOnboardingSeed = _sameTimelineBlockList(
        currentBlocks,
        sourceBlocks,
      );
      final sourceIds = source.trackedIdsFor(section);
      final trackedIdsMatchOnboardingSeed = _sameStringListOrdered(
        setup.trackedIdsFor(section),
        sourceIds,
      );
      final sourceDocsExist =
          sourceIds.isNotEmpty && sourceIds.every(liveIds.contains);

      if ((matchesOnboardingSeed || trackedIdsMatchOnboardingSeed) &&
          sourceDocsExist) {
        continue;
      }

      if (trackedIdsMatchOnboardingSeed && sourceIds.isNotEmpty) {
        continue;
      }

      if (currentBlocks.isEmpty && sourceBlocks.isNotEmpty) {
        ambiguousSections.add(section);
        if (kDebugMode) {
          debugPrint(
            'BaseTimelineAuthorityMigration: ambiguous_empty_v2 '
            'uid=${setup.uid} section=${section.name}',
          );
        }
        continue;
      }

      if (currentBlocks.isNotEmpty &&
          !matchesOnboardingSeed &&
          _hasDurableBaseTimelineSectionEvidence(setup, section)) {
        migrated = migrated.withSectionAuthority(
          section,
          BaseTimelineSectionAuthority.baseTimeline,
        );
      }
    }

    return migrated;
  }

  void _scheduleBaseTimelineFoundationRepair({
    required String uid,
    required int generation,
    required List<RoutineItem> currentRemoteItems,
    OnboardingCompletionBundle? bundle,
  }) {
    if (_ownerUid != uid || generation != _loadGeneration) return;
    final repairFuture = _runBaseTimelineFoundationRepair(
      uid: uid,
      generation: generation,
      currentRemoteItems: currentRemoteItems,
      bundle: bundle,
    );
    _inFlightBaseTimelineFoundationRepair = repairFuture;
  }

  Future<bool> _runBaseTimelineFoundationRepair({
    required String uid,
    required int generation,
    required List<RoutineItem> currentRemoteItems,
    OnboardingCompletionBundle? bundle,
  }) async {
    try {
      final setupRepo = _ref.read(baseTimelineSetupRepositoryProvider);
      final setup = await setupRepo.fetchSetup(uid);
      final source = await _fetchBaseTimelineOnboardingSource(
        uid: uid,
        bundle: bundle,
      );
      if (!mounted || generation != _loadGeneration || _ownerUid != uid) {
        return false;
      }

      final ambiguousSections = <BaseTimelineSection>{};
      var migrated = _setupWithStrongEvidenceAuthorities(
        setup: setup,
        onboardingSource: source,
        liveItems: currentRemoteItems,
        ambiguousSections: ambiguousSections,
      );

      final signature = Object.hash(
        uid,
        migrated.revision,
        Object.hashAll(
          BaseTimelineSection.values.map(
            (section) => Object.hash(
              section.name,
              migrated.authorityFor(section).name,
              migrated.blocksFor(section).length,
              Object.hashAll(migrated.trackedIdsFor(section)),
            ),
          ),
        ),
        Object.hashAll(currentRemoteItems.map((item) => item.id)),
      ).toString();
      if (_inFlightBaseTimelineFoundationRepairSignature != null) {
        return false;
      }
      _inFlightBaseTimelineFoundationRepairSignature = signature;

      try {
        final liveIds = currentRemoteItems.map((item) => item.id).toSet();
        final liveItemById = {
          for (final item in currentRemoteItems) item.id: item,
        };
        final itemsToCreate = <RoutineItem>[];
        final itemsToPatch = <RoutineItem>[];
        var setupToSave = migrated;
        var needsSetupSave = !identical(migrated, setup);
        final now = DateTime.now();

        for (final section in BaseTimelineSection.values) {
          if (ambiguousSections.contains(section)) continue;
          if (migrated.authorityFor(section) !=
              BaseTimelineSectionAuthority.baseTimeline) {
            continue;
          }

          final expectedItems =
              BaseTimelineTransactionCoordinator.routineItemsForSectionBlocks(
                uid: uid,
                section: section,
                blocks: migrated.blocksFor(section),
                now: now,
                setup: migrated,
              );
          final expectedById = {
            for (final expected in expectedItems) expected.id: expected,
          };
          final expectedIds = expectedItems
              .map((item) => item.id)
              .toList(growable: false);
          final trackedIds = migrated.trackedIdsFor(section).toSet();
          final actualRoutineIds = currentRemoteItems
              .where(
                (item) =>
                    trackedIds.contains(item.id) ||
                    (item.source == RoutineSource.baseTimeline &&
                        item.baseTimelineSection == section.name),
              )
              .map((item) => item.id)
              .toSet();
          final missingIds = expectedIds
              .where((id) => !liveIds.contains(id))
              .toList(growable: false);
          if (kDebugMode) {
            debugPrint(
              '[BaseTimelineIntegrity] section=${section.name} '
              'authority=${migrated.authorityFor(section).name} '
              'configuredBlocks=${migrated.blocksFor(section).length} '
              'trackedIds=${trackedIds.length} '
              'actualRoutineIds=${actualRoutineIds.length} '
              'missing=${missingIds.length} '
              'repairAction=${missingIds.isEmpty ? 'none' : 'createMissing'}',
            );
          }
          if (!_sameStringListOrdered(
            setupToSave.trackedIdsFor(section),
            expectedIds,
          )) {
            setupToSave = setupToSave.withSectionRoutineIds(
              section,
              expectedIds,
            );
            needsSetupSave = true;
          }
          itemsToCreate.addAll(
            expectedItems.where((item) => !liveIds.contains(item.id)),
          );
          for (final expected in expectedItems) {
            final actual = liveItemById[expected.id];
            if (actual == null) continue;
            if (actual.userId != uid ||
                actual.source != RoutineSource.baseTimeline ||
                actual.baseTimelineSection != section.name ||
                expectedById[actual.id]?.id != actual.id) {
              continue;
            }
            if (actual.onboardingVisualStyleKey !=
                    expected.onboardingVisualStyleKey ||
                actual.blockType != expected.blockType ||
                actual.category != expected.category ||
                actual.hardBlock != expected.hardBlock) {
              itemsToPatch.add(
                actual.copyWith(
                  onboardingVisualStyleKey: expected.onboardingVisualStyleKey,
                  blockType: expected.blockType,
                  category: expected.category,
                  hardBlock: expected.hardBlock,
                ),
              );
            }
          }
        }

        if (itemsToCreate.isEmpty && itemsToPatch.isEmpty && !needsSetupSave) {
          return false;
        }

        var repaired = false;
        if (itemsToCreate.isNotEmpty) {
          final created = await _repository.createRoutineItemsIfMissing(
            uid,
            itemsToCreate,
          );
          repaired = created.isNotEmpty;
        }
        for (final item in itemsToPatch) {
          await _repository.updateRoutineItem(uid, item);
          repaired = true;
        }
        if (needsSetupSave) {
          await setupRepo.saveSetup(
            uid,
            setupToSave.copyWith(
              revision: setup.revision + 1,
              updatedAt: DateTime.now(),
            ),
          );
          repaired = true;
        }

        if (!mounted || generation != _loadGeneration || _ownerUid != uid) {
          return repaired;
        }
        if (repaired) {
          final refreshedItems = await _repository.fetchRoutineItems(uid);
          if (mounted && _ownerUid == uid) {
            _mergeRefreshedItems(refreshedItems);
          }
        }
        return repaired;
      } finally {
        if (_inFlightBaseTimelineFoundationRepairSignature == signature) {
          _inFlightBaseTimelineFoundationRepairSignature = null;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'BaseTimelineFoundationRepair: failed (safe degraded state): $e',
        );
      }
      return false;
    }
  }

  Map<String, dynamic> _boundedHistorySnapshot(RoutineItem item, String uid) {
    // Only capture the fields required to render history reliably
    // without bloating the event payload.
    return {
      'id': item.id,
      'title': item.title,
      'startMinute': item.startMinute,
      'durationMinutes': item.durationMinutes,
      'blockType': item.blockType.name,
      'trackerTaskType': item.trackerType.name,
      'hardBlock': item.hardBlock,
      if (item.onboardingProjectionId != null)
        'onboardingProjectionId': item.onboardingProjectionId,
    };
  }

  Map<String, dynamic>? _historySnapshotForItemId(String itemId, String uid) {
    final item = state.items
        .where((candidate) => candidate.id == itemId)
        .firstOrNull;
    return item == null ? null : _boundedHistorySnapshot(item, uid);
  }

  String _stableOperationId(String prefix, Iterable<Object?> parts) {
    final digest = sha256.convert(
      utf8.encode(
        [prefix, ...parts.map((part) => part?.toString() ?? '')].join('\u001f'),
      ),
    );
    return '${prefix}_${digest.toString().substring(0, 32)}';
  }

  String _itemMutationFingerprint(RoutineItem item) {
    final map = item.toMap();
    map.remove('createdAt');
    map.remove('updatedAt');
    map.remove('createdByOperationId');
    map.remove('lastMutationOperationId');
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return jsonEncode(Map<String, dynamic>.fromEntries(entries));
  }

  String _stableEventId({
    required String operationId,
    required String itemId,
    required RoutineEventType eventType,
  }) {
    final digest = sha256.convert(
      utf8.encode(
        'routine-event-v1\u001f$operationId\u001f$itemId\u001f${eventType.name}',
      ),
    );
    return 'evt_${digest.toString().substring(0, 40)}';
  }

  RoutineWriteResult _supersededWriteResult(String operationId) {
    return RoutineWriteResult.superseded(
      operationId: operationId,
      message: 'Routine owner changed before the write completed.',
      failureCategory: RoutineFailureCategory.ownerSuperseded,
    );
  }

  List<RoutineItem> _replaceItemsPreservingOrder(
    List<RoutineItem> current,
    List<RoutineItem> replacements,
  ) {
    final byId = {for (final item in replacements) item.id: item};
    final seen = <String>{};
    final merged = <RoutineItem>[];
    for (final item in current) {
      final replacement = byId[item.id];
      if (replacement == null) {
        merged.add(item);
        continue;
      }
      if (seen.add(item.id)) {
        merged.add(replacement);
      }
    }
    for (final item in replacements) {
      if (seen.add(item.id)) merged.add(item);
    }
    return merged;
  }

  RoutineNotifier(
    this._repository,
    this._historyRepository,
    this._transactionRepository,
    this._ref, [
    this._onboardingRepository,
  ]) : super(
         RoutineState(
           items: [],
           selectedDay: TimelineUtils.dateOnly(DateTime.now()),
         ),
       ) {
    if (_ref.read(fakeDataAllowedProvider)) {
      final initialUid = _ref.read(userProfileProvider).uid.trim();
      if (initialUid.isNotEmpty) {
        _initialLoad = loadForOwner(initialUid);
      } else {
        _ownerUid = 'local-development-user';
      }
    }
  }

  @override
  set state(RoutineState value) {
    if (value.selectedCategoryFilter != 'all') {
      final itemsOrOccurrencesChanged =
          (value.items != state.items ||
              value.occurrences != state.occurrences) &&
          (value.items.isNotEmpty ||
              state.items.isNotEmpty ||
              value.occurrences.isNotEmpty ||
              state.occurrences.isNotEmpty);
      if (itemsOrOccurrencesChanged) {
        final dayEntries = RoutineOccurrenceProjector.entriesForDay(
          value.items,
          value.occurrences,
          value.selectedDay,
        );
        final normalized = value.filterSelection.normalizedFor(dayEntries);
        if (normalized.category != value.selectedCategoryFilter) {
          value = value.copyWith(selectedCategoryFilter: normalized.category);
        }
      }
    }
    super.state = value;
  }

  Future<void>? _inFlightLoad;
  String? _inFlightUid;
  int? _inFlightGeneration;
  int _lastAuthoritativeLoadGeneration = 0;
  String? _lastAuthoritativeUid;

  /// Post-commit Routine reconciliation reload primitive.
  ///
  /// Guarantees that at least one fresh repository fetch begins after this method
  /// is invoked:
  /// 1. Validates [uid].
  /// 2. If a same-owner load is already in progress, waits for it to finish so
  ///    potentially stale pre-commit data is not joined.
  /// 3. Verifies owner isolation if the active owner changed while waiting.
  /// 4. Initiates a fresh [loadForOwner] after the prior load has completed/cleared.
  /// 5. Propagates any real failure from the new reload.
  ///
  /// Returns `true` if a fresh same-owner load completed and remains authoritative.
  /// Returns `false` if the owner or session changed before it could complete authoritatively.
  /// Real repository/network failures throw.
  Future<bool> reloadForOwnerAfterCurrentLoad(String uid) async {
    if (uid.trim().isEmpty || uid.contains('/')) {
      throw ArgumentError('A valid authenticated Routine owner is required.');
    }

    final priorLoad = (_ownerUid == uid && _inFlightUid == uid)
        ? _inFlightLoad
        : null;
    if (priorLoad != null) {
      try {
        await priorLoad;
      } catch (_) {
        // Stale pre-commit load failure must not prevent our fresh post-commit reload.
      }
    }

    if (_ownerUid != null && _ownerUid != uid) {
      return false;
    }

    final targetGeneration = _inFlightLoad != null
        ? (_inFlightGeneration ?? _loadGeneration)
        : (_loadGeneration + 1);

    await loadForOwner(uid);

    if (_ownerUid != uid) {
      return false;
    }
    if (_lastAuthoritativeUid != uid ||
        _lastAuthoritativeLoadGeneration < targetGeneration) {
      return false;
    }

    return true;
  }

  Future<void> loadForOwner(String uid) {
    if (uid.trim().isEmpty || uid.contains('/')) {
      throw ArgumentError('A valid authenticated Routine owner is required.');
    }
    if (_inFlightUid == uid && _inFlightLoad != null) {
      return _inFlightLoad!;
    }
    final completer = Completer<void>();
    _inFlightUid = uid;
    _inFlightLoad = completer.future;

    _performLoadForOwner(uid)
        .then(
          (value) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!completer.isCompleted) {
              completer.completeError(error, stack);
            }
          },
        )
        .whenComplete(() {
          if (identical(_inFlightLoad, completer.future)) {
            _inFlightLoad = null;
            _inFlightUid = null;
            _inFlightGeneration = null;
          }
        });

    return completer.future;
  }

  Future<void> _performLoadForOwner(String uid) async {
    final isNewOwner = _ownerUid != uid;
    final generation = ++_loadGeneration;
    _inFlightGeneration = generation;
    _ownerUid = uid;
    // Cancel old subscription BEFORE fetch to prevent stale events.
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    if (isNewOwner) {
      _ref.read(trackerSessionLinksProvider.notifier).reset();
      state = state.copyWith(
        loading: true,
        eventsLoading: true,
        occurrences: const [],
        events: const [],
        corruptEvents: const [],
        pendingItemIds: const {},
        pendingOccurrenceIds: const {},
        failedIntentsByItemId: const {},
        failedOccurrenceIntentsById: const {},
        queuedOccurrenceActionsById: const {},
        failedBatchIntentsByOperationId: const {},
        items: const [],
        clearError: true,
        clearEventsError: true,
        clearTrackerIntent: true,
      );
    } else {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final results = await Future.wait<Object?>([
        _repository.fetchRoutineItems(uid),
        _historyRepository.fetchHistory(uid),
        _onboardingRepository == null
            ? Future<OnboardingCompletionBundle?>.value(null)
            : _onboardingRepository.fetchCompletionBundle(uid),
      ]);
      if (generation != _loadGeneration || _ownerUid != uid) return;
      final remoteItems = (results[0] as List<RoutineItem>)
          .map(
            (remote) => remote.hasConflict || remote.conflictMessage != null
                ? remote.copyWith(hasConflict: false, clearConflict: true)
                : remote,
          )
          .toList();

      final localActiveIds = state.pendingItemIds.union(
        state.failedIntentsByItemId.keys.toSet(),
      );

      final mergedItems = <RoutineItem>[];
      for (final remote in remoteItems) {
        if (!localActiveIds.contains(remote.id)) {
          mergedItems.add(remote);
        }
      }
      for (final id in localActiveIds) {
        final localItem = state.items.where((e) => e.id == id).firstOrNull;
        if (localItem != null) {
          mergedItems.add(localItem);
        }
      }

      final mergedOccurrences = <RoutineOccurrenceRecord>[];
      final remoteOccurrences = results[1] as List<RoutineOccurrenceRecord>;
      final localOccurrenceIds = state.pendingOccurrenceIds.union(
        state.failedOccurrenceIntentsById.keys.toSet(),
      );

      for (final remote in remoteOccurrences) {
        if (!localOccurrenceIds.contains(remote.id)) {
          mergedOccurrences.add(remote);
        }
      }
      for (final id in localOccurrenceIds) {
        if (state.failedOccurrenceIntentsById.containsKey(id)) {
          final intent = state.failedOccurrenceIntentsById[id]!;
          mergedOccurrences.add(
            intent.previousRecord ?? intent.attemptedRecord,
          );
        } else {
          final localOcc = state.occurrences
              .where((e) => e.id == id)
              .firstOrNull;
          if (localOcc != null) {
            mergedOccurrences.add(localOcc);
          }
        }
      }

      final activeLinks = <TrackerSessionLink>[];
      TrackerLaunchIntent? restoredTrackerIntent;
      for (final occ in mergedOccurrences) {
        if (occ.status == RoutineStatus.inTracker &&
            occ.trackerSessionId != null) {
          final link = TrackerSessionLink(
            routineTaskId: occ.routineItemId,
            occurrenceDateKey: occ.occurrenceDateKey,
            trackerType: occ.trackerType ?? TrackerType.none.name,
            sessionId: occ.trackerSessionId!,
            startedAt: occ.startedAt ?? occ.createdAt,
            status: 'active',
          );
          activeLinks.add(link);
          restoredTrackerIntent ??= TrackerLaunchIntent(
            trackerType: TrackerType.values.firstWhere(
              (t) => t.name == occ.trackerType,
              orElse: () => TrackerType.none,
            ),
            routineTaskId: occ.routineItemId,
            occurrenceDateKey: occ.occurrenceDateKey,
            sessionId: occ.trackerSessionId!,
            startedAt: occ.startedAt ?? occ.createdAt,
          );
        }
      }
      _ref.read(trackerSessionLinksProvider.notifier).replaceAll(activeLinks);

      state = state.copyWith(
        items: mergedItems,
        occurrences: mergedOccurrences,
        activeTrackerLaunchIntent: restoredTrackerIntent,
        clearTrackerIntent: restoredTrackerIntent == null,
        loading: false,
        eventsLoading: true,
      );

      _lastAuthoritativeLoadGeneration = generation;
      _lastAuthoritativeUid = uid;

      final eventsGeneration = ++_eventsGeneration;
      _eventsSubscription = _transactionRepository
          .watchEvents(uid)
          .listen(
            (feed) {
              if (mounted &&
                  _ownerUid == uid &&
                  _eventsGeneration == eventsGeneration &&
                  _loadGeneration == generation) {
                state = state.copyWith(
                  events: feed.validEvents,
                  corruptEvents: feed.corruptEvents,
                  eventsLoading: false,
                  clearEventsError: true,
                );
              }
            },
            onError: (Object error) {
              if (mounted &&
                  _ownerUid == uid &&
                  _eventsGeneration == eventsGeneration &&
                  _loadGeneration == generation) {
                state = state.copyWith(
                  eventsLoading: false,
                  eventsError: 'Failed to load history. Please try again.',
                );
              }
            },
          );

      final bundle = results[2] is OnboardingCompletionBundle
          ? results[2] as OnboardingCompletionBundle
          : null;
      _scheduleBaseTimelineFoundationRepair(
        uid: uid,
        generation: generation,
        currentRemoteItems: remoteItems,
        bundle: bundle,
      );
      if (bundle != null) {
        _scheduleProjectionIntegritySelfHeal(
          uid: uid,
          bundle: bundle,
          generation: generation,
          currentRemoteItems: remoteItems,
        );
      }
    } catch (e) {
      if (generation != _loadGeneration || _ownerUid != uid) return;
      state = state.copyWith(
        loading: false,
        error: 'Failed to load routine data. Please try again.',
      );
      rethrow;
    }
  }

  void refreshEvents() {
    final uid = _ownerUid;
    if (uid == null) return;

    _eventsSubscription?.cancel();
    state = state.copyWith(eventsLoading: true, clearEventsError: true);

    final eventsGeneration = ++_eventsGeneration;
    _eventsSubscription = _transactionRepository
        .watchEvents(uid)
        .listen(
          (feed) {
            if (mounted &&
                _ownerUid == uid &&
                _eventsGeneration == eventsGeneration) {
              state = state.copyWith(
                events: feed.validEvents,
                corruptEvents: feed.corruptEvents,
                eventsLoading: false,
                clearEventsError: true,
              );
            }
          },
          onError: (Object error) {
            if (mounted &&
                _ownerUid == uid &&
                _eventsGeneration == eventsGeneration) {
              state = state.copyWith(
                eventsLoading: false,
                eventsError: 'Failed to load history. Please try again.',
              );
            }
          },
        );
  }

  void _scheduleProjectionIntegritySelfHeal({
    required String uid,
    required OnboardingCompletionBundle bundle,
    required int generation,
    required List<RoutineItem> currentRemoteItems,
  }) {
    if (_ownerUid != uid || generation != _loadGeneration) return;

    final repairFuture = _runProjectionIntegritySelfHeal(
      uid: uid,
      bundle: bundle,
      generation: generation,
      currentRemoteItems: currentRemoteItems,
    );
    _inFlightProjectionRepair = repairFuture;
  }

  Future<bool> _runProjectionIntegritySelfHeal({
    required String uid,
    required OnboardingCompletionBundle bundle,
    required int generation,
    required List<RoutineItem> currentRemoteItems,
  }) async {
    try {
      final plan = RoutineOnboardingProjection.build(bundle);
      final receipt = await _repository.fetchProjectionReceipt(
        uid,
        plan.projectionId,
      );
      final setup = await _ref
          .read(baseTimelineSetupRepositoryProvider)
          .fetchSetup(uid);
      final source = await _fetchBaseTimelineOnboardingSource(
        uid: uid,
        bundle: bundle,
        plan: plan,
      );
      if (!mounted || generation != _loadGeneration || _ownerUid != uid) {
        return false;
      }
      final ambiguousSections = <BaseTimelineSection>{};
      final liveSetup = _setupWithStrongEvidenceAuthorities(
        setup: setup,
        onboardingSource: source,
        liveItems: currentRemoteItems,
        ambiguousSections: ambiguousSections,
      );

      final historicalValidation = const RoutineProjectionReceiptValidator()
          .validate(
            receipt: receipt,
            actualItems: currentRemoteItems,
            ownerUid: uid,
            plan: plan,
          );
      final liveExpectedItems = plan.items
          .where(
            (item) =>
                _isLiveOnboardingExpectation(item: item, setup: liveSetup) &&
                !ambiguousSections.contains(_foundationSectionForItem(item)),
          )
          .toList(growable: false);

      final signature = Object.hash(
        uid,
        plan.fingerprint,
        receipt?.sourceBundleFingerprint,
        Object.hashAll(
          BaseTimelineSection.values.map(
            (section) =>
                Object.hash(section.name, liveSetup.authorityFor(section).name),
          ),
        ),
        Object.hashAll(ambiguousSections.map((section) => section.name)),
        Object.hashAll(
          currentRemoteItems.map(
            (item) =>
                Object.hash(item.id, item.onboardingVisualStyleKey, item.notes),
          ),
        ),
      ).toString();

      if (kDebugMode) {
        final persistedOnboarding = currentRemoteItems
            .where((item) => item.source == RoutineSource.onboarding)
            .toList();
        final persistedIds = currentRemoteItems.map((i) => i.id).toSet();
        final missingIds = liveExpectedItems
            .where((expected) => !persistedIds.contains(expected.id))
            .map((i) => i.id)
            .toList();
        final sampleMissing = missingIds.take(3).join(',');
        final supersededCount = plan.items.length - liveExpectedItems.length;
        debugPrint(
          'RoutineProjectionIntegrity: expectedCount=${liveExpectedItems.length} '
          'supersededFoundationCount=$supersededCount '
          'persistedOnboardingCount=${persistedOnboarding.length} '
          'missingCount=${missingIds.length} historicalValid=${historicalValidation.isValid} '
          'projectionId=${plan.projectionId} '
          'fingerprintPrefix=${plan.fingerprint.substring(0, 8)}'
          '${missingIds.isNotEmpty ? ' sampleMissing=[$sampleMissing]' : ''}',
        );
      }

      final persistedIds = currentRemoteItems.map((item) => item.id).toSet();
      final missingLiveItems = liveExpectedItems
          .where((expected) => !persistedIds.contains(expected.id))
          .map(_liveRepairItem)
          .toList(growable: false);
      final hasSupersededFoundation =
          liveExpectedItems.length != plan.items.length;

      if (historicalValidation.isValid || missingLiveItems.isEmpty) {
        _lastSuccessfulProjectionIntegritySignature = signature;
        _projectionIntegrityRetryCount.remove(signature);
        _projectionIntegrityNextRetryAt.remove(signature);
        return false;
      }

      if (_lastSuccessfulProjectionIntegritySignature == signature) {
        return false;
      }

      if (_inFlightProjectionIntegritySignature != null) {
        return false;
      }

      final nextRetryAt = _projectionIntegrityNextRetryAt[signature];
      if (nextRetryAt != null && DateTime.now().isBefore(nextRetryAt)) {
        return false;
      }

      _inFlightProjectionIntegritySignature = signature;

      try {
        final repaired = hasSupersededFoundation
            ? (await _repository.createRoutineItemsIfMissing(
                uid,
                missingLiveItems,
              )).isNotEmpty
            : await _repository.reconcileOnboardingProjection(uid, plan);
        if (!mounted || generation != _loadGeneration || _ownerUid != uid) {
          return false;
        }

        if (repaired) {
          final refreshedItems = await _repository.fetchRoutineItems(uid);
          if (!mounted || generation != _loadGeneration || _ownerUid != uid) {
            return false;
          }

          final normalized = refreshedItems
              .map(
                (remote) => remote.hasConflict || remote.conflictMessage != null
                    ? remote.copyWith(hasConflict: false, clearConflict: true)
                    : remote,
              )
              .toList();

          final updatedReceipt = await _repository.fetchProjectionReceipt(
            uid,
            plan.projectionId,
          );
          final validAfterRepair = hasSupersededFoundation
              ? (() {
                  final normalizedIds = normalized
                      .map((item) => item.id)
                      .toSet();
                  final liveValid = liveExpectedItems.every(
                    (expected) => normalizedIds.contains(expected.id),
                  );
                  final receiptStillHistorical =
                      updatedReceipt?.sourceBundleFingerprint ==
                      receipt?.sourceBundleFingerprint;
                  return liveValid && receiptStillHistorical;
                })()
              : const RoutineProjectionReceiptValidator()
                    .validate(
                      receipt: updatedReceipt,
                      actualItems: normalized,
                      ownerUid: uid,
                      plan: plan,
                    )
                    .isValid;

          if (validAfterRepair) {
            _lastSuccessfulProjectionIntegritySignature = signature;
            _projectionIntegrityRetryCount.remove(signature);
            _projectionIntegrityNextRetryAt.remove(signature);
          } else {
            final retries =
                (_projectionIntegrityRetryCount[signature] ?? 0) + 1;
            _projectionIntegrityRetryCount[signature] = retries;
            final backoffSeconds = retries == 1 ? 5 : (retries == 2 ? 15 : 30);
            _projectionIntegrityNextRetryAt[signature] = DateTime.now().add(
              Duration(seconds: backoffSeconds),
            );
          }

          if (mounted && _ownerUid == uid) {
            _mergeRefreshedItems(normalized);
          }
          return true;
        } else {
          if (missingLiveItems.isEmpty) {
            _lastSuccessfulProjectionIntegritySignature = signature;
            _projectionIntegrityRetryCount.remove(signature);
            _projectionIntegrityNextRetryAt.remove(signature);
          } else {
            final retries =
                (_projectionIntegrityRetryCount[signature] ?? 0) + 1;
            _projectionIntegrityRetryCount[signature] = retries;
            final backoffSeconds = retries == 1 ? 5 : (retries == 2 ? 15 : 30);
            _projectionIntegrityNextRetryAt[signature] = DateTime.now().add(
              Duration(seconds: backoffSeconds),
            );
          }
          return false;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'RoutineProjectionIntegrity: repair failed (safe degraded state): $e',
          );
        }
        final retries = (_projectionIntegrityRetryCount[signature] ?? 0) + 1;
        _projectionIntegrityRetryCount[signature] = retries;
        final backoffSeconds = retries == 1 ? 5 : (retries == 2 ? 15 : 30);
        _projectionIntegrityNextRetryAt[signature] = DateTime.now().add(
          Duration(seconds: backoffSeconds),
        );
        return false;
      } finally {
        if (_inFlightProjectionIntegritySignature == signature) {
          _inFlightProjectionIntegritySignature = null;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'RoutineProjectionIntegrity: inspection failed (safe degraded state): $e',
        );
      }
      return false;
    }
  }

  void _mergeRefreshedItems(List<RoutineItem> refreshedItems) {
    final localActiveIds = state.pendingItemIds.union(
      state.failedIntentsByItemId.keys.toSet(),
    );
    final mergedItems = <RoutineItem>[];
    for (final remote in refreshedItems) {
      if (!localActiveIds.contains(remote.id)) {
        mergedItems.add(remote);
      }
    }
    for (final id in localActiveIds) {
      final localItem = state.items.where((e) => e.id == id).firstOrNull;
      if (localItem != null) {
        mergedItems.add(localItem);
      }
    }
    state = state.copyWith(items: mergedItems);
  }

  void resetForSignedOut() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _loadGeneration++;
    _eventsGeneration++;
    _ownerUid = null;
    _inFlightLoad = null;
    _inFlightUid = null;
    _inFlightGeneration = null;
    _lastAuthoritativeUid = null;
    _inFlightProjectionIntegritySignature = null;
    _lastSuccessfulProjectionIntegritySignature = null;
    _projectionIntegrityRetryCount.clear();
    _projectionIntegrityNextRetryAt.clear();
    _inFlightProjectionRepair = null;
    _inFlightBaseTimelineFoundationRepair = null;
    _inFlightBaseTimelineFoundationRepairSignature = null;
    _ref.read(trackerSessionLinksProvider.notifier).reset();
    state = RoutineState(
      items: const [],
      selectedDay: TimelineUtils.dateOnly(DateTime.now()),
      pendingItemIds: const {},
      pendingOccurrenceIds: const {},
      failedIntentsByItemId: const {},
      failedOccurrenceIntentsById: const {},
      queuedOccurrenceActionsById: const {},
      failedBatchIntentsByOperationId: const {},
    );
  }

  String _requireOwnerUid() {
    final uid = _ownerUid;
    if (uid == null || uid.trim().isEmpty) {
      throw StateError('Routine owner is not loaded.');
    }
    return uid;
  }

  void updateSelectedDay(DateTime day) {
    final normalized = TimelineUtils.dateOnly(day);
    if (state.selectedDay == normalized) return;
    final entries = RoutineOccurrenceProjector.entriesForDay(
      state.items,
      state.occurrences,
      normalized,
    );
    final normalizedSelection = state.filterSelection.normalizedFor(entries);
    state = state.copyWith(
      selectedDay: normalized,
      selectedCategoryFilter: normalizedSelection.category,
    );
  }

  void toggleFullDay(bool value) => state = state.copyWith(showFullDay: value);
  void toggleCompactMode(bool value) =>
      state = state.copyWith(compactMode: value);
  void toggleMinuteTicks(bool value) =>
      state = state.copyWith(showMinuteTicks: value);
  void toggleCurrentTimeLine(bool value) =>
      state = state.copyWith(showCurrentTimeLine: value);
  void togglePrecisionMode(bool value) =>
      state = state.copyWith(precisionMode: value);
  void setPrimaryFilter(String filter) {
    final supported = primaryFilters.any((entry) => entry.key == filter);
    state = state.copyWith(selectedPrimaryFilter: supported ? filter : 'all');
  }

  void setStatusFilter(String filter) {
    final supported = statusFilters.any((entry) => entry.key == filter);
    state = state.copyWith(selectedStatusFilter: supported ? filter : 'any');
  }

  void setCategoryFilter(String filter) {
    final supported =
        filter == 'all' || categoryFilters.any((entry) => entry.key == filter);
    state = state.copyWith(selectedCategoryFilter: supported ? filter : 'all');
  }

  void resetFilters() {
    state = state.copyWith(
      selectedPrimaryFilter: 'all',
      selectedStatusFilter: 'any',
      selectedCategoryFilter: 'all',
    );
  }

  void toggleAiSuggestions(bool value) =>
      state = state.copyWith(aiRoutineSuggestionsEnabled: value);
  void toggleNotifications(bool value) =>
      state = state.copyWith(routineNotificationsEnabled: value);

  RoutineValidationResult _validate(
    RoutineItem item,
    DateTime date, {
    RoutineValidationOperation operation = RoutineValidationOperation.update,
  }) {
    return RoutineValidationService.validate(
      RoutineValidationContext(
        candidate: item,
        existingTemplates: state.items,
        occurrences: state.occurrences,
        evaluationDate: date,
        explicitNow: DateTime.now(),
        operation: operation,
        authenticatedOwnerUid: _ownerUid ?? '',
      ),
    );
  }

  Future<RoutineWriteResult> addItem(RoutineItem item) async {
    if (_ownerUid == null || _inFlightLoad != null) {
      await (_inFlightLoad ?? _initialLoad);
    }
    final uid = _requireOwnerUid();
    final validation = _validate(
      item,
      item.date ?? state.selectedDay,
      operation: RoutineValidationOperation.create,
    );
    if (!validation.isValid) {
      return RoutineWriteResult.validationFailed(validation);
    }

    final operationId = _stableOperationId('create', [
      uid,
      item.id,
      _itemMutationFingerprint(item),
    ]);
    final ownedItem = item.copyWith(
      userId: uid,
      createdByOperationId: operationId,
      lastMutationOperationId: operationId,
    );

    final event = RoutineEventRecord(
      eventId: _stableEventId(
        operationId: operationId,
        itemId: ownedItem.id,
        eventType: RoutineEventType.created,
      ),
      ownerUid: uid,
      routineItemId: ownedItem.id,
      eventType: RoutineEventType.created,
      operationKey: operationId,
      source: 'app',
      occurredAt: DateTime.now().toUtc(),
      itemSnapshot: _boundedHistorySnapshot(ownedItem, uid),
    );

    return await _commitCreateWithRecovery(
      uid: uid,
      ownedItem: ownedItem,
      operationId: operationId,
      event: event,
    );
  }

  Future<RoutineWriteResult> _commitCreateWithRecovery({
    required String uid,
    required RoutineItem ownedItem,
    required String operationId,
    required RoutineEventRecord event,
    RoutineWriteIntent? existingIntent,
  }) async {
    final existingIndex = state.items.indexWhere((e) => e.id == ownedItem.id);
    final updatedItems = existingIndex >= 0
        ? [
            for (int i = 0; i < state.items.length; i++)
              if (i == existingIndex) ownedItem else state.items[i],
          ]
        : [...state.items, ownedItem];

    state = state.copyWith(
      pendingItemIds: {...state.pendingItemIds, ownedItem.id},
      items: updatedItems,
      error: null,
    );

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setItem: ownedItem,
        addEvent: event,
      );
      final canonical = ownedItem;
      if (_ownerUid != uid) return _supersededWriteResult(operationId);

      final remainingFailedIntents = Map<String, RoutineWriteIntent>.from(
        state.failedIntentsByItemId,
      )..remove(ownedItem.id);

      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => id != ownedItem.id)
            .toSet(),
        failedIntentsByItemId: remainingFailedIntents,
        items: state.items
            .map((e) => e.id == ownedItem.id ? canonical : e)
            .toList(),
      );
      return RoutineWriteResult.saved(operationId: operationId);
    } catch (error) {
      if (_ownerUid != uid) return _supersededWriteResult(operationId);

      bool isSuccess = false;
      RoutineItem? recoveredItem;
      try {
        final items = await _repository.fetchRoutineItems(uid);
        for (final i in items) {
          if (i.id == ownedItem.id && i.createdByOperationId == operationId) {
            isSuccess = true;
            recoveredItem = i;
            break;
          }
        }
      } catch (_) {}

      if (isSuccess && recoveredItem != null) {
        final remainingFailedIntents = Map<String, RoutineWriteIntent>.from(
          state.failedIntentsByItemId,
        )..remove(ownedItem.id);

        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != ownedItem.id)
              .toSet(),
          failedIntentsByItemId: remainingFailedIntents,
          items: state.items
              .map((e) => e.id == ownedItem.id ? recoveredItem! : e)
              .toList(),
        );
        return RoutineWriteResult.saved(operationId: operationId);
      } else {
        final intent =
            existingIntent ??
            RoutineWriteIntent(
              action: RoutineWriteAction.create,
              ownerUid: uid,
              itemId: ownedItem.id,
              operationId: operationId,
              attemptedItem: ownedItem,
              createdAt: DateTime.now().toUtc(),
              event: event,
            );
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != ownedItem.id)
              .toSet(),
          failedIntentsByItemId: {
            ...state.failedIntentsByItemId,
            ownedItem.id: intent,
          },
          error: 'Failed to save routine item.',
        );
      }
      return RoutineWriteResult.retryRequired(
        message: 'Failed to save routine item.',
        operationId: operationId,
      );
    }
  }

  Future<RoutineBatchValidationResult> addMissingItems(
    List<RoutineItem> items,
  ) async {
    if (_ownerUid == null || _inFlightLoad != null) {
      await (_inFlightLoad ?? _initialLoad);
    }
    final existingIds = state.items.map((item) => item.id).toSet();
    final toAdd = items
        .where(
          (item) => item.id.trim().isNotEmpty && !existingIds.contains(item.id),
        )
        .toList();
    if (toAdd.isEmpty) return const RoutineBatchValidationResult.valid();

    final uid = _requireOwnerUid();
    final validation = RoutineValidationService.validateBatch(
      itemsToAdd: toAdd,
      existingTemplates: state.items,
      occurrences: state.occurrences,
      evaluationDate: state.selectedDay,
      explicitNow: DateTime.now(),
      authenticatedOwnerUid: uid,
    );
    if (!validation.isValid) {
      return validation;
    }

    final batchIdentity = toAdd.map(_itemMutationFingerprint).toList()..sort();
    final operationId = _stableOperationId('batch_add', [
      uid,
      ...batchIdentity,
    ]);
    final ownedItems = <RoutineItem>[];
    final events = <RoutineEventRecord>[];
    for (final item in toAdd) {
      final owned = item.copyWith(
        userId: uid,
        createdByOperationId: operationId,
        lastMutationOperationId: operationId,
      );
      ownedItems.add(owned);
      events.add(
        RoutineEventRecord(
          eventId: _stableEventId(
            operationId: operationId,
            itemId: owned.id,
            eventType: RoutineEventType.created,
          ),
          ownerUid: uid,
          routineItemId: owned.id,
          eventType: RoutineEventType.created,
          operationKey: operationId,
          source: 'app',
          occurredAt: DateTime.now().toUtc(),
          itemSnapshot: _boundedHistorySnapshot(owned, uid),
        ),
      );
    }

    final addedIds = ownedItems.map((e) => e.id).toSet();

    // Optimistic update — add all at once.
    state = state.copyWith(
      pendingItemIds: {...state.pendingItemIds, ...addedIds},
      items: [...state.items, ...ownedItems],
    );

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setItems: ownedItems,
        addEvents: events,
      );
      if (_ownerUid != uid) {
        return RoutineBatchValidationResult.superseded(
          operationId: operationId,
          message: 'Routine owner changed before the batch write completed.',
        );
      }

      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => !addedIds.contains(id))
            .toSet(),
      );
      return RoutineBatchValidationResult.valid(operationId: operationId);
    } catch (error) {
      if (_ownerUid != uid) {
        return RoutineBatchValidationResult.superseded(
          operationId: operationId,
          message: 'Routine owner changed before the batch write completed.',
        );
      }

      final intent = RoutineBatchWriteIntent(
        ownerUid: uid,
        operationId: operationId,
        action: RoutineWriteAction.batchCreate,
        attemptedItems: ownedItems,
        events: events,
        createdAt: DateTime.now().toUtc(),
      );

      // Roll back all added items on failure.
      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => !addedIds.contains(id))
            .toSet(),
        items: state.items.where((e) => !addedIds.contains(e.id)).toList(),
        error: 'Failed to add routine items.',
        failedBatchIntentsByOperationId: {
          ...state.failedBatchIntentsByOperationId,
          operationId: intent,
        },
      );
      return RoutineBatchValidationResult.retryRequired(
        message: 'Failed to add routine items.',
        operationId: operationId,
      );
    }
  }

  Future<RoutineWriteResult> updateItem(RoutineItem item) async {
    final uid = _requireOwnerUid();
    final validation = _validate(item, item.date ?? state.selectedDay);
    if (!validation.isValid) {
      return RoutineWriteResult.validationFailed(validation);
    }

    final operationId = _stableOperationId('update', [
      uid,
      item.id,
      _itemMutationFingerprint(item),
    ]);
    final previousItem = state.items.cast<RoutineItem?>().firstWhere(
      (e) => e?.id == item.id,
      orElse: () => null,
    );
    if (previousItem == null) {
      return RoutineWriteResult.validationFailed(
        const RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.missingData,
          userSafeMessage: 'Item not found.',
        ),
      );
    }

    final ownedItem = item.copyWith(
      userId: uid,
      lastMutationOperationId: operationId,
    );

    state = state.copyWith(
      pendingItemIds: {...state.pendingItemIds, ownedItem.id},
      items: state.items.map((e) => e.id == item.id ? ownedItem : e).toList(),
    );

    final event = RoutineEventRecord(
      eventId: _stableEventId(
        operationId: operationId,
        itemId: ownedItem.id,
        eventType: RoutineEventType.edited,
      ),
      ownerUid: uid,
      routineItemId: ownedItem.id,
      eventType: RoutineEventType.edited,
      operationKey: operationId,
      source: 'app',
      occurredAt: DateTime.now().toUtc(),
      itemSnapshot: _boundedHistorySnapshot(ownedItem, uid),
    );

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setItem: ownedItem,
        addEvent: event,
      );
      final canonical = ownedItem;
      if (_ownerUid != uid) return _supersededWriteResult(operationId);

      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => id != ownedItem.id)
            .toSet(),
        items: state.items
            .map((e) => e.id == ownedItem.id ? canonical : e)
            .toList(),
      );
      return RoutineWriteResult.saved(operationId: operationId);
    } catch (error) {
      if (_ownerUid != uid) return _supersededWriteResult(operationId);

      final intent = RoutineWriteIntent(
        action: RoutineWriteAction.update,
        ownerUid: uid,
        itemId: ownedItem.id,
        operationId: operationId,
        attemptedItem: ownedItem,
        previousItem: previousItem,
        createdAt: DateTime.now().toUtc(),
        event: event,
      );

      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => id != ownedItem.id)
            .toSet(),
        items: state.items
            .map((e) => e.id == ownedItem.id ? previousItem : e)
            .toList(),
        failedIntentsByItemId: {
          ...state.failedIntentsByItemId,
          ownedItem.id: intent,
        },
        error: 'Failed to update routine item.',
      );
      return RoutineWriteResult.retryRequired(
        message: 'Failed to update routine item.',
        operationId: operationId,
      );
    }
  }

  Future<RoutineWriteResult> deleteItem(String itemId) async {
    final uid = _requireOwnerUid();
    final previousItem = state.items.cast<RoutineItem?>().firstWhere(
      (e) => e?.id == itemId,
      orElse: () => null,
    );
    if (previousItem == null) return const RoutineWriteResult.noOp();
    final operationId = _stableOperationId('delete', [
      uid,
      itemId,
      previousItem.lastMutationOperationId ?? previousItem.createdByOperationId,
      _itemMutationFingerprint(previousItem),
    ]);

    state = state.copyWith(pendingItemIds: {...state.pendingItemIds, itemId});

    final event = RoutineEventRecord(
      eventId: _stableEventId(
        operationId: operationId,
        itemId: itemId,
        eventType: RoutineEventType.deleted,
      ),
      ownerUid: uid,
      routineItemId: itemId,
      eventType: RoutineEventType.deleted,
      operationKey: operationId,
      source: 'app',
      occurredAt: DateTime.now().toUtc(),
      itemSnapshot: _boundedHistorySnapshot(previousItem, uid),
    );

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        deleteItemId: itemId,
        addEvent: event,
      );
      if (_ownerUid != uid) return _supersededWriteResult(operationId);

      _ref.read(trackerSessionLinksProvider.notifier).clearForRoutine(itemId);
      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => id != itemId)
            .toSet(),
        items: state.items.where((e) => e.id != itemId).toList(),
      );
      return RoutineWriteResult.saved(operationId: operationId);
    } catch (error) {
      if (_ownerUid != uid) return _supersededWriteResult(operationId);

      bool isSuccess = false;
      try {
        final items = await _repository.fetchRoutineItems(uid);
        if (!items.any((i) => i.id == itemId)) {
          isSuccess = true;
        }
      } catch (_) {}

      if (isSuccess) {
        _ref.read(trackerSessionLinksProvider.notifier).clearForRoutine(itemId);
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != itemId)
              .toSet(),
          items: state.items.where((e) => e.id != itemId).toList(),
        );
        return RoutineWriteResult.saved(operationId: operationId);
      } else {
        final intent = RoutineWriteIntent(
          action: RoutineWriteAction.delete,
          ownerUid: uid,
          itemId: itemId,
          operationId: operationId,
          previousItem: previousItem,
          createdAt: DateTime.now().toUtc(),
          event: event,
        );
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != itemId)
              .toSet(),
          failedIntentsByItemId: {
            ...state.failedIntentsByItemId,
            itemId: intent,
          },
          error: 'Failed to delete routine item.',
        );
      }
      return RoutineWriteResult.retryRequired(
        message: 'Failed to delete item.',
        operationId: operationId,
      );
    }
  }

  Future<RoutineWriteResult> retryFailedOperation(String itemId) async {
    final intent = state.failedIntentsByItemId[itemId];
    if (intent == null) {
      return const RoutineWriteResult.noOp(message: 'No failed operation.');
    }

    final uid = _ownerUid;
    if (uid == null || uid != intent.ownerUid) {
      return RoutineWriteResult.superseded(
        operationId: intent.operationId,
        message: 'Routine owner changed before retry.',
      );
    }

    if (intent.action == RoutineWriteAction.create &&
        intent.attemptedItem != null) {
      final event =
          intent.event ??
          RoutineEventRecord(
            eventId: _stableEventId(
              operationId: intent.operationId,
              itemId: intent.attemptedItem!.id,
              eventType: RoutineEventType.created,
            ),
            ownerUid: uid,
            routineItemId: intent.attemptedItem!.id,
            eventType: RoutineEventType.created,
            operationKey: intent.operationId,
            source: 'app',
            occurredAt: DateTime.now().toUtc(),
            itemSnapshot: _boundedHistorySnapshot(intent.attemptedItem!, uid),
          );
      return await _commitCreateWithRecovery(
        uid: uid,
        ownedItem: intent.attemptedItem!,
        operationId: intent.operationId,
        event: event,
        existingIntent: intent,
      );
    } else if (intent.action == RoutineWriteAction.update &&
        intent.attemptedItem != null) {
      state = state.copyWith(
        pendingItemIds: {...state.pendingItemIds, itemId},
        items: state.items
            .map((e) => e.id == itemId ? intent.attemptedItem! : e)
            .toList(),
      );
      try {
        await _transactionRepository.commitWrite(
          uid: uid,
          setItem: intent.attemptedItem!,
          addEvent: intent.event,
        );
        final canonical = intent.attemptedItem!;
        if (_ownerUid != uid) return _supersededWriteResult(intent.operationId);
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != itemId)
              .toSet(),
          failedIntentsByItemId: {...state.failedIntentsByItemId}
            ..remove(itemId),
          items: state.items
              .map((e) => e.id == itemId ? canonical : e)
              .toList(),
        );
        return RoutineWriteResult.saved(operationId: intent.operationId);
      } catch (error) {
        if (_ownerUid != uid) return _supersededWriteResult(intent.operationId);
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != itemId)
              .toSet(),
          items: state.items
              .map(
                (e) => e.id == itemId && intent.previousItem != null
                    ? intent.previousItem!
                    : e,
              )
              .toList(),
          failedIntentsByItemId: {
            ...state.failedIntentsByItemId,
            itemId: intent,
          },
          error: 'Failed to update routine item.',
        );
        return RoutineWriteResult.retryRequired(
          operationId: intent.operationId,
          message: 'Failed to update routine item.',
        );
      }
    } else if (intent.action == RoutineWriteAction.delete) {
      state = state.copyWith(pendingItemIds: {...state.pendingItemIds, itemId});
      try {
        await _transactionRepository.commitWrite(
          uid: uid,
          deleteItemId: itemId,
          addEvent: intent.event,
        );
        if (_ownerUid != uid) return _supersededWriteResult(intent.operationId);
        _ref.read(trackerSessionLinksProvider.notifier).clearForRoutine(itemId);
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != itemId)
              .toSet(),
          failedIntentsByItemId: {...state.failedIntentsByItemId}
            ..remove(itemId),
          items: state.items.where((e) => e.id != itemId).toList(),
        );
        return RoutineWriteResult.saved(operationId: intent.operationId);
      } catch (error) {
        if (_ownerUid != uid) return _supersededWriteResult(intent.operationId);
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != itemId)
              .toSet(),
          failedIntentsByItemId: {
            ...state.failedIntentsByItemId,
            itemId: intent,
          },
          error: 'Failed to delete routine item.',
        );
        return RoutineWriteResult.retryRequired(
          operationId: intent.operationId,
          message: 'Failed to delete routine item.',
        );
      }
    }
    return RoutineWriteResult.noOp(
      operationId: intent.operationId,
      message: 'Failed operation could not be replayed.',
    );
  }

  Future<RoutineDiscardResult> discardFailedCreate(String itemId) async {
    final intent = state.failedIntentsByItemId[itemId];
    if (intent == null || intent.action != RoutineWriteAction.create) {
      return const RoutineDiscardResult(wasSaved: false, discarded: false);
    }

    final uid = _ownerUid;
    if (uid == null || uid != intent.ownerUid) {
      return const RoutineDiscardResult(wasSaved: false, discarded: false);
    }

    // Reconcile with authoritative repository before destructive discard
    bool isCommittedRemotely = false;
    RoutineItem? remoteItem;
    try {
      final items = await _repository.fetchRoutineItems(uid);
      for (final i in items) {
        if (i.id == itemId && i.createdByOperationId == intent.operationId) {
          isCommittedRemotely = true;
          remoteItem = i;
          break;
        }
      }
    } catch (_) {
      return const RoutineDiscardResult.verificationUnavailable();
    }

    if (isCommittedRemotely && remoteItem != null) {
      // The item committed remotely! Do NOT delete locally.
      state = state.copyWith(
        items: state.items
            .map((e) => e.id == itemId ? remoteItem! : e)
            .toList(),
        failedIntentsByItemId: Map.fromEntries(
          state.failedIntentsByItemId.entries.where((e) => e.key != itemId),
        ),
        error: null,
      );
      return const RoutineDiscardResult(wasSaved: true, discarded: false);
    }

    // Truly not committed remotely: safe to discard locally
    state = state.copyWith(
      items: state.items.where((e) => e.id != itemId).toList(),
      failedIntentsByItemId: Map.fromEntries(
        state.failedIntentsByItemId.entries.where((e) => e.key != itemId),
      ),
      error: null,
    );
    return const RoutineDiscardResult(wasSaved: false, discarded: true);
  }

  void dismissFailedOperation(String itemId) {
    state = state.copyWith(
      failedIntentsByItemId: Map.fromEntries(
        state.failedIntentsByItemId.entries.where((e) => e.key != itemId),
      ),
      error: null,
    );
  }

  void dismissFailedOccurrenceAction(String occurrenceId) {
    state = state.copyWith(
      failedOccurrenceIntentsById: Map.fromEntries(
        state.failedOccurrenceIntentsById.entries.where(
          (e) => e.key != occurrenceId,
        ),
      ),
      error: null,
    );
  }

  Future<RoutineWriteResult> retryFailedBatchOperation(
    String operationId,
  ) async {
    final intent = state.failedBatchIntentsByOperationId[operationId];
    if (intent == null) {
      return const RoutineWriteResult.noOp(
        message: 'No failed batch operation.',
      );
    }

    final uid = _requireOwnerUid();
    if (uid != intent.ownerUid) {
      return _supersededWriteResult(operationId);
    }

    final addedIds = intent.attemptedItems.map((e) => e.id).toSet();

    // Keep the original failed intent visible until durable retry success.
    state = state.copyWith(
      pendingItemIds: {...state.pendingItemIds, ...addedIds},
      items: _replaceItemsPreservingOrder(state.items, intent.attemptedItems),
    );

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setItems: intent.attemptedItems,
        addEvents: intent.events,
      );

      if (_ownerUid != uid) return _supersededWriteResult(operationId);

      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => !addedIds.contains(id))
            .toSet(),
        failedBatchIntentsByOperationId: {
          ...state.failedBatchIntentsByOperationId,
        }..remove(operationId),
      );
      return RoutineWriteResult.saved(operationId: operationId);
    } catch (error) {
      if (_ownerUid != uid) return _supersededWriteResult(operationId);

      // Retrying must reuse the original intent rather than generating new identities
      final rollbackItems = intent.previousItems.isEmpty
          ? state.items.where((e) => !addedIds.contains(e.id)).toList()
          : _replaceItemsPreservingOrder(state.items, intent.previousItems);
      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => !addedIds.contains(id))
            .toSet(),
        failedBatchIntentsByOperationId: {
          ...state.failedBatchIntentsByOperationId,
          operationId: intent,
        },
        items: rollbackItems,
        error: 'Failed to add batch items.',
      );
      return RoutineWriteResult.retryRequired(
        operationId: operationId,
        message: 'Failed to add batch items.',
      );
    }
  }

  void discardFailedBatchOperation(String operationId) {
    final intent = state.failedBatchIntentsByOperationId[operationId];
    if (intent == null) return;

    final uid = _ownerUid;
    if (uid == null || uid != intent.ownerUid) return;

    state = state.copyWith(
      failedBatchIntentsByOperationId: {
        ...state.failedBatchIntentsByOperationId,
      }..remove(operationId),
    );
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  Future<RoutineWriteResult> _updateById(
    String itemId,
    RoutineItem Function(RoutineItem) update,
  ) async {
    for (final item in state.items) {
      if (item.id == itemId) {
        return await updateItem(update(item));
      }
    }
    return const RoutineWriteResult.noOp(message: 'Item not found.');
  }

  RoutineItem? _itemFor(String id) =>
      state.items.where((e) => e.id == id).firstOrNull;

  RoutineOccurrenceRecord? _occurrenceFor(String itemId, DateTime date) {
    final dateKey = routineLocalDateKey(date);
    for (final occurrence in state.occurrences) {
      if (occurrence.routineItemId == itemId &&
          occurrence.occurrenceDateKey == dateKey) {
        return occurrence;
      }
    }
    return null;
  }

  String _routineActionErrorCategory(Object error) {
    if (error is FirebaseException) return 'firestore_${error.code}';
    if (error is FormatException || error is ArgumentError) {
      return 'codec_validation';
    }
    if (error is StateError) return 'local_validation';
    return 'unknown';
  }

  void _logRoutineActionWrite({
    required String action,
    required String occurrenceSource,
    required String actionSource,
    required bool existing,
    required String result,
    Object? error,
  }) {
    if (!kDebugMode) return;
    final category = error == null ? null : _routineActionErrorCategory(error);
    debugPrint(
      '[RoutineActionWrite] '
      'action=$action '
      'occurrenceSource=$occurrenceSource '
      'actionSource=$actionSource '
      'existing=$existing '
      'result=$result'
      '${category == null ? '' : ' category=$category'}',
    );
  }

  RoutineOccurrenceWriteIntent _normalizeOccurrenceIntentForRetry(
    RoutineOccurrenceWriteIntent intent,
  ) {
    final previous = intent.previousRecord;
    if (previous == null) return intent;
    final attempted = intent.attemptedRecord;
    final normalized = RoutineOccurrenceRecord(
      id: attempted.id,
      ownerUid: attempted.ownerUid,
      routineItemId: attempted.routineItemId,
      occurrenceDateKey: attempted.occurrenceDateKey,
      status: attempted.status,
      source: previous.source,
      action: attempted.action,
      operationKey: attempted.operationKey,
      createdAt: previous.createdAt,
      updatedAt: attempted.updatedAt,
      schemaVersion: attempted.schemaVersion,
      movedToDateKey: attempted.movedToDateKey,
      movedStartMinute: attempted.movedStartMinute,
      movedEndMinute: attempted.movedEndMinute,
      completedSubtaskIndexes: attempted.completedSubtaskIndexes,
      note: attempted.note,
      displayTitleOverride: attempted.displayTitleOverride,
      undoToPlannedAllowed: attempted.undoToPlannedAllowed,
      onboardingProjectionId: previous.onboardingProjectionId,
      onboardingSourceItemId: previous.onboardingSourceItemId,
      sourceFingerprint: previous.sourceFingerprint,
      startedAt: attempted.startedAt,
      countdownDurationSeconds: attempted.countdownDurationSeconds,
      previousStatus: attempted.previousStatus,
      previousAction: attempted.previousAction,
      trackerSessionId: attempted.trackerSessionId,
      trackerType: attempted.trackerType,
    );
    if (normalized.source == attempted.source &&
        normalized.createdAt == attempted.createdAt &&
        normalized.onboardingProjectionId == attempted.onboardingProjectionId &&
        normalized.onboardingSourceItemId == attempted.onboardingSourceItemId &&
        normalized.sourceFingerprint == attempted.sourceFingerprint &&
        normalized.previousStatus == attempted.previousStatus &&
        normalized.previousAction == attempted.previousAction &&
        normalized.trackerSessionId == attempted.trackerSessionId &&
        normalized.trackerType == attempted.trackerType) {
      return intent;
    }
    return RoutineOccurrenceWriteIntent(
      action: intent.action,
      mutationType: intent.mutationType,
      ownerUid: intent.ownerUid,
      occurrenceId: intent.occurrenceId,
      operationId: intent.operationId,
      attemptedRecord: normalized,
      previousRecord: previous,
      createdAt: intent.createdAt,
      event: intent.event,
      completer: intent.completer,
    );
  }

  RoutineCountdownAllocation? _allocateCountdownForOccurrence({
    required String itemId,
    required String occurrenceDateKey,
    required DateTime actualStart,
    RoutineOccurrenceRecord? existing,
  }) {
    RoutineItem? template;
    for (final candidate in state.items) {
      if (candidate.id == itemId) {
        template = candidate;
        break;
      }
    }
    if (template == null) return null;
    return RoutineCountdownAllocator.allocate(
      template: template,
      occurrenceDateKey: occurrenceDateKey,
      actualStart: actualStart,
      existing: existing,
    );
  }

  Future<RoutineWriteResult> _writeOccurrence(
    String itemId, {
    required RoutineStatus status,
    required String actionSource,
    required String action,
    DateTime? occurrenceDate,
    String? movedToDateKey,
    int? movedStartMinute,
    int? movedEndMinute,
    List<int>? completedSubtaskIndexes,
    String? note,
    String? displayTitleOverride,
    DateTime? startedAt,
    int? countdownDurationSeconds,
    String? trackerSessionId,
    String? trackerType,
  }) async {
    final uid = _requireOwnerUid();
    final date =
        occurrenceDate ?? _occurrenceAnchorDate(itemId, state.selectedDay);
    final dateKey = routineLocalDateKey(date);
    final id = stableRoutineOccurrenceId(
      ownerUid: uid,
      routineItemId: itemId,
      occurrenceDateKey: dateKey,
    );

    final now = DateTime.now().toUtc();
    final existing = _occurrenceFor(itemId, date);
    final occurrenceSource = existing?.source ?? actionSource;
    final occAction = RoutineOccurrenceAction.values.firstWhere(
      (e) => e.name == action,
      orElse: () =>
          throw ArgumentError('Unsupported occurrence action: $action'),
    );

    if (state.pendingOccurrenceIds.contains(id)) {
      final queue = state.queuedOccurrenceActionsById[id] ?? const [];
      final lastAction = queue.isNotEmpty ? queue.last : null;
      final currentPendingRecord = state.occurrences
          .where((e) => e.id == id)
          .lastOrNull;

      if (lastAction != null) {
        if (lastAction.action == occAction &&
            lastAction.targetStatus == status &&
            lastAction.movedToDateKey == movedToDateKey &&
            lastAction.movedStartMinute == movedStartMinute &&
            lastAction.movedEndMinute == movedEndMinute) {
          return RoutineWriteResult.noOp(
            operationId: '',
            resultingStatus: status,
          );
        }
      } else if (currentPendingRecord != null) {
        if (currentPendingRecord.status == status &&
            currentPendingRecord.action == action &&
            currentPendingRecord.movedToDateKey == movedToDateKey &&
            currentPendingRecord.movedStartMinute == movedStartMinute &&
            currentPendingRecord.movedEndMinute == movedEndMinute) {
          return RoutineWriteResult.noOp(
            operationId: currentPendingRecord.operationKey,
            resultingStatus: currentPendingRecord.status,
          );
        }
      }

      final completer = Completer<RoutineWriteResult>();
      final queuedAction = RoutineQueuedOccurrenceAction(
        itemId: itemId,
        action: occAction,
        actionString: action,
        targetStatus: status,
        actionSource: actionSource,
        occurrenceDate: date,
        note: note,
        displayTitleOverride: displayTitleOverride,
        movedToDateKey: movedToDateKey,
        movedStartMinute: movedStartMinute,
        movedEndMinute: movedEndMinute,
        completedSubtaskIndexes: completedSubtaskIndexes,
        startedAt: startedAt,
        countdownDurationSeconds: countdownDurationSeconds,
        trackerSessionId: trackerSessionId,
        trackerType: trackerType,
        source: existing?.source ?? actionSource,
        completer: completer,
        queuedAt: now,
      );

      state = state.copyWith(
        queuedOccurrenceActionsById: {
          ...state.queuedOccurrenceActionsById,
          id: [...queue, queuedAction],
        },
      );
      return await completer.future;
    }

    final decision = RoutineTransitionPolicy.evaluate(
      existingRecord: existing,
      requestedAction: occAction,
      projectedStatus:
          existing?.status ?? _itemFor(itemId)?.status ?? RoutineStatus.planned,
    );
    if (!decision.isAllowed) {
      if (decision.isNoOp) {
        return RoutineWriteResult.noOp(
          message: decision.message,
          failureCategory: decision.failureCategory,
          resultingStatus: existing?.status ?? RoutineStatus.planned,
        );
      }
      return RoutineWriteResult.validationFailed(
        RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.invalidTime,
          userSafeMessage: decision.message ?? 'Invalid routine action.',
        ),
        message: decision.message,
        failureCategory: decision.failureCategory,
        resultingStatus: existing?.status ?? RoutineStatus.planned,
      );
    }

    final timerAllocation =
        action == 'start' &&
            existing?.status != RoutineStatus.completed &&
            existing?.startedAt == null &&
            existing?.countdownDurationSeconds == null
        ? _allocateCountdownForOccurrence(
            itemId: itemId,
            occurrenceDateKey: dateKey,
            actualStart: now,
            existing: existing,
          )
        : null;
    final effectiveStartedAt = action == 'skip'
        ? null
        : (existing?.startedAt ?? startedAt ?? timerAllocation?.startedAt);
    final effectiveCountdownDurationSeconds = action == 'skip'
        ? null
        : (existing?.countdownDurationSeconds ??
              countdownDurationSeconds ??
              timerAllocation?.durationSeconds);

    final operationId = _stableOperationId('occurrence', [
      uid,
      itemId,
      dateKey,
      action,
      status.name,
      movedToDateKey ?? '',
      movedStartMinute ?? '',
      movedEndMinute ?? '',
      completedSubtaskIndexes?.join(',') ?? '',
      note ?? '',
      displayTitleOverride ?? '',
      effectiveStartedAt?.toIso8601String() ?? '',
      effectiveCountdownDurationSeconds ?? '',
      existing?.operationKey ?? '',
    ]);

    final record = RoutineOccurrenceRecord(
      id: id,
      ownerUid: uid,
      routineItemId: itemId,
      occurrenceDateKey: dateKey,
      status: status,
      source: occurrenceSource,
      action: action,
      operationKey: operationId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      movedToDateKey: movedToDateKey ?? existing?.movedToDateKey,
      movedStartMinute: movedStartMinute ?? existing?.movedStartMinute,
      movedEndMinute: movedEndMinute ?? existing?.movedEndMinute,
      completedSubtaskIndexes:
          completedSubtaskIndexes ??
          existing?.completedSubtaskIndexes ??
          const [],
      note: note ?? existing?.note,
      displayTitleOverride:
          displayTitleOverride ?? existing?.displayTitleOverride,
      undoToPlannedAllowed:
          (action == 'skip' || action == 'start' || action == 'startTracker')
          ? true
          : (existing == null),
      onboardingProjectionId: existing?.onboardingProjectionId,
      onboardingSourceItemId: existing?.onboardingSourceItemId,
      sourceFingerprint: existing?.sourceFingerprint,
      startedAt: effectiveStartedAt,
      countdownDurationSeconds: effectiveCountdownDurationSeconds,
      previousStatus:
          (action == 'skip' || action == 'start' || action == 'startTracker')
          ? (existing?.status == RoutineStatus.moved
                ? RoutineStatus.moved
                : null)
          : null,
      previousAction:
          (action == 'skip' || action == 'start' || action == 'startTracker')
          ? (existing?.status == RoutineStatus.moved
                ? (existing?.action ?? 'move')
                : null)
          : null,
      trackerSessionId: trackerSessionId ?? existing?.trackerSessionId,
      trackerType: trackerType ?? existing?.trackerType,
    );

    RoutineEventType eventType = RoutineEventType.edited;
    switch (action) {
      case 'start':
      case 'startTracker':
        eventType = RoutineEventType.started;
        break;
      case 'complete':
        eventType = RoutineEventType.completed;
        break;
      case 'skip':
        eventType = RoutineEventType.skipped;
        break;
      case 'miss':
        eventType = RoutineEventType.missed;
        break;
      case 'move':
        eventType = RoutineEventType.moved;
        break;
      case 'reschedule':
        eventType = RoutineEventType.rescheduled;
        break;
      case 'undo':
        eventType = RoutineEventType.undone;
        break;
    }

    // Capture a snapshot of the template at the moment of the occurrence
    // action so that history rows can render the item's title, time, and type
    // even after the template is edited or deleted.
    final rawOccurrenceSnapshot = _historySnapshotForItemId(itemId, uid);
    if (rawOccurrenceSnapshot == null) {
      _logRoutineActionWrite(
        action: action,
        occurrenceSource: occurrenceSource,
        actionSource: actionSource,
        existing: existing != null,
        result: 'failure',
        error: StateError('missing_item_snapshot'),
      );
      return RoutineWriteResult.validationFailed(
        const RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.missingData,
          userSafeMessage: 'Item not found.',
        ),
      );
    }

    final effMovedToDateKey = movedToDateKey ?? existing?.movedToDateKey;
    final effMovedStart = movedStartMinute ?? existing?.movedStartMinute;
    final effMovedEnd = movedEndMinute ?? existing?.movedEndMinute;
    final effDisplayTitle =
        displayTitleOverride ?? existing?.displayTitleOverride;
    final occurrenceSnapshot = Map<String, dynamic>.from(rawOccurrenceSnapshot);
    if (effMovedToDateKey != null) {
      occurrenceSnapshot['movedToDateKey'] = effMovedToDateKey;
    }
    if (effMovedStart != null) {
      occurrenceSnapshot['movedStartMinute'] = effMovedStart;
    }
    if (effMovedEnd != null) {
      occurrenceSnapshot['movedEndMinute'] = effMovedEnd;
    }
    if (effDisplayTitle != null) {
      occurrenceSnapshot['displayTitleOverride'] = effDisplayTitle;
    }

    final event = RoutineEventRecord(
      eventId: _stableEventId(
        operationId: operationId,
        itemId: itemId,
        eventType: eventType,
      ),
      ownerUid: uid,
      routineItemId: itemId,
      occurrenceId: id,
      occurrenceDateKey: dateKey,
      eventType: eventType,
      operationKey: operationId,
      source: actionSource,
      occurredAt: now,
      itemSnapshot: occurrenceSnapshot,
    );

    final intent = RoutineOccurrenceWriteIntent(
      action: occAction,
      ownerUid: uid,
      occurrenceId: id,
      operationId: operationId,
      attemptedRecord: record,
      previousRecord: existing,
      createdAt: now,
      event: event,
    );

    final previous = state.occurrences;
    state = state.copyWith(
      pendingOccurrenceIds: {...state.pendingOccurrenceIds, id},
      occurrences: [
        for (final candidate in previous)
          if (candidate.id != id) candidate,
        record,
      ],
      error: null,
    );
    return await _commitOccurrenceIntentWithRecovery(intent);
  }

  Future<RoutineWriteResult> _commitOccurrenceIntentWithRecovery(
    RoutineOccurrenceWriteIntent intent, {
    bool isQueued = false,
  }) async {
    final uid = intent.ownerUid;
    final id = intent.occurrenceId;
    final operationId = intent.operationId;
    final isDelete =
        intent.mutationType == RoutineOccurrenceMutationType.deleteRecord;

    try {
      if (isDelete) {
        await _transactionRepository.commitWrite(
          uid: uid,
          deleteOccurrenceId: id,
          addEvent: intent.event,
        );
      } else {
        await _transactionRepository.commitWrite(
          uid: uid,
          setOccurrence: intent.attemptedRecord,
          addEvent: intent.event,
        );
      }

      _logRoutineActionWrite(
        action: intent.attemptedRecord.action,
        occurrenceSource: intent.attemptedRecord.source,
        actionSource: intent.event?.source ?? intent.attemptedRecord.source,
        existing: intent.previousRecord != null,
        result: 'success',
      );

      if (!mounted || _ownerUid != uid) {
        final res = _supersededWriteResult(operationId);
        if (intent.completer != null && !intent.completer!.isCompleted) {
          intent.completer!.complete(res);
        }
        return res;
      }

      state = state.copyWith(
        failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
          ..remove(id),
      );

      final resultingStatus = isDelete
          ? RoutineStatus.planned
          : intent.attemptedRecord.status;

      final writeResult = RoutineWriteResult.saved(
        operationId: operationId,
        resultingStatus: resultingStatus,
      );

      if (intent.completer != null && !intent.completer!.isCompleted) {
        intent.completer!.complete(writeResult);
      }

      await _processNextQueuedOccurrence(uid, id);
      return writeResult;
    } catch (error) {
      if (!mounted || _ownerUid != uid) {
        final res = _supersededWriteResult(operationId);
        if (intent.completer != null && !intent.completer!.isCompleted) {
          intent.completer!.complete(res);
        }
        return res;
      }

      // Check authoritative remote ambiguity recovery on transport / timeout errors
      bool isAmbiguitySuccess = false;
      RoutineOccurrenceRecord? recoveredRecord;
      try {
        if (intent.event != null) {
          final committedEvent = await _transactionRepository.fetchEventById(
            uid,
            intent.event!.eventId,
          );
          if (committedEvent != null &&
              committedEvent.operationKey == operationId) {
            isAmbiguitySuccess = true;
          }
        }

        final history = await _historyRepository.fetchHistory(uid);
        if (!isDelete) {
          for (final occ in history) {
            if (occ.id == id && occ.operationKey == operationId) {
              isAmbiguitySuccess = true;
              recoveredRecord = occ;
              break;
            }
          }
        }
      } catch (_) {}

      if (isAmbiguitySuccess) {
        _logRoutineActionWrite(
          action: intent.attemptedRecord.action,
          occurrenceSource: intent.attemptedRecord.source,
          actionSource: intent.event?.source ?? intent.attemptedRecord.source,
          existing: intent.previousRecord != null,
          result: 'success',
        );

        state = state.copyWith(
          failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
            ..remove(id),
          occurrences: isDelete
              ? state.occurrences.where((e) => e.id != id).toList()
              : [
                  for (final candidate in state.occurrences)
                    if (candidate.id != id) candidate,
                  recoveredRecord ?? intent.attemptedRecord,
                ],
        );

        final resultingStatus = isDelete
            ? RoutineStatus.planned
            : (recoveredRecord?.status ?? intent.attemptedRecord.status);

        final writeResult = RoutineWriteResult.saved(
          operationId: operationId,
          resultingStatus: resultingStatus,
        );

        if (intent.completer != null && !intent.completer!.isCompleted) {
          intent.completer!.complete(writeResult);
        }

        await _processNextQueuedOccurrence(uid, id);
        return writeResult;
      }

      final failureCat = classifyRoutineWriteFailure(error);
      _logRoutineActionWrite(
        action: intent.attemptedRecord.action,
        occurrenceSource: intent.attemptedRecord.source,
        actionSource: intent.event?.source ?? intent.attemptedRecord.source,
        existing: intent.previousRecord != null,
        result: 'failure',
        error: error,
      );

      final rolledBackOccurrences = [
        for (final candidate in state.occurrences)
          if (candidate.id != id) candidate,
        if (intent.previousRecord != null) intent.previousRecord!,
      ];

      state = state.copyWith(
        failedOccurrenceIntentsById: {
          ...state.failedOccurrenceIntentsById,
          id: intent,
        },
        occurrences: rolledBackOccurrences,
        error: failureCat == RoutineFailureCategory.offlineOrUnavailable
            ? 'Offline / sync pending.'
            : 'Could not update routine. Please try again.',
      );

      final retryResult = RoutineWriteResult.retryRequired(
        message: failureCat == RoutineFailureCategory.offlineOrUnavailable
            ? 'Offline / sync pending.'
            : 'Could not update routine. Please try again.',
        operationId: operationId,
        failureCategory: failureCat,
        resultingStatus: intent.previousRecord?.status ?? RoutineStatus.planned,
      );

      if (intent.completer != null && !intent.completer!.isCompleted) {
        intent.completer!.complete(retryResult);
      }

      await _processNextQueuedOccurrence(uid, id);
      return retryResult;
    }
  }

  Future<void> _processNextQueuedOccurrence(String uid, String id) async {
    final queue = state.queuedOccurrenceActionsById[id] ?? const [];
    if (queue.isEmpty) {
      state = state.copyWith(
        pendingOccurrenceIds: state.pendingOccurrenceIds
            .where((e) => e != id)
            .toSet(),
      );
      return;
    }

    final queuedAction = queue.first;
    final remainingQueue = queue.sublist(1);

    state = state.copyWith(
      queuedOccurrenceActionsById: {
        ...state.queuedOccurrenceActionsById,
        id: remainingQueue,
      },
    );

    // Rebase against CURRENT effective state (after predecessor committed or rolled back)
    final currentRecord = state.occurrences
        .where((e) => e.id == id)
        .firstOrNull;

    final transition = RoutineTransitionPolicy.evaluate(
      existingRecord: currentRecord,
      requestedAction: queuedAction.action,
    );

    if (!transition.isAllowed) {
      final res = transition.isNoOp
          ? RoutineWriteResult.noOp(
              message: transition.message,
              resultingStatus: currentRecord?.status ?? RoutineStatus.planned,
            )
          : RoutineWriteResult.validationFailed(
              RoutineValidationResult.invalid(
                errorType: RoutineValidationErrorType.missingData,
                userSafeMessage:
                    transition.message ?? 'Invalid state transition.',
              ),
              message: transition.message,
              failureCategory: transition.failureCategory,
              resultingStatus: currentRecord?.status ?? RoutineStatus.planned,
            );
      if (queuedAction.completer != null &&
          !queuedAction.completer!.isCompleted) {
        queuedAction.completer!.complete(res);
      }
      await _processNextQueuedOccurrence(uid, id);
      return;
    }

    final date =
        queuedAction.occurrenceDate ??
        _occurrenceAnchorDate(queuedAction.itemId, state.selectedDay);
    final dateKey = routineLocalDateKey(date);
    final now = DateTime.now().toUtc();

    if (queuedAction.action == RoutineOccurrenceAction.undo) {
      if (currentRecord == null) {
        final res = const RoutineWriteResult.noOp(
          message: 'No occurrence action to undo.',
          resultingStatus: RoutineStatus.planned,
        );
        if (queuedAction.completer != null &&
            !queuedAction.completer!.isCompleted) {
          queuedAction.completer!.complete(res);
        }
        await _processNextQueuedOccurrence(uid, id);
        return;
      }

      final operationId = _stableOperationId('occurrence_undo', [
        uid,
        queuedAction.itemId,
        dateKey,
        currentRecord.operationKey,
      ]);
      final rawSnapshot = _historySnapshotForItemId(queuedAction.itemId, uid);
      if (rawSnapshot == null) {
        final res = RoutineWriteResult.validationFailed(
          const RoutineValidationResult.invalid(
            errorType: RoutineValidationErrorType.missingData,
            userSafeMessage: 'Item not found.',
          ),
        );
        if (queuedAction.completer != null &&
            !queuedAction.completer!.isCompleted) {
          queuedAction.completer!.complete(res);
        }
        await _processNextQueuedOccurrence(uid, id);
        return;
      }

      final event = RoutineEventRecord(
        eventId: _stableEventId(
          operationId: operationId,
          itemId: queuedAction.itemId,
          eventType: RoutineEventType.undone,
        ),
        ownerUid: uid,
        routineItemId: queuedAction.itemId,
        occurrenceId: id,
        occurrenceDateKey: dateKey,
        eventType: RoutineEventType.undone,
        operationKey: operationId,
        source: 'app',
        occurredAt: now,
        itemSnapshot: rawSnapshot,
      );

      final isRestoringMoved =
          currentRecord.previousStatus == RoutineStatus.moved;
      final restoredRecord = isRestoringMoved
          ? currentRecord.clearTimer().copyWith(
              status: RoutineStatus.moved,
              action: currentRecord.previousAction ?? 'move',
              operationKey: operationId,
              previousStatus: null,
              previousAction: null,
              undoToPlannedAllowed: true,
              updatedAt: now,
            )
          : null;

      final intent = RoutineOccurrenceWriteIntent(
        action: RoutineOccurrenceAction.undo,
        mutationType: isRestoringMoved
            ? RoutineOccurrenceMutationType.setRecord
            : RoutineOccurrenceMutationType.deleteRecord,
        ownerUid: uid,
        occurrenceId: id,
        operationId: operationId,
        attemptedRecord: restoredRecord ?? currentRecord,
        previousRecord: currentRecord,
        createdAt: now,
        event: event,
        completer: queuedAction.completer,
      );

      state = state.copyWith(
        occurrences: isRestoringMoved
            ? [
                for (final occ in state.occurrences)
                  if (occ.id == id) restoredRecord! else occ,
              ]
            : state.occurrences.where((e) => e.id != id).toList(),
        error: null,
      );

      await _commitOccurrenceIntentWithRecovery(intent, isQueued: true);
      return;
    }

    final timerAllocation =
        (queuedAction.actionString == 'start' ||
            queuedAction.actionString == 'startTracker')
        ? _allocateCountdownForOccurrence(
            itemId: queuedAction.itemId,
            occurrenceDateKey: dateKey,
            actualStart: queuedAction.startedAt ?? now,
            existing: currentRecord,
          )
        : null;

    final effectiveStartedAt = queuedAction.actionString == 'skip'
        ? null
        : ((queuedAction.actionString == 'start' &&
                  currentRecord?.startedAt == null &&
                  timerAllocation != null)
              ? timerAllocation.startedAt
              : (queuedAction.startedAt ??
                    (currentRecord?.startedAt ??
                        (queuedAction.actionString == 'startTracker'
                            ? (currentRecord?.startedAt ?? now)
                            : null))));

    final effectiveCountdownDurationSeconds =
        queuedAction.actionString == 'skip'
        ? null
        : ((queuedAction.actionString == 'start' &&
                  currentRecord?.countdownDurationSeconds == null &&
                  timerAllocation != null)
              ? timerAllocation.durationSeconds
              : (currentRecord?.countdownDurationSeconds ??
                    queuedAction.countdownDurationSeconds ??
                    timerAllocation?.durationSeconds));

    final operationId = _stableOperationId('occurrence', [
      uid,
      queuedAction.itemId,
      dateKey,
      queuedAction.actionString,
      queuedAction.targetStatus?.name ?? '',
      queuedAction.movedToDateKey ?? '',
      queuedAction.movedStartMinute ?? '',
      queuedAction.movedEndMinute ?? '',
      queuedAction.completedSubtaskIndexes?.join(',') ?? '',
      queuedAction.note ?? '',
      queuedAction.displayTitleOverride ?? '',
      effectiveStartedAt?.toIso8601String() ?? '',
      effectiveCountdownDurationSeconds ?? '',
      currentRecord?.operationKey ?? '',
    ]);

    final occurrenceSource =
        queuedAction.source ??
        (currentRecord?.source ?? queuedAction.actionSource);

    final record = RoutineOccurrenceRecord(
      id: id,
      ownerUid: uid,
      routineItemId: queuedAction.itemId,
      occurrenceDateKey: dateKey,
      status: queuedAction.targetStatus ?? RoutineStatus.active,
      source: occurrenceSource,
      action: queuedAction.actionString,
      operationKey: operationId,
      createdAt: currentRecord?.createdAt ?? now,
      updatedAt: now,
      movedToDateKey:
          queuedAction.movedToDateKey ?? currentRecord?.movedToDateKey,
      movedStartMinute:
          queuedAction.movedStartMinute ?? currentRecord?.movedStartMinute,
      movedEndMinute:
          queuedAction.movedEndMinute ?? currentRecord?.movedEndMinute,
      completedSubtaskIndexes:
          queuedAction.completedSubtaskIndexes ??
          currentRecord?.completedSubtaskIndexes ??
          const [],
      note: queuedAction.note ?? currentRecord?.note,
      displayTitleOverride:
          queuedAction.displayTitleOverride ??
          currentRecord?.displayTitleOverride,
      undoToPlannedAllowed:
          (queuedAction.actionString == 'skip' ||
              queuedAction.actionString == 'start' ||
              queuedAction.actionString == 'startTracker')
          ? true
          : (currentRecord == null),
      onboardingProjectionId: currentRecord?.onboardingProjectionId,
      onboardingSourceItemId: currentRecord?.onboardingSourceItemId,
      sourceFingerprint: currentRecord?.sourceFingerprint,
      startedAt: effectiveStartedAt,
      countdownDurationSeconds: effectiveCountdownDurationSeconds,
      previousStatus:
          (queuedAction.actionString == 'skip' ||
              queuedAction.actionString == 'start' ||
              queuedAction.actionString == 'startTracker')
          ? (currentRecord?.status == RoutineStatus.moved
                ? RoutineStatus.moved
                : null)
          : null,
      previousAction:
          (queuedAction.actionString == 'skip' ||
              queuedAction.actionString == 'start' ||
              queuedAction.actionString == 'startTracker')
          ? (currentRecord?.status == RoutineStatus.moved
                ? (currentRecord?.action ?? 'move')
                : null)
          : null,
      trackerSessionId:
          queuedAction.trackerSessionId ?? currentRecord?.trackerSessionId,
      trackerType: queuedAction.trackerType ?? currentRecord?.trackerType,
    );

    RoutineEventType eventType = RoutineEventType.edited;
    switch (queuedAction.actionString) {
      case 'start':
      case 'startTracker':
        eventType = RoutineEventType.started;
        break;
      case 'complete':
        eventType = RoutineEventType.completed;
        break;
      case 'skip':
        eventType = RoutineEventType.skipped;
        break;
      case 'miss':
        eventType = RoutineEventType.missed;
        break;
      case 'move':
        eventType = RoutineEventType.moved;
        break;
      case 'reschedule':
        eventType = RoutineEventType.rescheduled;
        break;
      case 'undo':
        eventType = RoutineEventType.undone;
        break;
    }

    final rawSnapshot = _historySnapshotForItemId(queuedAction.itemId, uid);
    if (rawSnapshot == null) {
      final res = RoutineWriteResult.validationFailed(
        const RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.missingData,
          userSafeMessage: 'Item not found.',
        ),
      );
      if (queuedAction.completer != null &&
          !queuedAction.completer!.isCompleted) {
        queuedAction.completer!.complete(res);
      }
      await _processNextQueuedOccurrence(uid, id);
      return;
    }

    final effMovedToDateKey =
        queuedAction.movedToDateKey ?? currentRecord?.movedToDateKey;
    final effMovedStart =
        queuedAction.movedStartMinute ?? currentRecord?.movedStartMinute;
    final effMovedEnd =
        queuedAction.movedEndMinute ?? currentRecord?.movedEndMinute;
    final effDisplayTitle =
        queuedAction.displayTitleOverride ??
        currentRecord?.displayTitleOverride;
    final occurrenceSnapshot = Map<String, dynamic>.from(rawSnapshot);
    if (effMovedToDateKey != null) {
      occurrenceSnapshot['movedToDateKey'] = effMovedToDateKey;
    }
    if (effMovedStart != null) {
      occurrenceSnapshot['movedStartMinute'] = effMovedStart;
    }
    if (effMovedEnd != null) {
      occurrenceSnapshot['movedEndMinute'] = effMovedEnd;
    }
    if (effDisplayTitle != null) {
      occurrenceSnapshot['displayTitleOverride'] = effDisplayTitle;
    }

    final event = RoutineEventRecord(
      eventId: _stableEventId(
        operationId: operationId,
        itemId: queuedAction.itemId,
        eventType: eventType,
      ),
      ownerUid: uid,
      routineItemId: queuedAction.itemId,
      occurrenceId: id,
      occurrenceDateKey: dateKey,
      eventType: eventType,
      operationKey: operationId,
      source: queuedAction.actionSource,
      occurredAt: now,
      itemSnapshot: occurrenceSnapshot,
    );

    final intent = RoutineOccurrenceWriteIntent(
      action: queuedAction.action,
      ownerUid: uid,
      occurrenceId: id,
      operationId: operationId,
      attemptedRecord: record,
      previousRecord: currentRecord,
      createdAt: now,
      event: event,
      completer: queuedAction.completer,
    );

    state = state.copyWith(
      occurrences: [
        for (final candidate in state.occurrences)
          if (candidate.id != id) candidate,
        record,
      ],
      error: null,
    );

    await _commitOccurrenceIntentWithRecovery(intent, isQueued: true);
  }

  Future<RoutineWriteResult> undoOccurrenceAction(
    String itemId, {
    DateTime? occurrenceDate,
  }) async {
    final uid = _requireOwnerUid();
    final date =
        occurrenceDate ?? _occurrenceAnchorDate(itemId, state.selectedDay);
    final dateKey = routineLocalDateKey(date);
    final id = stableRoutineOccurrenceId(
      ownerUid: uid,
      routineItemId: itemId,
      occurrenceDateKey: dateKey,
    );

    if (state.pendingOccurrenceIds.contains(id)) {
      final queue = state.queuedOccurrenceActionsById[id] ?? const [];
      final completer = Completer<RoutineWriteResult>();
      final queuedAction = RoutineQueuedOccurrenceAction(
        itemId: itemId,
        action: RoutineOccurrenceAction.undo,
        actionString: 'undo',
        occurrenceDate: date,
        completer: completer,
        queuedAt: DateTime.now().toUtc(),
      );
      state = state.copyWith(
        queuedOccurrenceActionsById: {
          ...state.queuedOccurrenceActionsById,
          id: [...queue, queuedAction],
        },
      );
      return await completer.future;
    }

    final existing = _occurrenceFor(itemId, date);
    final decision = RoutineTransitionPolicy.evaluate(
      existingRecord: existing,
      requestedAction: RoutineOccurrenceAction.undo,
    );
    if (!decision.isAllowed && decision.isNoOp) {
      return RoutineWriteResult.noOp(
        message: decision.message,
        resultingStatus: RoutineStatus.planned,
      );
    }
    if (!decision.isAllowed) {
      return RoutineWriteResult.validationFailed(
        RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.missingData,
          userSafeMessage:
              decision.message ?? 'This action can no longer be undone.',
        ),
        message: decision.message,
        failureCategory: decision.failureCategory,
        resultingStatus: existing?.status,
      );
    }
    final undoRecord = existing!;

    final operationId = _stableOperationId('occurrence_undo', [
      uid,
      itemId,
      dateKey,
      undoRecord.operationKey,
    ]);
    final snapshot = _historySnapshotForItemId(itemId, uid);
    if (snapshot == null) {
      return RoutineWriteResult.validationFailed(
        const RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.missingData,
          userSafeMessage: 'Item not found.',
        ),
      );
    }
    final event = RoutineEventRecord(
      eventId: _stableEventId(
        operationId: operationId,
        itemId: itemId,
        eventType: RoutineEventType.undone,
      ),
      ownerUid: uid,
      routineItemId: itemId,
      occurrenceId: id,
      occurrenceDateKey: dateKey,
      eventType: RoutineEventType.undone,
      operationKey: operationId,
      source: 'app',
      occurredAt: DateTime.now().toUtc(),
      itemSnapshot: snapshot,
    );

    final restoredRecord = undoRecord.previousStatus == RoutineStatus.moved
        ? undoRecord.clearTimer().copyWith(
            status: RoutineStatus.moved,
            action: undoRecord.previousAction ?? 'move',
            operationKey: operationId,
            previousStatus: null,
            previousAction: null,
            undoToPlannedAllowed: true,
            updatedAt: DateTime.now().toUtc(),
          )
        : null;

    final isRestoringMoved = restoredRecord != null;
    final intent = RoutineOccurrenceWriteIntent(
      action: RoutineOccurrenceAction.undo,
      mutationType: isRestoringMoved
          ? RoutineOccurrenceMutationType.setRecord
          : RoutineOccurrenceMutationType.deleteRecord,
      ownerUid: uid,
      occurrenceId: id,
      operationId: operationId,
      attemptedRecord: restoredRecord ?? undoRecord,
      previousRecord: undoRecord,
      createdAt: DateTime.now().toUtc(),
      event: event,
    );

    state = state.copyWith(
      pendingOccurrenceIds: {...state.pendingOccurrenceIds, id},
      occurrences: isRestoringMoved
          ? [
              for (final occ in state.occurrences)
                if (occ.id == id) restoredRecord else occ,
            ]
          : state.occurrences.where((e) => e.id != id).toList(),
      error: null,
    );

    return await _commitOccurrenceIntentWithRecovery(intent);
  }

  Future<RoutineWriteResult> retryFailedOccurrenceAction(
    String occurrenceId,
  ) async {
    final intent = state.failedOccurrenceIntentsById[occurrenceId];
    if (intent == null) {
      return const RoutineWriteResult.noOp(
        message: 'No failed occurrence action.',
      );
    }

    final uid = _requireOwnerUid();
    if (intent.ownerUid != uid) {
      return _supersededWriteResult(intent.operationId);
    }

    final isDelete =
        intent.mutationType == RoutineOccurrenceMutationType.deleteRecord;
    final retryIntent = isDelete
        ? intent
        : _normalizeOccurrenceIntentForRetry(intent);

    state = state.copyWith(
      pendingOccurrenceIds: {...state.pendingOccurrenceIds, occurrenceId},
      occurrences: isDelete
          ? state.occurrences.where((e) => e.id != occurrenceId).toList()
          : [
              for (final candidate in state.occurrences)
                if (candidate.id != occurrenceId) candidate,
              retryIntent.attemptedRecord,
            ],
      error: null,
    );

    return await _commitOccurrenceIntentWithRecovery(retryIntent);
  }

  DateTime _occurrenceAnchorDate(String itemId, DateTime selectedDay) {
    RoutineItem? template;
    for (final candidate in state.items) {
      if (candidate.id == itemId) {
        template = candidate;
        break;
      }
    }
    if (template == null) return selectedDay;
    final selected = TimelineUtils.dateOnly(selectedDay);
    if (RoutineMaterializer.startsOnDay(template, selected)) {
      return selected;
    }
    final previous = selected.subtract(const Duration(days: 1));
    if (template.isOvernight &&
        RoutineMaterializer.startsOnDay(template, previous)) {
      return previous;
    }
    return selected;
  }

  Future<RoutineWriteResult> startRoutineItem(
    String itemId, {
    DateTime? occurrenceDate,
  }) async {
    final targetIndex = state.items.indexWhere((e) => e.id == itemId);
    if (targetIndex != -1) {
      final item = state.items[targetIndex];
      if (item.blockType == RoutineBlockType.flexibleTask) {
        return await startFlexibleTask(itemId, occurrenceDate: occurrenceDate);
      }
      if (item.blockType == RoutineBlockType.trackerTask) {
        return await _startTrackerTask(item, occurrenceDate: occurrenceDate);
      }
    }
    return await _writeOccurrence(
      itemId,
      status: RoutineStatus.active,
      actionSource: 'routine',
      action: 'start',
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> completeRoutineItem(
    String itemId, {
    DateTime? occurrenceDate,
  }) async {
    final targetIndex = state.items.indexWhere((e) => e.id == itemId);
    if (targetIndex != -1) {
      final item = state.items[targetIndex];
      if (item.blockType == RoutineBlockType.trackerTask) {
        return await _completeTrackerSession(
          itemId,
          occurrenceDate: occurrenceDate,
        );
      }
      if (item.blockType == RoutineBlockType.moneyTask) {
        if (!hasConfirmedMoneySaveForRoutine(itemId, date: occurrenceDate)) {
          return RoutineWriteResult.validationFailed(
            const RoutineValidationResult.invalid(
              errorType: RoutineValidationErrorType.missingData,
              userSafeMessage:
                  'Please save money via UPI or Tracker to complete this task.',
            ),
            message: 'Money task requires a confirmed save.',
            failureCategory: RoutineFailureCategory.validation,
          );
        }
        return await recordMoneySavedAndComplete(
          itemId,
          occurrenceDate: occurrenceDate,
        );
      }
      if (item.blockType == RoutineBlockType.checkIn &&
          item.category == RoutineCategory.badHabit) {
        return RoutineWriteResult.validationFailed(
          const RoutineValidationResult.invalid(
            errorType: RoutineValidationErrorType.missingData,
            userSafeMessage:
                'Check-in requires selecting a status (Avoided, Craving, or Relapsed).',
          ),
          message: 'Generic complete not allowed for bad-habit check-in.',
          failureCategory: RoutineFailureCategory.validation,
        );
      }
    }
    return await markCompleted(itemId, occurrenceDate: occurrenceDate);
  }

  Future<RoutineWriteResult> startFlexibleTask(
    String itemId, {
    DateTime? occurrenceDate,
  }) async {
    return await _writeOccurrence(
      itemId,
      status: RoutineStatus.active,
      actionSource: 'routine',
      action: 'start',
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> toggleSubtask(
    String itemId,
    int subtaskIndex, {
    DateTime? occurrenceDate,
  }) async {
    RoutineItem? item;
    for (final candidate in state.items) {
      if (candidate.id == itemId) {
        item = candidate;
        break;
      }
    }
    final subtasks = item?.subtasks;
    if (subtasks == null ||
        subtaskIndex < 0 ||
        subtaskIndex >= subtasks.length) {
      return RoutineWriteResult.validationFailed(
        const RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.missingData,
          userSafeMessage: 'Subtask not found.',
        ),
      );
    }
    final anchor =
        occurrenceDate ?? _occurrenceAnchorDate(itemId, state.selectedDay);
    final completed = {
      ...?_occurrenceFor(itemId, anchor)?.completedSubtaskIndexes,
    };
    if (!completed.add(subtaskIndex)) completed.remove(subtaskIndex);
    return await _writeOccurrence(
      itemId,
      status: _occurrenceFor(itemId, anchor)?.status ?? RoutineStatus.active,
      actionSource: 'routine',
      action: 'toggleSubtask',
      completedSubtaskIndexes: completed.toList()..sort(),
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> markCompleted(
    String itemId, {
    DateTime? occurrenceDate,
  }) async {
    return await _writeOccurrence(
      itemId,
      status: RoutineStatus.completed,
      actionSource: 'routine',
      action: 'complete',
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> markSkipped(
    String itemId, {
    DateTime? occurrenceDate,
  }) async {
    return await _writeOccurrence(
      itemId,
      status: RoutineStatus.skipped,
      actionSource: 'routine',
      action: 'skip',
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> markMissed(String itemId) async {
    return await _writeOccurrence(
      itemId,
      status: RoutineStatus.missed,
      actionSource: 'routine',
      action: 'miss',
    );
  }

  Future<RoutineWriteResult> markFlexible(String itemId) async {
    return await _updateById(
      itemId,
      (item) => item.copyWith(
        blockType: RoutineBlockType.flexibleTask,
        hardBlock: false,
        allowedOverlaps: const [],
      ),
    );
  }

  Future<RoutineWriteResult> checkIn(
    String itemId,
    String response, {
    DateTime? occurrenceDate,
  }) async {
    final normalized = response.toLowerCase();
    final status = normalized == 'relapsed'
        ? RoutineStatus.missed
        : RoutineStatus.completed;
    return await _writeOccurrence(
      itemId,
      status: status,
      actionSource: 'checkIn',
      action: 'checkIn',
      note: 'Check-in: $response',
      occurrenceDate: occurrenceDate,
    );
  }

  bool hasConfirmedMoneySaveForRoutine(String routineTaskId, {DateTime? date}) {
    final tracker = _ref.read(mockTrackerProvider);
    final targetDateKey = routineLocalDateKey(
      date ?? _occurrenceAnchorDate(routineTaskId, state.selectedDay),
    );
    return tracker.savingsEntries.any(
      (entry) =>
          entry.routineTaskId == routineTaskId &&
          entry.isConfirmed &&
          entry.dateKey == targetDateKey,
    );
  }

  Future<RoutineWriteResult> recordMoneySavedAndComplete(
    String itemId, {
    double? amount,
    DateTime? occurrenceDate,
  }) async {
    return _alreadySaved(
      itemId,
      amount: amount,
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> alreadySaved(
    String itemId, {
    double? amount,
    DateTime? occurrenceDate,
  }) {
    return _alreadySaved(
      itemId,
      amount: amount,
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> _alreadySaved(
    String itemId, {
    double? amount,
    DateTime? occurrenceDate,
  }) async {
    final fakeAllowed = _ref.read(fakeDataAllowedProvider);
    if (fakeAllowed) {
      final moneyGoal = _ref.read(mockTrackerProvider).moneyGoal;
      final alreadyConfirmed = hasConfirmedMoneySaveForRoutine(
        itemId,
        date: occurrenceDate,
      );
      if (!alreadyConfirmed) {
        final targetAmount = (amount != null && amount > 0)
            ? amount
            : (moneyGoal.dailyTarget > 0 ? moneyGoal.dailyTarget : 10.0);
        _ref
            .read(mockTrackerProvider.notifier)
            .saveMoneyToday(
              amount: targetAmount,
              method: moneyGoal.defaultMethod,
              source: MoneyEntrySource.routineTask,
              description: 'Routine Money System task',
              routineTaskId: itemId,
            );
      }
    }
    // In Firebase mode (!fakeAllowed), we do NOT mutate unbacked mock tracker state (preserving isolation),
    // and write the completed occurrence directly as the user explicitly declared their save.
    return await _writeOccurrence(
      itemId,
      status: RoutineStatus.completed,
      actionSource: 'money',
      action: 'complete',
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> startTrackerTask(
    RoutineItem item, {
    DateTime? occurrenceDate,
  }) {
    return _startTrackerTask(item, occurrenceDate: occurrenceDate);
  }

  Future<RoutineWriteResult> _startTrackerTask(
    RoutineItem item, {
    DateTime? occurrenceDate,
  }) async {
    final anchor =
        occurrenceDate ?? _occurrenceAnchorDate(item.id, state.selectedDay);
    final existing = _occurrenceFor(item.id, anchor);
    final decision = RoutineTransitionPolicy.evaluate(
      existingRecord: existing,
      requestedAction: RoutineOccurrenceAction.startTracker,
    );
    if (!decision.isAllowed) {
      if (decision.isNoOp) {
        _ref.read(appNavigationProvider.notifier).goToTracker();
        return RoutineWriteResult.noOp(
          message: decision.message,
          failureCategory: decision.failureCategory,
        );
      }
      return RoutineWriteResult.validationFailed(
        RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.invalidTime,
          userSafeMessage: decision.message ?? 'Cannot start tracker.',
        ),
        message: decision.message,
        failureCategory: decision.failureCategory,
      );
    }

    final now = DateTime.now();
    final occurrenceDateKey = routineLocalDateKey(anchor);
    final sessionId = 'tracker-${item.id}-${now.millisecondsSinceEpoch}';
    final trackerType = item.trackerType == TrackerType.none
        ? _inferTrackerType(item)
        : item.trackerType;
    final link = TrackerSessionLink(
      routineTaskId: item.id,
      occurrenceDateKey: occurrenceDateKey,
      trackerType: trackerType.name,
      sessionId: sessionId,
      startedAt: now,
      status: 'active',
    );

    final result = await _writeOccurrence(
      item.id,
      status: RoutineStatus.inTracker,
      actionSource: 'tracker',
      action: 'startTracker',
      occurrenceDate: occurrenceDate,
      trackerSessionId: sessionId,
      trackerType: trackerType.name,
    );
    if (!result.closesUserFlow) return result;
    if (_ownerUid == null) return result;

    _ref.read(trackerSessionLinksProvider.notifier).upsert(link);

    state = state.copyWith(
      activeTrackerLaunchIntent: TrackerLaunchIntent(
        trackerType: trackerType,
        routineTaskId: item.id,
        occurrenceDateKey: occurrenceDateKey,
        sessionId: sessionId,
        startedAt: now,
      ),
    );

    _ref.read(appNavigationProvider.notifier).goToTracker();
    return result;
  }

  void openTrackerSession(String itemId, {DateTime? occurrenceDate}) {
    final anchor =
        occurrenceDate ?? _occurrenceAnchorDate(itemId, state.selectedDay);
    final occurrenceDateKey = routineLocalDateKey(anchor);
    final existing = _occurrenceFor(itemId, anchor);
    final item = state.items.where((e) => e.id == itemId).firstOrNull;
    final trackerType =
        (item?.trackerType != null && item!.trackerType != TrackerType.none)
        ? item.trackerType
        : TrackerType.values.firstWhere(
            (t) => t.name == existing?.trackerType,
            orElse: () => TrackerType.none,
          );
    final links = _ref.read(trackerSessionLinksProvider);
    TrackerSessionLink? link;
    for (final candidate in links) {
      if (candidate.routineTaskId == itemId &&
          candidate.occurrenceDateKey == occurrenceDateKey) {
        link = candidate;
        break;
      }
    }

    final sessionId = existing?.trackerSessionId ?? link?.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      state = state.copyWith(
        error: 'No active tracker session found for this routine task.',
      );
      return;
    }

    state = state.copyWith(
      activeTrackerLaunchIntent: TrackerLaunchIntent(
        trackerType: trackerType,
        routineTaskId: itemId,
        occurrenceDateKey: occurrenceDateKey,
        sessionId: sessionId,
        startedAt: existing?.startedAt ?? link?.startedAt ?? DateTime.now(),
      ),
    );

    _ref.read(appNavigationProvider.notifier).goToTracker();
  }

  Future<RoutineWriteResult> completeTrackerSession(
    String routineTaskId, {
    DateTime? occurrenceDate,
    bool allowUntracked = false,
  }) {
    return _completeTrackerSession(
      routineTaskId,
      occurrenceDate: occurrenceDate,
      allowUntracked: allowUntracked,
    );
  }

  Future<RoutineWriteResult> markDoneWithoutTracking(
    String routineTaskId, {
    DateTime? occurrenceDate,
  }) {
    return _completeTrackerSession(
      routineTaskId,
      occurrenceDate: occurrenceDate,
      allowUntracked: true,
    );
  }

  Future<RoutineWriteResult> _completeTrackerSession(
    String routineTaskId, {
    DateTime? occurrenceDate,
    bool allowUntracked = false,
  }) async {
    final links = _ref.read(trackerSessionLinksProvider);
    final anchor =
        occurrenceDate ??
        _occurrenceAnchorDate(routineTaskId, state.selectedDay);
    final occurrenceDateKey = routineLocalDateKey(anchor);
    TrackerSessionLink? link;
    for (final candidate in links) {
      if (candidate.routineTaskId == routineTaskId &&
          candidate.occurrenceDateKey == occurrenceDateKey) {
        link = candidate;
        break;
      }
    }
    final existing = _occurrenceFor(routineTaskId, anchor);
    if (link == null && existing?.trackerSessionId != null) {
      link = TrackerSessionLink(
        routineTaskId: routineTaskId,
        occurrenceDateKey: occurrenceDateKey,
        trackerType: existing!.trackerType ?? TrackerType.none.name,
        sessionId: existing.trackerSessionId!,
        startedAt: existing.startedAt ?? existing.createdAt,
        status: 'active',
      );
      _ref.read(trackerSessionLinksProvider.notifier).upsert(link);
    }
    if (!allowUntracked && (link == null || link.status != 'active')) {
      return RoutineWriteResult.validationFailed(
        const RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.missingData,
          userSafeMessage:
              'Tracker session has not been started. Start tracker first.',
        ),
        message: 'Cannot complete tracker task without active session.',
        failureCategory: RoutineFailureCategory.validation,
      );
    }
    final now = DateTime.now();
    final result = await _writeOccurrence(
      routineTaskId,
      status: RoutineStatus.completed,
      actionSource: 'tracker',
      action: 'complete',
      occurrenceDate: anchor,
    );
    if (!result.closesUserFlow) return result;
    if (link != null) {
      _ref
          .read(trackerSessionLinksProvider.notifier)
          .upsert(
            link.copyWith(
              completedAt: now,
              duration: link.startedAt == null
                  ? null
                  : now.difference(link.startedAt!),
              status: 'completed',
            ),
          );
    }
    if (result.closesUserFlow &&
        state.activeTrackerLaunchIntent?.routineTaskId == routineTaskId &&
        state.activeTrackerLaunchIntent?.occurrenceDateKey ==
            occurrenceDateKey) {
      state = state.copyWith(clearTrackerIntent: true);
    }
    return result;
  }

  Future<RoutineWriteResult> _executeCanonicalMove({
    required String itemId,
    required DateTime targetDate,
    required int startMinute,
    required int durationMinutes,
    DateTime? occurrenceDate,
    String action = 'move',
    String? displayTitleOverride,
  }) async {
    _requireOwnerUid();
    final targetIndex = state.items.indexWhere((e) => e.id == itemId);
    if (targetIndex == -1) {
      return RoutineWriteResult.validationFailed(
        const RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.missingData,
          userSafeMessage: 'Item not found.',
        ),
      );
    }
    final item = state.items[targetIndex];

    final anchor =
        occurrenceDate ?? _occurrenceAnchorDate(itemId, state.selectedDay);
    final existingOcc = _occurrenceFor(itemId, anchor);
    final effectiveStatus = existingOcc?.status ?? item.status;

    final reqAction = action == 'makeTiny'
        ? RoutineOccurrenceAction.makeTiny
        : (action == 'reschedule'
              ? RoutineOccurrenceAction.reschedule
              : RoutineOccurrenceAction.move);
    final policyDecision = RoutineTransitionPolicy.evaluate(
      existingRecord: existingOcc,
      requestedAction: reqAction,
      projectedStatus: effectiveStatus,
    );
    if (!policyDecision.isAllowed) {
      return RoutineWriteResult.validationFailed(
        RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.invalidTime,
          userSafeMessage:
              policyDecision.message ?? 'This routine cannot be moved.',
        ),
        message: policyDecision.message,
        failureCategory: policyDecision.failureCategory,
        resultingStatus: effectiveStatus,
      );
    }

    final rawEndMinute = startMinute + durationMinutes;
    final endMinute = rawEndMinute <= 1440 ? rawEndMinute : rawEndMinute % 1440;
    if (endMinute == startMinute) {
      return RoutineWriteResult.validationFailed(
        const RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.invalidTime,
          userSafeMessage: 'Move duration must be less than 24 hours.',
        ),
        resultingStatus:
            _occurrenceFor(
              itemId,
              occurrenceDate ??
                  _occurrenceAnchorDate(itemId, state.selectedDay),
            )?.status ??
            RoutineStatus.planned,
      );
    }
    final dummyItem = item.copyWith(
      startMinute: startMinute,
      endMinute: endMinute,
      crossesMidnight: endMinute <= startMinute,
      endsNextDay: endMinute <= startMinute,
      date: TimelineUtils.dateOnly(targetDate),
      repeatDays: const [],
      clearConflict: true,
    );

    final validation = _validate(
      dummyItem,
      targetDate,
      operation: RoutineValidationOperation.move,
    );
    if (!validation.isValid) {
      return RoutineWriteResult.validationFailed(
        validation,
        resultingStatus:
            _occurrenceFor(
              itemId,
              occurrenceDate ??
                  _occurrenceAnchorDate(itemId, state.selectedDay),
            )?.status ??
            RoutineStatus.planned,
      );
    }

    final anchorKey = routineLocalDateKey(anchor);
    final targetKey = routineLocalDateKey(targetDate);

    final String effectiveAction;
    if (action == 'makeTiny') {
      effectiveAction = 'makeTiny';
    } else if (targetKey == anchorKey) {
      effectiveAction = 'move';
    } else {
      effectiveAction = 'reschedule';
    }

    return await _writeOccurrence(
      itemId,
      status: RoutineStatus.moved,
      actionSource: 'routine',
      action: effectiveAction,
      occurrenceDate: anchor,
      movedToDateKey: targetKey,
      movedStartMinute: startMinute,
      movedEndMinute: endMinute,
      displayTitleOverride: displayTitleOverride,
    );
  }

  Future<RoutineWriteResult> moveItem({
    required String itemId,
    required DateTime date,
    required int startMinute,
    required int durationMinutes,
    DateTime? occurrenceDate,
  }) async {
    return _executeCanonicalMove(
      itemId: itemId,
      targetDate: date,
      startMinute: startMinute,
      durationMinutes: durationMinutes,
      occurrenceDate: occurrenceDate,
      action: 'move',
    );
  }

  Future<RoutineWriteResult> moveToTomorrow(
    RoutineItem item, {
    DateTime? occurrenceDate,
    DateTime? displayDate,
    int? startMinute,
    int? durationMinutes,
  }) async {
    final baseDate = displayDate ?? occurrenceDate ?? state.selectedDay;
    final tomorrow = TimelineUtils.dateOnly(
      baseDate,
    ).add(const Duration(days: 1));
    return await _executeCanonicalMove(
      itemId: item.id,
      targetDate: tomorrow,
      startMinute: startMinute ?? item.startMinute,
      durationMinutes: durationMinutes ?? item.durationMinutes,
      occurrenceDate: occurrenceDate,
      action: 'reschedule',
    );
  }

  Future<RoutineWriteResult> makeTinyVersion(
    RoutineItem item, {
    DateTime? occurrenceDate,
    DateTime? displayDate,
    int? startMinute,
    int? durationMinutes,
    RoutineActionContext? actionContext,
  }) async {
    final effectiveOccDate = actionContext?.occurrenceDate ?? occurrenceDate;
    final effectiveDispDate =
        actionContext?.displayDate ??
        displayDate ??
        effectiveOccDate ??
        state.selectedDay;
    final targetItem = actionContext?.item ?? item;
    int seedStart = startMinute ?? targetItem.startMinute;
    int seedDur = durationMinutes ?? targetItem.durationMinutes;
    if (startMinute == null && targetItem.isContinuation) {
      final template = state.items
          .where((i) => i.id == targetItem.id)
          .firstOrNull;
      if (template != null) {
        seedStart = template.startMinute;
        seedDur = template.durationMinutes;
      }
    }
    final tinyDuration = seedDur.clamp(5, 10);

    return await _executeCanonicalMove(
      itemId: targetItem.id,
      targetDate: effectiveDispDate,
      startMinute: seedStart,
      durationMinutes: tinyDuration,
      occurrenceDate: effectiveOccDate,
      action: 'makeTiny',
      displayTitleOverride: targetItem.title.startsWith('[Tiny]')
          ? targetItem.title
          : '[Tiny] ${targetItem.title}',
    );
  }

  int? findWeeklyFreeSlot({
    required RoutineItem item,
    required List<int> repeatDays,
    required DateTime baseDate,
    int? durationMinutes,
  }) {
    if (repeatDays.isEmpty) {
      return findFreeSlot(
        item: item,
        date: baseDate,
        durationMinutes: durationMinutes,
      );
    }
    final duration = durationMinutes ?? item.durationMinutes;
    final snap = state.precisionMode ? 1 : 5;

    final testDates = <DateTime>[];
    for (final dayNum in repeatDays) {
      final normalizedDay = ((dayNum - 1) % 7) + 1;
      var testDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
      while (testDate.weekday != normalizedDay) {
        testDate = testDate.add(const Duration(days: 1));
      }
      testDates.add(testDate);
    }

    final availabilities = testDates
        .map((d) {
          final dayEntries = RoutineOccurrenceProjector.entriesForDay(
            state.items,
            state.occurrences,
            d,
          ).where((c) => c.templateId != item.id).toList(growable: false);
          return RoutineDayAvailability.computeFromEntries(dayEntries);
        })
        .toList(growable: false);

    const windowStart = kRoutinePlanningWindowStartMinute;
    const windowEnd = kRoutinePlanningWindowEndMinute;
    for (
      int minute = windowStart;
      minute + duration <= windowEnd;
      minute += snap
    ) {
      final end = minute + duration;
      final fitsAll = availabilities.every(
        (avail) => avail.isRangeFree(minute, end),
      );
      if (fitsAll) {
        return minute;
      }
    }
    return null;
  }

  int? findFreeSlot({
    required RoutineItem item,
    required DateTime date,
    int? durationMinutes,
    DateTime? occurrenceDate,
  }) {
    final duration = durationMinutes ?? item.durationMinutes;
    final targetOccurrenceDateKey = routineLocalDateKey(occurrenceDate ?? date);
    final dayEntries =
        RoutineOccurrenceProjector.entriesForDay(
              state.items,
              state.occurrences,
              date,
            )
            .where(
              (candidate) =>
                  candidate.templateId != item.id ||
                  candidate.occurrenceDateKey != targetOccurrenceDateKey,
            )
            .toList(growable: false);
    final availability = RoutineDayAvailability.computeFromEntries(dayEntries);
    final snap = state.precisionMode ? 1 : 5;
    return availability.findFirstFreeSlot(
      durationMinutes: duration,
      snapMinutes: snap,
    );
  }

  TrackerType _inferTrackerType(RoutineItem item) {
    final lower = item.title.toLowerCase();
    if (lower.contains('meditat')) return TrackerType.meditation;
    if (lower.contains('workout') || lower.contains('gym')) {
      return TrackerType.workout;
    }
    if (lower.contains('focus')) return TrackerType.focus;
    if (lower.contains('hydrat') || lower.contains('water')) {
      return TrackerType.hydration;
    }
    if (lower.contains('smok')) return TrackerType.smoking;
    if (lower.contains('money') || lower.contains('save')) {
      return TrackerType.money;
    }
    return TrackerType.none;
  }
}

final routineNotifierProvider =
    StateNotifierProvider<RoutineNotifier, RoutineState>((ref) {
      final routineRepository = ref.watch(routineRepositoryProvider);
      final onboardingRepository = ref.watch(onboardingRepositoryProvider);
      final repositoriesShareBackend =
          routineRepository is FirestoreRoutineRepository &&
              onboardingRepository is FirestoreOnboardingRepository ||
          routineRepository is FakeRoutineRepository &&
              onboardingRepository is FakeOnboardingRepository &&
              identical(
                routineRepository.database,
                onboardingRepository.routineDatabase,
              );
      return RoutineNotifier(
        routineRepository,
        ref.watch(routineHistoryRepositoryProvider),
        ref.watch(routineTransactionRepositoryProvider),
        ref,
        repositoriesShareBackend ? onboardingRepository : null,
      );
    });

final selectedDayRoutineItemsProvider = Provider<List<RoutineItem>>((ref) {
  final projection = ref.watch(
    routineNotifierProvider.select(
      (state) => (
        items: state.items,
        occurrences: state.occurrences,
        selectedDay: state.selectedDay,
      ),
    ),
  );
  final day = projection.selectedDay;
  final materialized = RoutineOccurrenceProjector.itemsForDay(
    projection.items,
    projection.occurrences,
    day,
  );

  return materialized
      .map(
        (item) => item.hasConflict || item.conflictMessage != null
            ? item.copyWith(hasConflict: false, clearConflict: true)
            : item,
      )
      .toList(growable: false)
    ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
});

final filteredRoutineItemsProvider = Provider<List<RoutineItem>>((ref) {
  final entries = ref.watch(filteredRoutineEntriesProvider);
  return entries.map((e) => e.item).toList(growable: false);
});

/// Occurrence-aware entries for the selected day, including stable instanceIds.
/// Prefer this over [filteredRoutineItemsProvider] for the live timeline.
final selectedDayRoutineEntriesProvider = Provider<List<RoutineDayEntry>>((
  ref,
) {
  final projection = ref.watch(
    routineNotifierProvider.select(
      (state) => (
        items: state.items,
        occurrences: state.occurrences,
        selectedDay: state.selectedDay,
      ),
    ),
  );
  final day = projection.selectedDay;
  final entries = RoutineOccurrenceProjector.entriesForDay(
    projection.items,
    projection.occurrences,
    day,
  );
  final result =
      entries
          .map(
            (entry) =>
                entry.item.hasConflict || entry.item.conflictMessage != null
                ? RoutineDayEntry(
                    item: entry.item.copyWith(
                      hasConflict: false,
                      clearConflict: true,
                    ),
                    instanceId: entry.instanceId,
                    templateId: entry.templateId,
                    occurrenceDateKey: entry.occurrenceDateKey,
                    displayDateKey: entry.displayDateKey,
                    occurrenceId: entry.occurrenceId,
                    kind: entry.kind,
                  )
                : entry,
          )
          .toList(growable: false)
        ..sort((a, b) => a.item.startMinute.compareTo(b.item.startMinute));
  if (kDebugMode) {
    debugPrint(
      'RoutineTimelineEntries: ${_routineCategoryCounts(result.map((e) => e.item))} '
      'instanceIds=${result.map((e) => e.instanceId).join(',')}',
    );
  }
  return result;
});

/// Filtered occurrence-aware entries for the selected day.
/// Apply primary and category filters, preserving stable instanceIds.
final filteredRoutineEntriesProvider = Provider<List<RoutineDayEntry>>((ref) {
  final entries = ref.watch(selectedDayRoutineEntriesProvider);
  final filterSelection = ref.watch(
    routineNotifierProvider.select((state) => state.filterSelection),
  );
  final effective = filterSelection.normalizedFor(entries);
  final result = RoutineEntryFilter.apply(
    entries,
    view: effective.view,
    status: effective.status,
    category: effective.category,
  );
  if (kDebugMode) {
    debugPrint(
      'RoutineTimelineFiltered: ${_routineCategoryCounts(result.map((e) => e.item))} '
      'instanceIds=${result.map((e) => e.instanceId).join(',')}',
    );
  }
  return result;
});

String _routineCategoryCounts(Iterable<RoutineItem> items) {
  final values = items.toList(growable: false);
  int count(RoutineCategory category) =>
      values.where((item) => item.category == category).length;
  return 'classes=${count(RoutineCategory.classBlock)} '
      'work=${count(RoutineCategory.job)} '
      'eating=${count(RoutineCategory.eating)} '
      'fixed=${count(RoutineCategory.fixed)} '
      'skin=${count(RoutineCategory.skinCare)}';
}

final todayRoutineItemsProvider = Provider<List<RoutineItem>>((ref) {
  final projection = ref.watch(
    routineNotifierProvider.select(
      (state) => (items: state.items, occurrences: state.occurrences),
    ),
  );
  final materialized = RoutineOccurrenceProjector.itemsForDay(
    projection.items,
    projection.occurrences,
    TimelineUtils.dateOnly(DateTime.now()),
  );
  return materialized
      .map(
        (item) => item.hasConflict || item.conflictMessage != null
            ? item.copyWith(hasConflict: false, clearConflict: true)
            : item,
      )
      .toList(growable: false)
    ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
});

final currentRoutineItemProvider = Provider<RoutineItem?>((ref) {
  final now = DateTime.now();
  final minute = now.hour * 60 + now.minute;
  final todayItems = ref.watch(todayRoutineItemsProvider);
  for (final item in todayItems) {
    if (TimelineUtils.isMinuteInsideItem(item, minute) &&
        item.status != RoutineStatus.completed &&
        item.status != RoutineStatus.skipped) {
      return item;
    }
  }
  return null;
});

final nextRoutineItemProvider = Provider<RoutineItem?>((ref) {
  final now = DateTime.now();
  final minute = now.hour * 60 + now.minute;
  final candidates =
      ref
          .watch(todayRoutineItemsProvider)
          .where(
            (item) =>
                item.startMinute >= minute &&
                item.status != RoutineStatus.completed &&
                item.status != RoutineStatus.skipped,
          )
          .toList()
        ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
  return candidates.isEmpty ? null : candidates.first;
});

class RoutineFilters {
  RoutineFilters._();

  static List<RoutineItem> applyCategory(
    List<RoutineItem> items,
    String filter,
  ) {
    if (filter == 'all') return items;
    return items
        .where((item) => RoutineEntryFilter.matchesCategory(item, filter))
        .toList();
  }

  static bool matchesCategory(RoutineItem item, String filter) =>
      RoutineEntryFilter.matchesCategory(item, filter);
}

// ── Generic Settings Providers ──
final aiRoutineSuggestionsEnabledProvider = StateProvider<bool>((ref) => true);
final routineNotificationsEnabledProvider = StateProvider<bool>((ref) => true);
