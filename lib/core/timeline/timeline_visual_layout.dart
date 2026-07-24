import 'dart:math' as math;
import 'timeline_visual_models.dart';

/// Layout engine for timeline visual calculation
class TimelineVisualLayout {
  /// Builds the layout result for a list of items.
  static TimelineLayoutResult<T> build<T extends TimelineVisualItem>({
    required List<T> items,
    required double pixelsPerMinute,
    required double timelineWidth,
    required String? focusedItemId,
    int? visibleStartMinute,
    int? visibleEndMinute,
    double topPadding = 0.0,
    List<TimelineStretchedSegment> stretchedSegments = const [],
    int maxOverlapLane = 2,
    double leftOffset = 48.0,
    double rightPadding = 16.0,
    double overlapMinFrontWidth = 140.0,
    double overlapMinLabelWidth = 70.0,
    double overlapMaxLabelWidth = 96.0,
  }) {
    final effectiveStretchedSegments = _segmentsForMinimumHeights(
      items: items,
      pixelsPerMinute: pixelsPerMinute,
      stretchedSegments: stretchedSegments,
    );
    final scale = _createScale(
      items,
      pixelsPerMinute,
      topPadding,
      effectiveStretchedSegments,
      visibleStartMinute: visibleStartMinute,
      visibleEndMinute: visibleEndMinute,
    );
    final sortedItems = List<T>.from(items)..sort(_compareItemsByTime);
    final visualEntries = _buildVisualEntries(
      sortedItems,
      maxOverlapLane,
      focusedItemId,
    );

    final exposedLabelWidth = _calculateExposedLabelWidth(
      timelineWidth,
      leftOffset,
      rightPadding,
      overlapMinFrontWidth,
      overlapMinLabelWidth,
      overlapMaxLabelWidth,
    );

    final List<TimelineVisualEntry<T>> finalEntries = [];
    double totalHeight = topPadding;

    for (final entry in visualEntries) {
      final top = scale.yForMinute(entry.item.startMinute);
      final bottom = scale.yForMinute(entry.item.endMinute);
      final exactHeight = bottom - top;
      final height = math.max(entry.item.minHeight, exactHeight);

      final left = _leftForVisual(
        entry,
        visualEntries,
        leftOffset,
        exposedLabelWidth,
      );
      final right = _rightForVisual(
        entry,
        visualEntries,
        rightPadding,
        maxOverlapLane,
      );

      finalEntries.add(
        entry.copyWith(top: top, height: height, left: left, right: right),
      );

      if (top + height > totalHeight) {
        totalHeight = top + height;
      }
    }

    final maxScaleHeight = scale.yForMinute(scale.endMinute);
    if (totalHeight < maxScaleHeight) {
      totalHeight = maxScaleHeight;
    }

    return TimelineLayoutResult<T>(
      scale: scale,
      entries: finalEntries,
      totalHeight: totalHeight,
    );
  }

  // --- Range & Scale ---
  static TimelineVisualScale _createScale<T extends TimelineVisualItem>(
    List<T> items,
    double pixelsPerMinute,
    double topPadding,
    List<TimelineStretchedSegment> stretchedSegments, {
    int? visibleStartMinute,
    int? visibleEndMinute,
  }) {
    if (visibleStartMinute != null && visibleEndMinute != null) {
      return TimelineVisualScale(
        startMinute: visibleStartMinute,
        endMinute: visibleEndMinute,
        pixelsPerMinute: pixelsPerMinute,
        topPadding: topPadding,
        stretchedSegments: _mergeSegments(stretchedSegments),
      );
    }
    var startHour = 6;
    var endHour = 23;
    if (items.isNotEmpty) {
      final minStart = items.map((i) => i.startMinute).reduce(math.min);
      final maxEnd = items.map((i) => i.endMinute).reduce(math.max);
      if (minStart < 6 * 60) {
        startHour = (minStart ~/ 60).clamp(0, 23);
      }
      if (maxEnd > 23 * 60) {
        endHour = ((maxEnd + 59) ~/ 60).clamp(startHour + 1, 24);
      }
    }
    return TimelineVisualScale(
      startMinute: startHour * 60,
      endMinute: endHour * 60,
      pixelsPerMinute: pixelsPerMinute,
      topPadding: topPadding,
      stretchedSegments: _mergeSegments(stretchedSegments),
    );
  }

