enum FitnessActivityType {
  walk,
  run,
  cycling,
  indoorWalk,
  freeWorkout,
  strengthWorkout,
  stretch,
  custom,
}

extension FitnessActivityTypeX on FitnessActivityType {
  String get label {
    return switch (this) {
      FitnessActivityType.walk => 'Outdoor Walk',
      FitnessActivityType.run => 'Outdoor Run',
      FitnessActivityType.cycling => 'Cycling',
      FitnessActivityType.indoorWalk => 'Indoor Walk',
      FitnessActivityType.freeWorkout => 'Free Workout',
      FitnessActivityType.strengthWorkout => 'Strength Workout',
      FitnessActivityType.stretch => 'Stretch / Mobility',
      FitnessActivityType.custom => 'Custom Activity',
    };
  }

  String get shortLabel {
    return switch (this) {
      FitnessActivityType.walk => 'Walk',
      FitnessActivityType.run => 'Run',
      FitnessActivityType.cycling => 'Cycling',
      FitnessActivityType.indoorWalk => 'Indoor Walk',
      FitnessActivityType.freeWorkout => 'Workout',
      FitnessActivityType.strengthWorkout => 'Strength',
      FitnessActivityType.stretch => 'Stretch',
      FitnessActivityType.custom => 'Custom',
    };
  }

  bool get isOutdoor {
    return this == FitnessActivityType.walk ||
        this == FitnessActivityType.run ||
        this == FitnessActivityType.cycling;
  }

  bool get isWorkout {
    return this == FitnessActivityType.freeWorkout ||
        this == FitnessActivityType.strengthWorkout ||
        this == FitnessActivityType.stretch;
  }

  static FitnessActivityType fromLegacyType(String value) {
    final normalized = value.toLowerCase().replaceAll(' ', '_');
    return switch (normalized) {
      'walk' || 'outdoor_walk' => FitnessActivityType.walk,
      'run' || 'outdoor_run' => FitnessActivityType.run,
      'cycling' || 'cycle' || 'bike' => FitnessActivityType.cycling,
      'indoor_walk' => FitnessActivityType.indoorWalk,
      'free_workout' || 'workout' => FitnessActivityType.freeWorkout,
      'strength' || 'strength_workout' => FitnessActivityType.strengthWorkout,
      'stretch' || 'mobility' || 'stretching' => FitnessActivityType.stretch,
      _ => FitnessActivityType.custom,
    };
  }
}

enum FitnessActivityStatus { ready, active, paused, completed, discarded }

enum FitnessActivitySource { tracker, routine, home, coach, manual }

enum FitnessGoalPeriod { daily, weekly, monthly }

enum FitnessGoalType {
  distance,
  activeMinutes,
  calories,
  steps,
  workoutSessions,
}

enum FitnessGoalStatus { active, completed, paused }

enum FitnessRecordType {
  longestDistance,
  bestPace,
  fastest1k,
  longestWorkout,
  bestWeek,
  longestActiveStreak,
  mostActiveDay,
}

class RouteBounds {
  final double north;
  final double south;
  final double east;
  final double west;

  const RouteBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  Map<String, dynamic> toMap() {
    return {'north': north, 'south': south, 'east': east, 'west': west};
  }
}

class RoutePoint {
  final String activityId;
  final double lat;
  final double lng;
  final DateTime recordedAt;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? bearing;
  final bool isPaused;
  final String? timestampLabel;

  RoutePoint({
    String? activityId,
    double? lat,
    double? lng,
    double? latitude,
    double? longitude,
    Object? timestamp,
    DateTime? recordedAt,
    this.accuracy,
    this.altitude,
    this.speed,
    this.bearing,
    this.isPaused = false,
  }) : activityId = activityId ?? '',
       lat = lat ?? latitude ?? 0,
       lng = lng ?? longitude ?? 0,
       recordedAt = recordedAt ?? _parseRecordedAt(timestamp),
       timestampLabel = timestamp is String ? timestamp : null;

  double get latitude => lat;
  double get longitude => lng;
  String get timestamp => timestampLabel ?? recordedAt.toIso8601String();

  static DateTime _parseRecordedAt(Object? timestamp) {
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'lat': lat,
      'lng': lng,
      'timestamp': recordedAt.toIso8601String(),
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'bearing': bearing,
      'isPaused': isPaused,
    };
  }
}

