import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_style.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_edit_sheet_shell.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_timeline_card.dart';
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
      minHeight: WorkTimelineCard.minimumHeight(block),
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
    Future<bool> Function(TimelineBlockDraft toDelete)? onDelete,
    Color accent = OptivusColors.warning,
  }) {
    final title = TextEditingController(text: block.title);
    final location = TextEditingController(text: block.location ?? '');
    final sectionLabel = TextEditingController(text: block.sectionLabel ?? '');
    final notes = TextEditingController(text: block.notes ?? '');
    var startMinute = block.startMinute;
    var endMinute = block.endMinute;
    final days = <int>{
      ...block.repeatDays.where((day) => day >= 1 && day <= 7),
    };

    return TimelineEditSheetShell.show<bool>(
      context: context,
      title: block.title.trim().isEmpty ? 'Add Work Block' : 'Edit Work Block',
      subtitle: 'Role, workplace, time and working days',
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
            sectionLabel: sectionLabel.text.trim(),
            notes: notes.text.trim(),
            startMinute: startMinute,
            endMinute: endMinute,
            repeatDays: days.toList()..sort(),
          ),
        );
      },
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isNarrow =
              MediaQuery.sizeOf(context).width < 360 ||
              MediaQuery.textScalerOf(context).scale(14) > 17;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ROLE / TITLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textSecondary,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('base-work-title-field'),
                controller: title,
                decoration: InputDecoration(
                  hintText: 'e.g. Software Engineer, Shift Lead',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: accent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'TIME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textSecondary,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 6),
              if (!isNarrow)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('base-work-start-time-picker'),
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
                              () => startMinute =
                                  picked.hour * 60 + picked.minute,
                            );
                          }
                        },
                        child: Text(
                          'Start: ${TimelineUtils.formatMinute(startMinute)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('base-work-end-time-picker'),
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
                              () =>
                                  endMinute = picked.hour * 60 + picked.minute,
                            );
                          }
                        },
                        child: Text(
                          'End: ${TimelineUtils.formatMinute(endMinute)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      key: const ValueKey('base-work-start-time-picker'),
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
                            () =>
                                startMinute = picked.hour * 60 + picked.minute,
                          );
                        }
                      },
                      child: Text(
                        'Start: ${TimelineUtils.formatMinute(startMinute)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const ValueKey('base-work-end-time-picker'),
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
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              if (endMinute <= startMinute)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'End time must be after start time.',
                    style: TextStyle(
                      color: OptivusColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                      if (selected) {
                        days.add(day);
                      } else if (days.length > 1) {
                        days.remove(day);
                      }
                    }),
                  );
                }),
              ),
              const SizedBox(height: 18),
              const Text(
                'WORK DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textSecondary,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('base-work-location-field'),
                controller: location,
                decoration: InputDecoration(
                  labelText: 'Workplace / location',
                  hintText: 'e.g. Office · Building 4, Remote, Studio',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: accent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('base-work-section-field'),
                controller: sectionLabel,
                decoration: InputDecoration(
                  labelText: 'Business / department (optional)',
                  hintText: 'e.g. Engineering, Client Consulting',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: accent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('base-work-notes-field'),
                controller: notes,
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Notes / details',
                  hintText: 'e.g. Team standup at 10 AM, client calls...',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: accent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(height: 24),
                const Divider(color: OptivusColors.borderStandard, height: 1),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('base-work-delete-button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OptivusColors.danger,
                      side: BorderSide(
                        color: OptivusColors.danger.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text(
                      'Remove work block',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: OptivusColors.backgroundBottom,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text(
                            'Remove this work block?',
                            style: TextStyle(
                              color: OptivusColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          content: const Text(
                            "This only changes the schedule you're reviewing.\nYour live Base Timeline is unchanged until you save.",
                            style: TextStyle(
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              key: const ValueKey(
                                'base-work-confirm-delete-button',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: OptivusColors.danger,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        final ok = await onDelete(block);
                        if (ok && context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      }
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
