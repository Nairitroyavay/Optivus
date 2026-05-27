import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/widgets/routine_glass_filter.dart'; // For GlassHighlightPainter
import 'package:optivus/features/routine/sheets/week_planner_sheet.dart';

/// Filter row for Routine.
///
/// Shows a single [Filter] glass pill that opens a beautiful glass overlay dropdown menu.
/// When filters are selected, it updates the pill text to reflect the selection.
class RoutineTitleFilterRow extends ConsumerStatefulWidget {
  const RoutineTitleFilterRow({super.key});

  @override
  ConsumerState<RoutineTitleFilterRow> createState() => _RoutineTitleFilterRowState();
}

class _RoutineTitleFilterRowState extends ConsumerState<RoutineTitleFilterRow>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  final LayerLink _link = LayerLink();
  final double _widgetWidth = 190.0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _closeDropdown(immediate: true);
    _anim.dispose();
    super.dispose();
  }

  void _openDropdown() {
    _overlay = OverlayEntry(
      builder: (_) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _closeDropdown,
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 8),
                child: ScaleTransition(
                  scale: _fade,
                  alignment: Alignment.topRight,
                  child: _buildGlassMenu(),
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

  void _closeDropdown({bool immediate = false}) async {
    if (_overlay == null) return;
    if (!immediate && mounted) {
      await _anim.reverse();
    }
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildGlassMenu() {
    const double outerR = 22.0;
    const double rim = 8.0;
    const double innerR = outerR - rim + 2;

    final filter = ref.watch(routineFilterProvider);
    final categoryFilter = ref.watch(selectedCategoryFilterProvider);

    final List<Widget> rows = [];
    
    // View section header
    rows.add(_buildSectionHeader('View'));
    for (int i = 0; i < primaryFilters.length; i++) {
      final f = primaryFilters[i];
      rows.add(_buildOptionRow(
        f: f,
        isSelected: filter == f.key,
        onTap: () {
          ref.read(routineFilterProvider.notifier).state = f.key;
        },
      ));
    }

    // Category section header
    rows.add(const SizedBox(height: 8));
    rows.add(_buildDivider());
    rows.add(_buildSectionHeader('Category'));
    for (int i = 0; i < categoryFilters.length; i++) {
      final f = categoryFilters[i];
      rows.add(_buildOptionRow(
        f: f,
        isSelected: categoryFilter == f.key,
        onTap: () {
          ref.read(selectedCategoryFilterProvider.notifier).state = f.key;
        },
      ));
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: _widgetWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerR),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(outerR),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                // Scrollable content
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: rows,
                    ),
                  ),
                ),
                // Transparent tint overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(outerR),
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ),
                // Glass rim highlights
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
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: OptivusColors.ink.withValues(alpha: 0.5),
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      color: Colors.white.withValues(alpha: 0.30),
      indent: 14,
      endIndent: 14,
    );
  }

  Widget _buildOptionRow({
    required RoutineFilterOption f,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: isSelected ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Text(
              f.emoji,
              style: const TextStyle(fontSize: 15, decoration: TextDecoration.none),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                f.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: OptivusColors.ink.withValues(alpha: isSelected ? 1.0 : 0.80),
                  letterSpacing: -0.1,
                  height: 1.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                size: 14,
                color: OptivusColors.ink.withValues(alpha: 0.85),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(routineFilterProvider);
    final categoryFilter = ref.watch(selectedCategoryFilterProvider);

    final activeFilters = <RoutineFilterOption>[];
    if (filter != 'all') {
      activeFilters.add(primaryFilters.firstWhere(
        (f) => f.key == filter,
        orElse: () => primaryFilters.first,
      ));
    }
    if (categoryFilter != 'all') {
      activeFilters.add(categoryFilters.firstWhere(
        (f) => f.key == categoryFilter,
        orElse: () => categoryFilters.first,
      ));
    }

    String pillLabel = 'Filter';
    if (activeFilters.length == 1) {
      pillLabel = activeFilters.first.label;
    } else if (activeFilters.length == 2) {
      pillLabel = '${activeFilters[0].label} • ${activeFilters[1].label}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
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
          const SizedBox(width: 10),
          CompositedTransformTarget(
            link: _link,
            child: GestureDetector(
              onTap: () => _overlay == null ? _openDropdown() : _closeDropdown(),
              child: _RoutineGlassPill(
                label: pillLabel,
                width: _widgetWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineGlassPill extends StatelessWidget {
  final String label;
  final double width;

  const _RoutineGlassPill({required this.label, required this.width});

  static const double outerR = 20.0;
  static const double rim = 7.0;
  static const double innerR = outerR - rim + 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1C1C2E),
                              letterSpacing: -0.2,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xFF1C1C2E),
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
