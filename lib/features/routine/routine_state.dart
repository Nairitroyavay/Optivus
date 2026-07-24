import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/tracker_session_link.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:uuid/uuid.dart';
import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/features/routine/services/routine_conflict_engine.dart';
import 'package:optivus/features/routine/domain/routine_conflict.dart';

enum RoutineWriteAction { create, update, delete, moveTemplate }

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

class RoutineOccurrenceWriteIntent {
  final RoutineOccurrenceAction action;
  final String ownerUid;
  final String occurrenceId;
  final String operationId;
  final RoutineOccurrenceRecord attemptedRecord;
  final RoutineOccurrenceRecord? previousRecord;
  final DateTime createdAt;
  final RoutineEventRecord? event;
  final Completer<void>? completer;

  const RoutineOccurrenceWriteIntent({
    required this.action,
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
  final List<RoutineItem> attemptedItems;
  final List<RoutineEventRecord> events;
  final DateTime createdAt;

  const RoutineBatchWriteIntent({
    required this.ownerUid,
    required this.operationId,
    required this.attemptedItems,
    required this.events,
    required this.createdAt,
  });
}

class RoutineState {
  final List<RoutineItem> items;
  final List<RoutineOccurrenceRecord> occurrences;
  final List<RoutineEventRecord> events;
  final List<RoutineCorruptEvent> corruptEvents;
  final DateTime selectedDay;
  final String selectedPrimaryFilter;
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
  final List<RoutineConflict> conflicts;
  final bool aiRoutineSuggestionsEnabled;
  final bool conflictResolverEnabled;
  final bool routineNotificationsEnabled;
  final bool refreshing;
  final Set<String> pendingItemIds;
  final Set<String> pendingOccurrenceIds;
  final Map<String, RoutineWriteIntent> failedIntentsByItemId;
  final Map<String, RoutineOccurrenceWriteIntent> failedOccurrenceIntentsById;
  final Map<String, List<RoutineOccurrenceWriteIntent>>
  queuedOccurrenceIntentsById;
  final Map<String, RoutineBatchWriteIntent> failedBatchIntentsByOperationId;

  const RoutineState({
    required this.items,
    this.occurrences = const [],
    this.events = const [],
    this.corruptEvents = const [],
    required this.selectedDay,
    this.selectedPrimaryFilter = 'all',
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
    this.conflicts = const [],
    this.aiRoutineSuggestionsEnabled = true,
    this.conflictResolverEnabled = true,
    this.routineNotificationsEnabled = false,
    this.refreshing = false,
    this.pendingItemIds = const {},
    this.pendingOccurrenceIds = const {},
    this.failedIntentsByItemId = const {},
    this.failedOccurrenceIntentsById = const {},
    this.queuedOccurrenceIntentsById = const {},
    this.failedBatchIntentsByOperationId = const {},
  });

  RoutineState copyWith({
    List<RoutineItem>? items,
    List<RoutineOccurrenceRecord>? occurrences,
    List<RoutineEventRecord>? events,
    List<RoutineCorruptEvent>? corruptEvents,
    DateTime? selectedDay,
    String? selectedPrimaryFilter,
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
    List<RoutineConflict>? conflicts,
    bool? aiRoutineSuggestionsEnabled,
    bool? conflictResolverEnabled,
    bool? routineNotificationsEnabled,
    bool? refreshing,
    Set<String>? pendingItemIds,
    Set<String>? pendingOccurrenceIds,
    Map<String, RoutineWriteIntent>? failedIntentsByItemId,
    Map<String, RoutineOccurrenceWriteIntent>? failedOccurrenceIntentsById,
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
      conflicts: conflicts ?? this.conflicts,
      aiRoutineSuggestionsEnabled:
          aiRoutineSuggestionsEnabled ?? this.aiRoutineSuggestionsEnabled,
      conflictResolverEnabled:
          conflictResolverEnabled ?? this.conflictResolverEnabled,
      routineNotificationsEnabled:
          routineNotificationsEnabled ?? this.routineNotificationsEnabled,
      refreshing: refreshing ?? this.refreshing,
      pendingItemIds: pendingItemIds ?? this.pendingItemIds,
      pendingOccurrenceIds: pendingOccurrenceIds ?? this.pendingOccurrenceIds,
      failedIntentsByItemId:
          failedIntentsByItemId ?? this.failedIntentsByItemId,
      failedOccurrenceIntentsById:
          failedOccurrenceIntentsById ?? this.failedOccurrenceIntentsById,
      queuedOccurrenceIntentsById:
          queuedOccurrenceIntentsById ?? this.queuedOccurrenceIntentsById,
      failedBatchIntentsByOperationId:
          failedBatchIntentsByOperationId ??
          this.failedBatchIntentsByOperationId,
    );
  }
}

/// Primary filter options with labels and emojis.
class RoutineFilterOption {
  final String key;
  final String label;
  final String emoji;

  const RoutineFilterOption(this.key, this.label, this.emoji);
}

const List<RoutineFilterOption> primaryFilters = [
  RoutineFilterOption('all', 'All', 'All'),
  RoutineFilterOption('base_timeline', 'Base Timeline', 'Base'),
  RoutineFilterOption('flexible_tasks', 'Flexible Tasks', 'Flex'),
  RoutineFilterOption('tracker_tasks', 'Tracker Tasks', 'Track'),
  RoutineFilterOption('check_ins', 'Check-ins', 'Check'),
  RoutineFilterOption('conflicts', 'Conflicts', 'Warn'),
  RoutineFilterOption('completed', 'Completed', 'Done'),
  RoutineFilterOption('missed', 'Missed', 'Miss'),
];

const List<RoutineFilterOption> categoryFilters = [
  RoutineFilterOption('all', 'All Categories', 'All'),
  RoutineFilterOption('classes', 'Classes', 'Class'),
  RoutineFilterOption('job', 'Job / Work', 'Work'),
  RoutineFilterOption('eating', 'Eating', 'Food'),
  RoutineFilterOption('fixed', 'Fixed', 'Fixed'),
  RoutineFilterOption('skin_care', 'Skin Care', 'Skin'),
  RoutineFilterOption('good_habits', 'Good Habits', 'Good'),
  RoutineFilterOption('bad_habits', 'Bad Habits', 'Bad'),
  RoutineFilterOption('money', 'Money System', 'Money'),
  RoutineFilterOption('meditation', 'Meditation', 'Mind'),
  RoutineFilterOption('hydration', 'Hydration', 'Water'),
  RoutineFilterOption('screen_time', 'Screen Time', 'Screen'),
];

class TrackerLaunchIntent {
  final TrackerType trackerType;
  final String routineTaskId;
  final String sessionId;
  final DateTime startedAt;

  const TrackerLaunchIntent({
    required this.trackerType,
    required this.routineTaskId,
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
        if (existing.routineTaskId == link.routineTaskId) link else existing,
      if (!state.any(
        (existing) => existing.routineTaskId == link.routineTaskId,
      ))
        link,
    ];
  }

  void clearForRoutine(String routineTaskId) {
    state = state
        .where((link) => link.routineTaskId != routineTaskId)
        .toList(growable: false);
  }

  void reset() => state = const [];
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
  Future<void> _initialLoad = Future<void>.value();
  String? _ownerUid;
  int _loadGeneration = 0;
  StreamSubscription<List<RoutineEventRecord>>? _eventsSubscription;

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

  RoutineNotifier(
    this._repository,
    this._historyRepository,
    this._transactionRepository,
    this._ref,
  ) : super(
        RoutineState(
          items: [],
          selectedDay: TimelineUtils.dateOnly(DateTime.now()),
        ),
      ) {
    if (_ref.read(optivusBackendModeProvider) == OptivusBackendMode.fake) {
      final initialUid = _ref.read(mockUserProfileProvider).uid.trim();
      if (initialUid.isNotEmpty) {
        _initialLoad = loadForOwner(initialUid);
      } else {
        _ownerUid = 'local-development-user';
      }
    }
  }

  Future<void> loadForOwner(String uid) async {
    if (uid.trim().isEmpty || uid.contains('/')) {
      throw ArgumentError('A valid authenticated Routine owner is required.');
    }
    final isNewOwner = _ownerUid != uid;
    final generation = ++_loadGeneration;
    _ownerUid = uid;
    // Cancel old subscription BEFORE fetch to prevent stale events.
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    if (isNewOwner) {
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
        queuedOccurrenceIntentsById: const {},
        failedBatchIntentsByOperationId: const {},
        items: const [],
        clearError: true,
        clearEventsError: true,
        clearTrackerIntent: true,
        conflicts: const [],
      );
    } else {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final results = await Future.wait<Object>([
        _repository.fetchRoutineItems(uid),
        _historyRepository.fetchHistory(uid),
      ]);
      if (generation != _loadGeneration || _ownerUid != uid) return;
      final remoteItems = results[0] as List<RoutineItem>;
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

      state = state.copyWith(
        items: mergedItems,
        occurrences: mergedOccurrences,
        loading: false,
        eventsLoading: true,
      );
      _recalculateConflicts();
      _eventsSubscription = _transactionRepository
          .watchEvents(uid)
          .listen(
            (feed) {
              if (mounted && _ownerUid == uid) {
                state = state.copyWith(
                  events: feed.validEvents,
                  corruptEvents: feed.corruptEvents,
                  eventsLoading: false,
                  clearEventsError: true,
                );
              }
            },
            onError: (Object error) {
              if (mounted && _ownerUid == uid) {
                state = state.copyWith(
                  eventsLoading: false,
                  eventsError: error.toString(),
                );
              }
            },
          );
    } catch (e) {
      if (generation != _loadGeneration || _ownerUid != uid) return;
      state = state.copyWith(loading: false, error: e.toString());
      rethrow;
    }
  }

  void refreshEvents() {
    final uid = _ownerUid;
    if (uid == null) return;

    _eventsSubscription?.cancel();
    state = state.copyWith(eventsLoading: true, clearEventsError: true);

    _eventsSubscription = _transactionRepository
        .watchEvents(uid)
        .listen(
          (feed) {
            if (mounted && _ownerUid == uid) {
              state = state.copyWith(
                events: feed.validEvents,
                corruptEvents: feed.corruptEvents,
                eventsLoading: false,
                clearEventsError: true,
              );
            }
          },
          onError: (Object error) {
            if (mounted && _ownerUid == uid) {
              state = state.copyWith(
                eventsLoading: false,
                eventsError: error.toString(),
              );
            }
          },
        );
  }

  void resetForSignedOut() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _loadGeneration++;
    _ownerUid = null;
    _ref.read(trackerSessionLinksProvider.notifier).reset();
    state = RoutineState(
      items: const [],
      selectedDay: TimelineUtils.dateOnly(DateTime.now()),
      pendingItemIds: const {},
      pendingOccurrenceIds: const {},
      failedIntentsByItemId: const {},
      failedOccurrenceIntentsById: const {},
      queuedOccurrenceIntentsById: const {},
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

  void _recalculateConflicts() {
    final conflicts = RoutineConflictEngine.detect(
      RoutineOccurrenceProjector.itemsForDay(
        state.items,
        state.occurrences,
        state.selectedDay,
      ),
      state.selectedDay,
      now: DateTime.now(),
    );
    state = state.copyWith(conflicts: conflicts);
  }

  void updateSelectedDay(DateTime day) {
    state = state.copyWith(selectedDay: TimelineUtils.dateOnly(day));
    _recalculateConflicts();
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
  void setPrimaryFilter(String filter) =>
      state = state.copyWith(selectedPrimaryFilter: filter);
  void setCategoryFilter(String filter) =>
      state = state.copyWith(selectedCategoryFilter: filter);
  void toggleAiSuggestions(bool value) =>
      state = state.copyWith(aiRoutineSuggestionsEnabled: value);
  void toggleConflictResolver(bool value) =>
      state = state.copyWith(conflictResolverEnabled: value);
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
      ),
    );
  }

