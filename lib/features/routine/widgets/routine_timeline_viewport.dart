import 'dart:math';

import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/routine_time_ruler.dart';
import 'package:optivus/features/routine/widgets/routine_current_time_line.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/routine/routine_state.dart';

/// Timeline viewport — scrollable stack with ruler, cards, and current time.
///
/// Matches old Optivus `TimelineDaySchedule` layout:
/// - Stack with ruler on left, positioned cards, current time overlay
/// - Cards at exact minute positions
/// - Auto-scrolls to current time on init
class RoutineTimelineViewport extends ConsumerStatefulWidget {
  final List<RoutineItem> items;
  final TimelineLayout layout;
  final bool isToday;
  final bool showCurrentTimeLine;
  final ValueChanged<RoutineItem>? onCardTap;

  const RoutineTimelineViewport({
    super.key,
    required this.items,
    required this.layout,
    required this.isToday,
    this.showCurrentTimeLine = true,
    this.onCardTap,
  });

  @override
  ConsumerState<RoutineTimelineViewport> createState() =>
      _RoutineTimelineViewportState();
}

class _RoutineTimelineViewportState extends ConsumerState<RoutineTimelineViewport> {
  late ScrollController _scrollController;
  
  String? _dragItemId;
  double _dragTop = 0.0;
  double _dragStartTop = 0.0;
  double _dragInitialGlobalY = 0.0;

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

    if (!widget.layout.isMinuteVisible(currentMinute)) return;

    final targetScroll = widget.layout.topForMinute(currentMinute) - 100;
    final maxScroll = _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      targetScroll.clamp(0.0, maxScroll).toDouble(),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 72 + 60;
    final timelineHeight = widget.layout.totalHeight;
    final itemLayouts = _buildItemLayouts();

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        height: timelineHeight + bottomPadding,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ── Vertical rail line ──
            Positioned(
              left:
                  kTimelineTimeRailWidth +
                  kTimelineRailDotColumnWidth / 2 -
                  0.6,
              top: 0,
              height: timelineHeight,
              child: Container(
                width: 1.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      OptivusColors.sub.withValues(alpha: 0.10),
                      OptivusColors.sub.withValues(alpha: 0.025),
                    ],
                  ),
                ),
              ),
            ),

            // ── Time ruler (hour labels + dots) ──
            Positioned(
              left: 0,
              top: 0,
              height: timelineHeight,
              width:
                  kTimelineTimeRailWidth +
                  kTimelineRailDotColumnWidth +
                  kTimelineContentGap,
              child: RoutineTimeRuler(layout: widget.layout),
            ),

            // ── Time anchor layer: exact duration rails and start/end lines ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: timelineHeight,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TimelineAnchorPainter(
                    layout: widget.layout,
                    entries: itemLayouts,
                  ),
                ),
              ),
            ),

            // ── Content card layer: readable overlays that do not affect anchors ──
            // TODO: Implement vertical drag-and-drop for cards.
            // On long press/drag card vertically, show floating time bubble.
            // Snap = 5 min or 1 min (precision mode). Warn if hitting hard block.
            ...itemLayouts.map((entry) {
              final item = entry.item;
              final now = DateTime.now();
              final currentMinute = now.hour * 60 + now.minute;
              final isNow =
                  widget.isToday &&
                  TimelineUtils.isMinuteInsideItem(item, currentMinute);

              final isDragging = _dragItemId == item.id;
              final top = isDragging ? _dragTop : entry.cardTop;

              return Positioned(
                top: top,
                left:
                    kTimelineTimeRailWidth +
                    kTimelineRailDotColumnWidth +
                    kTimelineContentGap +
                    entry.laneOffset,
                right: 12,
                child: GestureDetector(
                  onLongPressStart: (details) {
                    setState(() {
                      _dragItemId = item.id;
                      _dragStartTop = entry.cardTop;
                      _dragTop = entry.cardTop;
                      _dragInitialGlobalY = details.globalPosition.dy;
                    });
                  },
                  onLongPressMoveUpdate: (details) {
                    if (_dragItemId == item.id) {
                      setState(() {
                        _dragTop = _dragStartTop + (details.globalPosition.dy - _dragInitialGlobalY);
                      });
                    }
                  },
                  onLongPressEnd: (details) {
                    if (_dragItemId == item.id) {
                      final snap = ref.read(routineNotifierProvider).precisionMode ? 1 : 5;
                      int newMinute = widget.layout.minuteForTop(_dragTop).clamp(0, 1439);
                      newMinute = (newMinute / snap).round() * snap;
                      
                      ref.read(routineNotifierProvider.notifier).moveItem(
                        itemId: item.id,
                        date: item.date ?? ref.read(routineNotifierProvider).selectedDay,
                        startMinute: newMinute,
                        durationMinutes: item.durationMinutes,
                      );
                      
                      setState(() {
                        _dragItemId = null;
                      });
                    }
                  },
                  onLongPressCancel: () {
                    if (_dragItemId == item.id) {
                      setState(() {
                        _dragItemId = null;
                      });
                    }
                  },
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: _minimumCardHeightFor(item),
                    ),
                    child: Opacity(
                      opacity: isDragging ? 0.8 : 1.0,
                      // TODO(Phase 8): Implement drag-to-move behavior using LongPressDraggable.
                      // Wrap this RoutineCardFactory.buildCard in a GestureDetector (for long press)
                      // or LongPressDraggable to allow vertical dragging. On drag update, calculate
                      // the snapped target time (using precision mode vs 5-minute snap) and display
                      // a floating time bubble. On drop, trigger the move action with conflict resolution.
                      // Leaving this as a "safe partial" implementation for now per blueprint rules,
                      // since the standalone Move Sheet handles moving robustly.
                      child: RoutineCardFactory.buildCard(
                        item: item,
                        isNow: isNow,
                        railHeight: entry.railHeight,
                        onTap: () => widget.onCardTap?.call(item),
                      ),
                    ),
                  ),
                ),
              );
            }),

            // ── Current time indicator ──
            if (widget.isToday && widget.showCurrentTimeLine)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: timelineHeight,
                child: IgnorePointer(
                  child: RoutineCurrentTimeLine(layout: widget.layout),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_TimelineItemLayout> _buildItemLayouts() {
    final laneEndMinutes = <int>[];
    final entries = <_TimelineItemLayout>[];

    for (final item in widget.items) {
      final normalizedEndMinute = TimelineUtils.normalizedEndMinute(item);
      final startMinute = item.startMinute;

      if (normalizedEndMinute <= widget.layout.visibleStartMinute ||
          startMinute >= widget.layout.visibleEndMinute) {
        continue;
      }

      final visibleStartMinute = max(
        startMinute,
        widget.layout.visibleStartMinute,
      );
      final visibleEndMinute = min(
        normalizedEndMinute,
        widget.layout.visibleEndMinute,
      );

      var lane = 0;
      while (lane < laneEndMinutes.length &&
          laneEndMinutes[lane] > startMinute) {
        lane++;
      }

      if (lane == laneEndMinutes.length) {
        laneEndMinutes.add(normalizedEndMinute);
      } else {
        laneEndMinutes[lane] = normalizedEndMinute;
      }

      entries.add(
        _TimelineItemLayout(
          item: item,
          lane: lane,
          top: widget.layout.topForMinute(visibleStartMinute),
          cardTop: widget.layout.topForMinute(visibleStartMinute),
          railHeight: widget.layout.heightForRange(
            visibleStartMinute,
            visibleEndMinute,
          ),
          normalizedEndMinute: visibleEndMinute,
        ),
      );
    }

    return entries;
  }

  double _minimumCardHeightFor(RoutineItem item) {
    if (widget.layout.compactMode) return 88;
    return kTimelineMinimumTaskCardHeight;
  }
}

