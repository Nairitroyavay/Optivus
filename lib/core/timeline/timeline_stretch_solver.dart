import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';

/// Neutral timeline height constraint specification.
@immutable
class TimelineHeightConstraint {
  final String id;
  final int startMinute;
  final int endMinute;
  final double minHeight;

  const TimelineHeightConstraint({
    this.id = '',
    required this.startMinute,
    required this.endMinute,
    required this.minHeight,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineHeightConstraint &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          startMinute == other.startMinute &&
          endMinute == other.endMinute &&
          minHeight == other.minHeight;

  @override
  int get hashCode => Object.hash(id, startMinute, endMinute, minHeight);
}

/// Solves minimum-height constraints across time intervals by adding only
/// each current deficiency to produce stretched timeline segments.
List<TimelineStretchedSegment> solveTimelineStretchConstraints(
  List<TimelineHeightConstraint> constraints, {
  required double pixelsPerMinute,
  double epsilon = 0.01,
}) {
  final activeConstraints =
      constraints
          .where((c) => c.minHeight > 0 && c.endMinute > c.startMinute)
          .toList()
        ..sort((a, b) {
          if (a.startMinute != b.startMinute) {
            return a.startMinute.compareTo(b.startMinute);
          }
          if (a.endMinute != b.endMinute) {
            return b.endMinute.compareTo(a.endMinute); // Longer events first
          }
          return a.id.compareTo(b.id);
        });

  final segments = <TimelineStretchedSegment>[];

  double stretchAt(int minute) {
    var result = 0.0;
    for (final segment in segments) {
      if (minute <= segment.startMinute) continue;
      if (minute >= segment.endMinute) {
        result += segment.extraStretch;
      } else {
        result +=
            (minute - segment.startMinute) /
            (segment.endMinute - segment.startMinute) *
            segment.extraStretch;
      }
    }
    return result;
  }

  for (var pass = 0; pass < math.max(1, activeConstraints.length * 2); pass++) {
    var changed = false;
    for (final entry in activeConstraints) {
      final current =
          (entry.endMinute - entry.startMinute) * pixelsPerMinute +
          stretchAt(entry.endMinute) -
          stretchAt(entry.startMinute);
      final deficiency = entry.minHeight - current;
      if (deficiency > epsilon) {
        segments.add(
          TimelineStretchedSegment(
            startMinute: entry.startMinute,
            endMinute: entry.endMinute,
            extraStretch: deficiency,
          ),
        );
        changed = true;
      }
    }
    if (!changed) break;
  }
  return List.unmodifiable(segments);
}
