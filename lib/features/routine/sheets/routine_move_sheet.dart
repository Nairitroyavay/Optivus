import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/features/routine/services/routine_action_executor.dart';
import 'package:optivus/features/routine/services/routine_move_seed.dart';

void showRoutineMoveSheet(
  BuildContext context,
  WidgetRef ref,
  RoutineItem item, {
  DateTime? occurrenceDate,
  DateTime? displayDate,
  RoutineActionContext? actionContext,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RoutineMoveSheet(
      item: item,
      occurrenceDate: occurrenceDate,
      displayDate: displayDate,
      actionContext: actionContext,
    ),
  );
}

class _RoutineMoveSheet extends ConsumerStatefulWidget {
  final RoutineItem item;
  final DateTime? occurrenceDate;
  final DateTime? displayDate;
  final RoutineActionContext? actionContext;

  const _RoutineMoveSheet({
    required this.item,
    this.occurrenceDate,
    this.displayDate,
    this.actionContext,
  });

  @override
  ConsumerState<_RoutineMoveSheet> createState() => _RoutineMoveSheetState();
}

class _RoutineMoveSheetState extends ConsumerState<_RoutineMoveSheet> {
  late DateTime _date;
  late int _startMinute;
  late int _duration;
  late final int _seedStartMinute;
  late final int _seedDuration;
  late final RoutineActionContext _canonicalActionContext;
  bool _pending = false;
  String? _error;

  DateTime get _sourceOccurrenceDate => _canonicalActionContext.occurrenceDate;
  DateTime get _displayAnchorDate => _canonicalActionContext.displayDate;

