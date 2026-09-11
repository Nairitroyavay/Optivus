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
  final bool defaultEditable;

  const ClassTimelineAdapter({
    this.accent = OptivusColors.aquaAccent,
    this.defaultEditable = true,
  });

  /// Translates [ClassRoutineBlock] into neutral [TimelineEntry].
  @override
  List<TimelineEntry> toEntries(ClassRoutineBlock block, {bool? isEditable}) {
    final hasDetails =
        block.room.isNotEmpty ||
        block.professor.isNotEmpty ||
        block.courseCode.isNotEmpty ||
        block.classType.isNotEmpty;
    final hasRichDetails =
        (block.room.isNotEmpty && block.professor.isNotEmpty) ||
        ((block.courseCode.isNotEmpty || block.classType.isNotEmpty) &&
            (block.room.isNotEmpty || block.professor.isNotEmpty));
    final minHeight = hasRichDetails ? 96.0 : (hasDetails ? 76.0 : 60.0);

    String? subtitle;
    if (block.room.isNotEmpty) {
      subtitle = block.room;
    } else if (block.courseCode.isNotEmpty) {
      subtitle = block.courseCode;
    }

    return [
      TimelineEntry(
        id: block.id,
        sourceId: block.id,
        startMinute: block.startMinute,
        endMinute: block.endMinute,
        repeatDays: block.repeatDays,
        title: block.subject,
        subtitle: subtitle,
        category: TimelineCategory.classes,
        isEditable: isEditable ?? defaultEditable,
        adapterKey: 'classes',
        minHeight: minHeight,
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
    final courseCodeCtrl = TextEditingController(text: block.courseCode);
    final classTypeCtrl = TextEditingController(text: block.classType);
    final professorCtrl = TextEditingController(text: block.professor);
    final sectionCtrl = TextEditingController(text: block.section);
    final notesCtrl = TextEditingController(text: block.notes);
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
          courseCode: courseCodeCtrl.text.trim(),
          classType: classTypeCtrl.text.trim(),
          professor: professorCtrl.text.trim(),
          section: sectionCtrl.text.trim(),
          notes: notesCtrl.text.trim(),
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

                  const SizedBox(height: 14),

                  // Course Code & Class Type Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'COURSE CODE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: OptivusColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              key: const Key('timeline-edit-course-code-field'),
                              controller: courseCodeCtrl,
                              decoration: InputDecoration(
                                hintText: 'e.g. CS101',
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CLASS TYPE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: OptivusColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              key: const Key('timeline-edit-class-type-field'),
                              controller: classTypeCtrl,
                              decoration: InputDecoration(
                                hintText: 'e.g. Lecture / Lab',
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
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Room & Professor Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                hintText: 'e.g. Hall B-12',
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PROFESSOR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: OptivusColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              key: const Key('timeline-edit-professor-field'),
                              controller: professorCtrl,
                              decoration: InputDecoration(
                                hintText: 'e.g. Dr. Sharma',
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
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Section
                  const Text(
                    'SECTION (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('timeline-edit-section-field'),
                    controller: sectionCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Sec A',
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

                  const SizedBox(height: 14),

                  // Notes
                  const Text(
                    'NOTES (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('timeline-edit-notes-field'),
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Bring lab coat',
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
