import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/state/app_state.dart';

const fitnessMapStyles = [
  FitnessMapStyle(
    id: 'mapbox://styles/nairitroy/cmozyqm88000c01r14o8h7bn0',
    label: 'Coral',
  ),
  FitnessMapStyle(
    id: 'mapbox://styles/nairitroy/cmp006knu000e01r17cgd61pj',
    label: 'Mono Light',
  ),
  FitnessMapStyle(
    id: 'mapbox://styles/nairitroy/cmp00db5a000r01pe3pea1r0k',
    label: 'Satellite',
  ),
  FitnessMapStyle(
    id: 'mapbox://styles/nairitroy/cmp00nzd2005101s3foyldiil',
    label: 'Energy',
  ),
];

class FitnessMapStyle {
  final String id;
  final String label;

  const FitnessMapStyle({required this.id, required this.label});
}

class FitnessMetricPoint {
  final String label;
  final double distanceKm;
  final double activeMinutes;
  final double calories;
  final double sessions;
  final double bodyScore;

  const FitnessMetricPoint({
    required this.label,
    required this.distanceKm,
    required this.activeMinutes,
    required this.calories,
    required this.sessions,
    required this.bodyScore,
  });

  double valueFor(String metric) {
    return switch (metric) {
      'Time' => activeMinutes,
      'Calories' => calories,
      'Sessions' => sessions,
      _ => distanceKm,
    };
  }
}

class FitnessCenterState {
  final FitnessActivityType selectedActivityType;
  final String selectedMapStyleId;
  final String selectedGraphMetric;
  final FitnessActivity? activeActivity;
  final FitnessActivity? completedActivity;
  final List<FitnessActivity> recentActivities;
  final List<FitnessGoal> goals;
  final List<FitnessRecord> records;
  final List<FitnessInsight> insights;
  final List<FitnessMetricPoint> weeklyMetrics;
  final bool containsDemoData;

  const FitnessCenterState({
    required this.selectedActivityType,
    required this.selectedMapStyleId,
    required this.selectedGraphMetric,
    required this.activeActivity,
    required this.completedActivity,
    required this.recentActivities,
    required this.goals,
    required this.records,
    required this.insights,
    required this.weeklyMetrics,
    this.containsDemoData = false,
  });

  factory FitnessCenterState.empty() {
    return FitnessCenterState(
      selectedActivityType: FitnessActivityType.walk,
      selectedMapStyleId: fitnessMapStyles.first.id,
      selectedGraphMetric: 'Distance',
      activeActivity: null,
      completedActivity: null,
      recentActivities: const [],
      goals: const [],
      records: const [],
      insights: const [],
      weeklyMetrics: const [],
    );
  }

  factory FitnessCenterState.mock() {
    return FitnessCenterState(
      selectedActivityType: FitnessActivityType.walk,
      selectedMapStyleId: fitnessMapStyles.first.id,
      selectedGraphMetric: 'Distance',
      activeActivity: null,
      completedActivity: null,
      recentActivities: _mockRecentActivities(),
      goals: _mockGoals(),
      records: _mockRecords(),
      insights: _mockInsights(),
      weeklyMetrics: const [
        FitnessMetricPoint(
          label: 'M',
          distanceKm: 0.8,
          activeMinutes: 12,
          calories: 58,
          sessions: 1,
          bodyScore: 52,
        ),
        FitnessMetricPoint(
          label: 'T',
          distanceKm: 1.4,
          activeMinutes: 18,
          calories: 86,
          sessions: 1,
          bodyScore: 56,
        ),
        FitnessMetricPoint(
          label: 'W',
          distanceKm: 0.5,
          activeMinutes: 8,
          calories: 42,
          sessions: 0,
          bodyScore: 54,
        ),
        FitnessMetricPoint(
          label: 'T',
          distanceKm: 2.4,
          activeMinutes: 28,
          calories: 142,
          sessions: 1,
          bodyScore: 62,
        ),
        FitnessMetricPoint(
          label: 'F',
          distanceKm: 0.0,
          activeMinutes: 32,
          calories: 170,
          sessions: 1,
          bodyScore: 64,
        ),
        FitnessMetricPoint(
          label: 'S',
          distanceKm: 3.3,
          activeMinutes: 26,
          calories: 238,
          sessions: 1,
          bodyScore: 68,
        ),
        FitnessMetricPoint(
          label: 'S',
          distanceKm: 0.0,
          activeMinutes: 0,
          calories: 0,
          sessions: 0,
          bodyScore: 62,
        ),
      ],
      containsDemoData: true,
    );
  }