  @override
  void initState() {
    super.initState();
    final selectedDay = ref.read(routineNotifierProvider).selectedDay;
    final sourceAnchor =
        widget.actionContext?.occurrenceDate ??
        widget.occurrenceDate ??
        widget.item.date ??
        selectedDay;
    final initialAnchor =
        widget.actionContext?.displayDate ?? widget.displayDate ?? sourceAnchor;
    _canonicalActionContext =
        widget.actionContext ??
        RoutineActionContext.fallback(
          item: widget.item,
          occurrenceDate: sourceAnchor,
          displayDate: initialAnchor,
        );
    _date = TimelineUtils.dateOnly(initialAnchor);
    final routineState = ref.read(routineNotifierProvider);
    final seed = RoutineMoveSeedResolver.resolve(
      actionContext: _canonicalActionContext,
      visibleItem: widget.item,
      templates: routineState.items,
      occurrences: routineState.occurrences,
    );
    _startMinute = seed.startMinute;
    _duration = seed.durationMinutes;
    _seedStartMinute = seed.startMinute;
    _seedDuration = seed.durationMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final precisionMode = ref.watch(routineNotifierProvider).precisionMode;
    final snap = precisionMode ? 1 : 5;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                OptivusColors.routineSheetTop,
                OptivusColors.routineSheetBottom,
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Move ${widget.item.title}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final currentEnd = (_seedStartMinute + _seedDuration) > 1440
                      ? (_seedStartMinute + _seedDuration - 1440)
                      : (_seedStartMinute + _seedDuration);
                  final currentRange =
                      TimelineUtils.formatTimeRange(_seedStartMinute, currentEnd);
                  return Text(
                    'Current: $currentRange',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textSecondary,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _FieldTile(
                      label: 'New date',
                      value: _formatDate(_date),
                      icon: Icons.calendar_today_rounded,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldTile(
                      label: 'Start',
                      value: TimelineUtils.formatMinute(_startMinute),
                      icon: Icons.schedule_rounded,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _StepperTile(
                label: 'Duration',
                value: TimelineUtils.formatDuration(_duration),
                onMinus: () => setState(() {
                  _duration = (_duration - snap).clamp(1, 24 * 60).toInt();
                }),
                onPlus: () => setState(() {
                  _duration = (_duration + snap).clamp(1, 24 * 60).toInt();
                }),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                value: precisionMode,
                onChanged: (value) => ref
                    .read(routineNotifierProvider.notifier)
                    .togglePrecisionMode(value),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeTrackColor: OptivusColors.routineAccent,
                title: const Text(
                  'Precision mode',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  precisionMode
                      ? 'Snapping to 1 minute'
                      : 'Snapping to 5 minutes',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionPill(
                    label: 'Find free slot',
                    color: OptivusColors.routineAccent,
                    icon: Icons.search_rounded,
                    onTap: _pending ? null : _findFreeSlot,
                  ),
                  _ActionPill(
                    label: 'Make tiny version (5-10m)',
                    color: OptivusColors.routineAccent,
                    icon: Icons.compress_rounded,
                    pending: _pending,
                    onTap: _pending
                        ? null
                        : () => _runWrite(
                            RoutineOccurrenceAction.makeTiny,
                            () => ref
                                .read(routineNotifierProvider.notifier)
                                .makeTinyVersion(
                                  widget.item,
                                  occurrenceDate: _sourceOccurrenceDate,
                                  displayDate: widget.displayDate,
                                  startMinute: _seedStartMinute,
                                  durationMinutes: _seedDuration,
                                ),
                          ),
                  ),
                  _ActionPill(
                    label: 'Move to tomorrow',
                    color: OptivusColors.textSecondary,
                    icon: Icons.today_rounded,
                    pending: _pending,
                    onTap: _pending
                        ? null
                        : () => _runWrite(
                            RoutineOccurrenceAction.move,
                            () => ref
                                .read(routineNotifierProvider.notifier)
                                .moveToTomorrow(
                                  widget.item,
                                  occurrenceDate: _sourceOccurrenceDate,
                                  displayDate: _displayAnchorDate,
                                  startMinute: _seedStartMinute,
                                  durationMinutes: _seedDuration,
                                ),
                          ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OptivusColors.routineAccent,
                    disabledBackgroundColor: OptivusColors.disabled,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _pending
                      ? null
                      : () => _runWrite(
                          RoutineOccurrenceAction.move,
                          () => ref
                              .read(routineNotifierProvider.notifier)
                              .moveItem(
                                itemId: widget.item.id,
                                date: _date,
                                startMinute: _startMinute,
                                durationMinutes: _duration,
                                occurrenceDate: _sourceOccurrenceDate,
                              ),
                        ),
                  child: _pending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Move task',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final earliest = _date.isBefore(now)
        ? _date.subtract(const Duration(days: 365))
        : now.subtract(const Duration(days: 365));
    final latest = _date.isAfter(now)
        ? _date.add(const Duration(days: 365))
        : now.add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: TimelineUtils.dateOnly(earliest),
      lastDate: TimelineUtils.dateOnly(latest),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _startMinute ~/ 60,
        minute: _startMinute % 60,
      ),
    );
    if (picked != null) {
      final rawMinute = picked.hour * 60 + picked.minute;
      final snap = ref.read(routineNotifierProvider).precisionMode ? 1 : 5;
      setState(() => _startMinute = (rawMinute / snap).round() * snap);
    }
  }

  void _findFreeSlot() {
    if (_pending) return;
    final start = ref
        .read(routineNotifierProvider.notifier)
        .findFreeSlot(
          item: widget.item,
          date: _date,
          durationMinutes: _duration,
          occurrenceDate: _sourceOccurrenceDate,
        );
    if (start != null) {
      setState(() => _startMinute = start);
    } else {
      setState(
        () => _error =
            'No open slot found. You can still choose any time manually.',
      );
    }
  }

  Future<void> _runWrite(
    RoutineOccurrenceAction action,
    Future<RoutineWriteResult> Function() write,
  ) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await RoutineActionExecutor.execute(
      ref: ref,
      actionContext: _canonicalActionContext,
      action: action,
      perform: write,
      showFeedback: false,
    );
    if (!mounted) return;
    if (result.outcome == RoutineWriteOutcome.saved ||
        (result.outcome == RoutineWriteOutcome.noOp &&
            result.validation?.isValid != false)) {
      Navigator.of(context).pop();
      RoutineActionExecutor.showOutcomeFeedbackWithMessenger(messenger, result);
      return;
    }
    setState(() {
      _pending = false;
      _error =
          result.validation?.userSafeMessage ??
          result.message ??
          'Failed to update this item. Please adjust the move and retry.';
    });
    RoutineActionExecutor.showOutcomeFeedbackWithMessenger(messenger, result);
  }

  String _formatDate(DateTime date) {
    return '${TimelineUtils.getShortDayName(date.weekday)} ${date.day}/${date.month}';
  }
}

class _FieldTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _FieldTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: OptivusColors.routineAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _StepperTile({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: OptivusColors.textSecondary,
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: OptivusColors.routineAccent,
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool pending;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.label,
    required this.color,
    required this.icon,
    this.pending = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.48,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              if (pending && enabled) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
