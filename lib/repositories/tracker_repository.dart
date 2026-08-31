import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/tracker_models.dart';

abstract class TrackerRepository {
  Future<List<TrackerSession>> fetchSessions(String uid);
  Future<void> saveSession(String uid, TrackerSession session);
}

abstract class TrackerHistoryRepository {
  Future<List<TrackerHistoryEntry>> fetchHistory(String uid);
  Future<void> appendHistory(String uid, TrackerHistoryEntry entry);
}

abstract class FocusRepository {
  Future<List<FocusSession>> fetchFocusSessions(String uid);
  Future<void> saveFocusSession(String uid, FocusSession session);
}

abstract class BadHabitRepository {
  Future<List<BadHabitLog>> fetchBadHabitLogs(String uid);
  Future<void> saveBadHabitLog(String uid, BadHabitLog log);
}

abstract class SleepRepository {
  Future<List<SleepLog>> fetchSleepLogs(String uid);
  Future<void> saveSleepLog(String uid, SleepLog log);
}

abstract class NutritionRepository {
  Future<List<NutritionLog>> fetchNutritionLogs(String uid);
  Future<void> saveNutritionLog(String uid, NutritionLog log);
}

abstract class FitnessRepository {
  Future<List<FitnessActivity>> fetchFitnessActivities(String uid);
  Future<void> saveFitnessActivity(String uid, FitnessActivity activity);
}

class FakeTrackerRepository implements TrackerRepository {
  final Map<String, List<TrackerSession>> _sessions = {};

  @override
  Future<List<TrackerSession>> fetchSessions(String uid) async {
    return _sessions[uid] ?? const [];
  }

  @override
  Future<void> saveSession(String uid, TrackerSession session) async {
    final current = [...await fetchSessions(uid)];
    current.removeWhere((item) => item.id == session.id);
    current.add(session);
    _sessions[uid] = current;
  }
}

class FakeTrackerHistoryRepository implements TrackerHistoryRepository {
  final Map<String, List<TrackerHistoryEntry>> _history = {};

  @override
  Future<List<TrackerHistoryEntry>> fetchHistory(String uid) async {
    return _history[uid] ?? const [];
  }

  @override
  Future<void> appendHistory(String uid, TrackerHistoryEntry entry) async {
    _history[uid] = [entry, ...await fetchHistory(uid)];
  }
}

class FakeFocusRepository implements FocusRepository {
  final Map<String, List<FocusSession>> _sessions = {};

  @override
  Future<List<FocusSession>> fetchFocusSessions(String uid) async {
    return _sessions[uid] ?? const [];
  }

  @override
  Future<void> saveFocusSession(String uid, FocusSession session) async {
    final current = [...await fetchFocusSessions(uid)];
    current.removeWhere((item) => item.id == session.id);
    current.add(session);
    _sessions[uid] = current;
  }
}

class FakeBadHabitRepository implements BadHabitRepository {
  final Map<String, List<BadHabitLog>> _logs = {};

  @override
  Future<List<BadHabitLog>> fetchBadHabitLogs(String uid) async {
    return _logs[uid] ?? const [];
  }

  @override
  Future<void> saveBadHabitLog(String uid, BadHabitLog log) async {
    final current = [...await fetchBadHabitLogs(uid)];
    current.removeWhere((item) => item.id == log.id);
    current.add(log);
    _logs[uid] = current;
  }
}

class FakeSleepRepository implements SleepRepository {
  final Map<String, List<SleepLog>> _logs = {};

  @override
  Future<List<SleepLog>> fetchSleepLogs(String uid) async {
    return _logs[uid] ?? const [];
  }

  @override
  Future<void> saveSleepLog(String uid, SleepLog log) async {
    final current = [...await fetchSleepLogs(uid)];
    current.removeWhere((item) => item.id == log.id);
    current.add(log);
    _logs[uid] = current;
  }
}

class FakeNutritionRepository implements NutritionRepository {
  final Map<String, List<NutritionLog>> _logs = {};

