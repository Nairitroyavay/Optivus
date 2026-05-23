enum NotificationIntensity {
  low,
  medium,
  high
}

class NotificationPreferences {
  final bool morningStart;
  final bool nextTask;
  final bool eating;
  final bool badHabitCheckIn;
  final bool savings;
  final bool nightReflection;
  final NotificationIntensity intensity;

  NotificationPreferences({
    this.morningStart = true,
    this.nextTask = true,
    this.eating = true,
    this.badHabitCheckIn = true,
    this.savings = true,
    this.nightReflection = true,
    this.intensity = NotificationIntensity.medium,
  });

  NotificationPreferences copyWith({
    bool? morningStart,
    bool? nextTask,
    bool? eating,
    bool? badHabitCheckIn,
    bool? savings,
    bool? nightReflection,
    NotificationIntensity? intensity,
  }) {
    return NotificationPreferences(
      morningStart: morningStart ?? this.morningStart,
      nextTask: nextTask ?? this.nextTask,
      eating: eating ?? this.eating,
      badHabitCheckIn: badHabitCheckIn ?? this.badHabitCheckIn,
      savings: savings ?? this.savings,
      nightReflection: nightReflection ?? this.nightReflection,
      intensity: intensity ?? this.intensity,
    );
  }
}
