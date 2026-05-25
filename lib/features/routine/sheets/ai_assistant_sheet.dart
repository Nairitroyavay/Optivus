import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/sheets/add_routine_sheet.dart';
import 'package:optivus/features/routine/sheets/routine_move_sheet.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
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
              colors: [Color(0xFFF0FFF0), Color(0xFFDCFFCC)],
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
            onTap: () {
              suggestion.accept();
              Navigator.of(context).pop();
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
    final day = ref.watch(selectedDayProvider);
    final items = ref.watch(selectedDayRoutineItemsProvider);
    final conflicts = ref.watch(routineConflictsProvider);
    final controller = ref.read(routineControllerProvider);
    final suggestions = <_RoutineSuggestion>[];

    for (final conflict in conflicts.take(3)) {
      final item = _itemById(items, conflict.itemId);
      if (item == null) continue;
      final freeSlot = controller.findFreeSlot(item: item, date: day);
      suggestions.add(
        _RoutineSuggestion(
          id: 'fix-${conflict.id}',
          icon: Icons.warning_amber_rounded,
          color: conflict.blocking
              ? OptivusColors.danger
              : OptivusColors.warning,
          title: 'Fix conflict',
          body: freeSlot == null
              ? '${conflict.message}\nSuggestion: make a tiny version or move it tomorrow.'
              : '${conflict.message}\nSuggestion: move ${item.title} to ${TimelineUtils.formatMinute(freeSlot)}.',
          accept: () {
            if (freeSlot == null) {
              controller.makeTinyVersion(item);
            } else {
              controller.moveItem(
                itemId: item.id,
                date: day,
                startMinute: freeSlot,
                durationMinutes: item.durationMinutes,
              );
            }
          },
          edit: () => showRoutineMoveSheet(context, ref, item),
        ),
      );
    }

    final missed = items.where((item) {
      return item.status == RoutineStatus.missed || item.isMissed;
    }).toList();
    for (final item in missed.take(1)) {
      suggestions.add(
        _RoutineSuggestion(
          id: 'tiny-${item.id}',
          icon: Icons.compress_rounded,
          color: OptivusColors.warning,
          title: 'Create tiny version',
          body:
              '${item.title} was missed. Suggestion: keep a 5-10 min version today instead of dropping the habit.',
          accept: () => controller.makeTinyVersion(item),
          edit: () => showRoutineMoveSheet(context, ref, item),
        ),
      );
    }

    final freeGap = _largestFreeGap(items);
    if (freeGap.duration >= 15) {
      suggestions.add(
        _RoutineSuggestion(
          id: 'fill-${freeGap.start}-${freeGap.end}',
          icon: Icons.add_task_rounded,
          color: OptivusColors.routineAccent,
          title: 'Fill free time',
          body:
              'AI found ${TimelineUtils.formatDuration(freeGap.duration)} free from ${TimelineUtils.formatMinute(freeGap.start)}. Suggestion: add a short focus or reading task.',
          accept: () {
            controller.addItem(
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
          },
          edit: () => showAddRoutineSheet(context, ref),
        ),
      );
    }

    final longTask = items
        .where((item) {
          return item.blockType == RoutineBlockType.flexibleTask &&
              item.durationMinutes > 45;
        })
        .cast<RoutineItem?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (longTask != null) {
      suggestions.add(
        _RoutineSuggestion(
          id: 'order-${longTask.id}',
          icon: Icons.swap_vert_rounded,
          color: OptivusColors.blockFlex,
          title: 'Suggest better task order',
          body:
              '${longTask.title} is long for a crowded day. Suggestion: split it by making a tiny version now and moving the full block later.',
          accept: () => controller.makeTinyVersion(longTask),
          edit: () => showRoutineMoveSheet(context, ref, longTask),
        ),
      );
    }

    return suggestions;
  }

  RoutineItem? _itemById(List<RoutineItem> items, String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  _FreeGap _largestFreeGap(List<RoutineItem> items) {
    final sorted =
        items
            .where((item) => !item.allowOverlap && item.durationMinutes > 0)
            .toList()
          ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    var cursor = 6 * 60;
    var best = const _FreeGap(18 * 60, 18 * 60);
    for (final item in sorted) {
      if (item.startMinute > cursor &&
          item.startMinute - cursor > best.duration) {
        best = _FreeGap(cursor, item.startMinute);
      }
      final end = TimelineUtils.normalizedEndMinute(
        item,
      ).clamp(0, 24 * 60).toInt();
      if (end > cursor) cursor = end;
    }
    if (23 * 60 - cursor > best.duration) {
      best = _FreeGap(cursor, 23 * 60);
    }
    return best;
  }
}

class _RoutineSuggestion {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final VoidCallback accept;
  final VoidCallback edit;

  const _RoutineSuggestion({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.accept,
    required this.edit,
  });
}

class _FreeGap {
  final int start;
  final int end;

  const _FreeGap(this.start, this.end);

  int get duration => end - start;
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
      'Fix conflicts',
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
