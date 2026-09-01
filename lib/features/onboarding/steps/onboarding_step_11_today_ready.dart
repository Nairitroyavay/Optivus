import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/timeline/onboarding_timeline.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/region_settings_provider.dart';

class OnboardingStep14 extends ConsumerWidget {
  final ValueChanged<int>? onJumpToStep;

  const OnboardingStep14({super.key, this.onJumpToStep});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(mockOnboardingProvider);
    final draft = onboarding.draft;
    final bundle = OnboardingCompletionService.buildBundle(draft);
    final blockingConflicts = draft.timelineConflictsRequiringAcceptance();
    final conflictGroups = _ConflictGroup.from(blockingConflicts);
    final missing = <_MissingSetup>[
      if (draft.lifeRole.validate() != null)
        const _MissingSetup('Role and lifestyle', 2),
      if (draft.bodyBasics.validate() != null)
        const _MissingSetup('Body basics', 3),
      if (draft.baseTimeline.validateClassesAndWorkForRole(
            draft.lifeRole.lifeRole,
          ) !=
          null)
        const _MissingSetup('Classes & job', 4),
      if (draft.baseTimeline.validateEatingSetup() != null)
        const _MissingSetup('Eating setup', 5),
      if (draft.baseTimeline.validateFixedSchedule() != null)
        const _MissingSetup('Fixed schedule', 6),
      if (draft.baseTimeline.validateSkinCareSetup() != null)
        const _MissingSetup('Skin care', 7),
      if (!draft.badHabitsNotNow && draft.badHabits.isEmpty)
        const _MissingSetup('Bad habits', 8),
      if (!draft.goodHabitsNotNow && draft.goodHabits.isEmpty)
        const _MissingSetup('Good habits', 9),
      if (draft.identityGoals.isEmpty)
        const _MissingSetup('Identity goals', 10),
      if (draft.coachSetup.validate() != null)
        const _MissingSetup('Coach setup', 11),
      if (draft.slipUpHandling == null)
        const _MissingSetup('Slip-up handling', 12),
      if (!onboarding.stepCompleted
          .take(OnboardingDraft.lastStepIndex)
          .every((done) => done))
        const _MissingSetup('Unsaved setup steps', 0),
    ];

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape ||
        MediaQuery.sizeOf(context).height < 500;

