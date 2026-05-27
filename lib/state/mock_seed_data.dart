import 'package:optivus/models/user_profile.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/models/mind_note.dart';
import 'package:optivus/models/money_models.dart';

class MockSeedData {
  static UserProfile get defaultUserProfile => UserProfile(
    uid: 'mock-user-123',
    email: 'roy@optivus.app',
    displayName: 'Roy',
    lifeRole: '',
    workingExtra: null,
    businessMode: null,
    exerciseLevel: '',
    waterIntake: '',
    stressLevel: '',
    sleepQuality: '',
    ageRange: '',
    height: 0.0,
    weight: 0.0,
    gender: '',
    bmiEstimate: 0.0,
    calorieEstimate: 0.0,
    proteinEstimate: 0.0,
    onboardingCompleted: false,
    onboardingStep: 0,
    coachName: '',
    coachStyle: '',
    slipUpStyle: '',
  );

  // ── Blueprint sample routine data ─────────────────────────
  static List<RoutineItem> get defaultRoutineItems => [
    RoutineItem(
      id: 'routine-bath',
      title: 'Bath',
      startMinute: 435, // 7:15 AM
      endMinute: 455, // 7:35 AM
      blockType: RoutineBlockType.hardBlock,
      category: RoutineCategory.fixed,
      source: RoutineSource.onboarding,
      priority: RoutinePriority.mustDo,
      hardBlock: true,
      notes: 'Morning bath routine.',
    ),
    RoutineItem(
      id: 'routine-morning-skincare',
      title: 'Morning Skin Care',
      startMinute: 455, // 7:35 AM
      endMinute: 460, // 7:40 AM
      blockType: RoutineBlockType.softBlock,
      category: RoutineCategory.skinCare,
      source: RoutineSource.onboarding,
      steps: ['Face wash', 'Vitamin C', 'Sunscreen'],
      skincareProducts: ['Face wash', 'Vitamin C', 'Sunscreen'],
      notes: '3-step morning routine.',
    ),
    RoutineItem(
      id: 'routine-meditation',
      title: 'Meditation',
      startMinute: 460, // 7:40 AM
      endMinute: 465, // 7:45 AM
      blockType: RoutineBlockType.trackerTask,
      category: RoutineCategory.health,
      source: RoutineSource.onboarding,
      isTrackerLinked: true,
      trackerType: TrackerType.meditation,
      priority: RoutinePriority.mustDo,
      notes: 'Morning mindfulness session.',
    ),
    RoutineItem(
      id: 'routine-breakfast',
      title: 'Breakfast',
      startMinute: 480, // 8:00 AM
      endMinute: 510, // 8:30 AM
      blockType: RoutineBlockType.softBlock,
      category: RoutineCategory.eating,
      source: RoutineSource.onboarding,
      mealCategory: 'Breakfast',
      dishes: ['Bread', 'Egg', 'Banana'],
      caloriesEstimate: 520.0,
      proteinEstimate: 22.0,
      notes: 'Morning fuel.',
    ),
    RoutineItem(
      id: 'routine-class',
      title: 'Class',
      startMinute: 540, // 9:00 AM
      endMinute: 1020, // 5:00 PM
      blockType: RoutineBlockType.hardBlock,
      category: RoutineCategory.classBlock,
      source: RoutineSource.onboarding,
      priority: RoutinePriority.mustDo,
      hardBlock: true,
      location: 'Engineering Block',
      notes: 'University lectures and lab.',
    ),
    RoutineItem(
      id: 'routine-lunch',
      title: 'Lunch',
      startMinute: 780, // 1:00 PM
      endMinute: 810, // 1:30 PM
      blockType: RoutineBlockType.softBlock,
      category: RoutineCategory.eating,
      source: RoutineSource.onboarding,
      mealCategory: 'Lunch',
      dishes: ['Rice', 'Dal', 'Sabji', 'Chicken curry', 'Curd'],
      caloriesEstimate: 720.0,
      proteinEstimate: 28.0,
      allowOverlap: true,
      notes: 'Lunch break during class.',
    ),
    RoutineItem(
      id: 'routine-gym',
      title: 'Gym',
      startMinute: 1110, // 6:30 PM
      endMinute: 1155, // 7:15 PM
      blockType: RoutineBlockType.trackerTask,
      category: RoutineCategory.health,
      source: RoutineSource.onboarding,
      isTrackerLinked: true,
      trackerType: TrackerType.workout,
      priority: RoutinePriority.mustDo,
      subtasks: [
        'Warmup stretching',
        'Bench Press: 4x8',
        'Overhead Press: 3x10',
        'Tricep Pushdowns: 3x12',
      ],
      subtasksCompleted: [false, false, false, false],
      location: 'Powerhouse Gym',
      notes: 'Push Day: Chest, Shoulders, and Triceps.',
    ),
    RoutineItem(
      id: 'routine-dinner',
      title: 'Dinner',
      startMinute: 1260, // 9:00 PM
      endMinute: 1290, // 9:30 PM
      blockType: RoutineBlockType.softBlock,
      category: RoutineCategory.eating,
      source: RoutineSource.onboarding,
      mealCategory: 'Dinner',
      dishes: ['Rice', 'Dal', 'Sabji'],
      caloriesEstimate: 620.0,
      proteinEstimate: 18.0,
      notes: 'Evening meal.',
    ),
    RoutineItem(
      id: 'routine-save-money',
      title: 'Save ₹10',
      startMinute: 1305, // 9:45 PM
      endMinute: 1310, // 9:50 PM
      blockType: RoutineBlockType.moneyTask,
      category: RoutineCategory.finance,
      source: RoutineSource.onboarding,
      isTrackerLinked: true,
      trackerType: TrackerType.money,
      notes: 'Financially Free • Money System',
    ),
    RoutineItem(
      id: 'routine-smoking-checkin',
      title: 'Cigarettes',
      startMinute: 1320, // 10:00 PM
      endMinute: 1325, // 10:05 PM
      blockType: RoutineBlockType.checkIn,
      category: RoutineCategory.health,
      source: RoutineSource.onboarding,
      notes: 'Check-in: Did you avoid smoking today?',
    ),
    RoutineItem(
      id: 'routine-reading',
      title: 'Reading',
      startMinute: 1335, // 10:15 PM
      endMinute: 1350, // 10:30 PM
      blockType: RoutineBlockType.flexibleTask,
      category: RoutineCategory.habit,
      source: RoutineSource.manual,
      priority: RoutinePriority.goodToDo,
      subtasks: [
        'Revise stack',
        'Solve 1 problem',
        'Review solution',
      ],
      subtasksCompleted: [false, false, false],
      notes: 'DSA practice session.',
    ),
    RoutineItem(
      id: 'routine-night-skincare',
      title: 'Night Skin Care',
      startMinute: 1390, // 11:10 PM
      endMinute: 1395, // 11:15 PM
      blockType: RoutineBlockType.softBlock,
      category: RoutineCategory.skinCare,
      source: RoutineSource.onboarding,
      steps: ['Cleanser', 'Serum', 'Moisturizer'],
      skincareProducts: ['Cleanser', 'Serum', 'Moisturizer'],
      notes: 'Night skin care routine.',
    ),
    RoutineItem(
      id: 'routine-sleep',
      title: 'Sleep',
      startMinute: 1350, // 10:30 PM
      endMinute: 450, // 7:30 AM next day
      blockType: RoutineBlockType.hardBlock,
      category: RoutineCategory.sleep,
      source: RoutineSource.onboarding,
      priority: RoutinePriority.mustDo,
      hardBlock: true,
      crossesMidnight: true,
      endsNextDay: true,
      notes: 'Sleep and night recovery.',
    ),
  ];