class FitnessActivity {
  final String id;
  final String userId;
  final FitnessActivityType activityType;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration movingDuration;
  final Duration pausedDuration;
  final double distanceMeters;
  final double? avgPace;
  final double? avgSpeed;
  final int caloriesEstimate;
  final double? elevationGain;
  final String? mapStyleId;
  final RouteBounds? routeBounds;
  final FitnessActivityStatus status;
  final FitnessActivitySource source;
  final String? linkedRoutineItemId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RoutePoint> route;
  final String? title;
  final List<String> exercises;
  final int setsCompleted;
  final int exercisesCompleted;

  FitnessActivity({
    required this.id,
    String? userId,
    FitnessActivityType? activityType,
    String? type,
    DateTime? startedAt,
    this.endedAt,
    Duration? movingDuration,
    int? durationSeconds,
    Duration? pausedDuration,
    double? distanceMeters,
    double? distanceKm,
    double? avgPace,
    double? paceMinutesPerKm,
    this.avgSpeed,
    int? caloriesEstimate,
    int? caloriesBurned,
    this.elevationGain,
    this.mapStyleId,
    this.routeBounds,
    FitnessActivityStatus? status,
    FitnessActivitySource? source,
    this.linkedRoutineItemId,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RoutePoint>? route,
    this.title,
    List<String>? exercises,
    int? setsCompleted,
    int? exercisesCompleted,
  }) : userId = userId ?? '',
       activityType =
           activityType ??
           FitnessActivityTypeX.fromLegacyType(type ?? 'custom'),
       startedAt = startedAt ?? DateTime.now(),
       movingDuration =
           movingDuration ?? Duration(seconds: durationSeconds ?? 0),
       pausedDuration = pausedDuration ?? Duration.zero,
       distanceMeters = distanceMeters ?? ((distanceKm ?? 0.0) * 1000),
       avgPace = avgPace ?? paceMinutesPerKm,
       caloriesEstimate = caloriesEstimate ?? caloriesBurned ?? 0,
       status = status ?? FitnessActivityStatus.completed,
       source = source ?? FitnessActivitySource.tracker,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       route = route ?? const [],
       exercises = exercises ?? const [],
       setsCompleted = setsCompleted ?? 0,
       exercisesCompleted = exercisesCompleted ?? 0;

  String get type => activityType.shortLabel;
  double get distanceKm => distanceMeters / 1000;
  int get durationSeconds => movingDuration.inSeconds;
  double get paceMinutesPerKm {
    if (avgPace != null && avgPace! > 0) return avgPace!;
    if (distanceKm <= 0 || movingDuration.inSeconds <= 0) return 0;
    return movingDuration.inSeconds / 60 / distanceKm;
  }

  int get caloriesBurned => caloriesEstimate;
  bool get isOutdoor => activityType.isOutdoor;
  bool get isWorkout => activityType.isWorkout;

  FitnessActivity copyWith({
    String? id,
    String? userId,
    FitnessActivityType? activityType,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? movingDuration,
    Duration? pausedDuration,
    double? distanceMeters,
    double? avgPace,
    double? avgSpeed,
    int? caloriesEstimate,
    double? elevationGain,
    String? mapStyleId,
    RouteBounds? routeBounds,
    FitnessActivityStatus? status,
    FitnessActivitySource? source,
    String? linkedRoutineItemId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RoutePoint>? route,
    String? title,
    List<String>? exercises,
    int? setsCompleted,
    int? exercisesCompleted,
  }) {
    return FitnessActivity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      activityType: activityType ?? this.activityType,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      movingDuration: movingDuration ?? this.movingDuration,
      pausedDuration: pausedDuration ?? this.pausedDuration,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      avgPace: avgPace ?? this.avgPace,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      caloriesEstimate: caloriesEstimate ?? this.caloriesEstimate,
      elevationGain: elevationGain ?? this.elevationGain,
      mapStyleId: mapStyleId ?? this.mapStyleId,
      routeBounds: routeBounds ?? this.routeBounds,
      status: status ?? this.status,
      source: source ?? this.source,
      linkedRoutineItemId: linkedRoutineItemId ?? this.linkedRoutineItemId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      route: route ?? this.route,
      title: title ?? this.title,
      exercises: exercises ?? this.exercises,
      setsCompleted: setsCompleted ?? this.setsCompleted,
      exercisesCompleted: exercisesCompleted ?? this.exercisesCompleted,
    );
  }
}

