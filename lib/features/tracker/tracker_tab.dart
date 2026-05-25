import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
import 'package:optivus/features/tracker/widgets/tracker_details_sheets.dart';

class TrackerTab extends ConsumerStatefulWidget {
  const TrackerTab({super.key});

  @override
  ConsumerState<TrackerTab> createState() => _TrackerTabState();
}

class _TrackerTabState extends ConsumerState<TrackerTab> {
  // Meditation states
  bool _isMeditating = false;
  int _meditationSeconds = 0;
  Timer? _meditationTimer;
  String _breathText = 'Breathe in...';

  // Strava mock run states
  bool _isStravaSimulating = false;
  double _simulatedDistance = 0.0;
  int _simulatedSeconds = 0;
  Timer? _stravaTimer;

  // Selected tracker view (Daily, Weekly, Monthly)
  String _activeMetricView = 'Daily';

  // Active / Inactive metrics lists
  final List<String> _activeMetrics = [
    'Sleep',
    'Steps',
    'Hydration',
    'Meditation',
    'Workout',
    'Savings',
  ];
  final List<String> _inactiveMetrics = [
    'Screen Time',
    'Bad Habits',
    'Nutrition',
    'Skin Care',
    'Reading',
    'Language',
    'Skill Practice',
  ];

  @override
  void dispose() {
    _meditationTimer?.cancel();
    _stravaTimer?.cancel();
    super.dispose();
  }

