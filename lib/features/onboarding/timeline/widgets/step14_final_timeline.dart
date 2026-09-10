import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/layout/timeline_overlap_engine.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_day_chips.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';

enum Step14Continuation { none, continuesTomorrow, continuedFromYesterday }

@immutable
class Step14TimelineVisualIdentity {
  final Color accent;
  final IconData icon;
  final String categoryLabel;

  const Step14TimelineVisualIdentity({
    required this.accent,
    required this.icon,
    required this.categoryLabel,
  });

  static Step14TimelineVisualIdentity resolve(
    TimelineBlockDraft block, {
    required int classOrdinal,
    required int workOrdinal,
  }) {
    return switch (block.section) {
      'classes' => Step14TimelineVisualIdentity(
        accent:
            ScheduleSetupConfig.classSetup.colorCycle[classOrdinal %
                ScheduleSetupConfig.classSetup.colorCycle.length],
        icon: Icons.school_rounded,
        categoryLabel: 'Class',
      ),
      'job_work_business' => Step14TimelineVisualIdentity(
        accent:
            ScheduleSetupConfig.workSetup.colorCycle[workOrdinal %
                ScheduleSetupConfig.workSetup.colorCycle.length],
        icon: Icons.work_rounded,
        categoryLabel: 'Work',
      ),
      'eating' => Step14TimelineVisualIdentity(
        accent: OptivusColors.roseAccent,
        icon: _mealIcon(block.mealCategory ?? block.title),
        categoryLabel: 'Meal',
      ),
      'fixed' => Step14TimelineVisualIdentity(
        accent: OptivusColors.purpleAccent,
        icon: _fixedIcon(block.title),
        categoryLabel: 'Fixed',
      ),
      'skin_care' => const Step14TimelineVisualIdentity(
        accent: OptivusColors.roseAccent,
        icon: Icons.spa_rounded,
        categoryLabel: 'Skin Care',
      ),
      _ => const Step14TimelineVisualIdentity(
        accent: OptivusColors.purpleAccent,
        icon: Icons.schedule_rounded,
        categoryLabel: 'Activity',
      ),
    };
  }

  static IconData _mealIcon(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('breakfast')) return Icons.wb_sunny_rounded;
    if (normalized.contains('lunch')) return Icons.lunch_dining_rounded;
    if (normalized.contains('dinner')) return Icons.dinner_dining_rounded;
    if (normalized.contains('snack')) return Icons.cookie_rounded;
    return Icons.restaurant_rounded;
  }

  static IconData _fixedIcon(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('sleep')) return Icons.bedtime_rounded;
    if (normalized.contains('bath')) return Icons.bathtub_rounded;
    return Icons.event_rounded;
  }
}

/// Section-relative source ordering used only for Step 4-compatible colors.
@immutable
class Step14SourceVisualOrder {
  final Map<String, int> classOrdinalById;
  final Map<String, int> workOrdinalById;

  const Step14SourceVisualOrder({
    required this.classOrdinalById,
    required this.workOrdinalById,
  });

  factory Step14SourceVisualOrder.fromBlocks(
    Iterable<TimelineBlockDraft> blocks,
  ) {
    final classOrdinals = <String, int>{};
    final workOrdinals = <String, int>{};
    for (final block in blocks) {
      if (block.section == 'classes') {
        classOrdinals.putIfAbsent(block.id, () => classOrdinals.length);
      } else if (block.section == 'job_work_business') {
        workOrdinals.putIfAbsent(block.id, () => workOrdinals.length);
      }
    }
    return Step14SourceVisualOrder(
      classOrdinalById: Map.unmodifiable(classOrdinals),
      workOrdinalById: Map.unmodifiable(workOrdinals),
    );
  }
}

@immutable
class Step14FinalTimelineItem {
  final TimelineEntry entry;
  final TimelineBlockDraft sourceBlock;
  final Step14TimelineVisualIdentity identity;
  final Step14Continuation continuation;
  final int canonicalOrdinal;

  const Step14FinalTimelineItem({
    required this.entry,
    required this.sourceBlock,
    required this.identity,
    required this.continuation,
    required this.canonicalOrdinal,
  });

  Step14FinalTimelineItem copyWithEntry(TimelineEntry value) =>
      Step14FinalTimelineItem(
        entry: value,
        sourceBlock: sourceBlock,
        identity: identity,
        continuation: continuation,
        canonicalOrdinal: canonicalOrdinal,
      );
}