class FitnessGoal {
  final String id;
  final String userId;
  final FitnessGoalPeriod period;
  final FitnessGoalType goalType;
  final double targetValue;
  final double currentValue;
  final String unit;
  final FitnessGoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  FitnessGoal({
    required this.id,
    required this.userId,
    required this.period,
    required this.goalType,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    this.status = FitnessGoalStatus.active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

class FitnessRecord {
  final String id;
  final String userId;
  final FitnessRecordType recordType;
  final double value;
  final String unit;
  final String? activityId;
  final DateTime achievedAt;

  FitnessRecord({
    required this.id,
    required this.userId,
    required this.recordType,
    required this.value,
    required this.unit,
    this.activityId,
    DateTime? achievedAt,
  }) : achievedAt = achievedAt ?? DateTime.now();
}

class FitnessInsight {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String period;
  final DateTime createdAt;

  FitnessInsight({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.period,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class ScreenTimeApp {
  final String name;
  final String packageName;
  final int durationMinutes;
  final String distractionRisk; // Low, Medium, High

  ScreenTimeApp({
    required this.name,
    required this.packageName,
    required this.durationMinutes,
    required this.distractionRisk,
  });
}

class HydrationLog {
  final String id;
  final int amountMl;
  final String timestamp;

  HydrationLog({
    required this.id,
    required this.amountMl,
    required this.timestamp,
  });
}

class TrackerSession {
  final String id;
  final String category; // Mind, Body, Finance, Focus, Habits
  final String title;
  final DateTime timestamp;
  final int value; // Generic progress value (e.g. minutes, ml, rupees)
  final bool isCompleted;

  TrackerSession({
    required this.id,
    required this.category,
    required this.title,
    required this.timestamp,
    required this.value,
    this.isCompleted = true,
  });
}

enum FocusSessionMode { pomodoro25, deepWork45, custom }

enum FocusSessionStatus { planned, active, paused, completed, cancelled }

class FocusSession {
  final String id;
  final String userId;
  final FocusSessionMode mode;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int targetMinutes;
  final int completedMinutes;
  final String? linkedRoutineItemId;
  final String? linkedRoutineTitle;
  final FocusSessionStatus status;
  final int distractionRiskScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  FocusSession({
    required this.id,
    this.userId = '',
    required this.mode,
    required this.startedAt,
    this.completedAt,
    required this.targetMinutes,
    this.completedMinutes = 0,
    this.linkedRoutineItemId,
    this.linkedRoutineTitle,
    this.status = FocusSessionStatus.planned,
    this.distractionRiskScore = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  FocusSession copyWith({
    String? id,
    String? userId,
    FocusSessionMode? mode,
    DateTime? startedAt,
    DateTime? completedAt,
    int? targetMinutes,
    int? completedMinutes,
    String? linkedRoutineItemId,
    String? linkedRoutineTitle,
    FocusSessionStatus? status,
    int? distractionRiskScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FocusSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mode: mode ?? this.mode,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      completedMinutes: completedMinutes ?? this.completedMinutes,
      linkedRoutineItemId: linkedRoutineItemId ?? this.linkedRoutineItemId,
      linkedRoutineTitle: linkedRoutineTitle ?? this.linkedRoutineTitle,
      status: status ?? this.status,
      distractionRiskScore: distractionRiskScore ?? this.distractionRiskScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'mode': mode.name,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'targetMinutes': targetMinutes,
      'completedMinutes': completedMinutes,
      'linkedRoutineItemId': linkedRoutineItemId,
      'linkedRoutineTitle': linkedRoutineTitle,
      'status': status.name,
      'distractionRiskScore': distractionRiskScore,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

enum BadHabitType { smoking, alcohol, junkFood, custom }

enum BadHabitCheckInStatus { avoided, craving, relapsed }

enum CravingIntensity { low, medium, high }

class BadHabitLog {
  final String id;
  final String userId;
  final BadHabitType habitType;
  final String title;
  final BadHabitCheckInStatus status;
  final DateTime loggedAt;
  final String dateKey;
  final double dailyCost;
  final double potentialSaved;
  final double convertedSaved;
  final CravingIntensity? cravingIntensity;
  final String? trigger;
  final int? relapseCount;
  final String? reason;
  final String? comebackAction;
  final DateTime createdAt;
  final DateTime updatedAt;

  BadHabitLog({
    required this.id,
    this.userId = '',
    required this.habitType,
    required this.title,
    required this.status,
    required this.loggedAt,
    required this.dateKey,
    this.dailyCost = 0,
    this.potentialSaved = 0,
    this.convertedSaved = 0,
    this.cravingIntensity,
    this.trigger,
    this.relapseCount,
    this.reason,
    this.comebackAction,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'habitType': habitType.name,
      'title': title,
      'status': status.name,
      'loggedAt': loggedAt.toIso8601String(),
      'dateKey': dateKey,
      'dailyCost': dailyCost,
      'potentialSaved': potentialSaved,
      'convertedSaved': convertedSaved,
      'cravingIntensity': cravingIntensity?.name,
      'trigger': trigger,
      'relapseCount': relapseCount,
      'reason': reason,
      'comebackAction': comebackAction,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

enum SleepQuality { poor, okay, good }

class SleepLog {
  final String id;
  final String userId;
  final DateTime sleepStartDateTime;
  final DateTime wakeDateTime;
  final int durationMinutes;
  final SleepQuality quality;
  final DateTime progressDate;
  final String? source;
  final DateTime createdAt;
  final DateTime updatedAt;

  SleepLog({
    required this.id,
    this.userId = '',
    required this.sleepStartDateTime,
    required this.wakeDateTime,
    required this.durationMinutes,
    required this.quality,
    required this.progressDate,
    this.source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory SleepLog.fromRange({
    required String id,
    String userId = '',
    required DateTime sleepStartDateTime,
    required DateTime wakeDateTime,
    required SleepQuality quality,
    String? source,
  }) {
    final duration = wakeDateTime.difference(sleepStartDateTime);
    final wakeDay = DateTime(
      wakeDateTime.year,
      wakeDateTime.month,
      wakeDateTime.day,
    );
    return SleepLog(
      id: id,
      userId: userId,
      sleepStartDateTime: sleepStartDateTime,
      wakeDateTime: wakeDateTime,
      durationMinutes: duration.inMinutes,
      quality: quality,
      progressDate: wakeDay,
      source: source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'sleepStartDateTime': sleepStartDateTime.toIso8601String(),
      'wakeDateTime': wakeDateTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'quality': quality.name,
      'progressDate': progressDate.toIso8601String(),
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

enum MealType { breakfast, lunch, snacks, dinner }

enum MealSource { home, hostel, pg, mess, flat, mixed }

class NutritionLog {
  final String id;
  final String userId;
  final MealType mealType;
  final DateTime loggedAt;
  final String dateKey;
  final bool done;
  final double estimatedCalories;
  final double estimatedProtein;
  final MealSource source;
  final List<String> dishes;
  final String? linkedRoutineItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  NutritionLog({
    required this.id,
    this.userId = '',
    required this.mealType,
    required this.loggedAt,
    required this.dateKey,
    this.done = false,
    this.estimatedCalories = 0,
    this.estimatedProtein = 0,
    this.source = MealSource.home,
    this.dishes = const [],
    this.linkedRoutineItemId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  NutritionLog copyWith({
    String? id,
    String? userId,
    MealType? mealType,
    DateTime? loggedAt,
    String? dateKey,
    bool? done,
    double? estimatedCalories,
    double? estimatedProtein,
    MealSource? source,
    List<String>? dishes,
    String? linkedRoutineItemId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NutritionLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mealType: mealType ?? this.mealType,
      loggedAt: loggedAt ?? this.loggedAt,
      dateKey: dateKey ?? this.dateKey,
      done: done ?? this.done,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      estimatedProtein: estimatedProtein ?? this.estimatedProtein,
      source: source ?? this.source,
      dishes: dishes ?? this.dishes,
      linkedRoutineItemId: linkedRoutineItemId ?? this.linkedRoutineItemId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'mealType': mealType.name,
      'loggedAt': loggedAt.toIso8601String(),
      'dateKey': dateKey,
      'done': done,
      'estimatedCalories': estimatedCalories,
      'estimatedProtein': estimatedProtein,
      'source': source.name,
      'dishes': dishes,
      'linkedRoutineItemId': linkedRoutineItemId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class TrackerHistoryEntry {
  final String id;
  final String userId;
  final String trackerType;
  final String category;
  final String title;
  final String subtitle;
  final DateTime occurredAt;
  final String? sourceId;
  final String? valueLabel;
  final bool completed;
  final DateTime createdAt;

  TrackerHistoryEntry({
    required this.id,
    this.userId = '',
    required this.trackerType,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
    this.sourceId,
    this.valueLabel,
    this.completed = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'trackerType': trackerType,
      'category': category,
      'title': title,
      'subtitle': subtitle,
      'occurredAt': occurredAt.toIso8601String(),
      'sourceId': sourceId,
      'valueLabel': valueLabel,
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
