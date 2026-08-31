import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:optivus/models/user_profile.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/models/mind_note.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/permission_status.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_state.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/state/mock_seed_data.dart';

// ==========================================
// 1. User Profile State Notifier
// ==========================================
class MockUserProfileNotifier extends StateNotifier<UserProfile> {
  MockUserProfileNotifier() : super(UserProfile.empty(uid: ''));

  void resetEmpty({
    String uid = '',
    String email = '',
    String displayName = '',
  }) {
    state = UserProfile.empty(uid: uid, email: email, displayName: displayName);
  }

  void resetForSignedOut() => resetEmpty();

  void loadSeedData(UserProfile profile) {
    state = profile;
  }

  void updateProfile(UserProfile profile) {
    state = profile;
  }

  void updateLifestyleRole(String role, {String? extra, String? mode}) {
    state = state.copyWith(
      lifeRole: role,
      workingExtra: extra,
      businessMode: mode,
    );
  }

  void updateLifestyleAttributes({
    String? exerciseLevel,
    String? waterIntake,
    String? stressLevel,
    String? sleepQuality,
  }) {
    state = state.copyWith(
      exerciseLevel: exerciseLevel ?? state.exerciseLevel,
      waterIntake: waterIntake ?? state.waterIntake,
      stressLevel: stressLevel ?? state.stressLevel,
      sleepQuality: sleepQuality ?? state.sleepQuality,
    );
  }

  void updateBodyBasics({
    String? ageRange,
    double? height,
    double? weight,
    String? gender,
  }) {
    // Re-calculate mock estimates on body basics changes
    final double hMeters = (height ?? state.height) / 100.0;
    final double wKg = weight ?? state.weight;
    final bool canEstimate = hMeters > 0 && wKg > 0;
    final double bmi = canEstimate ? wKg / (hMeters * hMeters) : 0.0;
    final double calories = canEstimate
        ? wKg * 24.0 * 1.3
        : 0.0; // Simple Harris-Benedict representation
    final double protein = canEstimate ? wKg * 2.0 : 0.0;

    state = state.copyWith(
      ageRange: ageRange ?? state.ageRange,
      height: height ?? state.height,
      weight: weight ?? state.weight,
      gender: gender ?? state.gender,
      bmiEstimate: double.parse(bmi.toStringAsFixed(1)),
      calorieEstimate: double.parse(calories.toStringAsFixed(0)),
      proteinEstimate: double.parse(protein.toStringAsFixed(0)),
    );
  }

  void updateCoachPreferences({
    String? coachName,
    String? coachStyle,
    String? slipUpStyle,
  }) {
    state = state.copyWith(
      coachName: coachName ?? state.coachName,
      coachStyle: coachStyle ?? state.coachStyle,
      slipUpStyle: slipUpStyle ?? state.slipUpStyle,
    );
  }

  void completeOnboarding() {
    state = state.copyWith(
      onboardingInputCompleted: true,
      onboardingProjectionStatus: 'completed',
      onboardingCompleted: true,
    );
  }

