import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_motion.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/routine_glass_filter.dart';

enum _PickerPhase { closed, opening, open, closing }

/// Compact selected-day button with an authentic liquid-glass finish and
/// an anchored smooth vertical snapping date wheel popover.
///
/// Replaces the obsolete horizontal 7-day card strip.
/// Tapping the button opens a polished glass wheel selector centered on the currently
/// selected date. Selection updates [routineNotifierProvider.selectedDay] directly.
class RoutineDayPickerButton extends ConsumerStatefulWidget {
  const RoutineDayPickerButton({super.key});

  @override
  ConsumerState<RoutineDayPickerButton> createState() =>
      _RoutineDayPickerButtonState();
}

class _RoutineDayPickerButtonState extends ConsumerState<RoutineDayPickerButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late final AnimationController _anim;
  final LayerLink _link = LayerLink();
  _PickerPhase _phase = _PickerPhase.closed;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _anim.addStatusListener(_handleAnimationStatus);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _phase == _PickerPhase.opening) {
      _phase = _PickerPhase.open;
    } else if (status == AnimationStatus.dismissed &&
        _phase == _PickerPhase.closing) {
      _removeOverlaySynchronously();
      _phase = _PickerPhase.closed;
    }
  }

  void _removeOverlaySynchronously() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _anim.stop();
    _anim.removeStatusListener(_handleAnimationStatus);
    _removeOverlaySynchronously();
    _anim.dispose();
    super.dispose();
  }

  void _onDateSelected(DateTime date) {
    if (!mounted) return;
    final current = ref.read(routineNotifierProvider).selectedDay;
    if (!DateUtils.isSameDay(date, current)) {
      ref.read(routineNotifierProvider.notifier).updateSelectedDay(date);
    }
  }

  void _togglePicker() {
    switch (_phase) {
      case _PickerPhase.closed:
        _openPicker();
        break;
      case _PickerPhase.closing:
        _openPicker(); // reverse current transition smoothly
        break;
      case _PickerPhase.opening:
      case _PickerPhase.open:
        _closePicker();
        break;
    }
  }

  void _openPicker() {
    if (_phase == _PickerPhase.open || _phase == _PickerPhase.opening) return;

    final isReduced = OptivusMotion.isReducedMotion(context);

    if (_phase == _PickerPhase.closing) {
      _phase = _PickerPhase.opening;
      if (isReduced) {
        _anim.value = 1.0;
        _phase = _PickerPhase.open;
      } else {
        _anim.forward();
      }
      return;
    }

    final selectedDay = ref.read(routineNotifierProvider).selectedDay;

    _overlay = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            // 1. Explicit full-screen scrim behind the popup
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closePicker,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            // 2. Trigger proxy over button so tapping trigger while overlay is active invokes _togglePicker
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePicker,
                child: const SizedBox(width: 50, height: 48),
              ),
            ),
            // 3. Anchored floating glass date picker popover
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 8),
              child: _RoutineDayWheelPopover(
                animation: _anim,
                initialSelectedDay: selectedDay,
                onDateSelected: _onDateSelected,
                onClose: _closePicker,
              ),
            ),
          ],
        );
      },
    );

    _phase = _PickerPhase.opening;
    Overlay.of(context).insert(_overlay!);

    if (isReduced) {
      _anim.value = 1.0;
      _phase = _PickerPhase.open;
    } else {
      _anim.value = 0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _overlay == null || _phase != _PickerPhase.opening) {
          return;
        }
        _anim.forward(from: 0.0);
      });
    }
  }

  void _closePicker() {
    if (_phase == _PickerPhase.closed || _phase == _PickerPhase.closing) return;

    _phase = _PickerPhase.closing;
    final isReduced = OptivusMotion.isReducedMotion(context);

    if (isReduced) {
      _removeOverlaySynchronously();
      _anim.value = 0.0;
      _phase = _PickerPhase.closed;
    } else {
      _anim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(routineNotifierProvider).selectedDay;

    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const weekdaysFull = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const monthsFull = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final weekdayAbbr = weekdays[(selectedDay.weekday - 1).clamp(0, 6)];
    final weekdayName = weekdaysFull[(selectedDay.weekday - 1).clamp(0, 6)];
    final monthName = monthsFull[(selectedDay.month - 1).clamp(0, 11)];
    final semanticLabel =
        'Selected date, $weekdayName $monthName ${selectedDay.day}. Tap to change date.';

    return PopScope(
      canPop: _phase == _PickerPhase.closed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _phase != _PickerPhase.closed) {
          _closePicker();
        }
      },
      child: CompositedTransformTarget(
        link: _link,
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePicker,
            child: SizedBox(
              height: 48,
              width: 50,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      height: 40,
                      width: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withValues(alpha: 0.58),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.75),
                            blurRadius: 6,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Specular gloss reflection at top
                          Positioned(
                            top: 0,
                            left: 3,
                            right: 3,
                            height: 10,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                  bottom: Radius.circular(6),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.90),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  weekdayAbbr,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: OptivusColors.ink.withValues(
                                      alpha: 0.62,
                                    ),
                                    letterSpacing: 0.8,
                                    height: 1.0,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${selectedDay.day}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: OptivusColors.ink,
                                    height: 1.05,
                                    decoration: TextDecoration.none,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating glass popover containing the smooth snapping vertical date wheel.
class _RoutineDayWheelPopover extends StatefulWidget {
  final Animation<double> animation;
  final DateTime initialSelectedDay;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onClose;

  const _RoutineDayWheelPopover({
    required this.animation,
    required this.initialSelectedDay,
    required this.onDateSelected,
    required this.onClose,
  });

  @override
  State<_RoutineDayWheelPopover> createState() =>
      _RoutineDayWheelPopoverState();
}

class _RoutineDayWheelPopoverState extends State<_RoutineDayWheelPopover> {
  late final List<DateTime> _dates;
  late final int _initialIndex;
  late final PageController _scrollController;
  late final DateTime _today;
  late final Stopwatch _stopwatch;

  int _lastHapticIndex = -1;
  int? _lastHapticTimeMs;
  late int _lastCommittedIndex;

  static const double _popoverWidth = 120.0;
  static const double _popoverHeight = 220.0;
  static const double _itemExtent = 44.0;
  static const double _outerR = 22.0;
  static const double _rim = 8.0;
  static const double _innerR = _outerR - _rim + 2;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    final now = DateTime.now();
    _today = TimelineUtils.dateOnly(now);
    final selectedDay = widget.initialSelectedDay;

    // Generate supported Routine date window (at least -30 to +90 days, extended if needed)
    final pastDays = selectedDay.isBefore(_today)
        ? (_today.difference(selectedDay).inDays + 14).clamp(30, 365)
        : 30;
    final futureDays = selectedDay.isAfter(_today)
        ? (selectedDay.difference(_today).inDays + 30).clamp(90, 365)
        : 90;

    final startDate = _today.subtract(Duration(days: pastDays));
    final endDate = _today.add(Duration(days: futureDays));

    _dates = List.generate(
      endDate.difference(startDate).inDays + 1,
      (i) => startDate.add(Duration(days: i)),
    );

    final matchIndex = _dates.indexWhere(
      (d) => DateUtils.isSameDay(d, selectedDay),
    );
    _initialIndex = matchIndex >= 0 ? matchIndex : pastDays;
    _lastHapticIndex = _initialIndex;
    _lastCommittedIndex = _initialIndex;

    _scrollController = PageController(
      initialPage: _initialIndex,
      viewportFraction: 0.20,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index == _lastHapticIndex) return;

    final nowMs = _stopwatch.elapsedMilliseconds;
    if (_lastHapticTimeMs != null && (nowMs - _lastHapticTimeMs!) < 50) {
      _lastHapticIndex = index;
      return;
    }

    _lastHapticTimeMs = nowMs;
    _lastHapticIndex = index;
    HapticFeedback.mediumImpact();
  }

  void _commitSelection(int index) {
    if (index == _lastCommittedIndex) return;
    if (index < 0 || index >= _dates.length) return;

    _lastCommittedIndex = index;
    widget.onDateSelected(_dates[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _popoverWidth,
        height: _popoverHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_outerR),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_outerR),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Stack(
              children: [
                // 1. Static frosted glass background tint (0.06 alpha)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_outerR),
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ),

                // 2. Animated lightweight foreground: center selection lane + PageView
                AnimatedBuilder(
                  animation: widget.animation,
                  builder: (context, child) {
                    final progress = widget.animation.value;
                    final opacity = progress.clamp(0.0, 1.0);
                    final translateY = (1.0 - progress) * -3.0;

                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(0, translateY),
                        child: child,
                      ),
                    );
                  },
                  child: Stack(
                    children: [
                      // Center selection lane indicator (behind date items)
                      Positioned(
                        top: (_popoverHeight - _itemExtent) / 2,
                        left: 8,
                        right: 8,
                        height: _itemExtent,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.40),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Vertical PageView (RepaintBoundary isolates scrolling from glass rim)
                      NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollEndNotification) {
                            final page =
                                _scrollController.page?.round() ??
                                _scrollController.initialPage;
                            _commitSelection(page);
                          }
                          return false;
                        },
                        child: RepaintBoundary(
                          child: PageView.builder(
                            controller: _scrollController,
                            scrollDirection: Axis.vertical,
                            itemCount: _dates.length,
                            physics: const PageScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            onPageChanged: _onPageChanged,
                            itemBuilder: (context, index) {
                              return _buildDateItem(context, index);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Static glass highlight rim painter on top
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: GlassHighlightPainter(
                        outerR: _outerR,
                        innerR: _innerR,
                        rim: _rim,
                      ),
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

  Widget _buildDateItem(BuildContext context, int index) {
    final date = _dates[index];
    final isToday = DateUtils.isSameDay(date, _today);

    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final weekdayStr = weekdays[(date.weekday - 1).clamp(0, 6)];

    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        double page = _initialIndex.toDouble();
        if (_scrollController.hasClients &&
            _scrollController.position.hasContentDimensions) {
          page = _scrollController.page ?? page;
        }
        final distance = (page - index).abs();

        // Continuous scale and opacity interpolation
        final double scale;
        final double opacity;
        if (distance <= 1.0) {
          scale = 1.0 - (0.12 * distance);
          opacity = 1.0 - (0.45 * distance);
        } else if (distance <= 2.0) {
          final t = distance - 1.0;
          scale = 0.88 - (0.10 * t);
          opacity = 0.55 - (0.33 * t);
        } else {
          scale = 0.78;
          opacity = (0.22 - (0.07 * (distance - 2.0))).clamp(0.05, 0.22);
        }

        final isCenter = distance < 0.5;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final currentPage =
                _scrollController.page?.round() ??
                _scrollController.initialPage;
            if (index == currentPage) {
              _commitSelection(index);
              widget.onClose();
            } else {
              _scrollController
                  .animateToPage(
                    index,
                    duration: OptivusMotion.duration(
                      context,
                      const Duration(milliseconds: 180),
                    ),
                    curve: OptivusMotion.enterCurve,
                  )
                  .then((_) {
                    if (mounted) {
                      _commitSelection(index);
                      widget.onClose();
                    }
                  });
            }
          },
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      weekdayStr,
                      style: TextStyle(
                        fontSize: isCenter ? 12 : 11,
                        fontWeight: isCenter
                            ? FontWeight.w800
                            : FontWeight.w700,
                        color: OptivusColors.ink,
                        letterSpacing: 0.4,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: OptivusColors.routineAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ] else ...[
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: isCenter ? 18 : 15,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.ink,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
