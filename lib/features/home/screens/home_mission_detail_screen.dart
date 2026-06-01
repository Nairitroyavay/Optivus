import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'package:optivus/features/home/widgets/home_glass_widgets.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/state/app_state.dart';

class HomeMissionDetailScreen extends ConsumerWidget {
  final HomeMissionSummary summary;
  final VoidCallback onBack;

  const HomeMissionDetailScreen({
    super.key,
    required this.summary,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeDashboardProvider);
    final trackerState = ref.watch(mockTrackerProvider);
    final goals = ref.watch(mockGoalProvider);
    final activeGoal = _primaryActiveGoal(goals);
    final proofTitle =
        activeGoal?.dailyProof.title ??
        dashboard.identityFocus?.primaryProof ??
        'Choose an identity proof';
    final proofSubtitle = activeGoal == null
        ? 'Open Goals to choose the proof that anchors your mission.'
        : activeGoal.dailyProof.isCompleted
        ? 'Completed for ${activeGoal.identityTitle}'
        : 'Pending for ${activeGoal.identityTitle}';
    final proofCompleted = activeGoal?.dailyProof.isCompleted ?? false;

    void openGoals() {
      onBack();
      ref.read(appNavigationProvider.notifier).goToGoals();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onBack();
      },
      child: LiquidDetailScaffold(
        eyebrow: 'Home',
        title: "Today's Mission",
        subtitle:
            'Identity-weighted progress across routine, trackers, focus, finance, and check-ins.',
        accentColor: OptivusColors.homeAccent,
        onBack: onBack,
        children: [
          _MissionHeroSection(summary: summary),
          _CoreStatsSection(summary: summary),
          LiquidDetailSection(
            title: 'Identity Proof',
            children: [
              LiquidActionRow(
                icon: proofCompleted
                    ? Icons.verified_rounded
                    : Icons.verified_outlined,
                title: proofTitle,
                subtitle: proofSubtitle,
                accentColor: OptivusColors.goalsAccent,
                trailing: LiquidPill(
                  label: proofCompleted ? 'Completed' : 'Pending',
                  color: proofCompleted
                      ? OptivusColors.goalsAccent
                      : OptivusColors.homeAccent,
                  filled: proofCompleted,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: HomeActionPill(
                  label: 'Open Goals',
                  icon: Icons.flag_rounded,
                  accent: OptivusColors.goalsAccent,
                  selected: true,
                  compact: true,
                  onTap: openGoals,
                ),
              ),
            ],
          ),
          _TrackerSessionsSection(
            summary: summary,
            dashboard: dashboard,
            trackerState: trackerState,
          ),
          _ManualCheckInsSection(checkIns: dashboard.checkIns),
          _MissionScoreRulesSection(
            summary: summary,
            checkIns: dashboard.checkIns,
            proofCompleted: proofCompleted,
            trackerState: trackerState,
          ),
        ],
      ),
    );
  }
}

class _MissionHeroSection extends StatelessWidget {
  final HomeMissionSummary summary;

  const _MissionHeroSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final progress = _progress(summary);
    final percent = (progress * 100).round();

    return LiquidDetailSection(
      tint: OptivusColors.homeAccent.withValues(alpha: 0.08),
      children: [
        Text(
          '$percent%',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            height: 0.95,
            color: OptivusColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _actionsText(summary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: OptivusColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.45),
            valueColor: const AlwaysStoppedAnimation<Color>(
              OptivusColors.homeAccent,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _DetailStatGrid(
          stats: [
            _DetailStat('Focus', '${summary.focusMinutes}m'),
            _DetailStat('Saved', _moneySavedText(summary)),
            _DetailStat('Avoided', '${summary.badHabitsAvoided}'),
            _DetailStat(
              'Actions',
              '${summary.actionsDone}/${summary.actionsTotal}',
            ),
          ],
        ),
      ],
    );
  }
}

class _CoreStatsSection extends StatelessWidget {
  final HomeMissionSummary summary;