  void applyOnboardingBundle(OnboardingCompletionBundle bundle) {
    final patch = bundle.userProfilePatch;
    final inputCompleted =
        patch['onboardingInputCompleted'] as bool? ??
        patch['onboardingCompleted'] as bool? ??
        true;
    final projectionStatus =
        patch['onboardingProjectionStatus'] as String? ??
        (patch['onboardingCompleted'] == true ? 'completed' : 'pending');
    state = UserProfile(
      uid: patch['uid'] as String? ?? state.uid,
      email: state.email,
      displayName: state.displayName,
      createdAt: state.createdAt,
      updatedAt:
          DateTime.tryParse(patch['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      onboardingInputCompleted: inputCompleted,
      onboardingProjectionStatus: projectionStatus,
      onboardingStep:
          (patch['onboardingStep'] as num?)?.toInt() ?? state.onboardingStep,
      lifeRole: patch['lifeRole'] as String? ?? state.lifeRole,
      workingExtra: patch['workingExtra'] as String?,
      businessMode: patch['businessMode'] as String?,
      exerciseLevel: patch['exerciseLevel'] as String? ?? state.exerciseLevel,
      waterIntake: patch['waterIntake'] as String? ?? state.waterIntake,
      stressLevel: patch['stressLevel'] as String? ?? state.stressLevel,
      sleepQuality: patch['sleepQuality'] as String? ?? state.sleepQuality,
      ageRange: patch['ageRange'] as String? ?? state.ageRange,
      height: (patch['height'] as num?)?.toDouble() ?? state.height,
      weight: (patch['weight'] as num?)?.toDouble() ?? state.weight,
      gender: patch['gender'] as String? ?? state.gender,
      bmiEstimate:
          (patch['bmiEstimate'] as num?)?.toDouble() ?? state.bmiEstimate,
      calorieEstimate:
          (patch['calorieEstimate'] as num?)?.toDouble() ??
          state.calorieEstimate,
      proteinEstimate:
          (patch['proteinEstimate'] as num?)?.toDouble() ??
          state.proteinEstimate,
      coachName: patch['coachName'] as String? ?? state.coachName,
      coachStyle: patch['coachStyle'] as String? ?? state.coachStyle,
      slipUpStyle: patch['slipUpStyle'] as String? ?? state.slipUpStyle,
    );
  }
}

final mockUserProfileProvider =
    StateNotifierProvider<MockUserProfileNotifier, UserProfile>((ref) {
      return MockUserProfileNotifier();
    });

// ==========================================
// 2. Routine Items State Notifier
// ==========================================
class MockRoutineNotifier extends StateNotifier<List<RoutineItem>> {
  MockRoutineNotifier() : super(const []);

  void resetEmpty() {
    state = const [];
  }

  void resetForSignedOut() => resetEmpty();

  void loadSeedData() {
    state = MockSeedData.defaultRoutineItems;
    _checkConflicts();
  }

  void replaceWith(List<RoutineItem> items) {
    state = List<RoutineItem>.from(items);
    _checkConflicts();
  }

  List<String> mergeMissing(List<RoutineItem> items) {
    final existingIds = state.map((item) => item.id).toSet();
    final missing = <RoutineItem>[];
    for (final item in items) {
      if (item.id.trim().isEmpty || existingIds.contains(item.id)) continue;
      missing.add(item);
      existingIds.add(item.id);
    }
    if (missing.isEmpty) return const [];
    state = [...state, ...missing];
    _checkConflicts();
    return missing.map((item) => item.id).toList(growable: false);
  }

  void addRoutineItem(RoutineItem item) {
    state = [...state, item];
    _checkConflicts();
  }

  void updateRoutineItem(RoutineItem updatedItem) {
    state = [
      for (final item in state)
        if (item.id == updatedItem.id) updatedItem else item,
    ];
    _checkConflicts();
  }

  void deleteRoutineItem(String id) {
    state = state.where((item) => item.id != id).toList();
    _checkConflicts();
  }

  void toggleSubtask(String routineId, int index) {
    state = [
      for (final item in state)
        if (item.id == routineId &&
            item.subtasks != null &&
            item.subtasksCompleted != null)
          item.copyWith(
            subtasksCompleted: [
              for (int i = 0; i < item.subtasksCompleted!.length; i++)
                if (i == index)
                  !item.subtasksCompleted![i]
                else
                  item.subtasksCompleted![i],
            ],
          )
        else
          item,
    ];
  }

  void toggleRoutineCompleted(String routineId) {
    state = [
      for (final item in state)
        if (item.id == routineId)
          item.copyWith(isCompleted: !item.isCompleted, isMissed: false)
        else
          item,
    ];
  }

  void toggleRoutineMissed(String routineId) {
    state = [
      for (final item in state)
        if (item.id == routineId)
          item.copyWith(isMissed: !item.isMissed, isCompleted: false)
        else
          item,
    ];
  }

  void updateStatus(String routineId, RoutineStatus newStatus) {
    state = [
      for (final item in state)
        if (item.id == routineId)
          item.copyWith(
            status: newStatus,
            isCompleted: newStatus == RoutineStatus.completed,
            isMissed: newStatus == RoutineStatus.missed,
          )
        else
          item,
    ];
  }

  void _checkConflicts() {
    // Standard validation: check if start/end times of any hard blocks overlap
    final items = List<RoutineItem>.from(state);
    bool changed = false;

    for (int i = 0; i < items.length; i++) {
      final a = items[i];
      if (a.blockType != RoutineBlockType.hardBlock) continue;

      bool conflict = false;
      String? msg;

      for (int j = 0; j < items.length; j++) {
        if (i == j) continue;
        final b = items[j];
        if (b.blockType != RoutineBlockType.hardBlock) continue;

        // Check time overlaps
        final bool overlap =
            (a.startMinute < b.endMinute && a.endMinute > b.startMinute);
        if (overlap) {
          conflict = true;
          msg = 'Time conflict with hard block: "${b.title}"';
          break;
        }
      }

      if (a.hasConflict != conflict || a.conflictMessage != msg) {
        items[i] = a.copyWith(
          hasConflict: conflict,
          conflictMessage: msg,
          clearConflict: !conflict,
        );
        changed = true;
      }
    }

    if (changed) {
      state = items;
    }
  }
}

final mockRoutineProvider =
    StateNotifierProvider<MockRoutineNotifier, List<RoutineItem>>((ref) {
      return MockRoutineNotifier();
    });

// ==========================================
// 3. Trackers State Notifier
// ==========================================
class MockTrackerState {
  final List<HydrationLog> hydrationLogs;
  final List<FitnessActivity> fitnessActivities;
  final List<ScreenTimeApp> screenTimeApps;
  final List<TrackerSession> trackerSessions;
  final MoneyGoal moneyGoal;
  final List<SavingEntry> savingsEntries;
  final List<FocusSession> focusSessions;
  final List<BadHabitLog> badHabitLogs;
  final List<SleepLog> sleepLogs;
  final List<NutritionLog> nutritionLogs;

  MockTrackerState({
    required this.hydrationLogs,
    required this.fitnessActivities,
    required this.screenTimeApps,
    required this.trackerSessions,
    required this.moneyGoal,
    required this.savingsEntries,
    required this.focusSessions,
    required this.badHabitLogs,
    required this.sleepLogs,
    required this.nutritionLogs,
  });

  MockTrackerState copyWith({
    List<HydrationLog>? hydrationLogs,
    List<FitnessActivity>? fitnessActivities,
    List<ScreenTimeApp>? screenTimeApps,
    List<TrackerSession>? trackerSessions,
    MoneyGoal? moneyGoal,
    List<SavingEntry>? savingsEntries,
    List<FocusSession>? focusSessions,
    List<BadHabitLog>? badHabitLogs,
    List<SleepLog>? sleepLogs,
    List<NutritionLog>? nutritionLogs,
  }) {
    return MockTrackerState(
      hydrationLogs: hydrationLogs ?? this.hydrationLogs,
      fitnessActivities: fitnessActivities ?? this.fitnessActivities,
      screenTimeApps: screenTimeApps ?? this.screenTimeApps,
      trackerSessions: trackerSessions ?? this.trackerSessions,
      moneyGoal: moneyGoal ?? this.moneyGoal,
      savingsEntries: savingsEntries ?? this.savingsEntries,
      focusSessions: focusSessions ?? this.focusSessions,
      badHabitLogs: badHabitLogs ?? this.badHabitLogs,
      sleepLogs: sleepLogs ?? this.sleepLogs,
      nutritionLogs: nutritionLogs ?? this.nutritionLogs,
    );
  }
}

class MockTrackerNotifier extends StateNotifier<MockTrackerState> {
  MockTrackerNotifier() : super(_emptyState());

  static MockTrackerState _emptyState() {
    return MockTrackerState(
      hydrationLogs: const [],
      fitnessActivities: const [],
      screenTimeApps: const [],
      trackerSessions: const [],
      moneyGoal: MoneyGoal(id: 'money-goal-empty'),
      savingsEntries: const [],
      focusSessions: const [],
      badHabitLogs: const [],
      sleepLogs: const [],
      nutritionLogs: const [],
    );
  }

  static MockTrackerState _seedState() {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return MockTrackerState(
      hydrationLogs: MockSeedData.defaultHydrationLogs,
      fitnessActivities: MockSeedData.defaultFitnessActivities,
      screenTimeApps: MockSeedData.defaultScreenTimeApps,
      trackerSessions: MockSeedData.defaultTrackerSessions,
      moneyGoal: MockSeedData.defaultMoneyGoal,
      savingsEntries: MockSeedData.defaultSavingEntries,
      focusSessions: [
        FocusSession(
          id: 'focus-seed-1',
          mode: FocusSessionMode.pomodoro25,
          startedAt: now.subtract(const Duration(hours: 2)),
          completedAt: now.subtract(const Duration(hours: 1, minutes: 35)),
          targetMinutes: 25,
          completedMinutes: 25,
          linkedRoutineTitle: 'Study block',
          status: FocusSessionStatus.completed,
          distractionRiskScore: 72,
        ),
      ],
      badHabitLogs: [
        BadHabitLog(
          id: 'habit-seed-1',
          habitType: BadHabitType.smoking,
          title: 'Smoking',
          status: BadHabitCheckInStatus.avoided,
          loggedAt: now.subtract(const Duration(hours: 3)),
          dateKey: todayKey,
          dailyCost: 120,
          potentialSaved: 120,
          trigger: 'Evening break',
        ),
      ],
      sleepLogs: [
        SleepLog.fromRange(
          id: 'sleep-seed-1',
          sleepStartDateTime: DateTime(
            now.year,
            now.month,
            now.day - 1,
            22,
            30,
          ),
          wakeDateTime: DateTime(now.year, now.month, now.day, 7, 30),
          quality: SleepQuality.good,
          source: 'manual',
        ),
      ],
      nutritionLogs: [
        NutritionLog(
          id: 'meal-seed-breakfast',
          mealType: MealType.breakfast,
          loggedAt: now.subtract(const Duration(hours: 4)),
          dateKey: todayKey,
          done: true,
          estimatedCalories: 420,
          estimatedProtein: 22,
          source: MealSource.home,
          dishes: const ['Oats', 'Milk', 'Banana'],
        ),
      ],
    );
  }

  void resetEmpty() {
    state = _emptyState();
  }

  void resetForSignedOut() => resetEmpty();

  void loadSeedData() {
    state = _seedState();
  }

  void applyOnboardingBundle(OnboardingCompletionBundle bundle) {
    final sessions = bundle.badHabitCheckIns
        .where((checkIn) => checkIn.badHabitCheckInEnabled)
        .map(
          (checkIn) => TrackerSession(
            id: 'tracker-${checkIn.id}',
            category: 'Habits',
            title: '${checkIn.displayName} check-in ready',
            timestamp: DateTime.now(),
            value: checkIn.lostTimeMinutes,
            isCompleted: false,
          ),
        )
        .toList();
    final existingSessionIds = state.trackerSessions
        .map((session) => session.id)
        .toSet();
    final mergedSessions = [
      ...state.trackerSessions,
      for (final session in sessions)
        if (!existingSessionIds.contains(session.id)) session,
    ];
    state = state.copyWith(
      trackerSessions: mergedSessions,
      moneyGoal: bundle.moneyGoal ?? state.moneyGoal,
    );
  }

  void logHydration(int ml) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    final log = HydrationLog(
      id: 'w-${state.hydrationLogs.length + 1}',
      amountMl: ml,
      timestamp: timeStr,
    );
    state = state.copyWith(hydrationLogs: [...state.hydrationLogs, log]);
  }

  void resetHydration() {
    state = state.copyWith(hydrationLogs: []);
  }

  void addFitnessActivity(FitnessActivity activity) {
    state = state.copyWith(
      fitnessActivities: [...state.fitnessActivities, activity],
    );
  }

  void completeFitnessActivity(FitnessActivity activity) {
    final session = TrackerSession(
      id: 'tracker-${activity.id}',
      category: 'Body',
      title: '${activity.activityType.shortLabel} completed',
      timestamp: activity.endedAt ?? DateTime.now(),
      value: activity.movingDuration.inMinutes,
      isCompleted: true,
    );

    state = state.copyWith(
      fitnessActivities: [...state.fitnessActivities, activity],
      trackerSessions: [...state.trackerSessions, session],
    );

    // Later sync hooks:
    // - complete linked Routine item when linkedRoutineItemId is set
    // - update Home Body pillar progress and Strong Body goal proof
    // - expose the completed activity to Tracker graphs and Coach context
  }

  void updateScreenTime(String packageName, int addedMinutes) {
    state = state.copyWith(
      screenTimeApps: [
        for (final app in state.screenTimeApps)
          if (app.packageName == packageName)
            ScreenTimeApp(
              name: app.name,
              packageName: app.packageName,
              durationMinutes: app.durationMinutes + addedMinutes,
              distractionRisk: app.distractionRisk,
            )
          else
            app,
      ],
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _todayKey() => _dateKey(DateTime.now());

  String _entryId() => 's-${DateTime.now().microsecondsSinceEpoch}';

  bool hasConfirmedSavingForDate(String dateKey) {
    return state.savingsEntries.any(
      (entry) => entry.dateKey == dateKey && entry.isConfirmed,
    );
  }

  double confirmedSavedForDate(String dateKey) {
    return state.savingsEntries
        .where((entry) => entry.dateKey == dateKey && entry.isConfirmed)
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  double potentialSavedForDate(String dateKey) {
    return state.savingsEntries
        .where((entry) => entry.dateKey == dateKey && entry.isPotential)
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  List<SavingEntry> entriesForDate(String dateKey) {
    final entries = state.savingsEntries
        .where((entry) => entry.dateKey == dateKey)
        .toList(growable: false);
    return entries..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  MoneyEntrySource _dedupedTodaySource({
    required MoneyEntrySource requestedSource,
    required bool alreadyConfirmedToday,
  }) {
    if (!alreadyConfirmedToday) return requestedSource;
    if (requestedSource == MoneyEntrySource.badHabitConverted ||
        requestedSource == MoneyEntrySource.adjustment) {
      return requestedSource;
    }
    return MoneyEntrySource.manual;
  }

  String _saveDescription({
    required double amount,
    required MoneyEntrySource source,
    String? description,
  }) {
    if (description != null && description.trim().isNotEmpty) {
      return description.trim();
    }
    if (amount <= state.moneyGoal.tinySaveAmount) {
      return 'Tiny save';
    }
    return switch (source) {
      MoneyEntrySource.dailyTarget => 'Daily target saved',
      MoneyEntrySource.upiMock => 'Payment app transfer marked done',
      MoneyEntrySource.routineTask => 'Routine Money System task',
      MoneyEntrySource.badHabitConverted => 'Bad-habit money converted',
      MoneyEntrySource.adjustment => 'Savings adjustment',
      MoneyEntrySource.badHabitAvoided => 'Bad-habit money avoided',
      MoneyEntrySource.manual => 'Manual saving confirmed',
    };
  }

  void saveMoneyToday({
    required double amount,
    required MoneySaveMethod method,
    MoneyEntrySource source = MoneyEntrySource.manual,
    String? description,
    String? routineTaskId,
    String? currencyCode,
  }) {
    if (!amount.isFinite || amount <= 0) return;

    final now = DateTime.now();
    final today = _todayKey();
    final alreadyConfirmedToday = hasConfirmedSavingForDate(today);
    final effectiveSource = _dedupedTodaySource(
      requestedSource: source,
      alreadyConfirmedToday: alreadyConfirmedToday,
    );
    final effectiveDescription = _saveDescription(
      amount: amount,
      source: source,
      description: description,
    );

    final entry = SavingEntry(
      id: _entryId(),
      amount: amount,
      currencyCode: currencyCode ?? state.moneyGoal.currencyCode,
      createdAt: now,
      dateKey: today,
      description: effectiveDescription,
      status: MoneyEntryStatus.confirmed,
      source: effectiveSource,
      method: method,
      routineTaskId: routineTaskId,
    );

    final shouldUpdateStreak = !alreadyConfirmedToday;
    final nextStreak = shouldUpdateStreak
        ? state.moneyGoal.streakDays + 1
        : state.moneyGoal.streakDays;
    final updatedGoal = state.moneyGoal.copyWith(
      totalConfirmedSaved: state.moneyGoal.totalConfirmedSaved + amount,
      streakDays: nextStreak,
      bestStreakDays: nextStreak > state.moneyGoal.bestStreakDays
          ? nextStreak
          : state.moneyGoal.bestStreakDays,
      successfulDaysAtCurrentLevel: shouldUpdateStreak
          ? state.moneyGoal.successfulDaysAtCurrentLevel + 1
          : state.moneyGoal.successfulDaysAtCurrentLevel,
    );

    state = state.copyWith(
      savingsEntries: [...state.savingsEntries, entry],
      moneyGoal: updatedGoal,
    );
  }

  void logPotentialSaving({
    required double amount,
    required String description,
    String? badHabitKey,
    String? currencyCode,
  }) {
    if (!amount.isFinite || amount <= 0) return;

    final now = DateTime.now();
    final entry = SavingEntry(
      id: _entryId(),
      amount: amount,
      currencyCode: currencyCode ?? state.moneyGoal.currencyCode,
      createdAt: now,
      dateKey: _todayKey(),
      description: description.trim().isEmpty
          ? 'Bad-habit money avoided'
          : description.trim(),
      status: MoneyEntryStatus.potential,
      source: MoneyEntrySource.badHabitAvoided,
      method: MoneySaveMethod.none,
      badHabitKey: badHabitKey,
    );

    state = state.copyWith(
      savingsEntries: [...state.savingsEntries, entry],
      moneyGoal: state.moneyGoal.copyWith(
        totalPotentialSaved: state.moneyGoal.totalPotentialSaved + amount,
      ),
    );
  }

  void convertPotentialToConfirmed(
    String entryId, {
    MoneySaveMethod method = MoneySaveMethod.custom,
  }) {
    SavingEntry? target;
    for (final entry in state.savingsEntries) {
      if (entry.id == entryId && entry.isPotential) {
        target = entry;
        break;
      }
    }
    if (target == null) return;

    final today = _todayKey();
    final shouldUpdateStreak =
        target.dateKey == today && !hasConfirmedSavingForDate(today);
    final nextStreak = shouldUpdateStreak
        ? state.moneyGoal.streakDays + 1
        : state.moneyGoal.streakDays;
    final updatedEntries = [
      for (final entry in state.savingsEntries)
        if (entry.id == entryId)
          entry.copyWith(
            status: MoneyEntryStatus.confirmed,
            source: MoneyEntrySource.badHabitConverted,
            method: method,
            note: entry.note ?? 'Converted to real saving',
          )
        else
          entry,
    ];

    state = state.copyWith(
      savingsEntries: updatedEntries,
      moneyGoal: state.moneyGoal.copyWith(
        totalConfirmedSaved:
            state.moneyGoal.totalConfirmedSaved + target.amount,
        totalPotentialSaved:
            (state.moneyGoal.totalPotentialSaved - target.amount)
                .clamp(0.0, double.infinity)
                .toDouble(),
        streakDays: nextStreak,
        bestStreakDays: nextStreak > state.moneyGoal.bestStreakDays
            ? nextStreak
            : state.moneyGoal.bestStreakDays,
        successfulDaysAtCurrentLevel: shouldUpdateStreak
            ? state.moneyGoal.successfulDaysAtCurrentLevel + 1
            : state.moneyGoal.successfulDaysAtCurrentLevel,
      ),
    );
  }

  void skipMoneyToday({required String reason}) {
    final today = _todayKey();
    if (hasConfirmedSavingForDate(today)) return;

    final existingWithoutTodaySkip = state.savingsEntries
        .where(
          (entry) =>
              !(entry.dateKey == today &&
                  entry.status == MoneyEntryStatus.skipped),
        )
        .toList(growable: false);

    final now = DateTime.now();
    final entry = SavingEntry(
      id: _entryId(),
      amount: 0,
      currencyCode: state.moneyGoal.currencyCode,
      createdAt: now,
      dateKey: today,
      description: 'Skipped today',
      status: MoneyEntryStatus.skipped,
      source: MoneyEntrySource.dailyTarget,
      method: MoneySaveMethod.none,
      reason: reason.trim().isEmpty ? 'Skipped manually' : reason.trim(),
    );

    state = state.copyWith(
      savingsEntries: [...existingWithoutTodaySkip, entry],
      moneyGoal: state.moneyGoal.copyWith(
        streakDays: 0,
        successfulDaysAtCurrentLevel: 0,
      ),
    );
  }

  double _nextMoneyLevel(double current) {
    const levels = [5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0];
    for (final level in levels) {
      if (level > current) return level;
    }
    return current + 500.0;
  }

  void levelUpMoneyTarget() {
    final newLevel = state.moneyGoal.nextLevelAmount;
    state = state.copyWith(
      moneyGoal: state.moneyGoal.copyWith(
        dailyTarget: newLevel,
        currentLevelAmount: newLevel,
        streakLevel: state.moneyGoal.streakLevel + 1,
        successfulDaysAtCurrentLevel: 0,
        nextLevelAmount: _nextMoneyLevel(newLevel),
      ),
    );
  }

  void stayAtCurrentMoneyTarget() {
    state = state.copyWith(
      moneyGoal: state.moneyGoal.copyWith(successfulDaysAtCurrentLevel: 0),
    );
  }

  void updateMoneySettings({
    double? dailyTarget,
    double? tinySaveAmount,
    String? destinationLabel,
    String? currencyCode,
    MoneySaveMethod? defaultMethod,
    String? reminderTimeLabel,
    int? levelUpAfterDays,
    bool? manualConfirmationAllowed,
  }) {
    final normalizedTarget = dailyTarget != null && dailyTarget.isFinite
        ? dailyTarget.clamp(1.0, 1000000.0).toDouble()
        : null;
    final normalizedTiny = tinySaveAmount != null && tinySaveAmount.isFinite
        ? tinySaveAmount.clamp(1.0, 1000000.0).toDouble()
        : null;
    final currentLevel = normalizedTarget ?? state.moneyGoal.currentLevelAmount;

    state = state.copyWith(
      moneyGoal: state.moneyGoal.copyWith(
        dailyTarget: normalizedTarget,
        currencyCode: currencyCode,
        tinySaveAmount: normalizedTiny,
        currentLevelAmount: normalizedTarget,
        nextLevelAmount: normalizedTarget == null
            ? null
            : _nextMoneyLevel(currentLevel),
        destinationLabel:
            destinationLabel == null || destinationLabel.trim().isEmpty
            ? null
            : destinationLabel.trim(),
        defaultMethod: defaultMethod,
        reminderTimeLabel:
            reminderTimeLabel == null || reminderTimeLabel.trim().isEmpty
            ? null
            : reminderTimeLabel.trim(),
        levelUpAfterDays: levelUpAfterDays?.clamp(1, 365),
        manualConfirmationAllowed: manualConfirmationAllowed,
      ),
    );
  }

  void resetMoneySystem() {
    state = state.copyWith(
      moneyGoal: MoneyGoal(
        id: state.moneyGoal.id,
        currencyCode: state.moneyGoal.currencyCode,
      ),
      savingsEntries: const [],
    );
  }

  void logMeditationSession({
    required int durationMinutes,
    required String type,
  }) {
    final session = TrackerSession(
      id: 'meditation-${DateTime.now().millisecondsSinceEpoch}',
      category: 'Mind',
      title: type,
      timestamp: DateTime.now(),
      value: durationMinutes,
      isCompleted: true,
    );
    state = state.copyWith(
      trackerSessions: [...state.trackerSessions, session],
    );
  }

  void completeFocusSession(FocusSession session) {
    final completed = session.copyWith(
      completedAt: session.completedAt ?? DateTime.now(),
      completedMinutes: session.completedMinutes <= 0
          ? session.targetMinutes
          : session.completedMinutes,
      status: FocusSessionStatus.completed,
    );
    final trackerSession = TrackerSession(
      id: 'tracker-${completed.id}',
      category: 'Focus',
      title: 'Focus session completed',
      timestamp: completed.completedAt ?? DateTime.now(),
      value: completed.completedMinutes,
      isCompleted: true,
    );
    state = state.copyWith(
      focusSessions: [...state.focusSessions, completed],
      trackerSessions: [...state.trackerSessions, trackerSession],
    );
  }

  void addBadHabitLog(BadHabitLog log, {bool addPotentialSaving = false}) {
    state = state.copyWith(badHabitLogs: [...state.badHabitLogs, log]);
    if (addPotentialSaving && log.potentialSaved > 0) {
      logPotentialSaving(
        amount: log.potentialSaved,
        description: '${log.title} avoided',
        badHabitKey: log.habitType.name,
      );
    }
  }

  void addSleepLog(SleepLog log) {
    final session = TrackerSession(
      id: 'tracker-${log.id}',
      category: 'Body',
      title: 'Sleep logged',
      timestamp: log.wakeDateTime,
      value: log.durationMinutes,
      isCompleted: true,
    );
    state = state.copyWith(
      sleepLogs: [...state.sleepLogs, log],
      trackerSessions: [...state.trackerSessions, session],
    );
  }

  void upsertNutritionLog(NutritionLog log) {
    final updated = [
      for (final existing in state.nutritionLogs)
        if (existing.id == log.id) log else existing,
      if (!state.nutritionLogs.any((existing) => existing.id == log.id)) log,
    ];
    final session = TrackerSession(
      id: 'tracker-${log.id}',
      category: 'Body',
      title: '${log.mealType.name} logged',
      timestamp: log.loggedAt,
      value: log.done ? 1 : 0,
      isCompleted: log.done,
    );
    state = state.copyWith(
      nutritionLogs: updated,
      trackerSessions: log.done
          ? [...state.trackerSessions, session]
          : state.trackerSessions,
    );
  }
}

final mockTrackerProvider =
    StateNotifierProvider<MockTrackerNotifier, MockTrackerState>((ref) {
      return MockTrackerNotifier();
    });

// ==========================================
// 4. Goals Focus State Notifier
// ==========================================
class MockGoalNotifier extends StateNotifier<List<GoalModel>> {
  MockGoalNotifier() : super(const []);

  void resetEmpty() {
    state = const [];
  }

  void resetForSignedOut() => resetEmpty();

  void loadSeedData() {
    state = MockSeedData.defaultGoals;
  }

  void replaceWith(List<GoalModel> goals) {
    state = List<GoalModel>.from(goals);
  }

  List<String> mergeMissing(List<GoalModel> goals) {
    final existingIds = state.map((goal) => goal.id).toSet();
    final missing = <GoalModel>[];
    for (final goal in goals) {
      if (goal.id.trim().isEmpty || existingIds.contains(goal.id)) continue;
      missing.add(goal);
      existingIds.add(goal.id);
    }
    if (missing.isEmpty) return const [];
    state = [...state, ...missing];
    return missing.map((goal) => goal.id).toList(growable: false);
  }

  void addGoal(GoalModel goal) {
    state = [...state, goal];
  }

  void updateGoal(GoalModel updatedGoal) {
    state = [
      for (final goal in state)
        if (goal.id == updatedGoal.id) updatedGoal else goal,
    ];
  }

  void archiveGoal(String goalId) {
    state = [
      for (final goal in state)
        if (goal.id == goalId) goal.copyWith(isArchived: true) else goal,
    ];
  }

  void restoreGoal(String goalId) {
    state = [
      for (final goal in state)
        if (goal.id == goalId) goal.copyWith(isArchived: false) else goal,
    ];
  }

  void toggleGoalProofCompleted(String goalId) {
    state = [
      for (final goal in state)
        if (goal.id == goalId)
          goal.copyWith(
            dailyProof: goal.dailyProof.copyWith(
              isCompleted: !goal.dailyProof.isCompleted,
            ),
            streakDays: goal.dailyProof.isCompleted
                ? (goal.streakDays - 1).clamp(0, 999)
                : goal.streakDays + 1,
            progressPercent: goal.dailyProof.isCompleted
                ? (goal.progressPercent - 0.05).clamp(0.0, 1.0)
                : (goal.progressPercent + 0.05).clamp(0.0, 1.0),
          )
        else
          goal,
    ];
  }

  void changeGoalProofDifficulty(String goalId, String difficulty) {
    state = [
      for (final goal in state)
        if (goal.id == goalId)
          goal.copyWith(
            dailyProof: goal.dailyProof.copyWith(
              selectedDifficulty: difficulty,
            ),
          )
        else
          goal,
    ];
  }

  void updateGoalProofNote(String goalId, String note) {
    state = [
      for (final goal in state)
        if (goal.id == goalId)
          goal.copyWith(dailyProof: goal.dailyProof.copyWith(note: note))
        else
          goal,
    ];
  }
}

final mockGoalProvider =
    StateNotifierProvider<MockGoalNotifier, List<GoalModel>>((ref) {
      return MockGoalNotifier();
    });

// ==========================================
// 5. Mind Notes State Notifier
// ==========================================
class MockMindNoteNotifier extends StateNotifier<List<MindNote>> {
  MockMindNoteNotifier() : super(const []);

  void resetEmpty() {
    state = const [];
  }

  void resetForSignedOut() => resetEmpty();

  void loadSeedData() {
    state = MockSeedData.defaultMindNotes;
  }

  void addMindNote(
    String content,
    MindNoteType type,
    MindNoteIntensity intensity,
  ) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    final note = MindNote(
      id: 'note-${state.length + 1}',
      content: content,
      type: type,
      intensity: intensity,
      timestamp: timeStr,
    );
    state = [note, ...state];
  }

  void deleteMindNote(String id) {
    state = state.where((note) => note.id != id).toList();
  }

  void toggleShareWithCoach(String id) {
    state = [
      for (final note in state)
        if (note.id == id)
          note.copyWith(isSharedWithCoach: !note.isSharedWithCoach)
        else
          note,
    ];
  }
}

final mockMindNoteProvider =
    StateNotifierProvider<MockMindNoteNotifier, List<MindNote>>((ref) {
      return MockMindNoteNotifier();
    });

// ==========================================
// 6. AI Coach Sessions State Notifier
// ==========================================
class MockCoachNotifier extends StateNotifier<List<CoachSession>> {
  MockCoachNotifier() : super(const []);

  int _sessionGeneration = 0;

  void resetEmpty() {
    _sessionGeneration++;
    state = const [];
  }

  void resetForSignedOut() => resetEmpty();

  void loadSeedData() {
    state = MockSeedData.defaultCoachSessions;
  }

  void replaceWith(List<CoachSession> sessions) {
    state = List<CoachSession>.from(sessions);
  }

  void deleteSession(String sessionId) {
    state = state.where((session) => session.id != sessionId).toList();
  }

  void sendMessage(String sessionId, String content) {
    final sessionGeneration = _sessionGeneration;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    final userMsg = CoachMessage(
      id: 'm-user-${DateTime.now().millisecondsSinceEpoch}',
      isFromCoach: false,
      content: content,
      timestamp: timeStr,
    );

    state = [
      for (final session in state)
        if (session.id == sessionId)
          session.copyWith(messages: [...session.messages, userMsg])
        else
          session,
    ];

    // Trigger mock AI response after 1.5 seconds delay
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || sessionGeneration != _sessionGeneration) return;
      _generateCoachReply(sessionId, content);
    });
  }

  @override
  void dispose() {
    _sessionGeneration++;
    super.dispose();
  }

  void createNewSession(
    String title,
    CoachSessionType type,
    String coachName,
    String coachStyle,
  ) {
    final session = CoachSession(
      id: 'session-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: type,
      coachName: coachName,
      coachStyle: coachStyle,
      createdAt: 'Today',
      messages: [
        CoachMessage(
          id: 'm-coach-1',
          isFromCoach: true,
          content:
              'Hello! I am your AI Coach $coachName. I look forward to working with you under my $coachStyle philosophy. What is currently on your mind?',
          timestamp: 'Just now',
        ),
      ],
    );
    state = [session, ...state];
  }

  void _generateCoachReply(String sessionId, String userContent) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    String reply = '';
    List<CoachResponseBlock> blocks = [];

    // Simple keyword mapping to create an amazingly smart visual dashboard simulation
    final lower = userContent.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi')) {
      reply =
          'Greetings! How is your day proceeding? I am ready to audit your timeline, track hydration goals, or help you wind down.';
    } else if (lower.contains('tired') ||
        lower.contains('missed') ||
        lower.contains('skip')) {
      reply =
          'Fatigue is a real biological trigger. Don\'t stress about breaking a hard routine. We can dynamically adapt. I recommend triggering the "Tiny" daily proof adjustment for your Gym goals so your streak remains unbroken!';
      blocks = [
        CoachResponseBlock(
          type: CoachResponseBlockType.routineSuggestionCard,
          heading: 'Pivot Gym Workout',
          body:
              'Adapt Gym Workout block start time or limit to 15m home routine.',
          buttonLabel: 'Adapt Now',
          payload: 'pivot_routine',
        ),
      ];
    } else if (lower.contains('water') || lower.contains('hydrate')) {
      reply =
          'Hydration levels affect cognitive processing directly. You have logged several hydration milestones today. I suggest adding another 250ml now to stay on pace!';
      blocks = [
        CoachResponseBlock(
          type: CoachResponseBlockType.trackerActionCard,
          heading: 'Water Tracker Log',
          body: 'Quick log 250ml of water right from this card.',
          buttonLabel: '+250ml Water',
          payload: 'water_250',
        ),
      ];
    } else if (lower.contains('goal') ||
        lower.contains('gym') ||
        lower.contains('workout')) {
      reply =
          'Your systems shape your outcomes. Your "Sleek & Strong Athlete" identity currently has a 12-day streak. Complete your daily Gym proof to add to the multiplier!';
      blocks = [
        CoachResponseBlock(
          type: CoachResponseBlockType.goalProofCard,
          heading: 'Daily Gym Proof',
          body: 'Complete Gym compound lifts daily proof to maintain streak.',
          buttonLabel: 'Verify Gym Proof',
          payload: 'verify_proof_body',
        ),
      ];
    } else if (lower.contains('overthinking') ||
        lower.contains('stress') ||
        lower.contains('mind')) {
      reply =
          'Overthinking triggers cortisol releases. I recommend writing down whatever is running in your mind right into our Mind Notebook. I will automatically classify it for you to clear cognitive RAM.';
      blocks = [
        CoachResponseBlock(
          type: CoachResponseBlockType.mindNoteCard,
          heading: 'Dump Overthinking Thoughts',
          body:
              'Open your notebook timeline to classify and shelf mental clutter.',
          buttonLabel: 'Open Notebook',
          payload: 'open_notebook',
        ),
      ];
    } else {
      reply =
          'I understand. Let\'s review your routine timeline and find ways to build robust habit consistency. Would you like me to suggest some minor schedule optimizations?';
    }

    final coachMsg = CoachMessage(
      id: 'm-coach-${DateTime.now().millisecondsSinceEpoch}',
      isFromCoach: true,
      content: reply,
      timestamp: timeStr,
      blocks: blocks,
    );

    state = [
      for (final session in state)
        if (session.id == sessionId)
          session.copyWith(messages: [...session.messages, coachMsg])
        else
          session,
    ];
  }
}

