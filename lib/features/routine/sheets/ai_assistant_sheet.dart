import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/sheets/add_routine_sheet.dart';
import 'package:optivus/features/routine/sheets/routine_move_sheet.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/services/routine_day_availability.dart';
import 'package:optivus/models/routine_item.dart';

void showAIAssistantSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AIAssistantSheetBody(),
  );
}

class _AIAssistantSheetBody extends ConsumerStatefulWidget {
  const _AIAssistantSheetBody();

  @override
  ConsumerState<_AIAssistantSheetBody> createState() =>
      _AIAssistantSheetBodyState();
}

class _AIAssistantSheetBodyState extends ConsumerState<_AIAssistantSheetBody> {
  final Set<String> _rejected = {};

  @override
  Widget build(BuildContext context) {
    final suggestions = _buildSuggestions()
        .where((suggestion) => !_rejected.contains(suggestion.id))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.74,
      minChildSize: 0.4,
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
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
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 22,
                    color: OptivusColors.routineAccent,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI Routine Assistant',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Local planner suggestions. Nothing changes until you accept.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              if (suggestions.isEmpty)
                const _SuggestionShell(
                  icon: Icons.check_circle_rounded,
                  color: OptivusColors.success,
                  title: 'No urgent changes',
                  body:
                      'Your selected day has no unresolved local suggestions right now.',
                )
              else
                ...suggestions.map(_suggestionCard),
              const SizedBox(height: 10),
              const _OptionSummary(),
            ],
          ),
        );
      },
    );
  }

  Widget _suggestionCard(_RoutineSuggestion suggestion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _SuggestionShell(
        icon: suggestion.icon,
        color: suggestion.color,
        title: suggestion.title,
        body: suggestion.body,
        actions: [
          _ActionPill(
            label: 'Accept',
            color: OptivusColors.success,
            onTap: () async {
              final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
              if (suggestion.closesUserFlow) {
                Navigator.of(context).pop();
              }
              final error = await suggestion.accept();
              if (error != null && scaffoldMessenger != null) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: OptivusColors.danger,
                  ),
                );
              }
            },
          ),
          _ActionPill(
            label: 'Edit',
            color: OptivusColors.textSecondary,
            onTap: suggestion.edit,
          ),
          _ActionPill(
            label: 'Reject',
            color: OptivusColors.danger,
            onTap: () => setState(() => _rejected.add(suggestion.id)),
          ),
        ],
      ),
    );
  }

  List<_RoutineSuggestion> _buildSuggestions() {
    final day = ref.watch(routineNotifierProvider).selectedDay;
    final entries = ref.watch(selectedDayRoutineEntriesProvider);
    final controller = ref.read(routineNotifierProvider.notifier);
    final suggestions = <_RoutineSuggestion>[];

    final missed = entries.where((entry) {
      return entry.item.status == RoutineStatus.missed || entry.item.isMissed;
    }).toList();
    for (final entry in missed.take(1)) {
      final item = entry.item;
      final actionContext = RoutineActionContext.fromDayEntry(entry);
      suggestions.add(
        _RoutineSuggestion(
          id: 'reschedule-${item.id}',
          icon: Icons.schedule_rounded,
          color: OptivusColors.warning,
          title: 'Reschedule missed routine',
          body:
              '${item.title} was missed. Suggestion: reschedule it to an open slot later or another day.',
          accept: () async {
            showRoutineMoveSheet(
              context,
              ref,
              item,
              actionContext: actionContext,
            );
            return null;
          },
          edit: () => showRoutineMoveSheet(
            context,
            ref,
            item,
            actionContext: actionContext,
          ),
          closesUserFlow: false,
        ),
      );
    }

    final availability = RoutineDayAvailability.computeFromEntries(entries);
    final largest = availability.largestFreeInterval;
    if (largest != null && largest.durationMinutes >= 15) {
      final freeGap = FreeGap(largest.startMinute, largest.endMinute);
      suggestions.add(
        _RoutineSuggestion(
          id: 'fill-${freeGap.start}-${freeGap.end}',
          icon: Icons.add_task_rounded,
          color: OptivusColors.routineAccent,
          title: 'Fill free time',
          body:
              'AI found ${TimelineUtils.formatDuration(freeGap.duration)} free from ${TimelineUtils.formatMinute(freeGap.start)}. Suggestion: add a short focus or reading task.',
          accept: () async {
            final result = await controller.addItem(
              RoutineItem(
                id: 'ai-fill-${DateTime.now().millisecondsSinceEpoch}',
                title: 'Short focus block',
                date: TimelineUtils.dateOnly(day),
                startMinute: freeGap.start,
                endMinute: freeGap.start + 15,
                repeatDays: const [],
                blockType: RoutineBlockType.flexibleTask,
                category: RoutineCategory.focus,
                source: RoutineSource.aiSuggestion,
                priority: RoutinePriority.goodToDo,
                repeatRule: 'once',
                notes: 'Accepted from local Routine Assistant.',
              ),
            );
            if (!result.closesUserFlow) {
              return result.validation?.userSafeMessage ??
                  result.message ??
                  'Could not add task.';
            }
            return null;
          },
          edit: () => showAddRoutineSheet(context, ref),
        ),
      );
    }

    final longEntry = entries
        .where((entry) {
          final isPlannedOrActive =
              entry.item.status == RoutineStatus.planned ||
              entry.item.status == RoutineStatus.active ||
              (!entry.item.isCompleted &&
                  !entry.item.isMissed &&
                  entry.item.status != RoutineStatus.skipped);
          return entry.item.blockType == RoutineBlockType.flexibleTask &&
              isPlannedOrActive &&
              entry.item.durationMinutes > 45;
        })
        .cast<RoutineDayEntry?>()
        .firstWhere((entry) => entry != null, orElse: () => null);
    if (longEntry != null) {
      final longTask = longEntry.item;
      final actionContext = RoutineActionContext.fromDayEntry(longEntry);
      suggestions.add(
        _RoutineSuggestion(
          id: 'order-${longTask.id}',
          icon: Icons.swap_vert_rounded,
          color: OptivusColors.blockFlex,
          title: 'Make tiny version',
          body:
              '${longTask.title} is long for a crowded day (${longTask.durationMinutes} min). Suggestion: keep a 15-min tiny version and reschedule the remaining time.',
          accept: () async {
            final result = await controller.makeTinyVersion(
              longTask,
              occurrenceDate: actionContext.occurrenceDate,
              actionContext: actionContext,
            );
            if (!result.closesUserFlow) {
              return result.validation?.userSafeMessage ??
                  result.message ??
                  'Could not create tiny version.';
            }
            return null;
          },
          edit: () => showRoutineMoveSheet(
            context,
            ref,
            longTask,
            actionContext: actionContext,
          ),
        ),
      );
    }

    return suggestions;
  }
}

