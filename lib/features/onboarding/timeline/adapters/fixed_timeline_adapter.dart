import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import '../../../../models/onboarding_draft.dart';
import '../../../routine/utils/timeline_utils.dart';
import '../models/timeline_entry.dart';
import '../models/timeline_style.dart';
import '../widgets/timeline_edit_sheet_shell.dart';
import 'timeline_feature_adapter.dart';

/// Feature adapter for Fixed schedule items (Sleep, Bath, non-negotiable blocks).
///
/// Implements cross-midnight segment splitting so that [TimelineOverlapEngine]
/// only ever receives valid day-bounded entries (`0 <= startMinute < endMinute <= 1440`).
class FixedTimelineAdapter
    implements TimelineFeatureAdapter<TimelineBlockDraft> {
  final Color accent;

  const FixedTimelineAdapter({this.accent = OptivusColors.purpleAccent});

  @override
  List<TimelineEntry> toEntries(TimelineBlockDraft block) {
    // Normal non-overnight block
    if (block.startMinute < block.endMinute && !block.crossesMidnight) {
      return [
        TimelineEntry(
          id: block.id,
          sourceId: block.id,
          startMinute: block.startMinute,
          endMinute: block.endMinute,
          repeatDays: block.repeatDays,
          title: block.title,
          subtitle: block.location,
          category: TimelineCategory.fixed,
          isEditable: true,
          adapterKey: 'fixed',
        ),
      ];
    }

    // Cross-midnight block (e.g. 23:00 to 07:00 / 1380 to 420)
    final entries = <TimelineEntry>[];
    final days = block.repeatDays.isEmpty
        ? const [1, 2, 3, 4, 5, 6, 7]
        : block.repeatDays;

    for (final day in days) {
      // Night segment: startMinute -> 24:00 (1440) on Day `day`
      if (block.startMinute < 1440) {
        entries.add(
          TimelineEntry(
            id: '${block.id}_night_$day',
            sourceId: block.id,
            startMinute: block.startMinute,
            endMinute: 1440,
            repeatDays: [day],
            specificDay: day,
            title: block.title,
            subtitle: block.location,
            category: TimelineCategory.fixed,
            isEditable: true,
            adapterKey: 'fixed',
          ),
        );
      }

      // Morning segment: 00:00 -> endMinute on Day `nextDay`
      final nextDay = (day % 7) + 1;
      if (block.endMinute > 0) {
        entries.add(
          TimelineEntry(
            id: '${block.id}_morning_$nextDay',
            sourceId: block.id,
            startMinute: 0,
            endMinute: block.endMinute,
            repeatDays: [nextDay],
            specificDay: nextDay,
            title: block.title,
            subtitle: block.location,
            category: TimelineCategory.fixed,
            isEditable: true,
            adapterKey: 'fixed',
          ),
        );
      }
    }

    return entries;
  }

  @override
  TimelineEntryStyle styleForEntry(TimelineEntry entry) {
    final isSleep = entry.title.toLowerCase().contains('sleep');
    final isBath = entry.title.toLowerCase().contains('bath');

    return TimelineEntryStyle(
      accentColor: accent,
      icon: isSleep
          ? Icons.bedtime_rounded
          : isBath
          ? Icons.bathtub_rounded
          : Icons.event_rounded,
      badgeLabel: 'Fixed',
      tags: entry.subtitle != null ? [entry.subtitle!] : const [],
    );
  }

  @override
  Future<void> onEditRequested(
    BuildContext context,
    TimelineEntry entry,
    VoidCallback onUpdated,
  ) async {}

  /// Opens the shared edit sheet for a fixed block.
  static Future<bool?> showFixedEditSheet({
    required BuildContext context,
    required TimelineBlockDraft block,
    required Future<bool> Function(TimelineBlockDraft updated) onSave,
    Color accent = OptivusColors.purpleAccent,
  }) {
    final titleCtrl = TextEditingController(text: block.title);
    var startMinute = block.startMinute;
    var endMinute = block.endMinute;
    var crossesMidnight = block.crossesMidnight || startMinute > endMinute;
    final selectedDays = Set<int>.from(
      block.repeatDays.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : block.repeatDays,
    );
    final formKey = GlobalKey<FormState>();

    return TimelineEditSheetShell.show<bool>(
      context: context,
      title: 'Edit Fixed Block',
      subtitle: 'Set block name, time, and days',
      accent: accent,
      onSave: () async {
        if (!formKey.currentState!.validate()) return false;
        final title = titleCtrl.text.trim();
        if (title.isEmpty) {
          throw Exception('Title is required.');
        }
        if (!crossesMidnight && endMinute <= startMinute) {
          throw Exception('End time must be after start time.');
        }
        if (selectedDays.isEmpty) {
          throw Exception('Select at least one day.');
        }

        final updated = block.copyWith(
          title: title,
          startMinute: startMinute,
          endMinute: endMinute,
          repeatDays: selectedDays.toList()..sort(),
          crossesMidnight: crossesMidnight,
        );

        return await onSave(updated);
      },
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'BLOCK NAME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('timeline-edit-fixed-title-field'),
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Sleep / Bath',
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

                  // Time Range Pickers
                  const Text(
                    'TIME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key(
                            'timeline-edit-fixed-start-time-picker',
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: startMinute ~/ 60,
                                minute: startMinute % 60,
                              ),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                startMinute = picked.hour * 60 + picked.minute;
                                crossesMidnight = startMinute > endMinute;
                              });
                            }
                          },
                          child: Text(
                            'Start: ${TimelineUtils.formatMinute(startMinute)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('timeline-edit-fixed-end-time-picker'),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: endMinute ~/ 60,
                                minute: endMinute % 60,
                              ),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                endMinute = picked.hour * 60 + picked.minute;
                                crossesMidnight = startMinute > endMinute;
                              });
                            }
                          },
                          child: Text(
                            'End: ${TimelineUtils.formatMinute(endMinute)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Repeat Days
                  const Text(
                    'REPEAT DAYS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(7, (index) {
                      final day = index + 1;
                      final dayName = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ][index];
                      final isSelected = selectedDays.contains(day);
                      return FilterChip(
                        label: Text(dayName),
                        selected: isSelected,
                        selectedColor: accent.withValues(alpha: 0.25),
                        onSelected: (selected) {
                          setSheetState(() {
                            if (selected) {
                              selectedDays.add(day);
                            } else if (selectedDays.length > 1) {
                              selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