final mockCoachProvider =
    StateNotifierProvider<MockCoachNotifier, List<CoachSession>>((ref) {
      return MockCoachNotifier();
    });

class MockCoachPreferencesNotifier extends StateNotifier<CoachPreferences> {
  MockCoachPreferencesNotifier() : super(CoachPreferences());

  void resetEmpty() {
    state = CoachPreferences();
  }

  void resetForSignedOut() => resetEmpty();

  void updatePreferences(CoachPreferences prefs) {
    state = prefs;
  }
}

final mockCoachPreferencesProvider =
    StateNotifierProvider<MockCoachPreferencesNotifier, CoachPreferences>((
      ref,
    ) {
      return MockCoachPreferencesNotifier();
    });

// ==========================================
// 7. Notification Preferences Notifier
// ==========================================
class MockNotificationPreferencesNotifier
    extends StateNotifier<NotificationPreferences> {
  MockNotificationPreferencesNotifier() : super(NotificationPreferences());

  void resetEmpty() {
    state = NotificationPreferences(
      morningStart: false,
      nextTask: false,
      eating: false,
      badHabitCheckIn: false,
      savings: false,
      nightReflection: false,
    );
  }

  void resetForSignedOut() => resetEmpty();

  void updatePreferences(NotificationPreferences prefs) {
    state = prefs;
  }

  void toggleMorningStart() {
    state = state.copyWith(morningStart: !state.morningStart);
  }

  void toggleNextTask() {
    state = state.copyWith(nextTask: !state.nextTask);
  }

  void toggleEating() {
    state = state.copyWith(eating: !state.eating);
  }

  void toggleBadHabitCheckIn() {
    state = state.copyWith(badHabitCheckIn: !state.badHabitCheckIn);
  }

  void toggleSavings() {
    state = state.copyWith(savings: !state.savings);
  }

  void toggleNightReflection() {
    state = state.copyWith(nightReflection: !state.nightReflection);
  }

  void setIntensity(NotificationIntensity intensity) {
    state = state.copyWith(intensity: intensity);
  }
}

