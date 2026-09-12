import 'dart:math' as math;
import '../models/timeline_entry.dart';
import '../models/timeline_geometry.dart';
import 'package:optivus/core/timeline/timeline_stretch_solver.dart';

/// Pure deterministic overlap layout engine.
///
/// Implements maximum simultaneous concurrency column packing for connected
/// overlap clusters, minute-precise positioning, and minimum interactive height.
class TimelineOverlapEngine {
  const TimelineOverlapEngine._();

  /// Computes the complete timeline layout result for [entries] on [selectedDay].
  static TimelineLayoutResult computeLayout({
    required List<TimelineEntry> entries,
    required double availableWidth,
    required int selectedDay,
    TimelineGeometryConfig config = const TimelineGeometryConfig(),
    int? customStartMinute,
    int? customEndMinute,
    TimelineVisibleRangePolicy visibleRangePolicy =
        TimelineVisibleRangePolicy.legacy,
    TimelineStretchPolicy stretchPolicy = TimelineStretchPolicy.legacy,
    TimelineOverlapPresentation overlapPresentation =
        TimelineOverlapPresentation.sideBySide,
    String? frontEntryId,
  }) {
    // 1. Filter entries active on the selected day
    final dayEntries = entries
        .where((e) => e.isActiveOnDay(selectedDay))
        .toList(growable: false);

    // 2. Stable sort: startMinute ASC, endMinute DESC, id ASC
    final sortedEntries = List<TimelineEntry>.from(dayEntries)
      ..sort(_compareEntries);

    // 3. Determine visible time range
    final (visibleStart, visibleEnd) = _computeVisibleRange(
      sortedEntries,
      config,
      customStartMinute,
      customEndMinute,
      visibleRangePolicy,
    );

    // 4. Calculate stretched segments for entries with custom minHeight
    final rawStretches = <TimelineStretchedSegment>[];
    for (final entry in sortedEntries) {
      if (entry.minHeight > 0 && entry.endMinute > entry.startMinute) {
        final durationH =
            (entry.endMinute - entry.startMinute) * config.pixelsPerMinute;
        if (entry.minHeight > durationH) {
          rawStretches.add(
            TimelineStretchedSegment(
              startMinute: entry.startMinute,
              endMinute: entry.endMinute,
              extraStretch: entry.minHeight - durationH,
            ),
          );
        }
      }
    }
    final mergedStretches = stretchPolicy == TimelineStretchPolicy.legacy
        ? _mergeSegments(rawStretches)
        : solveStretchConstraints(
            sortedEntries,
            pixelsPerMinute: config.pixelsPerMinute,
          );

    // 5. Create coordinate scale
    final scale = TimelineScale(
      startMinute: visibleStart,
      endMinute: visibleEnd,
      pixelsPerMinute: config.pixelsPerMinute,
      topPadding: config.topPadding,
      stretchedSegments: mergedStretches,
    );

    // 6. Partition into connected overlap clusters
    final clusters = _buildClusters(sortedEntries);

    // 7. Usable width for event blocks
    final usableWidth = math.max(
      60.0,
      availableWidth - config.leftOffset - config.rightPadding,
    );

    final positionedEntries = <PositionedTimelineEntry>[];
    double maxCardBottom = scale.yForMinute(visibleEnd);

    // 8. For each cluster, lay out entries based on overlapPresentation
    for (final cluster in clusters) {
      if (cluster.isEmpty) continue;

      if (cluster.length == 1 ||
          overlapPresentation == TimelineOverlapPresentation.sideBySide) {
        final (assignments, maxCols) = _assignColumns(cluster);

        final colCount = math.max(1, maxCols);
        final totalGaps = (colCount - 1) * config.columnGap;
        final colWidth = math.max(20.0, (usableWidth - totalGaps) / colCount);

        for (final item in cluster) {
          final col = assignments[item.id] ?? 0;
          final left = config.leftOffset + col * (colWidth + config.columnGap);
          final top = scale.yForMinute(item.startMinute);
          final bottom = scale.yForMinute(item.endMinute);
          final durationHeight = bottom - top;
          final height = math.max(
            config.minInteractiveHeight,
            math.max(item.minHeight, durationHeight),
          );

          final positioned = PositionedTimelineEntry(
            entry: item,
            top: top,
            height: height,
            left: left,
            width: colWidth,
            column: col,
            columnCount: colCount,
            isFront: true,
            hasOverlap: cluster.length > 1,
          );

          positionedEntries.add(positioned);

          if (top + height > maxCardBottom) {
            maxCardBottom = top + height;
          }
        }
      } else {
        // frontAndExposed mode for overlapping cluster
        final TimelineEntry frontItem;
        if (frontEntryId != null && cluster.any((e) => e.id == frontEntryId)) {
          frontItem = cluster.firstWhere((e) => e.id == frontEntryId);
        } else {
          // Default priority: cluster is sorted by startMinute ASC, duration DESC (endMinute DESC), id ASC.
          frontItem = cluster.first;
        }

        final backItems = cluster.where((e) => e.id != frontItem.id).toList();

        const minFrontWidth = 140.0;
        const minLabelWidth = 60.0;
        const maxLabelWidth = 76.0;

        final double exposedLabelWidth;
        if (usableWidth >= minFrontWidth + maxLabelWidth) {
          exposedLabelWidth = maxLabelWidth;
        } else if (usableWidth > minFrontWidth) {
          exposedLabelWidth = (usableWidth - minFrontWidth).clamp(
            minLabelWidth,
            maxLabelWidth,
          );
        } else {
          exposedLabelWidth = math.min(minLabelWidth, usableWidth * 0.35);
        }

        // Add back items first (painted below front card in the stack)
        for (var lane = 0; lane < backItems.length; lane++) {
          final item = backItems[lane];
          final laneOffset = (lane * 6.0).clamp(0.0, 18.0);
          final left = config.leftOffset + laneOffset;
          final width = math.max(30.0, usableWidth - laneOffset);
          final top = scale.yForMinute(item.startMinute);
          final bottom = scale.yForMinute(item.endMinute);
          final durationHeight = bottom - top;
          final height = math.max(
            config.minInteractiveHeight,
            math.max(item.minHeight, durationHeight),
          );

          final positioned = PositionedTimelineEntry(
            entry: item,
            top: top,
            height: height,
            left: left,
            width: width,
            column: lane,
            columnCount: cluster.length,
            isFront: false,
            hasOverlap: true,
          );

          positionedEntries.add(positioned);

          if (top + height > maxCardBottom) {
            maxCardBottom = top + height;
          }
        }

        // Add front item last (painted on top of back cards)
        final frontLeft = config.leftOffset + exposedLabelWidth;
        final frontWidth = math.max(30.0, usableWidth - exposedLabelWidth);
        final frontTop = scale.yForMinute(frontItem.startMinute);
        final frontBottom = scale.yForMinute(frontItem.endMinute);
        final frontDurationHeight = frontBottom - frontTop;
        final frontHeight = math.max(
          config.minInteractiveHeight,
          math.max(frontItem.minHeight, frontDurationHeight),
        );

        final frontPositioned = PositionedTimelineEntry(
          entry: frontItem,
          top: frontTop,
          height: frontHeight,
          left: frontLeft,
          width: frontWidth,
          column: 0,
          columnCount: cluster.length,
          isFront: true,
          hasOverlap: true,
        );

        positionedEntries.add(frontPositioned);

        if (frontTop + frontHeight > maxCardBottom) {
          maxCardBottom = frontTop + frontHeight;
        }
      }
    }

    // 8. Collect non-hour boundary minutes for indicator ticks
    final boundaryMinutes = <int>{};
    for (final entry in sortedEntries) {
      if (entry.startMinute > visibleStart &&
          entry.startMinute < visibleEnd &&
          entry.startMinute % 60 != 0) {
        boundaryMinutes.add(entry.startMinute);
      }
      if (entry.endMinute > visibleStart &&
          entry.endMinute < visibleEnd &&
          entry.endMinute % 60 != 0) {
        boundaryMinutes.add(entry.endMinute);
      }
    }
    final sortedBoundaries = boundaryMinutes.toList()..sort();

    final totalHeight = maxCardBottom + config.bottomPadding;

    return TimelineLayoutResult(
      scale: scale,
      entries: positionedEntries,
      totalHeight: totalHeight,
      boundaryMinutes: sortedBoundaries,
      visibleStartMinute: visibleStart,
      visibleEndMinute: visibleEnd,
    );
  }