  @override
  Future<List<NutritionLog>> fetchNutritionLogs(String uid) async {
    return _logs[uid] ?? const [];
  }

  @override
  Future<void> saveNutritionLog(String uid, NutritionLog log) async {
    final current = [...await fetchNutritionLogs(uid)];
    current.removeWhere((item) => item.id == log.id);
    current.add(log);
    _logs[uid] = current;
  }
}

class FakeFitnessRepository implements FitnessRepository {
  final Map<String, List<FitnessActivity>> _activities = {};

  @override
  Future<List<FitnessActivity>> fetchFitnessActivities(String uid) async {
    return _activities[uid] ?? const [];
  }

  @override
  Future<void> saveFitnessActivity(String uid, FitnessActivity activity) async {
    final current = [...await fetchFitnessActivities(uid)];
    current.removeWhere((item) => item.id == activity.id);
    current.add(activity);
    _activities[uid] = current;
  }
}

abstract class MoneyRepository {
  Future<MoneyGoal> fetchMoneyGoal(String uid);
  Future<void> saveMoneyGoal(String uid, MoneyGoal goal);
  Future<List<SavingEntry>> fetchSavingEntries(String uid);
  Future<void> saveSavingEntry(String uid, SavingEntry entry);
}

class FakeMoneyRepository implements MoneyRepository {
  final Map<String, MoneyGoal> _goals = {};
  final Map<String, List<SavingEntry>> _entries = {};

  @override
  Future<MoneyGoal> fetchMoneyGoal(String uid) async {
    return _goals[uid] ?? MoneyGoal(id: 'money-$uid');
  }

  @override
  Future<void> saveMoneyGoal(String uid, MoneyGoal goal) async {
    _goals[uid] = goal;
  }

  @override
  Future<List<SavingEntry>> fetchSavingEntries(String uid) async {
    return _entries[uid] ?? const [];
  }

  @override
  Future<void> saveSavingEntry(String uid, SavingEntry entry) async {
    final current = [...await fetchSavingEntries(uid)];
    current.removeWhere((item) => item.id == entry.id);
    current.add(entry);
    _entries[uid] = current;
  }
}

class UnavailableFirebaseTrackerRepositories
    implements
        TrackerRepository,
        TrackerHistoryRepository,
        FocusRepository,
        BadHabitRepository,
        SleepRepository,
        NutritionRepository,
        FitnessRepository,
        MoneyRepository {
  const UnavailableFirebaseTrackerRepositories();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw const FirebaseFeatureUnavailableException('Tracker data');
  }
}

T _selectTrackerBackend<T>(Ref ref, {required T Function() fake}) {
  return ref
      .watch(fakeBackendPolicyProvider)
      .selectBackend(
        firebase: () => const UnavailableFirebaseTrackerRepositories() as T,
        fake: fake,
      );
}

final trackerRepositoryProvider = Provider<TrackerRepository>((ref) {
  return _selectTrackerBackend(ref, fake: FakeTrackerRepository.new);
});

final trackerHistoryRepositoryProvider = Provider<TrackerHistoryRepository>((
  ref,
) {
  return _selectTrackerBackend(ref, fake: FakeTrackerHistoryRepository.new);
});

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  return _selectTrackerBackend(ref, fake: FakeFocusRepository.new);
});

final badHabitRepositoryProvider = Provider<BadHabitRepository>((ref) {
  return _selectTrackerBackend(ref, fake: FakeBadHabitRepository.new);
});

final sleepRepositoryProvider = Provider<SleepRepository>((ref) {
  return _selectTrackerBackend(ref, fake: FakeSleepRepository.new);
});

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  return _selectTrackerBackend(ref, fake: FakeNutritionRepository.new);
});

final fitnessRepositoryProvider = Provider<FitnessRepository>((ref) {
  return _selectTrackerBackend(ref, fake: FakeFitnessRepository.new);
});

final moneyRepositoryProvider = Provider<MoneyRepository>((ref) {
  return _selectTrackerBackend(ref, fake: FakeMoneyRepository.new);
});
