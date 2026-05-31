import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/state/app_state.dart';

class SleepTrackerScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const SleepTrackerScreen({super.key, required this.onBack});

  @override
  ConsumerState<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends ConsumerState<SleepTrackerScreen> {
  TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 30);
  SleepQuality _quality = SleepQuality.good;

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(mockTrackerProvider).sleepLogs.toList()
      ..sort((a, b) => b.wakeDateTime.compareTo(a.wakeDateTime));
    final last = logs.isNotEmpty ? logs.first : _exampleLog();

    return LiquidDetailScaffold(
      eyebrow: 'Tracker',
      title: 'Sleep',
      subtitle: 'Sleep affects Routine load, Coach, Body, Mind, and Goals.',
      accentColor: OptivusColors.trackerAccent,
      onBack: widget.onBack,
      children: [
        TrackerGlassCard(
          padding: const EdgeInsets.all(22),
          radius: 28,
          opacity: 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Last night',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.sub,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(last.durationMinutes / 60).toStringAsFixed(1)} hours',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  LiquidPill(
                    label: _timeLabel(last.sleepStartDateTime),
                    color: OptivusColors.purpleAccent,
                  ),
                  LiquidPill(
                    label: _timeLabel(last.wakeDateTime),
                    color: OptivusColors.trackerAccent,
                  ),
                  LiquidPill(
                    label: last.quality.name,
                    color: OptivusColors.success,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidDetailSection(
          title: 'Manual log sleep',
          children: [
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Sleep start',
                    value: _sleepTime.format(context),
                    onTap: () => _pickTime(
                      current: _sleepTime,
                      onPicked: (value) => setState(() => _sleepTime = value),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimeTile(
                    label: 'Wake time',
                    value: _wakeTime.format(context),
                    onTap: () => _pickTime(
                      current: _wakeTime,
                      onPicked: (value) => setState(() => _wakeTime = value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SleepQuality.values.map((quality) {
                return GestureDetector(
                  onTap: () => setState(() => _quality = quality),
                  child: LiquidPill(
                    label: quality.name,
                    color: OptivusColors.trackerAccent,
                    filled: quality == _quality,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            _PrimaryAction(
              label: 'Log sleep',
              color: OptivusColors.trackerAccent,
              onTap: _logSleep,
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Overnight storage rule',
          children: const [
            Text(
              'If sleep starts at 10:30 PM on May 28 and wake is 7:30 AM on May 29, store sleepStartDateTime as 2026-05-28 22:30, wakeDateTime as 2026-05-29 07:30, duration as 9 hours. Daily progress belongs to the wake-up day.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Weekly sleep pattern',
          children: [
            SizedBox(
              height: 86,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [7.5, 6.8, 8.0, 9.0, 7.2, 8.5, 7.9]
                    .map(
                      (hours) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FractionallySizedBox(
                            heightFactor: (hours / 10).clamp(0.1, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: OptivusColors.trackerAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Health Connect',
          children: const [
            Text(
              'Native permission connects in backend/native pass. Manual sleep remains the current source of truth until Health Connect is enabled.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Wind-down recommendation',
          children: const [
            Text(
              'Start a low-light routine 45 minutes before target sleep time, avoid high-risk apps, and move flexible tasks out of the last hour.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickTime({
    required TimeOfDay current,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) onPicked(picked);
  }

  void _logSleep() {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
      _sleepTime.hour,
      _sleepTime.minute,
    );
    var wake = DateTime(
      now.year,
      now.month,
      now.day,
      _wakeTime.hour,
      _wakeTime.minute,
    );
    if (!wake.isAfter(start)) {
      wake = wake.add(const Duration(days: 1));
    }
    ref
        .read(mockTrackerProvider.notifier)
        .addSleepLog(
          SleepLog.fromRange(
            id: 'sleep-${DateTime.now().microsecondsSinceEpoch}',
            sleepStartDateTime: start,
            wakeDateTime: wake,
            quality: _quality,
            source: 'manual',
          ),
        );
  }

  SleepLog _exampleLog() {
    return SleepLog.fromRange(
      id: 'sleep-example',
      sleepStartDateTime: DateTime(2026, 5, 28, 22, 30),
      wakeDateTime: DateTime(2026, 5, 29, 7, 30),
      quality: SleepQuality.good,
      source: 'manual',
    );
  }

  String _timeLabel(DateTime value) {
    final hour = value.hour > 12 ? value.hour - 12 : value.hour;
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${value.minute.toString().padLeft(2, '0')} $suffix';
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