  /// Whether interval A overlaps interval B.
  /// Touching intervals (e.g. 9..10 and 10..11) do NOT overlap.
  static bool intervalsOverlap(int aStart, int aEnd, int bStart, int bEnd) {
    return aStart < bEnd && bStart < aEnd;
  }

  /// Deterministic comparison function for stable sorting.
  static int _compareEntries(TimelineEntry a, TimelineEntry b) {
    if (a.startMinute != b.startMinute) {
      return a.startMinute.compareTo(b.startMinute);
    }
    if (a.endMinute != b.endMinute) {
      return b.endMinute.compareTo(a.endMinute); // Longer events first
    }
    return a.id.compareTo(b.id);
  }

  /// Computes visible start and end minutes.
  static (int, int) _computeVisibleRange(
    List<TimelineEntry> entries,
    TimelineGeometryConfig config,
    int? customStart,
    int? customEnd,
    TimelineVisibleRangePolicy policy,
  ) {
    if (customStart != null && customEnd != null) {
      return (customStart, customEnd);
    }

    if (entries.isEmpty) {
      return (config.defaultStartMinute, config.defaultEndMinute);
    }

    final minStart = entries.map((e) => e.startMinute).reduce(math.min);
    final maxEnd = entries.map((e) => e.endMinute).reduce(math.max);

    if (policy == TimelineVisibleRangePolicy.contentAdaptive) {
      var start = (((minStart - 30).clamp(0, 1440)) ~/ 30) * 30;
      var end = (((((maxEnd + 30).clamp(0, 1440)) + 29) ~/ 30) * 30)
          .clamp(0, 1440)
          .toInt();
      if (end - start < 180) {
        final missing = 180 - (end - start);
        final before = math.min(start, (missing / 2).floor());
        start -= before;
        end = math.min(1440, end + missing - before);
        if (end - start < 180) {
          start = math.max(0, end - 180);
        }
      }
      return (start, end);
    }

    final startHour = math.max(
      0,
      math.min(config.defaultStartMinute ~/ 60, (minStart - 45) ~/ 60),
    );
    final endHour = math.min(
      24,
      math.max(
        (config.defaultEndMinute + 59) ~/ 60,
        ((maxEnd + 75) / 60).ceil(),
      ),
    );

    final startMin = startHour * 60;
    final endMin = math.max(startMin + 180, endHour * 60);

    return (startMin, math.min(1440, endMin));
  }

