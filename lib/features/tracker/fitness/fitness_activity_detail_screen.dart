import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/fitness/widgets/fitness_center_widgets.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/models/tracker_models.dart';

class FitnessActivityDetailScreen extends StatelessWidget {
  final FitnessActivity activity;

  const FitnessActivityDetailScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final accent = fitnessAccentFor(activity.activityType);
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: TrackerGlassCard(
                  padding: const EdgeInsets.all(12),
                  radius: 24,
                  opacity: 0.74,
                  child: Row(
                    children: [
                      TrackerHeaderButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title ?? activity.activityType.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: OptivusColors.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activity.activityType.label,
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        fitnessIconFor(activity.activityType),
                        color: accent,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                  child: activity.isOutdoor
                      ? _OutdoorDetail(activity: activity)
                      : _WorkoutDetail(activity: activity),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutdoorDetail extends StatelessWidget {
  final FitnessActivity activity;

  const _OutdoorDetail({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 230,
          child: FitnessRouteMapPreview(activity: activity),
        ),
        const SizedBox(height: 18),
        _StatsGrid(
          stats: [
            _DetailStat(
              'Distance',
              '${activity.distanceKm.toStringAsFixed(2)} km',
              Icons.route_rounded,
            ),
            _DetailStat(
              'Time',
              fitnessDurationLabel(activity.movingDuration),
              Icons.timer_rounded,
            ),
            _DetailStat(
              activity.activityType == FitnessActivityType.cycling
                  ? 'Avg Speed'
                  : 'Avg Pace',
              activity.activityType == FitnessActivityType.cycling
                  ? fitnessSpeedLabel(activity.avgSpeed)
                  : fitnessPaceLabel(activity.paceMinutesPerKm),
              Icons.speed_rounded,
            ),
            _DetailStat(
              'Calories',
              '${activity.caloriesEstimate} kcal',
              Icons.local_fire_department_rounded,
            ),
            _DetailStat(
              'Moving Time',
              fitnessDurationLabel(activity.movingDuration),
              Icons.directions_run_rounded,
            ),
            _DetailStat(
              'Paused Time',
              fitnessDurationLabel(activity.pausedDuration),
              Icons.pause_circle_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SplitsList(),
        const SizedBox(height: 18),
        _GraphPlaceholder(
          title: 'Pace Graph',
          subtitle: 'Minute-by-minute pace will render here.',
          icon: Icons.show_chart_rounded,
        ),
        const SizedBox(height: 14),
        _GraphPlaceholder(
          title: 'Elevation Graph',
          subtitle: 'Elevation gain and terrain profile placeholder.',
          icon: Icons.terrain_rounded,
        ),
        const SizedBox(height: 18),
        const _NotesAndImpact(
          title: 'Body Progress Impact',
          body:
              'Body pillar updated from movement time, completed distance, and weekly consistency.',
          badge: 'Record-ready',
        ),
      ],
    );
  }
}

class _WorkoutDetail extends StatelessWidget {
  final FitnessActivity activity;

  const _WorkoutDetail({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerGlassCard(
          padding: const EdgeInsets.all(22),
          radius: 30,
          opacity: 0.72,
          child: Column(
            children: [
              Text(
                fitnessDurationLabel(activity.movingDuration),
                style: const TextStyle(
                  color: OptivusColors.ink,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Timer summary',
                style: TextStyle(
                  color: OptivusColors.sub,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _StatsGrid(
          stats: [
            _DetailStat(
              'Exercises',
              '${activity.exercisesCompleted}',
              Icons.checklist_rounded,
            ),
            _DetailStat(
              'Sets',
              '${activity.setsCompleted}',
              Icons.format_list_numbered_rounded,
            ),
            _DetailStat(
              'Calories',
              '${activity.caloriesEstimate} kcal',
              Icons.local_fire_department_rounded,
            ),
            _DetailStat('Consistency', 'Good', Icons.verified_rounded),
          ],
        ),
        const SizedBox(height: 18),
        TrackerGlassCard(
          padding: const EdgeInsets.all(18),
          radius: 26,
          opacity: 0.68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Exercises',
                style: TextStyle(
                  color: OptivusColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ...activity.exercises.map(
                (exercise) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: OptivusColors.trackerAccent,
                        size: 18,
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
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _NotesAndImpact(
          title: 'Body Progress Impact',
          body:
              'Workout consistency score updated from completed exercises, sets, and active time.',
          badge: 'Consistency +',
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<_DetailStat> stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
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

class _SplitsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const splits = ['1 km - 7:10', '2 km - 7:25', '3 km - 7:02'];
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
          ...splits.map(
            (split) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  const Icon(
                    Icons.speed_rounded,
                    color: OptivusColors.trackerAccent,
                    size: 18,
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
        ],
      ),
    );
  }
}

class _GraphPlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _GraphPlaceholder({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 26,
      opacity: 0.66,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: OptivusColors.trackerAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: OptivusColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: OptivusColors.sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final height = 20.0 + index * 7.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      height: height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            OptivusColors.trackerAccent,
                            OptivusColors.trackerAccent.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesAndImpact extends StatelessWidget {
  final String title;
  final String body;
  final String badge;

  const _NotesAndImpact({
    required this.title,
    required this.body,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 26,
      opacity: 0.68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: OptivusColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: OptivusColors.trackerAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: OptivusColors.trackerAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: OptivusColors.sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.notes_rounded,
                  color: OptivusColors.trackerAccent,
                  size: 18,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Notes can be added after completion and synced to history.',
                    style: TextStyle(
                      color: OptivusColors.sub,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStat {
  final String label;
  final String value;
  final IconData icon;

  const _DetailStat(this.label, this.value, this.icon);
}