  const _CoreStatsSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return LiquidDetailSection(
      title: 'Core Stats',
      children: [
        LiquidActionRow(
          icon: Icons.task_alt_rounded,
          title: 'Routine Actions',
          subtitle: '${summary.actionsDone}/${summary.actionsTotal} done',
          accentColor: OptivusColors.routineAccent,
        ),
        LiquidActionRow(
          icon: Icons.timer_rounded,
          title: 'Focus Time',
          subtitle: '${summary.focusMinutes}m protected',
          accentColor: OptivusColors.homeAccent,
        ),
        LiquidActionRow(
          icon: Icons.savings_rounded,
          title: 'Money Saved',
          subtitle: _moneySavedText(summary),
          accentColor: OptivusColors.blockMoney,
        ),
        LiquidActionRow(
          icon: Icons.shield_rounded,
          title: 'Bad Habits Avoided',
          subtitle: '${summary.badHabitsAvoided}',
          accentColor: OptivusColors.coachAccent,
        ),
      ],
    );
  }
}

class _TrackerSessionsSection extends StatelessWidget {
  final HomeMissionSummary summary;
  final HomeDashboardState dashboard;
  final MockTrackerState trackerState;

  const _TrackerSessionsSection({
    required this.summary,
    required this.dashboard,
    required this.trackerState,
  });

  @override
  Widget build(BuildContext context) {
    final meditationMinutes = trackerState.trackerSessions
        .where(
          (session) =>
              _sameDay(session.timestamp, DateTime.now()) &&
              session.title.toLowerCase().contains('meditation') &&
              session.isCompleted,
        )
        .fold<int>(0, (sum, session) => sum + session.value);
    final fitnessActivities = trackerState.fitnessActivities.where(
      (activity) =>
          _sameDay(activity.startedAt, DateTime.now()) &&
          activity.status.name == 'completed',
    );
    final fitnessMinutes = fitnessActivities.fold<int>(
      0,
      (sum, activity) => sum + activity.movingDuration.inMinutes,
    );
    final hydrationMl = trackerState.hydrationLogs.fold<int>(
      0,
      (sum, log) => sum + log.amountMl,
    );

    return LiquidDetailSection(
      title: 'Tracker Sessions',
      children: [
        LiquidActionRow(
          icon: Icons.self_improvement_rounded,
          title: 'Meditation',
          subtitle: meditationMinutes > 0
              ? '${meditationMinutes}m completed today'
              : _previewSubtitle(dashboard.trackerPreviews, 'meditation'),
          accentColor: OptivusColors.trackerAccent,
        ),
        LiquidActionRow(
          icon: Icons.fitness_center_rounded,
          title: 'Workout / Fitness',
          subtitle: fitnessMinutes > 0
              ? '${fitnessActivities.length} sessions | ${fitnessMinutes}m'
              : _previewSubtitle(dashboard.trackerPreviews, 'workout'),
          accentColor: OptivusColors.trackerAccent,
        ),
        LiquidActionRow(
          icon: Icons.water_drop_rounded,
          title: 'Hydration',
          subtitle: hydrationMl > 0
              ? '${hydrationMl}ml logged'
              : _previewSubtitle(dashboard.trackerPreviews, 'hydration'),
          accentColor: Colors.blue,
        ),
        LiquidActionRow(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Money System',
          subtitle: _moneySavedText(summary),
          accentColor: OptivusColors.blockMoney,
        ),
      ],
    );
  }
}

class _ManualCheckInsSection extends StatelessWidget {
  final List<CheckInItem> checkIns;

  const _ManualCheckInsSection({required this.checkIns});

  @override
  Widget build(BuildContext context) {
    final visible = checkIns.where(_showManualCheckIn).toList(growable: false);

    return LiquidDetailSection(
      title: 'Manual Check-ins',
      children: [
        for (final item in visible)
          LiquidActionRow(
            icon: _checkInIcon(item.id),
            title: item.title,
            subtitle: item.selectedOption ?? 'Not checked in',
            accentColor: _checkInColor(item.id),
          ),
      ],
    );
  }
}

class _MissionScoreRulesSection extends StatelessWidget {
  final HomeMissionSummary summary;
  final List<CheckInItem> checkIns;
  final bool proofCompleted;
  final MockTrackerState trackerState;

  const _MissionScoreRulesSection({
    required this.summary,
    required this.checkIns,
    required this.proofCompleted,
    required this.trackerState,
  });

