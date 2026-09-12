import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/tracker_session_link.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/routine_projection_receipt_validator.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';

enum RoutineWriteAction { create, update, delete, moveTemplate, batchCreate }

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
  final Completer<RoutineWriteResult>? completer;

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
  final bool aiRoutineSuggestionsEnabled;
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
    this.aiRoutineSuggestionsEnabled = true,
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
    bool? aiRoutineSuggestionsEnabled,
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
  String? _lastProjectionIntegritySignature;

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

  Future<void>? _inFlightLoad;
  String? _inFlightUid;

  Future<void> loadForOwner(String uid) async {
    if (uid.trim().isEmpty || uid.contains('/')) {
      throw ArgumentError('A valid authenticated Routine owner is required.');
    }
    if (_ownerUid == uid && _inFlightUid == uid && _inFlightLoad != null) {
      await _inFlightLoad;
      return;
    }
    final inFlightCompleter = Completer<void>();
    _inFlightUid = uid;
    _inFlightLoad = inFlightCompleter.future;

    try {
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
        var remoteItems = (results[0] as List<RoutineItem>)
            .map(
              (remote) => remote.hasConflict || remote.conflictMessage != null
                  ? remote.copyWith(hasConflict: false, clearConflict: true)
                  : remote,
            )
            .toList();
        final bundle = results[2];
        if (bundle is OnboardingCompletionBundle) {
          final plan = RoutineOnboardingProjection.build(bundle);
          final receipt = await _repository.fetchProjectionReceipt(
            uid,
            plan.projectionId,
          );
          if (generation != _loadGeneration || _ownerUid != uid) return;
          final validation = const RoutineProjectionReceiptValidator().validate(
            receipt: receipt,
            actualItems: remoteItems,
            ownerUid: uid,
            plan: plan,
          );
          final signature = Object.hash(
            uid,
            plan.fingerprint,
            receipt?.sourceBundleFingerprint,
            Object.hashAll(
              remoteItems.map(
                (item) => Object.hash(
                  item.id,
                  item.onboardingVisualStyleKey,
                  item.notes,
                ),
              ),
            ),
          ).toString();
          if (kDebugMode) {
            debugPrint(
              'RoutineProjectionIntegrity: expected=${plan.items.length} '
              'persisted=${remoteItems.where((item) => item.source == RoutineSource.onboarding).length} '
              'expectedIds=${plan.items.map((item) => item.id).join(',')} '
              'valid=${validation.isValid}',
            );
          }
          if (!validation.isValid &&
              _lastProjectionIntegritySignature != signature) {
            _lastProjectionIntegritySignature = signature;
            final repaired = await _repository.reconcileOnboardingProjection(
              uid,
              plan,
            );
            if (repaired) {
              remoteItems = (await _repository.fetchRoutineItems(uid))
                  .map(
                    (remote) =>
                        remote.hasConflict || remote.conflictMessage != null
                        ? remote.copyWith(
                            hasConflict: false,
                            clearConflict: true,
                          )
                        : remote,
                  )
                  .toList();
            }
            if (generation != _loadGeneration || _ownerUid != uid) return;
          }
        }
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
      } catch (e) {
        if (generation != _loadGeneration || _ownerUid != uid) return;
        state = state.copyWith(
          loading: false,
          error: 'Failed to load routine data. Please try again.',
        );
        rethrow;
      }
    } finally {
      if (_inFlightUid == uid) {
        _inFlightLoad = null;
        _inFlightUid = null;
      }
      if (!inFlightCompleter.isCompleted) {
        inFlightCompleter.complete();
      }
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

  void resetForSignedOut() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _loadGeneration++;
    _eventsGeneration++;
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

  void updateSelectedDay(DateTime day) {
    state = state.copyWith(selectedDay: TimelineUtils.dateOnly(day));
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

  void setCategoryFilter(String filter) =>
      state = state.copyWith(selectedCategoryFilter: filter);
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
    await _initialLoad;
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

    state = state.copyWith(
      pendingItemIds: {...state.pendingItemIds, ownedItem.id},
      items: [...state.items, ownedItem],
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
        return RoutineWriteResult.saved(operationId: operationId);
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
      return RoutineWriteResult.retryRequired(
        message: 'Failed to save routine item.',
        operationId: operationId,
      );
    }
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
      // Re-add to list if missing
      if (!state.items.any((e) => e.id == itemId)) {
        state = state.copyWith(items: [...state.items, intent.attemptedItem!]);
      }
      state = state.copyWith(pendingItemIds: {...state.pendingItemIds, itemId});
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
          failedIntentsByItemId: {
            ...state.failedIntentsByItemId,
            itemId: intent,
          },
          error: 'Failed to save routine item.',
        );
        return RoutineWriteResult.retryRequired(
          operationId: intent.operationId,
          message: 'Failed to save routine item.',
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

  Future<RoutineWriteResult> _writeOccurrence(
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
      existing?.operationKey ?? '',
    ]);
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
    final occurrenceSnapshot = _historySnapshotForItemId(itemId, uid);
    if (occurrenceSnapshot == null) {
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
        eventType: eventType,
      ),
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

    final completer = Completer<RoutineWriteResult>();
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
        return RoutineWriteResult.noOp(operationId: operationId);
      }

      state = state.copyWith(
        queuedOccurrenceIntentsById: {
          ...state.queuedOccurrenceIntentsById,
          id: [...queue, intent],
        },
      );
      return await completer.future;
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
    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setOccurrence: record,
        addEvent: event,
      );
      if (!mounted) return _supersededWriteResult(operationId);
      if (_ownerUid != uid) return _supersededWriteResult(operationId);

      state = state.copyWith(
        failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
          ..remove(id),
      );
      await _processNextQueuedOccurrence(uid, id);
      if (!completer.isCompleted) {
        completer.complete(RoutineWriteResult.saved(operationId: operationId));
      }
      return RoutineWriteResult.saved(operationId: operationId);
    } catch (error) {
      if (!mounted) return _supersededWriteResult(operationId);
      if (_ownerUid != uid) return _supersededWriteResult(operationId);
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
        error: 'Could not update routine. Please try again.',
      );
      await _processNextQueuedOccurrence(uid, id);
      final result = RoutineWriteResult.retryRequired(
        message: 'Could not update routine. Please try again.',
        operationId: operationId,
      );
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      return result;
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

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setOccurrence: intent.attemptedRecord,
        addEvent: intent.event,
      );
      if (!mounted) {
        intent.completer?.complete(_supersededWriteResult(intent.operationId));
        return;
      }
      if (_ownerUid != uid) {
        intent.completer?.complete(_supersededWriteResult(intent.operationId));
        return;
      }

      state = state.copyWith(
        failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
          ..remove(id),
      );
      intent.completer?.complete(
        RoutineWriteResult.saved(operationId: intent.operationId),
      );
      await _processNextQueuedOccurrence(uid, id);
    } catch (error) {
      if (!mounted) {
        intent.completer?.complete(_supersededWriteResult(intent.operationId));
        return;
      }
      if (_ownerUid != uid) {
        intent.completer?.complete(_supersededWriteResult(intent.operationId));
        return;
      }
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
        error: 'Could not update routine. Please try again.',
      );
      intent.completer?.complete(
        RoutineWriteResult.retryRequired(
          message: 'Could not update routine. Please try again.',
          operationId: intent.operationId,
        ),
      );
      await _processNextQueuedOccurrence(uid, id);
    }
  }

  Future<RoutineWriteResult> undoOccurrenceAction(
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
    if (existing == null) {
      return const RoutineWriteResult.noOp(
        message: 'No occurrence action to undo.',
      );
    }
    if (!existing.undoToPlannedAllowed) {
      return RoutineWriteResult.validationFailed(
        const RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.missingData,
          userSafeMessage: 'This action can no longer be undone.',
        ),
      );
    }

    final operationId = _stableOperationId('occurrence_undo', [
      uid,
      itemId,
      dateKey,
      existing.operationKey,
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

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        deleteOccurrenceId: id,
        addEvent: event,
      );
      if (!mounted) return _supersededWriteResult(operationId);
      if (_ownerUid != uid) return _supersededWriteResult(operationId);

      state = state.copyWith(
        pendingOccurrenceIds: state.pendingOccurrenceIds
            .where((e) => e != id)
            .toSet(),
        failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
          ..remove(id),
      );
      return RoutineWriteResult.saved(operationId: operationId);
    } catch (error) {
      if (!mounted) return _supersededWriteResult(operationId);
      if (_ownerUid != uid) return _supersededWriteResult(operationId);
      state = state.copyWith(
        pendingOccurrenceIds: state.pendingOccurrenceIds
            .where((e) => e != id)
            .toSet(),
        occurrences: [...state.occurrences, existing],
        failedOccurrenceIntentsById: {
          ...state.failedOccurrenceIntentsById,
          id: intent,
        },
        error: 'Could not update routine. Please try again.',
      );
      return RoutineWriteResult.retryRequired(
        operationId: operationId,
        message: 'Could not update routine. Please try again.',
      );
    }
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

    if (intent.action == RoutineOccurrenceAction.undo) {
      state = state.copyWith(
        pendingOccurrenceIds: {...state.pendingOccurrenceIds, occurrenceId},
        occurrences: state.occurrences
            .where((e) => e.id != occurrenceId)
            .toList(),
        error: null,
      );

      try {
        await _transactionRepository.commitWrite(
          uid: uid,
          deleteOccurrenceId: occurrenceId,
          addEvent: intent.event,
        );
        if (!mounted) return _supersededWriteResult(intent.operationId);
        if (_ownerUid != uid) return _supersededWriteResult(intent.operationId);

        state = state.copyWith(
          pendingOccurrenceIds: state.pendingOccurrenceIds
              .where((e) => e != occurrenceId)
              .toSet(),
          failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
            ..remove(occurrenceId),
        );
        return RoutineWriteResult.saved(operationId: intent.operationId);
      } catch (error) {
        if (!mounted) return _supersededWriteResult(intent.operationId);
        if (_ownerUid != uid) return _supersededWriteResult(intent.operationId);
        state = state.copyWith(
          pendingOccurrenceIds: state.pendingOccurrenceIds
              .where((e) => e != occurrenceId)
              .toSet(),
          occurrences: [...state.occurrences, intent.previousRecord!],
          failedOccurrenceIntentsById: {
            ...state.failedOccurrenceIntentsById,
            occurrenceId: intent,
          },
          error: 'Could not update routine. Please try again.',
        );
        return RoutineWriteResult.retryRequired(
          operationId: intent.operationId,
          message: 'Could not update routine. Please try again.',
        );
      }
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

    try {
      await _transactionRepository.commitWrite(
        uid: uid,
        setOccurrence: record,
        addEvent: intent.event,
      );
      if (!mounted) return _supersededWriteResult(intent.operationId);
      if (_ownerUid != uid) return _supersededWriteResult(intent.operationId);

      state = state.copyWith(
        pendingOccurrenceIds: state.pendingOccurrenceIds
            .where((e) => e != occurrenceId)
            .toSet(),
        failedOccurrenceIntentsById: {...state.failedOccurrenceIntentsById}
          ..remove(occurrenceId),
      );
      return RoutineWriteResult.saved(operationId: intent.operationId);
    } catch (error) {
      if (!mounted) return _supersededWriteResult(intent.operationId);
      if (_ownerUid != uid) return _supersededWriteResult(intent.operationId);
      state = state.copyWith(
        pendingOccurrenceIds: state.pendingOccurrenceIds
            .where((e) => e != occurrenceId)
            .toSet(),
        occurrences:
            state.occurrences.where((e) => e.id != occurrenceId).toList()
              ..addAll(
                intent.previousRecord != null ? [intent.previousRecord!] : [],
              ),
        failedOccurrenceIntentsById: {
          ...state.failedOccurrenceIntentsById,
          occurrenceId: intent,
        },
        error: 'Could not update routine. Please try again.',
      );
      return RoutineWriteResult.retryRequired(
        operationId: intent.operationId,
        message: 'Could not update routine. Please try again.',
      );
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
        return await startTrackerTask(item);
      }
    }
    return await _writeOccurrence(
      itemId,
      status: RoutineStatus.active,
      source: 'routine',
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
        return await completeTrackerSession(itemId);
      }
      if (item.blockType == RoutineBlockType.moneyTask) {
        return await alreadySaved(itemId);
      }
      if (item.blockType == RoutineBlockType.checkIn &&
          item.category == RoutineCategory.badHabit) {
        return await checkIn(itemId, 'Avoided', occurrenceDate: occurrenceDate);
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
      source: 'routine',
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
      source: 'routine',
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
      source: 'routine',
      action: 'complete',
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> markSkipped(
    String itemId, {
    DateTime? occurrenceDate,
  }) async {
    try {
      final item = state.items.firstWhere((e) => e.id == itemId);
      if (item.blockType == RoutineBlockType.moneyTask) {
        if (_ref.read(fakeDataAllowedProvider)) {
          _ref
              .read(mockTrackerProvider.notifier)
              .skipMoneyToday(reason: 'Skipped from routine');
        }
      }
    } catch (_) {}

    return await _writeOccurrence(
      itemId,
      status: RoutineStatus.skipped,
      source: 'routine',
      action: 'skip',
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> markMissed(String itemId) async {
    return await _writeOccurrence(
      itemId,
      status: RoutineStatus.missed,
      source: 'routine',
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
      source: 'checkIn',
      action: 'checkIn',
      note: 'Check-in: $response',
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> alreadySaved(
    String itemId, {
    double? amount,
  }) async {
    if (_ref.read(fakeDataAllowedProvider)) {
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
    }
    return await _writeOccurrence(
      itemId,
      status: RoutineStatus.completed,
      source: 'money',
      action: 'complete',
    );
  }

  Future<RoutineWriteResult> startTrackerTask(RoutineItem item) async {
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
    return await _writeOccurrence(
      item.id,
      status: RoutineStatus.inTracker,
      source: 'tracker',
      action: 'startTracker',
    );
  }

  Future<RoutineWriteResult> completeTrackerSession(
    String routineTaskId,
  ) async {
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
    final result = await _writeOccurrence(
      routineTaskId,
      status: RoutineStatus.completed,
      source: 'tracker',
      action: 'complete',
    );
    if (result.closesUserFlow &&
        state.activeTrackerLaunchIntent?.routineTaskId == routineTaskId) {
      state = state.copyWith(clearTrackerIntent: true);
    }
    return result;
  }

  Future<RoutineWriteResult> moveItem({
    required String itemId,
    required DateTime date,
    required int startMinute,
    required int durationMinutes,
    DateTime? occurrenceDate,
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
    if (!validation.isValid) {
      return RoutineWriteResult.validationFailed(validation);
    }

    final anchor =
        occurrenceDate ?? _occurrenceAnchorDate(itemId, state.selectedDay);
    if (routineLocalDateKey(date) == routineLocalDateKey(anchor)) {
      return await _writeOccurrence(
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
      return await _writeOccurrence(
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
  }

  Future<RoutineWriteResult> moveToTomorrow(
    RoutineItem item, {
    DateTime? occurrenceDate,
  }) async {
    return await moveItem(
      itemId: item.id,
      date: TimelineUtils.dateOnly(DateTime.now()).add(const Duration(days: 1)),
      startMinute: item.startMinute,
      durationMinutes: item.durationMinutes,
      occurrenceDate: occurrenceDate,
    );
  }

  Future<RoutineWriteResult> makeTinyVersion(
    RoutineItem item, {
    DateTime? occurrenceDate,
  }) async {
    final tinyDuration = item.durationMinutes.clamp(5, 10);
    return await _writeOccurrence(
      item.id,
      status: RoutineStatus.moved,
      source: 'routine',
      action: 'makeTiny',
      occurrenceDate: occurrenceDate,
      movedToDateKey: routineLocalDateKey(occurrenceDate ?? state.selectedDay),
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
    DateTime? occurrenceDate,
  }) {
    final duration = durationMinutes ?? item.durationMinutes;
    final targetOccurrenceDateKey = routineLocalDateKey(occurrenceDate ?? date);
    final dayItems =
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
            .map((candidate) => candidate.item)
            .toList(growable: false);
    final snap = state.precisionMode ? 1 : 5;
    for (int start = 6 * 60; start + duration <= 23 * 60; start += snap) {
      final end = start + duration;
      final overlapsAny = dayItems.any((existing) {
        final existingStart = existing.startMinute;
        final existingEnd = TimelineUtils.normalizedEndMinute(existing);
        return existingStart < end && existingEnd > start;
      });
      if (!overlapsAny) return start;
    }
    return null;
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
  final items = ref.watch(selectedDayRoutineItemsProvider);
  final filters = ref.watch(
    routineNotifierProvider.select(
      (state) => (
        primary: state.selectedPrimaryFilter,
        category: state.selectedCategoryFilter,
      ),
    ),
  );
  final primary = TimelineUtils.filterItems(items, filters.primary);
  return RoutineFilters.applyCategory(primary, filters.category);
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
  final filters = ref.watch(
    routineNotifierProvider.select(
      (state) => (
        primary: state.selectedPrimaryFilter,
        category: state.selectedCategoryFilter,
      ),
    ),
  );
  final primaryFiltered = entries
      .where((entry) {
        final filtered = TimelineUtils.filterItems([
          entry.item,
        ], filters.primary);
        return filtered.isNotEmpty;
      })
      .toList(growable: false);
  final result = filters.category == 'all'
      ? primaryFiltered
      : primaryFiltered
            .where(
              (entry) =>
                  RoutineFilters._matchesCategory(entry.item, filters.category),
            )
            .toList(growable: false);
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
