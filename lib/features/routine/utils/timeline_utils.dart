import 'dart:math';

import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/timeline_layout.dart';

/// Utility functions for routine timeline calculations.
class TimelineUtils {
  TimelineUtils._();

  /// Calculate smart visible range based on routine items.
  ///
  /// Default: 30 min before first item, 30 min after last item,
  /// rounded to nearest 10 min. Falls back to 7:00 AM – 11:00 PM if empty.
  static TimelineLayout calculateVisibleRange(
    List<RoutineItem> items, {
    bool showFullDay = false,
    double minuteHeight = 5.0,
    bool showMinuteTicks = true,
    bool compactMode = false,
  }) {
    if (showFullDay) {
      return TimelineLayout(
        visibleStartMinute: 0,
        visibleEndMinute: 1440,
        minuteHeight: minuteHeight,
        showMinuteTicks: showMinuteTicks,
        showFullDay: true,
        compactMode: compactMode,
      );
    }

    if (items.isEmpty) {
      return TimelineLayout(
        visibleStartMinute: 420, // 7:00 AM
        visibleEndMinute: 1380, // 11:00 PM
        minuteHeight: minuteHeight,
        showMinuteTicks: showMinuteTicks,
        showFullDay: false,
        compactMode: compactMode,
      );
    }

    final firstStart = items.map((e) => e.startMinute).reduce(min);
    final lastEnd = items.map((e) => e.effectiveEndMinute).reduce(max);

    // 30 min buffer, rounded to nearest 10 min
    final visibleStart = ((firstStart - 30) / 10).floor() * 10;
    final visibleEnd = ((lastEnd + 30) / 10).ceil() * 10;

    return TimelineLayout(
      visibleStartMinute: visibleStart.clamp(0, 1430),
      visibleEndMinute: visibleEnd.clamp(10, 1440),
      minuteHeight: minuteHeight,
      showMinuteTicks: showMinuteTicks,
      showFullDay: false,
      compactMode: compactMode,
    );
  }

  /// Format minutes since midnight to a time string like "7:40 AM".
  static String formatMinute(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0
        ? 12
        : h > 12
            ? h - 12
            : h;
    return '$displayHour:${m.toString().padLeft(2, '0')} $period';
  }

  /// Format minutes to short time for ruler labels (e.g., "7:00", "7:10").
  static String formatMinuteShort(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final displayHour = h == 0
        ? 12
        : h > 12
            ? h - 12
            : h;
    return '$displayHour:${m.toString().padLeft(2, '0')}';
  }

  /// Format a time range like "7:40 - 7:45 AM" or "7:40 AM - 8:00 AM".
  static String formatTimeRange(int startMinute, int endMinute) {
    final startPeriod = startMinute ~/ 60 >= 12 ? 'PM' : 'AM';
    final endPeriod = endMinute ~/ 60 >= 12 ? 'PM' : 'AM';

    if (startPeriod == endPeriod) {
      // Same period: "7:40 - 8:00 AM"
      return '${_formatTimeOnly(startMinute)} - ${formatMinute(endMinute)}';
    }
    // Different periods: "11:30 AM - 12:00 PM"
    return '${formatMinute(startMinute)} - ${formatMinute(endMinute)}';
  }

  /// Format just the time part without AM/PM.
  static String _formatTimeOnly(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final displayHour = h == 0
        ? 12
        : h > 12
            ? h - 12
            : h;
    return '$displayHour:${m.toString().padLeft(2, '0')}';
  }

  /// Format duration in minutes to readable string.
  static String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Get abbreviated day label: "TOD", "TMR", "WED", etc.
  static String getDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'TOD';
    if (diff == 1) return 'TMR';

    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  /// Get the month name abbreviated.
  static String getMonthAbbr(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  /// Get the full day name.
  static String getDayName(int weekday) {
    const days = [
      'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY',
      'FRIDAY', 'SATURDAY', 'SUNDAY',
    ];
    return days[(weekday - 1).clamp(0, 6)];
  }

  /// Get short day name (e.g., "MON", "TUE").
  static String getShortDayName(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[(weekday - 1).clamp(0, 6)];
  }

  /// Check if a date is today.
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if a date is tomorrow.
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  /// Filter routine items by the active filter.
  static List<RoutineItem> filterItems(
    List<RoutineItem> items,
    String filter,
  ) {
    switch (filter) {
      case 'all':
        return items;
      case 'base_timeline':
        return items
            .where((i) =>
                i.blockType == RoutineBlockType.hardBlock ||
                i.blockType == RoutineBlockType.softBlock)
            .toList();
      case 'flexible_tasks':
        return items
            .where((i) => i.blockType == RoutineBlockType.flexibleTask)
            .toList();
      case 'tracker_tasks':
        return items
            .where((i) => i.blockType == RoutineBlockType.trackerTask)
            .toList();
      case 'check_ins':
        return items
            .where((i) => i.blockType == RoutineBlockType.checkIn)
            .toList();
      case 'conflicts':
        return items.where((i) => i.hasConflict).toList();
      case 'completed':
        return items
            .where((i) =>
                i.isCompleted || i.status == RoutineStatus.completed)
            .toList();
      case 'missed':
        return items
            .where(
                (i) => i.isMissed || i.status == RoutineStatus.missed)
            .toList();
      default:
        return items;
    }
  }
}
