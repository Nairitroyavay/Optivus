import 'dart:math' as math;
import 'package:optivus/models/onboarding_draft.dart';

class EatingDaySummary {
  final int day;
  final String dayName;
  final int mealCount;
  final int? totalCalories;
  final double? totalProtein;
  final bool isPartial;
  final String displayText;
  final String? macrosText;

  const EatingDaySummary({
    required this.day,
    required this.dayName,
    required this.mealCount,
    required this.totalCalories,
    required this.totalProtein,
    required this.isPartial,
    required this.displayText,
    this.macrosText,
  });
}

class EatingPresentationUtils {
  static const List<String> dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String dayName(int day) {
    if (day >= 1 && day <= 7) return dayNames[day - 1];
    return 'Day $day';
  }

  static String scheduleSummary(List<TimelineBlockDraft> blocks) {
    if (blocks.isEmpty) return 'No meals scheduled';

    final counts = <int>[];
    for (var d = 1; d <= 7; d++) {
      final count = blocks.where((b) => b.repeatDays.contains(d)).length;
      counts.add(count);
    }

    final minCount = counts.reduce(math.min);
    final maxCount = counts.reduce(math.max);

    if (minCount == maxCount) {
      if (minCount == 0) return 'No meals scheduled';
      if (minCount == 1) return '1 meal/day';
      return '$minCount meals/day';
    }

    if (minCount == 0) {
      final activeCounts = counts.where((c) => c > 0).toList();
      if (activeCounts.isEmpty) return 'No meals scheduled';
      final activeMin = activeCounts.reduce(math.min);
      final activeMax = activeCounts.reduce(math.max);
      if (activeMin == activeMax) {
        return '$activeMin meals/day (${activeCounts.length} days/week)';
      }
      return 'Varies by day · $activeMin–$activeMax meals';
    }

    return 'Varies by day · $minCount–$maxCount meals';
  }

  static EatingDaySummary daySummary(List<TimelineBlockDraft> blocks, int day) {
    final dName = dayName(day);
    final dayBlocks = blocks.where((b) => b.repeatDays.contains(day)).toList()
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    if (dayBlocks.isEmpty) {
      return EatingDaySummary(
        day: day,
        dayName: dName,
        mealCount: 0,
        totalCalories: 0,
        totalProtein: 0.0,
        isPartial: false,
        displayText: 'No meals scheduled',
        macrosText: null,
      );
    }

    int? totalCal;
    double? totalProt;
    bool hasAnyCal = false;
    bool hasAnyProt = false;
    bool hasMissingCal = false;
    bool hasMissingProt = false;

    for (final b in dayBlocks) {
      if (b.calories != null && b.calories! > 0) {
        hasAnyCal = true;
        totalCal = (totalCal ?? 0) + b.calories!.round();
      } else {
        hasMissingCal = true;
      }
      if (b.protein != null && b.protein! > 0) {
        hasAnyProt = true;
        totalProt = (totalProt ?? 0.0) + b.protein!;
      } else {
        hasMissingProt = true;
      }
    }

    final isPartial = hasMissingCal || hasMissingProt;
    final count = dayBlocks.length;
    final mealCountText = count == 1 ? '1 meal' : '$count meals';

    String macrosDesc;
    if (!hasAnyCal && !hasAnyProt) {
      macrosDesc = 'Nutrition estimates partial';
    } else if (isPartial) {
      if (hasAnyCal && totalCal != null && totalCal > 0) {
        macrosDesc = '~$totalCal kcal · partial';
      } else {
        macrosDesc = 'Nutrition estimates partial';
      }
    } else {
      final protRound = totalProt?.round() ?? 0;
      macrosDesc = '~$totalCal kcal · ${protRound}g protein';
    }

    return EatingDaySummary(
      day: day,
      dayName: dName,
      mealCount: count,
      totalCalories: totalCal,
      totalProtein: totalProt,
      isPartial: isPartial,
      displayText: '$mealCountText · $macrosDesc',
      macrosText: macrosDesc,
    );
  }

  static String formatSlotName(String? slot, [String? category]) {
    final raw = (slot != null && slot.trim().isNotEmpty)
        ? slot.trim()
        : (category != null && category.trim().isNotEmpty
            ? category.trim()
            : '');
    if (raw.isEmpty) return 'Meal';

    return switch (raw.toLowerCase()) {
      'breakfast' => 'Breakfast',
      'morning_snack' => 'Morning Snack',
      'lunch' => 'Lunch',
      'afternoon_snack' => 'Afternoon Snack',
      'snack' => 'Snack',
      'dinner' => 'Dinner',
      'extra_snack' => 'Extra Snack',
      _ => raw
          .split('_')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' '),
    };
  }

  static String formatDiet(String? foodType) {
    if (foodType == null || foodType.trim().isEmpty) return 'Not set';
    final clean = foodType.trim().toLowerCase();
    return switch (clean) {
      'vegetarian' => 'Vegetarian',
      'vegan' => 'Vegan',
      'eggetarian' => 'Eggetarian',
      'non_vegetarian' || 'non-vegetarian' => 'Non-Vegetarian',
      'mixed' => 'Mixed',
      _ => clean[0].toUpperCase() + clean.substring(1),
    };
  }

  static String formatFoodStyle(String? mode, String? customText) {
    if (mode == null || mode.trim().isEmpty) return 'Not set';
    final clean = mode.trim().toLowerCase();
    if (clean == 'custom') {
      return (customText != null && customText.trim().isNotEmpty)
          ? customText.trim()
          : 'Custom';
    }
    return switch (clean) {
      'indian' => 'Indian',
      'mediterranean' => 'Mediterranean',
      'balanced' => 'Balanced',
      'western' => 'Western',
      'asian' => 'Asian',
      _ => clean[0].toUpperCase() + clean.substring(1),
    };
  }

  static String formatTime(int minute) {
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    final period = h < 12 ? 'AM' : 'PM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final displayM = m < 10 ? '0$m' : '$m';
    return '$displayH:$displayM $period';
  }

  static String formatTimeRange(int startMinute, int endMinute) {
    return '${formatTime(startMinute)} – ${formatTime(endMinute)}';
  }

  static String formatPreferredMealTimes({
    int? breakfast,
    int? morningSnack,
    int? lunch,
    int? afternoonSnack,
    int? dinner,
  }) {
    final parts = <String>[];
    if (breakfast != null) parts.add('Breakfast ${formatTime(breakfast)}');
    if (morningSnack != null) parts.add('Snack ${formatTime(morningSnack)}');
    if (lunch != null) parts.add('Lunch ${formatTime(lunch)}');
    if (afternoonSnack != null) parts.add('Snack ${formatTime(afternoonSnack)}');
    if (dinner != null) parts.add('Dinner ${formatTime(dinner)}');
    return parts.join(' · ');
  }
}
