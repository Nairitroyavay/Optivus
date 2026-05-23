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
import 'package:optivus/models/onboarding_state.dart';
import 'package:optivus/state/mock_seed_data.dart';

// ==========================================
// 1. User Profile State Notifier
// ==========================================
class MockUserProfileNotifier extends StateNotifier<UserProfile> {
  MockUserProfileNotifier() : super(MockSeedData.defaultUserProfile);

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
    final double bmi = wKg / (hMeters * hMeters);
    final double calories = wKg * 24.0 * 1.3; // Simple Harris-Benedict representation
    final double protein = wKg * 2.0;

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
    state = state.copyWith(hasCompletedOnboarding: true);
  }
}

final mockUserProfileProvider = StateNotifierProvider<MockUserProfileNotifier, UserProfile>((ref) {
  return MockUserProfileNotifier();
});

// ==========================================
// 2. Routine Items State Notifier
// ==========================================
class MockRoutineNotifier extends StateNotifier<List<RoutineItem>> {
  MockRoutineNotifier() : super(MockSeedData.defaultRoutineItems);

  void addRoutineItem(RoutineItem item) {
    state = [...state, item];
    _checkConflicts();
  }

  void updateRoutineItem(RoutineItem updatedItem) {
    state = [
      for (final item in state)
        if (item.id == updatedItem.id) updatedItem else item
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
        if (item.id == routineId && item.subtasks != null && item.subtasksCompleted != null)
          item.copyWith(
            subtasksCompleted: [
              for (int i = 0; i < item.subtasksCompleted!.length; i++)
                if (i == index) !item.subtasksCompleted![i] else item.subtasksCompleted![i]
            ],
          )
        else
          item
    ];
  }

  void toggleRoutineCompleted(String routineId) {
    state = [
      for (final item in state)
        if (item.id == routineId) item.copyWith(isCompleted: !item.isCompleted, isMissed: false) else item
    ];
  }

  void toggleRoutineMissed(String routineId) {
    state = [
      for (final item in state)
        if (item.id == routineId) item.copyWith(isMissed: !item.isMissed, isCompleted: false) else item
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
        final bool overlap = (a.startMinute < b.endMinute && a.endMinute > b.startMinute);
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

final mockRoutineProvider = StateNotifierProvider<MockRoutineNotifier, List<RoutineItem>>((ref) {
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

  MockTrackerState({
    required this.hydrationLogs,
    required this.fitnessActivities,
    required this.screenTimeApps,
    required this.trackerSessions,
    required this.moneyGoal,
    required this.savingsEntries,
  });

  MockTrackerState copyWith({
    List<HydrationLog>? hydrationLogs,
    List<FitnessActivity>? fitnessActivities,
    List<ScreenTimeApp>? screenTimeApps,
    List<TrackerSession>? trackerSessions,
    MoneyGoal? moneyGoal,
    List<SavingEntry>? savingsEntries,
  }) {
    return MockTrackerState(
      hydrationLogs: hydrationLogs ?? this.hydrationLogs,
      fitnessActivities: fitnessActivities ?? this.fitnessActivities,
      screenTimeApps: screenTimeApps ?? this.screenTimeApps,
      trackerSessions: trackerSessions ?? this.trackerSessions,
      moneyGoal: moneyGoal ?? this.moneyGoal,
      savingsEntries: savingsEntries ?? this.savingsEntries,
    );
  }
}

class MockTrackerNotifier extends StateNotifier<MockTrackerState> {
  MockTrackerNotifier()
      : super(MockTrackerState(
          hydrationLogs: MockSeedData.defaultHydrationLogs,
          fitnessActivities: MockSeedData.defaultFitnessActivities,
          screenTimeApps: MockSeedData.defaultScreenTimeApps,
          trackerSessions: MockSeedData.defaultTrackerSessions,
          moneyGoal: MockSeedData.defaultMoneyGoal,
          savingsEntries: MockSeedData.defaultSavingEntries,
        ));

  void logHydration(int ml) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    final log = HydrationLog(
      id: 'w-${state.hydrationLogs.length + 1}',
      amountMl: ml,
      timestamp: timeStr,
    );
    state = state.copyWith(
      hydrationLogs: [...state.hydrationLogs, log],
    );
  }

  void resetHydration() {
    state = state.copyWith(hydrationLogs: []);
  }

  void addFitnessActivity(FitnessActivity activity) {
    state = state.copyWith(
      fitnessActivities: [...state.fitnessActivities, activity],
    );
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
            app
      ],
    );
  }

  void logSaving(double amount, String description, {bool isConfirmed = false}) {
    final entry = SavingEntry(
      id: 's-${state.savingsEntries.length + 1}',
      amount: amount,
      timestamp: 'Today',
      description: description,
      isConfirmed: isConfirmed,
    );

    double addConfirmed = isConfirmed ? amount : 0.0;
    double addPotential = !isConfirmed ? amount : 0.0;

    final updatedGoal = state.moneyGoal.copyWith(
      totalConfirmedSaved: state.moneyGoal.totalConfirmedSaved + addConfirmed,
      totalPotentialSaved: state.moneyGoal.totalPotentialSaved + addPotential,
    );

    state = state.copyWith(
      savingsEntries: [...state.savingsEntries, entry],
      moneyGoal: updatedGoal,
    );
  }

  void confirmSaving(String entryId) {
    double confirmAmount = 0.0;
    
    // Find the item first to get its amount safely outside the list literal
    for (final entry in state.savingsEntries) {
      if (entry.id == entryId && !entry.isConfirmed) {
        confirmAmount = entry.amount;
        break;
      }
    }

    if (confirmAmount > 0.0) {
      final updatedEntries = [
        for (final entry in state.savingsEntries)
          if (entry.id == entryId)
            SavingEntry(
              id: entry.id,
              amount: entry.amount,
              timestamp: entry.timestamp,
              description: entry.description,
              isConfirmed: true,
            )
          else
            entry
      ];

      final updatedGoal = state.moneyGoal.copyWith(
        totalConfirmedSaved: state.moneyGoal.totalConfirmedSaved + confirmAmount,
        totalPotentialSaved: (state.moneyGoal.totalPotentialSaved - confirmAmount).clamp(0, double.infinity),
        streakDays: state.moneyGoal.streakDays + 1,
      );

      state = state.copyWith(
        savingsEntries: updatedEntries,
        moneyGoal: updatedGoal,
      );
    }
  }
}

final mockTrackerProvider = StateNotifierProvider<MockTrackerNotifier, MockTrackerState>((ref) {
  return MockTrackerNotifier();
});

// ==========================================
// 4. Goals Focus State Notifier
// ==========================================
class MockGoalNotifier extends StateNotifier<List<GoalModel>> {
  MockGoalNotifier() : super(MockSeedData.defaultGoals);

