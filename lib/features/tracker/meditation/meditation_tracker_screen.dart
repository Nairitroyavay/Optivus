import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:optivus/core/liquid_ui/liquid_ui.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'meditation_mock_data.dart';
import 'meditation_tracker_widgets.dart';

class MeditationTrackerScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const MeditationTrackerScreen({super.key, this.onBack});

  @override
  State<MeditationTrackerScreen> createState() => _MeditationTrackerScreenState();
}

class _MeditationTrackerScreenState extends State<MeditationTrackerScreen> {
  // State
  final String _selectedTypeId = 'calm';
  int _selectedDuration = 5;
  String _selectedSoundId = 'silent';
  
  // Timer State
  // Status: ready, running, paused, completed
  String _status = 'ready';
  int _remainingSeconds = 5 * 60;
  Timer? _timer;
  
  // Orb State
  String _currentPhase = 'Inhale';
  int _phaseSeconds = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _selectedDuration * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateDuration(int duration) {
    if (_status == 'running' || _status == 'paused') return;
    setState(() {
      _selectedDuration = duration;
      _remainingSeconds = duration * 60;
    });
  }

  void _updateSound(String soundId) {
    setState(() {
      _selectedSoundId = soundId;
    });
  }

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
      _currentPhase = 'Inhale';
      _phaseSeconds = 0;
    });
  }

  void _completeSession() {
    _timer?.cancel();
    setState(() {
      _status = 'completed';
    });
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
    final type = mockMeditationSessionTypes.firstWhere((t) => t.id == _selectedTypeId);
    _phaseSeconds++;
    
    // Cycle logic
    if (_currentPhase == 'Inhale' && _phaseSeconds >= type.inhaleSeconds) {
      _currentPhase = type.holdSeconds > 0 ? 'Hold' : 'Exhale';
      _phaseSeconds = 0;
    } else if (_currentPhase == 'Hold' && _phaseSeconds >= type.holdSeconds) {
      _currentPhase = 'Exhale';
      _phaseSeconds = 0;
    } else if (_currentPhase == 'Exhale' && _phaseSeconds >= type.exhaleSeconds) {
      _currentPhase = 'Inhale';
      _phaseSeconds = 0;
    }
  }

  void _showAddNoteSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: OptivusColors.trackerCardTint,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How do you feel after this session?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kInk),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  LiquidChip(label: 'Calm', selected: false, onTap: () => context.pop(), accentColor: kPurple),
                  LiquidChip(label: 'Focused', selected: false, onTap: () => context.pop(), accentColor: kBlue),
                  LiquidChip(label: 'Sleepy', selected: false, onTap: () => context.pop(), accentColor: OptivusColors.trackerAccent),
                  LiquidChip(label: 'Still anxious', selected: false, onTap: () => context.pop(), accentColor: kRose),
                  LiquidChip(label: 'Better', selected: false, onTap: () => context.pop(), accentColor: kMint),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomReserve = media.padding.bottom + 120.0;
    
    final selectedType = mockMeditationSessionTypes.firstWhere((t) => t.id == _selectedTypeId);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomReserve),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Orb & Timer Area
                Center(
                  child: LiquidGlassBreathingOrb(
                    isRunning: _status == 'running',
                    currentPhase: _currentPhase,
                    accentColor: selectedType.accentToken,
                  ),
                ),
                const SizedBox(height: 32),
                
                TimerDisplay(
                  remainingSeconds: _remainingSeconds,
                  status: _status,
                  currentPhase: _currentPhase,
                  sessionTypeName: selectedType.title,
                ),
                
                const Spacer(flex: 3),

                // Duration Selector
                if (_status == 'ready')
                  DurationSelector(
                    selectedDuration: _selectedDuration,
                    onSelected: _updateDuration,
                  ),
                
                // Completion State
                if (_status == 'completed')
                  CompletionCard(
                    durationMinutes: _selectedDuration,
                    onDone: () {
                      setState(() {
                        _status = 'ready';
                      });
                      if (widget.onBack != null) {
                         widget.onBack!();
                      } else {
                         context.pop();
                      }
                    },
                    onStartAnother: _cancelSession,
                    onAddNote: _showAddNoteSheet,
                  ),

                // Controls
                if (_status != 'completed')
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                    child: MeditationControlBar(
                      status: _status,
                      onStart: _startSession,
                      onPause: _pauseSession,
                      onResume: _resumeSession,
                      onComplete: _completeSession,
                      onCancel: _cancelSession,
                    ),
                  ),

                // Target Card at bottom
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: MeditationTargetCard(
                    targetMinutes: 5,
                    completedMinutes: 0,
                    streakDays: 5,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              TrackerHeaderButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    context.pop();
                  }
                },
              ),
              const SizedBox(width: 16),
              const Text(
                'Meditation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: kInk,
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
      ),
    );
  }
}