  static List<HydrationLog> get defaultHydrationLogs => [
    HydrationLog(id: 'w-1', amountMl: 250, timestamp: '08:15 AM'),
    HydrationLog(id: 'w-2', amountMl: 500, timestamp: '11:30 AM'),
    HydrationLog(id: 'w-3', amountMl: 250, timestamp: '03:45 PM'),
    HydrationLog(id: 'w-4', amountMl: 500, timestamp: '06:15 PM'),
  ];

  static List<FitnessActivity> get defaultFitnessActivities => [
    FitnessActivity(
      id: 'fit-1',
      type: 'Run',
      distanceKm: 5.2,
      durationSeconds: 1680, // 28 minutes
      paceMinutesPerKm: 5.38,
      caloriesBurned: 410,
      route: [
        RoutePoint(
          latitude: 12.9716,
          longitude: 77.5946,
          timestamp: '05:01 PM',
        ),
        RoutePoint(
          latitude: 12.9725,
          longitude: 77.5955,
          timestamp: '05:08 PM',
        ),
        RoutePoint(
          latitude: 12.9738,
          longitude: 77.5970,
          timestamp: '05:15 PM',
        ),
        RoutePoint(
          latitude: 12.9750,
          longitude: 77.5960,
          timestamp: '05:22 PM',
        ),
        RoutePoint(
          latitude: 12.9716,
          longitude: 77.5946,
          timestamp: '05:29 PM',
        ),
      ],
    ),
    FitnessActivity(
      id: 'fit-2',
      type: 'Walk',
      distanceKm: 2.5,
      durationSeconds: 1500, // 25 minutes
      paceMinutesPerKm: 10.0,
      caloriesBurned: 150,
    ),
  ];

