import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart'
    hide TimelineLayoutResult;
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/layout/timeline_overlap_engine.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/onboarding_timeline_card_chrome.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_day_chips.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_time_rail.dart';
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
      if (block.needsTimeConfirmation || block.title.trim().isEmpty) continue;
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

typedef Step14OverlapRegion = TimelineOverlapRegion;

/// Splits a day into exact, non-transitive concurrency regions.
List<Step14OverlapRegion> buildStep14OverlapRegions(
  List<TimelineEntry> entries,
) => buildTimelineOverlapRegions(entries);

typedef Step14OverlapComponent = TimelineOverlapComponent;

/// Builds connected interaction components without changing atomic active sets.
List<Step14OverlapComponent> buildStep14OverlapComponents(
  List<TimelineEntry> entries, {
  required int selectedDay,
}) => buildTimelineOverlapComponents(entries, day: selectedDay);

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
      pixelsPerMinute: 84.0 / 60.0,
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
    final cardLeftOffsetByMinute = <int, double>{};
    final itemsForRail = List<Step14FinalTimelineItem>.from(prepared.items)
      ..sort(
        (a, b) => (_isFrontItem(prepared, a) ? 1 : 0).compareTo(
          _isFrontItem(prepared, b) ? 1 : 0,
        ),
      );
    for (final item in itemsForRail) {
      final isFront = _isFrontItem(prepared, item);
      final isFrontOverlap =
          prepared.overlapEntryIds.contains(item.entry.id) && isFront;
      final offset =
          prepared.leftOffset + (isFrontOverlap ? prepared.gutterWidth : 0.0);
      cardLeftOffsetByMinute[item.entry.startMinute] = offset;
      cardLeftOffsetByMinute[item.entry.endMinute] = offset;
    }

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
                leftOffset: prepared.leftOffset,
                items: prepared.items,
                cardLeftOffsetByMinute: cardLeftOffsetByMinute,
              ),
              for (final item in _cardPaintOrder(prepared))
                _buildLogicalCard(prepared, item),
              ..._buildExposedBackTabs(prepared),
            ],
          ),
        ),
      ),
    );
  }

  List<Step14FinalTimelineItem> _cardPaintOrder(
    Step14PreparedTimelineLayout prepared,
  ) {
    final items = List<Step14FinalTimelineItem>.from(prepared.items);
    items.sort((a, b) {
      final aFront = _isFrontItem(prepared, a);
      final bFront = _isFrontItem(prepared, b);
      if (aFront != bFront) {
        // Back cards painted first (-1), front cards painted last (1)
        return aFront ? 1 : -1;
      }
      final aDuration = a.entry.endMinute - a.entry.startMinute;
      final bDuration = b.entry.endMinute - b.entry.startMinute;
      if (aDuration != bDuration) {
        // Longer duration painted earlier so shorter overlaps on top
        return bDuration.compareTo(aDuration);
      }
      final startCompare = a.entry.startMinute.compareTo(b.entry.startMinute);
      if (startCompare != 0) return startCompare;
      return a.canonicalOrdinal.compareTo(b.canonicalOrdinal);
    });
    return items;
  }

  bool _isFrontItem(
    Step14PreparedTimelineLayout prepared,
    Step14FinalTimelineItem item,
  ) {
    final overlaps = prepared.overlapEntryIds.contains(item.entry.id);
    if (!overlaps) return true;

    final componentId = prepared.componentIdByEntryId[item.entry.id];
    final focusedId = componentId == null
        ? null
        : _focusedEntryByComponent[componentId];

    if (focusedId != null) {
      if (item.entry.id == focusedId) return true;
      final focusedItem = prepared.itemById[focusedId];
      if (focusedItem != null &&
          item.entry.startMinute < focusedItem.entry.endMinute &&
          item.entry.endMinute > focusedItem.entry.startMinute) {
        return false;
      }
    }

    final contestedRegions = prepared.regions
        .where(
          (r) => r.entryIds.contains(item.entry.id) && r.entryIds.length > 1,
        )
        .toList();
    if (contestedRegions.isEmpty) return true;

    return contestedRegions.every(
      (r) => _frontForRegion(prepared, r).entry.id == item.entry.id,
    );
  }

  Step14FinalTimelineItem _frontForRegion(
    Step14PreparedTimelineLayout prepared,
    Step14OverlapRegion region,
  ) {
    final componentId = prepared.componentIdByEntryId[region.entryIds.first];
    final focused = componentId == null
        ? null
        : _focusedEntryByComponent[componentId];
    return focused != null && region.entryIds.contains(focused)
        ? prepared.itemById[focused]!
        : _defaultFront(
            region.entryIds.map((id) => prepared.itemById[id]!).toList(),
          );
  }

  Widget _buildLogicalCard(
    Step14PreparedTimelineLayout prepared,
    Step14FinalTimelineItem item,
  ) {
    final geometry = prepared.positionedById[item.entry.id]!;
    final overlaps = prepared.overlapEntryIds.contains(item.entry.id);
    final isFront = _isFrontItem(prepared, item);
    final isFrontCard = overlaps && isFront;
    final cardLeft =
        prepared.leftOffset + (isFrontCard ? prepared.gutterWidth : 0);
    final cardWidth = isFrontCard ? prepared.frontWidth : prepared.fullWidth;

    void handleTap() {
      final componentId = prepared.componentIdByEntryId[item.entry.id];
      if (componentId != null) {
        setState(() {
          if (_focusedEntryByComponent[componentId] == item.entry.id) {
            _focusedEntryByComponent.remove(componentId);
          } else {
            _focusedEntryByComponent[componentId] = item.entry.id;
          }
        });
      }
    }

    return Positioned(
      key: ValueKey('step14-timeline-card-${item.entry.id}'),
      top: geometry.top,
      left: cardLeft,
      width: cardWidth,
      height: geometry.height,
      child: GestureDetector(
        key: ValueKey('step14-card-gesture-${item.entry.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: handleTap,
        child: ExcludeSemantics(
          key: ValueKey('step14-timeline-card-semantics-${item.entry.id}'),
          excluding: overlaps && !isFront,
          child: Container(
            key: ValueKey('step14-card-background-${item.entry.id}'),
            child: OnboardingTimelineCardChrome(
              baseColor: item.identity.accent,
              isFront: isFront,
              hasOverlap: overlaps,
              padding: EdgeInsets.zero,
              child: Offstage(
                offstage: overlaps && !isFront,
                child: Step14FinalTimelineCard(
                  key: ValueKey('step14-card-front-content-${item.entry.id}'),
                  item: item,
                  isFront: isFront,
                  hasOverlap: overlaps,
                  gutterWidth: prepared.gutterWidth,
                  includeBackground: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExposedBackTabs(Step14PreparedTimelineLayout prepared) {
    final widgets = <Widget>[];
    for (final component in prepared.components) {
      final componentId = component.id;
      final componentRegions = prepared.regions
          .where(
            (r) =>
                r.entryIds.any((id) => component.entryIds.contains(id)) &&
                r.entryIds.length > 1,
          )
          .toList();

      final backItems = <Step14FinalTimelineItem>[];
      final firstRegionByItemId = <String, Step14OverlapRegion>{};

      for (final id in component.entryIds) {
        final item = prepared.itemById[id];
        if (item == null) continue;
        for (final region in componentRegions) {
          if (!region.entryIds.contains(id)) continue;
          final front = _frontForRegion(prepared, region);
          if (front.entry.id != id) {
            firstRegionByItemId.putIfAbsent(id, () => region);
            if (!backItems.contains(item)) {
              backItems.add(item);
            }
            break;
          }
        }
      }

      backItems.sort((a, b) {
        final regA = firstRegionByItemId[a.entry.id]!;
        final regB = firstRegionByItemId[b.entry.id]!;
        final startComp = regA.startMinute.compareTo(regB.startMinute);
        if (startComp != 0) return startComp;
        final entryComp = a.entry.startMinute.compareTo(b.entry.startMinute);
        if (entryComp != 0) return entryComp;
        return a.canonicalOrdinal.compareTo(b.canonicalOrdinal);
      });

      var lastStartY = -1.0;
      var stackIndex = 0;

      for (final item in backItems) {
        final firstRegion = firstRegionByItemId[item.entry.id]!;
        final regionKey = firstRegion.keyForDay(prepared.selectedDay);
        final tabHeight = prepared.tabHeightByRegionKey[regionKey] ?? 44.0;
        final startY = prepared.layout.scale.yForMinute(
          firstRegion.startMinute,
        );

        if (lastStartY >= 0 && (startY - lastStartY).abs() < 4.0) {
          stackIndex++;
        } else {
          stackIndex = 0;
          lastStartY = startY;
        }

        final top = startY + stackIndex * tabHeight;

        widgets.add(
          Positioned(
            key: ValueKey(
              'step14-timeline-back-tab-${item.entry.id}-$regionKey',
            ),
            top: top,
            left: prepared.leftOffset,
            width: prepared.gutterWidth,
            height: tabHeight,
            child: Semantics(
              excludeSemantics: true,
              button: true,
              label:
                  'Show ${item.sourceBlock.title} in front, ${_logicalTimeRange(item.sourceBlock)}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(
                  () => _focusedEntryByComponent[componentId] = item.entry.id,
                ),
                child: _buildBackTabStrip(
                  item: item,
                  width: prepared.gutterWidth,
                  height: tabHeight,
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
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

@immutable
class Step14BackLabelSegment {
  final double top;
  final double height;
  final String key;

  const Step14BackLabelSegment({
    required this.top,
    required this.height,
    required this.key,
  });
}

class Step14FinalTimelineCard extends StatelessWidget {
  final Step14FinalTimelineItem item;
  final bool isFront;
  final bool hasOverlap;
  final double gutterWidth;
  final bool includeBackground;

  const Step14FinalTimelineCard({
    super.key,
    required this.item,
    this.isFront = true,
    this.hasOverlap = false,
    this.gutterWidth = 80.0,
    this.includeBackground = true,
  });

  static double measureHeight(
    BuildContext context,
    double width,
    Step14FinalTimelineItem item,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final contentWidth = math.max(40.0, width - 24);

    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: scaler,
      )..layout(maxWidth: contentWidth);
      return painter.height;
    }

    final titleWidth = math.max(24.0, contentWidth - 25);
    double measureTitle(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: scaler,
      )..layout(maxWidth: titleWidth);
      return math.max(18.0, painter.height);
    }

    double measureWrap(
      List<String> items,
      TextStyle textStyle,
      EdgeInsets chipPadding,
      double spacing,
      double runSpacing,
    ) {
      if (items.isEmpty) return 0;
      var currentLineWidth = 0.0;
      var lineCount = 1;
      var maxChipHeight = 0.0;
      for (final text in items) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: textDirection,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final chipWidth = painter.width + chipPadding.horizontal + 2.0;
        maxChipHeight = math.max(
          maxChipHeight,
          painter.height + chipPadding.vertical + 2.0,
        );
        if (currentLineWidth > 0 &&
            currentLineWidth + spacing + chipWidth > contentWidth) {
          lineCount++;
          currentLineWidth = chipWidth;
        } else {
          currentLineWidth += (currentLineWidth > 0 ? spacing : 0) + chipWidth;
        }
      }
      return lineCount * maxChipHeight + (lineCount - 1) * runSpacing;
    }

    const detailStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: OptivusColors.textPrimary,
      height: 1.25,
    );
    const headingStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w900,
      color: OptivusColors.textSecondary,
      letterSpacing: 0.7,
      height: 1.2,
    );
    const chipTextStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      color: OptivusColors.textPrimary,
    );

    var height = 0.0;

    // Title
    height += measureTitle(
      item.sourceBlock.title,
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, height: 1.2),
    );

    // Time range
    height += 5.0;
    height += measure(
      _logicalTimeRange(item.sourceBlock),
      const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, height: 1.2),
    );

    final block = item.sourceBlock;

    // Location
    final location = block.location?.trim();
    if (location != null && location.isNotEmpty) {
      height += 8.0;
      height += measure(location, detailStyle);
    }

    // Eating section
    if (block.section == 'eating') {
      final slot = block.mealSlot?.trim();
      final category = _userFacingMealLabel(block.mealCategory);
      final titleKey = _normalizedMealLabel(block.title);
      final slotKey = _normalizedMealLabel(slot);

      if (slot != null && slot.isNotEmpty && slotKey != titleKey) {
        height += 6.0;
        height += measure(slot, detailStyle);
      }

      final categoryKey = _normalizedMealLabel(category);
      if (category != null &&
          categoryKey != titleKey &&
          categoryKey != slotKey) {
        height += 6.0;
        height += measure(category, detailStyle);
      }

      final nutrition = <String>[];
      if (block.calories != null) {
        nutrition.add('${_compactNumber(block.calories!)} kcal');
      }
      if (block.protein != null) {
        nutrition.add('${_compactNumber(block.protein!)}g protein');
      }
      if (nutrition.isNotEmpty) {
        height += 8.0;
        final nutritionText = nutrition.join(' • ');
        height +=
            measure(
              nutritionText,
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ) +
            8.0;
      }

      final dishes = block.dishes
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
      if (dishes.isNotEmpty) {
        height += 6.0;
        height += measureWrap(
          dishes,
          chipTextStyle,
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          6.0,
          6.0,
        );
      }
    }

    // Skin care section
    if (block.section == 'skin_care') {
      final slot = block.skincareSlotLabel?.trim();
      if (slot != null &&
          slot.isNotEmpty &&
          slot.toLowerCase() != block.title.trim().toLowerCase()) {
        height += 6.0;
        height += measure(slot, detailStyle);
      }

      if (block.skincareSteps.isNotEmpty) {
        height += 9.0;
        height += measure('STEPS', headingStyle);
        for (var index = 0; index < block.skincareSteps.length; index++) {
          final value = block.skincareSteps[index].trim();
          if (value.isNotEmpty) {
            height += 3.0;
            height += measure('${index + 1}. $value', detailStyle);
          }
        }
      }

      if (block.skincareProducts.isNotEmpty) {
        height += 9.0;
        height += measure('PRODUCTS', headingStyle);
        for (final product in block.skincareProducts) {
          if (product.trim().isNotEmpty) {
            height += 3.0;
            height += measure(product.trim(), detailStyle);
          }
        }
      }

      if (block.skincareMissingItems.isNotEmpty) {
        height += 9.0;
        height += measure('MISSING', headingStyle);
        for (final missing in block.skincareMissingItems) {
          if (missing.trim().isNotEmpty) {
            height += 3.0;
            height += measure('⚠ ${missing.trim()}', detailStyle);
          }
        }
      }
    }

    // Continuation
    final continuation = switch (item.continuation) {
      Step14Continuation.none => null,
      Step14Continuation.continuesTomorrow => 'Continues tomorrow',
      Step14Continuation.continuedFromYesterday => 'Continued from yesterday',
    };
    if (continuation != null) {
      height += 8.0;
      height += measure(continuation, detailStyle);
    }

    return math.max(76.0, height + 24.0 + 2.8 + 12.0);
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

    final content = Semantics(
      container: true,
      label: semantic,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _buildRichCardBody(context),
      ),
    );

    if (!includeBackground) {
      return content;
    }

    return Container(
      key: ValueKey('step14-card-background-${item.entry.id}'),
      child: OnboardingTimelineCardChrome(
        baseColor: item.identity.accent,
        isFront: isFront,
        hasOverlap: hasOverlap,
        padding: EdgeInsets.zero,
        child: content,
      ),
    );
  }

  Widget _buildRichCardBody(BuildContext context) {
    final block = item.sourceBlock;

    const detailStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: OptivusColors.textPrimary,
      height: 1.25,
    );
    const headingStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w900,
      color: OptivusColors.textSecondary,
      letterSpacing: 0.7,
      height: 1.2,
    );

    final location = block.location?.trim();

    final nutrition = <String>[];
    if (block.section == 'eating') {
      if (block.calories != null) {
        nutrition.add('${_compactNumber(block.calories!)} kcal');
      }
      if (block.protein != null) {
        nutrition.add('${_compactNumber(block.protein!)}g protein');
      }
    }

    final cleanDishes = block.section == 'eating'
        ? block.dishes.map((v) => v.trim()).where((v) => v.isNotEmpty).toList()
        : const <String>[];

    final slot = block.section == 'eating'
        ? block.mealSlot?.trim()
        : block.section == 'skin_care'
        ? block.skincareSlotLabel?.trim()
        : null;

    final category = block.section == 'eating'
        ? _userFacingMealLabel(block.mealCategory)
        : null;

    final titleKey = _normalizedMealLabel(block.title);
    final slotKey = _normalizedMealLabel(slot);
    final showSlot =
        slot != null &&
        slot.isNotEmpty &&
        slotKey != titleKey &&
        (block.section != 'skin_care' ||
            slot.toLowerCase() != block.title.trim().toLowerCase());

    final categoryKey = _normalizedMealLabel(category);
    final showCategory =
        category != null && categoryKey != titleKey && categoryKey != slotKey;

    final continuation = switch (item.continuation) {
      Step14Continuation.none => null,
      Step14Continuation.continuesTomorrow => 'Continues tomorrow',
      Step14Continuation.continuedFromYesterday => 'Continued from yesterday',
    };

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.identity.icon, size: 18, color: item.identity.accent),
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
          if (location != null && location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(location, style: detailStyle),
          ],
          if (showSlot) ...[
            const SizedBox(height: 6),
            Text(slot, style: detailStyle),
          ],
          if (showCategory) ...[
            const SizedBox(height: 6),
            Text(category, style: detailStyle),
          ],
          if (nutrition.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.identity.accent.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Text(
                nutrition.join(' • '),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: item.identity.accent,
                ),
              ),
            ),
          ],
          if (cleanDishes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final dish in cleanDishes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFD4D7E2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      dish,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (block.section == 'skin_care') ...[
            if (block.skincareSteps.isNotEmpty) ...[
              const SizedBox(height: 9),
              const Text('STEPS', style: headingStyle),
              for (var index = 0; index < block.skincareSteps.length; index++)
                if (block.skincareSteps[index].trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${index + 1}. ${block.skincareSteps[index].trim()}',
                    style: detailStyle,
                  ),
                ],
            ],
            if (block.skincareProducts.isNotEmpty) ...[
              const SizedBox(height: 9),
              const Text('PRODUCTS', style: headingStyle),
              for (final product in block.skincareProducts)
                if (product.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(product.trim(), style: detailStyle),
                ],
            ],
            if (block.skincareMissingItems.isNotEmpty) ...[
              const SizedBox(height: 9),
              const Text(
                'MISSING',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.warning,
                  letterSpacing: 0.7,
                  height: 1.2,
                ),
              ),
              for (final missing in block.skincareMissingItems)
                if (missing.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '⚠ ${missing.trim()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.warning,
                      height: 1.25,
                    ),
                  ),
                ],
            ],
          ],
          if (continuation != null) ...[
            const SizedBox(height: 8),
            Text(continuation, style: detailStyle),
          ],
        ],
      ),
    );
  }
}

