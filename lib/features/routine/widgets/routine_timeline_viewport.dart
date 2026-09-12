import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/timeline/timeline_visual_layout.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';
import 'package:optivus/features/routine/widgets/routine_time_ruler.dart';
import 'package:optivus/features/routine/widgets/routine_current_time_line.dart';
import 'package:optivus/core/timeline/widgets/timeline_card_chrome.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_adapter.dart';

/// Routine timeline viewport redesign based on Onboarding Step 14 layout.
///
/// Features:
/// - Unchanged 64px rail, hour ruler, hour dots, and coordinate system.
/// - Source-authored onboarding colors with Routine-native fallback colors.
/// - Single front card + exposed real back-card layers in the overlap gutter.
/// - Exposed-card promotion on tap brings it forward without mutating DB.
/// - Full-detail rich cards with all dishes, skincare steps, and subtasks.
/// - Exactly 3 primary footer actions on front cards: [Start] [Done] [Move].
/// - Content-aware height measurement with constraint-based timeline stretching.
/// - Zero conflict UX: no conflict badges, warnings, or blocking dialogs.
class RoutineTimelineViewport extends ConsumerStatefulWidget {
  final List<RoutineDayEntry> items;
  final TimelineLayout layout;
  final bool isToday;
  final bool showCurrentTimeLine;
  final int? currentMinute;
  final ValueChanged<RoutineItem>? onCardTap;
  final int? selectedDay;

  const RoutineTimelineViewport({
    super.key,
    required this.items,
    required this.layout,
    required this.isToday,
    this.showCurrentTimeLine = true,
    this.currentMinute,
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
  int? _preparedCacheKey;
  RoutinePreparedTimelineLayout? _preparedCache;
  int? _lastDiagnosticKey;

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
    if (!mounted || !widget.isToday || _hasAutoScrolledForToday) {
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      // Layout not yet complete; retry after the next frame once only.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrentTime();
      });
      return;
    }

    final now = DateTime.now();
    final currentMinute = widget.currentMinute ?? now.hour * 60 + now.minute;

    if (!widget.layout.isMinuteVisible(currentMinute)) return;