  FitnessCenterState copyWith({
    FitnessActivityType? selectedActivityType,
    String? selectedMapStyleId,
    String? selectedGraphMetric,
    FitnessActivity? activeActivity,
    bool clearActiveActivity = false,
    FitnessActivity? completedActivity,
    List<FitnessActivity>? recentActivities,
    List<FitnessGoal>? goals,
    List<FitnessRecord>? records,
    List<FitnessInsight>? insights,
    List<FitnessMetricPoint>? weeklyMetrics,
    bool? containsDemoData,
  }) {
    return FitnessCenterState(
      selectedActivityType: selectedActivityType ?? this.selectedActivityType,
      selectedMapStyleId: selectedMapStyleId ?? this.selectedMapStyleId,
      selectedGraphMetric: selectedGraphMetric ?? this.selectedGraphMetric,
      activeActivity: clearActiveActivity
          ? null
          : activeActivity ?? this.activeActivity,
      completedActivity: completedActivity ?? this.completedActivity,
      recentActivities: recentActivities ?? this.recentActivities,
      goals: goals ?? this.goals,
      records: records ?? this.records,
      insights: insights ?? this.insights,
      weeklyMetrics: weeklyMetrics ?? this.weeklyMetrics,
      containsDemoData: containsDemoData ?? this.containsDemoData,
    );
  }

  double get todayDistanceKm => containsDemoData ? 2.4 : 0;
  int get todayActiveMinutes => containsDemoData ? 28 : 0;
  int get todayCalories => containsDemoData ? 142 : 0;
  int get todaySteps => containsDemoData ? 3820 : 0;
  int get bodyScorePercent => containsDemoData ? 62 : 0;
  String get workoutStatus => containsDemoData ? 'Pending' : 'No activity';
  double get weeklyDistanceKm => containsDemoData ? 8.4 : 0;
  int get weeklySessions => containsDemoData ? 3 : 0;
  int get activeMinutesThisWeek => containsDemoData ? 124 : 0;
  int get workoutSessionsThisWeek => containsDemoData ? 3 : 0;
  String get bestPaceLabel => containsDemoData ? '6\'55"/km' : '—';
  double get weeklyDistanceGoalKm => containsDemoData ? 15 : 0;
}

class FitnessCenterNotifier extends StateNotifier<FitnessCenterState> {
  FitnessCenterNotifier(this._ref, {required bool fakeDataAllowed})
    : _fakeDataAllowed = fakeDataAllowed,
      super(
        fakeDataAllowed
            ? FitnessCenterState.mock()
            : FitnessCenterState.empty(),
      );

  final Ref _ref;
  final bool _fakeDataAllowed;
  String? _ownerUid;

  String? get ownerUid => _ownerUid;

  void setOwnerUid(String? uid) {
    _ownerUid = uid;
  }

  void resetForSignedOut() {
    _ownerUid = null;
    state = FitnessCenterState.empty();
  }

  void selectActivityType(FitnessActivityType activityType) {
    state = state.copyWith(selectedActivityType: activityType);
  }

  void selectMapStyle(String mapStyleId) {
    state = state.copyWith(selectedMapStyleId: mapStyleId);
  }

  void selectGraphMetric(String metric) {
    state = state.copyWith(selectedGraphMetric: metric);
  }

