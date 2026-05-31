import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/coach/providers/coach_navigation_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/state/app_state.dart';

class BadHabitTrackerScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final String title;
  final String badHabitType;
  final ValueChanged<TrackerDetailTarget> onOpenDetail;

  const BadHabitTrackerScreen({
    super.key,
    required this.onBack,
    required this.title,
    required this.badHabitType,
    required this.onOpenDetail,
  });

  @override
  ConsumerState<BadHabitTrackerScreen> createState() =>
      _BadHabitTrackerScreenState();
}

class _BadHabitTrackerScreenState extends ConsumerState<BadHabitTrackerScreen> {
  final _cost = TextEditingController(text: '120');
  final _trigger = TextEditingController(text: 'Stress');
  final _relapseCount = TextEditingController(text: '1');
  final _reason = TextEditingController();
  final _comeback = TextEditingController(text: 'Drink water and walk 2 min');
  CravingIntensity _intensity = CravingIntensity.medium;
  BadHabitCheckInStatus? _todayStatus;
  Timer? _urgeTimer;
  int _urgeSeconds = 0;

  @override
  void dispose() {
    _urgeTimer?.cancel();
    _cost.dispose();
    _trigger.dispose();
    _relapseCount.dispose();
    _reason.dispose();
    _comeback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockTrackerProvider);
    final logs =
        state.badHabitLogs.where((log) => log.title == widget.title).toList()
          ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final dailyCost = double.tryParse(_cost.text) ?? 0;
    final potentialWeek = dailyCost * 7;

