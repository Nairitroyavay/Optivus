import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/timeline/timeline_visual_layout.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/routine_time_ruler.dart';
import 'package:optivus/features/routine/widgets/routine_current_time_line.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_adapter.dart';

/// Routine timeline viewport redesign based on Onboarding Step 14 layout.
///
/// Features:
/// - Unchanged 64px rail, hour ruler, hour dots, and coordinate system.
/// - Unchanged original Routine block colors via RoutineCardFactory.colorForType.
/// - Single front card + exposed back-card tabs in the overlap gutter.
/// - Tab promotion on tap brings back card to front without mutating DB.
/// - Full-detail rich cards with all dishes, skincare steps, and subtasks.
/// - Exactly 3 primary footer actions on front cards: [Start] [Done] [Move].
/// - Content-aware height measurement with constraint-based timeline stretching.
/// - Zero conflict UX: no conflict badges, warnings, or blocking dialogs.
class RoutineTimelineViewport extends ConsumerStatefulWidget {
  final List<RoutineItem> items;
  final TimelineLayout layout;
  final bool isToday;
  final bool showCurrentTimeLine;
  final ValueChanged<RoutineItem>? onCardTap;
  final int? selectedDay;

  const RoutineTimelineViewport({
    super.key,
    required this.items,
    required this.layout,
    required this.isToday,
    this.showCurrentTimeLine = true,
    this.onCardTap,
    this.selectedDay,
  });

  @override
  ConsumerState<RoutineTimelineViewport> createState() =>
      RoutineTimelineViewportState();
}