  static List<ScreenTimeApp> get defaultScreenTimeApps => [
    ScreenTimeApp(
      name: 'Instagram',
      packageName: 'com.instagram.android',
      durationMinutes: 112,
      distractionRisk: 'High',
    ),
    ScreenTimeApp(
      name: 'YouTube',
      packageName: 'com.google.android.youtube',
      durationMinutes: 78,
      distractionRisk: 'Medium',
    ),
    ScreenTimeApp(
      name: 'VS Code',
      packageName: 'com.microsoft.vscode',
      durationMinutes: 240,
      distractionRisk: 'Low',
    ),
    ScreenTimeApp(
      name: 'WhatsApp',
      packageName: 'com.whatsapp',
      durationMinutes: 42,
      distractionRisk: 'Low',
    ),
  ];

  static List<TrackerSession> get defaultTrackerSessions => [
    TrackerSession(
      id: 'session-1',
      category: 'Mind',
      title: 'Daily Evening Meditation',
      timestamp: DateTime.now().subtract(const Duration(hours: 14)),
      value: 30,
    ),
    TrackerSession(
      id: 'session-2',
      category: 'Body',
      title: '5K Sunset Run Simulator',
      timestamp: DateTime.now().subtract(const Duration(hours: 18)),
      value: 28,
    ),
    TrackerSession(
      id: 'session-3',
      category: 'Finance',
      title: 'Automated Bad Habit Intercept',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      value: 10,
    ),
  ];

  static MoneyGoal get defaultMoneyGoal => MoneyGoal(
    id: 'money-goal-1',
    dailyTarget: 10.0,
    totalConfirmedSaved: 80.0,
    totalPotentialSaved: 40.0,
    streakDays: 8,
    streakLevel: 2,
  );

  static List<SavingEntry> get defaultSavingEntries => [
    SavingEntry(
      id: 's-1',
      amount: 10.0,
      timestamp: 'May 18, 2026',
      description: 'Avoided vending machine soda',
      isConfirmed: true,
    ),
    SavingEntry(
      id: 's-2',
      amount: 10.0,
      timestamp: 'May 19, 2026',
      description: 'Brewed coffee at home',
      isConfirmed: true,
    ),
    SavingEntry(
      id: 's-3',
      amount: 20.0,
      timestamp: 'May 20, 2026',
      description: 'Skipped premium food delivery upgrade',
      isConfirmed: true,
    ),
    SavingEntry(
      id: 's-4',
      amount: 10.0,
      timestamp: 'May 21, 2026',
      description: 'Walked instead of booking auto rickshaw',
      isConfirmed: true,
    ),
    SavingEntry(
      id: 's-5',
      amount: 30.0,
      timestamp: 'May 22, 2026',
      description: 'Intercepted Impulse Buying Trigger',
      isConfirmed: false,
    ),
  ];

