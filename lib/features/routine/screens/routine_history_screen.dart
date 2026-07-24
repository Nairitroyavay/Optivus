import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/coach/providers/coach_navigation_provider.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/features/routine/routine_state.dart';

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
    final state = ref.watch(routineNotifierProvider);
    final events = state.events;
    final corruptCount = state.corruptEvents.length;
    final allItems = _historyRows(events);
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
        if (corruptCount > 0)
          LiquidDetailSection(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OptivusColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: OptivusColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: OptivusColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Some history entries are unavailable ($corruptCount)',
                        style: const TextStyle(
                          color: OptivusColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (state.eventsError != null)
          LiquidDetailSection(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OptivusColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: OptivusColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Failed to load history: ${state.eventsError}',
                      style: const TextStyle(
                        color: OptivusColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(routineNotifierProvider.notifier)
                          .refreshEvents(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OptivusColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          )
        else if (state.eventsLoading)
          const LiquidDetailSection(
            children: [Center(child: CircularProgressIndicator())],
          )
        else if (filtered.isEmpty)
          const LiquidDetailSection(
            children: [
              Text(
                'No routine history rows match this filter yet.',
                style: TextStyle(
                  color: OptivusColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _HistoryStatusSection(
                title: 'Created',
                rows: filtered
                    .where((row) => row.eventType == RoutineEventType.created)
                    .toList(),
                onTap: _showRow,
              ),
              _HistoryStatusSection(
                title: 'Edited',
                rows: filtered
                    .where((row) => row.eventType == RoutineEventType.edited)
                    .toList(),
                onTap: _showRow,
              ),
              _HistoryStatusSection(
                title: 'Deleted',
                rows: filtered
                    .where((row) => row.eventType == RoutineEventType.deleted)
                    .toList(),
                onTap: _showRow,
              ),
              _HistoryStatusSection(
                title: 'Started',
                rows: filtered
                    .where((row) => row.eventType == RoutineEventType.started)
                    .toList(),
                onTap: _showRow,
              ),
              _HistoryStatusSection(
                title: 'Completed',
                rows: filtered
                    .where((row) => row.eventType == RoutineEventType.completed)
                    .toList(),
                onTap: _showRow,
              ),
              _HistoryStatusSection(
                title: 'Skipped',
                rows: filtered
                    .where((row) => row.eventType == RoutineEventType.skipped)
                    .toList(),
                onTap: _showRow,
              ),
              _HistoryStatusSection(
                title: 'Missed',
                rows: filtered
                    .where((row) => row.eventType == RoutineEventType.missed)
                    .toList(),
                onTap: _showRow,
              ),
              _HistoryStatusSection(
                title: 'Rescheduled',
                rows: filtered
                    .where(
                      (row) =>
                          row.eventType == RoutineEventType.moved ||
                          row.eventType == RoutineEventType.rescheduled,
                    )
                    .toList(),
                onTap: _showRow,
              ),
              _HistoryStatusSection(
                title: 'Undone',
                rows: filtered
                    .where((row) => row.eventType == RoutineEventType.undone)
                    .toList(),
                onTap: _showRow,
              ),
            ],
          ),
      ],
    );
  }

  List<_RoutineHistoryRow> _historyRows(List<RoutineEventRecord> events) {
    final sortedEvents = List<RoutineEventRecord>.from(events)
      ..sort((a, b) {
        final cmp = b.occurredAt.compareTo(a.occurredAt);
        if (cmp != 0) return cmp;
        return b.eventId.compareTo(a.eventId);
      });
    final seenEventIds = <String>{};

    return sortedEvents.where((event) => seenEventIds.add(event.eventId)).map((
      event,
    ) {
      final snap = event.itemSnapshot;

      final title = snap['title'] as String? ?? 'History entry unavailable';
      final startMinute = (snap['startMinute'] as int?) ?? 0;
      final endMinuteRaw = snap['endMinute'] as int?;
      final durationMinutes = snap['durationMinutes'] as int?;
      final blockTypeRaw = snap['blockType'] as String?;

      // We no longer synthesize "Unknown task" or "Event data unavailable" for corrupt records
      // Corrupt records should be caught in RoutineEventFeed.corruptEvents, and this method only receives validEvents.
      // So we can assume all required fields exist.

      final displayTitle = title;
      final effectiveStart = startMinute;
      final effectiveEnd =
          endMinuteRaw ?? (effectiveStart + (durationMinutes ?? 0));
      final blockType =
          RoutineBlockType.values
              .where((e) => e.name == blockTypeRaw)
              .firstOrNull ??
          RoutineBlockType.flexibleTask;
      final trackerRaw = snap['trackerTaskType'] as String?;

      return _RoutineHistoryRow(
        title: displayTitle,
        originalTime: TimelineUtils.formatTimeRange(
          effectiveStart,
          effectiveEnd,
        ),
        eventType: event.eventType,
        source: event.source,
        type: _typeFor(blockType),
        linkedTracker: trackerRaw,
        date: event.occurredAt,
        eventId: event.eventId,
      );
    }).toList();
  }

  bool _matchesFilters(_RoutineHistoryRow row) {
    final now = DateTime.now();
    final isToday =
        row.date.year == now.year &&
        row.date.month == now.month &&
        row.date.day == now.day;
    final weekday = now.weekday; // Monday = 1
    final monday = DateTime(now.year, now.month, now.day - (weekday - 1));
    final isThisWeek = !row.date.isAfter(now) && !row.date.isBefore(monday);
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
                  row.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${row.originalTime} · ${row.eventType.name} · source ${row.source}',
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
                      label: 'Ask Coach',
                      color: OptivusColors.coachAccent,
                      onTap: () {
                        Navigator.of(context).pop();
                        ref.read(appNavigationProvider.notifier).goToCoach();
                        ref
                                .read(coachDetailViewRequestProvider.notifier)
                                .state =
                            CoachDetailView.newSession;
                      },
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
                  '${row.originalTime} · ${row.eventType.name} · source ${row.source}${row.linkedTracker == null ? '' : ' · ${row.linkedTracker}'}',
              accentColor: _colorFor(row.eventType),
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

  Color _colorFor(RoutineEventType type) {
    return switch (type) {
      RoutineEventType.completed => OptivusColors.success,
      RoutineEventType.skipped => OptivusColors.warning,
      RoutineEventType.missed => OptivusColors.danger,
      RoutineEventType.moved => OptivusColors.routineAccent,
      RoutineEventType.deleted => OptivusColors.danger,
      RoutineEventType.created => OptivusColors.success,
      RoutineEventType.started => OptivusColors.aquaAccent,
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
  final String title;
  final String originalTime;
  final RoutineEventType eventType;
  final String source;
  final String type;
  final String? linkedTracker;
  final DateTime date;
  final String eventId;

  const _RoutineHistoryRow({
    required this.title,
    required this.originalTime,
    required this.eventType,
    required this.source,
    required this.type,
    this.linkedTracker,
    required this.date,
    required this.eventId,
  });
}
