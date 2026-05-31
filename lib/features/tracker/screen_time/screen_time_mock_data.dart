import 'screen_time_models.dart';

class ScreenTimeMockData {
  static const int totalScreenTimeMinutes = 260; // 4h 20m
  static const String riskLevel = 'High';
  static const int limitCrossedMinutes = 80; // 1h 20m
  static const int focusScore = 45;
  static const String bestFocusBlock = '9:00 AM - 11:00 AM';
  static const String weeklyReductionPercent = '18';

  static const List<ScreenTimeAppUsageUiModel> topAppsToday = [
    ScreenTimeAppUsageUiModel(
      appName: 'Instagram',
      minutes: 200,
      category: 'Doom app',
      riskLevel: 'High',
      limitMinutes: 60,
      isLimitCrossed: true,
    ),
    ScreenTimeAppUsageUiModel(
      appName: 'YouTube',
      minutes: 45,
      category: 'Doom app',
      riskLevel: 'Medium',
      limitMinutes: 60,
      isLimitCrossed: false,
    ),
    ScreenTimeAppUsageUiModel(
      appName: 'Chrome',
      minutes: 30,
      category: 'Productive',
      riskLevel: 'Neutral',
    ),
    ScreenTimeAppUsageUiModel(
      appName: 'WhatsApp',
      minutes: 25,
      category: 'Neutral',
      riskLevel: 'Neutral',
    ),
  ];

  static const List<ScreenTimeRiskWindowUiModel> focusLossWindows = [
    ScreenTimeRiskWindowUiModel(
      startLabel: '10:30 PM',
      endLabel: '12:00 AM',
      riskLevel: 'High',
      topApp: 'Instagram',
      suggestion:
          'Your highest risk window is 10:30 PM - 12:00 AM. Instagram is your most-used high-risk app today.',
    ),
    ScreenTimeRiskWindowUiModel(
      startLabel: '4:00 PM',
      endLabel: '4:40 PM',
      riskLevel: 'Medium',
    ),
    ScreenTimeRiskWindowUiModel(
      startLabel: '12:30 PM',
      endLabel: '1:00 PM',
      riskLevel: 'Low',
    ),
  ];

  static const List<ScreenTimeWeeklyPointUiModel> weeklyData = [
    ScreenTimeWeeklyPointUiModel(
      dayLabel: 'Mon',
      totalMinutes: 220,
      riskLevel: 'Medium',
    ), // 3h 40m
    ScreenTimeWeeklyPointUiModel(
      dayLabel: 'Tue',
      totalMinutes: 175,
      riskLevel: 'Low',
    ), // 2h 55m
    ScreenTimeWeeklyPointUiModel(
      dayLabel: 'Wed',
      totalMinutes: 260,
      riskLevel: 'High',
    ), // 4h 20m
    ScreenTimeWeeklyPointUiModel(
      dayLabel: 'Thu',
      totalMinutes: 190,
      riskLevel: 'Medium',
    ), // 3h 10m
    ScreenTimeWeeklyPointUiModel(
      dayLabel: 'Fri',
      totalMinutes: 230,
      riskLevel: 'High',
    ), // 3h 50m
    ScreenTimeWeeklyPointUiModel(
      dayLabel: 'Sat',
      totalMinutes: 305,
      riskLevel: 'High',
    ), // 5h 05m
    ScreenTimeWeeklyPointUiModel(
      dayLabel: 'Sun',
      totalMinutes: 240,
      riskLevel: 'High',
    ), // 4h 00m
  ];

  static const List<String> doomAppsCategories = [
    'Instagram',
    'YouTube Shorts',
    'Facebook',
    'Snapchat',
    'X',
    'short-video apps',
  ];

  static const List<String> productiveAppsCategories = [
    'Notes',
    'learning apps',
    'reading apps',
    'work apps',
    'coding apps',
  ];

  static const List<String> neutralAppsCategories = [
    'Maps',
    'Phone',
    'Messages',
    'Utilities',
  ];
}
