import 'package:flutter/material.dart';
import 'package:optivus/core/liquid_ui/liquid_ui.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'meditation_mock_data.dart';

class MeditationHeroCard extends StatelessWidget {
  final int targetMinutes;
  final int completedMinutes;
  final int streakDays;

  const MeditationHeroCard({
    super.key,
    required this.targetMinutes,
    required this.completedMinutes,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      padding: const EdgeInsets.all(20),
      radius: 28,
      tint: OptivusColors.trackerCardTint.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s target',
                      style: TextStyle(
                        fontSize: 14,
                        color: kSub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$targetMinutes min',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: kInk,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Five calm minutes protect your mind today.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kSub,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [OptivusColors.trackerAccent, kPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: OptivusColors.trackerAccent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '$completedMinutes / $targetMinutes\nmin',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              _buildMiniChip('Target $targetMinutes min', OptivusColors.trackerAccent),
              _buildMiniChip('Streak $streakDays days', kAmber),
              _buildMiniChip('Mind Pillar', kPurple),
              _buildMiniChip('Inner Peace', kBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class SessionTypeSelector extends StatelessWidget {
  final List<MeditationSessionTypeUiModel> types;
  final String selectedTypeId;
  final ValueChanged<String> onSelected;

  const SessionTypeSelector({
    super.key,
    required this.types,
    required this.selectedTypeId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SESSION TYPE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: kSub,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: types.map((type) {
              final isSelected = type.id == selectedTypeId;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => onSelected(type.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? type.accentToken.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? type.accentToken : Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: type.accentToken.withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(type.icon, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              type.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? type.accentToken : kInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type.description,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? type.accentToken.withValues(alpha: 0.8) : kSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class DurationSelector extends StatelessWidget {
  final int selectedDuration;
  final ValueChanged<int> onSelected;

  const DurationSelector({
    super.key,
    required this.selectedDuration,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final durations = [1, 3, 5, 10, 15];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...durations.map((duration) {
          final isSelected = selectedDuration == duration;
          return LiquidChip(
            label: '$duration min',
            selected: isSelected,
            onTap: () => onSelected(duration),
            accentColor: OptivusColors.trackerAccent,
          );
        }),
        LiquidChip(
          label: 'Custom',
          selected: false,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Custom duration placeholder'),
                backgroundColor: OptivusColors.trackerAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          accentColor: kSub,
        ),
      ],
    );
  }
}

class BreathingOrb extends StatefulWidget {
  final bool isRunning;
  final String currentPhase;
  final Color accentColor;

  const BreathingOrb({
    super.key,
    required this.isRunning,
    required this.currentPhase,
    required this.accentColor,
  });

  @override
  State<BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<BreathingOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isRunning) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant BreathingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _startAnimation();
      } else {
        _controller.stop();
      }
    }
    
    // We roughly match the phase with the scale if we had a perfect breath engine, 
    // but for mock/local we just pulse smoothly or adjust based on phase.
    if (widget.isRunning && widget.currentPhase != oldWidget.currentPhase) {
        if (widget.currentPhase == 'Breathe in') {
            _controller.forward();
        } else if (widget.currentPhase == 'Hold') {
            _controller.stop();
        } else if (widget.currentPhase == 'Breathe out') {
            _controller.reverse();
        } else if (widget.currentPhase == 'Rest') {
            _controller.stop();
        }
    }
  }

  void _startAnimation() {
      if (widget.currentPhase == 'Breathe in') {
          _controller.forward();
      } else if (widget.currentPhase == 'Breathe out') {
          _controller.reverse();
      } else if (!_controller.isAnimating) {
         _controller.repeat(reverse: true);
      }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isRunning ? _scaleAnimation.value : 1.0,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: widget.isRunning ? 20 * _scaleAnimation.value : 0,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.8),
                      widget.accentColor.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TimerDisplay extends StatelessWidget {
  final int remainingSeconds;
  final String status;
  final String currentPhase;

  const TimerDisplay({
    super.key,
    required this.remainingSeconds,
    required this.status,
    required this.currentPhase,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        Text(
          status == 'completed' ? '00:00' : '$minutes:$seconds',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: kInk,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status == 'running' ? currentPhase : status.toUpperCase(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: status == 'running' ? OptivusColors.trackerAccent : kSub,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class MusicSelector extends StatelessWidget {
  final List<MeditationSoundUiModel> sounds;
  final String selectedSoundId;
  final ValueChanged<String> onSelected;

  const MusicSelector({
    super.key,
    required this.sounds,
    required this.selectedSoundId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SOUNDSCAPE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: kSub,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: sounds.map((sound) {
              final isSelected = sound.id == selectedSoundId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LiquidChip(
                  label: sound.title,
                  emoji: sound.id == 'silent' ? '🤫' : '🎵',
                  selected: isSelected,
                  onTap: () => onSelected(sound.id),
                  accentColor: kBlue,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class MeditationControls extends StatelessWidget {
  final String status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const MeditationControls({
    super.key,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'ready' || status == 'cancelled') {
      return LiquidButton(
        label: status == 'ready' ? 'Start Session' : 'Restart Session',
        onTap: onStart,
        color: OptivusColors.trackerAccent,
      );
    }

    if (status == 'running') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSecondaryBtn('Cancel', onCancel, isDestructive: true),
          const SizedBox(width: 16),
          Expanded(
            child: LiquidButton(
              label: 'Pause',
              onTap: onPause,
              color: kAmber,
              leading: const Icon(Icons.pause, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          _buildSecondaryBtn('Complete', onComplete),
        ],
      );
    }

    if (status == 'paused') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSecondaryBtn('Cancel', onCancel, isDestructive: true),
          const SizedBox(width: 16),
          Expanded(
            child: LiquidButton(
              label: 'Resume',
              onTap: onResume,
              color: kMint,
              leading: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          _buildSecondaryBtn('Complete', onComplete),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSecondaryBtn(String label, VoidCallback onTap, {bool isDestructive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDestructive ? kRose.withValues(alpha: 0.1) : kWhite.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDestructive ? kRose.withValues(alpha: 0.3) : kWhite,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDestructive ? kRose : kInk,
          ),
        ),
      ),
    );
  }
}

class CompletionCard extends StatelessWidget {
  final int durationMinutes;
  final VoidCallback onDone;
  final VoidCallback onStartAnother;
  final VoidCallback onAddNote;

  const CompletionCard({
    super.key,
    required this.durationMinutes,
    required this.onDone,
    required this.onStartAnother,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      padding: const EdgeInsets.all(24),
      radius: 32,
      tint: OptivusColors.trackerCardTint,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kMint.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.check_circle, color: kMint, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'Meditation Completed',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$durationMinutes min calm time',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kSub,
            ),
          ),
          const SizedBox(height: 24),
          _buildSyncItem('Routine task completed', kMint),
          _buildSyncItem('Mind pillar updated', kPurple),
          _buildSyncItem('Inner Peace goal updated', kBlue),
          const SizedBox(height: 32),
          LiquidButton(
            label: 'Done',
            onTap: onDone,
            color: OptivusColors.trackerAccent,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: onAddNote,
                child: const Text('Add note', style: TextStyle(color: kSub, fontWeight: FontWeight.bold)),
              ),
              const Text('•', style: TextStyle(color: kSub)),
              TextButton(
                onPressed: onStartAnother,
                child: const Text('Start another', style: TextStyle(color: kSub, fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSyncItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kInk,
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressSummary extends StatelessWidget {
  const ProgressSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROGRESS SUMMARY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: kSub,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard('Today', '5 / 5 min', OptivusColors.trackerAccent),
            _buildStatCard('This week', '5 / 7 days', kPurple),
            _buildStatCard('Total calm', '30 min', kBlue),
            _buildStatCard('Best streak', '7 days', kAmber),
            _buildStatCard('Current streak', '5 days', kMint),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color accent) {
    return LiquidCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kSub,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyCalmPattern extends StatelessWidget {
  const WeeklyCalmPattern({super.key});

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final minutes = [5, 5, 0, 5, 5, 0, 0];

    return LiquidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Calm Pattern',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kInk,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final min = minutes[index];
              return Column(
                children: [
                  Container(
                    width: 24,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: min > 0
                        ? Container(
                            width: 24,
                            height: 60.0 * (min / 5).clamp(0.2, 1.0),
                            decoration: BoxDecoration(
                              color: OptivusColors.trackerAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          )
                        : const SizedBox(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[index],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: kSub,
                    ),
                  ),
                  Text(
                    min > 0 ? '${min}m' : '-',
                    style: const TextStyle(
                      fontSize: 10,
                      color: kInk,
                    ),
                  )
                ],
              );
            }),
          )
        ],
      ),
    );
  }
}

class RecentSessionsList extends StatelessWidget {
  final List<MeditationSessionUiModel> sessions;

  const RecentSessionsList({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT SESSIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: kSub,
          ),
        ),
        const SizedBox(height: 12),
        ...sessions.map((session) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: LiquidCard(
              padding: const EdgeInsets.all(16),
              radius: 16,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      session.type == 'Calm' ? '🧘' : session.type == 'Focus' ? '🎯' : session.type == 'Sleep' ? '😴' : '🫂',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.type,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: kInk,
                          ),
                        ),
                        Text(
                          '${session.dateLabel} • ${session.durationMinutes} min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: session.status == 'Completed' ? kMint.withValues(alpha: 0.15) : kAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      session.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: session.status == 'Completed' ? kMint : kAmber,
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class InsightCard extends StatelessWidget {
  const InsightCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      tint: kPurple.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Sensei Insight',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kPurple.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '"You do not need to fix the whole day. Calm your mind first."',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kInk,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Today\'s Inner Peace proof is simple: sit still for five minutes.',
            style: TextStyle(
              fontSize: 13,
              color: kSub,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              LiquidChip(
                label: 'Ask Coach',
                selected: false,
                onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ask Coach placeholder')));
                },
                accentColor: kPurple,
              ),
              const SizedBox(width: 12),
              LiquidChip(
                label: '1 min tiny',
                selected: false,
                onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('1 min tiny placeholder')));
                },
                accentColor: OptivusColors.trackerAccent,
              ),
            ],
          )
        ],
      ),
    );
  }
}

class SettingsPreview extends StatelessWidget {
  const SettingsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SETTINGS & PREFERENCES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: kSub,
          ),
        ),
        const SizedBox(height: 12),
        LiquidCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildSettingRow('Default duration', '5 min'),
              _buildSettingRow('Default session type', 'Calm'),
              _buildSettingRow('Breathing rhythm', '4-2-6'),
              _buildSettingRow('Reminder time', '08:00 AM', isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(String title, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: kSub,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 14, color: kSub),
            ],
          )
        ],
      ),
    );
  }
}