/// Projects the authoritative completion bundle into day-bounded display data.
List<Step14FinalTimelineItem> buildStep14FinalTimelineItems(
  OnboardingCompletionBundle bundle, {
  Step14SourceVisualOrder? sourceVisualOrder,
}) {
  final result = <Step14FinalTimelineItem>[];
  var classOrdinal = 0;
  var workOrdinal = 0;

  for (var ordinal = 0; ordinal < bundle.baseTimelineBlocks.length; ordinal++) {
    final block = bundle.baseTimelineBlocks[ordinal];
    final identity = Step14TimelineVisualIdentity.resolve(
      block,
      classOrdinal:
          sourceVisualOrder?.classOrdinalById[block.id] ?? classOrdinal,
      workOrdinal: sourceVisualOrder?.workOrdinalById[block.id] ?? workOrdinal,
    );
    if (block.section == 'classes') classOrdinal++;
    if (block.section == 'job_work_business') workOrdinal++;
    final category = _categoryForSection(block.section);
    final overnight =
        block.crossesMidnight ||
        block.endsNextDay ||
        block.endMinute <= block.startMinute;
    final days = block.repeatDays.isEmpty
        ? const [1, 2, 3, 4, 5, 6, 7]
        : block.repeatDays;

    if (!overnight) {
      result.add(
        Step14FinalTimelineItem(
          entry: TimelineEntry(
            id: block.id,
            sourceId: block.id,
            startMinute: block.startMinute,
            endMinute: block.endMinute,
            repeatDays: days,
            title: block.title,
            subtitle: block.location,
            category: category,
            isEditable: false,
          ),
          sourceBlock: block,
          identity: identity,
          continuation: Step14Continuation.none,
          canonicalOrdinal: ordinal,
        ),
      );
      continue;
    }

    for (final day in days) {
      if (block.startMinute < 1440) {
        result.add(
          Step14FinalTimelineItem(
            entry: TimelineEntry(
              id: '${block.id}_night_$day',
              sourceId: block.id,
              startMinute: block.startMinute,
              endMinute: 1440,
              repeatDays: [day],
              specificDay: day,
              title: block.title,
              subtitle: block.location,
              category: category,
              isEditable: false,
            ),
            sourceBlock: block,
            identity: identity,
            continuation: Step14Continuation.continuesTomorrow,
            canonicalOrdinal: ordinal,
          ),
        );
      }
      final nextDay = (day % 7) + 1;
      if (block.endMinute > 0) {
        result.add(
          Step14FinalTimelineItem(
            entry: TimelineEntry(
              id: '${block.id}_morning_$nextDay',
              sourceId: block.id,
              startMinute: 0,
              endMinute: block.endMinute,
              repeatDays: [nextDay],
              specificDay: nextDay,
              title: block.title,
              subtitle: block.location,
              category: category,
              isEditable: false,
            ),
            sourceBlock: block,
            identity: identity,
            continuation: Step14Continuation.continuedFromYesterday,
            canonicalOrdinal: ordinal,
          ),
        );
      }
    }
  }
  return List.unmodifiable(result);
}

TimelineCategory _categoryForSection(String section) => switch (section) {
  'classes' => TimelineCategory.classes,
  'job_work_business' => TimelineCategory.work,
  'eating' => TimelineCategory.meal,
  'fixed' => TimelineCategory.fixed,
  'skin_care' => TimelineCategory.skinCare,
  _ => TimelineCategory.other,
};

@immutable
class Step14OverlapRegion {
  final int startMinute;
  final int endMinute;
  final List<String> entryIds;

  const Step14OverlapRegion({
    required this.startMinute,
    required this.endMinute,
    required this.entryIds,
  });

  String keyForDay(int day) =>
      '$day:$startMinute:$endMinute:${entryIds.join(',')}';
}

/// Splits a day into exact, non-transitive concurrency regions.
List<Step14OverlapRegion> buildStep14OverlapRegions(
  List<TimelineEntry> entries,
) {
  if (entries.isEmpty) return const [];
  final points =
      entries
          .expand((entry) => [entry.startMinute, entry.endMinute])
          .toSet()
          .toList()
        ..sort();
  final result = <Step14OverlapRegion>[];
  for (var index = 0; index < points.length - 1; index++) {
    final start = points[index];
    final end = points[index + 1];
    if (start == end) continue;
    final active =
        entries
            .where(
              (entry) => entry.startMinute < end && entry.endMinute > start,
            )
            .map((entry) => entry.id)
            .toList()
          ..sort();
    if (active.isEmpty) continue;
    if (result.isNotEmpty &&
        result.last.endMinute == start &&
        _sameIds(result.last.entryIds, active)) {
      final previous = result.removeLast();
      result.add(
        Step14OverlapRegion(
          startMinute: previous.startMinute,
          endMinute: end,
          entryIds: active,
        ),
      );
    } else {
      result.add(
        Step14OverlapRegion(
          startMinute: start,
          endMinute: end,
          entryIds: active,
        ),
      );
    }
  }
  return List.unmodifiable(result);
}

