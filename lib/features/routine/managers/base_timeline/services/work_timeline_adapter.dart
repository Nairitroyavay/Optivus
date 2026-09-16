import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_style.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_edit_sheet_shell.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_presentation_utils.dart';
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
    String? lifeRole,
    bool? isNew,
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

    final effectiveIsNew =
        isNew ??
        (block.title.trim().isEmpty &&
            (block.workRole?.trim().isEmpty ?? true));

    final sheetTitle = WorkPresentationUtils.editorTitle(
      isNew: effectiveIsNew,
      contextType: selectedContextType,
      lifeRole: lifeRole,
    );
    final sheetSubtitle = selectedContextType == 'business'
        ? 'Role, business name, time and operating days'
        : 'Role, workplace, time and working days';

    return TimelineEditSheetShell.show<bool>(
      context: context,
      title: sheetTitle,
      subtitle: sheetSubtitle,
      accent: accent,
      onSave: () async {
        final titleText = title.text.trim();
        final roleText = workRole.text.trim();
        final orgText = workOrganization.text.trim();
        final deptText = workDepartmentOrProject.text.trim();
        final locText = location.text.trim();
        final notesText = notes.text.trim();

        if (titleText.isEmpty) {
          throw Exception('Activity is required.');
        }
        if (endMinute <= startMinute) {
          throw Exception('End time must be after start time.');
        }
        if (days.isEmpty) throw Exception('Select at least one repeat day.');

        return onSave(
          block.copyWith(
            title: titleText,
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
              // 1. ACTIVITY
              const Text(
                'ACTIVITY',
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
                  hintText: 'e.g. Sprint Planning, Office Work, Client Review',
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
              const SizedBox(height: 18),

              // 2. PROFESSIONAL CONTEXT
              const Text(
                'PROFESSIONAL CONTEXT',
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
                  for (final ctx in [
                    'job',
                    'business',
                    'startup',
                    'freelance',
                    'other',
                  ])
                    buildChoiceChip(
                      label: WorkPresentationUtils.formatContext(ctx),
                      selected: selectedContextType == ctx,
                      onSelected: () => setSheetState(() {
                        selectedContextType = selectedContextType == ctx
                            ? null
                            : ctx;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                WorkPresentationUtils.roleEditorLabel(selectedContextType),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textSecondary,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('base-work-role-field'),
                controller: workRole,
                decoration: InputDecoration(
                  hintText: WorkPresentationUtils.roleEditorHint(
                    selectedContextType,
                  ),
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
              Text(
                WorkPresentationUtils.organizationEditorLabel(
                  selectedContextType,
                ),
                style: const TextStyle(
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
                  hintText: WorkPresentationUtils.organizationEditorHint(
                    selectedContextType,
                  ),
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
              Text(
                WorkPresentationUtils.departmentEditorLabel(
                  selectedContextType,
                ),
                style: const TextStyle(
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
                  hintText: WorkPresentationUtils.departmentEditorHint(
                    selectedContextType,
                  ),
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
              const SizedBox(height: 18),

              // 3. SCHEDULE
              const Text(
                'SCHEDULE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textSecondary,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'BLOCK FOCUS / KIND',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in [
                    'work_hours',
                    'deep_work',
                    'shift',
                    'meeting',
                    'client_call',
                    'project_work',
                    'team_sync',
                    'training',
                    'commute',
                    'break',
                    'business_hours',
                    'admin',
                    'other',
                  ])
                    buildChoiceChip(
                      label: WorkPresentationUtils.formatBlockKind(k),
                      selected: selectedBlockKind == k,
                      onSelected: () => setSheetState(() {
                        selectedBlockKind = selectedBlockKind == k ? null : k;
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
                  for (final m in [
                    'in_person',
                    'remote',
                    'hybrid',
                    'field',
                    'mixed',
                  ])
                    buildChoiceChip(
                      label: WorkPresentationUtils.formatMode(m),
                      selected: selectedMode == m,
                      onSelected: () => setSheetState(() {
                        selectedMode = selectedMode == m ? null : m;
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
                'PLACE & DETAILS',
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
                    label: Text(
                      WorkPresentationUtils.removeBlockLabel(lifeRole),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: OptivusColors.backgroundBottom,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            WorkPresentationUtils.removeBlockConfirmTitle(
                              lifeRole,
                            ),
                            style: const TextStyle(
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
