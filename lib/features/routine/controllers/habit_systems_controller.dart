import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/habit_system_repository.dart';
import 'package:optivus/state/app_state.dart';

class HabitSystemsState {
  final List<HabitSystemRecord> systems;
  final bool loading;
  final bool refreshing;
  final bool saving;
  final String? error;
  final Set<String> pendingSystemIds;

  const HabitSystemsState({
    this.systems = const [],
    this.loading = false,
    this.refreshing = false,
    this.saving = false,
    this.error,
    this.pendingSystemIds = const {},
  });

  HabitSystemsState copyWith({
    List<HabitSystemRecord>? systems,
    bool? loading,
    bool? refreshing,
    bool? saving,
    String? error,
    bool clearError = false,
    Set<String>? pendingSystemIds,
  }) {
    return HabitSystemsState(
      systems: systems ?? this.systems,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
      pendingSystemIds: pendingSystemIds ?? this.pendingSystemIds,
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
  final HabitSystemRepository _repository;
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

  String _generateSystemId(String uid, String title) {
    final digest = sha256.convert(
      utf8.encode(
        'habitsys\u001f$uid\u001f$title\u001f${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    return 'habitsys_${digest.toString().substring(0, 24)}';
  }

  Future<void> loadForOwner(String uid) async {
    if (uid.trim().isEmpty || uid.contains('/')) {
      throw ArgumentError('Valid authenticated owner UID is required.');
    }

    final isNewOwner = _ownerUid != uid;
    final generation = ++_loadGeneration;
    _ownerUid = uid;

    if (isNewOwner) {
      state = state.copyWith(
        loading: true,
        systems: const [],
        pendingSystemIds: const {},
        clearError: true,
      );
    } else {
      state = state.copyWith(loading: true, clearError: true);
    }

    try {
      final remoteSystems = await _repository.fetchHabitSystems(uid);
      if (!mounted || generation != _loadGeneration || _ownerUid != uid) return;

      state = state.copyWith(systems: remoteSystems, loading: false);
    } catch (e) {
      if (!mounted || generation != _loadGeneration || _ownerUid != uid) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> createSystem({
    required String title,
    String description = '',
    required RoutineCategory category,
    required HabitSystemType systemType,
    List<String> linkedRoutineIds = const [],
    String source = 'user',
    String? onboardingSourceId,
  }) async {
    final uid = _ownerUid;
    if (uid == null || uid.isEmpty) return false;

    if (title.trim().isEmpty) {
      state = state.copyWith(error: 'System title cannot be empty.');
      return false;
    }

    state = state.copyWith(saving: true, clearError: true);

    final now = DateTime.now().toUtc();
    final systemId = _generateSystemId(uid, title);
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
    );

    final optimisticList = [...state.systems, record];
    final updatedPending = {...state.pendingSystemIds, systemId};
    state = state.copyWith(
      systems: optimisticList,
      pendingSystemIds: updatedPending,
    );

    try {
      await _repository.saveHabitSystem(uid, record);
      if (_ownerUid != uid) return false;

      state = state.copyWith(
        saving: false,
        pendingSystemIds: state.pendingSystemIds
            .where((id) => id != systemId)
            .toSet(),
      );
      return true;
    } catch (e) {
      if (_ownerUid != uid) return false;
      state = state.copyWith(
        systems: state.systems.where((s) => s.systemId != systemId).toList(),
        pendingSystemIds: state.pendingSystemIds
            .where((id) => id != systemId)
            .toSet(),
        saving: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> updateSystem(HabitSystemRecord updated) async {
    final uid = _ownerUid;
    if (uid == null || uid.isEmpty) return false;

    final existingIndex = state.systems.indexWhere(
      (s) => s.systemId == updated.systemId,
    );
    if (existingIndex < 0) return false;

    final previous = state.systems[existingIndex];
    if (state.pendingSystemIds.contains(updated.systemId)) return false;

    state = state.copyWith(
      saving: true,
      pendingSystemIds: {...state.pendingSystemIds, updated.systemId},
      clearError: true,
    );

    final record = updated.copyWith(updatedAt: DateTime.now().toUtc());

    final newSystems = [...state.systems];
    newSystems[existingIndex] = record;
    state = state.copyWith(systems: newSystems);

    try {
      await _repository.saveHabitSystem(uid, record);
      if (_ownerUid != uid) return false;

      state = state.copyWith(
        saving: false,
        pendingSystemIds: state.pendingSystemIds
            .where((id) => id != updated.systemId)
            .toSet(),
      );
      return true;
    } catch (e) {
      if (_ownerUid != uid) return false;
      final rolledBack = [...state.systems];
      rolledBack[existingIndex] = previous;
      state = state.copyWith(
        systems: rolledBack,
        pendingSystemIds: state.pendingSystemIds
            .where((id) => id != updated.systemId)
            .toSet(),
        saving: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> pauseSystem(String systemId) async {
    final system = state.systems
        .where((s) => s.systemId == systemId)
        .firstOrNull;
    if (system == null) return false;
    return updateSystem(system.copyWith(status: HabitSystemStatus.paused));
  }

  Future<bool> resumeSystem(String systemId) async {
    final system = state.systems
        .where((s) => s.systemId == systemId)
        .firstOrNull;
    if (system == null) return false;
    return updateSystem(system.copyWith(status: HabitSystemStatus.active));
  }

  Future<bool> archiveSystem(String systemId) async {
    final system = state.systems
        .where((s) => s.systemId == systemId)
        .firstOrNull;
    if (system == null) return false;
    return updateSystem(
      system.copyWith(
        status: HabitSystemStatus.archived,
        archivedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<bool> restoreSystem(String systemId) async {
    final system = state.systems
        .where((s) => s.systemId == systemId)
        .firstOrNull;
    if (system == null) return false;
    return updateSystem(
      system.copyWith(status: HabitSystemStatus.active, clearArchivedAt: true),
    );
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
    state = state.copyWith(
      saving: true,
      pendingSystemIds: {...state.pendingSystemIds, systemId},
      systems: state.systems.where((s) => s.systemId != systemId).toList(),
      clearError: true,
    );

    try {
      await _repository.deleteHabitSystem(uid, systemId);
      if (_ownerUid != uid) return false;

      state = state.copyWith(
        saving: false,
        pendingSystemIds: state.pendingSystemIds
            .where((id) => id != systemId)
            .toSet(),
      );
      return true;
    } catch (e) {
      if (_ownerUid != uid) return false;
      state = state.copyWith(
        systems: [...state.systems, previous],
        pendingSystemIds: state.pendingSystemIds
            .where((id) => id != systemId)
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
      final repo = ref.watch(habitSystemRepositoryProvider);
      return HabitSystemsNotifier(repo, ref);
    });
