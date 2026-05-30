import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/state/app_state.dart';

import 'meditation_mock_data.dart';
import 'meditation_tracker_widgets.dart';

class MeditationTrackerScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const MeditationTrackerScreen({super.key, this.onBack});

  @override
  ConsumerState<MeditationTrackerScreen> createState() =>
      _MeditationTrackerScreenState();
}

class _MeditationTrackerScreenState
    extends ConsumerState<MeditationTrackerScreen> {
  final String _selectedTypeId = 'calm';
  int _selectedDuration = 5;
  String _selectedSoundId = 'silent';

  MeditationStatus _status = MeditationStatus.ready;
  int _remainingSeconds = 5 * 60;
  int _completedDurationMinutes = 0;
  bool _hasLoggedCompletion = false;
  Timer? _timer;

  String _currentPhase = 'ready';
  int _phaseSeconds = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _selectedDuration * 60;
    _currentPhase = 'ready';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateDuration(int duration) {
    if (_status == MeditationStatus.running ||
        _status == MeditationStatus.paused) {
      return;
    }
    setState(() {
      _selectedDuration = duration;
      _remainingSeconds = duration * 60;
      _completedDurationMinutes = 0;
      _hasLoggedCompletion = false;
      _currentPhase = 'ready';
      _phaseSeconds = 0;
      _status = MeditationStatus.ready;
    });
  }

  void _updateSound(String soundId) {
    setState(() {
      _selectedSoundId = soundId;
    });
  }

  void _startSession() {
    _timer?.cancel();
    setState(() {
      _status = MeditationStatus.running;
      _currentPhase = 'Inhale';
      _phaseSeconds = 0;
      _completedDurationMinutes = 0;
      _hasLoggedCompletion = false;
      if (_remainingSeconds <= 0 ||
          _remainingSeconds > _selectedDuration * 60) {
        _remainingSeconds = _selectedDuration * 60;
      }
    });
    _startTimer();
  }

  void _pauseSession() {
    _timer?.cancel();
    setState(() {
      _status = MeditationStatus.paused;
    });
  }

  void _resumeSession() {
    _timer?.cancel();
    setState(() {
      _status = MeditationStatus.running;
    });
    _startTimer();
  }

  void _cancelSession() {
    _timer?.cancel();
    setState(() {
      _status = MeditationStatus.ready;
      _remainingSeconds = _selectedDuration * 60;
      _currentPhase = 'ready';
      _phaseSeconds = 0;
      _completedDurationMinutes = 0;
      _hasLoggedCompletion = false;
    });
  }

  void _completeSession() {
    _timer?.cancel();

    final selectedType = mockMeditationSessionTypes.firstWhere(
      (t) => t.id == _selectedTypeId,
    );

    if (!_hasLoggedCompletion) {
      ref
          .read(mockTrackerProvider.notifier)
          .logMeditationSession(
            durationMinutes: _selectedDuration,
            type: selectedType.title,
          );
    }

    setState(() {
      _status = MeditationStatus.completed;
      _remainingSeconds = 0;
      _currentPhase = 'ready';
      _phaseSeconds = 0;
      _completedDurationMinutes = _selectedDuration;
      _hasLoggedCompletion = true;
    });
  }

  void _startAgain() {
    _timer?.cancel();
    setState(() {
      _status = MeditationStatus.ready;
      _remainingSeconds = _selectedDuration * 60;
      _currentPhase = 'ready';
      _phaseSeconds = 0;
      _completedDurationMinutes = 0;
      _hasLoggedCompletion = false;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        _completeSession();
        return;
      }

      setState(() {
        _remainingSeconds--;
        _updateBreathingPhase();
      });
    });
  }

  void _updateBreathingPhase() {
    final type = mockMeditationSessionTypes.firstWhere(
      (t) => t.id == _selectedTypeId,
    );
    _phaseSeconds++;

    if (_currentPhase == 'ready') {
      _currentPhase = 'Inhale';
      _phaseSeconds = 0;
    } else if (_currentPhase == 'Inhale' &&
        _phaseSeconds >= type.inhaleSeconds) {
      _currentPhase = type.holdSeconds > 0 ? 'Hold' : 'Exhale';
      _phaseSeconds = 0;
    } else if (_currentPhase == 'Hold' && _phaseSeconds >= type.holdSeconds) {
      _currentPhase = 'Exhale';
      _phaseSeconds = 0;
    } else if (_currentPhase == 'Exhale' &&
        _phaseSeconds >= type.exhaleSeconds) {
      _currentPhase = 'Inhale';
      _phaseSeconds = 0;
    }
  }

  void _handleBack() {
    _timer?.cancel();
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final selectedType = mockMeditationSessionTypes.firstWhere(
      (t) => t.id == _selectedTypeId,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final isSmall = h < 720 || w < 380;
        final tabReserve = 112.0 + media.padding.bottom;
        final targetHeight = isSmall ? 68.0 : 76.0;
        final targetBottom = tabReserve;
        final controlsBottom =
            targetBottom + targetHeight + (isSmall ? 12.0 : 16.0);
        final chipHeight = isSmall ? 34.0 : 38.0;
        final buttonHeight = isSmall ? 44.0 : 48.0;
        final controlsGap = isSmall ? 10.0 : 14.0;
        final completedHeight = _status == MeditationStatus.completed
            ? (isSmall ? 92.0 : 100.0)
            : buttonHeight;
        final controlsHeight = chipHeight + controlsGap + completedHeight;
        final centerTop = 62.0;
        final centerBottom =
            controlsBottom + controlsHeight + (isSmall ? 8.0 : 14.0);
        final centerHeight = math.max(120.0, h - centerTop - centerBottom);
        final timerFontSize = centerHeight < 260
            ? 40.0
            : (isSmall ? 44.0 : 52.0);
        final baseOrbSize = isSmall ? 162.0 : 202.0;
        final orbHeightBudget = centerHeight - timerFontSize - 76.0;
        final minOrbSize = h < 640 ? 124.0 : (isSmall ? 150.0 : 185.0);
        final orbSize = orbHeightBudget
            .clamp(minOrbSize, baseOrbSize)
            .toDouble();
        final orbTimerGap = isSmall ? 8.0 : 12.0;
        final filterWidth = w < 360
            ? 150.0
            : math.min(175.0, math.max(150.0, w * 0.42));

        return Stack(
          children: [
            Positioned(
              top: 12,
              left: 20,
              right: 20,
              height: 44,
              child: _buildHeader(filterWidth),
            ),

            Positioned(
              top: centerTop,
              left: 0,
              right: 0,
              bottom: centerBottom,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AiLiquidMeditationOrb(
                        isRunning: _status == MeditationStatus.running,
                        currentPhase: _currentPhase,
                        accentColor: selectedType.accentToken,
                        inhaleSeconds: selectedType.inhaleSeconds,
                        holdSeconds: selectedType.holdSeconds,
                        exhaleSeconds: selectedType.exhaleSeconds,
                        size: orbSize,
                      ),
                      SizedBox(height: orbTimerGap),
                      TimerDisplay(
                        remainingSeconds: _remainingSeconds,
                        status: _status,
                        currentPhase: _currentPhase,
                        sessionTypeName: selectedType.title,
                        fontSize: timerFontSize,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              bottom: controlsBottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MeditationDurationSelector(
                    selectedDuration: _selectedDuration,
                    onSelected: _updateDuration,
                    enabled:
                        _status == MeditationStatus.ready ||
                        _status == MeditationStatus.completed,
                    chipHeight: chipHeight,
                  ),
                  SizedBox(height: controlsGap),
                  MeditationControlBar(
                    status: _status,
                    buttonHeight: buttonHeight,
                    completedDurationMinutes: _completedDurationMinutes,
                    onStart: _startSession,
                    onPause: _pauseSession,
                    onResume: _resumeSession,
                    onComplete: _completeSession,
                    onCancel: _cancelSession,
                    onDone: () {
                      _handleBack();
                    },
                    onStartAgain: _startAgain,
                  ),
                ],
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              bottom: targetBottom,
              height: targetHeight,
              child: MeditationTargetCard(
                targetMinutes: 5,
                completedMinutes: _status == MeditationStatus.completed
                    ? _completedDurationMinutes
                    : 0,
                streakDays: 5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(double filterWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              TrackerHeaderButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _handleBack,
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Meditation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.ink,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        MeditationMusicFilter(
          sounds: mockMeditationSounds,
          selectedSoundId: _selectedSoundId,
          onSelected: _updateSound,
          width: filterWidth,
        ),
      ],
    );
  }
}
