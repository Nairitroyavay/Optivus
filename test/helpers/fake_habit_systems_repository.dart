import 'dart:async';

import 'package:optivus/models/habit_system_operation.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';

class FakeHabitSystemsRepository implements HabitSystemsRepository {
  final Map<String, Map<String, HabitSystemRecord>> _storage = {};
  final _controllers = <String, StreamController<List<HabitSystemRecord>>>{};

  StreamController<List<HabitSystemRecord>> _getController(String uid) {
    return _controllers.putIfAbsent(
      uid,
      () => StreamController<List<HabitSystemRecord>>.broadcast(),
    );
  }

  void _notify(String uid) {
    final list = (_storage[uid]?.values.toList() ?? [])
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _getController(uid).add(list);
  }

  @override
  Future<List<HabitSystemRecord>> fetchHabitSystems(String uid) async {
    final list = (_storage[uid]?.values.toList() ?? [])
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<HabitSystemWriteResult> createSystem({
    required HabitSystemRecord system,
    required String operationId,
  }) async {
    final uid = system.ownerUid;
    final userMap = _storage.putIfAbsent(uid, () => {});
    if (userMap.containsKey(system.systemId)) {
      final existing = userMap[system.systemId]!;
      if (existing.title == system.title && existing.source == system.source) {
        return HabitSystemWriteResult.success(existing);
      }
      return const HabitSystemWriteResult.failure('System already exists');
    }
    userMap[system.systemId] = system;
    _notify(uid);
    return HabitSystemWriteResult.success(system);
  }

  @override
  Future<HabitSystemWriteResult> updateSystem({
    required HabitSystemRecord system,
    required int expectedVersion,
    required String operationId,
  }) async {
    final uid = system.ownerUid;
    final userMap = _storage.putIfAbsent(uid, () => {});
    final current = userMap[system.systemId];
    if (current == null) return const HabitSystemWriteResult.failure('Not found');
    if (current.version != expectedVersion) {
      throw const HabitSystemWriteConflict('Stale version');
    }
    final next = system.copyWith(version: expectedVersion + 1);
    userMap[system.systemId] = next;
    _notify(uid);
    return HabitSystemWriteResult.success(next);
  }

  @override
  Future<HabitSystemWriteResult> archiveSystem(String uid, String systemId, int expectedVersion, String operationId) async {
    final userMap = _storage.putIfAbsent(uid, () => {});
    final current = userMap[systemId];
    if (current == null) return const HabitSystemWriteResult.failure('Not found');
    if (current.version != expectedVersion) {
      throw const HabitSystemWriteConflict('Stale version');
    }
    final next = current.copyWith(
      status: HabitSystemStatus.archived,
      archivedAt: DateTime.now().toUtc(),
      version: expectedVersion + 1,
    );
    userMap[systemId] = next;
    _notify(uid);
    return HabitSystemWriteResult.success(next);
  }

  @override
  Future<HabitSystemWriteResult> restoreSystem(String uid, String systemId, int expectedVersion, String operationId) async {
    final userMap = _storage.putIfAbsent(uid, () => {});
    final current = userMap[systemId];
    if (current == null) return const HabitSystemWriteResult.failure('Not found');
    if (current.version != expectedVersion) {
      throw const HabitSystemWriteConflict('Stale version');
    }
    final next = current.copyWith(
      status: HabitSystemStatus.active,
      clearArchivedAt: true,
      version: expectedVersion + 1,
    );
    userMap[systemId] = next;
    _notify(uid);
    return HabitSystemWriteResult.success(next);
  }

  @override
  Future<HabitSystemWriteResult> reconcileProjectedSystem(HabitSystemRecord system) async {
    final uid = system.ownerUid;
    final userMap = _storage.putIfAbsent(uid, () => {});
    if (!userMap.containsKey(system.systemId)) {
      userMap[system.systemId] = system;
      _notify(uid);
    }
    return HabitSystemWriteResult.success(system);
  }

  @override
  Future<void> deleteHabitSystem(String uid, String systemId) async {
    _storage[uid]?.remove(systemId);
    _notify(uid);
  }

  @override
  Stream<List<HabitSystemRecord>> watchHabitSystems(String uid) {
    final controller = _getController(uid);
    _notify(uid);
    return controller.stream;
  }
}
