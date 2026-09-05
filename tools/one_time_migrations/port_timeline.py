"""Archived one-time frontend migration. Do not execute."""

raise SystemExit("Archived migration: do not run against the current repository.")

import json

new_code = """
class _TimelineRange {
  final int startHour;
  final int endHour;

  const _TimelineRange({required this.startHour, required this.endHour});

  int get startMinute => startHour * 60;
  int get endMinute => endHour * 60;
  int get hourCount => (endHour - startHour).clamp(1, 24);
}

class _VisualSkinCareBlock {
  final TimelineBlockDraft block;
  final int lane;
  final int order;
  final bool hasOverlap;

  const _VisualSkinCareBlock({
    required this.block,
    required this.lane,
    required this.order,
    required this.hasOverlap,
  });
}

class _SkinCareVerticalTimeline extends StatefulWidget {
  final List<TimelineBlockDraft> blocks;
  final Color accent;

  const _SkinCareVerticalTimeline({
    super.key,
    required this.blocks,
    required this.accent,
  });

  @override
  State<_SkinCareVerticalTimeline> createState() => _SkinCareVerticalTimelineState();
}

class _SkinCareVerticalTimelineState extends State<_SkinCareVerticalTimeline> {
  static const double _kMinTimelineAreaHeight = 300.0;
  static const double _kPixelsPerMinute = 1.35;
  static const int _kMaxOverlapLane = 3;
  static const double _kLeftOffset = 64.0;
  static const double _kTimelineBottomPadding = OnboardingStepShell.bottomCtaHeight + 40;

  String? _frontBlockId;

  int _compareBlocksByTime(TimelineBlockDraft a, TimelineBlockDraft b) {
    final startCompare = a.startMinute.compareTo(b.startMinute);
    if (startCompare != 0) return startCompare;
    final endCompare = a.endMinute.compareTo(b.endMinute);
    if (endCompare != 0) return endCompare;
    return a.title.compareTo(b.title);
  }

  bool _blocksOverlap(TimelineBlockDraft a, TimelineBlockDraft b) {
    return a.startMinute < b.endMinute && a.endMinute > b.startMinute;
  }

  double _timelineY({
    required int minuteOfDay,
    required int visibleStartMinute,
    required double topPadding,
  }) {
    return topPadding + (minuteOfDay - visibleStartMinute) * _kPixelsPerMinute;
  }

  double _blockDurationHeight(TimelineBlockDraft item) {
    final durationMinutes = (item.endMinute - item.startMinute).clamp(1, 24 * 60).toInt();
    return durationMinutes * _kPixelsPerMinute;
  }

  double _blockVisualHeight(TimelineBlockDraft item) {
    return _blockDurationHeight(item);
  }

  List<_VisualSkinCareBlock> _visualBlocksFor(List<TimelineBlockDraft> dayItems) {
    final sorted = [...dayItems]..sort(_compareBlocksByTime);
    final active = <_VisualSkinCareBlock>[];
    final visualBlocks = <_VisualSkinCareBlock>[];

    for (final block in sorted) {
      active.removeWhere((entry) => !_blocksOverlap(block, entry.block));

      final usedLanes = active.map((entry) => entry.lane).toSet();
      var lane = 0;
      while (usedLanes.contains(lane) && lane < _kMaxOverlapLane) {
        lane++;
      }
      if (usedLanes.contains(lane)) {
        lane = _kMaxOverlapLane;
      }

      final visual = _VisualSkinCareBlock(
        block: block,
        lane: lane,
        order: visualBlocks.length,
        hasOverlap: dayItems.any(
          (other) => other.id != block.id && _blocksOverlap(block, other),
        ),
      );
      active.add(visual);
      visualBlocks.add(visual);
    }

    return visualBlocks;
  }

  _TimelineRange _rangeFor(List<TimelineBlockDraft> items) {
    if (items.isEmpty) {
      return const _TimelineRange(startHour: 7, endHour: 22);
    }
    final minStart = items.map((e) => e.startMinute).reduce(math.min);
    final maxEnd = items.map((e) => e.endMinute).reduce(math.max);
    
    final startHour = math.max(0, (minStart ~/ 60) - 1);
    final endHour = math.min(24, ((maxEnd + 59) ~/ 60) + 1);
    
    return _TimelineRange(startHour: startHour, endHour: endHour);
  }

  bool _isFrontVisual(_VisualSkinCareBlock visual, List<_VisualSkinCareBlock> visualBlocks) {
    if (!visual.hasOverlap) return true;
    if (_frontBlockId != null) return visual.block.id == _frontBlockId;
    final overlapping = visualBlocks.where((v) => _visualsOverlap(visual, v)).toList();
    if (overlapping.isEmpty) return true;
    final first = overlapping.reduce((a, b) => a.order < b.order ? a : b);
    return visual == first;
  }

  bool _visualsOverlap(_VisualSkinCareBlock a, _VisualSkinCareBlock b) {
    return _blocksOverlap(a.block, b.block);
  }

  double _overlapExposedLabelWidth(double availableWidth) {
    final timelineWidth = availableWidth - _kLeftOffset - 16;
    if (timelineWidth < 180) return 36.0;
    if (timelineWidth < 240) return 42.0;
    return 48.0;
  }

  double _leftForVisual(
    _VisualSkinCareBlock visual,
    List<_VisualSkinCareBlock> visualBlocks,
    double exposedLabelWidth,
  ) {
    final baseLeft = _kLeftOffset;
    if (!visual.hasOverlap) return baseLeft;

    final isFront = _isFrontVisual(visual, visualBlocks);
    if (isFront) {
      final hasOverlappingBacks = visualBlocks.any(
        (v) => _visualsOverlap(visual, v) && v != visual && !_isFrontVisual(v, visualBlocks),
      );
      return baseLeft + (hasOverlappingBacks ? exposedLabelWidth : 0.0);
    }

    final overlapping = visualBlocks.where((v) => _visualsOverlap(visual, v)).toList();
    final orderedBacks = overlapping.where((v) => !_isFrontVisual(v, visualBlocks)).toList()..sort((a, b) => a.order.compareTo(b.order));
    final backIndex = orderedBacks.indexOf(visual);
    if (backIndex == -1) return baseLeft;

    final totalBacks = orderedBacks.length;
    final maxLabelWidth = 48.0;
    final actualLabelWidth = (exposedLabelWidth / math.max(1, totalBacks - 1)).clamp(12.0, maxLabelWidth);

    return baseLeft + (backIndex * actualLabelWidth);
  }

  double _rightForVisual(_VisualSkinCareBlock visual, List<_VisualSkinCareBlock> visualBlocks) {
    if (!visual.hasOverlap) return 16.0;
    final isFront = _isFrontVisual(visual, visualBlocks);
    if (isFront) return 16.0;

    final frontBlock = visualBlocks.firstWhere(
      (v) => _visualsOverlap(visual, v) && _isFrontVisual(v, visualBlocks),
      orElse: () => visual,
    );

    if (frontBlock == visual) return 16.0;
    
    final overlapping = visualBlocks.where((v) => _visualsOverlap(visual, v)).toList();
    final orderedBacks = overlapping.where((v) => !_isFrontVisual(v, visualBlocks)).toList()..sort((a, b) => a.order.compareTo(b.order));
    final backIndex = orderedBacks.indexOf(visual);
    final totalBacks = orderedBacks.length;
    final insetPerBack = 12.0;
    
    final stackInset = (totalBacks - 1 - backIndex) * insetPerBack;
    return 16.0 + 8.0 + stackInset;
  }

  List<_VisualSkinCareBlock> _paintOrderedBlocks(List<_VisualSkinCareBlock> visualBlocks) {
    final painted = [...visualBlocks];
    painted.sort((a, b) {
      final aFront = _isFrontVisual(a, visualBlocks);
      final bFront = _isFrontVisual(b, visualBlocks);
      if (aFront && !bFront) return 1;
      if (!aFront && bFront) return -1;
      return a.order.compareTo(b.order);
    });
    return painted;
  }

  @override
  Widget build(BuildContext context) {
    final dayItems = [...widget.blocks]..sort(_compareBlocksByTime);
    final visualBlocks = _visualBlocksFor(dayItems);
    final paintedBlocks = _paintOrderedBlocks(visualBlocks);

    final range = _rangeFor(widget.blocks);
    const topPadding = 18.0;
    const bottomPadding = _kTimelineBottomPadding;

    final maxCardBottom = dayItems.fold<double>(0, (maxBottom, item) {
      final top = _timelineY(
        minuteOfDay: item.startMinute,
        visibleStartMinute: range.startMinute,
        topPadding: topPadding,
      );
      final bottom = top + _blockVisualHeight(item);
      return bottom > maxBottom ? bottom : maxBottom;
    });

    final timelineHeight = [
      _timelineY(
            minuteOfDay: range.endMinute,
            visibleStartMinute: range.startMinute,
            topPadding: topPadding,
          ) +
          bottomPadding,
      maxCardBottom + bottomPadding,
    ].reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : _kMinTimelineAreaHeight;
            
        return SizedBox(
          height: height,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
            ),
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.05, 0.95, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: _kTimelineBottomPadding),
                child: LayoutBuilder(
                  builder: (context, scrollConstraints) {
                    final exposedLabelWidth = _overlapExposedLabelWidth(
                      scrollConstraints.maxWidth,
                    );

                    return SizedBox(
                      height: timelineHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 48,
                            width: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: widget.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: widget.accent.withValues(alpha: 0.40),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.accent.withValues(alpha: 0.18),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          ..._buildMinuteIndicators(
                            range: range,
                            dayItems: dayItems,
                            topPadding: topPadding,
                          ),

                          ...List.generate(range.hourCount + 1, (i) {
                            final hour = (range.startHour + i) % 24;
                            final minute = range.startMinute + i * 60;
                            final ampm = hour < 12 ? 'AM' : 'PM';
                            final displayHour = hour == 0
                                ? 12
                                : (hour > 12 ? hour - 12 : hour);
                            final label = '$displayHour $ampm';
                            return Positioned(
                              top: _timelineY(
                                    minuteOfDay: minute,
                                    visibleStartMinute: range.startMinute,
                                    topPadding: topPadding,
                                  ) - 10,
                              left: 0,
                              width: 56,
                              height: 20,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    width: 42,
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: OptivusColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 48,
                                    top: 9,
                                    width: 4,
                                    height: 1.5,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: widget.accent.withValues(alpha: 0.35),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          ...paintedBlocks.map(
                            (visual) => _buildColoredBlock(
                              visual,
                              visualBlocks: visualBlocks,
                              visibleStartMinute: range.startMinute,
                              topPadding: topPadding,
                              exposedLabelWidth: exposedLabelWidth,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMinuteIndicators({
    required _TimelineRange range,
    required List<TimelineBlockDraft> dayItems,
    required double topPadding,
  }) {
    final widgets = <Widget>[];
    final boundaryMinutes = (<int>{
      for (final item in dayItems) ...[item.startMinute, item.endMinute],
    }.where((minute) {
      return minute % 60 != 0 &&
          minute > range.startMinute &&
          minute < range.endMinute;
    }).toList())
      ..sort();

    var lastLabelY = double.negativeInfinity;
    for (final minute in boundaryMinutes) {
      final y = _timelineY(
        minuteOfDay: minute,
        visibleStartMinute: range.startMinute,
        topPadding: topPadding,
      );
      final showLabel = y - lastLabelY >= 18;
      if (showLabel) lastLabelY = y;
      widgets.addAll([
        if (showLabel)
          Positioned(
            top: y - 8,
            left: 0,
            width: 38,
            height: 16,
            child: Text(
              TimelineUtils.formatMinuteShort(minute),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: widget.accent.withValues(alpha: 0.68),
              ),
            ),
          ),
        Positioned(
          top: y,
          left: _kLeftOffset,
          right: 16,
          height: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Positioned(
          top: y,
          left: 44,
          width: 18,
          height: 1.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ]);
    }
    return widgets;
  }

  Widget _buildColoredBlock(
    _VisualSkinCareBlock visual, {
    required List<_VisualSkinCareBlock> visualBlocks,
    required int visibleStartMinute,
    required double topPadding,
    required double exposedLabelWidth,
  }) {
    final item = visual.block;
    final isFront = _isFrontVisual(visual, visualBlocks);
    final isBackOverlap = visual.hasOverlap && !isFront;
    final top = _timelineY(
      minuteOfDay: item.startMinute,
      visibleStartMinute: visibleStartMinute,
      topPadding: topPadding,
    );
    final exactHeight = _blockDurationHeight(item);
    final height = exactHeight;
    final compact = height < 92;
    final tiny = height < 42;
    final baseColor = widget.accent;

    return Positioned(
      top: top,
      left: _leftForVisual(visual, visualBlocks, exposedLabelWidth),
      right: _rightForVisual(visual, visualBlocks),
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _frontBlockId = item.id);
        },
        child: SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(
                alpha: visual.hasOverlap ? (isFront ? 0.72 : 0.58) : 0.42,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withValues(alpha: isFront ? 0.26 : 0.18),
                  baseColor.withValues(alpha: isFront ? 0.08 : 0.04),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: isFront ? 0.96 : 0.82),
                width: isFront ? 1.6 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: isFront ? 0.18 : 0.09),
                  blurRadius: isFront ? 14 : 10,
                  offset: Offset(0, isFront ? 5 : 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: LayoutBuilder(
                  builder: (context, cardConstraints) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isBackOverlap ? 0 : tiny ? 8 : compact ? 12 : 14,
                        vertical: isBackOverlap ? 5 : tiny ? 1 : compact ? 7 : 10,
                      ),
                      child: isBackOverlap
                        ? Center(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: baseColor.withValues(alpha: 0.7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.face_retouching_natural_rounded, color: baseColor, size: tiny ? 12 : 18),
                                  SizedBox(width: tiny ? 4 : 8),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: tiny ? 12 : 15,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0F111A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!tiny && item.skincareProducts != null && item.skincareProducts!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    child: Text(
                                      item.skincareProducts!.join('\n'),
                                      style: TextStyle(
                                        fontSize: compact ? 11 : 12,
                                        fontWeight: FontWeight.w600,
                                        color: OptivusColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
"""

with open('/Users/roy/optivus2/Optivus/lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart', 'r') as f:
    content = f.read()

import re

# find where _SkinCareStretchedSegment starts
start_idx = content.find("class _SkinCareStretchedSegment {")
if start_idx == -1:
    print("Could not find start of _SkinCareStretchedSegment")
    exit(1)

# find where _SkinCareCompactMinuteLabel ends
end_idx = content.find("class _SkinCareChipGroup extends StatelessWidget {")
if end_idx == -1:
    print("Could not find start of _SkinCareChipGroup")
    exit(1)

new_content = content[:start_idx] + new_code + "\n" + content[end_idx:]

with open('/Users/roy/optivus2/Optivus/lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart', 'w') as f:
    f.write(new_content)

print("Timeline replaced successfully")