  FitnessActivity startSelectedActivity({
    FitnessActivityType? overrideType,
    FitnessActivitySource source = FitnessActivitySource.tracker,
    String? linkedRoutineItemId,
  }) {
    final type = overrideType ?? state.selectedActivityType;
    final now = DateTime.now();
    final activity = FitnessActivity(
      id: 'fitness-${now.microsecondsSinceEpoch}',
      activityType: type,
      startedAt: now,
      movingDuration: Duration.zero,
      pausedDuration: Duration.zero,
      distanceMeters: 0,
      caloriesEstimate: 0,
      mapStyleId: type.isOutdoor ? state.selectedMapStyleId : null,
      status: FitnessActivityStatus.active,
      source: source,
      linkedRoutineItemId: linkedRoutineItemId,
      title: _activityTitle(type),
      exercises: _defaultExercises(type),
    );
    state = state.copyWith(
      selectedActivityType: type,
      activeActivity: activity,
      completedActivity: null,
    );
    return activity;
  }

  void pauseActivity() {
    final active = state.activeActivity;
    if (active == null) return;
    state = state.copyWith(
      activeActivity: active.copyWith(status: FitnessActivityStatus.paused),
    );
  }

  void resumeActivity() {
    final active = state.activeActivity;
    if (active == null) return;
    state = state.copyWith(
      activeActivity: active.copyWith(status: FitnessActivityStatus.active),
    );
  }

  FitnessActivity? finishActiveActivity({
    int? elapsedSeconds,
    int? completedExercises,
    int? setsCompleted,
  }) {
    final active = state.activeActivity;
    if (active == null) return null;

    final completed = _completedActivityFrom(
      active,
      elapsedSeconds: elapsedSeconds,
      completedExercises: completedExercises,
      setsCompleted: setsCompleted,
    );

    state = state.copyWith(
      clearActiveActivity: true,
      completedActivity: completed,
      recentActivities: [completed, ...state.recentActivities],
    );

    _ref.read(mockTrackerProvider.notifier).completeFitnessActivity(completed);
    return completed;
  }

  void discardActiveActivity() {
    final active = state.activeActivity;
    if (active == null) return;
    state = state.copyWith(
      clearActiveActivity: true,
      completedActivity: active.copyWith(
        status: FitnessActivityStatus.discarded,
      ),
    );
  }

  FitnessActivity _completedActivityFrom(
    FitnessActivity active, {
    int? elapsedSeconds,
    int? completedExercises,
    int? setsCompleted,
  }) {
    final now = DateTime.now();
    final type = active.activityType;
    final route = _fakeDataAllowed && type.isOutdoor
        ? _mockRoute(active.id)
        : const <RoutePoint>[];
    final duration = Duration(
      seconds: elapsedSeconds != null && elapsedSeconds > 0
          ? elapsedSeconds
          : (_fakeDataAllowed ? _defaultDurationSeconds(type) : 0),
    );
    final distanceMeters = _fakeDataAllowed
        ? _defaultDistanceMeters(type)
        : 0.0;
    final pace = distanceMeters <= 0
        ? null
        : duration.inSeconds / 60 / (distanceMeters / 1000);
    final speed = distanceMeters <= 0
        ? null
        : (distanceMeters / 1000) / (duration.inSeconds / 3600);

    return active.copyWith(
      endedAt: now,
      movingDuration: duration,
      pausedDuration: active.status == FitnessActivityStatus.paused
          ? const Duration(minutes: 2)
          : Duration.zero,
      distanceMeters: distanceMeters,
      avgPace: type == FitnessActivityType.cycling ? null : pace,
      avgSpeed: type == FitnessActivityType.cycling ? speed : null,
      caloriesEstimate: _fakeDataAllowed ? _defaultCalories(type) : 0,
      elevationGain: _fakeDataAllowed && type.isOutdoor
          ? _defaultElevationGain(type)
          : null,
      route: route,
      routeBounds: _fakeDataAllowed && type.isOutdoor
          ? const RouteBounds(
              north: 12.9772,
              south: 12.9709,
              east: 77.5992,
              west: 77.5938,
            )
          : null,
      status: FitnessActivityStatus.completed,
      exercisesCompleted:
          completedExercises ??
          (_fakeDataAllowed ? _defaultExercises(type).length : 0),
      setsCompleted:
          setsCompleted ?? (_fakeDataAllowed && type.isWorkout ? 3 : 0),
      updatedAt: now,
    );
  }
}

