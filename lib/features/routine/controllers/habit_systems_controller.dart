import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/habit_system_operation.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/habit_system_onboarding_projection.dart';
import 'package:optivus/services/habit_system_schedule_reconciler.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/state/app_state.dart';

class HabitSystemsState {
  final List<HabitSystemRecord> systems;
  final bool loading;
  final bool refreshing;
  final bool saving;
  final String? error;
  final Set<String> pendingOperationKeys;
  final Map<String, FailedHabitSystemOperation> failedOperations;

  const HabitSystemsState({
    this.systems = const [],
    this.loading = false,
    this.refreshing = false,
    this.saving = false,
    this.error,
    this.pendingOperationKeys = const {},
    this.failedOperations = const {},
  });

  HabitSystemsState copyWith({
    List<HabitSystemRecord>? systems,
    bool? loading,
    bool? refreshing,
    bool? saving,
    String? error,
    bool clearError = false,
    Set<String>? pendingOperationKeys,
    Map<String, FailedHabitSystemOperation>? failedOperations,
  }) {
    return HabitSystemsState(
      systems: systems ?? this.systems,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
      pendingOperationKeys: pendingOperationKeys ?? this.pendingOperationKeys,
      failedOperations: failedOperations ?? this.failedOperations,
    );
  }

  List<HabitSystemRecord> get activeSystems =>
      systems.where((s) => s.isActive).toList();

  List<HabitSystemRecord> get pausedSystems =>
      systems.where((s) => s.isPaused).toList();

  List<HabitSystemRecord> get archivedSystems =>
      systems.where((s) => s.isArchived).toList();
}

class HabitSystemsNotifier extends StateNotifier<HabitSystemsState> {
  final HabitSystemsRepository _repository;
  final Ref _ref;
  String? _ownerUid;
  int _loadGeneration = 0;

  HabitSystemsNotifier(this._repository, this._ref)
    : super(const HabitSystemsState()) {
    if (_ref.read(optivusBackendModeProvider) == OptivusBackendMode.fake) {
      final initialUid = _ref.read(mockUserProfileProvider).uid.trim();
      if (initialUid.isNotEmpty) {
        loadForOwner(initialUid);
      }
    }
  }

  String _generateOperationId(
    String uid,
    String title,
    RoutineCategory category,
    HabitSystemType systemType,
    String source,
    String? onboardingSourceId,
  ) {
    final normalizedTitle = title.trim().toLowerCase();
    final parts = [
      'habitsys',
      uid,
      normalizedTitle,
      category.name,
      systemType.name,
      source,
      ?onboardingSourceId,
    ];
    final digest = sha256.convert(utf8.encode(parts.join('\u001f')));
    return 'habitsys_${digest.toString().substring(0, 24)}';
  }

  Future<void>? _inFlightLoad;
  String? _inFlightUid;

  Future<void> loadForOwner(String uid) async {
    return loadForOwnerWithFallback(uid);
  }