    return LiquidDetailScaffold(
      eyebrow: 'Bad habit',
      title: widget.title,
      subtitle: 'Avoidance, craving support, relapse recovery, and savings.',
      accentColor: OptivusColors.danger,
      onBack: widget.onBack,
      children: [
        TrackerGlassCard(
          padding: const EdgeInsets.all(22),
          radius: 28,
          opacity: 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Today status: $_statusLabel',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HabitAction(
                    label: 'Avoided',
                    color: OptivusColors.success,
                    onTap: () => _logAvoided(dailyCost),
                  ),
                  _HabitAction(
                    label: 'Craving',
                    color: OptivusColors.warning,
                    onTap: () => setState(
                      () => _todayStatus = BadHabitCheckInStatus.craving,
                    ),
                  ),
                  _HabitAction(
                    label: 'Relapsed',
                    color: OptivusColors.danger,
                    onTap: () => setState(
                      () => _todayStatus = BadHabitCheckInStatus.relapsed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MetricStrip(
                values: {
                  'Daily cost': 'Rs ${dailyCost.toStringAsFixed(0)}',
                  'Potential week': 'Rs ${potentialWeek.toStringAsFixed(0)}',
                  'Converted':
                      'Rs ${state.moneyGoal.totalConfirmedSaved.toStringAsFixed(0)}',
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidDetailSection(
          title: 'Money link',
          children: [
            TextField(
              controller: _cost,
              keyboardType: TextInputType.number,
              decoration: _decoration('Daily cost'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            LiquidActionRow(
              icon: Icons.savings_outlined,
              title: 'Open Money System',
              subtitle:
                  'When avoided money becomes real saving, convert it in Money System.',
              accentColor: OptivusColors.mintAccent,
              onTap: () => widget.onOpenDetail(
                TrackerDetailTarget.view(TrackerDetailView.money),
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Craving flow',
          children: [
            _IntensitySelector(
              selected: _intensity,
              onSelected: (value) => setState(() => _intensity = value),
            ),
            const SizedBox(height: 12),
            TextField(controller: _trigger, decoration: _decoration('Trigger')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HabitAction(
                  label: _urgeSeconds > 0
                      ? 'Urge ${(_urgeSeconds / 60).floor()}:${(_urgeSeconds % 60).toString().padLeft(2, '0')}'
                      : 'Start 2-min urge timer',
                  color: OptivusColors.warning,
                  onTap: _startUrgeTimer,
                ),
                _HabitAction(
                  label: 'Ask Coach',
                  color: OptivusColors.coachAccent,
                  onTap: () {
                    ref.read(appNavigationProvider.notifier).goToCoach();
                    ref.read(coachDetailViewRequestProvider.notifier).state =
                        CoachDetailView.newSession;
                  },
                ),
              ],
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Relapse flow',
          children: [
            TextField(
              controller: _relapseCount,
              keyboardType: TextInputType.number,
              decoration: _decoration('Amount / count'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 2,
              decoration: _decoration('Reason'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comeback,
              maxLines: 2,
              decoration: _decoration('Comeback action'),
            ),
            const SizedBox(height: 12),
            _HabitAction(
              label: 'Save relapse check-in',
              color: OptivusColors.danger,
              onTap: _logRelapse,
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'History preview',
          children: logs.isEmpty
              ? const [
                  Text(
                    'No check-ins yet. Log avoided, craving, or relapse above.',
                    style: TextStyle(
                      color: OptivusColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]
              : logs
                    .take(4)
                    .map(
                      (log) => LiquidActionRow(
                        icon: log.status == BadHabitCheckInStatus.avoided
                            ? Icons.check_circle_outline_rounded
                            : Icons.warning_amber_rounded,
                        title: log.status.name,
                        subtitle:
                            log.trigger ?? log.reason ?? 'Manual check-in',
                        accentColor: log.status == BadHabitCheckInStatus.avoided
                            ? OptivusColors.success
                            : OptivusColors.warning,
                      ),
                    )
                    .toList(),
        ),
      ],
    );
  }

  String get _statusLabel {
    return switch (_todayStatus) {
      BadHabitCheckInStatus.avoided => 'avoided',
      BadHabitCheckInStatus.craving => 'craving',
      BadHabitCheckInStatus.relapsed => 'relapsed',
      null => 'not checked',
    };
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  BadHabitType get _type {
    final type = widget.badHabitType.toLowerCase();
    if (type.contains('alcohol')) return BadHabitType.alcohol;
    if (type.contains('junk')) return BadHabitType.junkFood;
    if (type.contains('custom')) return BadHabitType.custom;
    return BadHabitType.smoking;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _logAvoided(double dailyCost) {
    final now = DateTime.now();
    ref
        .read(mockTrackerProvider.notifier)
        .addBadHabitLog(
          BadHabitLog(
            id: 'habit-${now.microsecondsSinceEpoch}',
            habitType: _type,
            title: widget.title,
            status: BadHabitCheckInStatus.avoided,
            loggedAt: now,
            dateKey: _dateKey(now),
            dailyCost: dailyCost,
            potentialSaved: dailyCost,
            trigger: _trigger.text.trim(),
          ),
          addPotentialSaving: dailyCost > 0,
        );
    setState(() => _todayStatus = BadHabitCheckInStatus.avoided);
  }

  void _logRelapse() {
    final now = DateTime.now();
    ref
        .read(mockTrackerProvider.notifier)
        .addBadHabitLog(
          BadHabitLog(
            id: 'habit-${now.microsecondsSinceEpoch}',
            habitType: _type,
            title: widget.title,
            status: BadHabitCheckInStatus.relapsed,
            loggedAt: now,
            dateKey: _dateKey(now),
            dailyCost: double.tryParse(_cost.text) ?? 0,
            trigger: _trigger.text.trim(),
            relapseCount: int.tryParse(_relapseCount.text) ?? 1,
            reason: _reason.text.trim(),
            comebackAction: _comeback.text.trim(),
          ),
        );
    setState(() => _todayStatus = BadHabitCheckInStatus.relapsed);
  }

  void _startUrgeTimer() {
    _urgeTimer?.cancel();
    setState(() {
      _todayStatus = BadHabitCheckInStatus.craving;
      _urgeSeconds = 120;
    });
    _urgeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_urgeSeconds <= 1) {
        timer.cancel();
        setState(() => _urgeSeconds = 0);
      } else {
        setState(() => _urgeSeconds -= 1);
      }
    });
  }
}

class _MetricStrip extends StatelessWidget {
  final Map<String, String> values;

  const _MetricStrip({required this.values});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: values.entries
          .map(
            (entry) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ),
                  ),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.sub,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _IntensitySelector extends StatelessWidget {
  final CravingIntensity selected;
  final ValueChanged<CravingIntensity> onSelected;

  const _IntensitySelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final options = {
      CravingIntensity.low: 'Low',
      CravingIntensity.medium: 'Medium',
      CravingIntensity.high: 'High',
    };
    return Wrap(
      spacing: 8,
      children: options.entries.map((entry) {
        return GestureDetector(
          onTap: () => onSelected(entry.key),
          child: LiquidPill(
            label: entry.value,
            color: OptivusColors.warning,
            filled: selected == entry.key,
          ),
        );
      }).toList(),
    );
  }
}

class _HabitAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HabitAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
