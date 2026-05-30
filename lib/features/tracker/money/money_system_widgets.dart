import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_blur_card.dart';
import 'package:optivus/core/widgets/liquid_buttons.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/features/tracker/money/money_system_mock_flows.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/state/app_state.dart';

String moneyDateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String formatMoney(double amount) => '₹${amount.toInt()}';

bool isTinySavingEntry(SavingEntry entry, MoneyGoal goal) {
  return entry.isConfirmed &&
      (entry.description.toLowerCase().contains('tiny') ||
          entry.amount <= goal.tinySaveAmount);
}

List<SavingEntry> moneyEntriesForToday(MockTrackerState state) {
  final todayKey = moneyDateKey(DateTime.now());
  final entries = state.savingsEntries
      .where((entry) => entry.dateKey == todayKey)
      .toList(growable: false);
  return entries..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

String todayMoneyStatusLabel(MockTrackerState state) {
  final entries = moneyEntriesForToday(state);
  final confirmed = entries.where((entry) => entry.isConfirmed).toList();
  if (confirmed.any((entry) => isTinySavingEntry(entry, state.moneyGoal))) {
    return 'Tiny saved';
  }
  if (confirmed.isNotEmpty) return 'Saved';
  if (entries.any((entry) => entry.isSkipped)) return 'Skipped';
  return 'Not saved yet';
}

Color moneyStatusColor(String status) {
  return switch (status) {
    'Saved' => OptivusColors.mintAccent,
    'Tiny saved' => OptivusColors.mintAccent,
    'Skipped' => OptivusColors.roseAccent,
    _ => OptivusColors.trackerAccent,
  };
}

double levelProgress(MoneyGoal goal) {
  if (goal.levelUpAfterDays <= 0) return 0;
  return (goal.successfulDaysAtCurrentLevel / goal.levelUpAfterDays)
      .clamp(0.0, 1.0)
      .toDouble();
}

class MoneyHeroTargetCard extends ConsumerWidget {
  const MoneyHeroTargetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockTrackerProvider);
    final goal = state.moneyGoal;
    final status = todayMoneyStatusLabel(state);
    final statusColor = moneyStatusColor(status);
    final progress = levelProgress(goal);

    return TrackerGlassCard(
      radius: 32,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s target',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.sub,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatMoney(goal.dailyTarget),
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.ink,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: status, color: statusColor),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth < 340;
              final cards = [
                _HeroStat(
                  label: 'Confirmed',
                  value: formatMoney(goal.totalConfirmedSaved),
                  color: OptivusColors.mintAccent,
                ),
                _HeroStat(
                  label: 'Potential',
                  value: formatMoney(goal.totalPotentialSaved),
                  color: OptivusColors.purpleAccent,
                ),
                _HeroStat(
                  label: 'Streak',
                  value: '${goal.streakDays}d',
                  color: OptivusColors.trackerAccent,
                ),
              ];
              if (!twoColumns) {
                return Row(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: (constraints.maxWidth - 10) / 2,
                        child: card,
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 20),
          _LevelProgressPanel(
            currentLevel: goal.currentLevelAmount,
            nextLevel: goal.nextLevelAmount,
            progress: progress,
            completedDays: goal.successfulDaysAtCurrentLevel,
            targetDays: goal.levelUpAfterDays,
          ),
        ],
      ),
    );
  }
}

class TodayFinanceProofCard extends ConsumerWidget {
  const TodayFinanceProofCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(mockTrackerProvider).moneyGoal;
    return TrackerGlassCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: OptivusColors.trackerAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: OptivusColors.trackerAccent.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.savings_outlined,
                  color: OptivusColors.trackerAccent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today finance proof',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Save a small amount today to protect your future self.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: OptivusColors.sub,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Target ${formatMoney(goal.dailyTarget)} • Tiny ${formatMoney(goal.tinySaveAmount)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: OptivusColors.trackerAccent,
            ),
          ),
          const SizedBox(height: 14),
          const MoneyQuickActionRow(),
        ],
      ),
    );
  }
}

class MoneyQuickActionRow extends ConsumerWidget {
  final String? routineTaskId;
  final VoidCallback? onSaved;
  final VoidCallback? onSkipped;

