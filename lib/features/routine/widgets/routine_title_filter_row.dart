import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_motion.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_entry_filter.dart';
import 'package:optivus/features/routine/sheets/week_planner_sheet.dart';
import 'package:optivus/features/routine/widgets/routine_day_picker.dart';
import 'package:optivus/features/routine/widgets/routine_glass_highlight_painter.dart';

enum _DropdownPhase { closed, opening, open, closing }

/// Filter row for Routine.
///
/// Contains [Day], [Week], and compact [Filter] controls.
/// Tapping [Filter] toggles an anchored glass dropdown attached to the pill.
class RoutineTitleFilterRow extends ConsumerStatefulWidget {
  const RoutineTitleFilterRow({super.key});

  @override
  ConsumerState<RoutineTitleFilterRow> createState() =>
      _RoutineTitleFilterRowState();
}

class _RoutineTitleFilterRowState extends ConsumerState<RoutineTitleFilterRow>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;
  late final AnimationController _anim;
  late final Animation<double> _curved;
  late final Animation<double> _chevronTurns;
  _DropdownPhase _phase = _DropdownPhase.closed;
  double? _pillWidth;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: OptivusMotion.fastDuration,
      reverseDuration: OptivusMotion.pressDuration,
    );
    _anim.addStatusListener(_handleAnimationStatus);

    _curved = CurvedAnimation(
      parent: _anim,
      curve: OptivusMotion.enterCurve,
      reverseCurve: OptivusMotion.exitCurve,
    );

    _chevronTurns = Tween<double>(begin: 0.0, end: 0.5).animate(_curved);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _phase == _DropdownPhase.opening) {
      _phase = _DropdownPhase.open;
    } else if (status == AnimationStatus.dismissed &&
        _phase == _DropdownPhase.closing) {
      _removeOverlaySynchronously();
      _phase = _DropdownPhase.closed;
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

  void _toggleDropdown() {
    switch (_phase) {
      case _DropdownPhase.closed:
        _openDropdown();
        break;
      case _DropdownPhase.closing:
        _openDropdown();
        break;
      case _DropdownPhase.opening:
      case _DropdownPhase.open:
        _closeDropdown();
        break;
    }
  }

  void _openDropdown() {
    if (_phase == _DropdownPhase.open || _phase == _DropdownPhase.opening) {
      return;
    }

    final isReduced = OptivusMotion.isReducedMotion(context);

    if (_phase == _DropdownPhase.closing) {
      _phase = _DropdownPhase.opening;
      if (isReduced) {
        _anim.value = 1.0;
        _phase = _DropdownPhase.open;
      } else {
        _anim.forward();
      }
      return;
    }

    if (_overlay != null) {
      return;
    }

    _overlay = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // 1. Full-screen scrim behind popup
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeDropdown,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            // 2. Trigger proxy over pill so tapping pill while overlay is active toggles cleanly
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleDropdown,
                child: SizedBox(width: _pillWidth ?? 120.0, height: 40.0),
              ),
            ),
            // 3. Anchored floating glass dropdown
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Material(
                type: MaterialType.transparency,
                child: _RoutineGlassDropdownContent(
                  width: _pillWidth ?? 200.0,
                  animation: _curved,
                  onClose: _closeDropdown,
                ),
              ),
            ),
          ],
        );
      },
    );

    _phase = _DropdownPhase.opening;
    Overlay.of(context).insert(_overlay!);

    if (isReduced) {
      _anim.value = 1.0;
      _phase = _DropdownPhase.open;
    } else {
      _anim.value = 0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _overlay == null || _phase != _DropdownPhase.opening) {
          return;
        }
        _anim.forward(from: 0.0);
      });
    }
  }

  void _closeDropdown({bool immediate = false}) {
    if (_phase == _DropdownPhase.closed && _overlay == null) return;

    if (immediate || !mounted) {
      _anim.stop();
      _removeOverlaySynchronously();
      _phase = _DropdownPhase.closed;
      return;
    }

    if (_phase == _DropdownPhase.closing) return;

    _phase = _DropdownPhase.closing;
    final isReduced = OptivusMotion.isReducedMotion(context);

    if (isReduced) {
      _anim.stop();
      _removeOverlaySynchronously();
      _anim.value = 0.0;
      _phase = _DropdownPhase.closed;
    } else {
      _anim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterSelection = ref.watch(
      routineNotifierProvider.select((s) => s.filterSelection),
    );
    final activeCount = filterSelection.activeCount;
    final pillLabel = activeCount == 0 ? 'Filter' : 'Filter • $activeCount';

    return PopScope(
      canPop: _phase == _DropdownPhase.closed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _phase != _DropdownPhase.closed) {
          _closeDropdown();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const RoutineDayPickerButton(),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => showRoutineWeekPlannerSheet(context, ref),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.78),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_view_week_rounded,
                      size: 16,
                      color: OptivusColors.ink,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Week',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OptivusColors.ink,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _pillWidth = constraints.maxWidth;
                  return CompositedTransformTarget(
                    link: _link,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleDropdown,
                      child: _RoutineGlassPill(
                        label: pillLabel,
                        isActive: activeCount > 0,
                        chevronTurns: _chevronTurns,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineGlassDropdownContent extends ConsumerStatefulWidget {
  final double width;
  final Animation<double> animation;
  final VoidCallback onClose;

  const _RoutineGlassDropdownContent({
    required this.width,
    required this.animation,
    required this.onClose,
  });

  @override
  ConsumerState<_RoutineGlassDropdownContent> createState() =>
      _RoutineGlassDropdownContentState();
}

class _RoutineGlassDropdownContentState
    extends ConsumerState<_RoutineGlassDropdownContent> {
  bool _categoriesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final filterSelection = ref.watch(
      routineNotifierProvider.select((s) => s.filterSelection),
    );
    final selectedDayEntries = ref.watch(selectedDayRoutineEntriesProvider);
    final availableCategories = RoutineEntryFilter.dynamicCategoryOptions(
      selectedDayEntries,
    );

    // If active selected category is past collapsed limit (5), auto-expand so it stays visible
    final selectedCat = filterSelection.selectedCategoryFilter;
    final selectedCatIndex = availableCategories.indexWhere(
      (c) => c.key == selectedCat,
    );
    final shouldAutoExpand = selectedCat != 'all' && selectedCatIndex >= 5;
    final isExpanded = _categoriesExpanded || shouldAutoExpand;

    final displayedCategories = isExpanded || availableCategories.length <= 5
        ? availableCategories
        : availableCategories.take(5).toList(growable: false);

    final hasMoreCategories = availableCategories.length > 5;

    final screenSize = MediaQuery.sizeOf(context);
    final width = widget.width.clamp(160.0, screenSize.width - 32);
    final maxHeight = screenSize.height * 0.62;

    const double outerR = 22.0;
    const double rim = 8.0;
    const double innerR = outerR - rim + 2;

    return SizedBox(
      width: width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(outerR),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(outerR),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  // 1. Transparent liquid glass tint base
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(outerR),
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                  ),
                  // 2. Animated lightweight foreground: Scrollable content (isolated from static glass layer)
                  AnimatedBuilder(
                    animation: widget.animation,
                    builder: (context, child) {
                      final progress = widget.animation.value;
                      final opacity = progress.clamp(0.0, 1.0);
                      final translateY = (1.0 - progress) * -4.0;

                      return Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, translateY),
                          child: child,
                        ),
                      );
                    },
                    child: RepaintBoundary(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                              child: Text(
                                'FILTER ROUTINE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: OptivusColors.ink.withValues(
                                    alpha: 0.45,
                                  ),
                                  letterSpacing: 0.8,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),

                            // VIEW Section
                            _buildSectionHeader('VIEW'),
                            for (final opt in primaryFilters)
                              _buildOptionRow(
                                label: opt.label,
                                isSelected:
                                    filterSelection.selectedPrimaryFilter ==
                                    opt.key,
                                onTap: () {
                                  ref
                                      .read(routineNotifierProvider.notifier)
                                      .setPrimaryFilter(opt.key);
                                },
                              ),

                            _buildDivider(),

                            // STATUS Section
                            _buildSectionHeader('STATUS'),
                            for (final opt in statusFilters)
                              _buildOptionRow(
                                label: opt.label,
                                isSelected:
                                    filterSelection.selectedStatusFilter ==
                                    opt.key,
                                onTap: () {
                                  ref
                                      .read(routineNotifierProvider.notifier)
                                      .setStatusFilter(opt.key);
                                },
                              ),

                            _buildDivider(),

                            // CATEGORY Section
                            _buildSectionHeader('CATEGORY'),
                            _buildOptionRow(
                              label: 'All Categories',
                              isSelected: selectedCat == 'all',
                              onTap: () {
                                ref
                                    .read(routineNotifierProvider.notifier)
                                    .setCategoryFilter('all');
                              },
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final opt in displayedCategories)
                                  _buildOptionRow(
                                    label: opt.label,
                                    isSelected: selectedCat == opt.key,
                                    onTap: () {
                                      ref
                                          .read(
                                            routineNotifierProvider.notifier,
                                          )
                                          .setCategoryFilter(opt.key);
                                    },
                                  ),
                              ],
                            ),

                            if (hasMoreCategories && !shouldAutoExpand)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    _categoriesExpanded = !_categoriesExpanded;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  child: Text(
                                    _categoriesExpanded
                                        ? 'Show less'
                                        : '+${availableCategories.length - 5} more',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: OptivusColors.ink.withValues(
                                        alpha: 0.70,
                                      ),
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),

                            // Reset Filters
                            if (filterSelection.activeCount > 0) ...[
                              _buildDivider(),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  ref
                                      .read(routineNotifierProvider.notifier)
                                      .resetFilters();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  child: Text(
                                    'Reset filters',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: OptivusColors.ink.withValues(
                                        alpha: 0.85,
                                      ),
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 3. Glass highlight overlay with glare and rainbow prism
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: GlassHighlightPainter(
                            outerR: outerR,
                            innerR: innerR,
                            rim: rim,
                          ),
                        ),
                      ),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 3),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: OptivusColors.ink.withValues(alpha: 0.45),
          letterSpacing: 0.6,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      height: 0.6,
      color: Colors.white.withValues(alpha: 0.30),
    );
  }

  Widget _buildOptionRow({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? OptivusColors.routineInkDark
                    : OptivusColors.ink.withValues(alpha: 0.78),
                decoration: TextDecoration.none,
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                size: 15,
                color: OptivusColors.routineInkDark,
              ),
          ],
        ),
      ),
    );
  }
}

class _RoutineGlassPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final Animation<double>? chevronTurns;

  const _RoutineGlassPill({
    required this.label,
    this.chevronTurns,
    this.isActive = false,
  });

  static const double outerR = 20.0;
  static const double rim = 7.0;
  static const double innerR = outerR - rim + 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerR),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(rim),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(innerR),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: OptivusColors.routineInkDark,
                              letterSpacing: -0.2,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      RepaintBoundary(
                        child: RotationTransition(
                          turns:
                              chevronTurns ??
                              const AlwaysStoppedAnimation<double>(0.0),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: OptivusColors.routineInkDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GlassHighlightPainter(
                      outerR: outerR,
                      innerR: innerR,
                      rim: rim,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
