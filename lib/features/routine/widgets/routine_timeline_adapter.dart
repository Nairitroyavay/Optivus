import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:optivus/core/timeline/timeline_visual_layout.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/routine_time_ruler.dart';

/// Item representation for routine timeline positioning.
class RoutineTimelineItem implements TimelineVisualItem {
  final RoutineItem item;
  @override
  final String id;
  @override
  final int startMinute;
  @override
  final int endMinute;
  @override
  final double minHeight;
  @override
  final int priority;

  const RoutineTimelineItem({
    required this.item,
    required this.id,
    required this.startMinute,
    required this.endMinute,
    required this.minHeight,
    required this.priority,
  });

  RoutineTimelineItem copyWith({
    RoutineItem? item,
    String? id,
    int? startMinute,
    int? endMinute,
    double? minHeight,
    int? priority,
  }) {
    return RoutineTimelineItem(
      item: item ?? this.item,
      id: id ?? this.id,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      minHeight: minHeight ?? this.minHeight,
      priority: priority ?? this.priority,
    );
  }
}

/// An atomic interval with overlapping items on the timeline.
class RoutineOverlapRegion {
  final int startMinute;
  final int endMinute;
  final List<String> itemIds;

  const RoutineOverlapRegion({
    required this.startMinute,
    required this.endMinute,
    required this.itemIds,
  });

  String get key => '${startMinute}_$endMinute';
}

/// A connected cluster of overlapping items.
class RoutineOverlapComponent {
  final String id;
  final List<String> itemIds;

  const RoutineOverlapComponent({required this.id, required this.itemIds});
}

/// Prepared layout holding all computed metrics, stretched scale, regions,
/// and gutter widths for the Routine timeline.
@immutable
class RoutinePreparedTimelineLayout {
  final List<RoutineTimelineItem> items;
  final Map<String, RoutineTimelineItem> itemById;
  final List<RoutineOverlapRegion> regions;
  final List<RoutineOverlapComponent> components;
  final Map<String, String> componentIdByItemId;
  final Map<String, double> tabHeightByRegionKey;
  final Set<String> overlapItemIds;
  final TimelineVisualScale scale;
  final double leftOffset;
  final double fullWidth;
  final double frontWidth;
  final double gutterWidth;
  final double totalHeight;

  const RoutinePreparedTimelineLayout({
    required this.items,
    required this.itemById,
    required this.regions,
    required this.components,
    required this.componentIdByItemId,
    required this.tabHeightByRegionKey,
    required this.overlapItemIds,
    required this.scale,
    required this.leftOffset,
    required this.fullWidth,
    required this.frontWidth,
    required this.gutterWidth,
    required this.totalHeight,
  });

