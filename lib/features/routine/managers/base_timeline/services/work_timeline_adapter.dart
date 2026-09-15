import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_style.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_edit_sheet_shell.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_timeline_card.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Helper for Work schedule block layout and card width calculation.
class WorkTimelineLayoutHelper {
  const WorkTimelineLayoutHelper._();

  /// Calculates effective front card width given container width and overlap status
  /// matching [TimelineOverlapPresentation.frontAndExposed] geometry.
  static double effectiveCardWidth({
    required double availableWidth,
    bool hasOverlap = false,
    double leftOffset = 62.0,
    double rightPadding = 16.0,
  }) {
    final usableWidth = (availableWidth - leftOffset - rightPadding).clamp(
      60.0,
      double.infinity,
    );
    if (!hasOverlap) {
      return usableWidth;
    }
    const minFrontWidth = 140.0;
    const minLabelWidth = 60.0;
    const maxLabelWidth = 76.0;

    final double exposedLabelWidth;
    if (usableWidth >= minFrontWidth + maxLabelWidth) {
      exposedLabelWidth = maxLabelWidth;
    } else if (usableWidth > minFrontWidth) {
      exposedLabelWidth = (usableWidth - minFrontWidth).clamp(
        minLabelWidth,
        maxLabelWidth,
      );
    } else {
      exposedLabelWidth = (usableWidth * 0.35).clamp(0.0, minLabelWidth);
    }
    return (usableWidth - exposedLabelWidth).clamp(30.0, double.infinity);
  }

  /// Checks if [block] overlaps with any other block in [allBlocks] on any shared active day.
  static bool hasOverlap(
    TimelineBlockDraft block,
    List<TimelineBlockDraft> allBlocks,
  ) {
    for (final other in allBlocks) {
      if (identical(other, block) || other.id == block.id) continue;
      final sharesDay = other.repeatDays.any(block.repeatDays.contains);
      if (!sharesDay) continue;
      if (other.startMinute < block.endMinute &&
          block.startMinute < other.endMinute) {
        return true;
      }
    }
    return false;
  }
}

/// Base Timeline Work adapter. Unlike the onboarding adapter, this operates on
/// the canonical typed draft and therefore preserves provenance and every
/// unexposed field during edits.
class BaseTimelineWorkAdapter {
  final Color accent;
  final bool defaultEditable;

  const BaseTimelineWorkAdapter({
    this.accent = OptivusColors.warning,
    this.defaultEditable = true,
  });

  List<TimelineEntry> toEntries(
    TimelineBlockDraft block, {
    double? contentWidth,
    double textScale = 1.0,
    bool? isEditable,
  }) {
    final editable = isEditable ?? defaultEditable;
    return [
      TimelineEntry(
        id: block.id,
        sourceId: block.id,
        startMinute: block.startMinute,
        endMinute: block.endMinute,
        repeatDays: block.repeatDays,
        title: block.title,
        subtitle: block.location,
        category: TimelineCategory.work,
        isEditable: editable,
        adapterKey: 'base_timeline_work',
        minHeight: WorkTimelineCard.minimumHeight(
          block,
          contentWidth: contentWidth ?? 220.0,
          textScale: textScale,
          isEditable: editable,
        ),
      ),
    ];
  }

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
    final workRole = TextEditingController(text: block.workRole ?? '');
    final workOrganization = TextEditingController(
      text: block.workOrganization ?? '',
    );
    final workDepartmentOrProject = TextEditingController(
      text: block.effectiveWorkDepartmentOrProject ?? '',
    );
    final location = TextEditingController(text: block.location ?? '');
    final notes = TextEditingController(text: block.notes ?? '');
    var startMinute = block.startMinute;
    var endMinute = block.endMinute;
    final days = <int>{
      ...block.repeatDays.where((day) => day >= 1 && day <= 7),
    };
    var selectedContextType = block.workContextType;
    var selectedMode = block.workMode;
    var selectedBlockKind = block.workBlockKind;

