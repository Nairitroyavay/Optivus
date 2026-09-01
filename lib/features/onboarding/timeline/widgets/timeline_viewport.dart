import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import '../models/timeline_entry.dart';
import '../models/timeline_geometry.dart';
import '../models/timeline_style.dart';
import 'timeline_block_card.dart';
import 'timeline_time_rail.dart';

/// Shared scrollable viewport for the timeline.
class TimelineViewport extends StatefulWidget {
  final TimelineLayoutResult layoutResult;
  final TimelineEntryStyle Function(TimelineEntry) styleBuilder;
  final ValueChanged<TimelineEntry>? onEntryTapped;
  final Color accent;
  final ScrollController? scrollController;
  final bool autoScrollToFirstEntry;
  final Widget Function(BuildContext, PositionedTimelineEntry)? blockBuilder;

  const TimelineViewport({
    super.key,
    required this.layoutResult,
    required this.styleBuilder,
    this.onEntryTapped,
    this.accent = OptivusColors.brandAccent,
    this.scrollController,
    this.autoScrollToFirstEntry = true,
    this.blockBuilder,
  });

  @override
  State<TimelineViewport> createState() => _TimelineViewportState();
}

class _TimelineViewportState extends State<TimelineViewport> {
  late final ScrollController _scrollController;
  bool _internalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _internalController = true;
    }

    if (widget.autoScrollToFirstEntry &&
        widget.layoutResult.entries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirst());
    }
  }

  void _scrollToFirst() {
    if (!_scrollController.hasClients || widget.layoutResult.entries.isEmpty) {
      return;
    }
    final firstTop = widget.layoutResult.entries
        .map((e) => e.top)
        .reduce(math.min);
    final target = math.max(0.0, firstTop - 40.0);
    if (target > 0) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    if (_internalController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.layoutResult;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.30),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.70),
            width: 1.2,
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
          stops: [0.0, 0.04, 0.96, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            height: result.totalHeight,
            child: Semantics(
              container: true,
              label: 'Timeline schedule, ${result.entries.length} items',
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Vertical Time Rail Background
                  TimelineTimeRailBackground(
                    scale: result.scale,
                    boundaryMinutes: result.boundaryMinutes,
                    accent: widget.accent,
                  ),

                  // Positioned Block Cards
                  for (final positioned in result.entries)
                    Positioned(
                      top: positioned.top,
                      left: positioned.left,
                      width: positioned.width,
                      height: positioned.height,
                      child:
                          widget.blockBuilder?.call(context, positioned) ??
                          TimelineBlockCard(
                            positioned: positioned,
                            style: widget.styleBuilder(positioned.entry),
                            onTap: () =>
                                widget.onEntryTapped?.call(positioned.entry),
                          ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
