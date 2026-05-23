import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/state/mock_app_state.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

/// GPS live run telemetry simulator (Strava-like mock).
class StravaRunCard extends ConsumerStatefulWidget {
  const StravaRunCard({super.key});

  @override
  ConsumerState<StravaRunCard> createState() => _StravaRunCardState();
}

class _StravaRunCardState extends ConsumerState<StravaRunCard> {
  bool _isSimulating = false;
  double _simulatedDistance = 0.0;
  int _simulatedSeconds = 0;
  Timer? _stravaTimer;

  @override
  void dispose() {
    _stravaTimer?.cancel();
    super.dispose();
  }

  void _toggleSimulation() {
    if (_isSimulating) {
      _stravaTimer?.cancel();
      if (_simulatedDistance > 0.0) {
        final pace = _simulatedDistance > 0
            ? (_simulatedSeconds / 60) / _simulatedDistance
            : 0.0;
        final act = FitnessActivity(
          id: 'fit-${DateTime.now().millisecondsSinceEpoch}',
          type: 'Run',
          distanceKm: _simulatedDistance,
          durationSeconds: _simulatedSeconds,
          paceMinutesPerKm: pace,
          caloriesBurned: (_simulatedDistance * 65).toInt(),
        );
        ref.read(mockTrackerProvider.notifier).addFitnessActivity(act);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Synced ${_simulatedDistance.toStringAsFixed(2)}km run to Strava logs!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        _isSimulating = false;
        _simulatedDistance = 0.0;
        _simulatedSeconds = 0;
      });
    } else {
      setState(() {
        _isSimulating = true;
        _simulatedDistance = 0.0;
        _simulatedSeconds = 0;
      });
      _stravaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _simulatedSeconds++;
          _simulatedDistance += 0.02;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockTrackerProvider);

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
                  Text('GPS Live Run Telemetry',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  const Text(
                      'Simulate aerobic road running stats offline',
                      style: TextStyle(
                          fontSize: 11,
                          color: OptivusColors.textSecondary)),
                ],
              ),
              const Icon(Icons.directions_run,
                  color: Colors.orange, size: 28),
            ],
          ),
          const SizedBox(height: 20),
          if (_isSimulating) ...[
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text('DISTANCE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: OptivusColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        '${_simulatedDistance.toStringAsFixed(2)} km',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.orange),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('PACE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: OptivusColors.textSecondary)),
                      const SizedBox(height: 4),
                      const Text(
                        '5:00 /km',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: OptivusColors.textPrimary),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('TIME',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: OptivusColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        '${_simulatedSeconds}s',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: OptivusColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ] else ...[
            const Center(
              child: Text(
                'Simulator Idle. Complete a workout to sync via Strava API mock.',
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: OptivusColors.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isSimulating ? OptivusColors.danger : Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: _toggleSimulation,
            child: Text(
              _isSimulating
                  ? 'Stop & Sync to Strava'
                  : 'Simulate Outdoor Run',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (state.fitnessActivities.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('SYNCED FITNESS STATS:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    color: OptivusColors.textSecondary)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.fitnessActivities.length,
              itemBuilder: (context, index) {
                final fit = state.fitnessActivities[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.offline_bolt,
                          color: OptivusColors.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${fit.type}: ${fit.distanceKm.toStringAsFixed(2)} km (${(fit.durationSeconds / 60).ceil()}m @ ${fit.paceMinutesPerKm.toStringAsFixed(1)}/km)',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Icon(Icons.cloud_done_outlined,
                          color: Colors.orange, size: 16),
                    ],
                  ),
                );
              },
            )
          ],
        ],
      ),
    );
  }
}