@visibleForTesting
class FreeGap {
  final int start;
  final int end;

  const FreeGap(this.start, this.end);

  int get duration => end - start;
}

@visibleForTesting
FreeGap calculateLargestFreeGap(dynamic itemsOrEntries) {
  final RoutineDayAvailability availability;
  if (itemsOrEntries is RoutineDayAvailability) {
    availability = itemsOrEntries;
  } else if (itemsOrEntries is List<RoutineDayEntry>) {
    availability = RoutineDayAvailability.computeFromEntries(itemsOrEntries);
  } else if (itemsOrEntries is List<RoutineItem>) {
    availability = RoutineDayAvailability.computeFromItems(itemsOrEntries);
  } else {
    throw ArgumentError(
      'calculateLargestFreeGap expects List<RoutineDayEntry>, List<RoutineItem>, or RoutineDayAvailability',
    );
  }
  final largest = availability.largestFreeInterval;
  if (largest == null || largest.durationMinutes <= 0) {
    return const FreeGap(18 * 60, 18 * 60);
  }
  return FreeGap(largest.startMinute, largest.endMinute);
}

class _RoutineSuggestion {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Future<String?> Function() accept;
  final VoidCallback edit;
  final bool closesUserFlow;

  const _RoutineSuggestion({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.accept,
    required this.edit,
    this.closesUserFlow = true,
  });
}

class _SuggestionShell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final List<Widget> actions;

  const _SuggestionShell({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: OptivusColors.textBody,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionPill({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _OptionSummary extends StatelessWidget {
  const _OptionSummary();

  @override
  Widget build(BuildContext context) {
    const options = [
      'Improve today\'s plan',
      'Fill free time',
      'Create tiny version',
      'Suggest better task order',
      'Rebuild this week',
    ];
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: options.map((option) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: OptivusColors.routineAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            option,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
        );
      }).toList(),
    );
  }
}