  static RoutinePreparedTimelineLayout prepare({
    required BuildContext context,
    required List<RoutineItem> rawItems,
    required TimelineLayout timelineLayout,
    required double availableWidth,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    // 1. Filter and normalize items in the visible range
    final activeItems = <RoutineTimelineItem>[];
    for (final item in rawItems) {
      final normEnd = TimelineUtils.normalizedEndMinute(item);
      final start = item.startMinute;
      if (normEnd <= timelineLayout.visibleStartMinute ||
          start >= timelineLayout.visibleEndMinute) {
        continue;
      }
      final visibleStart = math.max(start, timelineLayout.visibleStartMinute);
      final visibleEnd = math.min(normEnd, timelineLayout.visibleEndMinute);

      activeItems.add(
        RoutineTimelineItem(
          item: item,
          id: item.id,
          startMinute: visibleStart,
          endMinute: visibleEnd,
          minHeight: 88.0,
          priority: _priorityFor(item),
        ),
      );
    }

    // 2. Build atomic regions and components
    final regions = buildRoutineOverlapRegions(activeItems);
    final components = buildRoutineOverlapComponents(activeItems);

    final componentIdByItemId = <String, String>{
      for (final component in components)
        for (final id in component.itemIds) id: component.id,
    };

    final overlapIds = <String>{
      for (final region in regions)
        if (region.itemIds.length > 1) ...region.itemIds,
    };

    final maxOverlap = regions.fold<int>(
      1,
      (val, r) => math.max(val, r.itemIds.length),
    );

    const rightPadding = 12.0;
    const minimumFrontWidth = 120.0;
    final leftOffset =
        kTimelineTimeRailWidth +
        kTimelineRailDotColumnWidth +
        kTimelineContentGap;

    final fullWidth = math.max(
      80.0,
      availableWidth - leftOffset - rightPadding,
    );

    final desiredGutter = maxOverlap > 1
        ? math.min(96.0, math.max(64.0, fullWidth * 0.24))
        : 0.0;
    final gutterWidth = maxOverlap > 1
        ? math.min(desiredGutter, math.max(44.0, fullWidth - minimumFrontWidth))
        : 0.0;
    final frontWidth = math.max(80.0, fullWidth - gutterWidth);

    final itemByRawId = {for (final it in activeItems) it.id: it};
    final tabHeightByRegion = <String, double>{};

    for (final region in regions.where((r) => r.itemIds.length > 1)) {
      final height = region.itemIds.fold<double>(40.0, (cur, id) {
        final it = itemByRawId[id];
        if (it == null) return cur;
        return math.max(
          cur,
          _measureCompactTabHeight(
            it.item.title,
            gutterWidth,
            textScaler,
            textDirection,
          ),
        );
      });
      tabHeightByRegion[region.key] = height;
    }

    // 3. Measure content-aware card heights
    final measuredItems = <RoutineTimelineItem>[];
    for (final it in activeItems) {
      final cardWidth = overlapIds.contains(it.id) ? frontWidth : fullWidth;
      final requiredH = RoutineCardFactory.measureHeight(
        context,
        cardWidth,
        it.item,
      );
      measuredItems.add(it.copyWith(minHeight: requiredH));
    }

    // 4. Build navigation constraints for back-card tabs
    final constraints = <RoutineConstraintEntry>[
      for (final it in measuredItems)
        RoutineConstraintEntry(
          startMinute: it.startMinute,
          endMinute: it.endMinute,
          minHeight: it.minHeight,
        ),
      for (final region in regions.where((r) => r.itemIds.length > 1))
        RoutineConstraintEntry(
          startMinute: region.startMinute,
          endMinute: region.endMinute,
          minHeight:
              (tabHeightByRegion[region.key] ?? 40.0) *
              (region.itemIds.length - 1),
        ),
    ];

    // 5. Solve constraints and construct stretched visual scale
    final stretchedSegments = solveRoutineStretchConstraints(
      constraints,
      pixelsPerMinute: timelineLayout.minuteHeight,
    );

    final scale = TimelineVisualScale(
      startMinute: timelineLayout.visibleStartMinute,
      endMinute: timelineLayout.visibleEndMinute,
      pixelsPerMinute: timelineLayout.minuteHeight,
      stretchedSegments: stretchedSegments,
    );

    // 6. Compute total height
    double maxCardBottom = scale.yForMinute(timelineLayout.visibleEndMinute);
    for (final it in measuredItems) {
      final top = scale.yForMinute(it.startMinute);
      final exactH = scale.yForMinute(it.endMinute) - top;
      final height = math.max(it.minHeight, exactH);
      if (top + height > maxCardBottom) {
        maxCardBottom = top + height;
      }
    }

    final itemById = {for (final it in measuredItems) it.id: it};

    return RoutinePreparedTimelineLayout(
      items: List.unmodifiable(measuredItems),
      itemById: Map.unmodifiable(itemById),
      regions: regions,
      components: components,
      componentIdByItemId: Map.unmodifiable(componentIdByItemId),
      tabHeightByRegionKey: Map.unmodifiable(tabHeightByRegion),
      overlapItemIds: Set.unmodifiable(overlapIds),
      scale: scale,
      leftOffset: leftOffset,
      fullWidth: fullWidth,
      frontWidth: frontWidth,
      gutterWidth: gutterWidth,
      totalHeight: maxCardBottom,
    );
  }
}

List<RoutineOverlapRegion> buildRoutineOverlapRegions(
  List<RoutineTimelineItem> items,
) {
  if (items.isEmpty) return const [];
  final boundaries = <int>{};
  for (final item in items) {
    boundaries.add(item.startMinute);
    boundaries.add(item.endMinute);
  }
  final sortedBoundaries = boundaries.toList()..sort();
  final regions = <RoutineOverlapRegion>[];

  for (var i = 0; i < sortedBoundaries.length - 1; i++) {
    final start = sortedBoundaries[i];
    final end = sortedBoundaries[i + 1];
    if (start >= end) continue;

    final activeIds = <String>[];
    for (final item in items) {
      if (item.startMinute < end && item.endMinute > start) {
        activeIds.add(item.id);
      }
    }
    if (activeIds.isEmpty) continue;
    activeIds.sort();

    if (regions.isNotEmpty &&
        regions.last.endMinute == start &&
        _sameIds(regions.last.itemIds, activeIds)) {
      final previous = regions.removeLast();
      regions.add(
        RoutineOverlapRegion(
          startMinute: previous.startMinute,
          endMinute: end,
          itemIds: activeIds,
        ),
      );
    } else {
      regions.add(
        RoutineOverlapRegion(
          startMinute: start,
          endMinute: end,
          itemIds: activeIds,
        ),
      );
    }
  }
  return List.unmodifiable(regions);
}

bool _sameIds(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<RoutineOverlapComponent> buildRoutineOverlapComponents(
  List<RoutineTimelineItem> items,
) {
  if (items.isEmpty) return const [];
  final byId = {for (final item in items) item.id: item};
  final remaining = byId.keys.toSet();
  final result = <RoutineOverlapComponent>[];

  while (remaining.isNotEmpty) {
    final seed = (remaining.toList()..sort()).first;
    final queue = <String>[seed];
    final connected = <String>[];
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (!remaining.remove(id)) continue;
      connected.add(id);
      final item = byId[id]!;
      for (final candidateId in remaining.toList()) {
        final candidate = byId[candidateId]!;
        if (item.startMinute < candidate.endMinute &&
            item.endMinute > candidate.startMinute) {
          queue.add(candidateId);
        }
      }
    }
    if (connected.length > 1) {
      connected.sort();
      result.add(
        RoutineOverlapComponent(
          id: 'comp_${connected.join('_')}',
          itemIds: List.unmodifiable(connected),
        ),
      );
    }
  }
  result.sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(result);
}

class RoutineConstraintEntry {
  final int startMinute;
  final int endMinute;
  final double minHeight;