final mockNotificationPreferencesProvider =
    StateNotifierProvider<
      MockNotificationPreferencesNotifier,
      NotificationPreferences
    >((ref) {
      return MockNotificationPreferencesNotifier();
    });

// ==========================================
// 8. Permissions Status State Notifier
// ==========================================
class MockPermissionNotifier extends StateNotifier<PermissionStatus> {
  MockPermissionNotifier() : super(PermissionStatus());

  void resetEmpty() {
    state = PermissionStatus();
  }

  void resetForSignedOut() => resetEmpty();

  void toggleNotificationPermission() {
    final next = state.notifications == PermissionConnectionState.notConnected
        ? PermissionConnectionState.mockConnected
        : PermissionConnectionState.notConnected;
    state = state.copyWith(notifications: next);
  }

  void toggleUsageAccessPermission() {
    final next = state.usageAccess == PermissionConnectionState.notConnected
        ? PermissionConnectionState.mockConnected
        : PermissionConnectionState.notConnected;
    state = state.copyWith(usageAccess: next);
  }

  void toggleLocationGpsPermission() {
    final next = state.locationGps == PermissionConnectionState.notConnected
        ? PermissionConnectionState.mockConnected
        : PermissionConnectionState.notConnected;
    state = state.copyWith(locationGps: next);
  }