  const MoneyQuickActionRow({
    super.key,
    this.routineTaskId,
    this.onSaved,
    this.onSkipped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidPrimaryButton(
          label: 'Save via UPI mock',
          icon: Icons.payment_rounded,
          backgroundColor: OptivusColors.trackerAccent,
          foregroundColor: OptivusColors.ink,
          onPressed: () => showSaveViaUpiFlow(
            context,
            ref,
            source: routineTaskId == null
                ? MoneyEntrySource.upiMock
                : MoneyEntrySource.routineTask,
            routineTaskId: routineTaskId,
            onSaved: onSaved,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: LiquidOutlineButton(
                label: 'I already saved',
                icon: Icons.check_rounded,
                borderColor: OptivusColors.mintAccent,
                onPressed: () => showIAlreadySavedFlow(
                  context,
                  ref,
                  source: routineTaskId == null
                      ? MoneyEntrySource.manual
                      : MoneyEntrySource.routineTask,
                  routineTaskId: routineTaskId,
                  onSaved: onSaved,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiquidOutlineButton(
                label: 'Tiny save',
                icon: Icons.savings_outlined,
                borderColor: OptivusColors.trackerAccent,
                onPressed: () => showTinySaveFlow(
                  context,
                  ref,
                  routineTaskId: routineTaskId,
                  onSaved: onSaved,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LiquidOutlineButton(
          label: 'Skip today',
          icon: Icons.skip_next_rounded,
          borderColor: OptivusColors.roseAccent,
          onPressed: () =>
              showSkipTodayFlow(context, ref, onSkipped: onSkipped),
        ),
      ],
    );
  }
}

class WeeklySavingStrip extends ConsumerWidget {
  const WeeklySavingStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockTrackerProvider);
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TrackerSectionHeader(title: 'This week'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(7, (index) {
              final date = monday.add(Duration(days: index));
              final dateKey = moneyDateKey(date);
              final entries = state.savingsEntries
                  .where((entry) => entry.dateKey == dateKey)
                  .toList(growable: false);
              final confirmed = entries
                  .where((entry) => entry.isConfirmed)
                  .fold(0.0, (sum, entry) => sum + entry.amount);
              final potential = entries
                  .where((entry) => entry.isPotential)
                  .fold(0.0, (sum, entry) => sum + entry.amount);
              final skipped = entries.any((entry) => entry.isSkipped);
              final isToday = dateKey == moneyDateKey(now);
              final color = confirmed > 0
                  ? OptivusColors.mintAccent
                  : skipped
                  ? OptivusColors.roseAccent
                  : isToday
                  ? OptivusColors.trackerAccent
                  : OptivusColors.sub;
              final amountLabel = confirmed > 0
                  ? formatMoney(confirmed)
                  : potential > 0
                  ? formatMoney(potential)
                  : skipped
                  ? 'Missed'
                  : '-';

              return Padding(
                padding: EdgeInsets.only(right: index == 6 ? 0 : 8),
                child: Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withValues(alpha: 0.32)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: isToday
                              ? OptivusColors.ink
                              : OptivusColors.sub,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        amountLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: amountLabel == 'Missed' ? 10 : 12,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class MoneySourcesSummary extends ConsumerWidget {
  const MoneySourcesSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockTrackerProvider);
    double manual = 0;
    double upiMock = 0;
    double converted = 0;
    double potentialAvoided = 0;
    double routine = 0;

    for (final entry in state.savingsEntries) {
      if (entry.isPotential &&
          entry.source == MoneyEntrySource.badHabitAvoided) {
        potentialAvoided += entry.amount;
      }
      if (!entry.isConfirmed) continue;
      switch (entry.source) {
        case MoneyEntrySource.manual:
        case MoneyEntrySource.dailyTarget:
          manual += entry.amount;
        case MoneyEntrySource.upiMock:
          upiMock += entry.amount;
        case MoneyEntrySource.badHabitConverted:
          converted += entry.amount;
        case MoneyEntrySource.routineTask:
          routine += entry.amount;
        case MoneyEntrySource.badHabitAvoided:
        case MoneyEntrySource.adjustment:
          manual += entry.amount;
      }
    }

    return TrackerGlassCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TrackerSectionHeader(title: 'Money sources'),
          const SizedBox(height: 14),
          _SourceRow(
            label: 'Manual saving',
            amount: manual,
            color: OptivusColors.trackerAccent,
          ),
          _SourceRow(
            label: 'UPI mock saving',
            amount: upiMock,
            color: OptivusColors.trackerAccent,
          ),
          _SourceRow(
            label: 'Bad-habit money converted',
            amount: converted,
            color: OptivusColors.mintAccent,
          ),
          _SourceRow(
            label: 'Potential avoided money',
            amount: potentialAvoided,
            color: OptivusColors.purpleAccent,
          ),
          _SourceRow(
            label: 'Routine money task',
            amount: routine,
            color: OptivusColors.trackerAccent,
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: OptivusColors.borderSoft),
          const SizedBox(height: 12),
          _TotalRow(
            label: 'Confirmed saved total',
            value: formatMoney(state.moneyGoal.totalConfirmedSaved),
            color: OptivusColors.mintAccent,
          ),
          const SizedBox(height: 8),
          _TotalRow(
            label: 'Potential saved total',
            value: formatMoney(state.moneyGoal.totalPotentialSaved),
            color: OptivusColors.purpleAccent,
          ),
        ],
      ),
    );
  }
}

class TodayTabContent extends ConsumerWidget {
  const TodayTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockTrackerProvider);
    final goal = state.moneyGoal;
    final entries = moneyEntriesForToday(state);
    final status = todayMoneyStatusLabel(state);
    final confirmedAmount = entries
        .where((entry) => entry.isConfirmed)
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final skipped = entries.any((entry) => entry.isSkipped);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerGlassCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusPill(label: status, color: moneyStatusColor(status)),
                  const Spacer(),
                  Text(
                    confirmedAmount > 0
                        ? '${formatMoney(confirmedAmount)} today'
                        : 'No confirmed save yet',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                confirmedAmount > 0
                    ? 'Finance pillar completed'
                    : skipped
                    ? 'Come back with the tiny version if today still allows it.'
                    : 'Daily proof is still open. Save any real amount outside Optivus and mark it here.',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${goal.reminderTimeLabel} reminder • ${formatMoney(goal.tinySaveAmount)} tiny save available',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.sub,
                ),
              ),
              if (confirmedAmount == 0) ...[
                const SizedBox(height: 16),
                const MoneyQuickActionRow(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        TrackerGlassCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TrackerSectionHeader(title: 'Current day entries'),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                const _InlineEmptyState(
                  title: 'No finance proof yet',
                  body:
                      'Your first local entry will appear here after saving, skipping, or logging potential money.',
                )
              else
                ...entries.map((entry) => _EntryRow(entry: entry)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TrackerGlassCard(
          radius: 24,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: OptivusColors.trackerAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${goal.reminderTimeLabel} evening reminder: keep the finance pillar alive.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.ink,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _HistoryFilter {
  all,
  confirmed,
  potential,
  skipped,
  manual,
  upiMock,
  badHabit,
}

class HistoryTabContent extends ConsumerStatefulWidget {
  const HistoryTabContent({super.key});

  @override
  ConsumerState<HistoryTabContent> createState() => _HistoryTabContentState();
}

class _HistoryTabContentState extends ConsumerState<HistoryTabContent> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockTrackerProvider);
    final entries =
        state.savingsEntries.where(_matchesFilter).toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _HistoryFilter.values
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _LiquidFilterChip(
                      label: _filterLabel(filter),
                      selected: _filter == filter,
                      onTap: () => setState(() => _filter = filter),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 18),
        if (entries.isEmpty)
          const _EmptyState(
            title: 'No entries for this filter',
            body:
                'Savings, skipped days, and potential avoided money will be listed here.',
          )
        else
          ...entries.map((entry) => _EntryRow(entry: entry)),
      ],
    );
  }

  bool _matchesFilter(SavingEntry entry) {
    return switch (_filter) {
      _HistoryFilter.all => true,
      _HistoryFilter.confirmed => entry.isConfirmed,
      _HistoryFilter.potential => entry.isPotential,
      _HistoryFilter.skipped => entry.isSkipped,
      _HistoryFilter.manual => entry.source == MoneyEntrySource.manual,
      _HistoryFilter.upiMock =>
        entry.source == MoneyEntrySource.upiMock ||
            entry.method == MoneySaveMethod.upiMock,
      _HistoryFilter.badHabit =>
        entry.source == MoneyEntrySource.badHabitAvoided ||
            entry.source == MoneyEntrySource.badHabitConverted,
    };
  }

  String _filterLabel(_HistoryFilter filter) {
    return switch (filter) {
      _HistoryFilter.all => 'All',
      _HistoryFilter.confirmed => 'Confirmed',
      _HistoryFilter.potential => 'Potential',
      _HistoryFilter.skipped => 'Skipped',
      _HistoryFilter.manual => 'Manual',
      _HistoryFilter.upiMock => 'UPI mock',
      _HistoryFilter.badHabit => 'Bad habit',
    };
  }
}

class BadHabitTabContent extends ConsumerWidget {
  const BadHabitTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockTrackerProvider);
    final potentialEntries =
        state.savingsEntries
            .where(
              (entry) =>
                  entry.isPotential &&
                  entry.source == MoneyEntrySource.badHabitAvoided,
            )
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerGlassCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TrackerSectionHeader(title: 'Bad Habit Savings'),
              const SizedBox(height: 8),
              const Text(
                'Potential money appears when a bad-habit spend is avoided. Convert it when you actually move the money.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.sub,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              _TotalRow(
                label: 'Potential avoided',
                value: formatMoney(state.moneyGoal.totalPotentialSaved),
                color: OptivusColors.purpleAccent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (potentialEntries.isEmpty)
          const _EmptyState(
            title: 'No potential bad-habit savings',
            body:
                'Avoided cravings and impulse spends will appear here as potential money.',
          )
        else
          ...potentialEntries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TrackerGlassCard(
                radius: 24,
                padding: const EdgeInsets.all(18),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.description,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatMoney(entry.amount)} potential • ${entry.dateKey}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.purpleAccent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LiquidPrimaryButton(
                    label: 'Convert to real saving',
                    icon: Icons.swap_horiz_rounded,
                    backgroundColor: OptivusColors.trackerAccent,
                    foregroundColor: OptivusColors.ink,
                    onPressed: () => showSaveViaUpiFlow(
                      context,
                      ref,
                      convertEntryId: entry.id,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LiquidOutlineButton(
                    label: 'Keep as potential',
                    borderColor: OptivusColors.purpleAccent,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GoalsTabContent extends ConsumerStatefulWidget {
  const GoalsTabContent({super.key});

  @override
  ConsumerState<GoalsTabContent> createState() => _GoalsTabContentState();
}

class _GoalsTabContentState extends ConsumerState<GoalsTabContent> {
  String _selectedGoal = 'Emergency fund';
  bool _levelSuggestionDismissed = false;

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(mockTrackerProvider).moneyGoal;
    final progress = levelProgress(goal);
    final canLevelUp =
        goal.successfulDaysAtCurrentLevel >= goal.levelUpAfterDays &&
        !_levelSuggestionDismissed;
    final goalChips = [
      'Emergency fund',
      'Course fee',
      'Gym fee',
      'Phone',
      'Business fund',
      'Travel',
      'Custom',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerGlassCard(
          radius: 28,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Financially Free',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Main identity goal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: OptivusColors.sub,
                ),
              ),
              const SizedBox(height: 18),
              _LevelProgressPanel(
                currentLevel: goal.currentLevelAmount,
                nextLevel: goal.nextLevelAmount,
                progress: progress,
                completedDays: goal.successfulDaysAtCurrentLevel,
                targetDays: goal.levelUpAfterDays,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TrackerGlassCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                canLevelUp
                    ? 'Level-up unlocked'
                    : '${(goal.levelUpAfterDays - goal.successfulDaysAtCurrentLevel).clamp(0, goal.levelUpAfterDays)} successful days to unlock level-up',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                canLevelUp
                    ? 'You can raise the daily proof when the current amount feels easy.'
                    : 'Stay consistent at the current level before increasing pressure.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.sub,
                  height: 1.35,
                ),
              ),
              if (canLevelUp) ...[
                const SizedBox(height: 16),
                LiquidPrimaryButton(
                  label: 'Level up to ${formatMoney(goal.nextLevelAmount)}/day',
                  icon: Icons.arrow_upward_rounded,
                  backgroundColor: OptivusColors.trackerAccent,
                  foregroundColor: OptivusColors.ink,
                  onPressed: () {
                    ref.read(mockTrackerProvider.notifier).levelUpMoneyTarget();
                    setState(() => _levelSuggestionDismissed = false);
                  },
                ),
                const SizedBox(height: 10),
                LiquidOutlineButton(
                  label: 'Stay at ${formatMoney(goal.currentLevelAmount)}/day',
                  borderColor: OptivusColors.trackerAccent,
                  onPressed: () =>
                      setState(() => _levelSuggestionDismissed = true),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const TrackerSectionHeader(title: 'Goal buckets'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: goalChips
              .map(
                (chip) => _LiquidFilterChip(
                  label: chip,
                  selected: _selectedGoal == chip,
                  onTap: () => setState(() => _selectedGoal = chip),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class InsightsTabContent extends ConsumerWidget {
  const InsightsTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockTrackerProvider);
    final goal = state.moneyGoal;
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekKeys = List.generate(
      7,
      (index) => moneyDateKey(weekStart.add(Duration(days: index))),
    ).toSet();
    final weekEntries = state.savingsEntries
        .where((entry) => weekKeys.contains(entry.dateKey))
        .toList(growable: false);
    final savedThisWeek = weekEntries
        .where((entry) => entry.isConfirmed)
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final skippedThisWeek = weekEntries
        .where((entry) => entry.isSkipped)
        .map((entry) => entry.dateKey)
        .toSet()
        .length;
    final convertedTotal = state.savingsEntries
        .where(
          (entry) =>
              entry.isConfirmed &&
              entry.source == MoneyEntrySource.badHabitConverted,
        )
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final confirmedDays = state.savingsEntries
        .where((entry) => entry.isConfirmed)
        .map((entry) => entry.dateKey)
        .toSet()
        .length;
    final averageDaily = confirmedDays == 0
        ? 0.0
        : goal.totalConfirmedSaved / confirmedDays;

    final cards = [
      _InsightMetric(
        'Saved this week',
        formatMoney(savedThisWeek),
        OptivusColors.mintAccent,
      ),
      _InsightMetric(
        'Skipped this week',
        '$skippedThisWeek days',
        OptivusColors.roseAccent,
      ),
      _InsightMetric(
        'Best streak',
        '${goal.bestStreakDays} days',
        OptivusColors.trackerAccent,
      ),
      _InsightMetric(
        'Confirmed total',
        formatMoney(goal.totalConfirmedSaved),
        OptivusColors.mintAccent,
      ),
      _InsightMetric(
        'Potential total',
        formatMoney(goal.totalPotentialSaved),
        OptivusColors.purpleAccent,
      ),
      _InsightMetric(
        'Bad-habit converted',
        formatMoney(convertedTotal),
        OptivusColors.trackerAccent,
      ),
      _InsightMetric(
        'Average daily',
        formatMoney(averageDaily),
        OptivusColors.trackerAccent,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards
                  .map(
                    (metric) => SizedBox(
                      width: itemWidth,
                      child: _InsightCard(metric: metric),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 18),
        TrackerGlassCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: OptivusColors.trackerAccent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your money discipline is becoming automatic. Keep ${formatMoney(goal.currentLevelAmount)}/day until it feels easy.',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.ink,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsTabContent extends ConsumerWidget {
  const SettingsTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(mockTrackerProvider).moneyGoal;
    return TrackerGlassCard(
      radius: 24,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _SettingsRow(
            title: 'Daily target amount',
            value: formatMoney(goal.currentLevelAmount),
            onTap: () => showMoneySettingSheet(
              context,
              ref,
              MoneySettingKind.dailyTarget,
            ),
          ),
          _SettingsRow(
            title: 'Tiny save amount',
            value: formatMoney(goal.tinySaveAmount),
            onTap: () => showMoneySettingSheet(
              context,
              ref,
              MoneySettingKind.tinySaveAmount,
            ),
          ),
          _SettingsRow(
            title: 'Saving destination label',
            value: goal.destinationLabel,
            onTap: () => showMoneySettingSheet(
              context,
              ref,
              MoneySettingKind.destinationLabel,
            ),
          ),
          _SettingsRow(
            title: 'Default method',
            value: moneySaveMethodLabel(goal.defaultMethod),
            onTap: () => showMoneySettingSheet(
              context,
              ref,
              MoneySettingKind.defaultMethod,
            ),
          ),
          _SettingsRow(
            title: 'Reminder time label',
            value: goal.reminderTimeLabel,
            onTap: () => showMoneySettingSheet(
              context,
              ref,
              MoneySettingKind.reminderTimeLabel,
            ),
          ),
          _SettingsRow(
            title: 'Level-up rule',
            value: 'After ${goal.levelUpAfterDays} days',
            onTap: () => showMoneySettingSheet(
              context,
              ref,
              MoneySettingKind.levelUpRule,
            ),
          ),
          _SettingsRow(
            title: 'Manual confirmation allowed',
            value: goal.manualConfirmationAllowed ? 'Yes' : 'No',
            onTap: () => showMoneySettingSheet(
              context,
              ref,
              MoneySettingKind.manualConfirmationAllowed,
            ),
          ),
          _SettingsRow(
            title: 'Export savings data',
            value: 'Mock',
            onTap: () => showMoneySettingSheet(
              context,
              ref,
              MoneySettingKind.exportSavingsData,
            ),
          ),
          _SettingsRow(
            title: 'Reset money system',
            value: 'Clear local data',
            danger: true,
            onTap: () => showResetMoneyConfirmationSheet(context, ref),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: OptivusColors.sub,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelProgressPanel extends StatelessWidget {
  final double currentLevel;
  final double nextLevel;
  final double progress;
  final int completedDays;
  final int targetDays;

  const _LevelProgressPanel({
    required this.currentLevel,
    required this.nextLevel,
    required this.progress,
    required this.completedDays,
    required this.targetDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OptivusColors.trackerAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: OptivusColors.trackerAccent.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current level: ${formatMoney(currentLevel)}/day',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.ink,
                  ),
                ),
              ),
              Text(
                'Next ${formatMoney(nextLevel)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.trackerAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 9,
              color: OptivusColors.trackerCardTint,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(color: OptivusColors.trackerAccent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completedDays / $targetDays successful days at this level',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: OptivusColors.sub,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}


class _SourceRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SourceRow({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: OptivusColors.ink,
              ),
            ),
          ),
          Text(
            formatMoney(amount),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: OptivusColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TotalRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: OptivusColors.sub,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  final SavingEntry entry;

  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = entry.isConfirmed
        ? OptivusColors.mintAccent
        : entry.isPotential
        ? OptivusColors.purpleAccent
        : OptivusColors.roseAccent;
    final amount = entry.isSkipped ? '—' : formatMoney(entry.amount);
    final detail = entry.reason?.isNotEmpty == true
        ? entry.reason!
        : entry.note?.isNotEmpty == true
        ? entry.note!
        : entry.description;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              entry.isSkipped
                  ? Icons.close_rounded
                  : entry.isPotential
                  ? Icons.trending_up_rounded
                  : Icons.check_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amount,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${entry.dateKey} • ${moneyEntryStatusLabel(entry.status)} • ${moneyEntrySourceLabel(entry.source)} • ${moneySaveMethodLabel(entry.method)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.sub,
                    height: 1.25,
                  ),
                ),
                if (detail != entry.description) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.sub,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String body;

  const _EmptyState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.savings_outlined,
            color: OptivusColors.trackerAccent,
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: OptivusColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OptivusColors.sub,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  final String title;
  final String body;

  const _InlineEmptyState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OptivusColors.trackerCardTint.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: OptivusColors.trackerAccent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: OptivusColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OptivusColors.sub,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LiquidFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? OptivusColors.trackerAccent.withValues(alpha: 0.16)
              : OptivusColors.trackerCardTint.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? OptivusColors.trackerAccent
                : OptivusColors.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: selected ? OptivusColors.trackerAccent : OptivusColors.ink,
          ),
        ),
      ),
    );
  }
}

class _InsightMetric {
  final String title;
  final String value;
  final Color color;

  const _InsightMetric(this.title, this.value, this.color);
}

class _InsightCard extends StatelessWidget {
  final _InsightMetric metric;

  const _InsightCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: OptivusColors.sub,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: metric.color,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool danger;

  const _SettingsRow({
    required this.title,
    required this.value,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? OptivusColors.roseAccent : OptivusColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: OptivusColors.borderSoft.withValues(alpha: 0.8),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.sub,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: danger ? OptivusColors.roseAccent : OptivusColors.sub,
            ),
          ],
        ),
      ),
    );
  }
}
