import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/routine_header.dart';
import 'package:optivus/features/routine/widgets/routine_title_filter_row.dart';
import 'package:optivus/features/routine/widgets/routine_day_selector.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_viewport.dart';
import 'package:optivus/features/routine/widgets/conflict_banner.dart';
import 'package:optivus/features/routine/sheets/add_routine_sheet.dart';
import 'package:optivus/features/routine/sheets/ai_assistant_sheet.dart';
import 'package:optivus/features/routine/sheets/routine_settings_sheet.dart';
import 'package:optivus/features/routine/sheets/routine_detail_sheet.dart';

/// The rebuilt Routine tab — full timeline control center.
///
/// Uses the exact old Optivus green gradient background via OptivusColors
/// tokens, with a minute-accurate scrollable timeline and glass-styled cards.
class RoutineTab extends ConsumerStatefulWidget {
  const RoutineTab({super.key});

  @override
  ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    // Refresh every 60 seconds for the current time indicator
    _minuteTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(mockRoutineProvider);
    final filter = ref.watch(routineFilterProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    final showFullDay = ref.watch(showFullDayProvider);
    final showMinuteTicks = ref.watch(showMinuteTicksProvider);
    final compactMode = ref.watch(compactModeProvider);
    final isToday = TimelineUtils.isToday(selectedDay);

    // Apply filter
    final filteredItems = TimelineUtils.filterItems(allItems, filter);

    // Sort by start time
    final sortedItems = List<RoutineItem>.from(filteredItems)
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    // Calculate visible range
    final layout = TimelineUtils.calculateVisibleRange(
      sortedItems,
      showFullDay: showFullDay,
      showMinuteTicks: showMinuteTicks,
      compactMode: compactMode,
    );

    // Count conflicts
    final conflictCount = allItems.where((i) => i.hasConflict).length;

    // ── Layout matches old: LiquidBg → Scaffold(transparent) → Stack ──
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            OptivusColors.routineBgTop,    // #A3FF91
            OptivusColors.routineBgBottom, // #EFFEEC
          ],
          stops: [0.0, 0.55],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // ── Header: Date + AI/Add/Settings ──
                  RoutineHeader(
                    onAITap: () => showAIAssistantSheet(context),
                    onAddTap: () => showAddRoutineSheet(context, ref),
                    onSettingsTap: () => showRoutineSettingsSheet(context, ref),
                  ),

                  // ── Title + Filter (inside same padding block as header) ──
                  const RoutineTitleFilterRow(),
                  const SizedBox(height: 16),

                  // ── Day Selector ──
                  const RoutineDaySelector(),
                  const SizedBox(height: 16),

                  // ── Conflict Banner ──
                  ConflictBanner(
                    conflictCount: conflictCount,
                    onTap: () {
                      ref.read(routineFilterProvider.notifier).state =
                          'conflicts';
                    },
                  ),
                  
                  // Add a small spacing if there are conflicts so timeline doesn't touch it
                  if (conflictCount > 0) const SizedBox(height: 12),

                  // ── Timeline or Empty State ──
                  Expanded(
                    child: sortedItems.isEmpty
                        ? _buildEmptyState()
                        : RoutineTimelineViewport(
                            items: sortedItems,
                            layout: layout,
                            isToday: isToday,
                            onCardTap: (item) {
                              showRoutineDetailSheet(context, ref, item);
                            },
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon box matching old TimelineDayEmptyState
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: OptivusColors.purpleAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.add_task_rounded,
                size: 34,
                color: OptivusColors.purpleAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No routine items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: OptivusColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "+ Add" to create your first\nroutine block',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: OptivusColors.sub.withValues(alpha: 0.82),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
