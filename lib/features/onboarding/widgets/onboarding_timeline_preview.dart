import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:optivus/core/timeline/timeline_visual_layout.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_spacing.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/models/onboarding_draft.dart';

class OnboardingDayChips extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onChanged;
  final Color accent;

  const OnboardingDayChips({
    super.key,
    required this.selectedDay,
    required this.onChanged,
    this.accent = OptivusColors.roseAccent,
  });

  static const _labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _fullDayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          for (var index = 0; index < _labels.length; index++)
            Expanded(
              child: Semantics(
                button: true,
                selected: selectedDay == index + 1,
                label: _fullDayNames[index],
                hint: selectedDay == index + 1
                    ? 'Currently selected'
                    : 'Double tap to select ${_fullDayNames[index]} schedule',
                onTap: () {
                  onChanged(index + 1);
                  // ignore: deprecated_member_use
                  SemanticsService.announce(
                    '${_fullDayNames[index]} schedule selected',
                    TextDirection.ltr,
                  );
                },
                child: SizedBox(
                  height: 42,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      onChanged(index + 1);
                      // ignore: deprecated_member_use
                      SemanticsService.announce(
                        '${_fullDayNames[index]} schedule selected',
                        TextDirection.ltr,
                      );
                    },
                    child: _OnboardingDayChip(
                      label: _labels[index],
                      selected: selectedDay == index + 1,
                      accent: accent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OnboardingDayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;

  const _OnboardingDayChip({
    required this.label,
    required this.selected,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? 40.0 : 35.0;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (selected ? accent : Colors.black).withValues(
                alpha: selected ? 0.07 : 0.035,
              ),
              blurRadius: selected ? 5 : 7,
              offset: Offset(0, selected ? 2 : 3),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: selected ? 0.60 : 0.70),
              blurRadius: selected ? 6 : 10,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? accent.withValues(alpha: 0.68)
                    : Colors.white.withValues(alpha: 0.38),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.42)
                      : Colors.white.withValues(alpha: 0.72),
                  width: selected ? 1.8 : 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: selected ? 12 : 10,
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? Colors.white
                        : OptivusColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingTimelineEmptyCard extends StatelessWidget {
  final String label;

  const OnboardingTimelineEmptyCard({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 110),
          child: OnboardingGlassCard(
            tint: Colors.white.withValues(alpha: 0.30),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            radius: 20,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingVerticalTimeline extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;
  final Widget Function(BuildContext, TimelineBlockDraft) blockBuilder;
  final List<String> Function(TimelineBlockDraft)? stretchItemsBuilder;
  final double Function(BuildContext, TimelineBlockDraft, double)?
  requiredHeightBuilder;
  final Color accent;

  const OnboardingVerticalTimeline({
    super.key,
    required this.blocks,
    required this.blockBuilder,
    this.stretchItemsBuilder,
    this.requiredHeightBuilder,
    this.accent = OptivusColors.roseAccent,
  });

  Iterable<int> _boundaryMinutes(
    List<TimelineBlockDraft> blocks,
    int startMin,
    int endMin,
  ) {
    final Set<int> boundaries = {};
    for (final b in blocks) {
      if (b.startMinute > startMin && b.startMinute < endMin) {
        boundaries.add(b.startMinute);
      }
      if (b.endMinute > startMin && b.endMinute < endMin) {
        boundaries.add(b.endMinute);
      }
    }
    final sorted = boundaries.toList()..sort();
    return sorted.where((m) => m % 60 != 0);
  }

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }
    final minStart = blocks.map((block) => block.startMinute).reduce(math.min);
    final maxEnd = blocks.map((block) => block.endMinute).reduce(math.max);
    final startMinute = math.max(5 * 60, ((minStart - 45) ~/ 60) * 60);
    final endMinute = math.min(24 * 60, (((maxEnd + 75) / 60).ceil()) * 60);
    final rangeMinutes = math.max(180, endMinute - startMinute);
    const topPadding = OptivusSpacing.base;
    const bottomPadding = OnboardingStepShell.bottomCtaHeight + 40;
    const pxPerMinute = 0.82;

    return LayoutBuilder(
      builder: (context, constraints) {
        final blockWidth = constraints.maxWidth - 64 - 16;

        final visualItems = <_OnboardingTimelineVisualItem>[];
        for (final block in blocks) {
          final requiredHeight = requiredHeightBuilder != null
              ? requiredHeightBuilder!(context, block, blockWidth)
              : calculateRequiredBlockHeight(
                  context: context,
                  titleRowHeight: 22.0,
                  items:
                      stretchItemsBuilder?.call(block) ??
                      [
                        ...block.dishes,
                        ...block.skincareProducts,
                        ...block.skincareSteps,
                      ],
                  timeLabel:
                      '${onboardingTimeLabel(block.startMinute)} - ${onboardingTimeLabel(block.endMinute)}',
                  blockWidth: blockWidth,
                );
          visualItems.add(
            _OnboardingTimelineVisualItem(
              block: block,
              minHeight: requiredHeight,
            ),
          );
        }

        final visualLayout =
            TimelineVisualLayout.build<_OnboardingTimelineVisualItem>(
              items: visualItems,
              pixelsPerMinute: pxPerMinute,
              timelineWidth: constraints.maxWidth,
              focusedItemId: null,
              visibleStartMinute: startMinute,
              visibleEndMinute: startMinute + rangeMinutes,
              topPadding: topPadding,
              leftOffset: 64,
              rightPadding: 16,
              maxOverlapLane: 0,
              overlapMinFrontWidth: 0,
              overlapMinLabelWidth: 0,
              overlapMaxLabelWidth: 0,
            );
        final scale = visualLayout.scale;
        final entryById = {
          for (final entry in visualLayout.entries) entry.item.id: entry,
        };

        final timelineHeight = math.max(
          visualLayout.totalHeight,
          scale.yForMinute(startMinute + rangeMinutes),
        );

        return Container(
          key: const ValueKey('onboarding-generic-timeline'),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.40),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.80),
                width: 1.5,
              ),
            ),
          ),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.045, 0.95, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: bottomPadding),
              child: SizedBox(
                height: timelineHeight,
                child: Semantics(
                  container: true,
                  label: 'Timeline schedule, ${blocks.length} items',
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
                            color: accent.withValues(alpha: 0.17),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.36),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (final minute in _boundaryMinutes(
                        blocks,
                        startMinute,
                        endMinute,
                      ))
                        OnboardingMinuteIndicator(
                          minute: minute,
                          top: scale.yForMinute(minute),
                          accent: accent,
                        ),
                      for (
                        var minute = startMinute;
                        minute <= endMinute;
                        minute += 60
                      )
                        OnboardingTimelineTick(
                          minute: minute,
                          top: scale.yForMinute(minute),
                          accent: accent,
                        ),
                      for (final block in blocks)
                        if (entryById[block.id] != null)
                          Positioned(
                            top: entryById[block.id]!.top,
                            left: 64,
                            right: 16,
                            height: entryById[block.id]!.height,
                            child: Semantics(
                              button: true,
                              label:
                                  '${block.title}, from ${onboardingTimeLabel(block.startMinute)} to ${onboardingTimeLabel(block.endMinute)}',
                              hint: 'Double tap to edit timeline item',
                              child: blockBuilder(context, block),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingTimelineVisualItem implements TimelineVisualItem {
  final TimelineBlockDraft block;
  @override
  final double minHeight;

  const _OnboardingTimelineVisualItem({
    required this.block,
    required this.minHeight,
  });

  @override
  String get id => block.id;

  @override
  int get startMinute => block.startMinute;

  @override
  int get endMinute => block.endMinute;

  @override
  int get priority =>
      block.blockType == TimelineBlockDraft.hardBlockKey ? 90 : 50;
}

class OnboardingTimelineTick extends StatelessWidget {
  final int minute;
  final double top;
  final Color accent;

  const OnboardingTimelineTick({
    super.key,
    required this.minute,
    required this.top,
    this.accent = OptivusColors.roseAccent,
  });

  String _compactTimeLabel(int minute) {
    final h = (minute ~/ 60) % 24;
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final amPm = h < 12 ? 'AM' : 'PM';
    return '$displayH:00\n$amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top - 10,
      left: 0,
      width: 56,
      height: 25,
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              width: 42,
              child: Text(
                _compactTimeLabel(minute),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
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
                  color: accent.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingMinuteIndicator extends StatelessWidget {
  final int minute;
  final double top;
  final Color accent;

  const OnboardingMinuteIndicator({
    super.key,
    required this.minute,
    required this.top,
    this.accent = OptivusColors.roseAccent,
  });

  String _compactMinuteLabel(int minute) {
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final amPm = h < 12 ? 'AM' : 'PM';
    final mm = m.toString().padLeft(2, '0');
    return '$displayH:$mm $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Positioned(
              top: top - 8,
              left: 0,
              width: 44,
              height: 16,
              child: Text(
                _compactMinuteLabel(minute),
                textAlign: TextAlign.right,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: accent.withValues(alpha: 0.68),
                ),
              ),
            ),
            Positioned(
              top: top,
              left: 64,
              right: 16,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Positioned(
              top: top,
              left: 44,
              width: 18,
              height: 1.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingInfoChip extends StatelessWidget {
  final String label;

  const OnboardingInfoChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: OptivusColors.textBody,
        ),
      ),
    );
  }
}
