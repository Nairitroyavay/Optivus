import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/tracker/hydration/hydration_provider.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/state/app_state.dart';

class HydrationTrackerScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const HydrationTrackerScreen({super.key, required this.onBack});

  @override
  ConsumerState<HydrationTrackerScreen> createState() =>
      _HydrationTrackerScreenState();
}

class _HydrationTrackerScreenState
    extends ConsumerState<HydrationTrackerScreen> {
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _logWater(int ml) {
    if (ml <= 0) return;
    HapticFeedback.selectionClick();
    ref.read(mockTrackerProvider.notifier).logHydration(ml);
    _customController.clear();
  }

  void _confirmReset() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reset today?'),
        content: const Text('This clears today\'s local hydration logs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OptivusColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(mockTrackerProvider.notifier).resetHydration();
              Navigator.of(context).pop();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(hydrationTodayTotalProvider);
    final goal = ref.watch(hydrationGoalMlProvider);
    final logs = ref.watch(mockTrackerProvider).hydrationLogs.reversed.toList();
    final progress = (total / goal).clamp(0.0, 1.0);

    return LiquidDetailScaffold(
      eyebrow: 'Tracker',
      title: 'Hydration',
      subtitle: 'Today water progress, quick logs, reminders, and streak.',
      accentColor: OptivusColors.trackerAccent,
      onBack: widget.onBack,
      children: [
        TrackerGlassCard(
          padding: const EdgeInsets.all(22),
          radius: 28,
          opacity: 0.74,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: OptivusColors.sub,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor: OptivusColors.trackerAccent
                              .withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            OptivusColors.blueAccent,
                          ),
                        ),
                        Center(
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: OptivusColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(total / 1000).toStringAsFixed(1)}L / ${(goal / 1000).toStringAsFixed(1)}L',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Pace target: one glass every 90-120 minutes.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: OptivusColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TrackerGlassCard(
          padding: const EdgeInsets.all(18),
          radius: 24,
          opacity: 0.68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick add',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _WaterButton(label: '+100ml', onTap: () => _logWater(100)),
                  _WaterButton(label: '+250ml', onTap: () => _logWater(250)),
                  _WaterButton(label: '+500ml', onTap: () => _logWater(500)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Custom ml',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.72),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () =>
                        _logWater(int.tryParse(_customController.text) ?? 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OptivusColors.trackerAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TrackerGlassCard(
          padding: const EdgeInsets.all(18),
          radius: 24,
          opacity: 0.62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly mini graph',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 90,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final value = [
                      0.62,
                      0.76,
                      0.58,
                      0.92,
                      0.71,
                      0.84,
                      progress,
                    ][index];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              height: 64 * value,
                              decoration: BoxDecoration(
                                color: index == 6
                                    ? OptivusColors.blueAccent
                                    : OptivusColors.trackerAccent.withValues(
                                        alpha: 0.42,
                                      ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ['M', 'T', 'W', 'T', 'F', 'S', 'N'][index],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: OptivusColors.sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              const TrackerMetricChip(
                category: 'Consistency',
                value: '5-day hydration streak',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TrackerGlassCard(
          padding: const EdgeInsets.all(18),
          radius: 24,
          opacity: 0.64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today logs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ),
                  ),
                  TextButton(
                    onPressed: logs.isEmpty ? null : _confirmReset,
                    child: const Text('Reset today'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No water logged yet today.',
                    style: TextStyle(color: OptivusColors.sub),
                  ),
                )
              else
                ...logs.map(
                  (log) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.water_drop_rounded,
                          color: OptivusColors.blueAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '+${log.amountMl}ml',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: OptivusColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          log.timestamp,
                          style: const TextStyle(
                            fontSize: 12,
                            color: OptivusColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TrackerGlassCard(
          padding: const EdgeInsets.all(18),
          radius: 22,
          tint: OptivusColors.blueAccent.withValues(alpha: 0.08),
          child: const Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: OptivusColors.blueAccent,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reminder shortcut: hydration nudges use Profile notification settings and quiet hours.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: OptivusColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _WaterButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: OptivusColors.blueAccent.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: OptivusColors.blueAccent.withValues(alpha: 0.28),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: OptivusColors.blueAccent,
          ),
        ),
      ),
    );
  }
}