bool _sameIds(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

@immutable
class Step14OverlapComponent {
  final String id;
  final List<String> entryIds;

  const Step14OverlapComponent({required this.id, required this.entryIds});
}

/// Builds connected interaction components without changing atomic active sets.
List<Step14OverlapComponent> buildStep14OverlapComponents(
  List<TimelineEntry> entries, {
  required int selectedDay,
}) {
  final byId = {for (final entry in entries) entry.id: entry};
  final remaining = byId.keys.toSet();
  final result = <Step14OverlapComponent>[];
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
        if (TimelineOverlapEngine.intervalsOverlap(
          entry.startMinute,
          entry.endMinute,
          candidate.startMinute,
          candidate.endMinute,
        )) {
          queue.add(candidateId);
        }
      }
    }
    if (connected.length > 1) {
      connected.sort();
      result.add(
        Step14OverlapComponent(
          id: '$selectedDay:${connected.join(',')}',
          entryIds: List.unmodifiable(connected),
        ),
      );
    }
  }
  result.sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(result);
}

@immutable
class Step14PreparedTimelineLayout {
  final List<Step14FinalTimelineItem> items;
  final Map<String, Step14FinalTimelineItem> itemById;
  final Map<String, PositionedTimelineEntry> positionedById;
  final List<Step14OverlapRegion> regions;
  final List<Step14OverlapComponent> components;
  final Map<String, String> componentIdByEntryId;
  final Map<String, double> tabHeightByRegionKey;
  final Set<String> overlapEntryIds;
  final TimelineLayoutResult layout;
  final double leftOffset;
  final double fullWidth;
  final double frontWidth;
  final double gutterWidth;
  final double railLabelWidth;
  final double railLabelHeight;
  final TextDirection textDirection;
  final int selectedDay;

  const Step14PreparedTimelineLayout({
    required this.items,
    required this.itemById,
    required this.positionedById,
    required this.regions,
    required this.components,
    required this.componentIdByEntryId,
    required this.tabHeightByRegionKey,
    required this.overlapEntryIds,
    required this.layout,
    required this.leftOffset,
    required this.fullWidth,
    required this.frontWidth,
    required this.gutterWidth,
    required this.railLabelWidth,
    required this.railLabelHeight,
    required this.textDirection,
    required this.selectedDay,
  });

