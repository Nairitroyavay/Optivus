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
  OnboardingCompletionBundle bundle,
) {
  final result = <Step14FinalTimelineItem>[];
  var classOrdinal = 0;
  var workOrdinal = 0;

  for (var ordinal = 0; ordinal < bundle.baseTimelineBlocks.length; ordinal++) {
    final block = bundle.baseTimelineBlocks[ordinal];
    final identity = Step14TimelineVisualIdentity.resolve(
      block,
      classOrdinal: classOrdinal,
      workOrdinal: workOrdinal,
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

class Step14FinalTimeline extends StatefulWidget {
  final OnboardingCompletionBundle bundle;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final ScrollController? scrollController;

  const Step14FinalTimeline({
    super.key,
    required this.bundle,
    required this.selectedDay,
    required this.onDayChanged,
    this.scrollController,
  });

  @override
  State<Step14FinalTimeline> createState() => _Step14FinalTimelineState();
}

class _Step14FinalTimelineState extends State<Step14FinalTimeline> {
  final Map<String, String> _frontByRegion = {};
  late final ScrollController _scrollController;
  late final bool _ownsScrollController;

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
    final allItems = buildStep14FinalTimelineItems(widget.bundle);
    final dayItems = allItems
        .where((item) => item.entry.isActiveOnDay(widget.selectedDay))
        .toList();

    return Column(
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
        Expanded(
          child: dayItems.isEmpty
              ? Center(
                  child: Text(
                    'No activities scheduled for ${_weekdayName(widget.selectedDay)}.',
                    key: const ValueKey('step14-empty-day'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) =>
                      _buildTimeline(context, constraints.maxWidth, dayItems),
                ),
        ),
      ],
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    double availableWidth,
    List<Step14FinalTimelineItem> rawItems,
  ) {
    const config = TimelineGeometryConfig(
      pixelsPerMinute: 1.1,
      minInteractiveHeight: 44,
      leftOffset: 72,
      rightPadding: 14,
      topPadding: 18,
      bottomPadding: 50,
    );
    final rawEntries = rawItems.map((item) => item.entry).toList();
    final regions = buildStep14OverlapRegions(rawEntries);
    final overlapIds = <String>{
      for (final region in regions)
        if (region.entryIds.length > 1) ...region.entryIds,
    };
    final maxOverlap = regions.fold<int>(
      1,
      (value, region) => math.max(value, region.entryIds.length),
    );
    final gutter = maxOverlap > 1
        ? math.min(104.0, math.max(58.0, availableWidth * 0.24))
        : 0.0;
    final fullWidth = math.max(
      120.0,
      availableWidth - config.leftOffset - config.rightPadding,
    );
    final frontWidth = math.max(120.0, fullWidth - gutter);

    final measuredItems = <Step14FinalTimelineItem>[];
    for (final item in rawItems) {
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
      navigationConstraints.add(
        TimelineEntry(
          id: '__nav_${region.startMinute}_${region.endMinute}',
          sourceId: '__navigation__',
          startMinute: region.startMinute,
          endMinute: region.endMinute,
          repeatDays: [widget.selectedDay],
          title: '',
          category: TimelineCategory.other,
          isEditable: false,
          minHeight: math.max(44.0, (region.entryIds.length - 1) * 44.0),
        ),
      );
    }
    final layout = TimelineOverlapEngine.computeLayout(
      entries: [
        ...measuredItems.map((item) => item.entry),
        ...navigationConstraints,
      ],
      availableWidth: availableWidth,
      selectedDay: widget.selectedDay,
      config: config,
      visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
      stretchPolicy: TimelineStretchPolicy.constraintBased,
    );
    final positioned = {
      for (final entry in layout.entries)
        if (!entry.id.startsWith('__nav_')) entry.id: entry,
    };
    final itemById = {for (final item in measuredItems) item.entry.id: item};

    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3)),
      child: SingleChildScrollView(
        key: const ValueKey('step14-timeline-scroll'),
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          height: layout.totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Step14RichTimeRail(scale: layout.scale),
              for (final region in regions)
                _buildRegionFront(
                  region,
                  itemById,
                  positioned,
                  layout.scale,
                  config.leftOffset,
                  frontWidth,
                  fullWidth,
                  gutter,
                ),
              for (final region in regions.where(
                (region) => region.entryIds.length > 1,
              ))
                ..._buildBackTabs(
                  region,
                  itemById,
                  positioned,
                  layout.scale,
                  config.leftOffset,
                  gutter,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionFront(
    Step14OverlapRegion region,
    Map<String, Step14FinalTimelineItem> itemById,
    Map<String, PositionedTimelineEntry> positioned,
    TimelineScale scale,
    double left,
    double frontWidth,
    double fullWidth,
    double gutter,
  ) {
    final regionKey = region.keyForDay(widget.selectedDay);
    final selected = _frontByRegion[regionKey];
    final candidates = region.entryIds.map((id) => itemById[id]!).toList();
    final front = selected != null && region.entryIds.contains(selected)
        ? itemById[selected]!
        : (_defaultFront(candidates));
    final geometry = positioned[front.entry.id]!;
    final regionTop = scale.yForMinute(region.startMinute);
    final regionBottom = scale.yForMinute(region.endMinute);
    final x = left + (region.entryIds.length > 1 ? gutter : 0);
    return Positioned(
      key: ValueKey('step14-timeline-front-${front.entry.id}-$regionKey'),
      top: regionTop,
      left: x,
      width: region.entryIds.length > 1 ? frontWidth : fullWidth,
      height: regionBottom - regionTop,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(0, -(regionTop - geometry.top)),
          child: SizedBox(
            height: geometry.height,
            child: Step14FinalTimelineCard(item: front),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBackTabs(
    Step14OverlapRegion region,
    Map<String, Step14FinalTimelineItem> itemById,
    Map<String, PositionedTimelineEntry> positioned,
    TimelineScale scale,
    double left,
    double gutter,
  ) {
    final regionKey = region.keyForDay(widget.selectedDay);
    final candidates = region.entryIds.map((id) => itemById[id]!).toList();
    final selected = _frontByRegion[regionKey];
    final front = selected != null && region.entryIds.contains(selected)
        ? itemById[selected]!
        : _defaultFront(candidates);
    final backs = candidates.where((item) => item.entry.id != front.entry.id);
    final top = scale.yForMinute(region.startMinute);
    return [
      for (final indexed in backs.indexed)
        Positioned(
          key: ValueKey(
            'step14-timeline-back-tab-${indexed.$2.entry.id}-$regionKey',
          ),
          top: top + indexed.$1 * 44,
          left: left,
          width: gutter,
          height: 44,
          child: Semantics(
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
                  () => _frontByRegion[regionKey] = indexed.$2.entry.id,
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

  Step14FinalTimelineItem _defaultFront(
    List<Step14FinalTimelineItem> candidates,
  ) {
    final sorted = List<Step14FinalTimelineItem>.from(candidates)
      ..sort((a, b) {
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
      });
    return sorted.first;
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
}

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
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: contentWidth);
      return painter.height;
    }

    final titleWidth = math.max(24.0, contentWidth - 25);
    double measureTitle(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
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
    if (slot != null &&
        slot.isNotEmpty &&
        slot.toLowerCase() != block.title.trim().toLowerCase()) {
      lines.add(_DetailLine(slot, detail, gapBefore: 6));
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

  const Step14RichTimeRail({super.key, required this.scale});

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
      top: scale.yForMinute(minute) - (hour || half ? 8 : 0.5),
      left: 0,
      right: 8,
      height: hour || half ? 18 : 1,
      child: Row(
        children: [
          SizedBox(
            width: 58,
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
          const SizedBox(width: 8),
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