  // --- Meditation breathing timer handler
  void _toggleMeditation() {
    if (_isMeditating) {
      _meditationTimer?.cancel();
      final mins = (_meditationSeconds / 60).ceil();
      if (mins > 0) {
        final intent = ref.read(trackerLaunchIntentProvider);
        if (intent?.trackerType == TrackerType.meditation) {
          ref
              .read(routineControllerProvider)
              .completeTrackerSession(intent!.routineTaskId);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully logged $mins min of mindfulness meditation!',
            ),
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

  // --- Strava running simulator handler
  void _toggleStravaSimulation() {
    if (_isStravaSimulating) {
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
        final intent = ref.read(trackerLaunchIntentProvider);
        if (intent?.trackerType == TrackerType.workout) {
          ref
              .read(routineControllerProvider)
              .completeTrackerSession(intent!.routineTaskId);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synced ${_simulatedDistance.toStringAsFixed(2)}km run to Strava logs!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        _isStravaSimulating = false;
        _simulatedDistance = 0.0;
        _simulatedSeconds = 0;
      });
    } else {
      setState(() {
        _isStravaSimulating = true;
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

  void _triggerMockUPIPayment() {
    final amountController = TextEditingController(text: '10.0');
    final descController = TextEditingController(
      text: 'Skipped junk coffee savings',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFE8FCFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.payment, color: OptivusColors.brandAccent),
              SizedBox(width: 10),
              Text(
                'SANDBOX UPI TRANS',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Simulate moving ₹10 target from consumption into daily savings.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: OptivusColors.textBody,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Pledge Reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OptivusColors.brandAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final amt = double.tryParse(amountController.text) ?? 10.0;
                final desc = descController.text.trim();
                if (desc.isEmpty) return;

                ref
                    .read(mockTrackerProvider.notifier)
                    .logSaving(amt, desc, isConfirmed: true);
                final intent = ref.read(trackerLaunchIntentProvider);
                if (intent?.trackerType == TrackerType.money) {
                  ref
                      .read(routineControllerProvider)
                      .completeTrackerSession(intent!.routineTaskId);
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Mock UPI payment of ₹$amt verified! Saved successfully.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Simulate Paid',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deactivateMetric(String metric) {
    setState(() {
      _activeMetrics.remove(metric);
      if (!_inactiveMetrics.contains(metric)) {
        _inactiveMetrics.add(metric);
      }
    });
  }

  void _activateMetric(String metric) {
    setState(() {
      _inactiveMetrics.remove(metric);
      if (!_activeMetrics.contains(metric)) {
        _activeMetrics.add(metric);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockTrackerProvider);
    final waterTotal = state.hydrationLogs.fold<int>(
      0,
      (sum, item) => sum + item.amountMl,
    );
    final launchIntent = ref.watch(trackerLaunchIntentProvider);
    final launchedRoutine = launchIntent == null
        ? null
        : ref
              .watch(mockRoutineProvider)
              .where((item) => item.id == launchIntent.routineTaskId)
              .cast<RoutineItem?>()
              .firstWhere((item) => item != null, orElse: () => null);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (launchIntent != null && launchedRoutine != null) ...[
            _buildRoutineLaunchBanner(launchIntent, launchedRoutine),
            const SizedBox(height: 16),
          ],
          // 1. DYNAMIC PROGRESS CAROUSEL (Daily/Weekly/Monthly Toggle)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'METRICS & CONSISTENCY',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: OptivusColors.textSecondary,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OptivusColors.borderSoft),
                ),
                child: Row(
                  children: ['Daily', 'Weekly', 'Monthly'].map((view) {
                    final isSel = _activeMetricView == view;
                    return InkWell(
                      onTap: () => setState(() => _activeMetricView = view),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        color: isSel
                            ? OptivusColors.brandAccent
                            : Colors.transparent,
                        child: Text(
                          view,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSel
                                ? Colors.white
                                : OptivusColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LiquidGlassPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Audit Score:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _activeMetricView == 'Daily'
                          ? '92%'
                          : _activeMetricView == 'Weekly'
                          ? '88%'
                          : '94%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: OptivusColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    double heightPercent = [
                      0.8,
                      0.95,
                      0.45,
                      0.9,
                      0.75,
                      0.3,
                      0.85,
                    ][index];
                    return Column(
                      children: [
                        Container(
                          width: 14,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.bottomCenter,
                            heightFactor: heightPercent,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    OptivusColors.brandAccent,
                                    OptivusColors.aquaAccent,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          days[index],
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. STAGGERED GRID OF ACTIVE METRICS
          Text(
            'ACTIVE HEALTH & PRODUCTIVITY METRICS (TAP TO VIEW DETAILS)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _activeMetrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (context, index) {
              final metric = _activeMetrics[index];
              return _buildActiveMetricCard(metric, waterTotal, state);
            },
          ),
          const SizedBox(height: 24),

          // 3. INACTIVE METRICS SELECTOR DECK
          if (_inactiveMetrics.isNotEmpty) ...[
            Text(
              'INACTIVE SYSTEM TELEMETRY (TAP TO ACTIVATE)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: OptivusColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _inactiveMetrics.map((metric) {
                  return ActionChip(
                    backgroundColor: Colors.white.withValues(alpha: 0.8),
                    side: const BorderSide(color: OptivusColors.borderSoft),
                    label: Text(
                      '+ $metric',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: OptivusColors.brandAccent,
                      ),
                    ),
                    onPressed: () => _activateMetric(metric),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 4. INTERACTIVE PARASYMPATHETIC BREATHING COACH
          Text(
            'MINDFULNESS & NEURAL CALM',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          LiquidGlassPanel(
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
                        Text(
                          'Parasympathetic Breathing',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Deep pacing simulator for neural relaxation',
                          style: TextStyle(
                            fontSize: 11,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.self_improvement,
                      color: Colors.deepPurple,
                      size: 28,
                    ),
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
                                color: Colors.deepPurple.withValues(
                                  alpha: 0.15,
                                ),
                                border: Border.all(
                                  color: Colors.deepPurple,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _breathText,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    color: Colors.deepPurple,
                                  ),
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
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Center(
                    child: Text(
                      'Timer Idle. Press start to log daily focus minutes.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMeditating
                        ? OptivusColors.danger
                        : Colors.deepPurple,
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
          ),
          const SizedBox(height: 24),

          // 5. STRAVA ACTIVE FITNESS GPS SIMULATOR
          Text(
            'ACTIVE RUN COMPANION (STRAVA SYNC)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          LiquidGlassPanel(
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
                        Text(
                          'GPS Live Run Telemetry',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Simulate aerobic road running stats offline',
                          style: TextStyle(
                            fontSize: 11,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.directions_run,
                      color: Colors.orange,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_isStravaSimulating) ...[
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'DISTANCE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: OptivusColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_simulatedDistance.toStringAsFixed(2)} km',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'PACE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: OptivusColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '5:00 /km',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'TIME',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: OptivusColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_simulatedSeconds}s',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Center(
                    child: Text(
                      'Simulator Idle. Complete a workout to sync via Strava API mock.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStravaSimulating
                        ? OptivusColors.danger
                        : Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _toggleStravaSimulation,
                  child: Text(
                    _isStravaSimulating
                        ? 'Stop & Sync to Strava'
                        : 'Simulate Outdoor Run',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (state.fitnessActivities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'SYNCED FITNESS STATS:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
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
                            const Icon(
                              Icons.offline_bolt,
                              color: OptivusColors.success,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${fit.type}: ${fit.distanceKm.toStringAsFixed(2)} km (${(fit.durationSeconds / 60).ceil()}m @ ${fit.paceMinutesPerKm.toStringAsFixed(1)}/km)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.cloud_done_outlined,
                              color: Colors.orange,
                              size: 16,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 6. UPI ₹10 TARGET SANDBOX
          Text(
            'SANDBOX FINANCIAL COMMITMENT (MOCK UPI)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          LiquidGlassPanel(
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
                        Text(
                          '₹10 Daily Micro-Savings',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Confirmed Saved: ₹${state.moneyGoal.totalConfirmedSaved} | Streak: ${state.moneyGoal.streakDays} Days',
                          style: const TextStyle(
                            fontSize: 11,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.savings_outlined,
                      color: Colors.teal,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.security, size: 16),
                  label: const Text(
                    'Trigger Safe UPI Deposit',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _triggerMockUPIPayment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineLaunchBanner(
    TrackerLaunchIntent intent,
    RoutineItem item,
  ) {
    return LiquidGlassPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: OptivusColors.trackerAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: OptivusColors.trackerAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                Text(
                  'Launched from Routine • ${intent.trackerType.name}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(routineControllerProvider)
                  .completeTrackerSession(intent.routineTaskId);
            },
            child: const Text(
              'Complete',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMetricCard(
    String metric,
    int waterTotal,
    MockTrackerState state,
  ) {
    IconData icon = Icons.insights;
    Color color = OptivusColors.brandAccent;
    String statusStr = 'Active';

    switch (metric) {
      case 'Sleep':
        icon = Icons.bedtime;
        color = Colors.indigo;
        statusStr = '7.5h slept';
        break;
      case 'Steps':
        icon = Icons.directions_walk;
        color = Colors.orange;
        statusStr = '7,420 steps';
        break;
      case 'Hydration':
        icon = Icons.local_drink;
        color = OptivusColors.brandAccent;
        statusStr = '${waterTotal}ml';
        break;
      case 'Meditation':
        icon = Icons.self_improvement;
        color = Colors.deepPurple;
        statusStr = '10m focus';
        break;
      case 'Workout':
        icon = Icons.fitness_center;
        color = Colors.red;
        statusStr = 'PUSH split';
        break;
      case 'Savings':
        icon = Icons.savings;
        color = Colors.teal;
        statusStr = '₹${state.moneyGoal.totalConfirmedSaved} saved';
        break;
      default:
        icon = Icons.offline_bolt;
        color = Colors.blueGrey;
        statusStr = '100%';
    }

    return InkWell(
      onTap: () => showTrackerDetailSheet(context, ref, metric),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Stack(
          children: [
            // Top Right delete icon
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _deactivateMetric(metric),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: OptivusColors.borderSoft),
                  ),
                  child: const Icon(
                    Icons.remove,
                    size: 10,
                    color: OptivusColors.danger,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        color: OptivusColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
