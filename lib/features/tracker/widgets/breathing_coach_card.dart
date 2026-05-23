import 'dart:async';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

/// Parasympathetic breathing coach card with timer.
class BreathingCoachCard extends StatefulWidget {
  const BreathingCoachCard({super.key});

  @override
  State<BreathingCoachCard> createState() => _BreathingCoachCardState();
}

class _BreathingCoachCardState extends State<BreathingCoachCard> {
  bool _isMeditating = false;
  int _meditationSeconds = 0;
  Timer? _meditationTimer;
  String _breathText = 'Breathe in...';

  @override
  void dispose() {
    _meditationTimer?.cancel();
    super.dispose();
  }

  void _toggleMeditation() {
    if (_isMeditating) {
      _meditationTimer?.cancel();
      final mins = (_meditationSeconds / 60).ceil();
      if (mins > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully logged $mins min of mindfulness meditation!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        _isMeditating = false;
        _meditationSeconds = 0;
      });
    } else {
      setState(() {
        _isMeditating = true;
        _meditationSeconds = 0;
        _breathText = 'Breathe in...';
      });
      _meditationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _meditationSeconds++;
          final mod = _meditationSeconds % 12;
          if (mod < 4) {
            _breathText = 'Breathe in...';
          } else if (mod < 8) {
            _breathText = 'Hold...';
          } else {
            _breathText = 'Breathe out...';
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Parasympathetic Breathing',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  const Text(
                      'Deep pacing simulator for neural relaxation',
                      style: TextStyle(
                          fontSize: 11,
                          color: OptivusColors.textSecondary)),
                ],
              ),
              const Icon(Icons.self_improvement,
                  color: Colors.deepPurple, size: 28),
            ],
          ),
          const SizedBox(height: 20),
          if (_isMeditating) ...[
            Center(
              child: Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 4),
                    curve: Curves.easeInOut,
                    builder: (context, val, child) {
                      return Container(
                        width: 80 + (val * 40),
                        height: 80 + (val * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              Colors.deepPurple.withValues(alpha: 0.15),
                          border: Border.all(
                              color: Colors.deepPurple, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            _breathText,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                color: Colors.deepPurple),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Elapsed: ${_meditationSeconds}s',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: OptivusColors.textPrimary),
                  ),
                ],
              ),
            )
          ] else ...[
            const Center(
              child: Text(
                'Timer Idle. Press start to log daily focus minutes.',
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: OptivusColors.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isMeditating ? OptivusColors.danger : Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: _toggleMeditation,
            child: Text(
              _isMeditating
                  ? 'Finish & Log Meditation'
                  : 'Start Breathing Timer',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
