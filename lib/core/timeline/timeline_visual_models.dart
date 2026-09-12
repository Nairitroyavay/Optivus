import 'package:flutter/foundation.dart';
export 'timeline_tab_placement.dart';

/// Represents an item with a time interval in minutes.
abstract interface class TimelineInterval {
  /// Unique identifier for this item.
  String get id;

  /// Start time in minutes from midnight (0..1440+).
  int get startMinute;

  /// End time in minutes from midnight (0..1440+).
  int get endMinute;
}

/// Represents any item that needs to be laid out on a timeline.
abstract interface class TimelineVisualItem implements TimelineInterval {
  @override
  String get id;

  @override
  int get startMinute;

  @override
  int get endMinute;

  /// Minimum height required to display this item's content.
  double get minHeight;

  /// Priority used to determine front-most item when overlapping.
  int get priority;
}

/// An atomic interval with overlapping items on the timeline.
@immutable
class TimelineOverlapRegion {
  final int startMinute;
  final int endMinute;
  final List<String> itemIds;

  const TimelineOverlapRegion({
    required this.startMinute,
    required this.endMinute,
    required this.itemIds,
  });

  String get key => '${startMinute}_$endMinute';
  String keyForDay(int day) =>
      '$day:$startMinute:$endMinute:${itemIds.join(',')}';
  List<String> get entryIds => itemIds;
}

/// A connected cluster of overlapping items.
@immutable
class TimelineOverlapComponent {
  final String id;
  final List<String> itemIds;

  const TimelineOverlapComponent({required this.id, required this.itemIds});
  List<String> get entryIds => itemIds;
}

/// Splits timeline items into exact, non-transitive concurrency regions.
List<TimelineOverlapRegion> buildTimelineOverlapRegions(
  List<TimelineInterval> items,
) {
  if (items.isEmpty) return const [];
  final points =
      items
          .expand((item) => [item.startMinute, item.endMinute])
          .toSet()
          .toList()
        ..sort();
  final result = <TimelineOverlapRegion>[];
  for (var index = 0; index < points.length - 1; index++) {
    final start = points[index];
    final end = points[index + 1];
    if (start == end) continue;
    final active =
        items
            .where((item) => item.startMinute < end && item.endMinute > start)
            .map((item) => item.id)
            .toList()
          ..sort();
    if (active.isEmpty) continue;
    if (result.isNotEmpty &&
        result.last.endMinute == start &&
        _sameOverlapIds(result.last.itemIds, active)) {
      final previous = result.removeLast();
      result.add(
        TimelineOverlapRegion(
          startMinute: previous.startMinute,
          endMinute: end,
          itemIds: active,
        ),
      );
    } else {
      result.add(
        TimelineOverlapRegion(
          startMinute: start,
          endMinute: end,
          itemIds: active,
        ),
      );
    }
  }
  return List.unmodifiable(result);
}

bool _sameOverlapIds(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

/// Builds connected interaction components across overlapping items.
List<TimelineOverlapComponent> buildTimelineOverlapComponents(
  List<TimelineInterval> items, {
  int? day,
}) {
  if (items.isEmpty) return const [];
  final byId = {for (final item in items) item.id: item};
  final remaining = byId.keys.toSet();
  final result = <TimelineOverlapComponent>[];
  while (remaining.isNotEmpty) {
    final seed = (remaining.toList()..sort()).first;
    final queue = <String>[seed];
    final connected = <String>[];
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (!remaining.remove(id)) continue;
      connected.add(id);
      final entry = byId[id]!;
      for (final candidateId in remaining.toList()) {
        final candidate = byId[candidateId]!;
        if (entry.startMinute < candidate.endMinute &&
            entry.endMinute > candidate.startMinute) {
          queue.add(candidateId);
        }
      }
    }
    if (connected.length > 1) {
      connected.sort();
      final compId = day != null
          ? '$day:${connected.join(',')}'
          : 'comp_${connected.join('_')}';
      result.add(
        TimelineOverlapComponent(
          id: compId,
          itemIds: List.unmodifiable(connected),
        ),
      );
    }
  }
  result.sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(result);
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