  Future<RoutineValidationResult> addItem(RoutineItem item) async {
    await _initialLoad;
    final validation = _validate(
      item,
      item.date ?? state.selectedDay,
      operation: RoutineValidationOperation.create,
    );
    if (!validation.isValid) return validation;

    final uid = _requireOwnerUid();
    final operationId =
        'create_${item.id}_${DateTime.now().millisecondsSinceEpoch}';
    final ownedItem = item.copyWith(
      userId: uid,
      createdByOperationId: operationId,
      lastMutationOperationId: operationId,
    );

    state = state.copyWith(
      pendingItemIds: {...state.pendingItemIds, ownedItem.id},
      items: [...state.items, ownedItem],
    );
    _recalculateConflicts();

    final event = RoutineEventRecord(
      eventId: const Uuid().v4(),
      ownerUid: uid,
      routineItemId: ownedItem.id,
      eventType: RoutineEventType.created,
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
      if (_ownerUid != uid) return const RoutineValidationResult.valid();

      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => id != ownedItem.id)
            .toSet(),
        items: state.items
            .map((e) => e.id == ownedItem.id ? canonical : e)
            .toList(),
      );
      _recalculateConflicts();
    } catch (error) {
      if (_ownerUid != uid) return const RoutineValidationResult.valid();

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
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != ownedItem.id)
              .toSet(),
          items: state.items
              .map((e) => e.id == ownedItem.id ? recoveredItem! : e)
              .toList(),
        );
      } else {
        final intent = RoutineWriteIntent(
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
        );
      }
      _recalculateConflicts();
    }
    return const RoutineValidationResult.valid();
  }

  Future<RoutineBatchValidationResult> addMissingItems(
    List<RoutineItem> items,
  ) async {
    await _initialLoad;
    final existingIds = state.items.map((item) => item.id).toSet();
    final toAdd = items
        .where(
          (item) => item.id.trim().isNotEmpty && !existingIds.contains(item.id),
        )
        .toList();
    if (toAdd.isEmpty) return const RoutineBatchValidationResult.valid();

    final validation = RoutineValidationService.validateBatch(
      itemsToAdd: toAdd,
      existingTemplates: state.items,
      occurrences: state.occurrences,
      evaluationDate: state.selectedDay,
      explicitNow: DateTime.now(),
    );
    if (!validation.isValid) {
      return validation;
    }

    final uid = _requireOwnerUid();
    final operationId = 'batch_add_${DateTime.now().millisecondsSinceEpoch}';
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
          eventId: const Uuid().v4(),
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
    _recalculateConflicts();

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setItems: ownedItems,
        addEvents: events,
      );
      if (_ownerUid != uid) return const RoutineBatchValidationResult.valid();

      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => !addedIds.contains(id))
            .toSet(),
      );
      _recalculateConflicts();
    } catch (error) {
      if (_ownerUid != uid) return const RoutineBatchValidationResult.valid();

      final intent = RoutineBatchWriteIntent(
        ownerUid: uid,
        operationId: operationId,
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
      _recalculateConflicts();
      return const RoutineBatchValidationResult.valid(); // Zero writes, handled via intent.
    }
    return const RoutineBatchValidationResult.valid();
  }

  Future<RoutineValidationResult> updateItem(RoutineItem item) async {
    final validation = _validate(item, item.date ?? state.selectedDay);
    if (!validation.isValid) return validation;

    final uid = _requireOwnerUid();
    final operationId =
        'update_${item.id}_${DateTime.now().millisecondsSinceEpoch}';
    final previousItem = state.items.cast<RoutineItem?>().firstWhere(
      (e) => e?.id == item.id,
      orElse: () => null,
    );
    if (previousItem == null) {
      return const RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.missingData,
        userSafeMessage: 'Item not found.',
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
    _recalculateConflicts();

    final event = RoutineEventRecord(
      eventId: const Uuid().v4(),
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
      if (_ownerUid != uid) return const RoutineValidationResult.valid();

      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => id != ownedItem.id)
            .toSet(),
        items: state.items
            .map((e) => e.id == ownedItem.id ? canonical : e)
            .toList(),
      );
      _recalculateConflicts();
    } catch (error) {
      if (_ownerUid != uid) return const RoutineValidationResult.valid();

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
      _recalculateConflicts();
    }
    return const RoutineValidationResult.valid();
  }

  Future<void> deleteItem(String itemId) async {
    final uid = _requireOwnerUid();
    final operationId =
        'delete_${itemId}_${DateTime.now().millisecondsSinceEpoch}';
    final previousItem = state.items.cast<RoutineItem?>().firstWhere(
      (e) => e?.id == itemId,
      orElse: () => null,
    );
    if (previousItem == null) return;

    state = state.copyWith(pendingItemIds: {...state.pendingItemIds, itemId});

    final event = RoutineEventRecord(
      eventId: const Uuid().v4(),
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
      if (_ownerUid != uid) return;

      _ref.read(trackerSessionLinksProvider.notifier).clearForRoutine(itemId);
      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => id != itemId)
            .toSet(),
        items: state.items.where((e) => e.id != itemId).toList(),
      );
      _recalculateConflicts();
    } catch (error) {
      if (_ownerUid != uid) return;

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
      _recalculateConflicts();
    }
  }

  Future<void> retryFailedOperation(String itemId) async {
    final intent = state.failedIntentsByItemId[itemId];
    if (intent == null) return;

    final uid = _ownerUid;
    if (uid == null || uid != intent.ownerUid) return;

    dismissFailedOperation(itemId);

    if (intent.action == RoutineWriteAction.create &&
        intent.attemptedItem != null) {
      // Re-add to list if missing
      if (!state.items.any((e) => e.id == itemId)) {
        state = state.copyWith(items: [...state.items, intent.attemptedItem!]);
        _recalculateConflicts();
      }
      state = state.copyWith(pendingItemIds: {...state.pendingItemIds, itemId});
      try {
        await _transactionRepository.commitWrite(
          uid: uid,
          setItem: intent.attemptedItem!,
          addEvent: intent.event,
        );
        final canonical = intent.attemptedItem!;
        if (_ownerUid != uid) return;
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != itemId)
              .toSet(),
          items: state.items
              .map((e) => e.id == itemId ? canonical : e)
              .toList(),
        );
        _recalculateConflicts();
      } catch (error) {
        if (_ownerUid != uid) return;
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != itemId)
              .toSet(),
          failedIntentsByItemId: {
            ...state.failedIntentsByItemId,
            itemId: intent,
          },
        );
      }
    } else if (intent.action == RoutineWriteAction.update &&
        intent.attemptedItem != null) {
      state = state.copyWith(
        pendingItemIds: {...state.pendingItemIds, itemId},
        items: state.items
            .map((e) => e.id == itemId ? intent.attemptedItem! : e)
            .toList(),
      );
      _recalculateConflicts();
      try {
        await _transactionRepository.commitWrite(
          uid: uid,
          setItem: intent.attemptedItem!,
          addEvent: intent.event,
        );
        final canonical = intent.attemptedItem!;
        if (_ownerUid != uid) return;
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != itemId)
              .toSet(),
          items: state.items
              .map((e) => e.id == itemId ? canonical : e)
              .toList(),
        );
        _recalculateConflicts();
      } catch (error) {
        if (_ownerUid != uid) return;
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
        _recalculateConflicts();
      }
    } else if (intent.action == RoutineWriteAction.delete) {
      state = state.copyWith(pendingItemIds: {...state.pendingItemIds, itemId});
      try {
        await _transactionRepository.commitWrite(
          uid: uid,
          deleteItemId: itemId,
          addEvent: intent.event,
        );
        if (_ownerUid != uid) return;
        _ref.read(trackerSessionLinksProvider.notifier).clearForRoutine(itemId);
        state = state.copyWith(
          pendingItemIds: state.pendingItemIds
              .where((id) => id != itemId)
              .toSet(),
          items: state.items.where((e) => e.id != itemId).toList(),
        );
        _recalculateConflicts();
      } catch (error) {
        if (_ownerUid != uid) return;
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
    }
  }

  void discardFailedCreate(String itemId) {
    final intent = state.failedIntentsByItemId[itemId];
    if (intent == null || intent.action != RoutineWriteAction.create) return;

    final uid = _ownerUid;
    if (uid == null || uid != intent.ownerUid) return;

    state = state.copyWith(
      items: state.items.where((e) => e.id != itemId).toList(),
      failedIntentsByItemId: Map.fromEntries(
        state.failedIntentsByItemId.entries.where((e) => e.key != itemId),
      ),
      error: null,
    );
    _recalculateConflicts();
  }

  void dismissFailedOperation(String itemId) {
    state = state.copyWith(
      failedIntentsByItemId: Map.fromEntries(
        state.failedIntentsByItemId.entries.where((e) => e.key != itemId),
      ),
      error: null,
    );
  }

  Future<void> retryFailedBatchOperation(String operationId) async {
    final intent = state.failedBatchIntentsByOperationId[operationId];
    if (intent == null) return;

    final uid = _requireOwnerUid();
    if (uid != intent.ownerUid) return;

    final addedIds = intent.attemptedItems.map((e) => e.id).toSet();

    // Remove from failed map and optimistically apply
    state = state.copyWith(
      failedBatchIntentsByOperationId: {
        ...state.failedBatchIntentsByOperationId,
      }..remove(operationId),
      pendingItemIds: {...state.pendingItemIds, ...addedIds},
      items: [...state.items, ...intent.attemptedItems],
    );
    _recalculateConflicts();

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setItems: intent.attemptedItems,
        addEvents: intent.events,
      );

      if (_ownerUid != uid) return;

      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => !addedIds.contains(id))
            .toSet(),
      );
      _recalculateConflicts();
    } catch (error) {
      if (_ownerUid != uid) return;

      // Retrying must reuse the original intent rather than generating new identities
      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => !addedIds.contains(id))
            .toSet(),
        failedBatchIntentsByOperationId: {
          ...state.failedBatchIntentsByOperationId,
          operationId: intent,
        },
        items: state.items.where((e) => !addedIds.contains(e.id)).toList(),
        error: 'Failed to add batch items.',
      );
      _recalculateConflicts();
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

  Future<RoutineValidationResult> _updateById(
    String itemId,
    RoutineItem Function(RoutineItem) update,
  ) async {
    for (final item in state.items) {
      if (item.id == itemId) {
        return await updateItem(update(item));
      }
    }
    return const RoutineValidationResult.valid();
  }

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

  bool _isSemanticDuplicate(
    RoutineOccurrenceRecord a,
    RoutineOccurrenceRecord b,
  ) {
    if (a.status != b.status) return false;
    if (a.action != b.action) return false;
    if (a.occurrenceDateKey != b.occurrenceDateKey) return false;
    if (a.movedToDateKey != b.movedToDateKey) return false;
    if (a.movedStartMinute != b.movedStartMinute) return false;
    if (a.movedEndMinute != b.movedEndMinute) return false;
    if (a.note != b.note) return false;
    if (a.displayTitleOverride != b.displayTitleOverride) return false;
    if (a.completedSubtaskIndexes.length != b.completedSubtaskIndexes.length) {
      return false;
    }
    for (int i = 0; i < a.completedSubtaskIndexes.length; i++) {
      if (a.completedSubtaskIndexes[i] != b.completedSubtaskIndexes[i]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _writeOccurrence(
    String itemId, {
    required RoutineStatus status,
    required String source,
    required String action,
    DateTime? occurrenceDate,
    String? movedToDateKey,
    int? movedStartMinute,
    int? movedEndMinute,
    List<int>? completedSubtaskIndexes,
    String? note,
    String? displayTitleOverride,
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

    final operationId = const Uuid().v4();
    final occAction = RoutineOccurrenceAction.values.firstWhere(
      (e) => e.name == action,
      orElse: () =>
          throw ArgumentError('Unsupported occurrence action: $action'),
    );

    final record = RoutineOccurrenceRecord(
      id: id,
      ownerUid: uid,
      routineItemId: itemId,
      occurrenceDateKey: dateKey,
      status: status,
      source: source,
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
      undoToPlannedAllowed: existing == null,
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
    final template = state.items.where((i) => i.id == itemId).firstOrNull;
    final occurrenceSnapshot = template == null
        ? <String, dynamic>{}
        : _boundedHistorySnapshot(template, uid);

    final event = RoutineEventRecord(
      eventId: const Uuid().v4(),
      ownerUid: uid,
      routineItemId: itemId,
      occurrenceId: id,
      occurrenceDateKey: dateKey,
      eventType: eventType,
      operationKey: operationId,
      source: source,
      occurredAt: now,
      itemSnapshot: occurrenceSnapshot,
    );

    final completer = Completer<void>();
    final intent = RoutineOccurrenceWriteIntent(
      action: occAction,
      ownerUid: uid,
      occurrenceId: id,
      operationId: operationId,
      attemptedRecord: record,
      previousRecord: existing,
      createdAt: now,
      event: event,
      completer: completer,
    );

    if (state.pendingOccurrenceIds.contains(id)) {
      final queue = state.queuedOccurrenceIntentsById[id] ?? const [];
      final lastIntent = queue.isNotEmpty ? queue.last : null;
      final lastRecord =
          lastIntent?.attemptedRecord ??
          state.occurrences.where((e) => e.id == id).lastOrNull;

      if (lastRecord != null && _isSemanticDuplicate(record, lastRecord)) {
        return;
      }

      state = state.copyWith(
        queuedOccurrenceIntentsById: {
          ...state.queuedOccurrenceIntentsById,
          id: [...queue, intent],
        },
      );
      await completer.future;
      return;
    }

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
    _recalculateConflicts();
    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setOccurrence: record,
        addEvent: event,
      );
      if (!mounted) return;
      if (_ownerUid != uid) return;

      state = state.copyWith(
        failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
          ..remove(id),
      );
      await _processNextQueuedOccurrence(uid, id);
    } catch (error) {
      if (!mounted) return;
      if (_ownerUid != uid) return;
      state = state.copyWith(
        failedOccurrenceIntentsById: {
          ...state.failedOccurrenceIntentsById,
          id: intent,
        },
        occurrences: [
          for (final candidate in state.occurrences)
            if (candidate.id != id) candidate,
          if (intent.previousRecord != null) intent.previousRecord!,
        ],
        error: error.toString(),
      );
      _recalculateConflicts();
      await _processNextQueuedOccurrence(uid, id);
    }

    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _processNextQueuedOccurrence(String uid, String id) async {
    final queue = state.queuedOccurrenceIntentsById[id] ?? const [];
    if (queue.isEmpty) {
      state = state.copyWith(
        pendingOccurrenceIds: state.pendingOccurrenceIds
            .where((e) => e != id)
            .toSet(),
      );
      return;
    }

    final intent = queue.first;
    final remainingQueue = queue.sublist(1);

    state = state.copyWith(
      queuedOccurrenceIntentsById: {
        ...state.queuedOccurrenceIntentsById,
        id: remainingQueue,
      },
      occurrences: [
        for (final candidate in state.occurrences)
          if (candidate.id != id) candidate,
        intent.attemptedRecord,
      ],
      error: null,
    );
    _recalculateConflicts();

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setOccurrence: intent.attemptedRecord,
        addEvent: intent.event,
      );
      if (!mounted) return;
      if (_ownerUid != uid) return;

      state = state.copyWith(
        failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
          ..remove(id),
      );
      intent.completer?.complete();
      await _processNextQueuedOccurrence(uid, id);
    } catch (error) {
      if (!mounted) return;
      if (_ownerUid != uid) return;
      state = state.copyWith(
        failedOccurrenceIntentsById: {
          ...state.failedOccurrenceIntentsById,
          id: intent,
        },
        occurrences: [
          for (final candidate in state.occurrences)
            if (candidate.id != id) candidate,
          if (intent.previousRecord != null) intent.previousRecord!,
        ],
        error: error.toString(),
      );
      _recalculateConflicts();
      intent.completer?.complete();
      await _processNextQueuedOccurrence(uid, id);
    }
  }

  Future<void> undoOccurrenceAction(
    String itemId, [
    DateTime? occurrenceDate,
  ]) async {
    final uid = _requireOwnerUid();
    final date =
        occurrenceDate ?? _occurrenceAnchorDate(itemId, state.selectedDay);
    final dateKey = routineLocalDateKey(date);
    final id = stableRoutineOccurrenceId(
      ownerUid: uid,
      routineItemId: itemId,
      occurrenceDateKey: dateKey,
    );

    final existing = _occurrenceFor(itemId, date);
    if (existing == null) return;
    if (!existing.undoToPlannedAllowed) return;

    final operationId = const Uuid().v4();
    final event = RoutineEventRecord(
      eventId: const Uuid().v4(),
      ownerUid: uid,
      routineItemId: itemId,
      occurrenceId: id,
      occurrenceDateKey: dateKey,
      eventType: RoutineEventType.undone,
      operationKey: operationId,
      source: 'app',
      occurredAt: DateTime.now().toUtc(),
    );

    final intent = RoutineOccurrenceWriteIntent(
      action: RoutineOccurrenceAction.undo,
      ownerUid: uid,
      occurrenceId: id,
      operationId: operationId,
      attemptedRecord: existing, // attempted to revert
      previousRecord: existing,
      createdAt: DateTime.now().toUtc(),
      event: event,
    );

    state = state.copyWith(
      pendingOccurrenceIds: {...state.pendingOccurrenceIds, id},
      occurrences: state.occurrences.where((e) => e.id != id).toList(),
      error: null,
    );
    _recalculateConflicts();

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        deleteOccurrenceId: id,
        addEvent: event,
      );
      if (!mounted) return;
      if (_ownerUid != uid) return;

      state = state.copyWith(
        pendingOccurrenceIds: state.pendingOccurrenceIds
            .where((e) => e != id)
            .toSet(),
        failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
          ..remove(id),
      );
    } catch (error) {
      if (!mounted) return;
      if (_ownerUid != uid) return;
      state = state.copyWith(
        pendingOccurrenceIds: state.pendingOccurrenceIds
            .where((e) => e != id)
            .toSet(),
        occurrences: [...state.occurrences, existing],
        failedOccurrenceIntentsById: {
          ...state.failedOccurrenceIntentsById,
          id: intent,
        },
        error: error.toString(),
      );
      _recalculateConflicts();
    }
  }

  Future<void> retryFailedOccurrenceAction(String occurrenceId) async {
    final intent = state.failedOccurrenceIntentsById[occurrenceId];
    if (intent == null) return;

    final uid = _requireOwnerUid();
    if (intent.ownerUid != uid) return;

    if (intent.action == RoutineOccurrenceAction.undo) {
      state = state.copyWith(
        pendingOccurrenceIds: {...state.pendingOccurrenceIds, occurrenceId},
        occurrences: state.occurrences
            .where((e) => e.id != occurrenceId)
            .toList(),
        error: null,
      );
      _recalculateConflicts();

      try {
        await _transactionRepository.commitWrite(
          uid: uid,
          deleteOccurrenceId: occurrenceId,
          addEvent: intent.event,
        );
        if (!mounted) return;
        if (_ownerUid != uid) return;

        state = state.copyWith(
          pendingOccurrenceIds: state.pendingOccurrenceIds
              .where((e) => e != occurrenceId)
              .toSet(),
          failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
            ..remove(occurrenceId),
        );
      } catch (error) {
        if (!mounted) return;
        if (_ownerUid != uid) return;
        state = state.copyWith(
          pendingOccurrenceIds: state.pendingOccurrenceIds
              .where((e) => e != occurrenceId)
              .toSet(),
          occurrences: [...state.occurrences, intent.previousRecord!],
          error: error.toString(),
        );
        _recalculateConflicts();
      }
      return;
    }

    final record = intent.attemptedRecord;

    state = state.copyWith(
      pendingOccurrenceIds: {...state.pendingOccurrenceIds, occurrenceId},
      occurrences: [
        for (final candidate in state.occurrences)
          if (candidate.id != occurrenceId) candidate,
        record,
      ],
      error: null,
    );
    _recalculateConflicts();

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setOccurrence: record,
        addEvent: intent.event,
      );
      if (!mounted) return;
      if (_ownerUid != uid) return;

      state = state.copyWith(
        pendingOccurrenceIds: state.pendingOccurrenceIds
            .where((e) => e != occurrenceId)
            .toSet(),
        failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
          ..remove(occurrenceId),
      );
    } catch (error) {
      if (!mounted) return;
      if (_ownerUid != uid) return;
      state = state.copyWith(
        pendingOccurrenceIds: state.pendingOccurrenceIds
            .where((e) => e != occurrenceId)
            .toSet(),
        occurrences:
            state.occurrences.where((e) => e.id != occurrenceId).toList()
              ..addAll(
                intent.previousRecord != null ? [intent.previousRecord!] : [],
              ),
        error: error.toString(),
      );
      _recalculateConflicts();
    }
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

  Future<void> startFlexibleTask(String itemId) async {
    await _writeOccurrence(
      itemId,
      status: RoutineStatus.active,
      source: 'routine',
      action: 'start',
    );
  }

  Future<void> toggleSubtask(String itemId, int subtaskIndex) async {
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
      return;
    }
    final completed = {
      ...?_occurrenceFor(
        itemId,
        _occurrenceAnchorDate(itemId, state.selectedDay),
      )?.completedSubtaskIndexes,
    };
    if (!completed.add(subtaskIndex)) completed.remove(subtaskIndex);
    await _writeOccurrence(
      itemId,
      status:
          _occurrenceFor(
            itemId,
            _occurrenceAnchorDate(itemId, state.selectedDay),
          )?.status ??
          RoutineStatus.active,
      source: 'routine',
      action: 'toggleSubtask',
      completedSubtaskIndexes: completed.toList()..sort(),
    );
  }

  Future<void> markCompleted(String itemId) async {
    await _writeOccurrence(
      itemId,
      status: RoutineStatus.completed,
      source: 'routine',
      action: 'complete',
    );
  }

  Future<void> markSkipped(String itemId) async {
    try {
      final item = state.items.firstWhere((e) => e.id == itemId);
      if (item.blockType == RoutineBlockType.moneyTask) {
        _ref
            .read(mockTrackerProvider.notifier)
            .skipMoneyToday(reason: 'Skipped from routine');
      }
    } catch (_) {}

    await _writeOccurrence(
      itemId,
      status: RoutineStatus.skipped,
      source: 'routine',
      action: 'skip',
    );
  }

  Future<void> markMissed(String itemId) async {
    await _writeOccurrence(
      itemId,
      status: RoutineStatus.missed,
      source: 'routine',
      action: 'miss',
    );
  }

  Future<void> markFlexible(String itemId) async {
    await _updateById(
      itemId,
      (item) => item.copyWith(
        blockType: RoutineBlockType.flexibleTask,
        hardBlock: false,
        allowedOverlaps: const [],
      ),
    );
  }

  Future<void> checkIn(String itemId, String response) async {
    final normalized = response.toLowerCase();
    final status = normalized == 'relapsed'
        ? RoutineStatus.missed
        : RoutineStatus.completed;
    await _writeOccurrence(
      itemId,
      status: status,
      source: 'checkIn',
      action: 'checkIn',
      note: 'Check-in: $response',
    );
  }

  Future<void> alreadySaved(String itemId, {double? amount}) async {
    final moneyGoal = _ref.read(mockTrackerProvider).moneyGoal;
    _ref
        .read(mockTrackerProvider.notifier)
        .saveMoneyToday(
          amount: amount ?? moneyGoal.dailyTarget,
          method: moneyGoal.defaultMethod,
          source: MoneyEntrySource.routineTask,
          description: 'Routine Money System task',
          routineTaskId: itemId,
        );
    await _writeOccurrence(
      itemId,
      status: RoutineStatus.completed,
      source: 'money',
      action: 'complete',
    );
  }

  Future<void> startTrackerTask(RoutineItem item) async {
    final now = DateTime.now();
    final sessionId = 'tracker-${item.id}-${now.millisecondsSinceEpoch}';
    final trackerType = item.trackerType == TrackerType.none
        ? _inferTrackerType(item)
        : item.trackerType;
    final link = TrackerSessionLink(
      routineTaskId: item.id,
      trackerType: trackerType.name,
      sessionId: sessionId,
      startedAt: now,
      status: 'active',
    );

    _ref.read(trackerSessionLinksProvider.notifier).upsert(link);

    state = state.copyWith(
      activeTrackerLaunchIntent: TrackerLaunchIntent(
        trackerType: trackerType,
        routineTaskId: item.id,
        sessionId: sessionId,
        startedAt: now,
      ),
    );

    _ref.read(appNavigationProvider.notifier).goToTracker();
    await _writeOccurrence(
      item.id,
      status: RoutineStatus.inTracker,
      source: 'tracker',
      action: 'startTracker',
    );
  }

  Future<void> completeTrackerSession(String routineTaskId) async {
    final links = _ref.read(trackerSessionLinksProvider);
    TrackerSessionLink? link;
    for (final candidate in links) {
      if (candidate.routineTaskId == routineTaskId) {
        link = candidate;
        break;
      }
    }
    final now = DateTime.now();
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
    await _writeOccurrence(
      routineTaskId,
      status: RoutineStatus.completed,
      source: 'tracker',
      action: 'complete',
    );
    if (state.activeTrackerLaunchIntent?.routineTaskId == routineTaskId) {
      state = state.copyWith(clearTrackerIntent: true);
    }
  }

  Future<RoutineValidationResult> moveItem({
    required String itemId,
    required DateTime date,
    required int startMinute,
    required int durationMinutes,
  }) async {
    final targetIndex = state.items.indexWhere((e) => e.id == itemId);
    if (targetIndex == -1) {
      return const RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.missingData,
        userSafeMessage: 'Item not found.',
      );
    }
    final item = state.items[targetIndex];

    final endMinute = startMinute + durationMinutes;
    final dummyItem = item.copyWith(
      startMinute: startMinute,
      endMinute: endMinute,
      date: TimelineUtils.dateOnly(date),
      repeatDays: const [],
      clearConflict: true,
    );

    final validation = _validate(
      dummyItem,
      date,
      operation: RoutineValidationOperation.move,
    );
    if (!validation.isValid) return validation;

    final anchor = _occurrenceAnchorDate(itemId, state.selectedDay);
    if (routineLocalDateKey(date) == routineLocalDateKey(anchor)) {
      await _writeOccurrence(
        itemId,
        status: RoutineStatus.moved,
        source: 'routine',
        action: 'move',
        occurrenceDate: anchor,
        movedToDateKey: routineLocalDateKey(anchor),
        movedStartMinute: startMinute,
        movedEndMinute: endMinute,
      );
    } else {
      await _writeOccurrence(
        itemId,
        status: RoutineStatus.moved,
        source: 'routine',
        action: 'reschedule',
        occurrenceDate: anchor, // source date
        movedToDateKey: routineLocalDateKey(date),
        movedStartMinute: startMinute,
        movedEndMinute: endMinute,
      );
    }
    return const RoutineValidationResult.valid();
  }

  Future<void> moveToTomorrow(RoutineItem item) async {
    await moveItem(
      itemId: item.id,
      date: TimelineUtils.dateOnly(DateTime.now()).add(const Duration(days: 1)),
      startMinute: item.startMinute,
      durationMinutes: item.durationMinutes,
    );
  }

  Future<void> makeTinyVersion(RoutineItem item) async {
    final tinyDuration = item.durationMinutes.clamp(5, 10);
    await _writeOccurrence(
      item.id,
      status: RoutineStatus.moved,
      source: 'routine',
      action: 'makeTiny',
      movedToDateKey: routineLocalDateKey(state.selectedDay),
      movedStartMinute: item.startMinute,
      movedEndMinute: (item.startMinute + tinyDuration).clamp(1, 1440),
      displayTitleOverride: item.title.startsWith('[Tiny]')
          ? item.title
          : '[Tiny] ${item.title}',
    );
  }

  int? findFreeSlot({
    required RoutineItem item,
    required DateTime date,
    int? durationMinutes,
  }) {
    final duration = durationMinutes ?? item.durationMinutes;
    final dayItems = RoutineOccurrenceProjector.itemsForDay(
      state.items,
      state.occurrences,
      date,
    ).where((candidate) => candidate.id != item.id).toList(growable: false);
    final snap = state.precisionMode ? 1 : 5;
    for (int start = 6 * 60; start + duration <= 23 * 60; start += snap) {
      final candidate = item.copyWith(
        startMinute: start,
        endMinute: start + duration,
        date: TimelineUtils.dateOnly(date),
        repeatDays: const [],
        clearConflict: true,
      );
      final conflicts = RoutineConflictEngine.detect([
        ...dayItems,
        candidate,
      ], date);
      final blocking = conflicts.any(
        (conflict) =>
            conflict.itemId == candidate.id ||
            conflict.otherItemId == candidate.id,
      );
      if (!blocking) return start;
    }
    return null;
  }

  List<RoutineConflict> previewMove({
    required RoutineItem item,
    required DateTime date,
    required int startMinute,
    required int durationMinutes,
  }) {
    final dayItems = RoutineOccurrenceProjector.itemsForDay(
      state.items,
      state.occurrences,
      date,
    ).where((candidate) => candidate.id != item.id).toList(growable: false);
    final candidate = item.copyWith(
      date: TimelineUtils.dateOnly(date),
      startMinute: startMinute,
      endMinute: startMinute + durationMinutes,
      repeatDays: const [],
      clearConflict: true,
    );
    return RoutineConflictEngine.detect([...dayItems, candidate], date)
        .where(
          (conflict) =>
              conflict.itemId == item.id || conflict.otherItemId == item.id,
        )
        .toList(growable: false);
  }

  Future<RoutineValidationResult> keepConflictPair(
    RoutineConflict conflict,
  ) async {
    // Guard: reject conflicts that don't support Keep Both.
    if (!conflict.canKeepBoth) {
      return const RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.staleConflict,
        userSafeMessage: 'This conflict type does not support Keep Both.',
      );
    }

    // Guard: require two items.
    if (conflict.otherItemId == null) {
      return const RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.staleConflict,
        userSafeMessage: 'Keep Both requires two items.',
      );
    }

    final item1 = state.items.where((e) => e.id == conflict.itemId).firstOrNull;
    if (item1 == null) {
      return const RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.missingData,
        userSafeMessage: 'Item not found.',
      );
    }

    final item2 = state.items
        .where((e) => e.id == conflict.otherItemId)
        .firstOrNull;
    if (item2 == null) {
      return const RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.missingData,
        userSafeMessage: 'The other item no longer exists.',
      );
    }

    // Guard: stale-conflict detection — verify the conflict still exists.
    final currentConflicts = RoutineConflictEngine.detect(
      RoutineOccurrenceProjector.itemsForDay(
        state.items,
        state.occurrences,
        state.selectedDay,
      ),
      state.selectedDay,
    );

    final matchingConflict = currentConflicts
        .where(
          (c) =>
              (c.itemId == conflict.itemId &&
                  c.otherItemId == conflict.otherItemId) ||
              (c.itemId == conflict.otherItemId &&
                  c.otherItemId == conflict.itemId),
        )
        .firstOrNull;

    if (matchingConflict == null) {
      return const RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.staleConflict,
        userSafeMessage: 'This conflict has already been resolved.',
      );
    }

    // Create Fingerprint
    final fingerprint =
        '${item1.startMinute}-${item1.endMinute}_${item2.startMinute}-${item2.endMinute}_${conflict.type.name}';
    final dateKey = routineLocalDateKey(state.selectedDay);

    final allowance = RoutineConflictAllowance(
      canonicalPairId: ([item1.id, item2.id]..sort()).join('_'),
      evaluatedDateKey: dateKey,
      conflictType: conflict.type.name,
      scheduleFingerprint: fingerprint,
    );

    final uid = _requireOwnerUid();
    final operationId = 'keepboth_${conflict.itemId}_${conflict.otherItemId}';

    final ownedItem1 = item1.copyWith(
      userId: uid,
      allowedConflicts: [...item1.allowedConflicts, allowance],
      clearConflict: true,
      lastMutationOperationId: operationId,
    );

    final ownedItem2 = item2.copyWith(
      userId: uid,
      allowedConflicts: [...item2.allowedConflicts, allowance],
      clearConflict: true,
      lastMutationOperationId: operationId,
    );

    final itemsToUpdate = <RoutineItem>[ownedItem1, ownedItem2];
    final eventsToUpdate = <RoutineEventRecord>[
      RoutineEventRecord(
        eventId: const Uuid().v4(),
        ownerUid: uid,
        routineItemId: ownedItem1.id,
        eventType: RoutineEventType.edited,
        operationKey: operationId,
        source: 'app',
        occurredAt: DateTime.now().toUtc(),
        itemSnapshot: _boundedHistorySnapshot(ownedItem1, uid),
      ),
      RoutineEventRecord(
        eventId: const Uuid().v4(),
        ownerUid: uid,
        routineItemId: ownedItem2.id,
        eventType: RoutineEventType.edited,
        operationKey: operationId,
        source: 'app',
        occurredAt: DateTime.now().toUtc(),
        itemSnapshot: _boundedHistorySnapshot(ownedItem2, uid),
      ),
    ];

    final updatedIds = itemsToUpdate.map((e) => e.id).toSet();

    state = state.copyWith(
      pendingItemIds: {...state.pendingItemIds, ...updatedIds},
      items: state.items.map((e) {
        final update = itemsToUpdate.where((u) => u.id == e.id).firstOrNull;
        return update ?? e;
      }).toList(),
    );
    _recalculateConflicts();

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setItems: itemsToUpdate,
        addEvents: eventsToUpdate,
      );
      if (_ownerUid != uid) return const RoutineValidationResult.valid();

      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => !updatedIds.contains(id))
            .toSet(),
      );
      _recalculateConflicts();
      return const RoutineValidationResult.valid();
    } catch (error) {
      if (_ownerUid != uid) return const RoutineValidationResult.valid();
      final intent = RoutineBatchWriteIntent(
        ownerUid: uid,
        operationId: operationId,
        attemptedItems: itemsToUpdate,
        events: eventsToUpdate,
        createdAt: DateTime.now().toUtc(),
      );

      state = state.copyWith(
        pendingItemIds: state.pendingItemIds
            .where((id) => !updatedIds.contains(id))
            .toSet(),
        items: state.items.map((e) {
          if (e.id == item1.id) return item1;
          if (e.id == item2.id) return item2;
          return e;
        }).toList(),
        failedBatchIntentsByOperationId: {
          ...state.failedBatchIntentsByOperationId,
          operationId: intent,
        },
        error: 'Failed to resolve conflict atomically.',
      );
      _recalculateConflicts();
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.staleConflict,
        userSafeMessage:
            'Failed to resolve conflict atomically. You can retry.',
      );
    }
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
      return RoutineNotifier(
        ref.watch(routineRepositoryProvider),
        ref.watch(routineHistoryRepositoryProvider),
        ref.watch(routineTransactionRepositoryProvider),
        ref,
      );
    });

