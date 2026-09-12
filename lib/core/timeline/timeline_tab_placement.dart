import 'package:flutter/foundation.dart';

/// Neutral request object representing a back tab to be placed vertically in an overlap cluster.
@immutable
class TimelineBackTabPlacementRequest {
  final String id;
  final double startY;
  final double tabHeight;

  const TimelineBackTabPlacementRequest({
    required this.id,
    required this.startY,
    required this.tabHeight,
  });
}

/// Computes deterministic top vertical offsets for back-card tabs in an overlap cluster.
///
/// Implements Step 14's canonical placement logic:
/// - Anchors each tab at its exact [startY] corresponding to the start of its first overlap region.
/// - Stacks successive tabs below the anchor only when their start Ys are effectively identical (|Δy| < 4.0).
/// - When start Ys differ by >= 4.0, resets stackIndex to 0 and anchors at the new startY.
Map<String, double> computeBackTabTopOffsets(
  List<TimelineBackTabPlacementRequest> requests, {
  double sameStartThreshold = 4.0,
}) {
  final result = <String, double>{};
  var lastStartY = -1.0;
  var stackIndex = 0;

  for (final req in requests) {
    if (lastStartY >= 0 &&
        (req.startY - lastStartY).abs() < sameStartThreshold) {
      stackIndex++;
    } else {
      stackIndex = 0;
      lastStartY = req.startY;
    }
    result[req.id] = req.startY + stackIndex * req.tabHeight;
  }
  return result;
}
