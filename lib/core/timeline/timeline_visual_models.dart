/// Represents any item that needs to be laid out on a timeline.
abstract interface class TimelineVisualItem {
  /// Unique identifier for this item.
  String get id;

  /// Start time in minutes from midnight (0..1440+).
  int get startMinute;

  /// End time in minutes from midnight (0..1440+).
  int get endMinute;

  /// Minimum height required to display this item's content.
  double get minHeight;

  /// Priority used to determine front-most item when overlapping.
  int get priority;
}

/// Represents a segment where the timeline is stretched to accommodate content.
class TimelineStretchedSegment {
  final int startMinute;
  final int endMinute;
  final double extraStretch;

  const TimelineStretchedSegment({
    required this.startMinute,
    required this.endMinute,
    required this.extraStretch,
  });
}

/// Configuration for timeline density.
enum TimelineDensity { compact, standard, comfortable }

/// Visual scaling and padding for the timeline.
class TimelineVisualScale {
  final int startMinute;
  final int endMinute;
  final double pixelsPerMinute;
  final double topPadding;
  final List<TimelineStretchedSegment> stretchedSegments;

  const TimelineVisualScale({
    required this.startMinute,
    required this.endMinute,
    required this.pixelsPerMinute,
    this.topPadding = 0.0,
    this.stretchedSegments = const [],
  });

  int get durationMinutes => endMinute - startMinute;
}

/// Represents an item mapped to visual space with its overlap info.
class TimelineVisualEntry<T extends TimelineVisualItem> {
  final T item;
  final int lane;
  final int order;
  final bool hasOverlap;
  final bool isFront;

  // The calculated visual layout properties
  final double top;
  final double height;
  final double left;
  final double right;

  const TimelineVisualEntry({
    required this.item,
    required this.lane,
    required this.order,
    required this.hasOverlap,
    required this.isFront,
    required this.top,
    required this.height,
    required this.left,
    required this.right,
  });

  TimelineVisualEntry<T> copyWith({
    T? item,
    int? lane,
    int? order,
    bool? hasOverlap,
    bool? isFront,
    double? top,
    double? height,
    double? left,
    double? right,
  }) {
    return TimelineVisualEntry<T>(
      item: item ?? this.item,
      lane: lane ?? this.lane,
      order: order ?? this.order,
      hasOverlap: hasOverlap ?? this.hasOverlap,
      isFront: isFront ?? this.isFront,
      top: top ?? this.top,
      height: height ?? this.height,
      left: left ?? this.left,
      right: right ?? this.right,
    );
  }
}

/// A group of entries that overlap each other.
class TimelineOverlapGroup<T extends TimelineVisualItem> {
  final List<TimelineVisualEntry<T>> entries;

  const TimelineOverlapGroup(this.entries);
}

/// The final immutable layout result.
class TimelineLayoutResult<T extends TimelineVisualItem> {
  final TimelineVisualScale scale;
  final List<TimelineVisualEntry<T>> entries;
  final double totalHeight;

  const TimelineLayoutResult({
    required this.scale,
    required this.entries,
    required this.totalHeight,
  });
}