  const RoutineConstraintEntry({
    required this.startMinute,
    required this.endMinute,
    required this.minHeight,
  });
}

List<TimelineStretchedSegment> solveRoutineStretchConstraints(
  List<RoutineConstraintEntry> entries, {
  required double pixelsPerMinute,
  double epsilon = 0.01,
}) {
  final constraints =
      entries
          .where((e) => e.minHeight > 0 && e.endMinute > e.startMinute)
          .toList()
        ..sort((a, b) {
          final cmp = a.startMinute.compareTo(b.startMinute);
          if (cmp != 0) return cmp;
          return b.endMinute.compareTo(a.endMinute);
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

  for (var pass = 0; pass < math.max(1, constraints.length * 2); pass++) {
    var changed = false;
    for (final entry in constraints) {
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

double _measureCompactTabHeight(
  String title,
  double gutterWidth,
  TextScaler textScaler,
  TextDirection textDirection,
) {
  final labelWidth = math.max(20.0, gutterWidth - 34.0);
  final painter = TextPainter(
    text: const TextSpan(
      text: 'Sample',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, height: 1.0),
    ),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  )..layout(maxWidth: labelWidth);
  return math.max(40.0, painter.height + 22.0);
}

int _priorityFor(RoutineItem item) {
  return switch (item.blockType) {
    RoutineBlockType.hardBlock => 90,
    RoutineBlockType.trackerTask => 80,
    RoutineBlockType.checkIn => 70,
    RoutineBlockType.moneyTask => 65,
    RoutineBlockType.softBlock => 60,
    RoutineBlockType.flexibleTask => 50,
  };
}

String shortBackLabel(RoutineItem item) {
  final raw = item.title.trim();
  final lower = raw.toLowerCase();

  if (item.category == RoutineCategory.job ||
      lower.contains('work') ||
      lower.contains('office')) {
    if (lower.contains('office')) return 'Office';
    if (lower.contains('work') || lower.contains('job')) return 'Job';
    return raw.length <= 8 ? raw : 'Job';
  }

  if (item.category == RoutineCategory.classBlock) {
    if (item.courseCode != null && item.courseCode!.trim().isNotEmpty) {
      return item.courseCode!.trim();
    }
    return raw.length <= 8 ? raw : raw.split(' ').first;
  }

  if (item.category == RoutineCategory.eating) {
    final cat = item.mealCategory?.trim();
    if (cat != null && cat.isNotEmpty && cat.toLowerCase() != 'meal') {
      return cat.length <= 8 ? cat : cat.split(' ').first;
    }
    final slot = item.mealSlot?.trim();
    if (slot != null && slot.isNotEmpty && slot.toLowerCase() != 'meal') {
      return slot.length <= 8 ? slot : slot.split(' ').first;
    }
    if (lower.contains('breakfast')) return 'Breakfast';
    if (lower.contains('lunch')) return 'Lunch';
    if (lower.contains('dinner')) return 'Dinner';
    if (lower.contains('snack')) return 'Snack';
    return raw.length <= 8 ? raw : raw.split(' ').first;
  }

  if (item.category == RoutineCategory.skinCare) {
    return 'Skin';
  }

  if (item.category == RoutineCategory.sleep || lower.contains('sleep')) {
    return 'Sleep';
  }

  if (item.blockType == RoutineBlockType.trackerTask) {
    return raw.length <= 8 ? raw : 'Tracker';
  }

  if (item.blockType == RoutineBlockType.checkIn) {
    return 'Check-in';
  }

  if (item.blockType == RoutineBlockType.moneyTask) {
    return 'Finance';
  }

  return raw.length <= 8 ? raw : raw.split(' ').first;
}

IconData backTabIcon(RoutineItem item) {
  return switch (item.blockType) {
    RoutineBlockType.hardBlock =>
      item.category == RoutineCategory.sleep ||
              item.title.toLowerCase().contains('sleep')
          ? Icons.nightlight_round
          : (item.category == RoutineCategory.classBlock
                ? Icons.school_rounded
                : Icons.business_center_rounded),
    RoutineBlockType.softBlock =>
      item.category == RoutineCategory.eating
          ? Icons.restaurant_rounded
          : (item.category == RoutineCategory.skinCare
                ? Icons.spa_rounded
                : Icons.self_improvement_rounded),
    RoutineBlockType.flexibleTask => Icons.assignment_rounded,
    RoutineBlockType.trackerTask => Icons.track_changes_rounded,
    RoutineBlockType.checkIn => Icons.check_circle_outline_rounded,
    RoutineBlockType.moneyTask => Icons.attach_money_rounded,
  };
}
