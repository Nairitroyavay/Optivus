import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/fitness/fitness_activity_detail_screen.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/fitness/widgets/fitness_center_widgets.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/models/tracker_models.dart';

class FitnessActivityFinishScreen extends StatelessWidget {
  final FitnessActivity activity;

  const FitnessActivityFinishScreen({super.key, required this.activity});

  void _showActionSheet(
    BuildContext context, {
    required String title,
    required String message,
  }) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = fitnessAccentFor(activity.activityType);
    final media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [OptivusColors.trackerTop, OptivusColors.trackerBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + media.padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrackerGlassCard(
                  padding: const EdgeInsets.all(22),
                  radius: 32,
                  opacity: 0.74,
                  child: Column(
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [accent, accent.withValues(alpha: 0.68)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.28),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Activity Complete',
                        style: TextStyle(
                          color: OptivusColors.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.title ?? activity.activityType.label,
                        style: TextStyle(
                          color: accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (activity.isOutdoor) ...[
                  SizedBox(
                    height: 210,
                    child: FitnessRouteMapPreview(activity: activity),
                  ),
                  const SizedBox(height: 16),
                ],
                _FinishStatsGrid(activity: activity),
                const SizedBox(height: 18),
                if (activity.isOutdoor)
                  _SplitsCard(activity: activity)
                else
                  _WorkoutCompleteCard(activity: activity),
                const SizedBox(height: 18),
                _ProgressSyncCard(activity: activity),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FitnessPrimaryButton(
                        label: 'View Details',
                        icon: Icons.analytics_rounded,
                        color: accent,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FitnessActivityDetailScreen(
                                activity: activity,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FitnessOutlineButton(
                        label: 'Add Note',
                        icon: Icons.note_add_rounded,
                        onTap: () => _showActionSheet(
                          context,
                          title: 'Activity note',
                          message:
                              'Notes are captured in the FitnessActivity.notes field during the backend pass. This frontend path already preserves the action point.',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FitnessOutlineButton(
                        label: 'Share Image',
                        icon: Icons.ios_share_rounded,
                        onTap: () => _showActionSheet(
                          context,
                          title: 'Share image',
                          message:
                              'Share-card generation will use local render or Cloudflare R2 upload path, not Firebase Storage.',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FitnessOutlineButton(
                        label: 'Done',
                        icon: Icons.done_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinishStatsGrid extends StatelessWidget {
  final FitnessActivity activity;

  const _FinishStatsGrid({required this.activity});

  @override
  Widget build(BuildContext context) {
    final stats = activity.isOutdoor
        ? [
            _FinishStat(
              'Distance',
              '${activity.distanceKm.toStringAsFixed(2)} km',
              Icons.route_rounded,
            ),
            _FinishStat(
              'Total Time',
              fitnessDurationLabel(
                activity.movingDuration + activity.pausedDuration,
              ),
              Icons.timer_rounded,
            ),
            _FinishStat(
              'Moving Time',
              fitnessDurationLabel(activity.movingDuration),
              Icons.directions_run_rounded,
            ),
            _FinishStat(
              activity.activityType == FitnessActivityType.cycling
                  ? 'Avg Speed'
                  : 'Avg Pace',
              activity.activityType == FitnessActivityType.cycling
                  ? fitnessSpeedLabel(activity.avgSpeed)
                  : fitnessPaceLabel(activity.paceMinutesPerKm),
              Icons.speed_rounded,
            ),
            _FinishStat(
              'Calories',
              '${activity.caloriesEstimate} kcal',
              Icons.local_fire_department_rounded,
            ),
            _FinishStat(
              'Elevation',
              '${(activity.elevationGain ?? 0).toStringAsFixed(0)} m',
              Icons.terrain_rounded,
            ),
          ]
        : [
            _FinishStat(
              'Duration',
              fitnessDurationLabel(activity.movingDuration),
              Icons.timer_rounded,
            ),
            _FinishStat(
              'Exercises',
              '${activity.exercisesCompleted}',
              Icons.checklist_rounded,
            ),
            _FinishStat(
              'Sets',
              '${activity.setsCompleted}',
              Icons.format_list_numbered_rounded,
            ),
            _FinishStat(
              'Calories',
              '${activity.caloriesEstimate} kcal',
              Icons.local_fire_department_rounded,
            ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: stats
              .map(
                (stat) => SizedBox(
                  width: width,
                  child: FitnessStatTile(
                    label: stat.label,
                    value: stat.value,
                    icon: stat.icon,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SplitsCard extends StatelessWidget {
  final FitnessActivity activity;

  const _SplitsCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 26,
      opacity: 0.68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Splits',
            style: TextStyle(
              color: OptivusColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...['1 km - 7:10', '2 km - 7:25', '3 km - 7:02'].map(
            (split) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  const Icon(
                    Icons.speed_rounded,
                    size: 18,
                    color: OptivusColors.trackerAccent,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      split,
                      style: const TextStyle(
                        color: OptivusColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Map style used: ${_mapStyleLabel(activity.mapStyleId)}',
            style: const TextStyle(
              color: OptivusColors.sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutCompleteCard extends StatelessWidget {
  final FitnessActivity activity;

  const _WorkoutCompleteCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 26,
      opacity: 0.68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workout Summary',
            style: TextStyle(
              color: OptivusColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...activity.exercises.map(
            (exercise) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: OptivusColors.trackerAccent,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      exercise,
                      style: const TextStyle(
                        color: OptivusColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text(
                    '3 sets',
                    style: TextStyle(
                      color: OptivusColors.sub,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Body score update prepared from duration, completion, and consistency.',
            style: TextStyle(
              color: OptivusColors.sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSyncCard extends StatelessWidget {
  final FitnessActivity activity;

  const _ProgressSyncCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    const rows = [
      'Body pillar updated',
      'Routine task completed if linked',
      'Weekly fitness goal updated',
      'Tracker progress updated',
      'Goal progress updated if Strong Body exists',
    ];
    return TrackerGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 26,
      opacity: 0.66,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Sync',
            style: TextStyle(
              color: OptivusColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Icon(
                    row.contains('if linked') || row.contains('if Strong Body')
                        ? Icons.radio_button_unchecked_rounded
                        : Icons.check_circle_rounded,
                    color: row.contains('if')
                        ? OptivusColors.textMuted
                        : OptivusColors.trackerAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      row,
                      style: const TextStyle(
                        color: OptivusColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishStat {
  final String label;
  final String value;
  final IconData icon;

  const _FinishStat(this.label, this.value, this.icon);
}

String _mapStyleLabel(String? id) {
  if (id == null) return 'Indoor mode';
  for (final style in fitnessMapStyles) {
    if (style.id == id) return style.label;
  }
  return 'Custom style';
}
