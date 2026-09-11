import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/base_timeline_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/classes_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/eating_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/fixed_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/skin_care_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/work_base_setup_screen.dart';

import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/screens/routine_habit_systems_screen.dart';
import 'package:optivus/features/routine/screens/routine_history_screen.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/routine_header.dart';
import 'package:optivus/features/routine/widgets/routine_title_filter_row.dart';
import 'package:optivus/features/routine/widgets/routine_timeline_viewport.dart';
import 'package:optivus/features/routine/widgets/routine_write_status_banner.dart';
import 'package:optivus/features/routine/sheets/add_routine_sheet.dart';
import 'package:optivus/features/routine/sheets/ai_assistant_sheet.dart';
import 'package:optivus/features/routine/sheets/routine_detail_sheet.dart';
import 'package:optivus/state/app_state.dart';

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
  final List<RoutineDetailTarget> _detailStack = [];
  RoutineDetailTarget get _activeDetail =>
      _detailStack.isEmpty ? RoutineDetailTarget.none : _detailStack.last;
  bool _initialRoutineLoadRequested = false;

  @override
  void initState() {
    super.initState();
    // Refresh every 60 seconds for the current time indicator
    _minuteTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureCompletedAccountRoutinesLoaded());
    });
  }

  Future<void> _ensureCompletedAccountRoutinesLoaded() async {
    if (!mounted || _initialRoutineLoadRequested) return;
    final profile = ref.read(userProfileProvider);
    final routineState = ref.read(routineNotifierProvider);
    if (!profile.onboardingCompleted ||
        profile.uid.trim().isEmpty ||
        routineState.loading ||
        routineState.items.isNotEmpty) {
      return;
    }
    _initialRoutineLoadRequested = true;
    try {
      await ref
          .read(routineNotifierProvider.notifier)
          .loadForOwner(profile.uid);
    } catch (_) {
      // RoutineState retains the safe loading error and normal recovery UI.
    }
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  void _openDetail(RoutineDetailTarget target) {
    if (target.view == RoutineDetailView.none) {
      setState(() => _detailStack.clear());
      return;
    }
    setState(() {
      if (_detailStack.isEmpty &&
          (target.view == RoutineDetailView.classesSetup ||
              target.view == RoutineDetailView.workSetup ||
              target.view == RoutineDetailView.eatingSetup ||
              target.view == RoutineDetailView.fixedSetup ||
              target.view == RoutineDetailView.skinCareSetup)) {
        _detailStack.add(
          const RoutineDetailTarget(view: RoutineDetailView.baseTimeline),
        );
      }
      _detailStack.add(target);
    });
  }

  void _closeDetail() {
    if (_detailStack.isNotEmpty) {
      setState(() => _detailStack.removeLast());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(routineDetailViewRequestProvider, (previous, next) {
      if (next.view == RoutineDetailView.none) return;
      _openDetail(next);
      ref.read(routineDetailViewRequestProvider.notifier).state =
          RoutineDetailTarget.none;
    });

    final pending = ref.watch(routineDetailViewRequestProvider);
    if (pending.view != RoutineDetailView.none &&
        _activeDetail.view != pending.view) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openDetail(pending);
        ref.read(routineDetailViewRequestProvider.notifier).state =
            RoutineDetailTarget.none;
      });
    }

    if (_activeDetail.view != RoutineDetailView.none) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _closeDetail();
        },
        child: _buildDetail(),
      );
    }

    final state = ref.watch(routineNotifierProvider);
    final selectedDay = state.selectedDay;
    final showFullDay = state.showFullDay;
    final showMinuteTicks = state.showMinuteTicks;
    final showCurrentTimeLine = state.showCurrentTimeLine;
    final compactMode = state.compactMode;
    final isToday = TimelineUtils.isToday(selectedDay);
    final filteredItems = ref.watch(filteredRoutineItemsProvider);

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

    // ── Layout matches old: LiquidBg → Scaffold(transparent) → Stack ──
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── Header: Date + AI/Add/Settings ──
                RoutineHeader(
                  onAITap: () => showAIAssistantSheet(context, ref),
                  onAddTap: () => showAddRoutineSheet(context, ref),
                  onSettingsTap: () => _openDetail(
                    const RoutineDetailTarget(
                      view: RoutineDetailView.routineSettings,
                    ),
                  ),
                ),

                // ── Controls: Selected Day + Week + Filter ──
                const RoutineTitleFilterRow(),
                const SizedBox(height: 12),

                // ── Write Status Banner ──
                const RoutineWriteStatusBanner(),

                // ── Timeline or Empty State ──
                Expanded(
                  child: state.loading
                      ? const Center(child: CircularProgressIndicator())
                      : sortedItems.isEmpty
                      ? Stack(
                          children: [
                            RoutineTimelineViewport(
                              items: const [],
                              layout: layout,
                              isToday: isToday,
                              showCurrentTimeLine: showCurrentTimeLine,
                            ),
                            Positioned.fill(
                              child: IgnorePointer(child: _buildEmptyState()),
                            ),
                          ],
                        )
                      : RoutineTimelineViewport(
                          items: sortedItems,
                          layout: layout,
                          isToday: isToday,
                          showCurrentTimeLine: showCurrentTimeLine,
                          onCardTap: (item) =>
                              showRoutineDetailSheet(context, ref, item),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail() {
    return switch (_activeDetail.view) {
      RoutineDetailView.baseTimeline => BaseTimelineScreen(
        onBack: _closeDetail,
        onOpenDetail: _openDetail,
      ),
      RoutineDetailView.classesSetup => ClassesBaseSetupScreen(
        onBack: _closeDetail,
      ),
      RoutineDetailView.workSetup => WorkBaseSetupScreen(onBack: _closeDetail),
      RoutineDetailView.eatingSetup => EatingBaseSetupScreen(
        onBack: _closeDetail,
      ),
      RoutineDetailView.fixedSetup => FixedBaseSetupScreen(
        onBack: _closeDetail,
      ),
      RoutineDetailView.skinCareSetup => SkinCareBaseSetupScreen(
        onBack: _closeDetail,
      ),
      RoutineDetailView.routineSettings => _RoutineSettingsInline(
        onBack: _closeDetail,
        onOpenDetail: _openDetail,
      ),
      RoutineDetailView.habitSystems => RoutineHabitSystemsScreen(
        onBack: _closeDetail,
      ),
      RoutineDetailView.routineHistory => RoutineHistoryScreen(
        onBack: _closeDetail,
      ),
      RoutineDetailView.none => const SizedBox.shrink(),
    };
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

class _RoutineSettingsInline extends ConsumerWidget {
  final VoidCallback onBack;
  final ValueChanged<RoutineDetailTarget> onOpenDetail;

  const _RoutineSettingsInline({
    required this.onBack,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routineNotifierProvider);
    final notifier = ref.read(routineNotifierProvider.notifier);

    return LiquidDetailScaffold(
      eyebrow: 'Routine',
      title: 'Routine Settings',
      subtitle:
          'Timeline display, automation, base timeline, and export preview.',
      accentColor: OptivusColors.routineAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Managers',
          children: [
            LiquidActionRow(
              icon: Icons.schedule_rounded,
              title: 'Base Timeline',
              subtitle: 'Classes, work, eating, fixed, and skin care.',
              accentColor: OptivusColors.routineAccent,
              onTap: () => onOpenDetail(
                const RoutineDetailTarget(view: RoutineDetailView.baseTimeline),
              ),
            ),
            LiquidActionRow(
              icon: Icons.psychology_rounded,
              title: 'Habit Systems',
              subtitle: 'Good habits, bad habits, and identity systems.',
              accentColor: OptivusColors.routineAccent,
              onTap: () => onOpenDetail(
                const RoutineDetailTarget(view: RoutineDetailView.habitSystems),
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Timeline View',
          children: [
            _RoutineSwitch(
              title: 'Full 24h mode',
              value: state.showFullDay,
              onChanged: notifier.toggleFullDay,
            ),
            _RoutineSwitch(
              title: 'Show minute ticks',
              value: state.showMinuteTicks,
              onChanged: notifier.toggleMinuteTicks,
            ),
            _RoutineSwitch(
              title: 'Compact mode',
              value: state.compactMode,
              onChanged: notifier.toggleCompactMode,
            ),
            _RoutineSwitch(
              title: 'Current Time Line',
              value: state.showCurrentTimeLine,
              onChanged: notifier.toggleCurrentTimeLine,
            ),
            _RoutineSwitch(
              title: 'Precision mode',
              value: state.precisionMode,
              onChanged: notifier.togglePrecisionMode,
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Automation',
          children: [
            _RoutineSwitch(
              title: 'AI Suggestions',
              value: state.aiRoutineSuggestionsEnabled,
              onChanged: notifier.toggleAiSuggestions,
            ),
            _RoutineSwitch(
              title: 'Notifications',
              value: state.routineNotificationsEnabled,
              onChanged: notifier.toggleNotifications,
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'History',
          children: [
            LiquidActionRow(
              icon: Icons.history_rounded,
              title: 'Routine History',
              subtitle: 'Completed, skipped, missed, moved, and check-ins.',
              accentColor: OptivusColors.routineAccent,
              onTap: () => onOpenDetail(
                const RoutineDetailTarget(
                  view: RoutineDetailView.routineHistory,
                ),
              ),
            ),
          ],
        ),
        const LiquidDetailSection(
          title: 'Export',
          children: [
            Text(
              'Export Schedule preview is local-share ready. Full generated exports should use Cloudflare R2 or local share, not Firebase Storage.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoutineSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RoutineSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidActionRow(
      icon: Icons.tune_rounded,
      title: title,
      accentColor: OptivusColors.routineAccent,
      trailing: Switch(
        value: value,
        activeThumbColor: OptivusColors.routineAccent,
        onChanged: onChanged,
      ),
    );
  }
}
