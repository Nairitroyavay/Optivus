import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';

/// Routine header: date label (left) + AI / Add / Settings actions (right).
///
/// Matches old Optivus routine_tab.dart header exactly.
class RoutineHeader extends ConsumerWidget {
  final VoidCallback onAITap;
  final VoidCallback onAddTap;
  final VoidCallback onSettingsTap;

  const RoutineHeader({
    super.key,
    required this.onAITap,
    required this.onAddTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(routineNotifierProvider).selectedDay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Date label ──
          Expanded(
            child: SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  _formatDate(selectedDay).toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.ink.withValues(alpha: 0.8),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Action buttons ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderActionButton(
                icon: Icons.hub_rounded,
                label: 'AI',
                color: OptivusColors.headerAI,
                onTap: onAITap,
              ),
              const SizedBox(width: 10),
              _HeaderActionButton(
                icon: Icons.add_rounded,
                label: 'Add',
                color: OptivusColors.headerAdd,
                onTap: onAddTap,
              ),
              const SizedBox(width: 8),
              _SettingsPill(onTap: onSettingsTap),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final isToday = TimelineUtils.isToday(date);
    final isTomorrow = TimelineUtils.isTomorrow(date);

    const daysStr = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const mos = [
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

    final dayStr = daysStr[date.weekday - 1];
    final moStr = mos[date.month - 1];
    final dateStr = '$dayStr, $moStr ${date.day}, ${date.year}';

    if (isToday) return 'TODAY: $dateStr';
    if (isTomorrow) return 'TOMORROW: $dateStr';
    return dateStr;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeaderActionButton — FilledButton.icon matching old Optivus exactly
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withValues(alpha: 0.25),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.60),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            // Specular gloss at top-left
            Positioned(
              top: 0,
              left: -4,
              child: Container(
                width: 24,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: OptivusColors.routineIconDark),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.routineIconDark,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsPill — transparent liquid-drop glass bubble (36×36 circle)
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SettingsPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.60),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Specular gloss at top-left
            Positioned(
              top: 4,
              left: 6,
              child: Container(
                width: 16,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
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
            const Center(
              child: Icon(
                Icons.settings_rounded,
                size: 17,
                color: OptivusColors.routineTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
