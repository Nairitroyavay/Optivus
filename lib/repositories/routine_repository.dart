import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/routine_item.dart';

abstract class RoutineRepository {
  Future<List<RoutineItem>> fetchRoutineItems(String uid);
  Future<void> saveRoutineItem(String uid, RoutineItem item);
  Future<void> saveRoutineItems(String uid, List<RoutineItem> items);
}

class FakeRoutineRepository implements RoutineRepository {
  final Map<String, List<RoutineItem>> _routines = {};

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _routines[uid] ?? [];
  }

  @override
  Future<void> saveRoutineItem(String uid, RoutineItem item) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final items = _routines[uid] ?? [];
    items.removeWhere((i) => i.id == item.id);
    items.add(item);
    _routines[uid] = items;
  }

  @override
  Future<void> saveRoutineItems(String uid, List<RoutineItem> items) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _routines[uid] = items;
  }
}

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return FakeRoutineRepository();
});