    return TimelineEditSheetShell.show<bool>(
      context: context,
      title: block.title.trim().isEmpty ? 'Add Work Block' : 'Edit Work Block',
      subtitle: 'Role, workplace, time and working days',
      accent: accent,
      onSave: () async {
        final titleText = title.text.trim();
        final roleText = workRole.text.trim();
        final orgText = workOrganization.text.trim();
        final deptText = workDepartmentOrProject.text.trim();
        final locText = location.text.trim();
        final notesText = notes.text.trim();

        final effectiveTitle = titleText.isNotEmpty
            ? titleText
            : (roleText.isNotEmpty
                  ? roleText
                  : (orgText.isNotEmpty ? orgText : ''));

        if (effectiveTitle.isEmpty) {
          throw Exception('Role or title is required.');
        }
        if (endMinute <= startMinute) {
          throw Exception('End time must be after start time.');
        }
        if (days.isEmpty) throw Exception('Select at least one repeat day.');

        return onSave(
          block.copyWith(
            title: effectiveTitle,
            location: locText.isNotEmpty ? locText : null,
            clearLocation: locText.isEmpty,
            sectionLabel: null,
            clearSectionLabel: true,
            notes: notesText.isNotEmpty ? notesText : null,
            clearNotes: notesText.isEmpty,
            workRole: roleText.isNotEmpty ? roleText : null,
            clearWorkRole: roleText.isEmpty,
            workOrganization: orgText.isNotEmpty ? orgText : null,
            clearWorkOrganization: orgText.isEmpty,
            workDepartmentOrProject: deptText.isNotEmpty ? deptText : null,
            clearWorkDepartmentOrProject: deptText.isEmpty,
            workContextType: selectedContextType,
            clearWorkContextType: selectedContextType == null,
            workMode: selectedMode,
            clearWorkMode: selectedMode == null,
            workBlockKind: selectedBlockKind,
            clearWorkBlockKind: selectedBlockKind == null,
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

          Widget buildChoiceChip({
            required String label,
            required bool selected,
            required VoidCallback onSelected,
          }) {
            return ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? OptivusColors.textPrimary
                      : OptivusColors.textSecondary,
                ),
              ),
              selected: selected,
              selectedColor: accent.withValues(alpha: .25),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              side: BorderSide(
                color: selected ? accent : OptivusColors.borderStandard,
                width: selected ? 1.5 : 1.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onSelected: (_) => onSelected(),
            );
          }

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
                  hintText: 'e.g. Software Engineer, Shift Lead, Operations',
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
              const Text(
                'COMPANY / ORGANIZATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textSecondary,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('base-work-organization-field'),
                controller: workOrganization,
                decoration: InputDecoration(
                  hintText: 'e.g. Acme Corp, Studio X, Freelance',
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
              const Text(
                'DEPARTMENT / PROJECT (OPTIONAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textSecondary,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('base-work-section-field'),
                controller: workDepartmentOrProject,
                decoration: InputDecoration(
                  hintText: 'e.g. Engineering, Client Consulting, Q3 Launch',
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
                'WORK CONTEXT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textSecondary,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  buildChoiceChip(
                    label: 'Job',
                    selected: selectedContextType == 'job',
                    onSelected: () => setSheetState(() {
                      selectedContextType = selectedContextType == 'job'
                          ? null
                          : 'job';
                    }),
                  ),
                  buildChoiceChip(
                    label: 'Business',
                    selected: selectedContextType == 'business',
                    onSelected: () => setSheetState(() {
                      selectedContextType = selectedContextType == 'business'
                          ? null
                          : 'business';
                    }),
                  ),
                  buildChoiceChip(
                    label: 'Freelance',
                    selected: selectedContextType == 'freelance',
                    onSelected: () => setSheetState(() {
                      selectedContextType = selectedContextType == 'freelance'
                          ? null
                          : 'freelance';
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'WORK MODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textSecondary,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  buildChoiceChip(
                    label: 'In-person',
                    selected: selectedMode == 'in_person',
                    onSelected: () => setSheetState(() {
                      selectedMode = selectedMode == 'in_person'
                          ? null
                          : 'in_person';
                    }),
                  ),
                  buildChoiceChip(
                    label: 'Remote',
                    selected: selectedMode == 'remote',
                    onSelected: () => setSheetState(() {
                      selectedMode = selectedMode == 'remote' ? null : 'remote';
                    }),
                  ),
                  buildChoiceChip(
                    label: 'Hybrid',
                    selected: selectedMode == 'hybrid',
                    onSelected: () => setSheetState(() {
                      selectedMode = selectedMode == 'hybrid' ? null : 'hybrid';
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'BLOCK FOCUS / KIND',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textSecondary,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  buildChoiceChip(
                    label: 'Deep Work',
                    selected: selectedBlockKind == 'deep_work',
                    onSelected: () => setSheetState(() {
                      selectedBlockKind = selectedBlockKind == 'deep_work'
                          ? null
                          : 'deep_work';
                    }),
                  ),
                  buildChoiceChip(
                    label: 'Meeting',
                    selected: selectedBlockKind == 'meeting',
                    onSelected: () => setSheetState(() {
                      selectedBlockKind = selectedBlockKind == 'meeting'
                          ? null
                          : 'meeting';
                    }),
                  ),
                  buildChoiceChip(
                    label: 'Shift',
                    selected: selectedBlockKind == 'shift',
                    onSelected: () => setSheetState(() {
                      selectedBlockKind = selectedBlockKind == 'shift'
                          ? null
                          : 'shift';
                    }),
                  ),
                  buildChoiceChip(
                    label: 'Admin',
                    selected: selectedBlockKind == 'admin',
                    onSelected: () => setSheetState(() {
                      selectedBlockKind = selectedBlockKind == 'admin'
                          ? null
                          : 'admin';
                    }),
                  ),
                  buildChoiceChip(
                    label: 'Client Call',
                    selected: selectedBlockKind == 'client_call',
                    onSelected: () => setSheetState(() {
                      selectedBlockKind = selectedBlockKind == 'client_call'
                          ? null
                          : 'client_call';
                    }),
                  ),
                ],
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
                'WORKPLACE & LOCATION',
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