final fitnessCenterProvider =
    StateNotifierProvider<FitnessCenterNotifier, FitnessCenterState>((ref) {
      return FitnessCenterNotifier(
        ref,
        fakeDataAllowed: ref.watch(fakeDataAllowedProvider),
      );
    });

class FitnessRouteQuality {
  const FitnessRouteQuality._();

  static List<RoutePoint> cleanForDistance(List<RoutePoint> points) {
    // Later GPS integration should ignore low-quality points, smooth noisy
    // samples, avoid counting distance while paused, and prevent a straight-line
    // jump from being added when tracking resumes after a pause.
    return points
        .where((point) => !point.isPaused)
        .where((point) => (point.accuracy ?? 0) <= 50)
        .toList(growable: false);
  }

  static RouteBounds? calculateBounds(List<RoutePoint> points) {
    // Store bounds with the completed activity so route previews can frame the
    // path without reprocessing every point. Map style remains activity-owned.
    if (points.isEmpty) return null;
    double north = points.first.lat;
    double south = points.first.lat;
    double east = points.first.lng;
    double west = points.first.lng;
    for (final point in points) {
      if (point.lat > north) north = point.lat;
      if (point.lat < south) south = point.lat;
      if (point.lng > east) east = point.lng;
      if (point.lng < west) west = point.lng;
    }
    return RouteBounds(north: north, south: south, east: east, west: west);
  }
}

List<FitnessActivity> _mockRecentActivities() {
  final now = DateTime.now();
  return [
    FitnessActivity(
      id: 'fitness-walk-today',
      activityType: FitnessActivityType.walk,
      title: 'Morning Walk',
      startedAt: now.subtract(const Duration(hours: 4)),
      endedAt: now.subtract(const Duration(hours: 3, minutes: 31)),
      movingDuration: const Duration(minutes: 28, seconds: 12),
      distanceMeters: 2410,
      avgPace: 11.7,
      caloriesEstimate: 142,
      elevationGain: 8,
      mapStyleId: fitnessMapStyles.first.id,
      routeBounds: const RouteBounds(
        north: 12.9772,
        south: 12.9709,
        east: 77.5992,
        west: 77.5938,
      ),
      route: _mockRoute('fitness-walk-today'),
      status: FitnessActivityStatus.completed,
    ),
    FitnessActivity(
      id: 'fitness-run-yesterday',
      activityType: FitnessActivityType.run,
      title: 'Evening Run',
      startedAt: now.subtract(const Duration(days: 1, hours: 2)),
      endedAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 35)),
      movingDuration: const Duration(minutes: 24, seconds: 12),
      distanceMeters: 3240,
      avgPace: 7.47,
      caloriesEstimate: 258,
      elevationGain: 18,
      mapStyleId: fitnessMapStyles.first.id,
      routeBounds: const RouteBounds(
        north: 12.9772,
        south: 12.9709,
        east: 77.5992,
        west: 77.5938,
      ),
      route: _mockRoute('fitness-run-yesterday'),
      status: FitnessActivityStatus.completed,
    ),
    FitnessActivity(
      id: 'fitness-workout-week',
      activityType: FitnessActivityType.strengthWorkout,
      title: 'Full Body Workout',
      startedAt: now.subtract(const Duration(days: 2, hours: 1)),
      endedAt: now.subtract(const Duration(days: 2, minutes: 28)),
      movingDuration: const Duration(minutes: 32),
      distanceMeters: 0,
      caloriesEstimate: 170,
      exercises: const ['Push-ups', 'Squats', 'Plank', 'Walking', 'Stretching'],
      exercisesCompleted: 5,
      setsCompleted: 3,
      status: FitnessActivityStatus.completed,
    ),
    FitnessActivity(
      id: 'fitness-cycle-week',
      activityType: FitnessActivityType.cycling,
      title: 'Campus Cycling',
      startedAt: now.subtract(const Duration(days: 3, hours: 5)),
      endedAt: now.subtract(const Duration(days: 3, hours: 4, minutes: 34)),
      movingDuration: const Duration(minutes: 26),
      distanceMeters: 2750,
      avgSpeed: 6.35,
      caloriesEstimate: 92,
      elevationGain: 12,
      mapStyleId: fitnessMapStyles[1].id,
      route: _mockRoute('fitness-cycle-week'),
      status: FitnessActivityStatus.completed,
    ),
  ];
}

