import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_motion.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/routine_glass_filter.dart';

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
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  final LayerLink _link = LayerLink();
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: OptivusMotion.enterCurve),
    );
    _fadeAnim = CurvedAnimation(parent: _anim, curve: OptivusMotion.enterCurve);
  }

  @override
  void dispose() {
    _closePicker(immediate: true);
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

  void _openPicker() {
    if (_overlay != null || _isClosing) return;
    final selectedDay = ref.read(routineNotifierProvider).selectedDay;

    _overlay = OverlayEntry(
      builder: (_) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _closePicker(),
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(0, 8),
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, child) {
                    final isReduced = OptivusMotion.isReducedMotion(context);
                    final opacity = isReduced ? 1.0 : _fadeAnim.value;
                    final scale = isReduced ? 1.0 : _scaleAnim.value;
                    final translateY =
                        isReduced ? 0.0 : (1.0 - _fadeAnim.value) * -3.0;

                    return Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, translateY),
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.topLeft,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _RoutineDayWheelPopover(
                    initialSelectedDay: selectedDay,
                    onDateSelected: _onDateSelected,
                    onClose: () => _closePicker(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlay!);
    _anim.forward();
  }

  void _closePicker({bool immediate = false}) async {
    if (_overlay == null || _isClosing) return;
    _isClosing = true;
    if (!immediate && mounted) {
      await _anim.reverse();
    }
    _overlay?.remove();
    _overlay = null;
    _isClosing = false;
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
      canPop: _overlay == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _overlay != null) {
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
            onTap: () => _overlay == null ? _openPicker() : _closePicker(),
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
                                    color: OptivusColors.ink
                                        .withValues(alpha: 0.62),
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
  final DateTime initialSelectedDay;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onClose;

  const _RoutineDayWheelPopover({
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

  int _lastHapticIndex = -1;

  static const double _popoverWidth = 120.0;
  static const double _popoverHeight = 220.0;
  static const double _itemExtent = 44.0;
  static const double _outerR = 22.0;
  static const double _rim = 8.0;
  static const double _innerR = _outerR - _rim + 2;

  @override
  void initState() {
    super.initState();
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

    _scrollController = PageController(
      initialPage: _initialIndex,
      viewportFraction: 0.20,
    );
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      final currentPage =
          _scrollController.page?.round() ?? _scrollController.initialPage;
      _commitSelection(currentPage);
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index != _lastHapticIndex) {
      _lastHapticIndex = index;
      HapticFeedback.selectionClick();
    }
  }

  void _commitSelection(int index) {
    if (index >= 0 && index < _dates.length) {
      widget.onDateSelected(_dates[index]);
    }
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
                // 1. Transparent frosted glass tint matching Filter (0.06 alpha)
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

                // 2. Translucent center selection lane indicator (behind date items)
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

                // 3. Smooth vertical PageView with edge gradient mask
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollEndNotification) {
                      final page = _scrollController.page?.round() ??
                          _scrollController.initialPage;
                      _commitSelection(page);
                    }
                    return false;
                  },
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.16, 0.84, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: PageView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.vertical,
                      itemCount: _dates.length,
                      physics: const BouncingScrollPhysics(
                        parent: PageScrollPhysics(),
                      ),
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        return _buildDateItem(context, index);
                      },
                    ),
                  ),
                ),

                // 4. Glass highlight rim painter on top
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
            final currentPage = _scrollController.page?.round() ??
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
                      const Duration(milliseconds: 200),
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
                        fontWeight:
                            isCenter ? FontWeight.w800 : FontWeight.w700,
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
