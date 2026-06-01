import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/utils/currency_formatter.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/region_settings_provider.dart';

class TrackerHistoryScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const TrackerHistoryScreen({super.key, required this.onBack});

  @override
  ConsumerState<TrackerHistoryScreen> createState() =>
      _TrackerHistoryScreenState();
}

class _TrackerHistoryScreenState extends ConsumerState<TrackerHistoryScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final region = ref.watch(regionSettingsProvider);
    final entries = _buildEntries(ref.watch(mockTrackerProvider), region);
    final visible = _filter == 'All'
        ? entries
        : entries.where((entry) => entry.category == _filter).toList();

    return LiquidDetailScaffold(
      eyebrow: 'Tracker',
      title: 'Tracker History',
      subtitle: 'All local sessions, logs, summaries, and check-ins.',
      accentColor: OptivusColors.trackerAccent,
      onBack: widget.onBack,
      children: [
        TrackerGlassCard(
          radius: 24,
          opacity: 0.68,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'Mind', 'Body', 'Focus', 'Finance', 'Bad Habits']
                .map(
                  (label) => GestureDetector(
                    onTap: () => setState(() => _filter = label),
                    child: LiquidPill(
                      label: label,
                      color: OptivusColors.trackerAccent,
                      filled: _filter == label,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          LiquidDetailSection(
            children: const [
              Text(
                'No tracker logs match this filter yet.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ],
          )
        else ...[
          _HistorySection(
            title: 'Today',
            entries: visible.where(_isToday).toList(),
            onTap: _showEntryDetail,
          ),
          _HistorySection(
            title: 'This Week',
            entries: visible
                .where((entry) => !_isToday(entry) && _isThisWeek(entry))
                .toList(),
            onTap: _showEntryDetail,
          ),
          _HistorySection(
            title: 'Older',
            entries: visible.where((entry) => !_isThisWeek(entry)).toList(),
            onTap: _showEntryDetail,
          ),
        ],
      ],
    );
  }

  void _showEntryDetail(TrackerHistoryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return Container(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
          margin: const EdgeInsets.all(16),
          padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + media.padding.bottom),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.subtitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    LiquidPill(
                      label: entry.category,
                      color: OptivusColors.info,
                    ),
                    if (entry.valueLabel != null)
                      LiquidPill(
                        label: entry.valueLabel!,
                        color: OptivusColors.trackerAccent,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isToday(TrackerHistoryEntry entry) {
    final now = DateTime.now();
    final date = entry.occurredAt;
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isThisWeek(TrackerHistoryEntry entry) {
    return DateTime.now().difference(entry.occurredAt).inDays < 7;
  }

  List<TrackerHistoryEntry> _buildEntries(
    MockTrackerState state,
    RegionSettings region,
  ) {
    final now = DateTime.now();
    final entries = <TrackerHistoryEntry>[
      TrackerHistoryEntry(
        id: 'screen-summary',
        trackerType: 'screenTime',
        category: 'Focus',
        title: 'Screen Time summary',
        subtitle: '${state.screenTimeApps.length} apps reviewed',
        occurredAt: now.subtract(const Duration(hours: 1)),
        valueLabel: 'Risk review',
      ),
      TrackerHistoryEntry(
        id: 'sleep-local',
        trackerType: 'sleep',
        category: 'Body',
        title: 'Sleep log',
        subtitle: 'Manual overnight sleep belongs to wake-up day',
        occurredAt: now.subtract(const Duration(hours: 7)),
        valueLabel: '9h',
      ),
      TrackerHistoryEntry(
        id: 'focus-local',
        trackerType: 'focus',
        category: 'Focus',
        title: 'Focus session',
        subtitle: 'Routine-linked deep work block',
        occurredAt: now.subtract(const Duration(days: 2)),
        valueLabel: '45m',
      ),
      TrackerHistoryEntry(
        id: 'nutrition-local',
        trackerType: 'nutrition',
        category: 'Body',
        title: 'Nutrition log',
        subtitle: 'Lunch marked done with protein estimate',
        occurredAt: now.subtract(const Duration(days: 8)),
        valueLabel: '32g protein',
      ),
    ];

    entries.addAll(
      state.trackerSessions.map(
        (session) => TrackerHistoryEntry(
          id: session.id,
          trackerType: session.title,
          category: session.category == 'Habits'
              ? 'Bad Habits'
              : session.category,
          title: session.title,
          subtitle: session.isCompleted
              ? 'Completed session'
              : 'Pending session',
          occurredAt: session.timestamp,
          valueLabel: '${session.value}',
          completed: session.isCompleted,
        ),
      ),
    );
    entries.addAll(
      state.savingsEntries.map(
        (entry) => TrackerHistoryEntry(
          id: entry.id,
          trackerType: 'money',
          category: 'Finance',
          title: entry.isConfirmed ? 'Money saving entry' : 'Potential saving',
          subtitle: entry.description,
          occurredAt: entry.createdAt,
          valueLabel: formatMoney(entry.amount, region),
          completed: entry.isConfirmed,
        ),
      ),
    );
    entries.addAll(
      state.hydrationLogs.map(
        (log) => TrackerHistoryEntry(
          id: log.id,
          trackerType: 'hydration',
          category: 'Body',
          title: 'Hydration log',
          subtitle: log.timestamp,
          occurredAt: now,
          valueLabel: '${log.amountMl}ml',
        ),
      ),
    );
    entries.addAll(
      state.fitnessActivities.map(
        (activity) => TrackerHistoryEntry(
          id: activity.id,
          trackerType: 'fitness',
          category: 'Body',
          title: 'Fitness activity',
          subtitle: activity.activityType.label,
          occurredAt: activity.startedAt,
          valueLabel: '${activity.distanceKm.toStringAsFixed(1)} km',
        ),
      ),
    );
    entries.addAll(
      state.badHabitLogs.map(
        (log) => TrackerHistoryEntry(
          id: log.id,
          trackerType: log.habitType.name,
          category: 'Bad Habits',
          title: 'Bad habit log',
          subtitle: '${log.title}: ${log.status.name}',
          occurredAt: log.loggedAt,
          valueLabel: log.potentialSaved > 0
              ? 'Rs ${log.potentialSaved.toStringAsFixed(0)}'
              : null,
        ),
      ),
    );
    entries.addAll(
      state.focusSessions.map(
        (session) => TrackerHistoryEntry(
          id: session.id,
          trackerType: 'focus',
          category: 'Focus',
          title: 'Focus session',
          subtitle: session.linkedRoutineTitle ?? session.mode.name,
          occurredAt: session.completedAt ?? session.startedAt,
          valueLabel: '${session.completedMinutes}m',
        ),
      ),
    );
    entries.addAll(
      state.sleepLogs.map(
        (log) => TrackerHistoryEntry(
          id: log.id,
          trackerType: 'sleep',
          category: 'Body',
          title: 'Sleep log',
          subtitle: log.quality.name,
          occurredAt: log.wakeDateTime,
          valueLabel: '${(log.durationMinutes / 60).toStringAsFixed(1)}h',
        ),
      ),
    );
    entries.addAll(
      state.nutritionLogs.map(
        (log) => TrackerHistoryEntry(
          id: log.id,
          trackerType: 'nutrition',
          category: 'Body',
          title: 'Nutrition log',
          subtitle: log.mealType.name,
          occurredAt: log.loggedAt,
          valueLabel: '${log.estimatedProtein.toStringAsFixed(0)}g protein',
          completed: log.done,
        ),
      ),
    );

    entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return entries;
  }
}

class _HistorySection extends StatelessWidget {
  final String title;
  final List<TrackerHistoryEntry> entries;
  final ValueChanged<TrackerHistoryEntry> onTap;

  const _HistorySection({
    required this.title,
    required this.entries,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return LiquidDetailSection(
      title: title,
      children: entries
          .map(
            (entry) => LiquidActionRow(
              icon: _iconFor(entry.category),
              title: entry.title,
              subtitle: entry.subtitle,
              accentColor: _colorFor(entry.category),
              trailing: Text(
                entry.valueLabel ?? '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: _colorFor(entry.category),
                ),
              ),
              onTap: () => onTap(entry),
            ),
          )
          .toList(),
    );
  }

  IconData _iconFor(String category) {
    return switch (category) {
      'Mind' => Icons.self_improvement_rounded,
      'Body' => Icons.directions_run_rounded,
      'Focus' => Icons.center_focus_strong_rounded,
      'Finance' => Icons.savings_outlined,
      'Bad Habits' => Icons.smoke_free_outlined,
      _ => Icons.track_changes_rounded,
    };
  }

  Color _colorFor(String category) {
    return switch (category) {
      'Mind' => OptivusColors.purpleAccent,
      'Body' => OptivusColors.blueAccent,
      'Focus' => OptivusColors.trackerAccent,
      'Finance' => OptivusColors.mintAccent,
      'Bad Habits' => OptivusColors.danger,
      _ => OptivusColors.trackerAccent,
    };
  }
}