class _TimelineItemLayout {
  final RoutineItem item;
  final int lane;
  final double top;
  final double cardTop;
  final double railHeight;
  final int normalizedEndMinute;

  const _TimelineItemLayout({
    required this.item,
    required this.lane,
    required this.top,
    required this.cardTop,
    required this.railHeight,
    required this.normalizedEndMinute,
  });

  double get laneOffset => lane * 20.0;
}

class _TimelineAnchorPainter extends CustomPainter {
  final TimelineLayout layout;
  final List<_TimelineItemLayout> entries;

  const _TimelineAnchorPainter({required this.layout, required this.entries});

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in entries) {
      if (entry.railHeight <= 0) continue;

      final color = RoutineCardFactory.colorForType(entry.item.blockType);
      final startY = entry.top;
      final endY = layout.topForMinute(entry.normalizedEndMinute);

      if (endY < -20 || startY > size.height + 20) continue;

      final railX =
          kTimelineTimeRailWidth +
          kTimelineRailDotColumnWidth +
          kTimelineContentGap +
          entry.laneOffset -
          6;

      final railPaint = Paint()
        ..color = color.withValues(alpha: 0.82)
        ..style = PaintingStyle.fill;
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.44)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(railX - 1.8, startY, 3.6, endY - startY),
          const Radius.circular(3),
        ),
        railPaint,
      );

      canvas.drawLine(
        Offset(railX - 5, startY),
        Offset(railX + 14, startY),
        linePaint,
      );
      canvas.drawLine(
        Offset(railX - 5, endY),
        Offset(railX + 14, endY),
        linePaint,
      );

      canvas.drawCircle(Offset(railX, startY), 3.2, Paint()..color = color);
      canvas.drawCircle(
        Offset(railX, endY),
        2.6,
        Paint()..color = color.withValues(alpha: 0.72),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineAnchorPainter oldDelegate) {
    return layout != oldDelegate.layout || entries != oldDelegate.entries;
  }
}
