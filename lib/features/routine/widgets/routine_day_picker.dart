import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
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
  late final Animation<double> _fade;
  final LayerLink _link = LayerLink();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
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
                child: ScaleTransition(
                  scale: _fade,
                  alignment: Alignment.topLeft,
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
    if (_overlay == null) return;
    if (!immediate && mounted) {
      await _anim.reverse();
    }
    _overlay?.remove();
    _overlay = null;
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

    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          onTap: () => _overlay == null ? _openPicker() : _closePicker(),
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
                              color: OptivusColors.ink.withValues(alpha: 0.62),
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
  late final FixedExtentScrollController _scrollController;
  late final ValueNotifier<int> _centeredIndexNotifier;

  int _lastHapticIndex = -1;
  Timer? _debounceTimer;

  static const double _popoverWidth = 158.0;
  static const double _popoverHeight = 240.0;
  static const double _itemExtent = 48.0;
  static const double _outerR = 22.0;
  static const double _rim = 8.0;
  static const double _innerR = _outerR - _rim + 2;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = TimelineUtils.dateOnly(now);
    final selectedDay = widget.initialSelectedDay;

    // Generate supported Routine date window (at least -30 to +90 days, extended if needed)
    final pastDays = selectedDay.isBefore(today)
        ? (today.difference(selectedDay).inDays + 14).clamp(30, 365)
        : 30;
    final futureDays = selectedDay.isAfter(today)
        ? (selectedDay.difference(today).inDays + 30).clamp(90, 365)
        : 90;

    final startDate = today.subtract(Duration(days: pastDays));
    final endDate = today.add(Duration(days: futureDays));

    _dates = List.generate(
      endDate.difference(startDate).inDays + 1,
      (i) => startDate.add(Duration(days: i)),
    );

    final matchIndex = _dates.indexWhere(
      (d) => DateUtils.isSameDay(d, selectedDay),
    );
    _initialIndex = matchIndex >= 0 ? matchIndex : pastDays;
    _centeredIndexNotifier = ValueNotifier<int>(_initialIndex);
    _lastHapticIndex = _initialIndex;

    _scrollController = FixedExtentScrollController(
      initialItem: _initialIndex,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _centeredIndexNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSelectedItemChanged(int index) {
    if (index != _lastHapticIndex) {
      _lastHapticIndex = index;
      // High-tactility impact that feels crisp, physical, and premium
      HapticFeedback.lightImpact();
    }
    _centeredIndexNotifier.value = index;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _commitSelection(index);
    });
  }

  void _commitSelection(int index) {
    if (index >= 0 && index < _dates.length) {
      widget.onDateSelected(_dates[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];

    final now = DateTime.now();
    final today = TimelineUtils.dateOnly(now);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: _popoverWidth,
        height: _popoverHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_outerR),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
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
                // Frosted glass background fill
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_outerR),
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ),

                // Centered glass selection lens indicator
                Positioned(
                  top: (_popoverHeight - _itemExtent) / 2 + 2,
                  left: 10,
                  right: 10,
                  height: _itemExtent - 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.95),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                // Smooth snapping wheel with edge gradient mask
                NotificationListener<ScrollEndNotification>(
                  onNotification: (notif) {
                    _commitSelection(_centeredIndexNotifier.value);
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
                    child: ListWheelScrollView.useDelegate(
                      controller: _scrollController,
                      itemExtent: _itemExtent,
                      physics: const BouncingScrollPhysics(
                        parent: FixedExtentScrollPhysics(),
                      ),
                      perspective: 0.0025,
                      diameterRatio: 1.35,
                      squeeze: 1.08,
                      useMagnifier: true,
                      magnification: 1.12,
                      onSelectedItemChanged: _onSelectedItemChanged,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _dates.length,
                        builder: (context, index) {
                          final date = _dates[index];
                          final isToday = DateUtils.isSameDay(date, today);

                          final weekdayStr =
                              weekdays[(date.weekday - 1).clamp(0, 6)];
                          final monthStr = months[(date.month - 1).clamp(0, 11)];

                          return ValueListenableBuilder<int>(
                            valueListenable: _centeredIndexNotifier,
                            builder: (context, centeredIndex, _) {
                              final isCentered = index == centeredIndex;
                              final distance = (index - centeredIndex).abs();

                              final double opacity = switch (distance) {
                                0 => 1.0,
                                1 => 0.45,
                                2 => 0.18,
                                _ => 0.06,
                              };

                              final double scale = switch (distance) {
                                0 => 1.0,
                                1 => 0.90,
                                _ => 0.80,
                              };

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (isCentered) {
                                    _commitSelection(index);
                                    widget.onClose();
                                  } else {
                                    _scrollController.animateToItem(
                                      index,
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                },
                                child: Transform.scale(
                                  scale: scale,
                                  child: Opacity(
                                    opacity: opacity,
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    weekdayStr,
                                                    style: TextStyle(
                                                      fontSize:
                                                          isCentered ? 11 : 10,
                                                      fontWeight: FontWeight.w900,
                                                      color: OptivusColors.ink,
                                                      letterSpacing: 0.6,
                                                      decoration:
                                                          TextDecoration.none,
                                                    ),
                                                  ),
                                                  if (isToday) ...[
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 4,
                                                        vertical: 1,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: OptivusColors
                                                            .routineAccent
                                                            .withValues(
                                                              alpha: 0.28,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                4),
                                                      ),
                                                      child: const Text(
                                                        'TODAY',
                                                        style: TextStyle(
                                                          fontSize: 7.5,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color:
                                                              OptivusColors.ink,
                                                          letterSpacing: 0.3,
                                                          decoration:
                                                              TextDecoration.none,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              Text(
                                                monthStr,
                                                style: TextStyle(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: OptivusColors.sub
                                                      .withValues(alpha: 0.85),
                                                  letterSpacing: 0.4,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${date.day}',
                                            style: TextStyle(
                                              fontSize: isCentered ? 21 : 16,
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
                        },
                      ),
                    ),
                  ),
                ),

                // Glass highlight rim painter
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
}
