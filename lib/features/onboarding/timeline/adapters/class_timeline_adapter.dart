import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import '../../../routine/utils/timeline_utils.dart';
import '../../steps/onboarding_step_4_schedule_models.dart';
import '../models/timeline_entry.dart';
import '../models/timeline_style.dart';
import '../widgets/timeline_edit_sheet_shell.dart';
import 'timeline_feature_adapter.dart';

/// Feature adapter for Class schedule items.
class ClassTimelineAdapter
    implements TimelineFeatureAdapter<ClassRoutineBlock> {
  final Color accent;

  const ClassTimelineAdapter({this.accent = OptivusColors.aquaAccent});

  /// Translates [ClassRoutineBlock] into neutral [TimelineEntry].
  @override
  List<TimelineEntry> toEntries(ClassRoutineBlock block) {
    return [
      TimelineEntry(
        id: block.id,
        sourceId: block.id,
        startMinute: block.startMinute,
        endMinute: block.endMinute,
        repeatDays: block.repeatDays,
        title: block.subject,
        subtitle: block.room.isNotEmpty ? block.room : null,
        category: TimelineCategory.classes,
        isEditable: true,
        adapterKey: 'classes',
      ),
    ];
  }

  @override
  TimelineEntryStyle styleForEntry(TimelineEntry entry) {
    return TimelineEntryStyle(
      accentColor: accent,
      icon: Icons.school_rounded,
      badgeLabel: 'Class',
      tags: entry.subtitle != null && entry.subtitle!.isNotEmpty
          ? [entry.subtitle!]
          : const [],
    );
  }

  @override
  Future<void> onEditRequested(
    BuildContext context,
    TimelineEntry entry,
    VoidCallback onUpdated,
  ) async {
    // Feature edit handler can be overridden or called via showClassEditSheet
  }

  /// Opens the shared edit sheet for a class routine block.
  static Future<bool?> showClassEditSheet({
    required BuildContext context,
    required ClassRoutineBlock block,
    required Future<bool> Function(ClassRoutineBlock updated) onSave,
    Color accent = OptivusColors.aquaAccent,
  }) {
    final titleCtrl = TextEditingController(text: block.subject);
    final roomCtrl = TextEditingController(text: block.room);
    var startMinute = block.startMinute;
    var endMinute = block.endMinute;
    final selectedDays = Set<int>.from(
      block.repeatDays.isEmpty ? [1] : block.repeatDays,
    );
    final formKey = GlobalKey<FormState>();

    return TimelineEditSheetShell.show<bool>(
      context: context,
      title: 'Edit Class',
      subtitle: 'Set subject name, room, time, and days',
      accent: accent,
      onSave: () async {
        if (!formKey.currentState!.validate()) return false;
        final title = titleCtrl.text.trim();
        if (title.isEmpty) {
          throw Exception('Subject name is required.');
        }
        if (endMinute <= startMinute) {
          throw Exception('End time must be after start time.');
        }
        if (selectedDays.isEmpty) {
          throw Exception('Select at least one day.');
        }

        final updated = block.copyWith(
          subject: title,
          room: roomCtrl.text.trim(),
          startMinute: startMinute,
          endMinute: endMinute,
          repeatDays: selectedDays.toList()..sort(),
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
                  // Subject Name
                  const Text(
                    'SUBJECT NAME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('timeline-edit-subject-field'),
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Data Structures',
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

                  // Room / Location
                  const Text(
                    'ROOM / LOCATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('timeline-edit-room-field'),
                    controller: roomCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Hall B-12 (optional)',
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
                          key: const Key('timeline-edit-start-time-picker'),
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
                          key: const Key('timeline-edit-end-time-picker'),
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

                  // Repeat Days Selector
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
