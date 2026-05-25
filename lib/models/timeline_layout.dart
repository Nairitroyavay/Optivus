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
  double get totalHeight =>
      (visibleEndMinute - visibleStartMinute) * minuteHeight;

  /// Total minutes visible.
  int get totalMinutes => visibleEndMinute - visibleStartMinute;

  /// Calculate the top position for a given minute.
  double topForMinute(int minute) =>
      (minute - visibleStartMinute) * minuteHeight;

  /// Calculate the height for a duration in minutes.
  double heightForDuration(int durationMinutes) =>
      durationMinutes * minuteHeight;

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