class RoutineTimelineViewportState
    extends ConsumerState<RoutineTimelineViewport> {
  late ScrollController _scrollController;
  final Map<String, String> _focusedItemIdByComponent = {};
  bool _hasAutoScrolledForToday = false;

  TimelineVisualScale? _lastScale;

  @visibleForTesting
  Map<String, String> get focusedItemIdByComponentForTesting =>
      Map.unmodifiable(_focusedItemIdByComponent);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (widget.isToday) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentTime();
      });
    }
  }

  @override
  void didUpdateWidget(covariant RoutineTimelineViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isToday && widget.isToday) {
      _hasAutoScrolledForToday = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentTime();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reconcileFocus(RoutinePreparedTimelineLayout prepared) {
    final validComponentItemMap = <String, Set<String>>{};
    for (final c in prepared.components) {
      validComponentItemMap[c.id] = c.itemIds.toSet();
    }
    _focusedItemIdByComponent.removeWhere((componentId, itemId) {
      final itemIds = validComponentItemMap[componentId];
      if (itemIds == null) return true;
      return !itemIds.contains(itemId);
    });
  }

  void _scrollToCurrentTime() {
    if (!widget.isToday ||
        !_scrollController.hasClients ||
        _hasAutoScrolledForToday)
      return;
    _hasAutoScrolledForToday = true;

    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;

    if (!widget.layout.isMinuteVisible(currentMinute)) return;

    final targetY = _lastScale != null
        ? _lastScale!.yForMinute(currentMinute)
        : widget.layout.topForMinute(currentMinute);
    final targetScroll = targetY - 100;
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
    final routineState = ref.watch(routineNotifierProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        if (!viewportWidth.isFinite || viewportWidth <= 0) {
          return const SizedBox.shrink();
        }

        final effectiveDay =
            widget.selectedDay ?? routineState.selectedDay.weekday;
        final prepared = RoutinePreparedTimelineLayout.prepare(
          context: context,
          rawItems: widget.items,
          timelineLayout: widget.layout,
          availableWidth: viewportWidth,
          selectedDay: effectiveDay,
        );
        _reconcileFocus(prepared);
        _lastScale = prepared.scale;

        final timelineHeight = math.max(
          prepared.totalHeight,
          prepared.scale.yForMinute(widget.layout.visibleEndMinute),
        );

        final isFrontById = <String, bool>{
          for (final item in prepared.items)
            item.id: _isFrontItem(prepared, item),
        };

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
                    visualScale: prepared.scale,
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
                        scale: prepared.scale,
                        items: prepared.items,
                        overlapIds: prepared.overlapItemIds,
                        isFrontById: isFrontById,
                        leftOffset: prepared.leftOffset,
                        gutterWidth: prepared.gutterWidth,
                      ),
                    ),
                  ),
                ),

                // ── Content card layer: back cards painted first, front cards painted last ──
                for (final item in _cardPaintOrder(prepared))
                  _buildCard(context, prepared, item, routineState),

                // ── Exposed back tabs in the overlap gutter ──
                ..._buildExposedBackTabs(prepared),

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
                        visualScale: prepared.scale,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    RoutinePreparedTimelineLayout prepared,
    RoutineTimelineItem item,
    RoutineState routineState,
  ) {
    final overlaps = prepared.overlapItemIds.contains(item.id);
    final isFront = _isFrontItem(prepared, item);
    final isFrontCard = overlaps && isFront;
    final cardLeft =
        prepared.leftOffset + (isFrontCard ? prepared.gutterWidth : 0);
    final cardWidth = isFrontCard ? prepared.frontWidth : prepared.fullWidth;

    final top = prepared.scale.yForMinute(item.startMinute);
    final exactH = prepared.scale.yForMinute(item.endMinute) - top;
    final height = math.max(item.minHeight, exactH);

    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;
    final isNow =
        widget.isToday &&
        TimelineUtils.isMinuteInsideItem(item.item, currentMinute);

    final isPending = routineState.pendingItemIds.contains(item.id);
    final failedIntent = routineState.failedIntentsByItemId[item.id];

    return Positioned(
      key: ValueKey('routine-timeline-card-${item.id}'),
      top: top,
      left: cardLeft,
      width: cardWidth,
      height: height,
      child: GestureDetector(
        key: ValueKey('routine-card-gesture-${item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (overlaps && !isFront) {
            final componentId = prepared.componentIdByItemId[item.id];
            if (componentId != null) {
              setState(() {
                _focusedItemIdByComponent[componentId] = item.id;
              });
            }
          }
        },
        child: ExcludeSemantics(
          key: ValueKey('routine-timeline-card-semantics-${item.id}'),
          excluding: overlaps && !isFront,
          child: Opacity(
            opacity: isPending ? 0.6 : 1.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                RoutineCardFactory.buildCard(
                  item: item.item,
                  isNow: isNow,
                  railHeight: exactH,
                  isFront: isFront,
                  hasOverlap: overlaps,
                  onTap: isPending
                      ? null
                      : () {
                          if (overlaps && !isFront) {
                            final componentId =
                                prepared.componentIdByItemId[item.id];
                            if (componentId != null) {
                              setState(() {
                                _focusedItemIdByComponent[componentId] =
                                    item.id;
                              });
                            }
                          }
                        },
                ),

                // Pending operation spinner
                if (isPending && isFront)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),

                // Failed operation banner & retry/dismiss
                if (failedIntent != null && !isPending && isFront)
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
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade200),
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
                              .read(routineNotifierProvider.notifier)
                              .retryFailedOperation(item.id),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
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
                                  .read(routineNotifierProvider.notifier)
                                  .discardFailedCreate(item.id);
                            } else {
                              ref
                                  .read(routineNotifierProvider.notifier)
                                  .dismissFailedOperation(item.id);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
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
          ),
        ),
      ),
    );
  }

  List<RoutineTimelineItem> _cardPaintOrder(
    RoutinePreparedTimelineLayout prepared,
  ) {
    final items = List<RoutineTimelineItem>.from(prepared.items);
    items.sort((a, b) {
      final aFront = _isFrontItem(prepared, a);
      final bFront = _isFrontItem(prepared, b);
      if (aFront != bFront) {
        // Back cards painted first (-1), front cards painted last (1)
        return aFront ? 1 : -1;
      }
      final aDuration = a.endMinute - a.startMinute;
      final bDuration = b.endMinute - b.startMinute;
      if (aDuration != bDuration) {
        // Longer duration painted earlier so shorter overlaps on top
        return bDuration.compareTo(aDuration);
      }
      final startCmp = a.startMinute.compareTo(b.startMinute);
      if (startCmp != 0) return startCmp;
      return a.id.compareTo(b.id);
    });
    return items;
  }

  bool _isFrontItem(
    RoutinePreparedTimelineLayout prepared,
    RoutineTimelineItem item,
  ) {
    final overlaps = prepared.overlapItemIds.contains(item.id);
    if (!overlaps) return true;

    final componentId = prepared.componentIdByItemId[item.id];
    final focusedId = componentId == null
        ? null
        : _focusedItemIdByComponent[componentId];

    if (focusedId != null) {
      if (item.id == focusedId) return true;
      final focusedItem = prepared.itemById[focusedId];
      if (focusedItem != null &&
          item.startMinute < focusedItem.endMinute &&
          item.endMinute > focusedItem.startMinute) {
        return false;
      }
    }

    final contestedRegions = prepared.regions
        .where((r) => r.itemIds.contains(item.id) && r.itemIds.length > 1)
        .toList();
    if (contestedRegions.isEmpty) return true;

    return contestedRegions.every(
      (r) => _frontForRegion(prepared, r).id == item.id,
    );
  }

  RoutineTimelineItem _frontForRegion(
    RoutinePreparedTimelineLayout prepared,
    RoutineOverlapRegion region,
  ) {
    final componentId = prepared.componentIdByItemId[region.itemIds.first];
    final focused = componentId == null
        ? null
        : _focusedItemIdByComponent[componentId];
    if (focused != null && region.itemIds.contains(focused)) {
      return prepared.itemById[focused]!;
    }
    return _defaultFront(
      region.itemIds.map((id) => prepared.itemById[id]!).toList(),
    );
  }

  RoutineTimelineItem _defaultFront(List<RoutineTimelineItem> candidates) {
    final sorted = List<RoutineTimelineItem>.from(candidates)
      ..sort(_compareFrontPriority);
    return sorted.first;
  }

  int _compareFrontPriority(RoutineTimelineItem a, RoutineTimelineItem b) {
    final duration = (a.endMinute - a.startMinute).compareTo(
      b.endMinute - b.startMinute,
    );
    if (duration != 0) return duration;
    final prio = b.priority.compareTo(a.priority);
    if (prio != 0) return prio;
    final start = a.startMinute.compareTo(b.startMinute);
    if (start != 0) return start;
    return a.id.compareTo(b.id);
  }

  List<Widget> _buildExposedBackTabs(RoutinePreparedTimelineLayout prepared) {
    final widgets = <Widget>[];

    for (final component in prepared.components) {
      final componentId = component.id;
      final componentRegions = prepared.regions
          .where(
            (r) =>
                r.itemIds.any((id) => component.itemIds.contains(id)) &&
                r.itemIds.length > 1,
          )
          .toList();

      final backItems = <RoutineTimelineItem>[];
      final firstRegionByItemId = <String, RoutineOverlapRegion>{};

      for (final id in component.itemIds) {
        final item = prepared.itemById[id];
        if (item == null) continue;
        for (final region in componentRegions) {
          if (!region.itemIds.contains(id)) continue;
          final front = _frontForRegion(prepared, region);
          if (front.id != id) {
            firstRegionByItemId.putIfAbsent(id, () => region);
            if (!backItems.contains(item)) {
              backItems.add(item);
            }
            break;
          }
        }
      }

      backItems.sort((a, b) {
        final regA = firstRegionByItemId[a.id]!;
        final regB = firstRegionByItemId[b.id]!;
        final startComp = regA.startMinute.compareTo(regB.startMinute);
        if (startComp != 0) return startComp;
        final itemComp = a.startMinute.compareTo(b.startMinute);
        if (itemComp != 0) return itemComp;
        return a.id.compareTo(b.id);
      });

      double lastBottom = -1.0;

      for (final item in backItems) {
        final firstRegion = firstRegionByItemId[item.id]!;
        final regionKey = firstRegion.key;
        final tabHeight = prepared.tabHeightByRegionKey[regionKey] ?? 40.0;
        final startY = prepared.scale.yForMinute(firstRegion.startMinute);

        final top = math.max(startY, lastBottom);
        lastBottom = top + tabHeight + 2.0;

        widgets.add(
          Positioned(
            key: ValueKey('routine-timeline-back-tab-${item.id}-$regionKey'),
            top: top,
            left: prepared.leftOffset,
            width: prepared.gutterWidth,
            height: tabHeight,
            child: Semantics(
              excludeSemantics: true,
              button: true,
              label:
                  'Show ${item.item.title} in front, ${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _focusedItemIdByComponent[componentId] = item.id;
                  });
                },
                child: _buildBackTabStrip(
                  item: item.item,
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

  Widget _buildBackTabStrip({
    required RoutineItem item,
    required double width,
    required double height,
  }) {
    final color = RoutineCardFactory.colorForType(item.blockType);
    final stripWidth = width.clamp(44.0, 96.0);
    final label = shortBackLabel(item);
    final icon = backTabIcon(item);

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
                    color: color.withValues(alpha: 0.16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.72),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 11),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    key: ValueKey('routine-back-label-${item.id}'),
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
}

class _TimelineAnchorPainter extends CustomPainter {
  final TimelineVisualScale scale;
  final List<RoutineTimelineItem> items;
  final Set<String> overlapIds;
  final Map<String, bool> isFrontById;
  final double leftOffset;
  final double gutterWidth;

  const _TimelineAnchorPainter({
    required this.scale,
    required this.items,
    required this.overlapIds,
    required this.isFrontById,
    required this.leftOffset,
    required this.gutterWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final it in items) {
      final isOverlapping = overlapIds.contains(it.id);
      final isFront = isFrontById[it.id] ?? true;
      final color = RoutineCardFactory.colorForType(it.item.blockType);
      final startY = scale.yForMinute(it.startMinute);
      final endY = scale.yForMinute(it.endMinute);

      if (endY < -20 || startY > size.height + 20) continue;

      final cardLeft =
          leftOffset + (isOverlapping && isFront ? gutterWidth : 0);
      final railX = cardLeft - 6;

      final railPaint = Paint()
        ..color = color.withValues(alpha: isFront ? 0.82 : 0.44)
        ..style = PaintingStyle.fill;
      final linePaint = Paint()
        ..color = color.withValues(alpha: isFront ? 0.44 : 0.22)
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
    return scale != oldDelegate.scale ||
        items != oldDelegate.items ||
        isFrontById != oldDelegate.isFrontById;
  }
}
