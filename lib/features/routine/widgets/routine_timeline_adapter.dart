import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:optivus/core/timeline/timeline_visual_layout.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/features/onboarding/timeline/layout/timeline_overlap_engine.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/routine_time_ruler.dart';

/// Item representation for routine timeline positioning.
class RoutineTimelineItem implements TimelineVisualItem, TimelineInterval {
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
typedef RoutineOverlapRegion = TimelineOverlapRegion;

/// A connected cluster of overlapping items.
typedef RoutineOverlapComponent = TimelineOverlapComponent;

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
    int? selectedDay,
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
    final components = buildRoutineOverlapComponents(
      activeItems,
      day: selectedDay,
    );

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
            it.item,
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
  return buildTimelineOverlapRegions(items);
}

List<RoutineOverlapComponent> buildRoutineOverlapComponents(
  List<RoutineTimelineItem> items, {
  int? day,
}) {
  return buildTimelineOverlapComponents(items, day: day);
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
  final timelineEntries = entries.asMap().entries.map((e) {
    final entry = e.value;
    return TimelineEntry(
      id: 'routine_constraint_${e.key}',
      sourceId: 'routine_constraint_${e.key}',
      startMinute: entry.startMinute,
      endMinute: entry.endMinute,
      repeatDays: const [1, 2, 3, 4, 5, 6, 7],
      title: 'Constraint',
      category: TimelineCategory.other,
      minHeight: entry.minHeight,
    );
  }).toList();
  return TimelineOverlapEngine.solveStretchConstraints(
    timelineEntries,
    pixelsPerMinute: pixelsPerMinute,
    epsilon: epsilon,
  );
}

double _measureCompactTabHeight(
  RoutineItem item,
  double gutterWidth,
  TextScaler textScaler,
  TextDirection textDirection,
) {
  final labelWidth = math.max(18.0, gutterWidth - 25.0);
  final painter = TextPainter(
    text: TextSpan(
      text: shortBackLabel(item),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    ),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: labelWidth);
  return math.max(44.0, painter.height + 12.0);
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