  void addGoal(GoalModel goal) {
    state = [...state, goal];
  }

  void toggleGoalProofCompleted(String goalId) {
    state = [
      for (final goal in state)
        if (goal.id == goalId)
          goal.copyWith(
            dailyProof: goal.dailyProof.copyWith(isCompleted: !goal.dailyProof.isCompleted),
            streakDays: goal.dailyProof.isCompleted ? (goal.streakDays - 1).clamp(0, 999) : goal.streakDays + 1,
            progressPercent: goal.dailyProof.isCompleted
                ? (goal.progressPercent - 0.05).clamp(0.0, 1.0)
                : (goal.progressPercent + 0.05).clamp(0.0, 1.0),
          )
        else
          goal
    ];
  }

  void changeGoalProofDifficulty(String goalId, String difficulty) {
    state = [
      for (final goal in state)
        if (goal.id == goalId)
          goal.copyWith(
            dailyProof: goal.dailyProof.copyWith(selectedDifficulty: difficulty),
          )
        else
          goal
    ];
  }

  void updateGoalProofNote(String goalId, String note) {
    state = [
      for (final goal in state)
        if (goal.id == goalId)
          goal.copyWith(
            dailyProof: goal.dailyProof.copyWith(note: note),
          )
        else
          goal
    ];
  }
}

final mockGoalProvider = StateNotifierProvider<MockGoalNotifier, List<GoalModel>>((ref) {
  return MockGoalNotifier();
});

// ==========================================
// 5. Mind Notes State Notifier
// ==========================================
class MockMindNoteNotifier extends StateNotifier<List<MindNote>> {
  MockMindNoteNotifier() : super(MockSeedData.defaultMindNotes);

  void addMindNote(String content, MindNoteType type, MindNoteIntensity intensity) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
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
        if (note.id == id) note.copyWith(isSharedWithCoach: !note.isSharedWithCoach) else note
    ];
  }
}

final mockMindNoteProvider = StateNotifierProvider<MockMindNoteNotifier, List<MindNote>>((ref) {
  return MockMindNoteNotifier();
});

// ==========================================
// 6. AI Coach Sessions State Notifier
// ==========================================
class MockCoachNotifier extends StateNotifier<List<CoachSession>> {
  MockCoachNotifier() : super(MockSeedData.defaultCoachSessions);

