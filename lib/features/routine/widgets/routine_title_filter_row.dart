import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_entry_filter.dart';
import 'package:optivus/features/routine/sheets/week_planner_sheet.dart';
import 'package:optivus/features/routine/widgets/routine_day_picker.dart';
import 'package:optivus/features/routine/widgets/routine_glass_highlight_painter.dart';

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
  late final Animation<double> _fade;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _closeDropdown(immediate: true);
    _anim.dispose();
    super.dispose();
  }

  void _openDropdown() {
    if (_overlay != null) return;

    _overlay = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeDropdown,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Material(
                type: MaterialType.transparency,
                child: ScaleTransition(
                  scale: _fade,
                  alignment: Alignment.topRight,
                  child: FadeTransition(
                    opacity: _fade,
                    child: _RoutineGlassDropdownContent(
                      onClose: _closeDropdown,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlay!);
    _anim.forward();
    if (mounted) setState(() {});
  }

  void _closeDropdown({bool immediate = false}) async {
    if (_overlay == null) return;
    if (immediate || !mounted) {
      _overlay?.remove();
      _overlay = null;
      return;
    }
    if (_isClosing) return;
    _isClosing = true;
    try {
      await _anim.reverse();
    } finally {
      _isClosing = false;
      _overlay?.remove();
      _overlay = null;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterSelection = ref.watch(
      routineNotifierProvider.select((s) => s.filterSelection),
    );
    final activeCount = filterSelection.activeCount;
    final pillLabel = activeCount == 0 ? 'Filter' : 'Filter • $activeCount';

    return Padding(
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
            child: CompositedTransformTarget(
              link: _link,
              child: GestureDetector(
                onTap: () {
                  if (_overlay == null) {
                    _openDropdown();
                  } else {
                    _closeDropdown();
                  }
                },
                child: _RoutineGlassPill(
                  label: pillLabel,
                  isActive: activeCount > 0,
                  isOpen: _overlay != null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineGlassDropdownContent extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const _RoutineGlassDropdownContent({required this.onClose});

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
    final width = (screenSize.width - 32).clamp(240.0, 280.0);
    final maxHeight = screenSize.height * 0.62;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 1.0,
                ),
              ),
              child: SingleChildScrollView(
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
                          color: OptivusColors.ink.withValues(alpha: 0.45),
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
                            filterSelection.selectedPrimaryFilter == opt.key,
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
                            filterSelection.selectedStatusFilter == opt.key,
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
                    for (final opt in displayedCategories)
                      _buildOptionRow(
                        label: opt.label,
                        isSelected: selectedCat == opt.key,
                        onTap: () {
                          ref
                              .read(routineNotifierProvider.notifier)
                              .setCategoryFilter(opt.key);
                        },
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
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: OptivusColors.routineAccent,
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
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          child: Text(
                            'Reset filters',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: OptivusColors.routineAccent,
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
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: OptivusColors.ink.withValues(alpha: 0.45),
          letterSpacing: 0.5,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 12,
      thickness: 0.5,
      color: OptivusColors.ink.withValues(alpha: 0.08),
      indent: 14,
      endIndent: 14,
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
        color: isSelected
            ? OptivusColors.routineAccent.withValues(alpha: 0.12)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? OptivusColors.routineAccent
                      : OptivusColors.ink.withValues(alpha: 0.85),
                  letterSpacing: -0.1,
                  height: 1.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: OptivusColors.routineAccent,
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
  final bool isOpen;

  const _RoutineGlassPill({
    required this.label,
    this.isActive = false,
    this.isOpen = false,
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
                    color: isActive
                        ? OptivusColors.routineAccent.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(innerR),
                    border: Border.all(
                      color: isActive
                          ? OptivusColors.routineAccent.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.6),
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
                                  : FontWeight.w600,
                              color: isActive
                                  ? OptivusColors.routineAccent
                                  : OptivusColors.routineInkDark,
                              letterSpacing: -0.2,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: isOpen ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: isActive
                              ? OptivusColors.routineAccent
                              : OptivusColors.routineInkDark,
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