Widget _buildBackTabStrip({
  required Step14FinalTimelineItem item,
  required double width,
  required double height,
}) {
  final stripWidth = width.clamp(70.0, 96.0);
  final baseColor = item.identity.accent;

  return Align(
    alignment: Alignment.centerLeft,
    child: ClipRect(
      child: SizedBox(
        width: stripWidth,
        height: height,
        child: Padding(
          padding: const EdgeInsets.only(left: 6, right: 6),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: baseColor.withValues(alpha: 0.16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.72),
                    width: 1,
                  ),
                ),
                child: Icon(item.identity.icon, color: baseColor, size: 11),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _shortBackLabel(item.sourceBlock),
                  key: ValueKey('step14-back-label-${item.entry.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _shortBackLabel(TimelineBlockDraft block) {
  final raw = block.title.trim();
  final lower = raw.toLowerCase();

  if (block.section == 'job_work_business') {
    if (lower.contains('office')) return 'Office';
    if (lower.contains('work') || lower.contains('job')) return 'Job';
    return raw.length <= 8 ? raw : 'Job';
  }

  if (block.section == 'classes') {
    return raw.length <= 8 ? raw : raw.split(' ').first;
  }

  if (block.section == 'eating') {
    final cat = block.mealCategory?.trim();
    if (cat != null && cat.isNotEmpty && cat.toLowerCase() != 'meal') {
      return cat.length <= 8 ? cat : cat.split(' ').first;
    }
    if (lower.contains('breakfast')) return 'Breakfast';
    if (lower.contains('lunch')) return 'Lunch';
    if (lower.contains('dinner')) return 'Dinner';
    if (lower.contains('snack')) return 'Snack';
    return raw.length <= 8 ? raw : raw.split(' ').first;
  }

  if (block.section == 'fixed') {
    if (lower.contains('sleep')) return 'Sleep';
    if (lower.contains('bath')) return 'Bath';
    return raw.length <= 8 ? raw : raw.split(' ').first;
  }

  if (block.section == 'skin_care') {
    return 'Skin';
  }

  return raw.length <= 8 ? raw : raw.split(' ').first;
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
  final double? leftOffset;
  final List<Step14FinalTimelineItem> items;

  final Map<int, double>? cardLeftOffsetByMinute;

  const Step14RichTimeRail({
    super.key,
    required this.scale,
    this.labelWidth = 58,
    this.labelHeight = 18,
    this.lineStart = 66,
    this.leftOffset,
    this.items = const [],
    this.cardLeftOffsetByMinute,
  });

  @override
  Widget build(BuildContext context) {
    final boundaryMinutes =
        (<int>{
                for (final item in items) ...[
                  item.entry.startMinute,
                  item.entry.endMinute,
                ],
              }
              .where((m) => m >= scale.startMinute && m <= scale.endMinute)
              .toList())
          ..sort();

    return TimelineTimeRailBackground(
      scale: scale,
      boundaryMinutes: boundaryMinutes,
      accent: OptivusColors.brandAccent,
      keyPrefix: 'step14-rail',
      minimumBoundaryLabelSpacing: 18,
      cardLeftOffset: leftOffset ?? 64.0,
      labelWidth: labelWidth,
      labelHeight: labelHeight,
      cardLeftOffsetByMinute: cardLeftOffsetByMinute,
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
