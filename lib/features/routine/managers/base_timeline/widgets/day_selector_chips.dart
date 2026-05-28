import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class DaySelectorChips extends StatelessWidget {
  final List<int> selectedDays;
  final ValueChanged<List<int>> onChanged;

  const DaySelectorChips({
    super.key,
    required this.selectedDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const days = [
      {'label': 'M', 'value': 1},
      {'label': 'T', 'value': 2},
      {'label': 'W', 'value': 3},
      {'label': 'T', 'value': 4},
      {'label': 'F', 'value': 5},
      {'label': 'S', 'value': 6},
      {'label': 'S', 'value': 7},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((day) {
        final value = day['value'] as int;
        final isSelected = selectedDays.contains(value);

        return GestureDetector(
          onTap: () {
            final newSelection = List<int>.from(selectedDays);
            if (isSelected) {
              newSelection.remove(value);
            } else {
              newSelection.add(value);
              newSelection.sort();
            }
            onChanged(newSelection);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? OptivusColors.routineAccent : Colors.transparent,
              border: Border.all(
                color: isSelected ? OptivusColors.routineAccent : OptivusColors.textMuted.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              day['label'] as String,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : OptivusColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