  @override
  Widget build(BuildContext context) {
    final completedCheckIns = checkIns
        .where(
          (item) =>
              item.selectedOption != null && item.selectedOption!.isNotEmpty,
        )
        .length;
    final trackerSignals =
        trackerState.trackerSessions
            .where((session) => session.isCompleted)
            .length +
        trackerState.fitnessActivities
            .where((activity) => activity.status.name == 'completed')
            .length +
        trackerState.hydrationLogs.length;

    return LiquidDetailSection(
      title: 'What Counts in Mission Score',
      children: [
        LiquidActionRow(
          icon: Icons.check_circle_rounded,
          title: 'Routine completed',
          subtitle:
              '${summary.actionsDone}/${summary.actionsTotal} actions counted',
          accentColor: OptivusColors.routineAccent,
        ),
        LiquidActionRow(
          icon: Icons.insights_rounded,
          title: 'Tracker session completed',
          subtitle: '$trackerSignals tracker signals counted',
          accentColor: OptivusColors.trackerAccent,
        ),
        LiquidActionRow(
          icon: Icons.fact_check_rounded,
          title: 'Manual check-in completed',
          subtitle: '$completedCheckIns/${checkIns.length} selected',
          accentColor: OptivusColors.homeAccent,
        ),
        LiquidActionRow(
          icon: Icons.verified_rounded,
          title: 'Identity proof completed',
          subtitle: proofCompleted ? 'Completed today' : 'Not completed yet',
          accentColor: OptivusColors.goalsAccent,
        ),
        LiquidActionRow(
          icon: Icons.shield_rounded,
          title: 'Bad habit avoided',
          subtitle: '${summary.badHabitsAvoided} avoided',
          accentColor: OptivusColors.coachAccent,
        ),
        LiquidActionRow(
          icon: Icons.savings_rounded,
          title: 'Money saved',
          subtitle: _moneySavedText(summary),
          accentColor: OptivusColors.blockMoney,
        ),
        LiquidActionRow(
          icon: Icons.lock_clock_rounded,
          title: 'Focus time protected',
          subtitle: '${summary.focusMinutes}m protected',
          accentColor: OptivusColors.homeAccent,
        ),
      ],
    );
  }
}

class _DetailStat {
  final String label;
  final String value;

  const _DetailStat(this.label, this.value);
}

class _DetailStatGrid extends StatelessWidget {
  final List<_DetailStat> stats;

  const _DetailStatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 270;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - 8) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final stat in stats)
              SizedBox(
                width: itemWidth,
                child: _DetailStatChip(label: stat.label, value: stat.value),
              ),
          ],
        );
      },
    );
  }
}

class _DetailStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _DetailStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

GoalModel? _primaryActiveGoal(List<GoalModel> goals) {
  for (final goal in goals) {
    if (!goal.isArchived && !goal.isPaused) return goal;
  }
  return null;
}

String _actionsText(HomeMissionSummary summary) {
  if (summary.actionsTotal == 0) return 'No mission actions scheduled yet';
  return '${summary.actionsDone}/${summary.actionsTotal} actions complete';
}

String _moneySavedText(HomeMissionSummary summary) {
  final label = summary.moneySavedLabel.trim();
  if (label.isNotEmpty) return label;
  return '${summary.moneySaved}';
}

String _previewSubtitle(List<TrackerPreview> previews, String id) {
  for (final preview in previews) {
    if (preview.id == id) return preview.subtitle;
  }
  return 'No session logged today';
}

bool _showManualCheckIn(CheckInItem item) {
  const alwaysVisible = {'water', 'sleep', 'stress'};
  const habitIds = {'smoking', 'cigarettes', 'alcohol', 'junk_food'};
  if (alwaysVisible.contains(item.id)) return true;
  return habitIds.contains(item.id) &&
      item.selectedOption != null &&
      item.selectedOption!.isNotEmpty;
}

IconData _checkInIcon(String id) {
  return switch (id) {
    'water' => Icons.water_drop_rounded,
    'sleep' => Icons.bedtime_rounded,
    'stress' => Icons.psychology_alt_rounded,
    'smoking' || 'cigarettes' => Icons.smoke_free_rounded,
    'alcohol' => Icons.no_drinks_rounded,
    'junk_food' => Icons.no_food_rounded,
    _ => Icons.fact_check_rounded,
  };
}

Color _checkInColor(String id) {
  return switch (id) {
    'water' => Colors.blue,
    'sleep' => Colors.indigo,
    'stress' => OptivusColors.coachAccent,
    'smoking' ||
    'cigarettes' ||
    'alcohol' ||
    'junk_food' => OptivusColors.coachAccent,
    _ => OptivusColors.homeAccent,
  };
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

double _progress(HomeMissionSummary summary) {
  return summary.percentage.clamp(0.0, 1.0).toDouble();
}