    if (isLandscape) {
      return OnboardingScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OnboardingSectionTitle(
              title: 'Today Is Ready',
              subtitle:
                  'Review the local onboarding setup before entering Optivus.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (missing.isNotEmpty)
              OnboardingGlassCard(
                tint: OptivusColors.warning.withValues(alpha: 0.10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: OptivusColors.warning,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Missing required setup',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      missing.map((item) => item.label).join('\n'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: OptivusColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in missing)
                          ActionChip(
                            label: Text('Fix ${item.label}'),
                            onPressed: onJumpToStep == null
                                ? null
                                : () => onJumpToStep!(item.step),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (missing.isNotEmpty) const SizedBox(height: 16),
            if (conflictGroups.isNotEmpty) ...[
              _BlockingConflictList(
                groups: conflictGroups,
                onKeepBoth: (group, days) => _keepBoth(ref, group, days),
                onEdit: (blockId) => _editBlock(draft, blockId),
              ),
              const SizedBox(height: 16),
            ],
            OnboardingGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Final preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text('Timeline blocks: ${draft.baseTimeline.blocks.length}'),
                  Text(
                    'Eating mode: ${draft.baseTimeline.eatingMode ?? "default"}',
                  ),
                  Text(
                    'Skin care products: ${draft.baseTimeline.skinCareSelectedProductNames.length}',
                  ),
                  Text('Identity goals: ${draft.identityGoals.length}'),
                ],
              ),
            ),
            if (bundle.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              OnboardingGlassCard(
                tint: OptivusColors.warning.withValues(alpha: 0.08),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Warnings',
                      style: TextStyle(
                        color: OptivusColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(bundle.warnings.join('\n')),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const OnboardingSectionTitle(
              title: 'Today timeline preview',
              subtitle: 'Generated blocks for your first day',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 480,
              child: _Step14TimelinePreview(blocks: bundle.baseTimelineBlocks),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(
            title: 'Today Is Ready',
            subtitle:
                'Review the local onboarding setup before entering Optivus.',
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (missing.isNotEmpty)
                  OnboardingGlassCard(
                    tint: OptivusColors.warning.withValues(alpha: 0.10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: OptivusColors.warning,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Missing required setup',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          missing.map((item) => item.label).join('\n'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: OptivusColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: missing
                              .map(
                                (item) => OnboardingChip(
                                  label: 'Edit ${item.label}',
                                  selected: false,
                                  accent: OptivusColors.warning,
                                  onTap: () => onJumpToStep?.call(item.step),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  )
                else
                  OnboardingGlassCard(
                    tint: OptivusColors.success.withValues(alpha: 0.10),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: OptivusColors.success,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Required onboarding setup is complete.',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: OptivusColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                if (conflictGroups.isNotEmpty) ...[
                  _BlockingConflictList(
                    groups: conflictGroups,
                    onKeepBoth: (group, days) => _keepBoth(ref, group, days),
                    onEdit: (blockId) => _editBlock(draft, blockId),
                  ),
                  const SizedBox(height: 14),
                ],
                OnboardingGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Final preview',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          OnboardingActionPill(
                            label: 'Edit Setup',
                            icon: Icons.edit_rounded,
                            accent: OptivusColors.brandAccent,
                            compact: true,
                            onTap: () => onJumpToStep?.call(2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _row(
                        'Your identity goals',
                        draft.identityGoals.isEmpty
                            ? 'Not selected'
                            : draft.identityGoals
                                  .map((goal) => goal.displayName)
                                  .join(', '),
                      ),
                      _row(
                        'Today timeline',
                        '${bundle.routineItemsForApp.length} generated blocks',
                      ),
                      _row('Habit focus', _habitFocus(draft)),
                      _row(
                        'Coach',
                        draft.coachSetup.coachName ?? 'Not selected',
                      ),
                      _row(
                        'Coach style',
                        _displayKey(draft.coachSetup.coachStyle),
                      ),
                      _row(
                        'Slip-up handling',
                        _displayKey(draft.slipUpHandling),
                      ),
                      _row(
                        'Notifications',
                        draft.notifications.selectedLabels().isEmpty
                            ? 'None selected'
                            : draft.notifications.selectedLabels().join(', '),
                      ),
                      if (bundle.duplicateSystemKeysMerged.isNotEmpty)
                        _row(
                          'Merged duplicates',
                          bundle.duplicateSystemKeysMerged
                              .map(identitySystemTitle)
                              .join(', '),
                        ),
                    ],
                  ),
                ),
                if (bundle.warnings.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  OnboardingGlassCard(
                    tint: OptivusColors.warning.withValues(alpha: 0.10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Warnings',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bundle.warnings.join('\n'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: OptivusColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 500,
                  child: _Step14TimelinePreview(
                    blocks: bundle.baseTimelineBlocks,
                  ),
                ),
              ], // end OnboardingScrollView inner Column children
            ), // end OnboardingScrollView inner Column
          ), // end OnboardingScrollView
        ), // end Expanded
      ], // end outer Column children
    );
  }

  static Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _keepBoth(WidgetRef ref, _ConflictGroup group, List<int> days) {
    final timezoneId = ref.read(regionSettingsProvider).timezone;
    ref
        .read(mockOnboardingProvider.notifier)
        .updateDraft(
          (draft) => draft.acceptTimelineConflictGroup(
            conflict: group.conflicts.first,
            weekdays: days,
            timezoneId: timezoneId,
          ),
        );
  }

  void _editBlock(OnboardingDraft draft, String blockId) {
    final block = draft.baseTimeline.blockById(blockId);
    if (block == null) return;
    final step = switch (block.section) {
      'classes' || 'job_work_business' => 4,
      'eating' => 5,
      'fixed' => 6,
      'skin_care' => 7,
      _ => 4,
    };
    onJumpToStep?.call(step);
  }

  static String _habitFocus(OnboardingDraft draft) {
    final parts = [
      if (draft.goodHabits.isNotEmpty)
        draft.goodHabits.map((habit) => habit.displayName).join(', '),
      if (draft.badHabits.isNotEmpty)
        '${draft.badHabits.length} bad habit check-in${draft.badHabits.length == 1 ? '' : 's'}',
    ];
    return parts.isEmpty ? 'Not now' : parts.join(' + ');
  }

  static String _displayKey(String? key) {
    if (key == null || key.isEmpty) return 'Not selected';
    return key
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}

class _Step14TimelinePreview extends StatefulWidget {
  final List<TimelineBlockDraft> blocks;

  const _Step14TimelinePreview({required this.blocks});

  @override
  State<_Step14TimelinePreview> createState() => _Step14TimelinePreviewState();
}

class _Step14TimelinePreviewState extends State<_Step14TimelinePreview> {
  int _selectedDay = 1;

  @override
  Widget build(BuildContext context) {
    final entries = <TimelineEntry>[];
    for (final block in widget.blocks) {
      if (block.section == 'fixed' &&
          (block.crossesMidnight || block.startMinute >= block.endMinute)) {
        entries.addAll(
          const FixedTimelineAdapter()
              .toEntries(block)
              .map((entry) => entry.copyWith(isEditable: false)),
        );
        continue;
      }
      final category = switch (block.section) {
        'classes' => TimelineCategory.classes,
        'job_work_business' => TimelineCategory.work,
        'eating' => TimelineCategory.meal,
        'fixed' => TimelineCategory.fixed,
        'skin_care' => TimelineCategory.skinCare,
        _ => TimelineCategory.other,
      };
      entries.add(
        TimelineEntry(
          id: block.id,
          sourceId: block.id,
          startMinute: block.startMinute,
          endMinute: block.endMinute,
          repeatDays: block.repeatDays,
          title: block.title,
          subtitle: block.location,
          category: category,
          isEditable: false,
        ),
      );
    }

    return FullScreenTimelineScaffold(
      key: const ValueKey('onboarding-step14-shared-preview'),
      entries: entries,
      selectedDay: _selectedDay,
      onDayChanged: (day) => setState(() => _selectedDay = day),
      title: 'Today timeline preview',
      subtitle: 'Review only — edit items from their setup step.',
      mode: TimelineMode.previewReadOnly,
      accent: OptivusColors.aquaAccent,
      styleBuilder: (entry) =>
          TimelineEntryStyle.defaultForCategory(entry.category),
    );
  }
}

class _BlockingConflictList extends StatelessWidget {
  final List<_ConflictGroup> groups;
  final void Function(_ConflictGroup group, List<int> days) onKeepBoth;
  final ValueChanged<String> onEdit;

  const _BlockingConflictList({
    required this.groups,
    required this.onKeepBoth,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: OptivusColors.warning.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_arrows_rounded, color: OptivusColors.warning),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose how to handle overlaps',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Keeping both preserves both cards in Routine at the times you selected.',
            style: TextStyle(
              fontSize: 12,
              color: OptivusColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < groups.length; index++) ...[
            _BlockingConflictRow(
              group: groups[index],
              onKeepBoth: (days) => onKeepBoth(groups[index], days),
              onEdit: onEdit,
            ),
            if (index != groups.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _BlockingConflictRow extends StatelessWidget {
  final _ConflictGroup group;
  final ValueChanged<List<int>> onKeepBoth;
  final ValueChanged<String> onEdit;

  const _BlockingConflictRow({
    required this.group,
    required this.onKeepBoth,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final conflict = group.conflicts.first;
    return Semantics(
      container: true,
      label:
          '${conflict.firstTitle} and ${conflict.secondTitle} overlap ${group.dayLabel}. ${conflict.publicReason}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${conflict.firstTitle} + ${conflict.secondTitle}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'Overlap ${group.dayLabel}',
            style: const TextStyle(
              fontSize: 11,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            conflict.publicReason,
            style: TextStyle(
              fontSize: 11,
              color: conflict.canKeepBoth
                  ? OptivusColors.textSecondary
                  : OptivusColors.warning,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onEdit(conflict.firstBlockId),
                child: Text('Edit ${conflict.firstTitle}'),
              ),
              OutlinedButton(
                onPressed: () => onEdit(conflict.secondBlockId),
                child: Text('Edit ${conflict.secondTitle}'),
              ),
              if (conflict.canKeepBoth)
                FilledButton.tonal(
                  key: ValueKey(
                    'onboarding-final-keep-both-${group.conflicts.first.key}',
                  ),
                  onPressed: () => onKeepBoth(group.weekdays),
                  child: const Text('Keep Both on These Days'),
                ),
              OutlinedButton(
                onPressed: conflict.canKeepBoth
                    ? () => _reviewDays(context)
                    : null,
                child: const Text('Review Days'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reviewDays(BuildContext context) async {
    final selected = group.weekdays.toSet();
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Choose overlap days'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final day in group.weekdays)
                CheckboxListTile(
                  value: selected.contains(day),
                  title: Text(_weekday(day)),
                  onChanged: (checked) {
                    setState(() {
                      if (checked ?? false) {
                        selected.add(day);
                      } else {
                        selected.remove(day);
                      }
                    });
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, selected.toList()..sort()),
              child: const Text('Keep Both'),
            ),
          ],
        ),
      ),
    );
    if (result != null && result.isNotEmpty) onKeepBoth(result);
  }

  static String _weekday(int day) => switch (day) {
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
    7 => 'Sunday',
    _ => 'the selected day',
  };
}

class _ConflictGroup {
  const _ConflictGroup({required this.key, required this.conflicts});

  final String key;
  final List<TimelineConflictDraft> conflicts;

  List<int> get weekdays =>
      (conflicts.map((conflict) => conflict.day).toSet().toList()..sort());

  String get dayLabel {
    final days = weekdays;
    if (days.length == 5 && days.join(',') == '1,2,3,4,5') {
      return 'Monday–Friday';
    }
    return days.map(_BlockingConflictRow._weekday).join(', ');
  }

  static List<_ConflictGroup> from(List<TimelineConflictDraft> conflicts) {
    final grouped = <String, List<TimelineConflictDraft>>{};
    for (final conflict in conflicts) {
      final ids = [conflict.firstBlockId, conflict.secondBlockId]..sort();
      final key = '${ids[0]}|${ids[1]}|${conflict.conflictType}';
      grouped.putIfAbsent(key, () => []).add(conflict);
    }
    final result = grouped.entries
        .map(
          (entry) => _ConflictGroup(
            key: entry.key,
            conflicts: entry.value..sort((a, b) => a.day.compareTo(b.day)),
          ),
        )
        .toList();
    result.sort((a, b) => a.key.compareTo(b.key));
    return result;
  }
}

class _MissingSetup {
  final String label;
  final int step;

  const _MissingSetup(this.label, this.step);
}
