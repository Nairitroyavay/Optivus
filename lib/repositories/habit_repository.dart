import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';

abstract class HabitRepository {
  Future<List<GoodHabitTemplateBundle>> fetchGoodHabits(String uid);
  Future<void> saveGoodHabits(String uid, List<GoodHabitTemplateBundle> habits);
  Future<List<BadHabitCheckInBundle>> fetchBadHabits(String uid);
  Future<void> saveBadHabits(String uid, List<BadHabitCheckInBundle> habits);
}

class FakeHabitRepository implements HabitRepository {
  final Map<String, List<GoodHabitTemplateBundle>> _goodHabits = {};
  final Map<String, List<BadHabitCheckInBundle>> _badHabits = {};

  @override
  Future<List<GoodHabitTemplateBundle>> fetchGoodHabits(String uid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _goodHabits[uid] ?? [];
  }

  @override
  Future<void> saveGoodHabits(String uid, List<GoodHabitTemplateBundle> habits) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _goodHabits[uid] = habits;
  }

  @override
  Future<List<BadHabitCheckInBundle>> fetchBadHabits(String uid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _badHabits[uid] ?? [];
  }

  @override
  Future<void> saveBadHabits(String uid, List<BadHabitCheckInBundle> habits) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _badHabits[uid] = habits;
  }
}

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return FakeHabitRepository();
});
