enum MoneyEntryStatus {
  confirmed,
  potential,
  skipped,
}

enum MoneyEntrySource {
  dailyTarget,
  manual,
  upiMock,
  badHabitAvoided,
  badHabitConverted,
  routineTask,
  adjustment,
}

enum MoneySaveMethod {
  upiMock,
  cash,
  bankTransfer,
  secondAccount,
  familyAccount,
  custom,
  none,
}

class SavingEntry {
  final String id;
  final double amount;
  final DateTime createdAt;
  final String dateKey; // YYYY-MM-DD
  final String description;
  final MoneyEntryStatus status;
  final MoneyEntrySource source;
  final MoneySaveMethod method;
  final String? routineTaskId;
  final String? badHabitKey;
  final String? reason;
  final String? note;

  SavingEntry({
    required this.id,
    required this.amount,
    required this.createdAt,
    required this.dateKey,
    required this.description,
    required this.status,
    required this.source,
    required this.method,
    this.routineTaskId,
    this.badHabitKey,
    this.reason,
    this.note,
  });

  bool get isConfirmed => status == MoneyEntryStatus.confirmed;
  bool get isPotential => status == MoneyEntryStatus.potential;
  bool get isSkipped => status == MoneyEntryStatus.skipped;

  SavingEntry copyWith({
    String? id,
    double? amount,
    DateTime? createdAt,
    String? dateKey,
    String? description,
    MoneyEntryStatus? status,
    MoneyEntrySource? source,
    MoneySaveMethod? method,
    String? routineTaskId,
    String? badHabitKey,
    String? reason,
    String? note,
  }) {
    return SavingEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      dateKey: dateKey ?? this.dateKey,
      description: description ?? this.description,
      status: status ?? this.status,
      source: source ?? this.source,
      method: method ?? this.method,
      routineTaskId: routineTaskId ?? this.routineTaskId,
      badHabitKey: badHabitKey ?? this.badHabitKey,
      reason: reason ?? this.reason,
      note: note ?? this.note,
    );
  }
}

class MoneyGoal {
  final String id;
  final double dailyTarget;
  final double tinySaveAmount;
  final double totalConfirmedSaved;
  final double totalPotentialSaved;
  final int streakDays;
  final int bestStreakDays;
  final int streakLevel;
  final int successfulDaysAtCurrentLevel;
  final double currentLevelAmount;
  final double nextLevelAmount;
  final int levelUpAfterDays;
  final String destinationLabel;
  final MoneySaveMethod defaultMethod;
  final String reminderTimeLabel;
  final bool manualConfirmationAllowed;

  MoneyGoal({
    required this.id,
    this.dailyTarget = 10.0,
    this.tinySaveAmount = 5.0,
    this.totalConfirmedSaved = 0.0,
    this.totalPotentialSaved = 0.0,
    this.streakDays = 0,
    this.bestStreakDays = 0,
    this.streakLevel = 1,
    this.successfulDaysAtCurrentLevel = 0,
    this.currentLevelAmount = 10.0,
    this.nextLevelAmount = 25.0,
    this.levelUpAfterDays = 5,
    this.destinationLabel = 'My Second Bank',
    this.defaultMethod = MoneySaveMethod.upiMock,
    this.reminderTimeLabel = '8:00 PM',
    this.manualConfirmationAllowed = true,
  });

  MoneyGoal copyWith({
    String? id,
    double? dailyTarget,
    double? tinySaveAmount,
    double? totalConfirmedSaved,
    double? totalPotentialSaved,
    int? streakDays,
    int? bestStreakDays,
    int? streakLevel,
    int? successfulDaysAtCurrentLevel,
    double? currentLevelAmount,
    double? nextLevelAmount,
    int? levelUpAfterDays,
    String? destinationLabel,
    MoneySaveMethod? defaultMethod,
    String? reminderTimeLabel,
    bool? manualConfirmationAllowed,
  }) {
    return MoneyGoal(
      id: id ?? this.id,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      tinySaveAmount: tinySaveAmount ?? this.tinySaveAmount,
      totalConfirmedSaved: totalConfirmedSaved ?? this.totalConfirmedSaved,
      totalPotentialSaved: totalPotentialSaved ?? this.totalPotentialSaved,
      streakDays: streakDays ?? this.streakDays,
      bestStreakDays: bestStreakDays ?? this.bestStreakDays,
      streakLevel: streakLevel ?? this.streakLevel,
      successfulDaysAtCurrentLevel: successfulDaysAtCurrentLevel ?? this.successfulDaysAtCurrentLevel,
      currentLevelAmount: currentLevelAmount ?? this.currentLevelAmount,
      nextLevelAmount: nextLevelAmount ?? this.nextLevelAmount,
      levelUpAfterDays: levelUpAfterDays ?? this.levelUpAfterDays,
      destinationLabel: destinationLabel ?? this.destinationLabel,
      defaultMethod: defaultMethod ?? this.defaultMethod,
      reminderTimeLabel: reminderTimeLabel ?? this.reminderTimeLabel,
      manualConfirmationAllowed: manualConfirmationAllowed ?? this.manualConfirmationAllowed,
    );
  }
}
