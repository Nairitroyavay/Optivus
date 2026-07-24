import 'dart:math';

import 'package:flutter/material.dart';
import 'package:optivus/core/timeline/timeline_visual_layout.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
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

class _RoutineTimelineViewportState
    extends ConsumerState<RoutineTimelineViewport> {
  late ScrollController _scrollController;

  String? _dragItemId;
  double _dragTop = 0.0;
  double _dragStartTop = 0.0;
  double _dragInitialGlobalY = 0.0;
  String? _focusedItemId;

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
    final bottomPadding = liquidTabBarReserve(context) + 24;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final visualBuild = _buildItemLayouts(viewportWidth);
    final itemLayouts = visualBuild.entries;
    final visualScale = visualBuild.scale;
    final timelineHeight = max(
      visualBuild.totalHeight,
      itemLayouts.fold<double>(
        visualBuild.totalHeight,
        (height, entry) => max(height, entry.cardTop + entry.cardHeight),
      ),
    );
    final paintedItemLayouts = [...itemLayouts]
      ..sort((a, b) {
        if (a.isFront != b.isFront) return a.isFront ? 1 : -1;
        return a.order.compareTo(b.order);
      });
    final routineState = ref.watch(routineNotifierProvider);

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
              child: RoutineTimeRuler(
                layout: widget.layout,
                visualScale: visualScale,
              ),
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
                    scale: visualScale,
                    entries: itemLayouts,
                  ),
                ),
              ),
            ),

            // ── Content card layer: readable overlays that do not affect anchors ──
            // Long press drag moves cards with 5 min or precision-mode snapping.
            ...paintedItemLayouts.map((entry) {
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
                left: entry.left,
                right: entry.right,
                child: GestureDetector(
                  onLongPressStart: (details) {
                    setState(() {
                      _dragItemId = item.id;
                      _focusedItemId = item.id;
                      _dragStartTop = entry.cardTop;
                      _dragTop = entry.cardTop;
                      _dragInitialGlobalY = details.globalPosition.dy;
                    });
                  },
                  onLongPressMoveUpdate: (details) {
                    if (_dragItemId == item.id) {
                      setState(() {
                        _dragTop =
                            _dragStartTop +
                            (details.globalPosition.dy - _dragInitialGlobalY);
                      });
                    }
                  },
                  onLongPressEnd: (details) async {
                    if (_dragItemId == item.id) {
                      final snap =
                          ref.read(routineNotifierProvider).precisionMode
                          ? 1
                          : 5;
                      int newMinute = widget.layout
                          .clampMinuteToVisibleRange(
                            visualScale.minuteForY(_dragTop).round(),
                          )
                          .clamp(0, 1439);
                      newMinute = (newMinute / snap).round() * snap;

                      final result = await ref
                          .read(routineNotifierProvider.notifier)
                          .moveItem(
                            itemId: item.id,
                            date:
                                item.date ??
                                ref.read(routineNotifierProvider).selectedDay,
                            startMinute: newMinute,
                            durationMinutes: item.durationMinutes,
                          );

                      if (!context.mounted) return;
                      if (!result.closesUserFlow) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.message ?? 'Failed to move item.',
                            ),
                          ),
                        );
                      }
                      if (!mounted) return;
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
                    child: Builder(
                      builder: (context) {
                        final isPending = routineState.pendingItemIds.contains(
                          item.id,
                        );
                        final failedIntent =
                            routineState.failedIntentsByItemId[item.id];
                        return Opacity(
                          opacity: isDragging || isPending ? 0.6 : 1.0,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              RoutineCardFactory.buildCard(
                                item: item,
                                isNow: isNow,
                                railHeight: entry.railHeight,
                                onTap: isPending
                                    ? null
                                    : () {
                                        if (entry.hasOverlap &&
                                            !entry.isFront) {
                                          setState(
                                            () => _focusedItemId = item.id,
                                          );
                                          return;
                                        }
                                        widget.onCardTap?.call(item);
                                      },
                              ),
                              if (entry.hiddenOverlapCount > 0 && entry.isFront)
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: Semantics(
                                    button: true,
                                    label:
                                        'Show ${entry.hiddenOverlapCount} hidden overlapping routine tasks',
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _showHiddenOverlapChooser(
                                        entry,
                                        itemLayouts,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minWidth: 44,
                                          minHeight: 44,
                                        ),
                                        child: Align(
                                          alignment: Alignment.bottomRight,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.56,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '+${entry.hiddenOverlapCount} more',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (isPending)
                                const Positioned(
                                  top: 12,
                                  right: 12,
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              if (failedIntent != null && !isPending)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (failedIntent.action ==
                                          RoutineWriteAction.create) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.red.shade200,
                                            ),
                                          ),
                                          child: const Text(
                                            'Not saved',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => ref
                                            .read(
                                              routineNotifierProvider.notifier,
                                            )
                                            .retryFailedOperation(item.id),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.1,
                                                ),
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.refresh,
                                            color: Colors.red,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          if (failedIntent.action ==
                                              RoutineWriteAction.create) {
                                            ref
                                                .read(
                                                  routineNotifierProvider
                                                      .notifier,
                                                )
                                                .discardFailedCreate(item.id);
                                          } else {
                                            ref
                                                .read(
                                                  routineNotifierProvider
                                                      .notifier,
                                                )
                                                .dismissFailedOperation(
                                                  item.id,
                                                );
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.1,
                                                ),
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.red,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
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
                  child: RoutineCurrentTimeLine(
                    layout: widget.layout,
                    visualScale: visualScale,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _TimelineBuildResult _buildItemLayouts(double viewportWidth) {
    final visualItems = <_RoutineTimelineVisualItem>[];

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

      visualItems.add(
        _RoutineTimelineVisualItem(
          item: item,
          startMinute: visibleStartMinute,
          endMinute: visibleEndMinute,
          minHeight: _minimumCardHeightFor(item),
          priority: _priorityFor(item),
        ),
      );
    }

    final visualLayout = TimelineVisualLayout.build<_RoutineTimelineVisualItem>(
      items: visualItems,
      pixelsPerMinute: widget.layout.minuteHeight,
      timelineWidth: viewportWidth,
      focusedItemId: _focusedItemId,
      visibleStartMinute: widget.layout.visibleStartMinute,
      visibleEndMinute: widget.layout.visibleEndMinute,
      leftOffset:
          kTimelineTimeRailWidth +
          kTimelineRailDotColumnWidth +
          kTimelineContentGap,
      rightPadding: 12,
      maxOverlapLane: 2,
    );
    final overlapCounts = _overlapCounts(visualLayout.entries);

    final entries = [
      for (final entry in visualLayout.entries)
        _TimelineItemLayout(
          item: entry.item.item,
          lane: entry.lane,
          order: entry.order,
          top: entry.top,
          cardTop: entry.top,
          cardHeight: entry.height,
          railHeight:
              visualLayout.scale.yForMinute(entry.item.endMinute) -
              visualLayout.scale.yForMinute(entry.item.startMinute),
          normalizedEndMinute: entry.item.endMinute,
          left: entry.left,
          right: entry.right,
          hasOverlap: entry.hasOverlap,
          isFront: entry.isFront,
          hiddenOverlapCount: max(0, (overlapCounts[entry.item.id] ?? 1) - 1),
        ),
    ];
    return _TimelineBuildResult(
      entries: entries,
      scale: visualLayout.scale,
      totalHeight: visualLayout.totalHeight,
    );
  }

  double _minimumCardHeightFor(RoutineItem item) {
    if (widget.layout.compactMode) return 88;
    return kTimelineMinimumTaskCardHeight;
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

  Map<String, int> _overlapCounts(
    List<TimelineVisualEntry<_RoutineTimelineVisualItem>> entries,
  ) {
    final counts = <String, int>{};
    for (final entry in entries) {
      var count = 1;
      for (final other in entries) {
        if (entry.item.id == other.item.id) continue;
        if (entry.item.startMinute < other.item.endMinute &&
            entry.item.endMinute > other.item.startMinute) {
          count++;
        }
      }
      counts[entry.item.id] = count;
    }
    return counts;
  }

  void _showHiddenOverlapChooser(
    _TimelineItemLayout entry,
    List<_TimelineItemLayout> layouts,
  ) {
    final overlapping =
        layouts
            .where(
              (candidate) =>
                  candidate.item.id != entry.item.id &&
                  entry.item.startMinute < candidate.normalizedEndMinute &&
                  entry.normalizedEndMinute > candidate.item.startMinute,
            )
            .toList()
          ..sort((a, b) {
            final start = a.item.startMinute.compareTo(b.item.startMinute);
            if (start != 0) return start;
            return a.item.title.compareTo(b.item.title);
          });
    if (overlapping.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overlapping tasks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final candidate in overlapping)
                  Semantics(
                    button: true,
                    label:
                        'Select ${candidate.item.title}, ${TimelineUtils.formatTimeRange(candidate.item.startMinute, candidate.normalizedEndMinute)}',
                    child: ListTile(
                      minVerticalPadding: 12,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        candidate.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        TimelineUtils.formatTimeRange(
                          candidate.item.startMinute,
                          candidate.normalizedEndMinute,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        setState(() => _focusedItemId = candidate.item.id);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimelineBuildResult {
  final List<_TimelineItemLayout> entries;
  final TimelineVisualScale scale;
  final double totalHeight;

  const _TimelineBuildResult({
    required this.entries,
    required this.scale,
    required this.totalHeight,
  });
}

class _TimelineItemLayout {
  final RoutineItem item;
  final int lane;
  final int order;
  final double top;
  final double cardTop;
  final double cardHeight;
  final double railHeight;
  final int normalizedEndMinute;
  final double left;
  final double right;
  final bool hasOverlap;
  final bool isFront;
  final int hiddenOverlapCount;

  const _TimelineItemLayout({
    required this.item,
    required this.lane,
    required this.order,
    required this.top,
    required this.cardTop,
    required this.cardHeight,
    required this.railHeight,
    required this.normalizedEndMinute,
    required this.left,
    required this.right,
    required this.hasOverlap,
    required this.isFront,
    required this.hiddenOverlapCount,
  });
}

class _RoutineTimelineVisualItem implements TimelineVisualItem {
  final RoutineItem item;
  @override
  final int startMinute;
  @override
  final int endMinute;
  @override
  final double minHeight;
  @override
  final int priority;

  const _RoutineTimelineVisualItem({
    required this.item,
    required this.startMinute,
    required this.endMinute,
    required this.minHeight,
    required this.priority,
  });

  @override
  String get id => item.id;
}

class _TimelineAnchorPainter extends CustomPainter {
  final TimelineVisualScale scale;
  final List<_TimelineItemLayout> entries;

  const _TimelineAnchorPainter({required this.scale, required this.entries});

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in entries) {
      if (entry.railHeight <= 0) continue;

      final color = RoutineCardFactory.colorForType(entry.item.blockType);
      final startY = entry.top;
      final endY = scale.yForMinute(entry.normalizedEndMinute);

      if (endY < -20 || startY > size.height + 20) continue;

      final railX = entry.left - 6;

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
    return scale != oldDelegate.scale || entries != oldDelegate.entries;
  }
}
