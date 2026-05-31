import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/sheets/week_planner_sheet.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';

/// Shows the Routine Settings bottom sheet.
void showRoutineSettingsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RoutineSettingsSheetBody(parentRef: ref),
  );
}

class _RoutineSettingsSheetBody extends StatelessWidget {
  final WidgetRef parentRef;
  const _RoutineSettingsSheetBody({required this.parentRef});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                OptivusColors.routineSheetTop,
                OptivusColors.routineSheetBottom,
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              const Row(
                children: [
                  Icon(
                    Icons.settings,
                    size: 22,
                    color: OptivusColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Routine Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Settings tiles
              _SettingsTile(
                icon: Icons.calendar_view_week,
                title: 'Week Planner',
                subtitle: 'Monday to Sunday planning',
                onTap: () => showRoutineWeekPlannerSheet(context, parentRef),
              ),
              _SettingsTile(
                icon: Icons.schedule,
                title: 'Base Timeline Manager',
                subtitle: 'Classes, Job, Eating, Fixed blocks',
                onTap: () => _showBaseTimelineManager(context),
              ),
              _SettingsTile(
                icon: Icons.psychology,
                title: 'Habit Systems',
                subtitle: 'Good habits, Bad habits, Identity goals',
                onTap: () => _showHabitSystems(context),
              ),
              _SettingsTile(
                icon: Icons.history,
                title: 'Routine History',
                subtitle: 'Completed, Skipped, Missed',
                onTap: () => _showRoutineHistory(context),
              ),

              const SizedBox(height: 16),
              const Text(
                'Timeline View',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Working toggles
              Consumer(
                builder: (ctx, ref, _) {
                  final showFullDay = ref
                      .watch(routineNotifierProvider)
                      .showFullDay;
                  return _ToggleTile(
                    title: 'Full 24h mode',
                    subtitle: 'Show all 24 hours',
                    value: showFullDay,
                    onChanged: (v) => ref
                        .read(routineNotifierProvider.notifier)
                        .toggleFullDay(v),
                  );
                },
              ),
              Consumer(
                builder: (ctx, ref, _) {
                  final showMinuteTicks = ref
                      .watch(routineNotifierProvider)
                      .showMinuteTicks;
                  return _ToggleTile(
                    title: 'Show minute ticks',
                    subtitle: '1-min and 5-min markers on ruler',
                    value: showMinuteTicks,
                    onChanged: (v) => ref
                        .read(routineNotifierProvider.notifier)
                        .toggleMinuteTicks(v),
                  );
                },
              ),
              Consumer(
                builder: (ctx, ref, _) {
                  final compactMode = ref
                      .watch(routineNotifierProvider)
                      .compactMode;
                  return _ToggleTile(
                    title: 'Compact mode',
                    subtitle: 'Smaller card heights',
                    value: compactMode,
                    onChanged: (v) => ref
                        .read(routineNotifierProvider.notifier)
                        .toggleCompactMode(v),
                  );
                },
              ),
              Consumer(
                builder: (ctx, ref, _) {
                  final showCurrentTimeLine = ref
                      .watch(routineNotifierProvider)
                      .showCurrentTimeLine;
                  return _ToggleTile(
                    title: 'Current Time Line',
                    subtitle: 'Show floating indicator',
                    value: showCurrentTimeLine,
                    onChanged: (v) => ref
                        .read(routineNotifierProvider.notifier)
                        .toggleCurrentTimeLine(v),
                  );
                },
              ),
              Consumer(
                builder: (ctx, ref, _) {
                  final precisionMode = ref
                      .watch(routineNotifierProvider)
                      .precisionMode;
                  return _ToggleTile(
                    title: 'Precision mode',
                    subtitle: 'Move controls snap to 1 minute',
                    value: precisionMode,
                    onChanged: (v) => ref
                        .read(routineNotifierProvider.notifier)
                        .togglePrecisionMode(v),
                  );
                },
              ),

              const SizedBox(height: 16),
              const Text(
                'Automation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.auto_fix_high,
                title: 'AI Suggestions',
                subtitle: 'Get smart suggestions for your routine',
                onTap: () => _showAutomationSheet(context),
              ),
              _SettingsTile(
                icon: Icons.warning_amber_rounded,
                title: 'Conflict Resolver',
                subtitle: 'Warnings and move suggestions',
                onTap: () => _showConflictResolver(context),
              ),
              _SettingsTile(
                icon: Icons.notifications_none,
                title: 'Notifications',
                subtitle: 'Task reminders and alerts',
                onTap: () => _showAutomationSheet(context),
              ),
              const SizedBox(height: 16),
              const Text(
                'Export',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.ios_share_rounded,
                title: 'Export Schedule',
                subtitle: 'Preview a text schedule export',
                onTap: () => _showExportSheet(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBaseTimelineManager(BuildContext context) {
    Navigator.of(context).pop(); // Close the settings sheet first
    parentRef.read(routineDetailViewRequestProvider.notifier).state =
        const RoutineDetailTarget(view: RoutineDetailView.baseTimelineManager);
  }

  void _showHabitSystems(BuildContext context) {
    final items = parentRef.watch(routineNotifierProvider).items;
    _showListSheet(
      context,
      title: 'Habit Systems',
      icon: Icons.psychology_rounded,
      children: [
        const _SectionLabel('Good Habits'),
        ...items
            .where(
              (item) =>
                  item.category == RoutineCategory.habit ||
                  item.category == RoutineCategory.identity,
            )
            .map(_itemTile),
        const _SectionLabel('Bad Habits'),
        ...items
            .where(
              (item) =>
                  item.category == RoutineCategory.badHabit ||
                  item.blockType == RoutineBlockType.checkIn,
            )
            .map(_itemTile),
        const _SectionLabel('Identity Goals'),
        ...items
            .where((item) => item.priority == RoutinePriority.mustDo)
            .map(_itemTile),
      ],
    );
  }

  void _showRoutineHistory(BuildContext context) {
    final history =
        parentRef
            .watch(routineNotifierProvider)
            .items
            .where(
              (item) =>
                  item.status == RoutineStatus.completed ||
                  item.status == RoutineStatus.skipped ||
                  item.status == RoutineStatus.missed ||
                  item.isCompleted ||
                  item.isMissed,
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _showListSheet(
      context,
      title: 'Routine History',
      icon: Icons.history_rounded,
      children: history.isEmpty
          ? [
              const _InfoRowBox(
                text:
                    'Completed, skipped, and missed routine items appear here.',
              ),
            ]
          : history.map(_itemTile).toList(),
    );
  }

  void _showAutomationSheet(BuildContext context) {
    _showListSheet(
      context,
      title: 'Automation',
      icon: Icons.auto_fix_high_rounded,
      children: [
        Consumer(
          builder: (context, ref, _) => _ToggleTile(
            title: 'AI Routine Suggestions',
            subtitle: 'Local suggestions only in this frontend build',
            value: ref.watch(aiRoutineSuggestionsEnabledProvider),
            onChanged: (value) =>
                ref.read(aiRoutineSuggestionsEnabledProvider.notifier).state =
                    value,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => _ToggleTile(
            title: 'Conflict Resolver',
            subtitle: 'Show schedule warnings and move suggestions',
            value: ref.watch(conflictResolverEnabledProvider),
            onChanged: (value) =>
                ref.read(conflictResolverEnabledProvider.notifier).state =
                    value,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => _ToggleTile(
            title: 'Notifications',
            subtitle: 'Mock reminder toggle, no system permission request',
            value: ref.watch(routineNotificationsEnabledProvider),
            onChanged: (value) =>
                ref.read(routineNotificationsEnabledProvider.notifier).state =
                    value,
          ),
        ),
      ],
    );
  }

  void _showConflictResolver(BuildContext context) {
    final conflicts = parentRef.watch(routineNotifierProvider).conflicts;
    _showListSheet(
      context,
      title: 'Conflict Resolver',
      icon: Icons.warning_amber_rounded,
      children: conflicts.isEmpty
          ? [const _InfoRowBox(text: 'No conflicts on the selected day.')]
          : conflicts.map((conflict) {
              return _ConflictResolverTile(
                conflict: conflict,
                onKeepBoth: conflict.canKeepBoth
                    ? () {
                        parentRef
                            .read(routineNotifierProvider.notifier)
                            .keepConflictPair(conflict);
                        Navigator.of(context).pop();
                      }
                    : null,
                onMarkFlexible: () {
                  parentRef
                      .read(routineNotifierProvider.notifier)
                      .markFlexible(conflict.itemId);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
    );
  }

  void _showExportSheet(BuildContext context) {
    final selectedDay = parentRef.watch(routineNotifierProvider).selectedDay;
    final items = parentRef.watch(selectedDayRoutineItemsProvider);
    final lines = items
        .map((item) {
          return '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)}  ${item.title}  ${item.statusLabel}';
        })
        .join('\n');
    _showListSheet(
      context,
      title: 'Export Schedule',
      icon: Icons.ios_share_rounded,
      children: [
        _InfoRowBox(
          text:
              '${TimelineUtils.getDayName(selectedDay.weekday)} ${selectedDay.day}/${selectedDay.month}\n$lines',
        ),
      ],
    );
  }

  Widget _itemTile(RoutineItem item) {
    return _InfoRowBox(
      text:
          '${item.title}\n${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • ${item.blockTypeLabel} • ${item.statusLabel}',
    );
  }

  void _showListSheet(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  OptivusColors.routineSheetTop,
                  OptivusColors.routineSheetBottom,
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(icon, color: OptivusColors.routineAccent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: OptivusColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InfoRowBox extends StatelessWidget {
  final String text;

  const _InfoRowBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: OptivusColors.textBody,
        ),
      ),
    );
  }
}

class _ConflictResolverTile extends ConsumerWidget {
  final RoutineConflict conflict;
  final VoidCallback? onKeepBoth;
  final VoidCallback onMarkFlexible;

  const _ConflictResolverTile({
    required this.conflict,
    required this.onKeepBoth,
    required this.onMarkFlexible,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = conflict.blocking
        ? OptivusColors.danger
        : OptivusColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conflict.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            conflict.message,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: OptivusColors.textBody,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onKeepBoth != null)
                _MiniAction(
                  label: 'Keep both',
                  color: OptivusColors.warning,
                  onTap: onKeepBoth,
                ),
              _MiniAction(
                label: 'Find free slot',
                color: OptivusColors.success,
                onTap: () {
                  final item = ref
                      .read(routineNotifierProvider)
                      .items
                      .firstWhere((i) => i.id == conflict.itemId);
                  final start = ref
                      .read(routineNotifierProvider.notifier)
                      .findFreeSlot(
                        item: item,
                        date: ref.read(routineNotifierProvider).selectedDay,
                      );
                  if (start != null) {
                    ref
                        .read(routineNotifierProvider.notifier)
                        .moveItem(
                          itemId: item.id,
                          date: ref.read(routineNotifierProvider).selectedDay,
                          startMinute: start,
                          durationMinutes: item.durationMinutes,
                        );
                  }
                  Navigator.of(context).pop();
                },
              ),
              _MiniAction(
                label: 'Make tiny version',
                color: OptivusColors.routineAccent,
                onTap: () {
                  final item = ref
                      .read(routineNotifierProvider)
                      .items
                      .firstWhere((i) => i.id == conflict.itemId);
                  ref
                      .read(routineNotifierProvider.notifier)
                      .makeTinyVersion(item);
                  Navigator.of(context).pop();
                },
              ),
              _MiniAction(
                label: 'Mark flexible',
                color: OptivusColors.textSecondary,
                onTap: onMarkFlexible,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _MiniAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: OptivusColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: OptivusColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: OptivusColors.routineAccent,
            ),
          ],
        ),
      ),
    );
  }
}
