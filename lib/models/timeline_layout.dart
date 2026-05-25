/// Configuration for the routine timeline viewport.
class TimelineLayout {
  final int visibleStartMinute;
  final int visibleEndMinute;
  final double minuteHeight;
  final bool showMinuteTicks;
  final bool showFullDay;
  final bool compactMode;

  const TimelineLayout({
    this.visibleStartMinute = 420, // 7:00 AM default
    this.visibleEndMinute = 1380, // 11:00 PM default
    this.minuteHeight = 5.0, // 1 min = 5px, 1 hour = 300px
    this.showMinuteTicks = true,
    this.showFullDay = false,
    this.compactMode = false,
  });

  /// Total pixel height of the visible timeline range.
  double get totalHeight => totalMinutes * minuteHeight;

  /// Total minutes visible.
  int get totalMinutes {
    final minutes = visibleEndMinute - visibleStartMinute;
    return minutes < 0 ? 0 : minutes;
  }

  /// Calculate the top position for a given minute.
  double topForMinute(int minute) =>
      (minute - visibleStartMinute) * minuteHeight;

  /// Calculate the exact pixel height for a normalized minute range.
  double heightForRange(int startMinute, int endMinute) {
    final minutes = endMinute - startMinute;
    return (minutes < 0 ? 0 : minutes) * minuteHeight;
  }

  /// Calculate the height for a duration in minutes.
  double heightForDuration(int durationMinutes) =>
      (durationMinutes < 0 ? 0 : durationMinutes) * minuteHeight;

  /// Whether a minute sits inside the visible timeline range.
  bool isMinuteVisible(int minute) =>
      minute >= visibleStartMinute && minute <= visibleEndMinute;

  /// Clamp a minute to the visible timeline range.
  int clampMinuteToVisibleRange(int minute) {
    if (minute < visibleStartMinute) return visibleStartMinute;
    if (minute > visibleEndMinute) return visibleEndMinute;
    return minute;
  }

  /// Round a minute down to the nearest 10-minute boundary.
  int roundDownToNearestTen(int minute) => (minute / 10).floor() * 10;

  /// Round a minute up to the nearest 10-minute boundary.
  int roundUpToNearestTen(int minute) => (minute / 10).ceil() * 10;

  TimelineLayout copyWith({
    int? visibleStartMinute,
    int? visibleEndMinute,
    double? minuteHeight,
    bool? showMinuteTicks,
    bool? showFullDay,
    bool? compactMode,
  }) {
    return TimelineLayout(
      visibleStartMinute: visibleStartMinute ?? this.visibleStartMinute,
      visibleEndMinute: visibleEndMinute ?? this.visibleEndMinute,
      minuteHeight: minuteHeight ?? this.minuteHeight,
      showMinuteTicks: showMinuteTicks ?? this.showMinuteTicks,
      showFullDay: showFullDay ?? this.showFullDay,
      compactMode: compactMode ?? this.compactMode,
    );
  }
}