    if (_lastScale == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrentTime();
      });
      return;
    }

    // Set AFTER all guard clauses pass.
    _hasAutoScrolledForToday = true;

    final targetY = _lastScale!.yForMinute(currentMinute);
    final targetScroll = targetY - 100;
    final maxScroll = position.maxScrollExtent;

    _scrollController.animateTo(
      targetScroll.clamp(0.0, maxScroll).toDouble(),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        liquidTabBarReserve(context) +
        MediaQuery.viewPaddingOf(context).bottom +
        36;
    final writeState = ref.watch(
      routineNotifierProvider.select(
        (state) => (
          selectedDay: state.selectedDay,
          pendingItemIds: state.pendingItemIds,
          pendingOccurrenceIds: state.pendingOccurrenceIds,
          failedIntentsByItemId: state.failedIntentsByItemId,
          failedOccurrenceIntentsById: state.failedOccurrenceIntentsById,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        if (!viewportWidth.isFinite || viewportWidth <= 0) {
          return const SizedBox.shrink();
        }

        final effectiveDay =
            widget.selectedDay ?? writeState.selectedDay.weekday;
        final cacheKey = _layoutCacheKey(context, viewportWidth, effectiveDay);
        final prepared = _preparedCacheKey == cacheKey
            ? _preparedCache!
            : RoutinePreparedTimelineLayout.prepare(
                context: context,
                rawItems: widget.items,
                timelineLayout: widget.layout,
                availableWidth: viewportWidth,
                selectedDay: effectiveDay,
              );
        _preparedCacheKey = cacheKey;
        _preparedCache = prepared;
        if (kDebugMode && _lastDiagnosticKey != cacheKey) {
          _lastDiagnosticKey = cacheKey;
          debugPrint(
            'RoutineTimelinePrepared: items=${prepared.items.length} '
            'classes=${prepared.items.where((e) => e.item.category == RoutineCategory.classBlock).length} '
            'work=${prepared.items.where((e) => e.item.category == RoutineCategory.job).length} '
            'eating=${prepared.items.where((e) => e.item.category == RoutineCategory.eating).length} '
            'fixed=${prepared.items.where((e) => e.item.category == RoutineCategory.fixed).length} '
            'skin=${prepared.items.where((e) => e.item.category == RoutineCategory.skinCare).length} '
            'instanceIds=${prepared.items.map((e) => e.id).join(',')}',
          );
        }
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

        return BackdropGroup(
          child: SingleChildScrollView(
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
                    child: RepaintBoundary(
                      child: RoutineTimeRuler(
                        layout: widget.layout,
                        visualScale: prepared.scale,
                      ),
                    ),
                  ),

                  // ── Time anchor layer: exact duration rails and start/end lines ──
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: timelineHeight,
                    child: RepaintBoundary(
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
                  ),

                  // Real condensed card layers remain behind the promoted card.
                  ..._buildExposedBackCards(prepared),

                  // Full-detail front/non-overlapping cards.
                  for (final item in _cardPaintOrder(prepared))
                    _buildCard(context, prepared, item, writeState),

                  // ── Current time indicator ──
                  if (widget.isToday && widget.showCurrentTimeLine)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: timelineHeight,
                      child: RepaintBoundary(
                        child: IgnorePointer(
                          child: RoutineCurrentTimeLine(
                            layout: widget.layout,
                            visualScale: prepared.scale,
                            currentMinute: widget.currentMinute,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _layoutCacheKey(
    BuildContext context,
    double viewportWidth,
    int selectedDay,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    return Object.hash(
      viewportWidth,
      selectedDay,
      widget.layout.visibleStartMinute,
      widget.layout.visibleEndMinute,
      widget.layout.minuteHeight,
      scaler.scale(16),
      Directionality.of(context),
      Object.hashAll(
        widget.items.map(
          (entry) => Object.hashAll([
            entry.instanceId,
            entry.item.title,
            entry.item.startMinute,
            entry.item.endMinute,
            entry.item.location,
            entry.item.notes,
            entry.item.onboardingVisualStyleKey,
            Object.hashAll(entry.item.subtasks ?? const <String>[]),
            Object.hashAll(entry.item.steps ?? const <String>[]),
            Object.hashAll(entry.item.dishes ?? const <String>[]),
          ]),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    RoutinePreparedTimelineLayout prepared,
    RoutineTimelineItem item,
    ({
      DateTime selectedDay,
      Set<String> pendingItemIds,
      Set<String> pendingOccurrenceIds,
      Map<String, RoutineWriteIntent> failedIntentsByItemId,
      Map<String, RoutineOccurrenceWriteIntent> failedOccurrenceIntentsById,
    })
    writeState,
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
    final currentMinute = widget.currentMinute ?? now.hour * 60 + now.minute;
    final isNow =
        widget.isToday &&
        TimelineUtils.isMinuteInsideItem(item.item, currentMinute);

    // Pending / failed state is tracked by template ID, not by instanceId.
    final templateId = item.entry.templateId;
    final occurrenceId = item.entry.occurrenceId;
    final ownerUid = item.item.userId?.trim();
    final occurrenceTargetId =
        occurrenceId ??
        (ownerUid != null && ownerUid.isNotEmpty
            ? stableRoutineOccurrenceId(
                ownerUid: ownerUid,
                routineItemId: templateId,
                occurrenceDateKey: item.entry.occurrenceDateKey,
              )
            : null);
    final isPending =
        writeState.pendingItemIds.contains(templateId) ||
        (occurrenceTargetId != null &&
            writeState.pendingOccurrenceIds.contains(occurrenceTargetId));
    final failedIntent = writeState.failedIntentsByItemId[templateId];

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
                  occurrenceDate: parseRoutineLocalDateKey(
                    item.entry.occurrenceDateKey,
                  ),
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
                              .retryFailedOperation(templateId),
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
                                  .discardFailedCreate(templateId);
                            } else {
                              ref
                                  .read(routineNotifierProvider.notifier)
                                  .dismissFailedOperation(templateId);
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
    return items.where((item) => _isFrontItem(prepared, item)).toList();
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

  List<Widget> _buildExposedBackCards(RoutinePreparedTimelineLayout prepared) {
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

      final placementRequests = [
        for (final item in backItems)
          TimelineBackTabPlacementRequest(
            id: item.id,
            startY: prepared.scale.yForMinute(
              firstRegionByItemId[item.id]!.startMinute,
            ),
            tabHeight:
                prepared.tabHeightByRegionKey[firstRegionByItemId[item.id]!
                    .key] ??
                44.0,
          ),
      ];
      final topOffsets = computeBackTabTopOffsets(placementRequests);

      for (final item in backItems) {
        final firstRegion = firstRegionByItemId[item.id]!;
        final regionKey = firstRegion.key;
        final tabHeight = prepared.tabHeightByRegionKey[regionKey] ?? 44.0;
        final top = topOffsets[item.id]!;

        widgets.add(
          Positioned(
            key: ValueKey('routine-timeline-back-tab-${item.id}-$regionKey'),
            top: top,
            left: prepared.leftOffset,
            width: prepared.fullWidth,
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
                child: TimelineCardChrome(
                  baseColor: RoutineCardFactory.colorForItem(item.item),
                  isFront: false,
                  hasOverlap: true,
                  useGroupedBackdrop: true,
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: math.max(44, prepared.gutterWidth - 16),
                      child: Row(
                        children: [
                          Icon(
                            backTabIcon(item.item),
                            size: 16,
                            color: RoutineCardFactory.colorForItem(item.item),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              shortBackLabel(item.item),
                              key: ValueKey(
                                'routine-back-label-${item.item.id}',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1,
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
              ),
            ),
          ),
        );
      }
    }

    return widgets;
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
      final color = RoutineCardFactory.colorForItem(it.item);
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