List<FitnessGoal> _mockGoals() {
  return [
    FitnessGoal(
      id: 'fitness-goal-distance',
      userId: 'mock-user',
      period: FitnessGoalPeriod.weekly,
      goalType: FitnessGoalType.distance,
      targetValue: 15,
      currentValue: 8.4,
      unit: 'km',
    ),
    FitnessGoal(
      id: 'fitness-goal-minutes',
      userId: 'mock-user',
      period: FitnessGoalPeriod.weekly,
      goalType: FitnessGoalType.activeMinutes,
      targetValue: 180,
      currentValue: 124,
      unit: 'min',
    ),
    FitnessGoal(
      id: 'fitness-goal-workouts',
      userId: 'mock-user',
      period: FitnessGoalPeriod.weekly,
      goalType: FitnessGoalType.workoutSessions,
      targetValue: 4,
      currentValue: 3,
      unit: 'sessions',
    ),
    FitnessGoal(
      id: 'fitness-goal-steps',
      userId: 'mock-user',
      period: FitnessGoalPeriod.daily,
      goalType: FitnessGoalType.steps,
      targetValue: 8000,
      currentValue: 3820,
      unit: 'steps',
    ),
    FitnessGoal(
      id: 'fitness-goal-calories',
      userId: 'mock-user',
      period: FitnessGoalPeriod.weekly,
      goalType: FitnessGoalType.calories,
      targetValue: 1200,
      currentValue: 786,
      unit: 'kcal',
    ),
  ];
}

List<FitnessRecord> _mockRecords() {
  return [
    FitnessRecord(
      id: 'record-longest-run',
      userId: 'mock-user',
      recordType: FitnessRecordType.longestDistance,
      value: 5.2,
      unit: 'km',
      activityId: 'fitness-run-yesterday',
    ),
    FitnessRecord(
      id: 'record-best-pace',
      userId: 'mock-user',
      recordType: FitnessRecordType.bestPace,
      value: 6.92,
      unit: '/km',
      activityId: 'fitness-run-yesterday',
    ),
    FitnessRecord(
      id: 'record-longest-walk',
      userId: 'mock-user',
      recordType: FitnessRecordType.mostActiveDay,
      value: 7.4,
      unit: 'km',
    ),
    FitnessRecord(
      id: 'record-best-week',
      userId: 'mock-user',
      recordType: FitnessRecordType.bestWeek,
      value: 18.6,
      unit: 'km',
    ),
  ];
}

List<FitnessInsight> _mockInsights() {
  return [
    FitnessInsight(
      id: 'insight-evening',
      userId: 'mock-user',
      type: 'best_time',
      title: 'Best movement window',
      message: 'Your strongest movement sessions are usually in the evening.',
      period: 'weekly',
    ),
    FitnessInsight(
      id: 'insight-goal-gap',
      userId: 'mock-user',
      type: 'goal_gap',
      title: 'Weekly distance gap',
      message: 'You are 6.6 km away from the 15 km weekly distance goal.',
      period: 'weekly',
    ),
    FitnessInsight(
      id: 'insight-class-walk',
      userId: 'mock-user',
      type: 'context',
      title: 'Body system pattern',
      message: 'Your body score improves on days you walk after class.',
      period: 'weekly',
    ),
    FitnessInsight(
      id: 'insight-active-time',
      userId: 'mock-user',
      type: 'trend',
      title: 'Active time trend',
      message: 'Active time is lower than last week, but still recoverable.',
      period: 'weekly',
    ),
  ];
}

