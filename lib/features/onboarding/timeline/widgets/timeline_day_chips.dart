import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';

/// Standard weekday names in canonical 1-indexed order (1 = Monday, 7 = Sunday).
const List<String> kTimelineWeekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Shared day chips widget for timeline views.
///
/// Weekdays are consistently 1-indexed (1 = Monday, 7 = Sunday).
class TimelineDayChips extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final Color accent;
  final EdgeInsetsGeometry padding;

  const TimelineDayChips({
    super.key,
    required this.selectedDay,
    required this.onDayChanged,
    this.accent = OptivusColors.brandAccent,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - padding.horizontal;
        // If screen is wide enough, spread evenly; otherwise allow horizontal scroll
        final useExpanded = availableWidth >= 280;

        final row = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final dayNumber = index + 1;
            final dayName = kTimelineWeekdays[index];
            final isSelected = selectedDay == dayNumber;

            final chip = _DayChipItem(
              dayNumber: dayNumber,
              label: dayName,
              isSelected: isSelected,
              accent: accent,
              onTap: () => onDayChanged(dayNumber),
            );

            return useExpanded
                ? Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index < 6 ? 4.0 : 0.0),
                      child: chip,
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.only(right: index < 6 ? 6.0 : 0.0),
                    child: chip,
                  );
          }),
        );

        return Padding(
          padding: padding,
          child: useExpanded
              ? row
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: row,
                ),
        );
      },
    );
  }
}

class _DayChipItem extends StatelessWidget {
  final int dayNumber;
  final String label;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  const _DayChipItem({
    required this.dayNumber,
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fullDayName = switch (dayNumber) {
      1 => 'Monday',
      2 => 'Tuesday',
      3 => 'Wednesday',
      4 => 'Thursday',
      5 => 'Friday',
      6 => 'Saturday',
      _ => 'Sunday',
    };

    return Semantics(
      excludeSemantics: true,
      button: true,
      selected: isSelected,
      label: fullDayName,
      hint: isSelected
          ? 'Currently selected'
          : 'Double tap to select $fullDayName schedule',
      onTap: onTap,
      child: GestureDetector(
        key: ValueKey('timeline-day-chip-$dayNumber'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? accent : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accent : Colors.white.withValues(alpha: 0.65),
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : OptivusColors.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Opacity(opacity: 0, child: Text(label)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
