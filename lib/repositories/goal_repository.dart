import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/goal_models.dart';

abstract class GoalRepository {
  Future<List<GoalModel>> fetchGoals(String uid);
  Future<void> saveGoal(String uid, GoalModel goal);
  Future<void> saveGoals(String uid, List<GoalModel> goals);
  Future<void> archiveGoal(String uid, String goalId);
  Future<void> restoreGoal(String uid, String goalId);
  Future<void> saveDailyProof(String uid, String goalId, GoalProof proof);
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

  @override
  Future<void> archiveGoal(String uid, String goalId) async {
    final goals = [...await fetchGoals(uid)];
    _goals[uid] = [
      for (final goal in goals)
        if (goal.id == goalId) goal.copyWith(isArchived: true) else goal,
    ];
  }

  @override
  Future<void> restoreGoal(String uid, String goalId) async {
    final goals = [...await fetchGoals(uid)];
    _goals[uid] = [
      for (final goal in goals)
        if (goal.id == goalId) goal.copyWith(isArchived: false) else goal,
    ];
  }

  @override
  Future<void> saveDailyProof(
    String uid,
    String goalId,
    GoalProof proof,
  ) async {
    final goals = [...await fetchGoals(uid)];
    _goals[uid] = [
      for (final goal in goals)
        if (goal.id == goalId) goal.copyWith(dailyProof: proof) else goal,
    ];
  }
}

class UnavailableFirebaseGoalRepository implements GoalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw const FirebaseFeatureUnavailableException('Goals');
  }
}

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return ref
      .watch(fakeBackendPolicyProvider)
      .selectBackend(
        firebase: UnavailableFirebaseGoalRepository.new,
        fake: FakeGoalRepository.new,
      );
});