  void toggleHealthConnectPermission() {
    final next = state.healthConnect == PermissionConnectionState.notConnected
        ? PermissionConnectionState.mockConnected
        : PermissionConnectionState.notConnected;
    state = state.copyWith(healthConnect: next);
  }

  void toggleCameraGalleryPermission() {
    final next = state.cameraGallery == PermissionConnectionState.notConnected
        ? PermissionConnectionState.mockConnected
        : PermissionConnectionState.notConnected;
    state = state.copyWith(cameraGallery: next);
  }
}

final mockPermissionProvider =
    StateNotifierProvider<MockPermissionNotifier, PermissionStatus>((ref) {
      return MockPermissionNotifier();
    });

// ==========================================
// 9. Onboarding State Notifier
// ==========================================
class MockOnboardingNotifier extends StateNotifier<OnboardingState> {
  MockOnboardingNotifier() : super(OnboardingState());

  void loadSeedData(OnboardingDraft seedDraft) {
    state = OnboardingState(draft: seedDraft, validationMessage: null);
  }

  void reset(String uid) {
    final now = DateTime.now();
    state = OnboardingState(
      draft: OnboardingDraft(
        uid: uid,
        createdAt: now,
        updatedAt: now,
        baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks(),
      ),
    );
  }

  void resetForSignedOut() => reset('');

