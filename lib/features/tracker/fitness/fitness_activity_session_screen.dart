import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/fitness/widgets/fitness_center_widgets.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/models/tracker_models.dart';

class FitnessActivitySessionScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<FitnessActivity>? onFinished;

  const FitnessActivitySessionScreen({super.key, this.onBack, this.onFinished});

  @override
  ConsumerState<FitnessActivitySessionScreen> createState() =>
      _FitnessActivitySessionScreenState();
}

class _FitnessActivitySessionScreenState
    extends ConsumerState<FitnessActivitySessionScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _locked = false;
  late List<bool> _exerciseChecks;

  @override
  void initState() {
    super.initState();
    final active = ref.read(fitnessCenterProvider).activeActivity;
    _exerciseChecks = List<bool>.filled(_exerciseCount(active), false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(fitnessCenterProvider).activeActivity;
      if (current == null) {
        final started = ref
            .read(fitnessCenterProvider.notifier)
            .startSelectedActivity();
        setState(() {
          _exerciseChecks = List<bool>.filled(_exerciseCount(started), false);
        });
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final active = ref.read(fitnessCenterProvider).activeActivity;
      if (active?.status == FitnessActivityStatus.active) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish() {
    final completed = ref
        .read(fitnessCenterProvider.notifier)
        .finishActiveActivity(
          elapsedSeconds: _elapsedSeconds,
          completedExercises: _exerciseChecks
              .where((checked) => checked)
              .length,
          setsCompleted: _exerciseChecks.where((checked) => checked).isEmpty
              ? null
              : 3,
        );
    if (completed == null || !mounted) return;
    if (widget.onFinished != null) {
      widget.onFinished!(completed);
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _discard() {
    ref.read(fitnessCenterProvider.notifier).discardActiveActivity();
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fitnessCenterProvider);
    final active = state.activeActivity;
    if (active == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              OptivusColors.trackerAccent,
            ),
          ),
        ),
      );
    }

    final activeExerciseCount = _exerciseCount(active);
    if (_exerciseChecks.length != activeExerciseCount) {
      _exerciseChecks = List<bool>.filled(activeExerciseCount, false);
    }

    return active.activityType.isOutdoor
        ? _buildOutdoorSession(context, state, active)
        : _buildIndoorSession(context, state, active);
  }

  Widget _buildOutdoorSession(
    BuildContext context,
    FitnessCenterState state,
    FitnessActivity active,
  ) {
    final accent = fitnessAccentFor(active.activityType);
    final simulatedDistance = _simulatedDistance(active.activityType);
    final pace = simulatedDistance <= 0 || _elapsedSeconds <= 0
        ? 0.0
        : (_elapsedSeconds / 60) / simulatedDistance;

    // Native pass: Android long-running outdoor sessions need a foreground
    // service before production GPS/background tracking is connected.
    return Scaffold(
      backgroundColor: OptivusColors.trackerBottom,
      body: Stack(
        children: [
          Positioned.fill(
            child: FitnessRouteMapPreview(activity: active, showDot: true),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    OptivusColors.trackerTop.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.04),
                    OptivusColors.ink.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  _SessionTopBar(
                    title: active.activityType.label,
                    subtitle: 'Outdoor route tracking',
                    accent: accent,
                    onBack:
                        widget.onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 14),
                  _OutdoorStatsPanel(
                    distanceLabel: '${simulatedDistance.toStringAsFixed(2)} km',
                    timeLabel: fitnessDurationLabel(
                      Duration(seconds: _elapsedSeconds),
                    ),
                    paceLabel:
                        active.activityType == FitnessActivityType.cycling
                        ? fitnessSpeedLabel(
                            _simulatedSpeed(active.activityType),
                          )
                        : fitnessPaceLabel(pace),
                    caloriesLabel:
                        '${_simulatedCalories(active.activityType)} kcal',
                    accent: accent,
                  ),
                  const Spacer(),
                  _MapStylePanel(
                    selectedMapStyleId: state.selectedMapStyleId,
                    onSelect: ref
                        .read(fitnessCenterProvider.notifier)
                        .selectMapStyle,
                    accent: accent,
                  ),
                  const SizedBox(height: 12),
                  _OutdoorControlPanel(
                    active: active,
                    locked: _locked,
                    accent: accent,
                    onPause: ref
                        .read(fitnessCenterProvider.notifier)
                        .pauseActivity,
                    onResume: ref
                        .read(fitnessCenterProvider.notifier)
                        .resumeActivity,
                    onFinish: _finish,
                    onDiscard: _discard,
                    onLock: () => setState(() => _locked = !_locked),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndoorSession(
    BuildContext context,
    FitnessCenterState state,
    FitnessActivity active,
  ) {
    final accent = fitnessAccentFor(active.activityType);
    final exercises = active.exercises.isEmpty
        ? const ['Warm-up', 'Main movement', 'Cooldown']
        : active.exercises;

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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SessionTopBar(
                  title: active.title ?? active.activityType.label,
                  subtitle: 'Indoor timer mode',
                  accent: accent,
                  onBack:
                      widget.onBack ?? () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 20),
                TrackerGlassCard(
                  padding: const EdgeInsets.all(24),
                  radius: 32,
                  opacity: 0.74,
                  child: Column(
                    children: [
                      _ActivityStatusPill(active: active, accent: accent),
                      const SizedBox(height: 18),
                      Text(
                        fitnessDurationLabel(
                          Duration(seconds: _elapsedSeconds),
                        ),
                        style: const TextStyle(
                          color: OptivusColors.ink,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        active.activityType == FitnessActivityType.stretch
                            ? 'Mobility and recovery timer'
                            : 'Workout timer with checklist',
                        style: const TextStyle(
                          color: OptivusColors.sub,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: FitnessStatTile(
                              label: 'Calories',
                              value:
                                  '${_simulatedCalories(active.activityType)} kcal',
                              icon: Icons.local_fire_department_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FitnessStatTile(
                              label: 'Sets',
                              value:
                                  '${_exerciseChecks.where((checked) => checked).isEmpty ? 0 : 3}',
                              icon: Icons.format_list_numbered_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TrackerGlassCard(
                  padding: const EdgeInsets.all(18),
                  radius: 26,
                  opacity: 0.66,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exercise Checklist',
                        style: TextStyle(
                          color: OptivusColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(exercises.length, (index) {
                        final checked = index < _exerciseChecks.length
                            ? _exerciseChecks[index]
                            : false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () {
                              if (index >= _exerciseChecks.length) return;
                              setState(() {
                                _exerciseChecks[index] =
                                    !_exerciseChecks[index];
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: checked
                                    ? accent.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: checked
                                      ? accent.withValues(alpha: 0.32)
                                      : Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    checked
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: checked
                                        ? accent
                                        : OptivusColors.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      exercises[index],
                                      style: const TextStyle(
                                        color: OptivusColors.ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
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
                        );
                      }),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.hourglass_bottom_rounded,
                              color: OptivusColors.trackerAccent,
                              size: 19,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Rest timer and workout notes are ready for production logic.',
                                style: TextStyle(
                                  color: OptivusColors.sub,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _IndoorControlPanel(
                  active: active,
                  accent: accent,
                  onPause: ref
                      .read(fitnessCenterProvider.notifier)
                      .pauseActivity,
                  onResume: ref
                      .read(fitnessCenterProvider.notifier)
                      .resumeActivity,
                  onFinish: _finish,
                  onDiscard: _discard,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _simulatedDistance(FitnessActivityType type) {
    final target = switch (type) {
      FitnessActivityType.walk => 2.41,
      FitnessActivityType.run => 3.24,
      FitnessActivityType.cycling => 2.75,
      FitnessActivityType.indoorWalk => 1.2,
      _ => 0.0,
    };
    final duration = switch (type) {
      FitnessActivityType.walk => 28 * 60 + 12,
      FitnessActivityType.run => 24 * 60 + 12,
      FitnessActivityType.cycling => 26 * 60,
      FitnessActivityType.indoorWalk => 22 * 60,
      _ => 1,
    };
    final progress = duration <= 0
        ? 0.0
        : (_elapsedSeconds / duration).clamp(0.0, 1.0);
    return target * progress;
  }

  double? _simulatedSpeed(FitnessActivityType type) {
    final distance = _simulatedDistance(type);
    if (_elapsedSeconds <= 0 || distance <= 0) return null;
    return distance / (_elapsedSeconds / 3600);
  }

  int _simulatedCalories(FitnessActivityType type) {
    final target = switch (type) {
      FitnessActivityType.walk => 142,
      FitnessActivityType.run => 258,
      FitnessActivityType.cycling => 92,
      FitnessActivityType.indoorWalk => 96,
      FitnessActivityType.freeWorkout ||
      FitnessActivityType.strengthWorkout => 170,
      FitnessActivityType.stretch => 52,
      FitnessActivityType.custom => 80,
    };
    final divisor = switch (type) {
      FitnessActivityType.walk => 28 * 60 + 12,
      FitnessActivityType.run => 24 * 60 + 12,
      FitnessActivityType.cycling => 26 * 60,
      FitnessActivityType.indoorWalk => 22 * 60,
      FitnessActivityType.freeWorkout ||
      FitnessActivityType.strengthWorkout => 32 * 60,
      FitnessActivityType.stretch => 18 * 60,
      FitnessActivityType.custom => 20 * 60,
    };
    final progress = (_elapsedSeconds / divisor).clamp(0.0, 1.0);
    return (target * progress).round();
  }

  int _exerciseCount(FitnessActivity? activity) {
    if (activity == null) return 5;
    if (activity.exercises.isNotEmpty) return activity.exercises.length;
    return activity.activityType.isOutdoor ? 0 : 3;
  }
}

class _SessionTopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onBack;

  const _SessionTopBar({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 22,
      opacity: 0.78,
      child: Row(
        children: [
          TrackerHeaderButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: OptivusColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.shield_moon_rounded, color: accent, size: 21),
        ],
      ),
    );
  }
}

class _OutdoorStatsPanel extends StatelessWidget {
  final String distanceLabel;
  final String timeLabel;
  final String paceLabel;
  final String caloriesLabel;
  final Color accent;

  const _OutdoorStatsPanel({
    required this.distanceLabel,
    required this.timeLabel,
    required this.paceLabel,
    required this.caloriesLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(14),
      radius: 24,
      opacity: 0.78,
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(label: 'Distance', value: distanceLabel),
          ),
          Expanded(
            child: _StatColumn(label: 'Time', value: timeLabel),
          ),
          Expanded(
            child: _StatColumn(label: 'Pace', value: paceLabel),
          ),
          Expanded(
            child: _StatColumn(label: 'Calories', value: caloriesLabel),
          ),
        ],
      ),
    );
  }
}

class _MapStylePanel extends StatelessWidget {
  final String selectedMapStyleId;
  final ValueChanged<String> onSelect;
  final Color accent;

  const _MapStylePanel({
    required this.selectedMapStyleId,
    required this.onSelect,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 22,
      opacity: 0.74,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: fitnessMapStyles.map((style) {
            final selected = style.id == selectedMapStyleId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(style.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? accent.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Text(
                    style.label,
                    style: TextStyle(
                      color: selected ? accent : OptivusColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _OutdoorControlPanel extends StatelessWidget {
  final FitnessActivity active;
  final bool locked;
  final Color accent;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onDiscard;
  final VoidCallback onLock;

  const _OutdoorControlPanel({
    required this.active,
    required this.locked,
    required this.accent,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onDiscard,
    required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    final paused = active.status == FitnessActivityStatus.paused;
    return TrackerGlassCard(
      padding: const EdgeInsets.all(14),
      radius: 26,
      opacity: 0.82,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FitnessOutlineButton(
                  label: paused ? 'Resume' : 'Pause',
                  icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  onTap: paused ? onResume : onPause,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FitnessPrimaryButton(
                  label: 'Finish',
                  icon: Icons.flag_rounded,
                  color: accent,
                  onTap: onFinish,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FitnessOutlineButton(
                  label: locked ? 'Unlock' : 'Lock',
                  icon: locked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  onTap: onLock,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FitnessOutlineButton(
                  label: 'Discard',
                  icon: Icons.close_rounded,
                  onTap: onDiscard,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IndoorControlPanel extends StatelessWidget {
  final FitnessActivity active;
  final Color accent;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onDiscard;

  const _IndoorControlPanel({
    required this.active,
    required this.accent,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final paused = active.status == FitnessActivityStatus.paused;
    return TrackerGlassCard(
      padding: const EdgeInsets.all(14),
      radius: 26,
      opacity: 0.74,
      child: Row(
        children: [
          Expanded(
            child: FitnessOutlineButton(
              label: paused ? 'Resume' : 'Pause',
              icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              onTap: paused ? onResume : onPause,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FitnessPrimaryButton(
              label: 'Finish',
              icon: Icons.flag_rounded,
              color: accent,
              onTap: onFinish,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FitnessOutlineButton(
              label: 'Cancel',
              icon: Icons.close_rounded,
              onTap: onDiscard,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStatusPill extends StatelessWidget {
  final FitnessActivity active;
  final Color accent;

  const _ActivityStatusPill({required this.active, required this.accent});

  @override
  Widget build(BuildContext context) {
    final label = active.status == FitnessActivityStatus.paused
        ? 'Paused'
        : 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: OptivusColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
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
      ],
    );
  }
}