  void sendMessage(String sessionId, String content) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

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
          session
    ];

    // Trigger mock AI response after 1.5 seconds delay
    Timer(const Duration(milliseconds: 1500), () {
      _generateCoachReply(sessionId, content);
    });
  }

  void createNewSession(String title, CoachSessionType type, String coachName, String coachStyle) {
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
          content: 'Hello! I am your AI Coach $coachName. I look forward to working with you under my $coachStyle philosophy. What is currently on your mind?',
          timestamp: 'Just now',
        )
      ],
    );
    state = [session, ...state];
  }

  void _generateCoachReply(String sessionId, String userContent) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    String reply = '';
    List<CoachResponseBlock> blocks = [];

    // Simple keyword mapping to create an amazingly smart visual dashboard simulation
    final lower = userContent.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi')) {
      reply = 'Greetings! How is your day proceeding? I am ready to audit your timeline, track hydration goals, or help you wind down.';
    } else if (lower.contains('tired') || lower.contains('missed') || lower.contains('skip')) {
      reply = 'Fatigue is a real biological trigger. Don\'t stress about breaking a hard routine. We can dynamically adapt. I recommend triggering the "Tiny" daily proof adjustment for your Gym goals so your streak remains unbroken!';
      blocks = [
        CoachResponseBlock(
          type: CoachResponseBlockType.routineSuggestionCard,
          heading: 'Pivot Gym Workout',
          body: 'Adapt Gym Workout block start time or limit to 15m home routine.',
          buttonLabel: 'Adapt Now',
          payload: 'pivot_routine',
        )
      ];
    } else if (lower.contains('water') || lower.contains('hydrate')) {
      reply = 'Hydration levels affect cognitive processing directly. You have logged several hydration milestones today. I suggest adding another 250ml now to stay on pace!';
      blocks = [
        CoachResponseBlock(
          type: CoachResponseBlockType.trackerActionCard,
          heading: 'Water Tracker Log',
          body: 'Quick log 250ml of water right from this card.',
          buttonLabel: '+250ml Water',
          payload: 'water_250',
        )
      ];
    } else if (lower.contains('goal') || lower.contains('gym') || lower.contains('workout')) {
      reply = 'Your systems shape your outcomes. Your "Sleek & Strong Athlete" identity currently has a 12-day streak. Complete your daily Gym proof to add to the multiplier!';
      blocks = [
        CoachResponseBlock(
          type: CoachResponseBlockType.goalProofCard,
          heading: 'Daily Gym Proof',
          body: 'Complete Gym compound lifts daily proof to maintain streak.',
          buttonLabel: 'Verify Gym Proof',
          payload: 'verify_proof_body',
        )
      ];
    } else if (lower.contains('overthinking') || lower.contains('stress') || lower.contains('mind')) {
      reply = 'Overthinking triggers cortisol releases. I recommend writing down whatever is running in your mind right into our Mind Notebook. I will automatically classify it for you to clear cognitive RAM.';
      blocks = [
        CoachResponseBlock(
          type: CoachResponseBlockType.mindNoteCard,
          heading: 'Dump Overthinking Thoughts',
          body: 'Open your notebook timeline to classify and shelf mental clutter.',
          buttonLabel: 'Open Notebook',
          payload: 'open_notebook',
        )
      ];
    } else {
      reply = 'I understand. Let\'s review your routine timeline and find ways to build robust habit consistency. Would you like me to suggest some minor schedule optimizations?';
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
          session
    ];
  }
}

final mockCoachProvider = StateNotifierProvider<MockCoachNotifier, List<CoachSession>>((ref) {
  return MockCoachNotifier();
});

class MockCoachPreferencesNotifier extends StateNotifier<CoachPreferences> {
  MockCoachPreferencesNotifier() : super(CoachPreferences());

  void updatePreferences(CoachPreferences prefs) {
    state = prefs;
  }
}

final mockCoachPreferencesProvider = StateNotifierProvider<MockCoachPreferencesNotifier, CoachPreferences>((ref) {
  return MockCoachPreferencesNotifier();
});

// ==========================================
// 7. Notification Preferences Notifier
// ==========================================
class MockNotificationPreferencesNotifier extends StateNotifier<NotificationPreferences> {
  MockNotificationPreferencesNotifier() : super(NotificationPreferences());

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
    StateNotifierProvider<MockNotificationPreferencesNotifier, NotificationPreferences>((ref) {
  return MockNotificationPreferencesNotifier();
});

// ==========================================
// 8. Permissions Status State Notifier
// ==========================================
class MockPermissionNotifier extends StateNotifier<PermissionStatus> {
  MockPermissionNotifier() : super(PermissionStatus());

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

final mockPermissionProvider = StateNotifierProvider<MockPermissionNotifier, PermissionStatus>((ref) {
  return MockPermissionNotifier();
});

// ==========================================
// 9. Onboarding State Notifier
// ==========================================
class MockOnboardingNotifier extends StateNotifier<OnboardingState> {
  MockOnboardingNotifier() : super(OnboardingState());

  void setStep(int step) {
    state = state.copyWith(currentStep: step, clearValidation: true);
  }

  void setStepCompleted(int step, bool completed) {
    final list = List<bool>.from(state.stepCompleted);
    list[step] = completed;
    state = state.copyWith(stepCompleted: list);
  }

  void setStepDirty(int step, bool dirty) {
    final list = List<bool>.from(state.stepDirty);
    list[step] = dirty;
    state = state.copyWith(stepDirty: list);
  }

  void setStepLoading(int step, bool loading) {
    final list = List<bool>.from(state.stepLoading);
    list[step] = loading;
    state = state.copyWith(stepLoading: list);
  }

  void setValidationMessage(String? msg) {
    state = state.copyWith(validationMessage: msg);
  }

  void clearValidation() {
    state = state.copyWith(clearValidation: true);
  }
}

final mockOnboardingProvider = StateNotifierProvider<MockOnboardingNotifier, OnboardingState>((ref) {
  return MockOnboardingNotifier();
});