List<RoutePoint> _mockRoute(String activityId) {
  final now = DateTime.now();
  return [
    RoutePoint(
      activityId: activityId,
      lat: 12.9716,
      lng: 77.5946,
      recordedAt: now.subtract(const Duration(minutes: 28)),
      accuracy: 12,
    ),
    RoutePoint(
      activityId: activityId,
      lat: 12.9725,
      lng: 77.5955,
      recordedAt: now.subtract(const Duration(minutes: 21)),
      accuracy: 10,
    ),
    RoutePoint(
      activityId: activityId,
      lat: 12.9738,
      lng: 77.5970,
      recordedAt: now.subtract(const Duration(minutes: 14)),
      accuracy: 9,
    ),
    RoutePoint(
      activityId: activityId,
      lat: 12.9750,
      lng: 77.5960,
      recordedAt: now.subtract(const Duration(minutes: 7)),
      accuracy: 11,
    ),
    RoutePoint(
      activityId: activityId,
      lat: 12.9716,
      lng: 77.5946,
      recordedAt: now,
      accuracy: 13,
    ),
  ];
}

String _activityTitle(FitnessActivityType type) {
  return switch (type) {
    FitnessActivityType.walk => 'Outdoor Walk',
    FitnessActivityType.run => 'Outdoor Run',
    FitnessActivityType.cycling => 'Cycling',
    FitnessActivityType.indoorWalk => 'Indoor Walk',
    FitnessActivityType.freeWorkout => 'Free Workout',
    FitnessActivityType.strengthWorkout => 'Full Body Workout',
    FitnessActivityType.stretch => 'Stretch / Mobility',
    FitnessActivityType.custom => 'Custom Activity',
  };
}

List<String> _defaultExercises(FitnessActivityType type) {
  return switch (type) {
    FitnessActivityType.freeWorkout || FitnessActivityType.strengthWorkout =>
      const ['Push-ups', 'Squats', 'Plank', 'Walking', 'Stretching'],
    FitnessActivityType.stretch => const [
      'Neck release',
      'Hamstring fold',
      'Hip opener',
      'Child pose',
      'Breathing reset',
    ],
    _ => const [],
  };
}

int _defaultDurationSeconds(FitnessActivityType type) {
  return switch (type) {
    FitnessActivityType.walk => 28 * 60 + 12,
    FitnessActivityType.run => 24 * 60 + 12,
    FitnessActivityType.cycling => 26 * 60,
    FitnessActivityType.indoorWalk => 22 * 60,
    FitnessActivityType.freeWorkout ||
    FitnessActivityType.strengthWorkout => 32 * 60,
    FitnessActivityType.stretch => 18 * 60,
    FitnessActivityType.custom => 20 * 60,
  };
}

double _defaultDistanceMeters(FitnessActivityType type) {
  return switch (type) {
    FitnessActivityType.walk => 2410,
    FitnessActivityType.run => 3240,
    FitnessActivityType.cycling => 2750,
    FitnessActivityType.indoorWalk => 1200,
    _ => 0,
  };
}

int _defaultCalories(FitnessActivityType type) {
  return switch (type) {
    FitnessActivityType.walk => 142,
    FitnessActivityType.run => 258,
    FitnessActivityType.cycling => 92,
    FitnessActivityType.indoorWalk => 96,
    FitnessActivityType.freeWorkout ||
    FitnessActivityType.strengthWorkout => 170,
    FitnessActivityType.stretch => 52,
    FitnessActivityType.custom => 80,
  };
}

double _defaultElevationGain(FitnessActivityType type) {
  return switch (type) {
    FitnessActivityType.walk => 8,
    FitnessActivityType.run => 18,
    FitnessActivityType.cycling => 12,
    _ => 0,
  };
}
