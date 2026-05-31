import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class TimeRangePickerRow extends StatelessWidget {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final ValueChanged<TimeOfDay> onEndTimeChanged;

  const TimeRangePickerRow({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
  });

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initialTime,
    ValueChanged<TimeOfDay> onChanged,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: OptivusColors.routineAccent,
              onPrimary: Colors.white,
              onSurface: OptivusColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimeBox(
            label: 'Start Time',
            time: startTime,
            onTap: () => _pickTime(context, startTime, onStartTimeChanged),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _TimeBox(
            label: 'End Time',
            time: endTime,
            onTap: () => _pickTime(context, endTime, onEndTimeChanged),
          ),
        ),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeBox({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OptivusColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
