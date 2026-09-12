import 'package:flutter/foundation.dart';
import 'timeline_entry.dart';

/// Configuration parameters for timeline geometry calculation.
@immutable
class TimelineGeometryConfig {
  /// Vertical pixels per minute (e.g. 1.0 = 60px/hr, 1.4 = 84px/hr).
  final double pixelsPerMinute;

  /// Default start minute for waking hours (e.g. 7:00 AM = 420).
  final int defaultStartMinute;

  /// Default end minute for waking hours (e.g. 11:00 PM = 1380).
  final int defaultEndMinute;

  /// Minimum interactive height for any block card (regardless of duration).
  final double minInteractiveHeight;

  /// Width of the vertical time rail area.
  final double railWidth;

  /// Left offset where block content starts.
  final double leftOffset;

  /// Right padding from the edge of the viewport.
  final double rightPadding;

  /// Horizontal gap between overlapping columns.
  final double columnGap;

  /// Top padding above the earliest visible minute.
  final double topPadding;

  /// Bottom padding below the latest visible minute.
  final double bottomPadding;

  const TimelineGeometryConfig({
    this.pixelsPerMinute = 1.1,
    this.defaultStartMinute = 420, // 7:00 AM
    this.defaultEndMinute = 1380, // 11:00 PM
    this.minInteractiveHeight = 34.0,
    this.railWidth = 54.0,
    this.leftOffset = 62.0,
    this.rightPadding = 16.0,
    this.columnGap = 6.0,
    this.topPadding = 18.0,
    this.bottomPadding = 80.0,
  });

  TimelineGeometryConfig copyWith({
    double? pixelsPerMinute,
    int? defaultStartMinute,
    int? defaultEndMinute,
    double? minInteractiveHeight,
    double? railWidth,
    double? leftOffset,
    double? rightPadding,
    double? columnGap,
    double? topPadding,
    double? bottomPadding,
  }) {
    return TimelineGeometryConfig(
      pixelsPerMinute: pixelsPerMinute ?? this.pixelsPerMinute,
      defaultStartMinute: defaultStartMinute ?? this.defaultStartMinute,
      defaultEndMinute: defaultEndMinute ?? this.defaultEndMinute,
      minInteractiveHeight: minInteractiveHeight ?? this.minInteractiveHeight,
      railWidth: railWidth ?? this.railWidth,
      leftOffset: leftOffset ?? this.leftOffset,
      rightPadding: rightPadding ?? this.rightPadding,
      columnGap: columnGap ?? this.columnGap,
      topPadding: topPadding ?? this.topPadding,
      bottomPadding: bottomPadding ?? this.bottomPadding,
    );
  }
}

enum TimelineVisibleRangePolicy { legacy, contentAdaptive }

enum TimelineStretchPolicy { legacy, constraintBased }

/// Overlap presentation mode for the timeline.
enum TimelineOverlapPresentation {
  /// Concurrently overlapping items are partitioned into side-by-side columns.
  sideBySide,

  /// Overlapping items present as a readable front card with exposed back card strip(s).
  frontAndExposed,
}

/// A segment of the timeline that has been stretched vertically to fit content.
@immutable
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

/// Scale mapping minute of day to vertical coordinate in pixels.
@immutable
class TimelineScale {
  final int startMinute;
  final int endMinute;
  final double pixelsPerMinute;
  final double topPadding;
  final List<TimelineStretchedSegment> stretchedSegments;

  const TimelineScale({
    required this.startMinute,
    required this.endMinute,
    required this.pixelsPerMinute,
    required this.topPadding,
    this.stretchedSegments = const [],
  });

  /// Calculates Y position for a given minute of day.
  double yForMinute(int minute) {
    return (minute - startMinute) * pixelsPerMinute +
        _stretchAtMinute(minute.toDouble()) +
        topPadding;
  }

  /// Calculates minute of day for a given Y position.
  int minuteForY(double y) {
    if (y <= topPadding) return startMinute;
    var low = startMinute.toDouble();
    var high = endMinute.toDouble();
    for (var i = 0; i < 48; i++) {
      final mid = (low + high) / 2;
      if (_yForMinuteDouble(mid) < y) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return ((low + high) / 2).round().clamp(startMinute, endMinute);
  }

  /// Exact pixel height for a minute range.
  double heightForRange(int start, int end) {
    if (end <= start) return 0;
    return yForMinute(end) - yForMinute(start);
  }

  double _yForMinuteDouble(double minute) =>
      (minute - startMinute) * pixelsPerMinute +
      _stretchAtMinute(minute) +
      topPadding;

  double _stretchAtMinute(double minute) {
    double stretch = 0.0;
    for (final seg in stretchedSegments) {
      if (minute <= seg.startMinute) continue;
      if (minute >= seg.endMinute) {
        stretch += seg.extraStretch;
        continue;
      }
      final fraction =
          (minute - seg.startMinute) / (seg.endMinute - seg.startMinute);
      stretch += fraction * seg.extraStretch;
    }
    return stretch;
  }
}

/// A timeline entry with calculated layout geometry.
@immutable
class PositionedTimelineEntry {
  final TimelineEntry entry;
  final double top;
  final double height;
  final double left;
  final double width;
  final int column;
  final int columnCount;
  final bool isFront;
  final bool hasOverlap;

  const PositionedTimelineEntry({
    required this.entry,
    required this.top,
    required this.height,
    required this.left,
    required this.width,
    required this.column,
    required this.columnCount,
    this.isFront = true,
    this.hasOverlap = false,
  });

  String get id => entry.id;
  int get startMinute => entry.startMinute;
  int get endMinute => entry.endMinute;
  double get right => left + width;
  double get bottom => top + height;

  PositionedTimelineEntry copyWith({
    TimelineEntry? entry,
    double? top,
    double? height,
    double? left,
    double? width,
    int? column,
    int? columnCount,
    bool? isFront,
    bool? hasOverlap,
  }) {
    return PositionedTimelineEntry(
      entry: entry ?? this.entry,
      top: top ?? this.top,
      height: height ?? this.height,
      left: left ?? this.left,
      width: width ?? this.width,
      column: column ?? this.column,
      columnCount: columnCount ?? this.columnCount,
      isFront: isFront ?? this.isFront,
      hasOverlap: hasOverlap ?? this.hasOverlap,
    );
  }

  @override
  String toString() =>
      'PositionedTimelineEntry(${entry.id}, col: $column/$columnCount, front: $isFront, overlap: $hasOverlap, top: $top, h: $height, left: $left, w: $width)';
}

/// The result of timeline layout calculation.
@immutable
class TimelineLayoutResult {
  final TimelineScale scale;
  final List<PositionedTimelineEntry> entries;
  final double totalHeight;
  final List<int> boundaryMinutes;
  final int visibleStartMinute;
  final int visibleEndMinute;

  const TimelineLayoutResult({
    required this.scale,
    required this.entries,
    required this.totalHeight,
    required this.boundaryMinutes,
    required this.visibleStartMinute,
    required this.visibleEndMinute,
  });

  /// Map of entry id to positioned entry.
  Map<String, PositionedTimelineEntry> get entryMap => {
    for (final entry in entries) entry.id: entry,
  };
}
