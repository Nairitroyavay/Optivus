import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/coach/providers/coach_navigation_provider.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';

class RoutineHistoryScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const RoutineHistoryScreen({super.key, required this.onBack});

  @override
  ConsumerState<RoutineHistoryScreen> createState() =>
      _RoutineHistoryScreenState();
}

class _RoutineHistoryScreenState extends ConsumerState<RoutineHistoryScreen> {
  String _dateFilter = 'This Week';
  String _typeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final allItems = _historyRows(ref.watch(routineNotifierProvider).items);
    final filtered = allItems.where(_matchesFilters).toList();

    return LiquidDetailScaffold(
      eyebrow: 'Routine',
      title: 'Routine History',
      subtitle:
          'Completed, skipped, missed, rescheduled, tracker-completed, and check-in states.',
      accentColor: OptivusColors.routineAccent,
      onBack: widget.onBack,
      children: [
        LiquidDetailSection(
          title: 'Filters',
          children: [
            _FilterWrap(
              values: const ['Today', 'This Week', 'All'],
              selected: _dateFilter,
              onSelected: (value) => setState(() => _dateFilter = value),
            ),
            const SizedBox(height: 12),
            _FilterWrap(
              values: const [
                'All',
                'hard',
                'soft',
                'flexible',
                'tracker',
                'check-in',
                'money',
              ],
              selected: _typeFilter,
              onSelected: (value) => setState(() => _typeFilter = value),
            ),
          ],
        ),
        if (filtered.isEmpty)
          LiquidDetailSection(
            children: const [
              Text(
                'No routine history rows match this filter yet.',
                style: TextStyle(
                  color: OptivusColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          )
        else ...[
          _HistoryStatusSection(
            title: 'Completed',
            rows: filtered
                .where((row) => row.status == RoutineStatus.completed)
                .toList(),
            onTap: _showRow,
          ),
          _HistoryStatusSection(
            title: 'Skipped',
            rows: filtered
                .where((row) => row.status == RoutineStatus.skipped)
                .toList(),
            onTap: _showRow,
          ),
          _HistoryStatusSection(
            title: 'Missed',
            rows: filtered
                .where((row) => row.status == RoutineStatus.missed)
                .toList(),
            onTap: _showRow,
          ),
          _HistoryStatusSection(
            title: 'Rescheduled',
            rows: filtered
                .where((row) => row.status == RoutineStatus.moved)
                .toList(),
            onTap: _showRow,
          ),
          _HistoryStatusSection(
            title: 'Tracker-completed',
            rows: filtered.where((row) => row.linkedTracker != null).toList(),
            onTap: _showRow,
          ),
          _HistoryStatusSection(
            title: 'Check-ins',
            rows: filtered.where((row) => row.type == 'check-in').toList(),
            onTap: _showRow,
          ),
        ],
      ],
    );
  }

  List<_RoutineHistoryRow> _historyRows(List<RoutineItem> items) {
    final rows = items
        .where(
          (item) =>
              item.status == RoutineStatus.completed ||
              item.status == RoutineStatus.skipped ||
              item.status == RoutineStatus.missed ||
              item.status == RoutineStatus.moved ||
              item.isCompleted ||
              item.isMissed ||
              item.isTrackerLinked ||
              item.blockType == RoutineBlockType.checkIn,
        )
        .map(
          (item) => _RoutineHistoryRow(
            item: item,
            title: item.title,
            originalTime: TimelineUtils.formatTimeRange(
              item.startMinute,
              item.endMinute,
            ),
            status: item.status,
            source: item.source.name,
            type: _typeFor(item.blockType),
            linkedTracker: item.trackerType == TrackerType.none
                ? null
                : item.trackerType.name,
            date: item.date ?? DateTime.now(),
          ),
        )
        .toList();

    if (rows.isNotEmpty) return rows;
    final now = DateTime.now();
    return [
      _RoutineHistoryRow.example(
        title: 'Morning meditation',
        status: RoutineStatus.completed,
        type: 'tracker',
        linkedTracker: 'meditation',
        date: now,
      ),
      _RoutineHistoryRow.example(
        title: 'Money System',
        status: RoutineStatus.completed,
        type: 'money',
        linkedTracker: 'money',
        date: now,
      ),
      _RoutineHistoryRow.example(
        title: 'Cigarettes check-in',
        status: RoutineStatus.skipped,
        type: 'check-in',
        linkedTracker: 'smoking',
        date: now.subtract(const Duration(days: 1)),
      ),
      _RoutineHistoryRow.example(
        title: 'Workout block',
        status: RoutineStatus.missed,
        type: 'hard',
        date: now.subtract(const Duration(days: 2)),
      ),
      _RoutineHistoryRow.example(
        title: 'Reading practice',
        status: RoutineStatus.moved,
        type: 'flexible',
        date: now.subtract(const Duration(days: 4)),
      ),
    ];
  }

  bool _matchesFilters(_RoutineHistoryRow row) {
    final now = DateTime.now();
    final isToday =
        row.date.year == now.year &&
        row.date.month == now.month &&
        row.date.day == now.day;
    final isThisWeek = now.difference(row.date).inDays < 7;
    final dateOk = switch (_dateFilter) {
      'Today' => isToday,
      'This Week' => isThisWeek,
      _ => true,
    };
    final typeOk = _typeFilter == 'All' || row.type == _typeFilter;
    return dateOk && typeOk;
  }

  String _typeFor(RoutineBlockType type) {
    return switch (type) {
      RoutineBlockType.hardBlock => 'hard',
      RoutineBlockType.softBlock => 'soft',
      RoutineBlockType.flexibleTask => 'flexible',
      RoutineBlockType.trackerTask => 'tracker',
      RoutineBlockType.checkIn => 'check-in',
      RoutineBlockType.moneyTask => 'money',
    };
  }

  void _showRow(_RoutineHistoryRow row) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${row.originalTime} · ${row.status.name} · source ${row.source}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SheetButton(
                  label: 'Restore / repeat',
                  color: OptivusColors.routineAccent,
                  onTap: () => Navigator.of(context).pop(),
                ),
                _SheetButton(
                  label: 'Ask Coach',
                  color: OptivusColors.coachAccent,
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(appNavigationProvider.notifier).goToCoach();
                    ref.read(coachDetailViewRequestProvider.notifier).state =
                        CoachDetailView.newSession;
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryStatusSection extends StatelessWidget {
  final String title;
  final List<_RoutineHistoryRow> rows;
  final ValueChanged<_RoutineHistoryRow> onTap;

  const _HistoryStatusSection({
    required this.title,
    required this.rows,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return LiquidDetailSection(
      title: title,
      children: rows
          .map(
            (row) => LiquidActionRow(
              icon: _iconFor(row),
              title: row.title,
              subtitle:
                  '${row.originalTime} · ${row.status.name} · source ${row.source}${row.linkedTracker == null ? '' : ' · ${row.linkedTracker}'}',
              accentColor: _colorFor(row.status),
              onTap: () => onTap(row),
            ),
          )
          .toList(),
    );
  }

  IconData _iconFor(_RoutineHistoryRow row) {
    return switch (row.type) {
      'money' => Icons.savings_outlined,
      'tracker' => Icons.track_changes_rounded,
      'check-in' => Icons.fact_check_outlined,
      'hard' => Icons.lock_clock_rounded,
      'soft' => Icons.event_available_rounded,
      _ => Icons.history_rounded,
    };
  }

  Color _colorFor(RoutineStatus status) {
    return switch (status) {
      RoutineStatus.completed => OptivusColors.success,
      RoutineStatus.skipped => OptivusColors.warning,
      RoutineStatus.missed => OptivusColors.danger,
      RoutineStatus.moved => OptivusColors.routineAccent,
      _ => OptivusColors.routineAccent,
    };
  }
}

class _FilterWrap extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterWrap({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return GestureDetector(
          onTap: () => onSelected(value),
          child: LiquidPill(
            label: value,
            color: OptivusColors.routineAccent,
            filled: selected == value,
          ),
        );
      }).toList(),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
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

class _RoutineHistoryRow {
  final RoutineItem? item;
  final String title;
  final String originalTime;
  final RoutineStatus status;
  final String source;
  final String type;
  final String? linkedTracker;
  final DateTime date;

  const _RoutineHistoryRow({
    required this.item,
    required this.title,
    required this.originalTime,
    required this.status,
    required this.source,
    required this.type,
    this.linkedTracker,
    required this.date,
  });

  factory _RoutineHistoryRow.example({
    required String title,
    required RoutineStatus status,
    required String type,
    String? linkedTracker,
    required DateTime date,
  }) {
    return _RoutineHistoryRow(
      item: null,
      title: title,
      originalTime: '8:00 PM - 8:15 PM',
      status: status,
      source: 'frontend-preview',
      type: type,
      linkedTracker: linkedTracker,
      date: date,
    );
  }
}
