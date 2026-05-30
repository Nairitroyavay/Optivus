import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/models/tracker_models.dart';

class FitnessSummaryCard extends StatelessWidget {
  final FitnessCenterState state;

  const FitnessSummaryCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 28,
      opacity: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today Body Score',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Movement, activity time, steps, and workout status.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.sub.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 74,
                height: 74,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 74,
                      height: 74,
                      child: CircularProgressIndicator(
                        value: state.bodyScorePercent / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.78),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          OptivusColors.trackerAccent,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '${state.bodyScorePercent}%',
                      style: const TextStyle(
                        color: OptivusColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final statWidth = isWide
                  ? (constraints.maxWidth - 18) / 3
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SummaryStat(
                    width: statWidth,
                    icon: Icons.route_rounded,
                    label: 'Distance',
                    value: '${state.todayDistanceKm.toStringAsFixed(1)} km',
                  ),
                  _SummaryStat(
                    width: statWidth,
                    icon: Icons.timer_rounded,
                    label: 'Active Time',
                    value: '${state.todayActiveMinutes} min',
                  ),
                  _SummaryStat(
                    width: statWidth,
                    icon: Icons.local_fire_department_rounded,
                    label: 'Calories',
                    value: '${state.todayCalories} kcal',
                  ),
                  _SummaryStat(
                    width: statWidth,
                    icon: Icons.directions_walk_rounded,
                    label: 'Steps',
                    value: _formatCount(state.todaySteps),
                  ),
                  _SummaryStat(
                    width: statWidth,
                    icon: Icons.fitness_center_rounded,
                    label: 'Workout',
                    value: state.workoutStatus,
                  ),
                  _SummaryStat(
                    width: statWidth,
                    icon: Icons.accessibility_new_rounded,
                    label: 'Body Pillar',
                    value: 'Updated',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class StartActivityCard extends StatelessWidget {
  final FitnessCenterState state;
  final ValueChanged<FitnessActivityType> onSelectType;
  final ValueChanged<String> onSelectMapStyle;
  final VoidCallback onStart;
  final VoidCallback onStartIndoor;

  const StartActivityCard({
    super.key,
    required this.state,
    required this.onSelectType,
    required this.onSelectMapStyle,
    required this.onStart,
    required this.onStartIndoor,
  });

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedActivityType;
    final accent = fitnessAccentFor(selected);
    final gpsStatus = selected.isOutdoor
        ? 'GPS ready'
        : selected == FitnessActivityType.indoorWalk
        ? 'Indoor mode'
        : 'GPS not required';

    return TrackerGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 30,
      tint: OptivusColors.trackerCardTint.withValues(alpha: 0.72),
      opacity: 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ActivityIconBadge(type: selected, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selected.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: gpsStatus, color: accent),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                const [
                  _ActivitySelectorChip(type: FitnessActivityType.walk),
                  _ActivitySelectorChip(type: FitnessActivityType.run),
                  _ActivitySelectorChip(type: FitnessActivityType.cycling),
                  _ActivitySelectorChip(type: FitnessActivityType.freeWorkout),
                  _ActivitySelectorChip(type: FitnessActivityType.stretch),
                  _ActivitySelectorChip(type: FitnessActivityType.custom),
                ].map((chip) {
                  final isSelected =
                      chip.type == selected ||
                      (chip.type == FitnessActivityType.freeWorkout &&
                          selected == FitnessActivityType.strengthWorkout);
                  return GestureDetector(
                    onTap: () => onSelectType(chip.type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  fitnessAccentFor(chip.type),
                                  fitnessAccentFor(
                                    chip.type,
                                  ).withValues(alpha: 0.78),
                                ],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.75)
                              : Colors.white.withValues(alpha: 0.95),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: fitnessAccentFor(
                                    chip.type,
                                  ).withValues(alpha: 0.24),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            fitnessIconFor(chip.type),
                            size: 15,
                            color: isSelected
                                ? Colors.white
                                : OptivusColors.ink,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            chip.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? Colors.white
                                  : OptivusColors.ink.withValues(alpha: 0.86),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth < 410
                  ? (constraints.maxWidth - 10) / 2
                  : (constraints.maxWidth - 30) / 4;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PreStartMetric(
                    width: width,
                    label: 'Distance',
                    value: '0.00 km',
                  ),
                  _PreStartMetric(width: width, label: 'Time', value: '00:00'),
                  _PreStartMetric(
                    width: width,
                    label: selected == FitnessActivityType.cycling
                        ? 'Speed'
                        : 'Pace',
                    value: selected == FitnessActivityType.cycling
                        ? '-- km/h'
                        : '-- /km',
                  ),
                  _PreStartMetric(width: width, label: 'Calories', value: '--'),
                ],
              );
            },
          ),
          if (selected.isOutdoor) ...[
            const SizedBox(height: 16),
            const Text(
              'Map Style',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: OptivusColors.sub,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: fitnessMapStyles.map((style) {
                  final isSelected = style.id == state.selectedMapStyleId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onSelectMapStyle(style.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? accent.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        child: Text(
                          style.label,
                          style: TextStyle(
                            color: isSelected ? accent : OptivusColors.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FitnessPrimaryButton(
                  label: 'Start',
                  icon: Icons.play_arrow_rounded,
                  color: accent,
                  onTap: onStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FitnessOutlineButton(
                  label: 'Indoor Activity',
                  icon: Icons.home_work_rounded,
                  onTap: onStartIndoor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ActivityTypeCards extends StatelessWidget {
  final FitnessActivityType selectedType;
  final ValueChanged<FitnessActivityType> onSelect;

  const ActivityTypeCards({
    super.key,
    required this.selectedType,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cards = const [
      ActivityTypeInfo(
        type: FitnessActivityType.walk,
        title: 'Outdoor Walk',
        description: 'Easy movement, steps, distance, route.',
      ),
      ActivityTypeInfo(
        type: FitnessActivityType.run,
        title: 'Outdoor Run',
        description: 'Pace, splits, route, personal records.',
      ),
      ActivityTypeInfo(
        type: FitnessActivityType.cycling,
        title: 'Cycling',
        description: 'Speed, distance, route, elevation.',
      ),
      ActivityTypeInfo(
        type: FitnessActivityType.strengthWorkout,
        title: 'Strength Workout',
        description: 'Sets, reps, time, body progress.',
      ),
      ActivityTypeInfo(
        type: FitnessActivityType.stretch,
        title: 'Stretch / Mobility',
        description: 'Recovery, flexibility, calm body.',
      ),
      ActivityTypeInfo(
        type: FitnessActivityType.custom,
        title: 'Custom Activity',
        description: 'Track your own movement.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((info) {
            return SizedBox(
              width: width,
              child: ActivityTypeCard(
                info: info,
                isSelected: selectedType == info.type,
                onTap: () => onSelect(info.type),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class ActivityTypeCard extends StatelessWidget {
  final ActivityTypeInfo info;
  final bool isSelected;
  final VoidCallback onTap;

  const ActivityTypeCard({
    super.key,
    required this.info,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = fitnessAccentFor(info.type);
    return GestureDetector(
      onTap: onTap,
      child: TrackerGlassCard(
        padding: const EdgeInsets.all(14),
        radius: 22,
        opacity: isSelected ? 0.78 : 0.58,
        tint: isSelected
            ? accent.withValues(alpha: 0.13)
            : Colors.white.withValues(alpha: 0.58),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ActivityIconBadge(type: info.type, size: 42),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 20, color: accent),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              info.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: OptivusColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              info.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: OptivusColors.sub,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MovementGraphCard extends StatelessWidget {
  final FitnessCenterState state;
  final ValueChanged<String> onMetricSelected;

  const MovementGraphCard({
    super.key,
    required this.state,
    required this.onMetricSelected,
  });

  @override
  Widget build(BuildContext context) {
    final metric = state.selectedGraphMetric;
    final values = state.weeklyMetrics
        .map((point) => point.valueFor(metric))
        .toList(growable: false);
    final labels = state.weeklyMetrics
        .map((point) => point.label)
        .toList(growable: false);
    final maxValue = values.fold<double>(
      0,
      (current, value) => math.max(current, value),
    );

    return TrackerGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 28,
      opacity: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Movement This Week',
                      style: TextStyle(
                        color: OptivusColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Distance, active minutes, sessions, and body trend.',
                      style: TextStyle(
                        color: OptivusColors.sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                label:
                    '${state.weeklyDistanceKm.toStringAsFixed(1)} / ${state.weeklyDistanceGoalKm.toStringAsFixed(0)} km',
                color: OptivusColors.trackerAccent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          TrackerSegmentedControl(
            segments: const ['Distance', 'Time', 'Calories', 'Sessions'],
            selectedSegment: metric,
            onSegmentSelected: onMetricSelected,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 164,
            child: CustomPaint(
              painter: _MovementChartPainter(
                labels: labels,
                values: values,
                bodyTrend: state.weeklyMetrics
                    .map((point) => point.bodyScore)
                    .toList(growable: false),
                maxValue: maxValue == 0 ? 1 : maxValue,
                accent: OptivusColors.trackerAccent,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TrackerMetricChip(
                category: 'Distance',
                value: '${state.weeklyDistanceKm.toStringAsFixed(1)} km',
              ),
              TrackerMetricChip(
                category: 'Active',
                value: '${state.activeMinutesThisWeek} min',
              ),
              TrackerMetricChip(
                category: 'Sessions',
                value: '${state.workoutSessionsThisWeek}',
              ),
              TrackerMetricChip(
                category: 'Best pace',
                value: state.bestPaceLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RecentActivityCard extends StatelessWidget {
  final FitnessActivity activity;
  final VoidCallback onTap;

  const RecentActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = fitnessAccentFor(activity.activityType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: TrackerGlassCard(
          padding: const EdgeInsets.all(14),
          radius: 22,
          opacity: 0.66,
          child: Row(
            children: [
              _ActivityIconBadge(type: activity.activityType, size: 48),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activitySubtitle(activity),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OptivusColors.sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _dateLabel(activity.startedAt),
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 78,
                height: 58,
                child: activity.isOutdoor
                    ? FitnessRouteMapPreview(
                        activity: activity,
                        showDot: false,
                        compact: true,
                      )
                    : _WorkoutMiniPreview(activity: activity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PersonalRecordsCard extends StatelessWidget {
  final List<FitnessRecord> records;

  const PersonalRecordsCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final items = [
      _RecordItem('Longest Run', '5.2 km', Icons.social_distance_rounded),
      _RecordItem('Best Pace', '6\'55"/km', Icons.speed_rounded),
      _RecordItem('Longest Walk', '7.4 km', Icons.directions_walk_rounded),
      _RecordItem('Best Week', '18.6 km', Icons.calendar_view_week_rounded),
    ];
    return TrackerGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 26,
      opacity: 0.66,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Records',
            style: TextStyle(
              color: OptivusColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: items
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: _RecordTile(item: item),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FitnessGoalsCard extends StatelessWidget {
  final List<FitnessGoal> goals;
  final VoidCallback onEditGoals;
  final VoidCallback onTinyVersion;

  const FitnessGoalsCard({
    super.key,
    required this.goals,
    required this.onEditGoals,
    required this.onTinyVersion,
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
              const Expanded(
                child: Text(
                  'Fitness Goals',
                  style: TextStyle(
                    color: OptivusColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusBadge(
                label: 'Weekly Goal',
                color: OptivusColors.trackerAccent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...goals.map(
            (goal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GoalProgressRow(goal: goal),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FitnessOutlineButton(
                  label: 'Edit Goals',
                  icon: Icons.tune_rounded,
                  onTap: onEditGoals,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FitnessPrimaryButton(
                  label: 'Tiny Version',
                  icon: Icons.bolt_rounded,
                  color: OptivusColors.trackerAccent,
                  onTap: onTinyVersion,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FitnessInsightsCard extends StatelessWidget {
  final List<FitnessInsight> insights;

  const FitnessInsightsCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 26,
      opacity: 0.66,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fitness Insights',
            style: TextStyle(
              color: OptivusColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: OptivusColors.trackerAccent.withValues(
                        alpha: 0.14,
                      ),
                      border: Border.all(
                        color: OptivusColors.trackerAccent.withValues(
                          alpha: 0.28,
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      size: 15,
                      color: OptivusColors.trackerAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: const TextStyle(
                            color: OptivusColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          insight.message,
                          style: const TextStyle(
                            color: OptivusColors.sub,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ],
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

class FitnessDataSourcesCard extends StatelessWidget {
  final VoidCallback onLocation;
  final VoidCallback onHealthConnect;
  final VoidCallback onManual;

  const FitnessDataSourcesCard({
    super.key,
    required this.onLocation,
    required this.onHealthConnect,
    required this.onManual,
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
          const Text(
            'Fitness Data Sources',
            style: TextStyle(
              color: OptivusColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Health Connect only shares data from connected apps or devices after permission.',
            style: TextStyle(
              color: OptivusColors.sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _DataSourceRow(
            title: 'GPS Location',
            status: 'Permission needed',
            usedFor: 'route, distance, pace, speed',
            icon: Icons.location_on_rounded,
            connected: false,
            onTap: onLocation,
          ),
          _DataSourceRow(
            title: 'Health Connect',
            status: 'Not connected',
            usedFor: 'steps, calories, heart rate, sleep, workouts',
            icon: Icons.favorite_rounded,
            connected: false,
            onTap: onHealthConnect,
          ),
          _DataSourceRow(
            title: 'Manual Entry',
            status: 'Always available',
            usedFor: 'indoor workouts, custom sessions',
            icon: Icons.edit_note_rounded,
            connected: true,
            onTap: onManual,
          ),
        ],
      ),
    );
  }
}

class FitnessRouteMapPreview extends StatelessWidget {
  final FitnessActivity? activity;
  final bool showDot;
  final bool compact;

  const FitnessRouteMapPreview({
    super.key,
    this.activity,
    this.showDot = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 16 : 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              OptivusColors.trackerTop.withValues(alpha: 0.9),
              OptivusColors.trackerBottom,
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RoutePreviewPainter(
                  accent: activity == null
                      ? OptivusColors.trackerAccent
                      : fitnessAccentFor(activity!.activityType),
                  compact: compact,
                  showDot: showDot,
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ),
            if (!compact)
              Positioned(
                right: 12,
                bottom: 12,
                child: _StatusBadge(
                  label: 'Route preview',
                  color: OptivusColors.trackerAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FitnessPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const FitnessPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.78)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FitnessOutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const FitnessOutlineButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: OptivusColors.ink, size: 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: OptivusColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FitnessStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const FitnessStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _SummaryStat(
      width: double.infinity,
      icon: icon,
      label: label,
      value: value,
    );
  }
}

Color fitnessAccentFor(FitnessActivityType type) {
  return switch (type) {
    FitnessActivityType.walk => OptivusColors.trackerAccent,
    FitnessActivityType.run => OptivusColors.blueAccent,
    FitnessActivityType.cycling => OptivusColors.tealAccent,
    FitnessActivityType.indoorWalk => OptivusColors.trackerAccent,
    FitnessActivityType.freeWorkout => OptivusColors.purpleAccent,
    FitnessActivityType.strengthWorkout => OptivusColors.purpleAccent,
    FitnessActivityType.stretch => OptivusColors.mintAccent,
    FitnessActivityType.custom => OptivusColors.ink,
  };
}

IconData fitnessIconFor(FitnessActivityType type) {
  return switch (type) {
    FitnessActivityType.walk => Icons.directions_walk_rounded,
    FitnessActivityType.run => Icons.directions_run_rounded,
    FitnessActivityType.cycling => Icons.directions_bike_rounded,
    FitnessActivityType.indoorWalk => Icons.home_work_rounded,
    FitnessActivityType.freeWorkout => Icons.timer_rounded,
    FitnessActivityType.strengthWorkout => Icons.fitness_center_rounded,
    FitnessActivityType.stretch => Icons.self_improvement_rounded,
    FitnessActivityType.custom => Icons.add_circle_outline_rounded,
  };
}

String fitnessDurationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String fitnessPaceLabel(double pace) {
  if (pace <= 0 || pace.isNaN || pace.isInfinite) return '-- /km';
  final minutes = pace.floor();
  final seconds = ((pace - minutes) * 60).round().clamp(0, 59);
  return '$minutes\'${seconds.toString().padLeft(2, '0')}"/km';
}

String fitnessSpeedLabel(double? speed) {
  if (speed == null || speed <= 0) return '-- km/h';
  return '${speed.toStringAsFixed(1)} km/h';
}

String fitnessDistanceLabel(FitnessActivity activity) {
  if (activity.distanceKm <= 0) {
    return '${activity.movingDuration.inMinutes} min';
  }
  return '${activity.distanceKm.toStringAsFixed(2)} km';
}

class _SummaryStat extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;

  const _SummaryStat({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OptivusColors.trackerAccent.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 16, color: OptivusColors.trackerAccent),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OptivusColors.sub,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OptivusColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityIconBadge extends StatelessWidget {
  final FitnessActivityType type;
  final double size;

  const _ActivityIconBadge({required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    final accent = fitnessAccentFor(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.88),
            accent.withValues(alpha: 0.16),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(fitnessIconFor(type), color: accent, size: size * 0.45),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActivitySelectorChip {
  final FitnessActivityType type;

  const _ActivitySelectorChip({required this.type});

  String get label {
    return switch (type) {
      FitnessActivityType.freeWorkout => 'Workout',
      FitnessActivityType.stretch => 'Stretch',
      FitnessActivityType.walk => 'Walk',
      FitnessActivityType.run => 'Run',
      _ => type.shortLabel,
    };
  }
}

class _PreStartMetric extends StatelessWidget {
  final double width;
  final String label;
  final String value;

  const _PreStartMetric({
    required this.width,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: OptivusColors.sub,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: OptivusColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityTypeInfo {
  final FitnessActivityType type;
  final String title;
  final String description;

  const ActivityTypeInfo({
    required this.type,
    required this.title,
    required this.description,
  });
}

class _MovementChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final List<double> bodyTrend;
  final double maxValue;
  final Color accent;

  const _MovementChartPainter({
    required this.labels,
    required this.values,
    required this.bodyTrend,
    required this.maxValue,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    final barPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent, accent.withValues(alpha: 0.48)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    final chartHeight = size.height - 28;
    final spacing = size.width / values.length;
    final barWidth = math.min(22.0, spacing * 0.38);
    final trendPoints = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final centerX = spacing * i + spacing / 2;
      final trackRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, chartHeight / 2),
          width: barWidth,
          height: chartHeight,
        ),
        const Radius.circular(12),
      );
      canvas.drawRRect(trackRect, trackPaint);

      final barHeight = (values[i] / maxValue * chartHeight).clamp(
        5.0,
        chartHeight,
      );
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barWidth / 2,
          chartHeight - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(12),
      );
      canvas.drawRRect(barRect, barPaint);

      final trendY = chartHeight - (bodyTrend[i] / 100 * chartHeight);
      trendPoints.add(Offset(centerX, trendY));

      labelPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(
          color: OptivusColors.sub,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      );
      labelPainter.layout(minWidth: spacing);
      labelPainter.paint(canvas, Offset(spacing * i, size.height - 18));
    }

    if (trendPoints.length > 1) {
      final linePaint = Paint()
        ..color = OptivusColors.ink.withValues(alpha: 0.34)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(trendPoints.first.dx, trendPoints.first.dy);
      for (final point in trendPoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, linePaint);

      final dotPaint = Paint()
        ..color = OptivusColors.ink.withValues(alpha: 0.5);
      for (final point in trendPoints) {
        canvas.drawCircle(point, 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MovementChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.bodyTrend != bodyTrend ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.accent != accent;
  }
}

class _RoutePreviewPainter extends CustomPainter {
  final Color accent;
  final bool compact;
  final bool showDot;

  const _RoutePreviewPainter({
    required this.accent,
    required this.compact,
    required this.showDot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.56)
      ..strokeWidth = 1;
    final step = compact ? 22.0 : 34.0;
    for (double x = -step; x < size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + step, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final route = Path()
      ..moveTo(size.width * 0.16, size.height * 0.72)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.48,
        size.width * 0.42,
        size.height * 0.78,
        size.width * 0.52,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.1,
        size.width * 0.8,
        size.height * 0.28,
        size.width * 0.86,
        size.height * 0.18,
      );
    final underPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = compact ? 7 : 10;
    final routePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = compact ? 3 : 5;
    canvas.drawPath(route, underPaint);
    canvas.drawPath(route, routePaint);

    if (showDot) {
      final dot = Offset(size.width * 0.86, size.height * 0.18);
      canvas.drawCircle(dot, compact ? 6 : 9, Paint()..color = Colors.white);
      canvas.drawCircle(dot, compact ? 4 : 6, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.compact != compact ||
        oldDelegate.showDot != showDot;
  }
}

class _WorkoutMiniPreview extends StatelessWidget {
  final FitnessActivity activity;

  const _WorkoutMiniPreview({required this.activity});

  @override
  Widget build(BuildContext context) {
    final accent = fitnessAccentFor(activity.activityType);
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(fitnessIconFor(activity.activityType), color: accent, size: 20),
          const SizedBox(height: 4),
          Text(
            '${activity.exercisesCompleted} ex',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordItem {
  final String label;
  final String value;
  final IconData icon;

  const _RecordItem(this.label, this.value, this.icon);
}

class _RecordTile extends StatelessWidget {
  final _RecordItem item;

  const _RecordTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: OptivusColors.trackerAccent, size: 19),
          const SizedBox(height: 9),
          Text(
            item.value,
            style: const TextStyle(
              color: OptivusColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: OptivusColors.sub,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalProgressRow extends StatelessWidget {
  final FitnessGoal goal;

  const _GoalProgressRow({required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = (goal.currentValue / goal.targetValue).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _goalTitle(goal.goalType),
                style: const TextStyle(
                  color: OptivusColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${_formatGoalValue(goal.currentValue)} / ${_formatGoalValue(goal.targetValue)} ${goal.unit}',
              style: const TextStyle(
                color: OptivusColors.sub,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.76),
            valueColor: const AlwaysStoppedAnimation<Color>(
              OptivusColors.trackerAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _DataSourceRow extends StatelessWidget {
  final String title;
  final String status;
  final String usedFor;
  final IconData icon;
  final bool connected;
  final VoidCallback onTap;

  const _DataSourceRow({
    required this.title,
    required this.status,
    required this.usedFor,
    required this.icon,
    required this.connected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = connected ? OptivusColors.success : OptivusColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: OptivusColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Used for: $usedFor',
                      style: const TextStyle(
                        color: OptivusColors.sub,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(label: status, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatCount(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String _activitySubtitle(FitnessActivity activity) {
  if (activity.isOutdoor) {
    final paceOrSpeed = activity.activityType == FitnessActivityType.cycling
        ? fitnessSpeedLabel(activity.avgSpeed)
        : fitnessPaceLabel(activity.paceMinutesPerKm);
    return '${activity.distanceKm.toStringAsFixed(2)} km • ${fitnessDurationLabel(activity.movingDuration)} • $paceOrSpeed';
  }
  return '${activity.movingDuration.inMinutes} min • ${activity.exercisesCompleted} exercises • ${activity.setsCompleted} sets';
}

String _dateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = today.difference(target).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return '${date.month}/${date.day}/${date.year}';
}

String _goalTitle(FitnessGoalType type) {
  return switch (type) {
    FitnessGoalType.distance => 'Weekly distance goal',
    FitnessGoalType.activeMinutes => 'Active minutes goal',
    FitnessGoalType.calories => 'Calories goal',
    FitnessGoalType.steps => 'Steps goal',
    FitnessGoalType.workoutSessions => 'Workout sessions goal',
  };
}

String _formatGoalValue(double value) {
  if (value >= 1000) return value.toStringAsFixed(0);
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
