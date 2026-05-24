import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/goal_models.dart';

abstract class GoalRepository {
  Future<List<GoalModel>> fetchGoals(String uid);
  Future<void> saveGoal(String uid, GoalModel goal);
  Future<void> saveGoals(String uid, List<GoalModel> goals);
}

class FakeGoalRepository implements GoalRepository {
  final Map<String, List<GoalModel>> _goals = {};

  @override
  Future<List<GoalModel>> fetchGoals(String uid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _goals[uid] ?? [];
  }

  @override
  Future<void> saveGoal(String uid, GoalModel goal) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final items = _goals[uid] ?? [];
    items.removeWhere((i) => i.id == goal.id);
    items.add(goal);
    _goals[uid] = items;
  }

  @override
  Future<void> saveGoals(String uid, List<GoalModel> goals) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _goals[uid] = goals;
  }
}

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return FakeGoalRepository();
});
