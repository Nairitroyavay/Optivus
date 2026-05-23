import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/mock_app_state.dart';
import 'package:optivus/models/permission_status.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
import 'tracker_widgets.dart';

void showTrackerDetailSheet(BuildContext context, WidgetRef ref, String metricTitle) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFE8FCFF), // Matching App Tab background color
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, child) {
              return _TrackerDetailContent(
                metricTitle: metricTitle,
                scrollController: scrollController,
              );
            },
          );
        },
      );
    },
  );
}

class _TrackerDetailContent extends ConsumerStatefulWidget {
  final String metricTitle;
  final ScrollController scrollController;

  const _TrackerDetailContent({
    required this.metricTitle,
    required this.scrollController,
  });

  @override
  ConsumerState<_TrackerDetailContent> createState() => _TrackerDetailContentState();
}

class _TrackerDetailContentState extends ConsumerState<_TrackerDetailContent> {
  // Common state vars for mock interaction
  double _sliderVal = 5.0;
  int _counter = 0;
  bool _mockSyncState = true;
  final List<String> _checkboxList = ['Morning Cleanser', 'Toner Hydrate', 'Moisturizer Active', 'Sunscreen SPF50'];
  final List<bool> _checkboxState = [true, false, false, false];

  @override
  void initState() {
    super.initState();
    // Default config values based on metrics
    if (widget.metricTitle == 'Sleep') {
      _sliderVal = 7.5;
    } else if (widget.metricTitle == 'Screen Time') {
      _sliderVal = 145.0;
    } else if (widget.metricTitle == 'Steps') {
      _counter = 7420;
    } else if (widget.metricTitle == 'Meditation') {
      _counter = 10;
    } else if (widget.metricTitle == 'Focus') {
      _counter = 2;
    } else if (widget.metricTitle == 'Hydration') {
      _counter = 1750;
    } else if (widget.metricTitle == 'Reading') {
      _sliderVal = 12.0;
    } else if (widget.metricTitle == 'Skill Practice') {
      _sliderVal = 30.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockTrackerProvider);
    final isGpsConnected = ref.watch(mockPermissionProvider).locationGps == PermissionConnectionState.mockConnected;

    return SingleChildScrollView(
      controller: widget.scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag indicator
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TELEMETRY READINGS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.metricTitle} System',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: OptivusColors.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: OptivusColors.brandAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIconForMetric(), color: OptivusColors.brandAccent, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Render targeted UI matching one of the 15 categories
          _buildMetricSpecificPanel(state, isGpsConnected),
          const SizedBox(height: 24),

          // Visual sparkline chart (Every detail sheet gets a gorgeous trendline graph!)
          const Text(
            '7-DAY PERFORMANCE LOGS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          LiquidGlassPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TrackerSparkline(
                  dataPoints: _getSparklinePoints(),
                  lineColor: _getColorForMetric(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Mon', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
                    Text('Wed', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
                    Text('Fri', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
                    Text('Sun', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Wearable Linker Card
          PhoneDataSourceCard(
            isSynced: _mockSyncState,
            onToggle: () => setState(() => _mockSyncState = !_mockSyncState),
          ),
          const SizedBox(height: 32),

          // Close button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OptivusColors.brandAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Sync & Close Panel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  IconData _getIconForMetric() {
    switch (widget.metricTitle) {
      case 'Sleep': return Icons.bedtime;
      case 'Screen Time': return Icons.phonelink_setup;
      case 'Steps': return Icons.directions_walk;
      case 'Savings': return Icons.savings;
      case 'Meditation': return Icons.self_improvement;
      case 'Focus': return Icons.hourglass_bottom;
      case 'Hydration': return Icons.local_drink;
      case 'Bad Habits': return Icons.do_not_disturb_alt;
      case 'Workout': return Icons.fitness_center;
      case 'Nutrition': return Icons.restaurant;
      case 'Skin Care': return Icons.face;
      case 'Reading': return Icons.menu_book;
      case 'Language': return Icons.translate;
      case 'Skill Practice': return Icons.star;
      default: return Icons.insights;
    }
  }

  Color _getColorForMetric() {
    switch (widget.metricTitle) {
      case 'Sleep': return Colors.indigo;
      case 'Screen Time': return Colors.purple;
      case 'Steps': return Colors.orange;
      case 'Savings': return Colors.teal;
      case 'Meditation': return Colors.deepPurple;
      case 'Focus': return Colors.blue;
      case 'Hydration': return OptivusColors.brandAccent;
      case 'Bad Habits': return OptivusColors.danger;
      case 'Workout': return Colors.red;
      case 'Nutrition': return Colors.green;
      case 'Skin Care': return Colors.pink;
      case 'Reading': return Colors.amber;
      case 'Language': return Colors.cyan;
      case 'Skill Practice': return Colors.deepOrange;
      default: return OptivusColors.brandAccent;
    }
  }

  List<double> _getSparklinePoints() {
    switch (widget.metricTitle) {
      case 'Sleep': return [6.5, 7.2, 8.0, 5.5, 7.8, 8.5, _sliderVal];
      case 'Screen Time': return [180.0, 240.0, 160.0, _sliderVal, 120.0, 95.0, 70.0];
      case 'Steps': return [8500.0, 12000.0, 6000.0, 9200.0, _counter.toDouble(), 11000.0, 10500.0];
      case 'Savings': return [10.0, 20.0, 10.0, 0.0, 30.0, 40.0, 20.0];
      case 'Meditation': return [5.0, 10.0, 15.0, 0.0, 20.0, _counter.toDouble(), 15.0];
      case 'Hydration': return [2500, 3000, 2000, 3200, 2800, _counter.toDouble(), 3100];
      default: return [2.0, 4.0, 3.0, 6.0, 5.0, 7.0, 8.0];
    }
  }

  Widget _buildMetricSpecificPanel(MockTrackerState state, bool isGpsConnected) {
    switch (widget.metricTitle) {
      case 'Sleep':
        return LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('CIRCADIAN DEPTH RECORD', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Center(
                child: TrackerProgressRing(
                  progress: _sliderVal / 8.0,
                  ringColor: Colors.indigo,
                  centerWidget: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_sliderVal.toStringAsFixed(1)}h', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.indigo)),
                      const Text('SLEEP CYCLE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: _sliderVal,
                min: 4.0,
                max: 12.0,
                activeColor: Colors.indigo,
                onChanged: (val) => setState(() => _sliderVal = val),
              ),
              const Text(
                'Verify bedtime window: 11:30 PM - 7:00 AM. Adjust slider to input actual sleep depth logged.',
                style: TextStyle(fontSize: 11, color: OptivusColors.textSecondary, height: 1.3),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case 'Screen Time':
        return LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('APP SCREEN TIME FOCUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daily Limit: 180 mins', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
                  Text(
                    'Current: ${_sliderVal.toInt()} mins',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _sliderVal > 180 ? OptivusColors.danger : OptivusColors.success),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_sliderVal / 180.0).clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(_sliderVal > 180 ? OptivusColors.danger : OptivusColors.success),
                ),
              ),
              const SizedBox(height: 16),
              const Text('DISTRACTING APP BLOCKS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: OptivusColors.textSecondary)),
              const SizedBox(height: 8),
              for (final app in state.screenTimeApps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(app.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${app.durationMinutes} mins', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
        );

      case 'Steps':
        return Column(
          children: [
            LiquidGlassPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ACCELEROMETER STEPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('$_counter / 10,000 Target', style: const TextStyle(fontSize: 11, color: OptivusColors.textSecondary)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.orange, size: 28),
                        onPressed: () => setState(() => _counter += 500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _counter / 10000.0,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('LIVE GPS ROUTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            const MockMapPreview(),
          ],
        );

      case 'Savings':
        final total = state.moneyGoal.totalConfirmedSaved;
        return LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('MICRO-SAVINGS BALANCES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Confirmed:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('₹$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.teal)),
                ],
              ),
              const Divider(height: 24),
              const Text('CONFIRMED SAVINGS LEDGER:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary)),
              const SizedBox(height: 8),
              if (state.savingsEntries.isEmpty)
                const Text('No saving transactions made today.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: OptivusColors.textSecondary))
              else
                ...state.savingsEntries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(e.description, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          Text('₹${e.amount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.teal)),
                        ],
                      ),
                    )),
            ],
          ),
        );

      case 'Skin Care':
        return LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('SKINCARE HYGIENE TIMELINE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              for (int i = 0; i < _checkboxList.length; i++)
                CheckboxListTile(
                  value: _checkboxState[i],
                  title: Text(_checkboxList[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  activeColor: Colors.pink,
                  onChanged: (val) {
                    setState(() {
                      _checkboxState[i] = val ?? false;
                    });
                  },
                ),
            ],
          ),
        );

      case 'Hydration':
        final waterTotal = state.hydrationLogs.fold<int>(0, (sum, item) => sum + item.amountMl);
        return LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('HYDRATION TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 16),
              Center(
                child: TrackerProgressRing(
                  progress: waterTotal / 3200.0,
                  ringColor: OptivusColors.brandAccent,
                  centerWidget: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${waterTotal}ml', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: OptivusColors.brandAccent)),
                      const Text('/ 3200ml', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: OptivusColors.brandAccent, foregroundColor: Colors.white),
                      onPressed: () => ref.read(mockTrackerProvider.notifier).logHydration(250),
                      child: const Text('+250ml', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: OptivusColors.brandAccent, foregroundColor: Colors.white),
                      onPressed: () => ref.read(mockTrackerProvider.notifier).logHydration(500),
                      child: const Text('+500ml', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                ],
              )
            ],
          ),
        );

      case 'Bad Habits':
        return LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('BAD HABITS MULTIPLIER WARNING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OptivusColors.danger)),
              const SizedBox(height: 8),
              const Text(
                'Skipping triggers automatic coaching accountability. Logging a clean day adds to saving sweep rates.',
                style: TextStyle(fontSize: 11, color: OptivusColors.textBody, height: 1.3),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: OptivusColors.danger, foregroundColor: Colors.white),
                icon: const Icon(Icons.gavel, size: 16),
                label: const Text('Verify Perfect Clean Day', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Streak verified! Clean day synced.'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ],
          ),
        );

      case 'Workout':
        return LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('WORKOUT SESSION LOGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              const Text('Current Split: PUSH A (Chest/Shoulders/Triceps)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
              const SizedBox(height: 16),
              _buildWorkoutRow('Incline Dumbbell Press', '3 sets x 8 reps @ 32kg'),
              _buildWorkoutRow('Overhead Military Press', '3 sets x 10 reps @ 50kg'),
              _buildWorkoutRow('Tricep Dip Extensions', '3 sets x 12 reps @ Bodyweight'),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gym Workout Set Saved!'), behavior: SnackBarBehavior.floating),
                  );
                },
                child: const Text('Log Workout Lift Session', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

      case 'Nutrition':
        return LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('MACRONUTRIENT RATIOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroRing('CALORIES', '1920', '/ 2400', Colors.orange, 0.8),
                  _buildMacroRing('PROTEIN', '125g', '/ 150g', Colors.red, 0.83),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Meal calorie target logged!'), behavior: SnackBarBehavior.floating),
                  );
                },
                child: const Text('+500 kcal (Standard High Protein)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

      default:
        // Generic fallback for reading, language, skill practice, focus, meditation
        return LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.metricTitle.toUpperCase()} COUNTER TARGET', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 16),
              Center(
                child: TrackerProgressRing(
                  progress: _sliderVal / 10.0,
                  ringColor: _getColorForMetric(),
                  centerWidget: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_sliderVal.toInt()}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: _getColorForMetric())),
                      const Text('UNITS COMPLETED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: _sliderVal,
                min: 0.0,
                max: 30.0,
                activeColor: _getColorForMetric(),
                onChanged: (val) => setState(() => _sliderVal = val),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildWorkoutRow(String name, String setsStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          Text(setsStr, style: const TextStyle(fontSize: 11, color: OptivusColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMacroRing(String title, String val, String target, Color color, double progress) {
    return Column(
      children: [
        TrackerProgressRing(
          progress: progress,
          ringColor: color,
          strokeWidth: 8,
          centerWidget: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
              Text(target, style: const TextStyle(fontSize: 8, color: OptivusColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