  static Step14PreparedTimelineLayout prepare({
    required BuildContext context,
    required OnboardingCompletionBundle bundle,
    required List<TimelineBlockDraft> sourceBlocks,
    required int selectedDay,
    required double availableWidth,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final sourceOrder = Step14SourceVisualOrder.fromBlocks(sourceBlocks);
    final items = buildStep14FinalTimelineItems(
      bundle,
      sourceVisualOrder: sourceOrder,
    ).where((item) => item.entry.isActiveOnDay(selectedDay)).toList();
    final rawEntries = items.map((item) => item.entry).toList();
    final regions = buildStep14OverlapRegions(rawEntries);
    final components = buildStep14OverlapComponents(
      rawEntries,
      selectedDay: selectedDay,
    );
    final componentIdByEntryId = <String, String>{
      for (final component in components)
        for (final id in component.entryIds) id: component.id,
    };
    final overlapIds = <String>{
      for (final region in regions)
        if (region.entryIds.length > 1) ...region.entryIds,
    };
    final maxOverlap = regions.fold<int>(
      1,
      (value, region) => math.max(value, region.entryIds.length),
    );
    const rightPadding = 14.0;
    const minimumFrontWidth = 120.0;
    final railMetrics = _measureRailMetrics(
      textScaler: textScaler,
      textDirection: textDirection,
    );
    final minimumGutter = maxOverlap > 1 ? 44.0 : 0.0;
    final maximumRailWidth = math.max(
      58.0,
      availableWidth - rightPadding - minimumFrontWidth - minimumGutter - 12.0,
    );
    final railLabelWidth = math.min(railMetrics.$1, maximumRailWidth);
    final leftOffset = railLabelWidth + 12.0;
    final fullWidth = math.max(
      80.0,
      availableWidth - leftOffset - rightPadding,
    );
    final desiredGutter = maxOverlap > 1
        ? math.min(104.0, math.max(58.0, availableWidth * 0.24))
        : 0.0;
    final gutterWidth = maxOverlap > 1
        ? math.min(desiredGutter, math.max(44.0, fullWidth - minimumFrontWidth))
        : 0.0;
    final frontWidth = math.max(80.0, fullWidth - gutterWidth);

    final itemByRawId = {for (final item in items) item.entry.id: item};
    final tabHeightByRegion = <String, double>{};
    for (final region in regions.where(
      (region) => region.entryIds.length > 1,
    )) {
      final height = region.entryIds.fold<double>(44.0, (current, id) {
        return math.max(
          current,
          _measureCompactTabHeight(
            itemByRawId[id]!.sourceBlock.title,
            gutterWidth,
            textScaler,
            textDirection,
          ),
        );
      });
      tabHeightByRegion[region.keyForDay(selectedDay)] = height;
    }

    final measuredItems = <Step14FinalTimelineItem>[];
    for (final item in items) {
      final width = overlapIds.contains(item.entry.id) ? frontWidth : fullWidth;
      final required = Step14FinalTimelineCard.measureHeight(
        context,
        width,
        item,
      );
      measuredItems.add(
        item.copyWithEntry(item.entry.copyWith(minHeight: required)),
      );
    }

    final navigationConstraints = <TimelineEntry>[];
    for (final region in regions.where(
      (region) => region.entryIds.length > 1,
    )) {
      final tabHeight = tabHeightByRegion[region.keyForDay(selectedDay)]!;
      navigationConstraints.add(
        TimelineEntry(
          id: '__nav_${region.startMinute}_${region.endMinute}',
          sourceId: '__navigation__',
          startMinute: region.startMinute,
          endMinute: region.endMinute,
          repeatDays: [selectedDay],
          title: '',
          category: TimelineCategory.other,
          isEditable: false,
          minHeight: tabHeight * (region.entryIds.length - 1),
        ),
      );
    }
    final config = TimelineGeometryConfig(
      pixelsPerMinute: 1.1,
      minInteractiveHeight: 44,
      leftOffset: leftOffset,
      rightPadding: rightPadding,
      topPadding: math.max(18.0, railMetrics.$2 / 2),
      bottomPadding: 50,
    );
    final layout = TimelineOverlapEngine.computeLayout(
      entries: [
        ...measuredItems.map((item) => item.entry),
        ...navigationConstraints,
      ],
      availableWidth: availableWidth,
      selectedDay: selectedDay,
      config: config,
      visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
      stretchPolicy: TimelineStretchPolicy.constraintBased,
    );
    final positioned = <String, PositionedTimelineEntry>{
      for (final entry in layout.entries)
        if (!entry.id.startsWith('__nav_')) entry.id: entry,
    };
    final itemById = {for (final item in measuredItems) item.entry.id: item};

    return Step14PreparedTimelineLayout(
      items: List.unmodifiable(measuredItems),
      itemById: Map.unmodifiable(itemById),
      positionedById: Map.unmodifiable(positioned),
      regions: regions,
      components: components,
      componentIdByEntryId: Map.unmodifiable(componentIdByEntryId),
      tabHeightByRegionKey: Map.unmodifiable(tabHeightByRegion),
      overlapEntryIds: Set.unmodifiable(overlapIds),
      layout: layout,
      leftOffset: leftOffset,
      fullWidth: fullWidth,
      frontWidth: frontWidth,
      gutterWidth: gutterWidth,
      railLabelWidth: railLabelWidth,
      railLabelHeight: railMetrics.$2,
      textDirection: textDirection,
      selectedDay: selectedDay,
    );
  }
}

(double, double) _measureRailMetrics({
  required TextScaler textScaler,
  required TextDirection textDirection,
}) {
  const styles = [
    TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
    TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
  ];
  var width = 58.0;
  var height = 18.0;
  for (final style in styles) {
    final painter = TextPainter(
      text: TextSpan(text: '12:30 PM', style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    width = math.max(width, painter.width + 4);
    height = math.max(height, painter.height + 2);
  }
  return (width, height);
}

double _measureCompactTabHeight(
  String title,
  double width,
  TextScaler textScaler,
  TextDirection textDirection,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: title,
      style: const TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
    ),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: math.max(18.0, width - 25));
  return math.max(44.0, painter.height + 12);
}

class _Step14PreparedLayoutKey {
  final OnboardingCompletionBundle bundle;
  final List<TimelineBlockDraft> sourceBlocks;
  final int selectedDay;
  final double availableWidth;
  final TextScaler textScaler;
  final TextDirection textDirection;

