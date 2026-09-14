import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/widgets/routine_glass_filter.dart'; // For GlassHighlightPainter
import 'package:optivus/features/routine/widgets/routine_day_picker.dart';
import 'package:optivus/features/routine/sheets/week_planner_sheet.dart';
import 'package:optivus/features/routine/sheets/routine_filter_sheet.dart';

/// Filter row for Routine.
///
/// Contains [Day], [Week], and compact [Filter] controls.
/// Tapping [Filter] opens the authoritative filter bottom sheet.
class RoutineTitleFilterRow extends ConsumerWidget {
  const RoutineTitleFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      routineNotifierProvider.select(
        (s) => (
          primary: s.selectedPrimaryFilter,
          status: s.selectedStatusFilter,
          category: s.selectedCategoryFilter,
        ),
      ),
    );

    int activeCount = 0;
    if (state.primary != 'all') activeCount++;
    if (state.status != 'any') activeCount++;
    if (state.category != 'all') activeCount++;

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
            child: GestureDetector(
              onTap: () => showRoutineFilterSheet(context, ref),
              child: _RoutineGlassPill(
                label: pillLabel,
                isActive: activeCount > 0,
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
  final bool isActive;

  const _RoutineGlassPill({required this.label, this.isActive = false});

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
                      Icon(
                        Icons.tune_rounded,
                        size: 15,
                        color: isActive
                            ? OptivusColors.routineAccent
                            : OptivusColors.routineInkDark,
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
