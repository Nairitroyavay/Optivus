import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/routine_item.dart';

class RoutineHistoryRecord {
  final String id;
  final String routineItemId;
  final String title;
  final RoutineStatus status;
  final RoutineBlockType blockType;
  final String source;
  final DateTime occurredAt;
  final String? linkedTrackerType;

  const RoutineHistoryRecord({
    required this.id,
    required this.routineItemId,
    required this.title,
    required this.status,
    required this.blockType,
    required this.source,
    required this.occurredAt,
    this.linkedTrackerType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routineItemId': routineItemId,
      'title': title,
      'status': status.name,
      'blockType': blockType.name,
      'source': source,
      'occurredAt': occurredAt.toIso8601String(),
      'linkedTrackerType': linkedTrackerType,
    };
  }
}

class HabitSystemRecord {
  final String id;
  final String title;
  final String category;
  final List<String> routineItemIds;
  final List<String> trackerTypes;
  final bool paused;
  final DateTime updatedAt;

  const HabitSystemRecord({
    required this.id,
    required this.title,
    required this.category,
    this.routineItemIds = const [],
    this.trackerTypes = const [],
    this.paused = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'routineItemIds': routineItemIds,
      'trackerTypes': trackerTypes,
      'paused': paused,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

abstract class RoutineHistoryRepository {
  Future<List<RoutineHistoryRecord>> fetchHistory(String uid);
  Future<void> appendHistory(String uid, RoutineHistoryRecord record);
}

abstract class HabitSystemsRepository {
  Future<List<HabitSystemRecord>> fetchHabitSystems(String uid);
  Future<void> saveHabitSystem(String uid, HabitSystemRecord system);
}

class FakeRoutineHistoryRepository implements RoutineHistoryRepository {
  final Map<String, List<RoutineHistoryRecord>> _history = {};

  @override
  Future<List<RoutineHistoryRecord>> fetchHistory(String uid) async {
    return _history[uid] ?? const [];
  }

  @override
  Future<void> appendHistory(String uid, RoutineHistoryRecord record) async {
    _history[uid] = [record, ...await fetchHistory(uid)];
  }
}

class FakeHabitSystemsRepository implements HabitSystemsRepository {
  final Map<String, List<HabitSystemRecord>> _systems = {};

  @override
  Future<List<HabitSystemRecord>> fetchHabitSystems(String uid) async {
    return _systems[uid] ?? const [];
  }

  @override
  Future<void> saveHabitSystem(String uid, HabitSystemRecord system) async {
    final current = [...await fetchHabitSystems(uid)];
    current.removeWhere((item) => item.id == system.id);
    current.add(system);
    _systems[uid] = current;
  }
}

final routineHistoryRepositoryProvider = Provider<RoutineHistoryRepository>((
  ref,
) {
  return FakeRoutineHistoryRepository();
});

final habitSystemsRepositoryProvider = Provider<HabitSystemsRepository>((ref) {
  return FakeHabitSystemsRepository();
});
