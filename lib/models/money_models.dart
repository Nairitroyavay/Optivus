class SavingEntry {
  final String id;
  final double amount;
  final String timestamp;
  final String description;
  final bool isConfirmed; // Confirmed saved vs Potential saved from bad habits

  SavingEntry({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.description,
    this.isConfirmed = false,
  });
}

class MoneyGoal {
  final String id;
  final double dailyTarget;
  final double totalConfirmedSaved;
  final double totalPotentialSaved;
  final int streakDays;
  final int streakLevel;

  MoneyGoal({
    required this.id,
    this.dailyTarget = 10.0,
    this.totalConfirmedSaved = 0.0,
    this.totalPotentialSaved = 0.0,
    this.streakDays = 0,
    this.streakLevel = 1,
  });

  MoneyGoal copyWith({
    String? id,
    double? dailyTarget,
    double? totalConfirmedSaved,
    double? totalPotentialSaved,
    int? streakDays,
    int? streakLevel,
  }) {
    return MoneyGoal(
      id: id ?? this.id,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      totalConfirmedSaved: totalConfirmedSaved ?? this.totalConfirmedSaved,
      totalPotentialSaved: totalPotentialSaved ?? this.totalPotentialSaved,
      streakDays: streakDays ?? this.streakDays,
      streakLevel: streakLevel ?? this.streakLevel,
    );
  }
}