  Future<void> loadForOwnerWithFallback(
    String uid, {
    OnboardingCompletionBundle? bundle,
    List<RoutineItem>? projectedRoutines,
  }) async {
    if (uid.trim().isEmpty || uid.contains('/')) {
      throw ArgumentError('Valid authenticated owner UID is required.');
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

      if (isNewOwner) {
        state = state.copyWith(
          loading: true,
          systems: const [],
          pendingOperationKeys: const {},
          failedOperations: const {},
          clearError: true,
        );
      } else {
        state = state.copyWith(loading: true, clearError: true);
      }

      try {
        final remoteSystems = await _repository.fetchHabitSystems(uid);
        if (!mounted || generation != _loadGeneration || _ownerUid != uid) {
          return;
        }

        OnboardingCompletionBundle? activeBundle = bundle;
        if (activeBundle == null) {
          try {
            final repo = _ref.read(onboardingRepositoryProvider);
            activeBundle = await repo.fetchCompletionBundle(uid);
          } catch (_) {}
        }

        var routines = projectedRoutines ?? tryReadRoutineItems();
        if (routines.isEmpty) {
          try {
            final routineRepo = _ref.read(routineRepositoryProvider);
            routines = await routineRepo.fetchRoutineItems(uid);
          } catch (_) {}
        }

        if (remoteSystems.isEmpty && activeBundle != null) {
          final projectedSystems = HabitSystemOnboardingProjection.build(
            activeBundle,
            routines,
          );
          state = state.copyWith(systems: projectedSystems, loading: false);
        } else if (activeBundle != null) {
          final projectedSystems = HabitSystemOnboardingProjection.build(
            activeBundle,
            routines,
          );
          final merged = _mergeSystems(remoteSystems, projectedSystems);
          state = state.copyWith(systems: merged, loading: false);
        } else {
          state = state.copyWith(systems: remoteSystems, loading: false);
        }
      } catch (e) {
        if (!mounted || generation != _loadGeneration || _ownerUid != uid) {
          return;
        }

        OnboardingCompletionBundle? activeBundle = bundle;
        if (activeBundle == null) {
          try {
            final repo = _ref.read(onboardingRepositoryProvider);
            activeBundle = await repo.fetchCompletionBundle(uid);
          } catch (_) {}
        }

        if (activeBundle != null) {
          var routines = projectedRoutines ?? tryReadRoutineItems();
          if (routines.isEmpty) {
            try {
              final routineRepo = _ref.read(routineRepositoryProvider);
              routines = await routineRepo.fetchRoutineItems(uid);
            } catch (_) {}
          }
          final projectedSystems = HabitSystemOnboardingProjection.build(
            activeBundle,
            routines,
          );
          state = state.copyWith(systems: projectedSystems, loading: false);
        } else {
          state = state.copyWith(loading: false, error: e.toString());
        }
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

  List<RoutineItem> tryReadRoutineItems() {
    try {
      return _ref.read(routineNotifierProvider).items;
    } catch (_) {
      return const [];
    }
  }

  List<HabitSystemRecord> _mergeSystems(
    List<HabitSystemRecord> remote,
    List<HabitSystemRecord> fallback,
  ) {
    final map = <String, HabitSystemRecord>{};
    for (final s in fallback) {
      map[s.systemId] = s;
    }
    for (final s in remote) {
      map[s.systemId] = s;
    }
    return map.values.toList();
  }

  Future<bool> createSystem({
    required String title,
    String description = '',
    required RoutineCategory category,
    required HabitSystemType systemType,
    List<String> linkedRoutineIds = const [],
    String source = 'user',
    String? onboardingSourceId,
    String? operationIdOverride,
  }) async {
    final uid = _ownerUid;
    if (uid == null || uid.isEmpty) return false;

    if (title.trim().isEmpty) {
      state = state.copyWith(error: 'System title cannot be empty.');
      return false;
    }

    final operationId =
        operationIdOverride ??
        _generateOperationId(
          uid,
          title,
          category,
          systemType,
          source,
          onboardingSourceId,
        );
    if (state.pendingOperationKeys.contains(operationId)) return false;

    state = state.copyWith(
      saving: true,
      clearError: true,
      pendingOperationKeys: {...state.pendingOperationKeys, operationId},
    );

    final now = DateTime.now().toUtc();
    final systemId = operationId;
    final record = HabitSystemRecord(
      systemId: systemId,
      ownerUid: uid,
      title: title.trim(),
      description: description.trim(),
      category: category,
      systemType: systemType,
      status: HabitSystemStatus.active,
      linkedRoutineIds: linkedRoutineIds,
      source: source,
      onboardingSourceId: onboardingSourceId,
      createdAt: now,
      updatedAt: now,
      version: 1,
    );

    final optimisticList = [...state.systems, record];
    state = state.copyWith(systems: optimisticList);

    final result = await _repository.createSystem(
      system: record,
      operationId: operationId,
    );

    if (!mounted || _ownerUid != uid) return false;

    if (result.success) {
      final updatedFailed = Map<String, FailedHabitSystemOperation>.from(
        state.failedOperations,
      );
      updatedFailed.remove(operationId);

      state = state.copyWith(
        saving: false,
        pendingOperationKeys: state.pendingOperationKeys
            .where((id) => id != operationId)
            .toSet(),
        failedOperations: updatedFailed,
      );
      return true;
    } else {
      final failedOp = FailedHabitSystemOperation(
        operationId: operationId,
        type: HabitSystemOperationType.create,
        userMessage: result.error ?? 'Failed to create system',
        failedAt: DateTime.now().toUtc(),
        retryPayload: RetryPayload({
          'title': title,
          'description': description,
          'category': category.name,
          'systemType': systemType.name,
          'linkedRoutineIds': linkedRoutineIds,
          'source': source,
          'onboardingSourceId': onboardingSourceId,
        }),
      );

      final rolledBack = state.systems
          .where((s) => s.systemId != systemId)
          .toList();

      state = state.copyWith(
        systems: rolledBack,
        pendingOperationKeys: state.pendingOperationKeys
            .where((id) => id != operationId)
            .toSet(),
        saving: false,
        error: result.error,
        failedOperations: {...state.failedOperations, operationId: failedOp},
      );
      return false;
    }
  }

  Future<bool> retryOperation(String operationId) async {
    final failedOp = state.failedOperations[operationId];
    if (failedOp == null) return false;

    if (failedOp.type == HabitSystemOperationType.create) {
      final data = failedOp.retryPayload.data;
      return createSystem(
        title: data['title'],
        description: data['description'] ?? '',
        category: RoutineCategory.values.byName(data['category']),
        systemType: HabitSystemType.values.byName(data['systemType']),
        linkedRoutineIds: List<String>.from(data['linkedRoutineIds'] ?? []),
        source: data['source'] ?? 'user',
        onboardingSourceId: data['onboardingSourceId'],
        operationIdOverride: operationId,
      );
    }
    return false; // Other retries can be added here
  }

  Future<bool> updateSystem(HabitSystemRecord updated) async {
    final uid = _ownerUid;
    if (uid == null || uid.isEmpty) return false;
    if (updated.ownerUid != uid) return false;

    final existingIndex = state.systems.indexWhere(
      (s) => s.systemId == updated.systemId,
    );
    if (existingIndex < 0) return false;

    final previous = state.systems[existingIndex];
    final operationId =
        'upd_${updated.systemId}_${DateTime.now().millisecondsSinceEpoch}';

    if (state.pendingOperationKeys.contains(operationId)) return false;

    state = state.copyWith(
      saving: true,
      pendingOperationKeys: {...state.pendingOperationKeys, operationId},
      clearError: true,
    );

    final record = updated.copyWith(
      updatedAt: DateTime.now().toUtc(),
      version: previous.version + 1,
    );

    final newSystems = [...state.systems];
    newSystems[existingIndex] = record;
    state = state.copyWith(systems: newSystems);

    final result = await _repository.updateSystem(
      system: record,
      expectedVersion: previous.version,
      operationId: operationId,
    );

    if (!mounted || _ownerUid != uid) return false;

    if (result.success) {
      state = state.copyWith(
        saving: false,
        pendingOperationKeys: state.pendingOperationKeys
            .where((id) => id != operationId)
            .toSet(),
      );
      _reconcileScheduleForSystem(record);
      return true;
    } else {
      final rolledBack = [...state.systems];
      rolledBack[existingIndex] = previous;
      state = state.copyWith(
        systems: rolledBack,
        pendingOperationKeys: state.pendingOperationKeys
            .where((id) => id != operationId)
            .toSet(),
        saving: false,
        error: result.error,
      );
      return false;
    }
  }

  Future<bool> pauseSystem(String systemId) async {
    final system = state.systems
        .where((s) => s.systemId == systemId)
        .firstOrNull;
    if (system == null) return false;
    final updated = system.copyWith(status: HabitSystemStatus.paused);
    final success = await updateSystem(updated);
    if (success) {
      _reconcileScheduleForSystem(updated);
    }
    return success;
  }

  Future<bool> resumeSystem(String systemId) async {
    final system = state.systems
        .where((s) => s.systemId == systemId)
        .firstOrNull;
    if (system == null) return false;
    final updated = system.copyWith(status: HabitSystemStatus.active);
    final success = await updateSystem(updated);
    if (success) {
      _reconcileScheduleForSystem(updated);
    }
    return success;
  }

  Future<bool> archiveSystem(String systemId) async {
    final uid = _ownerUid;
    if (uid == null) return false;

    final system = state.systems
        .where((s) => s.systemId == systemId)
        .firstOrNull;
    if (system == null) return false;

    final operationId =
        'arch_${systemId}_${DateTime.now().millisecondsSinceEpoch}';

    state = state.copyWith(
      saving: true,
      pendingOperationKeys: {...state.pendingOperationKeys, operationId},
      clearError: true,
    );

    final result = await _repository.archiveSystem(
      uid,
      systemId,
      system.version,
      operationId,
    );

    if (!mounted || _ownerUid != uid) return false;

    if (result.success) {
      final newSystems = [...state.systems];
      final index = newSystems.indexWhere((s) => s.systemId == systemId);
      if (index >= 0) newSystems[index] = result.system!;

      state = state.copyWith(
        saving: false,
        systems: newSystems,
        pendingOperationKeys: state.pendingOperationKeys
            .where((id) => id != operationId)
            .toSet(),
      );
      _reconcileScheduleForSystem(result.system!);
      return true;
    } else {
      state = state.copyWith(
        saving: false,
        error: result.error,
        pendingOperationKeys: state.pendingOperationKeys
            .where((id) => id != operationId)
            .toSet(),
      );
      return false;
    }
  }

  Future<bool> restoreSystem(String systemId) async {
    final uid = _ownerUid;
    if (uid == null) return false;

    final system = state.systems
        .where((s) => s.systemId == systemId)
        .firstOrNull;
    if (system == null) return false;

    final operationId =
        'rest_${systemId}_${DateTime.now().millisecondsSinceEpoch}';

    state = state.copyWith(
      saving: true,
      pendingOperationKeys: {...state.pendingOperationKeys, operationId},
      clearError: true,
    );

    final result = await _repository.restoreSystem(
      uid,
      systemId,
      system.version,
      operationId,
    );

    if (!mounted || _ownerUid != uid) return false;

    if (result.success) {
      final newSystems = [...state.systems];
      final index = newSystems.indexWhere((s) => s.systemId == systemId);
      if (index >= 0) newSystems[index] = result.system!;

      state = state.copyWith(
        saving: false,
        systems: newSystems,
        pendingOperationKeys: state.pendingOperationKeys
            .where((id) => id != operationId)
            .toSet(),
      );
      _reconcileScheduleForSystem(result.system!);
      return true;
    } else {
      state = state.copyWith(
        saving: false,
        error: result.error,
        pendingOperationKeys: state.pendingOperationKeys
            .where((id) => id != operationId)
            .toSet(),
      );
      return false;
    }
  }

  void _reconcileScheduleForSystem(
    HabitSystemRecord system, {
    List<int>? repeatDays,
  }) {
    try {
      final routines = tryReadRoutineItems();
      if (routines.isEmpty) return;

      const reconciler = HabitSystemScheduleReconciler();
      final result = reconciler.reconcile(
        system: system,
        routines: routines,
        repeatDays: repeatDays,
      );

      if (result.system.linkedRoutineIds.length !=
          system.linkedRoutineIds.length) {
        final index = state.systems.indexWhere(
          (s) => s.systemId == system.systemId,
        );
        if (index >= 0) {
          final newSystems = [...state.systems];
          newSystems[index] = result.system;
          state = state.copyWith(systems: newSystems);
        }
      }

      try {
        final routineNotifier = _ref.read(routineNotifierProvider.notifier);
        for (final item in result.routines) {
          routineNotifier.updateItem(item);
        }
      } catch (_) {}
    } catch (_) {}
  }

  void reconcileWithRoutines(List<RoutineItem> routines) {
    final existingIds = routines.map((r) => r.id).toSet();
    const reconciler = HabitSystemScheduleReconciler();
    final updatedSystems = <HabitSystemRecord>[];
    bool changed = false;

    for (final sys in state.systems) {
      final pruned = reconciler.pruneOrphanedRoutineIds(sys, existingIds);
      if (pruned != sys) changed = true;
      updatedSystems.add(pruned);
    }

    if (changed) {
      state = state.copyWith(systems: updatedSystems);
    }
  }

  Future<bool> updateScheduleFrequency(
    String systemId,
    List<int> repeatDays,
  ) async {
    final system = state.systems
        .where((s) => s.systemId == systemId)
        .firstOrNull;
    if (system == null) return false;
    final success = await updateSystem(system);
    if (success) {
      _reconcileScheduleForSystem(system, repeatDays: repeatDays);
    }
    return success;
  }

  Future<bool> linkRoutine(String systemId, String routineId) async {
    final system = state.systems
        .where((s) => s.systemId == systemId)
        .firstOrNull;
    if (system == null) return false;
    if (system.linkedRoutineIds.contains(routineId)) return true;
    final updatedList = [...system.linkedRoutineIds, routineId];
    return updateSystem(system.copyWith(linkedRoutineIds: updatedList));
  }

  Future<bool> unlinkRoutine(String systemId, String routineId) async {
    final system = state.systems
        .where((s) => s.systemId == systemId)
        .firstOrNull;
    if (system == null) return false;
    if (!system.linkedRoutineIds.contains(routineId)) return true;
    final updatedList = system.linkedRoutineIds
        .where((id) => id != routineId)
        .toList();
    return updateSystem(system.copyWith(linkedRoutineIds: updatedList));
  }

  Future<bool> deleteSystem(String systemId) async {
    final uid = _ownerUid;
    if (uid == null || uid.isEmpty) return false;

    final existingIndex = state.systems.indexWhere(
      (s) => s.systemId == systemId,
    );
    if (existingIndex < 0) return false;

    final previous = state.systems[existingIndex];
    final operationId =
        'del_${systemId}_${DateTime.now().millisecondsSinceEpoch}';

    state = state.copyWith(
      saving: true,
      pendingOperationKeys: {...state.pendingOperationKeys, operationId},
      systems: state.systems.where((s) => s.systemId != systemId).toList(),
      clearError: true,
    );

    try {
      await _repository.deleteHabitSystem(uid, systemId);
      if (_ownerUid != uid) return false;

      state = state.copyWith(
        saving: false,
        pendingOperationKeys: state.pendingOperationKeys
            .where((id) => id != operationId)
            .toSet(),
      );
      return true;
    } catch (e) {
      if (_ownerUid != uid) return false;
      state = state.copyWith(
        systems: [...state.systems, previous],
        pendingOperationKeys: state.pendingOperationKeys
            .where((id) => id != operationId)
            .toSet(),
        saving: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void resetForSignedOut() {
    _loadGeneration++;
    _ownerUid = null;
    state = const HabitSystemsState();
  }
}

final habitSystemsNotifierProvider =
    StateNotifierProvider<HabitSystemsNotifier, HabitSystemsState>((ref) {
      final repo = ref.watch(habitSystemsRepositoryProvider);
      return HabitSystemsNotifier(repo, ref);
    });