  void setStep(int step) {
    final bounded = step.clamp(0, OnboardingDraft.lastStepIndex).toInt();
    state = state.copyWith(
      draft: state.draft.copyWith(currentStep: bounded),
      currentStep: bounded,
      clearValidation: true,
    );
  }

  void setStepCompleted(int step, bool completed) {
    final list = _setStepValue(state.draft.stepCompleted, step, completed);
    state = state.copyWith(
      draft: state.draft.copyWith(stepCompleted: list),
      stepCompleted: list,
    );
  }

  void setStepDirty(int step, bool dirty) {
    final list = _setStepValue(state.draft.stepDirty, step, dirty);
    final statuses = _setSaveStatus(
      state.stepSaveStatus,
      step,
      dirty
          ? SaveSyncStatus.dirty
          : (state.stepCompleted[step]
                ? SaveSyncStatus.synced
                : SaveSyncStatus.clean),
    );
    state = state.copyWith(
      draft: state.draft.copyWith(stepDirty: list),
      stepDirty: list,
      stepSaveStatus: statuses,
    );
  }

  void setStepLoading(int step, bool loading) {
    final list = _setStepValue(state.draft.stepLoading, step, loading);
    state = state.copyWith(
      draft: state.draft.copyWith(stepLoading: list),
      stepLoading: list,
      stepSaveStatus: loading
          ? _setSaveStatus(state.stepSaveStatus, step, SaveSyncStatus.saving)
          : state.stepSaveStatus,
    );
  }

