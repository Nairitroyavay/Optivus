import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/state/app_state.dart';

class FocusTimerScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const FocusTimerScreen({super.key, required this.onBack});

  @override
  ConsumerState<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends ConsumerState<FocusTimerScreen> {
  Timer? _timer;
  FocusSessionMode _mode = FocusSessionMode.pomodoro25;
  int _customMinutes = 30;
  int _remainingSeconds = 25 * 60;
  bool _running = false;
  bool _completed = false;
  RoutineItem? _linkedTask;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routineTasks = ref
        .watch(routineNotifierProvider)
        .items
        .where((item) => item.trackerType == TrackerType.focus)
        .toList();
    final screenApps = ref.watch(mockTrackerProvider).screenTimeApps;
    final riskMinutes = screenApps.fold<int>(
      0,
      (sum, app) =>
          app.distractionRisk == 'High' ? sum + app.durationMinutes : sum,
    );

    return LiquidDetailScaffold(
      eyebrow: 'Tracker',
      title: 'Focus Timer',
      subtitle: 'Deep work sessions, routine links, and distraction context.',
      accentColor: OptivusColors.trackerAccent,
      onBack: widget.onBack,
      children: [
        TrackerGlassCard(
          padding: const EdgeInsets.all(22),
          radius: 28,
          opacity: 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Today focus target',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.sub,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '90 minutes of protected work',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              _TimerDisplay(seconds: _remainingSeconds),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _TimerButton(
                    label: _running ? 'Pause' : 'Start',
                    color: OptivusColors.trackerAccent,
                    onTap: _running ? _pause : _start,
                  ),
                  _TimerButton(
                    label: 'Complete',
                    color: OptivusColors.success,
                    onTap: _complete,
                  ),
                  _TimerButton(
                    label: 'Cancel',
                    color: OptivusColors.danger,
                    outlined: true,
                    onTap: _cancel,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidDetailSection(
          title: 'Mode selector',
          children: [
            _ModeRow(
              selected: _mode,
              onSelected: (mode) {
                setState(() {
                  _mode = mode;
                  _remainingSeconds = _targetMinutesFor(mode) * 60;
                  _completed = false;
                });
              },
            ),
            if (_mode == FocusSessionMode.custom) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _customMinutes.toDouble(),
                      min: 10,
                      max: 120,
                      divisions: 11,
                      activeColor: OptivusColors.trackerAccent,
                      onChanged: (value) {
                        setState(() {
                          _customMinutes = value.round();
                          _remainingSeconds = _customMinutes * 60;
                        });
                      },
                    ),
                  ),
                  Text(
                    '${_customMinutes}m',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        LiquidDetailSection(
          title: 'Linked Routine task',
          children: [
            if (routineTasks.isEmpty)
              const Text(
                'No focus routine task yet. This can still run as a standalone tracker session.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              )
            else
              DropdownButtonFormField<RoutineItem>(
                initialValue: _linkedTask,
                hint: const Text('Select Routine task'),
                decoration: _fieldDecoration(),
                items: routineTasks
                    .map(
                      (item) => DropdownMenuItem<RoutineItem>(
                        value: item,
                        child: Text(item.title),
                      ),
                    )
                    .toList(),
                onChanged: (item) => setState(() => _linkedTask = item),
              ),
          ],
        ),
        LiquidDetailSection(
          title: 'Distraction risk',
          children: [
            Text(
              'High-risk app usage today: ${riskMinutes}m. Usage Access can replace this mock summary in the native pass.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
        if (_completed)
          LiquidDetailSection(
            tint: OptivusColors.success.withValues(alpha: 0.08),
            children: const [
              Text(
                'Focus session completed and added to Tracker History.',
                style: TextStyle(
                  color: OptivusColors.success,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
      ],
    );
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  int _targetMinutesFor(FocusSessionMode mode) {
    return switch (mode) {
      FocusSessionMode.pomodoro25 => 25,
      FocusSessionMode.deepWork45 => 45,
      FocusSessionMode.custom => _customMinutes,
    };
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _running = true;
      _completed = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _complete();
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _cancel() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _completed = false;
      _remainingSeconds = _targetMinutesFor(_mode) * 60;
    });
  }

  void _complete() {
    _timer?.cancel();
    final target = _targetMinutesFor(_mode);
    ref
        .read(mockTrackerProvider.notifier)
        .completeFocusSession(
          FocusSession(
            id: 'focus-${DateTime.now().millisecondsSinceEpoch}',
            mode: _mode,
            startedAt: DateTime.now().subtract(Duration(minutes: target)),
            completedAt: DateTime.now(),
            targetMinutes: target,
            completedMinutes: target,
            linkedRoutineItemId: _linkedTask?.id,
            linkedRoutineTitle: _linkedTask?.title,
            status: FocusSessionStatus.completed,
            distractionRiskScore: 70,
          ),
        );
    setState(() {
      _running = false;
      _completed = true;
      _remainingSeconds = _targetMinutesFor(_mode) * 60;
    });
  }
}

class _TimerDisplay extends StatelessWidget {
  final int seconds;

  const _TimerDisplay({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return Text(
      '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 58,
        fontWeight: FontWeight.w900,
        color: OptivusColors.ink,
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  final FocusSessionMode selected;
  final ValueChanged<FocusSessionMode> onSelected;

  const _ModeRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final options = {
      FocusSessionMode.pomodoro25: '25/5 Pomodoro',
      FocusSessionMode.deepWork45: '45/10 Deep Work',
      FocusSessionMode.custom: 'Custom',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((entry) {
        return GestureDetector(
          onTap: () => onSelected(entry.key),
          child: LiquidPill(
            label: entry.value,
            color: OptivusColors.trackerAccent,
            filled: selected == entry.key,
          ),
        );
      }).toList(),
    );
  }
}

class _TimerButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _TimerButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: outlined ? Colors.white.withValues(alpha: 0.52) : color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: outlined ? color : Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