  const _Step14PreparedLayoutKey({
    required this.bundle,
    required this.sourceBlocks,
    required this.selectedDay,
    required this.availableWidth,
    required this.textScaler,
    required this.textDirection,
  });

  @override
  bool operator ==(Object other) =>
      other is _Step14PreparedLayoutKey &&
      identical(bundle, other.bundle) &&
      identical(sourceBlocks, other.sourceBlocks) &&
      selectedDay == other.selectedDay &&
      availableWidth == other.availableWidth &&
      textScaler == other.textScaler &&
      textDirection == other.textDirection;

  @override
  int get hashCode => Object.hash(
    identityHashCode(bundle),
    identityHashCode(sourceBlocks),
    selectedDay,
    availableWidth,
    textScaler,
    textDirection,
  );
}

class Step14FinalTimeline extends StatefulWidget {
  final OnboardingCompletionBundle bundle;
  final List<TimelineBlockDraft>? sourceBlocks;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final ScrollController? scrollController;

  const Step14FinalTimeline({
    super.key,
    required this.bundle,
    this.sourceBlocks,
    required this.selectedDay,
    required this.onDayChanged,
    this.scrollController,
  });

  @override
  State<Step14FinalTimeline> createState() => Step14FinalTimelineState();
}

class Step14FinalTimelineState extends State<Step14FinalTimeline> {
  final Map<String, String> _focusedEntryByComponent = {};
  late final ScrollController _scrollController;
  late final bool _ownsScrollController;
  _Step14PreparedLayoutKey? _preparedKey;
  Step14PreparedTimelineLayout? _preparedLayout;

  @visibleForTesting
  Step14PreparedTimelineLayout? get preparedLayoutForTesting => _preparedLayout;

  @override
  void initState() {
    super.initState();
    _ownsScrollController = widget.scrollController == null;
    _scrollController = widget.scrollController ?? ScrollController();
    _scheduleInitialScroll();
  }

  @override
  void didUpdateWidget(covariant Step14FinalTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay ||
        !identical(oldWidget.bundle, widget.bundle) ||
        !identical(oldWidget.sourceBlocks, widget.sourceBlocks)) {
      _focusedEntryByComponent.clear();
    }
    if (oldWidget.selectedDay != widget.selectedDay) _scheduleInitialScroll();
  }