  static List<TimelineStretchedSegment> _mergeSegments(
    List<TimelineStretchedSegment> segments,
  ) {
    if (segments.isEmpty) return [];
    final sorted = List<TimelineStretchedSegment>.from(segments)
      ..sort((a, b) {
        final cmp = a.startMinute.compareTo(b.startMinute);
        if (cmp != 0) return cmp;
        return a.endMinute.compareTo(b.endMinute);
      });

    final List<TimelineStretchedSegment> merged = [];
    var current = sorted[0];

    for (int i = 1; i < sorted.length; i++) {
      final next = sorted[i];
      if (next.startMinute < current.endMinute) {
        final newStart = current.startMinute;
        final newEnd = math.max(current.endMinute, next.endMinute);
        final newExtraStretch = current.extraStretch + next.extraStretch;
        current = TimelineStretchedSegment(
          startMinute: newStart,
          endMinute: newEnd,
          extraStretch: newExtraStretch,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    return merged;
  }

  static List<TimelineStretchedSegment>
  _segmentsForMinimumHeights<T extends TimelineVisualItem>({
    required List<T> items,
    required double pixelsPerMinute,
    required List<TimelineStretchedSegment> stretchedSegments,
  }) {
    final explicitSegments = _mergeSegments(stretchedSegments);
    final minimumSegments = <TimelineStretchedSegment>[];
    for (final item in items) {
      if (item.endMinute <= item.startMinute || item.minHeight <= 0) {
        continue;
      }
      final currentHeight =
          (item.endMinute - item.startMinute) * pixelsPerMinute +
          _stretchAtMinute(item.endMinute.toDouble(), explicitSegments) -
          _stretchAtMinute(item.startMinute.toDouble(), explicitSegments);
      final extra = item.minHeight - currentHeight;
      if (extra > 0) {
        minimumSegments.add(
          TimelineStretchedSegment(
            startMinute: item.startMinute,
            endMinute: item.endMinute,
            extraStretch: extra,
          ),
        );
      }
    }
    return _mergeSegments([...explicitSegments, ...minimumSegments]);
  }

  static double _stretchAtMinute(
    double minute,
    List<TimelineStretchedSegment> segments,
  ) {
    double stretch = 0.0;
    for (final seg in segments) {
      if (minute <= seg.startMinute) {
        continue;
      }
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

  // --- Sort & Layout ---
  static int _compareItemsByTime(TimelineVisualItem a, TimelineVisualItem b) {
    final startCompare = a.startMinute.compareTo(b.startMinute);
    if (startCompare != 0) return startCompare;
    final endCompare = a.endMinute.compareTo(b.endMinute);
    if (endCompare != 0) return endCompare;
    return a.id.compareTo(b.id);
  }

  static bool _itemsOverlap(TimelineVisualItem a, TimelineVisualItem b) {
    return a.startMinute < b.endMinute && a.endMinute > b.startMinute;
  }

  static List<TimelineVisualEntry<T>> _buildVisualEntries<
    T extends TimelineVisualItem
  >(List<T> sortedItems, int maxOverlapLane, String? focusedItemId) {
    final active = <TimelineVisualEntry<T>>[];
    final visualEntries = <TimelineVisualEntry<T>>[];

    for (final item in sortedItems) {
      active.removeWhere((entry) => !_itemsOverlap(item, entry.item));

      final usedLanes = active.map((entry) => entry.lane).toSet();
      var lane = 0;
      while (usedLanes.contains(lane) && lane < maxOverlapLane) {
        lane++;
      }
      if (usedLanes.contains(lane)) {
        lane = maxOverlapLane;
      }

      final hasOverlap = sortedItems.any(
        (other) => other.id != item.id && _itemsOverlap(item, other),
      );

      final visual = TimelineVisualEntry<T>(
        item: item,
        lane: lane,
        order: visualEntries.length,
        hasOverlap: hasOverlap,
        isFront: false,
        top: 0,
        height: 0,
        left: 0,
        right: 0,
      );
      active.add(visual);
      visualEntries.add(visual);
    }

    return visualEntries.map((entry) {
      final isFront = _isFrontVisual(entry, visualEntries, focusedItemId);
      return entry.copyWith(isFront: isFront);
    }).toList();
  }

  static bool _isFrontVisual<T extends TimelineVisualItem>(
    TimelineVisualEntry<T> visual,
    List<TimelineVisualEntry<T>> blocks,
    String? focusedItemId,
  ) {
    if (!visual.hasOverlap) return true;
    if (_groupHasFocusedItem(visual, blocks, focusedItemId)) {
      return visual.item.id == focusedItemId;
    }
    return _isDefaultFrontVisual(visual, blocks);
  }

  static bool _groupHasFocusedItem<T extends TimelineVisualItem>(
    TimelineVisualEntry<T> visual,
    List<TimelineVisualEntry<T>> blocks,
    String? focusedItemId,
  ) {
    if (focusedItemId == null) return false;
    final group = _overlapGroupFor(visual, blocks);
    return group.any((candidate) => candidate.item.id == focusedItemId);
  }

  static List<TimelineVisualEntry<T>> _overlapGroupFor<
    T extends TimelineVisualItem
  >(TimelineVisualEntry<T> visual, List<TimelineVisualEntry<T>> blocks) {
    final group = <TimelineVisualEntry<T>>[];
    final visited = <String>{};
    final queue = <TimelineVisualEntry<T>>[visual];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!visited.add(current.item.id)) continue;
      group.add(current);
      for (final candidate in blocks) {
        if (visited.contains(candidate.item.id)) continue;
        if (current.item.id != candidate.item.id &&
            _itemsOverlap(current.item, candidate.item)) {
          queue.add(candidate);
        }
      }
    }

    return group;
  }

  static bool _isDefaultFrontVisual<T extends TimelineVisualItem>(
    TimelineVisualEntry<T> visual,
    List<TimelineVisualEntry<T>> blocks,
  ) {
    for (final candidate in blocks) {
      if (candidate.item.id == visual.item.id) continue;
      if (!_itemsOverlap(candidate.item, visual.item)) continue;
      if (_compareDefaultFrontPriority(candidate, visual) < 0) {
        return false;
      }
    }
    return true;
  }

  static int _compareDefaultFrontPriority<T extends TimelineVisualItem>(
    TimelineVisualEntry<T> a,
    TimelineVisualEntry<T> b,
  ) {
    final aDuration = a.item.endMinute - a.item.startMinute;
    final bDuration = b.item.endMinute - b.item.startMinute;
    final durationCompare = aDuration.compareTo(bDuration);
    if (durationCompare != 0) return durationCompare;

    final priorityCompare = a.item.priority.compareTo(b.item.priority);
    if (priorityCompare != 0) return priorityCompare;

    final startCompare = a.item.startMinute.compareTo(b.item.startMinute);
    if (startCompare != 0) return startCompare;

    return a.order.compareTo(b.order);
  }

  // --- View Dimensions ---
  static double _calculateExposedLabelWidth(
    double timelineWidth,
    double leftOffset,
    double rightPadding,
    double minFrontWidth,
    double minLabelWidth,
    double maxLabelWidth,
  ) {
    final available = timelineWidth - leftOffset - rightPadding;
    if (!available.isFinite || available <= 0) {
      return maxLabelWidth;
    }
    if (available >= minFrontWidth + maxLabelWidth) {
      return maxLabelWidth;
    }
    return (available - minFrontWidth)
        .clamp(minLabelWidth, maxLabelWidth)
        .toDouble();
  }

  static double _leftForVisual<T extends TimelineVisualItem>(
    TimelineVisualEntry<T> visual,
    List<TimelineVisualEntry<T>> blocks,
    double leftOffset,
    double exposedLabelWidth,
  ) {
    if (!visual.hasOverlap) return leftOffset;
    if (visual.isFront) {
      return leftOffset + exposedLabelWidth;
    }
    return leftOffset;
  }

  static double _rightForVisual<T extends TimelineVisualItem>(
    TimelineVisualEntry<T> visual,
    List<TimelineVisualEntry<T>> blocks,
    double rightPadding,
    int maxOverlapLane,
  ) {
    if (!visual.hasOverlap) return rightPadding;
    if (visual.isFront) return rightPadding;

    final lane = visual.lane.clamp(0, maxOverlapLane);
    return switch (lane) {
      0 => 8.0,
      1 => 12.0,
      _ => 16.0,
    };
  }
}

extension TimelineVisualScaleMath on TimelineVisualScale {
  double yForMinute(num minute) {
    final double m = minute.toDouble();
    final double baseClamped = m.clamp(
      startMinute.toDouble(),
      endMinute.toDouble(),
    );
    final double normalY =
        topPadding + (baseClamped - startMinute) * pixelsPerMinute;

    double stretch = 0.0;
    for (final seg in stretchedSegments) {
      if (m <= seg.startMinute) {
        continue;
      } else if (m >= seg.endMinute) {
        stretch += seg.extraStretch;
      } else {
        final double fraction =
            (m - seg.startMinute) / (seg.endMinute - seg.startMinute);
        stretch += fraction * seg.extraStretch;
      }
    }
    return normalY + stretch;
  }

  double minuteForY(double y) {
    if (y <= topPadding) return startMinute.toDouble();

    double remainingY = y - topPadding;
    double currentMinute = startMinute.toDouble();

    for (final seg in stretchedSegments) {
      if (currentMinute >= seg.startMinute) continue;

      final double distanceToSeg =
          (seg.startMinute - currentMinute) * pixelsPerMinute;
      if (remainingY <= distanceToSeg) {
        return currentMinute + (remainingY / pixelsPerMinute);
      }

      remainingY -= distanceToSeg;
      currentMinute = seg.startMinute.toDouble();

      final double segDuration = (seg.endMinute - seg.startMinute).toDouble();
      final double segNormalHeight = segDuration * pixelsPerMinute;
      final double segTotalHeight = segNormalHeight + seg.extraStretch;

      if (remainingY <= segTotalHeight) {
        final fraction = remainingY / segTotalHeight;
        return currentMinute + (fraction * segDuration);
      }

      remainingY -= segTotalHeight;
      currentMinute = seg.endMinute.toDouble();
    }

    final minuteResult = currentMinute + (remainingY / pixelsPerMinute);
    return math.min(minuteResult, endMinute.toDouble());
  }
}
