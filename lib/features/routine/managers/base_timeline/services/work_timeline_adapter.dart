import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_style.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_edit_sheet_shell.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Base Timeline Work adapter. Unlike the onboarding adapter, this operates on
/// the canonical typed draft and therefore preserves provenance and every
/// unexposed field during edits.
class BaseTimelineWorkAdapter {
  final Color accent;

  const BaseTimelineWorkAdapter({this.accent = OptivusColors.warning});

  List<TimelineEntry> toEntries(TimelineBlockDraft block) => [
    TimelineEntry(
      id: block.id,
      sourceId: block.id,
      startMinute: block.startMinute,
      endMinute: block.endMinute,
      repeatDays: block.repeatDays,
      title: block.title,
      subtitle: block.location,
      category: TimelineCategory.work,
      isEditable: true,
      adapterKey: 'base_timeline_work',
      minHeight:
          94 +
          (block.location?.trim().isNotEmpty == true ? 18 : 0) +
          (block.notes?.trim().isNotEmpty == true ? 34 : 0),
    ),
  ];

  TimelineEntryStyle styleForEntry(TimelineEntry entry) => TimelineEntryStyle(
    accentColor: accent,
    icon: Icons.work_rounded,
    badgeLabel: 'Work',
    tags: entry.subtitle?.trim().isNotEmpty == true
        ? [entry.subtitle!.trim()]
        : const [],
  );

  static Future<bool?> showEditSheet({
    required BuildContext context,
    required TimelineBlockDraft block,
    required Future<bool> Function(TimelineBlockDraft updated) onSave,
    Color accent = OptivusColors.warning,
  }) {
    final title = TextEditingController(text: block.title);
    final location = TextEditingController(text: block.location ?? '');
    final notes = TextEditingController(text: block.notes ?? '');
    var startMinute = block.startMinute;
    var endMinute = block.endMinute;
    final days = <int>{
      ...block.repeatDays.where((day) => day >= 1 && day <= 7),
    };

    return TimelineEditSheetShell.show<bool>(
      context: context,
      title: block.title.trim().isEmpty ? 'Add Work Block' : 'Edit Work Block',
      subtitle: 'Set role, workplace, details, time, and repeat days',
      accent: accent,
      onSave: () async {
        if (title.text.trim().isEmpty) {
          throw Exception('Role or title is required.');
        }
        if (endMinute <= startMinute) {
          throw Exception('End time must be after start time.');
        }
        if (days.isEmpty) throw Exception('Select at least one repeat day.');
        return onSave(
          block.copyWith(
            title: title.text.trim(),
            location: location.text.trim(),
            notes: notes.text.trim(),
            startMinute: startMinute,
            endMinute: endMinute,
            repeatDays: days.toList()..sort(),
          ),
        );
      },
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('base-work-title-field'),
              controller: title,
              decoration: const InputDecoration(labelText: 'Role / title'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('base-work-location-field'),
              controller: location,
              decoration: const InputDecoration(
                labelText: 'Workplace / location',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('base-work-notes-field'),
              controller: notes,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Notes / details'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: startMinute ~/ 60,
                          minute: startMinute % 60,
                        ),
                      );
                      if (picked != null) {
                        setSheetState(
                          () => startMinute = picked.hour * 60 + picked.minute,
                        );
                      }
                    },
                    child: Text(
                      'Start: ${TimelineUtils.formatMinute(startMinute)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: endMinute ~/ 60,
                          minute: endMinute % 60,
                        ),
                      );
                      if (picked != null) {
                        setSheetState(
                          () => endMinute = picked.hour * 60 + picked.minute,
                        );
                      }
                    },
                    child: Text(
                      'End: ${TimelineUtils.formatMinute(endMinute)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'REPEAT DAYS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(7, (index) {
                final day = index + 1;
                return FilterChip(
                  label: Text(
                    const [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ][index],
                  ),
                  selected: days.contains(day),
                  selectedColor: accent.withValues(alpha: .25),
                  onSelected: (selected) => setSheetState(() {
                    selected ? days.add(day) : days.remove(day);
                  }),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