final selectedDayRoutineItemsProvider = Provider<List<RoutineItem>>((ref) {
  final state = ref.watch(routineNotifierProvider);
  final day = state.selectedDay;
  final materialized = RoutineOccurrenceProjector.itemsForDay(
    state.items,
    state.occurrences,
    day,
  );
  final conflicts = state.conflicts;
  final conflictItemIds = conflicts
      .expand((conflict) => [conflict.itemId, conflict.otherItemId])
      .whereType<String>()
      .toSet();

  return materialized
      .map(
        (item) => item.copyWith(
          hasConflict: conflictItemIds.contains(item.id),
          conflictMessage: _firstConflictMessage(item.id, conflicts),
        ),
      )
      .toList(growable: false)
    ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
});

final filteredRoutineItemsProvider = Provider<List<RoutineItem>>((ref) {
  final items = ref.watch(selectedDayRoutineItemsProvider);
  final state = ref.watch(routineNotifierProvider);
  final primary = TimelineUtils.filterItems(items, state.selectedPrimaryFilter);
  return RoutineFilters.applyCategory(primary, state.selectedCategoryFilter);
});

final todayRoutineItemsProvider = Provider<List<RoutineItem>>((ref) {
  final state = ref.watch(routineNotifierProvider);
  return RoutineOccurrenceProjector.itemsForDay(
    state.items,
    state.occurrences,
    TimelineUtils.dateOnly(DateTime.now()),
  );
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

final routineCompletionSummaryProvider = Provider<RoutineCompletionSummary>((
  ref,
) {
  final items = ref.watch(todayRoutineItemsProvider);
  final actionable = items
      .where((item) {
        return item.blockType != RoutineBlockType.hardBlock;
      })
      .toList(growable: false);
  return RoutineCompletionSummary(
    total: actionable.length,
    completed: actionable
        .where(
          (item) => item.isCompleted || item.status == RoutineStatus.completed,
        )
        .length,
    skipped: actionable
        .where((item) => item.status == RoutineStatus.skipped)
        .length,
    missed: actionable
        .where((item) => item.isMissed || item.status == RoutineStatus.missed)
        .length,
  );
});

final routineConflictSummaryProvider = Provider<RoutineConflictSummary>((ref) {
  final conflicts = RoutineConflictEngine.detect(
    ref.watch(todayRoutineItemsProvider),
    TimelineUtils.dateOnly(DateTime.now()),
    now: DateTime.now(),
  );
  return RoutineConflictSummary(
    total: conflicts.length,
    blocking: conflicts.where((conflict) => conflict.blocking).length,
  );
});

String? _firstConflictMessage(String itemId, List<RoutineConflict> conflicts) {
  for (final conflict in conflicts) {
    if (conflict.itemId == itemId || conflict.otherItemId == itemId) {
      return conflict.message;
    }
  }
  return null;
}

class RoutineFilters {
  RoutineFilters._();

  static List<RoutineItem> applyCategory(
    List<RoutineItem> items,
    String filter,
  ) {
    if (filter == 'all') return items;
    return items.where((item) => _matchesCategory(item, filter)).toList();
  }

  static bool _matchesCategory(RoutineItem item, String filter) {
    final title = item.title.toLowerCase();
    return switch (filter) {
      'classes' => item.category == RoutineCategory.classBlock,
      'job' => item.category == RoutineCategory.job,
      'eating' => item.category == RoutineCategory.eating,
      'fixed' => item.category == RoutineCategory.fixed,
      'skin_care' => item.category == RoutineCategory.skinCare,
      'good_habits' =>
        item.category == RoutineCategory.habit ||
            item.category == RoutineCategory.identity,
      'bad_habits' =>
        item.category == RoutineCategory.badHabit ||
            title.contains('smok') ||
            title.contains('alcohol') ||
            title.contains('junk'),
      'money' =>
        item.category == RoutineCategory.finance ||
            item.blockType == RoutineBlockType.moneyTask,
      'meditation' =>
        item.category == RoutineCategory.meditation ||
            item.trackerType == TrackerType.meditation ||
            title.contains('meditat'),
      'hydration' =>
        item.category == RoutineCategory.hydration ||
            item.trackerType == TrackerType.hydration ||
            title.contains('water'),
      'screen_time' => item.category == RoutineCategory.screenTime,
      _ => true,
    };
  }
}

// ── Generic Settings Providers ──
final aiRoutineSuggestionsEnabledProvider = StateProvider<bool>((ref) => true);
final conflictResolverEnabledProvider = StateProvider<bool>((ref) => true);
final routineNotificationsEnabledProvider = StateProvider<bool>((ref) => true);

class RoutineCompletionSummary {
  final int total;
  final int completed;
  final int skipped;
  final int missed;
  const RoutineCompletionSummary({
    required this.total,
    required this.completed,
    required this.skipped,
    required this.missed,
  });
}