  void _scheduleInitialScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    if (_ownsScrollController) _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final headerMaxHeight = outerConstraints.hasBoundedHeight
            ? math.max(
                160.0,
                math.min(300.0, outerConstraints.maxHeight * 0.45),
              )
            : double.infinity;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: headerMaxHeight),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Text(
                        'Today timeline preview',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 3, 24, 0),
                      child: Text(
                        'Review only — your complete onboarding schedule.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TimelineDayChips(
                      selectedDay: widget.selectedDay,
                      onDayChanged: widget.onDayChanged,
                      accent: OptivusColors.aquaAccent,
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final prepared = _resolvePreparedLayout(
                    context,
                    constraints.maxWidth,
                  );
                  if (prepared.items.isEmpty) {
                    return Center(
                      child: Text(
                        'No activities scheduled for ${_weekdayName(widget.selectedDay)}.',
                        key: const ValueKey('step14-empty-day'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    );
                  }
                  return _buildPreparedTimeline(prepared);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Step14PreparedTimelineLayout _resolvePreparedLayout(
    BuildContext context,
    double availableWidth,
  ) {
    final sourceBlocks =
        widget.sourceBlocks ?? widget.bundle.baseTimelineBlocks;
    final key = _Step14PreparedLayoutKey(
      bundle: widget.bundle,
      sourceBlocks: sourceBlocks,
      selectedDay: widget.selectedDay,
      availableWidth: availableWidth,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    );
    if (key != _preparedKey || _preparedLayout == null) {
      _preparedKey = key;
      _preparedLayout = Step14PreparedTimelineLayout.prepare(
        context: context,
        bundle: widget.bundle,
        sourceBlocks: sourceBlocks,
        selectedDay: widget.selectedDay,
        availableWidth: availableWidth,
      );
    }
    return _preparedLayout!;
  }

  Widget _buildPreparedTimeline(Step14PreparedTimelineLayout prepared) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3)),
      child: SingleChildScrollView(
        key: const ValueKey('step14-timeline-scroll'),
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          height: prepared.layout.totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Step14RichTimeRail(
                scale: prepared.layout.scale,
                labelWidth: prepared.railLabelWidth,
                labelHeight: prepared.railLabelHeight,
                lineStart: prepared.leftOffset - 6,
              ),
              for (final item in _cardPaintOrder(prepared))
                _buildLogicalCard(prepared, item),
              for (final region in prepared.regions.where(
                (region) => region.entryIds.length > 1,
              ))
                ..._buildBackTabs(prepared, region),
            ],
          ),
        ),
      ),
    );
  }

  List<Step14FinalTimelineItem> _cardPaintOrder(
    Step14PreparedTimelineLayout prepared,
  ) {
    final chronological = List<Step14FinalTimelineItem>.from(prepared.items)
      ..sort((a, b) {
        final start = a.entry.startMinute.compareTo(b.entry.startMinute);
        if (start != 0) return start;
        return a.canonicalOrdinal.compareTo(b.canonicalOrdinal);
      });
    final result = <Step14FinalTimelineItem>[];
    final emittedComponents = <String>{};
    for (final item in chronological) {
      final componentId = prepared.componentIdByEntryId[item.entry.id];
      if (componentId == null) {
        result.add(item);
        continue;
      }
      if (!emittedComponents.add(componentId)) continue;
      final componentItems = prepared.items
          .where(
            (candidate) =>
                prepared.componentIdByEntryId[candidate.entry.id] ==
                componentId,
          )
          .toList();
      final focused = _focusedEntryByComponent[componentId];
      componentItems.sort((a, b) {
        if (a.entry.id == focused) return 1;
        if (b.entry.id == focused) return -1;
        return -_compareFrontPriority(a, b);
      });
      result.addAll(componentItems);
    }
    return result;
  }

  Widget _buildLogicalCard(
    Step14PreparedTimelineLayout prepared,
    Step14FinalTimelineItem item,
  ) {
    final geometry = prepared.positionedById[item.entry.id]!;
    final overlaps = prepared.overlapEntryIds.contains(item.entry.id);
    return Positioned(
      key: ValueKey('step14-timeline-card-${item.entry.id}'),
      top: geometry.top,
      left: prepared.leftOffset + (overlaps ? prepared.gutterWidth : 0),
      width: overlaps ? prepared.frontWidth : prepared.fullWidth,
      height: geometry.height,
      child: Step14FinalTimelineCard(item: item),
    );
  }

  List<Widget> _buildBackTabs(
    Step14PreparedTimelineLayout prepared,
    Step14OverlapRegion region,
  ) {
    final regionKey = region.keyForDay(prepared.selectedDay);
    final candidates = region.entryIds
        .map((id) => prepared.itemById[id]!)
        .toList();
    final componentId = prepared.componentIdByEntryId[region.entryIds.first]!;
    final focused = _focusedEntryByComponent[componentId];
    final front = focused != null && region.entryIds.contains(focused)
        ? prepared.itemById[focused]!
        : _defaultFront(candidates);
    final backs = candidates.where((item) => item.entry.id != front.entry.id);
    final top = prepared.layout.scale.yForMinute(region.startMinute);
    final tabHeight = prepared.tabHeightByRegionKey[regionKey]!;
    return [
      for (final indexed in backs.indexed)
        Positioned(
          key: ValueKey(
            'step14-timeline-back-tab-${indexed.$2.entry.id}-$regionKey',
          ),
          top: top + indexed.$1 * tabHeight,
          left: prepared.leftOffset,
          width: prepared.gutterWidth,
          height: tabHeight,
          child: Semantics(
            excludeSemantics: true,
            button: true,
            label:
                'Show ${indexed.$2.sourceBlock.title} in front, ${_logicalTimeRange(indexed.$2.sourceBlock)}',
            child: Material(
              color: indexed.$2.identity.accent.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              child: InkWell(
                onTap: () => setState(
                  () => _focusedEntryByComponent[componentId] =
                      indexed.$2.entry.id,
                ),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Row(
                    children: [
                      Icon(
                        indexed.$2.identity.icon,
                        size: 14,
                        color: indexed.$2.identity.accent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          indexed.$2.sourceBlock.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

Step14FinalTimelineItem _defaultFront(
  List<Step14FinalTimelineItem> candidates,
) {
  final sorted = List<Step14FinalTimelineItem>.from(candidates)
    ..sort(_compareFrontPriority);
  return sorted.first;
}

int _compareFrontPriority(
  Step14FinalTimelineItem a,
  Step14FinalTimelineItem b,
) {
  final duration = a.sourceBlock.durationMinutes.compareTo(
    b.sourceBlock.durationMinutes,
  );
  if (duration != 0) return duration;
  final hard = _hardPriority(
    a.sourceBlock,
  ).compareTo(_hardPriority(b.sourceBlock));
  if (hard != 0) return hard;
  final category = _categoryPriority(
    a.entry.category,
  ).compareTo(_categoryPriority(b.entry.category));
  if (category != 0) return category;
  final start = a.entry.startMinute.compareTo(b.entry.startMinute);
  if (start != 0) return start;
  return a.canonicalOrdinal.compareTo(b.canonicalOrdinal);
}

int _hardPriority(TimelineBlockDraft block) =>
    block.blockType == TimelineBlockDraft.hardBlockKey ? 0 : 1;

int _categoryPriority(TimelineCategory category) => switch (category) {
  TimelineCategory.fixed => 0,
  TimelineCategory.classes => 1,
  TimelineCategory.work => 2,
  TimelineCategory.meal => 3,
  TimelineCategory.skinCare => 4,
  TimelineCategory.other => 5,
};

class Step14FinalTimelineCard extends StatelessWidget {
  final Step14FinalTimelineItem item;

  const Step14FinalTimelineCard({super.key, required this.item});

  static double measureHeight(
    BuildContext context,
    double width,
    Step14FinalTimelineItem item,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final contentWidth = math.max(40.0, width - 24);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: contentWidth);
      return painter.height;
    }

    final titleWidth = math.max(24.0, contentWidth - 25);
    double measureTitle(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: titleWidth);
      return math.max(18.0, painter.height);
    }

    var height = 20.0;
    height += measureTitle(
      item.sourceBlock.title,
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, height: 1.2),
    );
    height +=
        5 +
        measure(
          _logicalTimeRange(item.sourceBlock),
          const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        );
    final lines = _detailLines(item);
    for (final line in lines) {
      height += line.gapBefore;
      height += measure(line.text, line.style);
    }
    return math.max(76.0, height + 12);
  }

  @override
  Widget build(BuildContext context) {
    final block = item.sourceBlock;
    final lines = _detailLines(item);
    final semantic = [
      block.title,
      _logicalTimeRange(block),
      ...lines.map((line) => line.text),
    ].join(', ');
    return Semantics(
      container: true,
      label: semantic,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              item.identity.accent.withValues(alpha: 0.24),
              item.identity.accent.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.identity.accent.withValues(alpha: 0.42),
          ),
          boxShadow: [
            BoxShadow(
              color: item.identity.accent.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.identity.icon,
                    size: 18,
                    color: item.identity.accent,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      block.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                _logicalTimeRange(block),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: item.identity.accent,
                  height: 1.2,
                ),
              ),
              for (final line in lines) ...[
                SizedBox(height: line.gapBefore),
                Text(line.text, style: line.style),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine {
  final String text;
  final TextStyle style;
  final double gapBefore;

  const _DetailLine(this.text, this.style, {this.gapBefore = 3});
}

List<_DetailLine> _detailLines(Step14FinalTimelineItem item) {
  const detail = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: OptivusColors.textPrimary,
    height: 1.25,
  );
  const heading = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w900,
    color: OptivusColors.textSecondary,
    letterSpacing: 0.7,
    height: 1.2,
  );
  final block = item.sourceBlock;
  final lines = <_DetailLine>[];
  final location = block.location?.trim();
  if (location != null && location.isNotEmpty) {
    lines.add(_DetailLine(location, detail, gapBefore: 8));
  }
  if (block.section == 'eating') {
    final slot = block.mealSlot?.trim();
    final category = _userFacingMealLabel(block.mealCategory);
    final titleKey = _normalizedMealLabel(block.title);
    final slotKey = _normalizedMealLabel(slot);
    if (slot != null && slot.isNotEmpty && slotKey != titleKey) {
      lines.add(_DetailLine(slot, detail, gapBefore: 6));
    }
    final categoryKey = _normalizedMealLabel(category);
    if (category != null && categoryKey != titleKey && categoryKey != slotKey) {
      lines.add(_DetailLine(category, detail, gapBefore: 6));
    }
    final nutrition = <String>[];
    if (block.calories != null) {
      nutrition.add('${_compactNumber(block.calories!)} kcal');
    }
    if (block.protein != null) {
      nutrition.add('${_compactNumber(block.protein!)}g protein');
    }
    if (nutrition.isNotEmpty) {
      lines.add(_DetailLine(nutrition.join(' • '), detail, gapBefore: 8));
    }
    for (final dish
        in block.dishes
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)) {
      lines.add(_DetailLine(dish, detail, gapBefore: 4));
    }
  }
  if (block.section == 'skin_care') {
    final slot = block.skincareSlotLabel?.trim();
    if (slot != null &&
        slot.isNotEmpty &&
        slot.toLowerCase() != block.title.trim().toLowerCase()) {
      lines.add(_DetailLine(slot, detail, gapBefore: 6));
    }
    if (block.skincareSteps.isNotEmpty) {
      lines.add(const _DetailLine('STEPS', heading, gapBefore: 9));
      for (var index = 0; index < block.skincareSteps.length; index++) {
        final value = block.skincareSteps[index].trim();
        if (value.isNotEmpty) {
          lines.add(_DetailLine('${index + 1}. $value', detail));
        }
      }
    }
    if (block.skincareProducts.isNotEmpty) {
      lines.add(const _DetailLine('PRODUCTS', heading, gapBefore: 9));
      for (final product in block.skincareProducts) {
        if (product.trim().isNotEmpty) {
          lines.add(_DetailLine(product.trim(), detail));
        }
      }
    }
    if (block.skincareMissingItems.isNotEmpty) {
      lines.add(const _DetailLine('MISSING', heading, gapBefore: 9));
      for (final missing in block.skincareMissingItems) {
        if (missing.trim().isNotEmpty) {
          lines.add(_DetailLine('⚠ ${missing.trim()}', detail));
        }
      }
    }
  }
  final continuation = switch (item.continuation) {
    Step14Continuation.none => null,
    Step14Continuation.continuesTomorrow => 'Continues tomorrow',
    Step14Continuation.continuedFromYesterday => 'Continued from yesterday',
  };
  if (continuation != null) {
    lines.add(_DetailLine(continuation, detail, gapBefore: 8));
  }
  return lines;
}

class Step14RichTimeRail extends StatelessWidget {
  final TimelineScale scale;
  final double labelWidth;
  final double labelHeight;
  final double lineStart;

  const Step14RichTimeRail({
    super.key,
    required this.scale,
    this.labelWidth = 58,
    this.labelHeight = 18,
    this.lineStart = 66,
  });

  @override
  Widget build(BuildContext context) {
    final first = (scale.startMinute ~/ 10) * 10;
    final last = ((scale.endMinute + 9) ~/ 10) * 10;
    return Stack(
      children: [
        for (var minute = first; minute <= last; minute += 10)
          if (minute >= scale.startMinute && minute <= scale.endMinute)
            _railMark(minute),
      ],
    );
  }

  Widget _railMark(int minute) {
    final hour = minute % 60 == 0;
    final half = minute % 60 == 30;
    final key = hour
        ? 'step14-rail-hour-$minute'
        : half
        ? 'step14-rail-half-$minute'
        : 'step14-rail-minor-$minute';
    return Positioned(
      key: ValueKey(key),
      top: scale.yForMinute(minute) - (hour || half ? labelHeight / 2 : 0.5),
      left: 0,
      right: 8,
      height: hour || half ? labelHeight : 1,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: hour || half
                ? Text(
                    _railLabel(minute),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: hour ? 10 : 9,
                      fontWeight: hour ? FontWeight.w900 : FontWeight.w700,
                      color: OptivusColors.textSecondary,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(width: math.max(0, lineStart - labelWidth)),
          Expanded(
            child: Divider(
              height: 1,
              thickness: hour ? 1.2 : (half ? 0.9 : 0.6),
              color: OptivusColors.aquaAccent.withValues(
                alpha: hour ? 0.26 : (half ? 0.17 : 0.09),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _normalizedMealLabel(String? value) =>
    (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String? _userFacingMealLabel(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final normalized = _normalizedMealLabel(trimmed);
  if (normalized == 'meal' || normalized == 'eating') return null;
  if (trimmed.contains('_') || trimmed.contains('.') || trimmed.contains('/')) {
    return null;
  }
  return trimmed;
}

String _logicalTimeRange(TimelineBlockDraft block) =>
    '${_clock(block.startMinute)} – ${_clock(block.endMinute)}';

String _clock(int minute) {
  final normalized = minute % 1440;
  final hour24 = normalized ~/ 60;
  final minutePart = normalized % 60;
  final hour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
  final suffix = hour24 < 12 ? 'AM' : 'PM';
  return '$hour:${minutePart.toString().padLeft(2, '0')} $suffix';
}

String _railLabel(int minute) {
  final normalized = minute % 1440;
  final hour24 = normalized ~/ 60;
  final minutePart = normalized % 60;
  final hour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
  final suffix = hour24 < 12 ? 'AM' : 'PM';
  return minutePart == 0 ? '$hour $suffix' : '$hour:30 $suffix';
}

String _compactNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String _weekdayName(int day) => const {
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
}[day]!;