  static List<GoalModel> get defaultGoals => [
    GoalModel(
      id: 'goal-body',
      identityTitle: 'Sleek & Strong Athlete',
      purposeStatement:
          'To feel highly energetic, build skeletal protection, and keep focus at maximum.',
      progressPercent: 0.65,
      systems: [
        GoalSystem(
          id: 'sys-body-1',
          description: 'Strength workouts 4 times per week',
          linkedRoutineTaskIds: ['routine-gym'],
        ),
        GoalSystem(
          id: 'sys-body-2',
          description: 'Consume 140g protein daily',
          linkedRoutineTaskIds: ['routine-breakfast', 'routine-dinner'],
        ),
      ],
      dailyProof: GoalProof(
        id: 'proof-body',
        title: 'Physical Proof of Identity',
        tinyVersion: '15 Push-ups in morning',
        normalVersion: '45-min weight training session',
        strongVersion: '90-min heavy compound lifts & stretch',
        selectedDifficulty: 'normal',
        isCompleted: false,
      ),
      streakDays: 12,
    ),
    GoalModel(
      id: 'goal-mind',
      identityTitle: 'Mindful Architect of Focus',
      purposeStatement:
          'To replace cheap scrolling dopamine with structured deep cognitive presence.',
      progressPercent: 0.40,
      systems: [
        GoalSystem(
          id: 'sys-mind-1',
          description: 'Wind-down breathing practice',
          linkedRoutineTaskIds: ['routine-meditation'],
        ),
      ],
      dailyProof: GoalProof(
        id: 'proof-mind',
        title: 'Cognitive Proof of Identity',
        tinyVersion: '5 minutes of box breathing',
        normalVersion: '20 minutes seated vipassana',
        strongVersion: '45 minutes deep mindfulness or reflection',
        selectedDifficulty: 'normal',
        isCompleted: true,
      ),
      streakDays: 4,
    ),
  ];

  static List<MindNote> get defaultMindNotes => [
    MindNote(
      id: 'note-1',
      content:
          'Feeling slightly overwhelmed by the semester exams approaching. Hard to focus in the evening block.',
      type: MindNoteType.overthinking,
      intensity: MindNoteIntensity.medium,
      timestamp: '10:15 AM',
      isSharedWithCoach: true,
    ),
    MindNote(
      id: 'note-2',
      content:
          'Idea: Build a personalized productivity widget that links to haptic alerts.',
      type: MindNoteType.idea,
      intensity: MindNoteIntensity.low,
      timestamp: '02:30 PM',
      isSharedWithCoach: false,
    ),
  ];

  static List<CoachSession> get defaultCoachSessions => [
    CoachSession(
      id: 'session-chat-default',
      title: 'Habit Realignment & Focus',
      type: CoachSessionType.todayPlan,
      coachName: 'Sensei',
      coachStyle: 'Supportive',
      createdAt: 'May 22, 2026 10:00 AM',
      messages: [
        CoachMessage(
          id: 'm-1',
          isFromCoach: true,
          content:
              'Greetings Roy! I have prepared your morning dashboard. Your day is organized into key blocks. We have a non-negotiable University Block from 10:00 AM to 4:00 PM. How are you feeling about committing to your Gym Workout at 5:00 PM today?',
          timestamp: '10:00 AM',
        ),
        CoachMessage(
          id: 'm-2',
          isFromCoach: false,
          content:
              'I feel a bit tired but determined to complete the Gym block.',
          timestamp: '10:02 AM',
        ),
        CoachMessage(
          id: 'm-3',
          isFromCoach: true,
          content:
              'Excellent resilience. If energy is low, we can pivot to the "Tiny" version of your workout goal: just a warm-up and 15 push-ups. Remember, showing up keeps the identity streak active. Shall I activate the Tiny alternative for today?',
          timestamp: '10:03 AM',
          blocks: [
            CoachResponseBlock(
              type: CoachResponseBlockType.routineSuggestionCard,
              heading: 'Gym Push Session Alternative',
              body:
                  'Pivot Gym Workout block from Normal (45m) to Tiny (15m push-ups at home). Keeps Gym streak safe!',
              buttonLabel: 'Accept Alternative',
              payload: 'pivot_tiny',
            ),
          ],
        ),
      ],
    ),
  ];
}
