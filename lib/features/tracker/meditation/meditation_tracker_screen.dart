import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:optivus/core/liquid_ui/liquid_ui.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'meditation_mock_data.dart';
import 'meditation_tracker_widgets.dart';

class MeditationTrackerScreen extends StatefulWidget {
  const MeditationTrackerScreen({super.key});

  @override
  State<MeditationTrackerScreen> createState() => _MeditationTrackerScreenState();
}

class _MeditationTrackerScreenState extends State<MeditationTrackerScreen> {
  // State
  String _selectedTypeId = 'calm';
  int _selectedDuration = 5;
  String _selectedSoundId = 'silent';
  
  // Timer State
  // Status: ready, running, paused, completed, cancelled
  String _status = 'ready';
  int _remainingSeconds = 5 * 60;
  Timer? _timer;
  
  // Orb State
  String _currentPhase = 'Breathe in';
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

  void _updateType(String typeId) {
    if (_status == 'running' || _status == 'paused') return;
    setState(() {
      _selectedTypeId = typeId;
    });
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
      _currentPhase = 'Breathe in';
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
      _status = 'cancelled';
      _remainingSeconds = _selectedDuration * 60;
      _currentPhase = 'Breathe in';
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
    if (_currentPhase == 'Breathe in' && _phaseSeconds >= type.inhaleSeconds) {
      _currentPhase = type.holdSeconds > 0 ? 'Hold' : 'Breathe out';
      _phaseSeconds = 0;
    } else if (_currentPhase == 'Hold' && _phaseSeconds >= type.holdSeconds) {
      _currentPhase = 'Breathe out';
      _phaseSeconds = 0;
    } else if (_currentPhase == 'Breathe out' && _phaseSeconds >= type.exhaleSeconds) {
      _currentPhase = 'Breathe in'; // Skipping 'rest' for simplicity, unless we add it to model
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
    final bottomReserve = media.padding.bottom + 24.0;
    
    final selectedType = mockMeditationSessionTypes.firstWhere((t) => t.id == _selectedTypeId);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            OptivusColors.trackerTop,
            OptivusColors.trackerCardTint,
          ],
          stops: const [0.0, 0.8],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 8, 20, bottomReserve),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MeditationHeroCard(
                        targetMinutes: 5,
                        completedMinutes: 0,
                        streakDays: 5,
                      ),
                      const SizedBox(height: 32),
                      
                      SessionTypeSelector(
                        types: mockMeditationSessionTypes,
                        selectedTypeId: _selectedTypeId,
                        onSelected: _updateType,
                      ),
                      const SizedBox(height: 32),

                      // Orb & Timer Area
                      Center(
                        child: BreathingOrb(
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
                      ),
                      const SizedBox(height: 24),

                      // Duration Selector (hide if running/paused/completed)
                      if (_status == 'ready' || _status == 'cancelled')
                        DurationSelector(
                          selectedDuration: _selectedDuration,
                          onSelected: _updateDuration,
                        ),
                      if (_status == 'ready' || _status == 'cancelled')
                        const SizedBox(height: 32),

                      // Completion State
                      if (_status == 'completed')
                        CompletionCard(
                          durationMinutes: _selectedDuration,
                          onDone: () => context.pop(),
                          onStartAnother: _cancelSession,
                          onAddNote: _showAddNoteSheet,
                        ),
                      if (_status == 'completed')
                        const SizedBox(height: 32),

                      // Controls
                      if (_status != 'completed')
                        MeditationControls(
                          status: _status,
                          onStart: _startSession,
                          onPause: _pauseSession,
                          onResume: _resumeSession,
                          onComplete: _completeSession,
                          onCancel: _cancelSession,
                        ),
                      const SizedBox(height: 40),

                      // Music Selector
                      MusicSelector(
                        sounds: mockMeditationSounds,
                        selectedSoundId: _selectedSoundId,
                        onSelected: _updateSound,
                      ),
                      const SizedBox(height: 40),
                      
                      const ProgressSummary(),
                      const SizedBox(height: 32),
                      
                      const WeeklyCalmPattern(),
                      const SizedBox(height: 32),
                      
                      const RecentSessionsList(sessions: mockRecentSessions),
                      const SizedBox(height: 32),
                      
                      const InsightCard(),
                      const SizedBox(height: 32),
                      
                      const SettingsPreview(),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
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
              LiquidIconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => context.pop(),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meditation',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: kInk,
                    ),
                  ),
                  Text(
                    'Calm your mind.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kSub.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          LiquidIconBtn(
            icon: Icons.info_outline_rounded,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Meditation info placeholder')),
              );
            },
          ),
        ],
      ),
    );
  }
}