  void markStepSyncFailed(int step, {required String message}) {
    final dirty = _setStepValue(state.draft.stepDirty, step, true);
    final loading = _setStepValue(state.draft.stepLoading, step, false);
    state = state.copyWith(
      draft: state.draft.copyWith(stepDirty: dirty, stepLoading: loading),
      stepDirty: dirty,
      stepLoading: loading,
      stepSaveStatus: _setSaveStatus(
        state.stepSaveStatus,
        step,
        SaveSyncStatus.failed,
      ),
      validationMessage: message,
    );
  }

  void markStepSaving(int step) {
    state = state.copyWith(
      stepSaveStatus: _setSaveStatus(
        state.stepSaveStatus,
        step,
        SaveSyncStatus.saving,
      ),
    );
  }

  bool acknowledgeDraftSync({
    required int step,
    required int submittedRevision,
  }) {
    if (state.draft.revision != submittedRevision) {
      state = state.copyWith(
        stepSaveStatus: _setSaveStatus(
          state.stepSaveStatus,
          step,
          SaveSyncStatus.dirty,
        ),
      );
      return false;
    }
    state = state.copyWith(
      stepSaveStatus: _setSaveStatus(
        state.stepSaveStatus,
        step,
        SaveSyncStatus.synced,
      ),
      clearValidation: true,
    );
    return true;
  }

  /// Acknowledges only the exact draft revision submitted by the save.
  /// Newer in-memory edits remain visible and dirty.
  bool acknowledgeStepSave({
    required int step,
    required int submittedRevision,
    required OnboardingDraft savedDraft,
  }) {
    if (state.draft.revision != submittedRevision) {
      final dirty = _setStepValue(state.draft.stepDirty, step, true);
      state = state.copyWith(
        draft: state.draft.copyWith(stepDirty: dirty),
        stepDirty: dirty,
        stepSaveStatus: _setSaveStatus(
          state.stepSaveStatus,
          step,
          SaveSyncStatus.dirty,
        ),
        validationMessage:
            'Your latest changes still need to sync. Retry before leaving this step.',
      );
      return false;
    }

    state = state.copyWith(
      draft: savedDraft,
      stepSaveStatus: _setSaveStatus(
        state.stepSaveStatus,
        step,
        SaveSyncStatus.synced,
      ),
      clearValidation: true,
    );
    return true;
  }

