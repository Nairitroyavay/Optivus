class GoalProof {
  final String id;
  final String title;
  final String tinyVersion;
  final String normalVersion;
  final String strongVersion;
  final String selectedDifficulty; // tiny, normal, strong
  final bool isCompleted;
  final String? note;
  final bool sharedToCoach;

  GoalProof({
    required this.id,
    required this.title,
    required this.tinyVersion,
    required this.normalVersion,
    required this.strongVersion,
    this.selectedDifficulty = 'normal',
    this.isCompleted = false,
    this.note,
    this.sharedToCoach = false,
  });

  GoalProof copyWith({
    String? id,
    String? title,
    String? tinyVersion,
    String? normalVersion,
    String? strongVersion,
    String? selectedDifficulty,
    bool? isCompleted,
    String? note,
    bool? sharedToCoach,
  }) {
    return GoalProof(
      id: id ?? this.id,
      title: title ?? this.title,
      tinyVersion: tinyVersion ?? this.tinyVersion,
      normalVersion: normalVersion ?? this.normalVersion,
      strongVersion: strongVersion ?? this.strongVersion,
      selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
      isCompleted: isCompleted ?? this.isCompleted,
      note: note ?? this.note,
      sharedToCoach: sharedToCoach ?? this.sharedToCoach,
    );
  }
}

class GoalSystem {
  final String id;
  final String description;
  final List<String> linkedRoutineTaskIds;
  final List<String> linkedTrackerIds;

  GoalSystem({
    required this.id,
    required this.description,
    this.linkedRoutineTaskIds = const [],
    this.linkedTrackerIds = const [],
  });
}

class GoalModel {
  final String id;
  final String identityTitle; // e.g. "Financially Free", "Strong Body"
  final String purposeStatement; // "Why this matters"
  final double progressPercent;
  final List<GoalSystem> systems;
  final GoalProof dailyProof;
  final int streakDays;
  final bool isArchived;
  final bool isPaused;

  GoalModel({
    required this.id,
    required this.identityTitle,
    required this.purposeStatement,
    required this.dailyProof,
    this.progressPercent = 0.0,
    this.systems = const [],
    this.streakDays = 0,
    this.isArchived = false,
    this.isPaused = false,
  });

  GoalModel copyWith({
    String? id,
    String? identityTitle,
    String? purposeStatement,
    double? progressPercent,
    List<GoalSystem>? systems,
    GoalProof? dailyProof,
    int? streakDays,
    bool? isArchived,
    bool? isPaused,
  }) {
    return GoalModel(
      id: id ?? this.id,
      identityTitle: identityTitle ?? this.identityTitle,
      purposeStatement: purposeStatement ?? this.purposeStatement,
      progressPercent: progressPercent ?? this.progressPercent,
      systems: systems ?? this.systems,
      dailyProof: dailyProof ?? this.dailyProof,
      streakDays: streakDays ?? this.streakDays,
      isArchived: isArchived ?? this.isArchived,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}
