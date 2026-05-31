import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';

class RoutineHabitSystemsScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const RoutineHabitSystemsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(routineNotifierProvider).items;
    final habits = items
        .where((item) => item.category == RoutineCategory.habit)
        .toList();
    final badHabits = items
        .where((item) => item.category == RoutineCategory.badHabit)
        .toList();
    final identities = items
        .where((item) => item.category == RoutineCategory.identity)
        .toList();
    final merged = _mergedExamples(items);
    final overload = items
        .where((item) => item.priority == RoutinePriority.mustDo)
        .length;

    return LiquidDetailScaffold(
      eyebrow: 'Routine',
      title: 'Habit Systems',
      subtitle:
          'Good habits, bad habits, identity systems, merged duplicates, and overload warnings.',
      accentColor: OptivusColors.routineAccent,
      onBack: onBack,
      children: [
        _SystemSection(
          title: 'Good Habits',
          items: habits,
          fallback: const [
            _SystemExample('Meditation', 'Daily mind reset', '5m'),
            _SystemExample('Reading', 'Growth input', '20m'),
            _SystemExample('Skill Practice', 'Project reps', '30m'),
          ],
        ),
        _SystemSection(
          title: 'Bad Habits',
          items: badHabits,
          fallback: const [
            _SystemExample('Cigarettes Check-in', 'Evening risk check', '2m'),
            _SystemExample('Money System', 'Avoided spend converted', '5m'),
          ],
        ),
        _SystemSection(
          title: 'Identity Goal Systems',
          items: identities,
          fallback: const [
            _SystemExample(
              'New Language system',
              'Daily learning proof',
              '15m',
            ),
            _SystemExample(
              'Strong Body system',
              'Movement and workout proof',
              '45m',
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Duplicate-merged Systems',
          children: merged
              .map(
                (example) => LiquidActionRow(
                  icon: Icons.merge_type_rounded,
                  title: example.title,
                  subtitle: example.subtitle,
                  accentColor: OptivusColors.routineAccent,
                ),
              )
              .toList(),
        ),
        LiquidDetailSection(
          title: 'Overload warnings',
          tint: overload > 3
              ? OptivusColors.warning.withValues(alpha: 0.08)
              : null,
          children: [
            Text(
              overload > 3
                  ? 'Overload warning: $overload must-do systems compete for attention today. Use tiny versions or pause one system.'
                  : 'No overload warning. Must-do systems are within the frontend guardrail.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w800,
                color: overload > 3
                    ? OptivusColors.warning
                    : OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Actions',
          children: [
            LiquidActionRow(
              icon: Icons.flag_outlined,
              title: 'Open Goals',
              subtitle: 'Goals owns identity logic and proof definitions.',
              accentColor: OptivusColors.goalsAccent,
              onTap: () => ref.read(appNavigationProvider.notifier).goToGoals(),
            ),
            LiquidActionRow(
              icon: Icons.track_changes_rounded,
              title: 'Open Tracker',
              subtitle: 'Tracker owns progress, sessions, and check-ins.',
              accentColor: OptivusColors.trackerAccent,
              onTap: () =>
                  ref.read(appNavigationProvider.notifier).goToTracker(),
            ),
          ],
        ),
      ],
    );
  }

  List<_SystemExample> _mergedExamples(List<RoutineItem> items) {
    final titles = <String, int>{};
    for (final item in items) {
      final key = item.title.toLowerCase().replaceAll('[tiny] ', '');
      titles[key] = (titles[key] ?? 0) + 1;
    }
    final duplicates = titles.entries
        .where((entry) => entry.value > 1)
        .toList();
    if (duplicates.isEmpty) {
      return const [
        _SystemExample(
          'Meditation + Mind Goal',
          'Merged into one morning system',
          '5m',
        ),
        _SystemExample(
          'Money System + Cigarettes',
          'Avoided spend links to savings',
          '5m',
        ),
      ];
    }
    return duplicates
        .map(
          (entry) => _SystemExample(
            entry.key,
            '${entry.value} duplicates merged for Firestore schema',
            'merged',
          ),
        )
        .toList();
  }
}

class _SystemSection extends ConsumerWidget {
  final String title;
  final List<RoutineItem> items;
  final List<_SystemExample> fallback;

  const _SystemSection({
    required this.title,
    required this.items,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return LiquidDetailSection(
        title: title,
        children: fallback
            .map(
              (example) => LiquidActionRow(
                icon: Icons.auto_awesome_motion_rounded,
                title: example.title,
                subtitle: '${example.subtitle} · ${example.duration}',
                accentColor: OptivusColors.routineAccent,
              ),
            )
            .toList(),
      );
    }

    return LiquidDetailSection(
      title: title,
      children: items
          .map(
            (item) => LiquidActionRow(
              icon: _iconFor(item),
              title: item.title,
              subtitle:
                  '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} · ${item.blockTypeLabel}',
              accentColor: _colorFor(item),
              onTap: () => _showActions(context, ref, item),
            ),
          )
          .toList(),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, RoutineItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetAction(
              label: 'View system',
              onTap: () => Navigator.of(context).pop(),
            ),
            _SheetAction(
              label: 'Edit frequency',
              onTap: () {
                ref
                    .read(routineNotifierProvider.notifier)
                    .updateItem(item.copyWith(repeatDays: const [1, 3, 5]));
                Navigator.of(context).pop();
              },
            ),
            _SheetAction(
              label: 'Tiny version',
              onTap: () {
                ref
                    .read(routineNotifierProvider.notifier)
                    .makeTinyVersion(item);
                Navigator.of(context).pop();
              },
            ),
            _SheetAction(
              label: 'Pause system',
              onTap: () {
                ref
                    .read(routineNotifierProvider.notifier)
                    .updateItem(item.copyWith(status: RoutineStatus.skipped));
                Navigator.of(context).pop();
              },
            ),
            _SheetAction(
              label: 'Open Tracker',
              onTap: () {
                Navigator.of(context).pop();
                ref.read(appNavigationProvider.notifier).goToTracker();
                if (item.trackerType == TrackerType.focus) {
                  ref.read(trackerDetailViewRequestProvider.notifier).state =
                      TrackerDetailTarget.view(TrackerDetailView.focusTimer);
                }
              },
            ),
            _SheetAction(
              label: 'Open Goals',
              onTap: () {
                Navigator.of(context).pop();
                ref.read(appNavigationProvider.notifier).goToGoals();
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(RoutineItem item) {
    return switch (item.category) {
      RoutineCategory.badHabit => Icons.smoke_free_outlined,
      RoutineCategory.identity => Icons.flag_outlined,
      RoutineCategory.finance => Icons.savings_outlined,
      RoutineCategory.meditation => Icons.self_improvement_rounded,
      _ => Icons.auto_awesome_motion_rounded,
    };
  }

  Color _colorFor(RoutineItem item) {
    return switch (item.category) {
      RoutineCategory.badHabit => OptivusColors.danger,
      RoutineCategory.identity => OptivusColors.goalsAccent,
      RoutineCategory.finance => OptivusColors.mintAccent,
      RoutineCategory.meditation => OptivusColors.purpleAccent,
      _ => OptivusColors.routineAccent,
    };
  }
}

class _SheetAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SheetAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: OptivusColors.textPrimary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _SystemExample {
  final String title;
  final String subtitle;
  final String duration;

  const _SystemExample(this.title, this.subtitle, this.duration);
}