  void setValidationMessage(String? msg) {
    state = state.copyWith(validationMessage: msg);
  }

  void clearValidation() {
    state = state.copyWith(clearValidation: true);
  }

  void updateDraft(OnboardingDraft Function(OnboardingDraft draft) update) {
    state = state.copyWith(
      draft: update(state.draft),
      // Keep a sync failure visible while the user continues editing the
      // in-memory draft. A retry (or successful acknowledgement) clears it.
      clearValidation: !state.stepSaveStatus.contains(SaveSyncStatus.failed),
    );
  }

  void setDraft(OnboardingDraft draft) {
    state = state.copyWith(draft: draft, clearValidation: true);
  }

  void saveFinalPreview() {
    final now = DateTime.now();
    state = state.copyWith(
      draft: state.draft.copyWith(
        finalPreview: state.draft.buildFinalPreview(),
        createdAt: state.draft.createdAt ?? now,
        updatedAt: now,
      ),
      clearValidation: true,
    );
  }

  void saveStep(
    int step, {
    required String uid,
    OnboardingDraft Function(OnboardingDraft draft)? transform,
  }) {
    final now = DateTime.now();
    var draft = transform == null ? state.draft : transform(state.draft);
    final completed = _setStepValue(draft.stepCompleted, step, true);
    final dirty = _setStepValue(draft.stepDirty, step, false);
    final loading = _setStepValue(draft.stepLoading, step, false);
    draft = draft.copyWith(
      uid: uid.isEmpty ? draft.uid : uid,
      currentStep: step,
      stepCompleted: completed,
      stepDirty: dirty,
      stepLoading: loading,
      createdAt: draft.createdAt ?? now,
      updatedAt: now,
    );
    state = state.copyWith(draft: draft, clearValidation: true);
  }

  void completeOnboarding({required String uid}) {
    final now = DateTime.now();
    final completed = List<bool>.filled(OnboardingDraft.stepCount, true);
    final dirty = List<bool>.filled(OnboardingDraft.stepCount, false);
    final loading = List<bool>.filled(OnboardingDraft.stepCount, false);
    final preview = state.draft.finalPreview ?? state.draft.buildFinalPreview();
    state = state.copyWith(
      draft: state.draft.copyWith(
        uid: uid.isEmpty ? state.draft.uid : uid,
        currentStep: OnboardingDraft.lastStepIndex,
        stepCompleted: completed,
        stepDirty: dirty,
        stepLoading: loading,
        finalPreview: preview,
        onboardingCompleted: true,
        createdAt: state.draft.createdAt ?? now,
        updatedAt: now,
      ),
      clearValidation: true,
    );
  }

  List<String> updateLifeRoleSelection(String roleKey) {
    final invalidation = state.draft.baseTimeline.invalidateForRole(roleKey);

    // Clear class and work blocks from the timeline (Step 4 is invalidated)
    final cleanBlocks = invalidation.timeline.blocks
        .where((block) {
          return block.section != 'classes' &&
              block.section != 'job_work_business';
        })
        .toList(growable: false);

    // Clear pending future imports for classes and work
    final cleanPendingImports = invalidation.timeline.pendingFutureImports
        .where((entry) {
          return entry.section != 'classes' &&
              entry.section != 'job_work_business';
        })
        .toList(growable: false);

    var nextTimeline = invalidation.timeline.copyWith(
      blocks: cleanBlocks,
      pendingFutureImports: cleanPendingImports,
      classJobSetupStep: 0,
    );

    // Local Step 5 revalidation (preserve if valid, clear if invalid)
    final eatingError = nextTimeline.validateEatingSetup();
    if (eatingError != null) {
      nextTimeline = nextTimeline.copyWith(
        blocks: nextTimeline.blocks
            .where((block) => block.section != 'eating')
            .toList(growable: false),
        eatingSetupStep: 0,
      );
    }

    final nextDraft = state.draft.copyWith(
      lifeRole: state.draft.lifeRole.copyWith(
        lifeRole: roleKey,
        clearWorkType:
            roleKey != LifeRoleDraft.workingKey &&
            roleKey != LifeRoleDraft.studentWorkingKey,
        clearBusinessMode: roleKey != LifeRoleDraft.businessKey,
      ),
      baseTimeline: nextTimeline,
      clearFinalPreview: true,
    );

    final completed = List<bool>.from(state.draft.stepCompleted);
    final dirty = List<bool>.from(state.draft.stepDirty);

    // A role tap is input, not durable completion. Dynamic role fields still
    // need validation and an explicit Next/save before Step 3 is unlocked.
    completed[2] = false;
    dirty[2] = true;

    // Step 4 is cleared, so it is incomplete and dirty
    completed[onboardingClassJobStepIndex] = false;
    dirty[onboardingClassJobStepIndex] = true;

    // Step 5 is preserved if valid and was completed, otherwise marked incomplete/dirty
    completed[onboardingEatingStepIndex] =
        eatingError == null && completed[onboardingEatingStepIndex];
    dirty[onboardingEatingStepIndex] =
        eatingError != null || dirty[onboardingEatingStepIndex];

    // Downstream steps (> 5) are invalidated (marked incomplete and dirty)
    for (
      var i = onboardingEatingStepIndex + 1;
      i < OnboardingDraft.stepCount;
      i++
    ) {
      completed[i] = false;
      dirty[i] = true;
    }

    state = state.copyWith(
      draft: nextDraft.copyWith(stepCompleted: completed, stepDirty: dirty),
      validationMessage: invalidation.warnings.isEmpty
          ? null
          : invalidation.warnings.join(' '),
    );
    return invalidation.warnings;
  }

  static List<bool> _setStepValue(List<bool> source, int step, bool value) {
    final list = List<bool>.generate(
      OnboardingDraft.stepCount,
      (index) => index < source.length ? source[index] : false,
    );
    if (step >= 0 && step < list.length) {
      list[step] = value;
    }
    return list;
  }

  static List<SaveSyncStatus> _setSaveStatus(
    List<SaveSyncStatus> source,
    int step,
    SaveSyncStatus value,
  ) {
    final list = List<SaveSyncStatus>.generate(
      OnboardingDraft.stepCount,
      (index) => index < source.length ? source[index] : SaveSyncStatus.clean,
    );
    if (step >= 0 && step < list.length) list[step] = value;
    return list;
  }
}

final mockOnboardingProvider =
    StateNotifierProvider<MockOnboardingNotifier, OnboardingState>((ref) {
      return MockOnboardingNotifier();
    });

final onboardingDraftProvider = Provider<OnboardingDraft>((ref) {
  return ref.watch(mockOnboardingProvider.select((state) => state.draft));
});
