import 'package:flutter/material.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/features/routine/widgets/routine_time_ruler.dart';
import 'package:optivus/features/routine/widgets/routine_current_time_line.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';

/// Timeline viewport — scrollable stack with ruler, cards, and current time.
///
/// Matches old Optivus `TimelineDaySchedule` layout:
/// - Stack with ruler on left, positioned cards, current time overlay
/// - Cards at exact minute positions
/// - Auto-scrolls to current time on init
class RoutineTimelineViewport extends StatefulWidget {
  final List<RoutineItem> items;
  final TimelineLayout layout;
  final bool isToday;
  final ValueChanged<RoutineItem>? onCardTap;

  const RoutineTimelineViewport({
    super.key,
    required this.items,
    required this.layout,
    required this.isToday,
    this.onCardTap,
  });

  @override
  State<RoutineTimelineViewport> createState() =>
      _RoutineTimelineViewportState();
}

class _RoutineTimelineViewportState extends State<RoutineTimelineViewport> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentTime() {
    if (!widget.isToday || !_scrollController.hasClients) return;

    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;
    final offsetMinute = currentMinute - widget.layout.visibleStartMinute;

    if (offsetMinute < 0) return;

    final targetScroll = offsetMinute * widget.layout.minuteHeight - 100;
    final maxScroll = _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      targetScroll.clamp(0, maxScroll),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 72 + 60;
    final totalHeight = widget.layout.totalHeight;

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        height: totalHeight + bottomPadding,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Vertical rail line ──
            Positioned(
              left: kTimelineTimeRailWidth +
                  kTimelineRailDotColumnWidth / 2 -
                  0.6,
              top: 0,
              bottom: 0,
              child: Container(
                width: 1.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF6B7280).withValues(alpha: 0.10),
                      const Color(0xFF6B7280).withValues(alpha: 0.025),
                    ],
                  ),
                ),
              ),
            ),

            // ── Time ruler (hour labels + dots) ──
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: kTimelineTimeRailWidth +
                  kTimelineRailDotColumnWidth +
                  kTimelineContentGap,
              child: RoutineTimeRuler(
                startMinute: widget.layout.visibleStartMinute,
                endMinute: widget.layout.visibleEndMinute,
              ),
            ),

            // ── Positioned cards ──
            ...widget.items.map((item) {
              final top = widget.layout.topForMinute(item.startMinute);
              final height = widget.layout
                  .heightForDuration(item.durationMinutes)
                  .clamp(kTimelineMinimumTaskCardHeight, double.infinity);

              // Check if this item is currently active
              final now = DateTime.now();
              final currentMinute = now.hour * 60 + now.minute;
              final isNow = widget.isToday &&
                  currentMinute >= item.startMinute &&
                  currentMinute < item.effectiveEndMinute;

              return Positioned(
                top: top,
                left: kTimelineTimeRailWidth +
                    kTimelineRailDotColumnWidth +
                    kTimelineContentGap,
                right: 12,
                height: height,
                child: RoutineCardFactory.buildCard(
                  item: item,
                  isNow: isNow,
                  onTap: () => widget.onCardTap?.call(item),
                ),
              );
            }),

            // ── Current time indicator ──
            if (widget.isToday)
              Positioned.fill(
                child: IgnorePointer(
                  child: RoutineCurrentTimeLine(
                    startMinute: widget.layout.visibleStartMinute,
                    endMinute: widget.layout.visibleEndMinute,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
