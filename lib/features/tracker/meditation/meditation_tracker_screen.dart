import 'package:flutter/material.dart';
import 'dart:async';
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
  // ── State ─────────────────────────────────────────────────────────────────
  final String _selectedTypeId = 'calm';
  int _selectedDuration = 5;
  String _selectedSoundId = 'silent';

  // ── Timer State ───────────────────────────────────────────────────────────
  // Status: ready, running, paused, completed
  String _status = 'ready';
  int _remainingSeconds = 5 * 60;
  Timer? _timer;

  // ── Orb State ─────────────────────────────────────────────────────────────
  String _currentPhase = 'Inhale'; // "ready", "Inhale", "Hold", "Exhale"
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

  // ── Duration ──────────────────────────────────────────────────────────────
  void _updateDuration(int duration) {
    if (_status == 'running' || _status == 'paused') return;
    setState(() {
      _selectedDuration = duration;
      _remainingSeconds = duration * 60;
    });
  }

  // ── Sound ─────────────────────────────────────────────────────────────────
  void _updateSound(String soundId) {
    setState(() {
      _selectedSoundId = soundId;
    });
  }

  // ── Session Controls ──────────────────────────────────────────────────────
  void _startSession() {
    setState(() {
      _status = 'running';
      _currentPhase = 'Inhale';
      _phaseSeconds = 0;
      if (_remainingSeconds <= 0) {
        _remainingSeconds = _selectedDuration * 60;
      }
    });
    _startTimer();
  }

  void _pauseSession() {
    _timer?.cancel();
    setState(() {
      _status = 'paused';
    });
  }

  void _resumeSession() {
    setState(() {
      _status = 'running';
    });
    _startTimer();
  }

  void _cancelSession() {
    _timer?.cancel();
    setState(() {
      _status = 'ready';
      _remainingSeconds = _selectedDuration * 60;
      _currentPhase = 'ready';
      _phaseSeconds = 0;
    });
  }

  void _completeSession() {
    _timer?.cancel();
    setState(() {
      _status = 'completed';
      _currentPhase = 'ready';
    });

    final selectedType = mockMeditationSessionTypes.firstWhere(
      (t) => t.id == _selectedTypeId,
    );

    // Log session to provider
    ref
        .read(mockTrackerProvider.notifier)
        .logMeditationSession(
          durationMinutes: _selectedDuration,
          type: selectedType.title,
        );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _updateBreathingPhase();
        });
      } else {
        _completeSession();
      }
    });
  }

  void _updateBreathingPhase() {
    final type = mockMeditationSessionTypes.firstWhere(
      (t) => t.id == _selectedTypeId,
    );
    _phaseSeconds++;

    if (_currentPhase == 'Inhale' && _phaseSeconds >= type.inhaleSeconds) {
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

  // ── Back navigation ───────────────────────────────────────────────────────
  void _handleBack() {
    _timer?.cancel();
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final selectedType = mockMeditationSessionTypes.firstWhere(
      (t) => t.id == _selectedTypeId,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final isSmall = h < 720;
        final tabReserve = 112.0 + media.padding.bottom;

        final orbSize = isSmall ? 165.0 : 200.0;
        final timerFontSize = isSmall ? 42.0 : 50.0;
        final orbTimerGap = isSmall ? 12.0 : 18.0;

        return Stack(
          children: [
            // ── Header Row ───────────────────────────────────────────────
            Positioned(
              top: 12,
              left: 20,
              right: 20,
              height: 44,
              child: _buildHeader(selectedType),
            ),

            // ── Center: Orb + Timer + Phase ──────────────────────────────
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              bottom: tabReserve + 220,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: AiLiquidMeditationOrb(
                      isRunning: _status == 'running',
                      currentPhase: _currentPhase,
                      accentColor: selectedType.accentToken,
                      inhaleSeconds: selectedType.inhaleSeconds,
                      holdSeconds: selectedType.holdSeconds,
                      exhaleSeconds: selectedType.exhaleSeconds,
                      size: orbSize,
                    ),
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

            // ── Controls Area ───────────────────────────────────────────
            Positioned(
              left: 20,
              right: 20,
              bottom: tabReserve + 92,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Duration Selector (always visible, disabled during session)
                  MeditationDurationSelector(
                    selectedDuration: _selectedDuration,
                    onSelected: _updateDuration,
                    enabled: _status == 'ready' || _status == 'completed',
                  ),
                  const SizedBox(height: 16),

                  // Control Buttons
                  MeditationControlBar(
                    status: _status,
                    onStart: _startSession,
                    onPause: _pauseSession,
                    onResume: _resumeSession,
                    onComplete: _completeSession,
                    onCancel: _cancelSession,
                    onDone: () {
                      _cancelSession();
                      _handleBack();
                    },
                    onStartAnother: _cancelSession,
                  ),
                ],
              ),
            ),

            // ── Bottom Target Card ───────────────────────────────────────
            Positioned(
              left: 20,
              right: 20,
              bottom: tabReserve,
              height: 76,
              child: MeditationTargetCard(
                targetMinutes: 5,
                completedMinutes: _status == 'completed'
                    ? _selectedDuration
                    : 0,
                streakDays: 5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(MeditationSessionTypeUiModel selectedType) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            TrackerHeaderButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: _handleBack,
            ),
            const SizedBox(width: 16),
            const Text(
              'Meditation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: OptivusColors.ink,
              ),
            ),
          ],
        ),
        MeditationMusicFilter(
          sounds: mockMeditationSounds,
          selectedSoundId: _selectedSoundId,
          onSelected: _updateSound,
        ),
      ],
    );
  }
}