  /// Groups transitively overlapping entries into connected clusters.
  static List<List<TimelineEntry>> _buildClusters(List<TimelineEntry> sorted) {
    if (sorted.isEmpty) return const [];

    final clusters = <List<TimelineEntry>>[];
    var currentCluster = <TimelineEntry>[sorted.first];
    var clusterMaxEnd = sorted.first.endMinute;

    for (var i = 1; i < sorted.length; i++) {
      final entry = sorted[i];
      if (entry.startMinute < clusterMaxEnd) {
        // Overlaps with the current cluster
        currentCluster.add(entry);
        clusterMaxEnd = math.max(clusterMaxEnd, entry.endMinute);
      } else {
        // Starts a new cluster
        clusters.add(currentCluster);
        currentCluster = [entry];
        clusterMaxEnd = entry.endMinute;
      }
    }
    clusters.add(currentCluster);

    return clusters;
  }

  /// Greedily assigns column indices to entries in a cluster.
  ///
  /// Returns a map of entry ID to column index (0..k-1) and the maximum concurrent
  /// column count (which equals the number of columns actually allocated).
  static (Map<String, int>, int) _assignColumns(List<TimelineEntry> cluster) {
    if (cluster.isEmpty) return (const {}, 0);
    if (cluster.length == 1) {
      return ({cluster.first.id: 0}, 1);
    }

    final assignments = <String, int>{};
    // Track the end minute of the last placed entry in each column
    final columnEndMinutes = <int>[];

    for (final entry in cluster) {
      // Find the first column where the last entry has already ended
      var assignedCol = -1;
      for (var col = 0; col < columnEndMinutes.length; col++) {
        if (columnEndMinutes[col] <= entry.startMinute) {
          assignedCol = col;
          columnEndMinutes[col] = entry.endMinute;
          break;
        }
      }

      // If no existing column is free, allocate a new column
      if (assignedCol == -1) {
        assignedCol = columnEndMinutes.length;
        columnEndMinutes.add(entry.endMinute);
      }

      assignments[entry.id] = assignedCol;
    }

    final maxColumns = columnEndMinutes.length;
    return (assignments, maxColumns);
  }

  static List<TimelineStretchedSegment> _mergeSegments(
    List<TimelineStretchedSegment> segments,
  ) {
    if (segments.isEmpty) return const [];
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

  /// Solves minimum-height constraints by adding only each current deficiency.
  static List<TimelineStretchedSegment> solveStretchConstraints(
    List<TimelineEntry> entries, {
    required double pixelsPerMinute,
    double epsilon = 0.01,
  }) {
    final constraints = entries
        .map(
          (e) => TimelineHeightConstraint(
            id: e.id,
            startMinute: e.startMinute,
            endMinute: e.endMinute,
            minHeight: e.minHeight,
          ),
        )
        .toList();
    return solveTimelineStretchConstraints(
      constraints,
      pixelsPerMinute: pixelsPerMinute,
      epsilon: epsilon,
    );
  }
}
