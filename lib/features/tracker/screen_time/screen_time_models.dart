class ScreenTimeAppUsageUiModel {
  final String appName;
  final int minutes;
  final String category; // 'Doom app', 'Productive', 'Neutral'
  final String riskLevel; // 'High', 'Medium', 'Neutral'
  final int? limitMinutes;
  final bool isLimitCrossed;

  const ScreenTimeAppUsageUiModel({
    required this.appName,
    required this.minutes,
    required this.category,
    required this.riskLevel,
    this.limitMinutes,
    this.isLimitCrossed = false,
  });

  String get formattedDuration {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }
}

class ScreenTimeRiskWindowUiModel {
  final String startLabel;
  final String endLabel;
  final String riskLevel;
  final String? topApp;
  final String? suggestion;

  const ScreenTimeRiskWindowUiModel({
    required this.startLabel,
    required this.endLabel,
    required this.riskLevel,
    this.topApp,
    this.suggestion,
  });

  String get windowLabel => '$startLabel - $endLabel';
}

class ScreenTimeWeeklyPointUiModel {
  final String dayLabel;
  final int totalMinutes;
  final String riskLevel;

  const ScreenTimeWeeklyPointUiModel({
    required this.dayLabel,
    required this.totalMinutes,
    required this.riskLevel,
  });

  String get formattedDuration {
    if (totalMinutes < 60) return '${totalMinutes}m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }
}
