import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/core/widgets/liquid_inputs.dart';
import 'package:optivus/features/goals/widgets/goals_tab_widgets.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/state/app_state.dart';

class AddGoalInlineScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const AddGoalInlineScreen({super.key, required this.onBack});

  @override
  ConsumerState<AddGoalInlineScreen> createState() =>
      _AddGoalInlineScreenState();
}

class _AddGoalInlineScreenState extends ConsumerState<AddGoalInlineScreen> {
  final _identity = TextEditingController();
  final _purpose = TextEditingController();
  final _proof = TextEditingController();
  final _tiny = TextEditingController(text: 'Do 2 minutes');
  final _strong = TextEditingController(text: 'Do 2x duration');
  String _difficulty = 'normal';
  String? _error;

  @override
  void dispose() {
    _identity.dispose();
    _purpose.dispose();
    _proof.dispose();
    _tiny.dispose();
    _strong.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeGoals = ref
        .watch(mockGoalProvider)
        .where((goal) => !goal.isArchived)
        .toList();
    final limitReached = activeGoals.length >= 3;

    return LiquidDetailScaffold(
      eyebrow: 'Goals',
      title: 'Add Goal',
      subtitle: 'Create one active identity goal with daily proof versions.',
      accentColor: OptivusColors.goalsAccent,
      onBack: widget.onBack,
      children: [
        if (limitReached)
          LiquidDetailSection(
            tint: OptivusColors.danger.withValues(alpha: 0.08),
            children: const [
              Text(
                'Overload protection active',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.danger,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You already have 3 active identity goals. Archive or complete one before adding another.',
                style: TextStyle(
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ],
          )
        else ...[
          LiquidDetailSection(
            title: 'Identity',
            children: [
              LiquidInput(
                controller: _identity,
                labelText: 'Identity title',
                hintText: 'Financially Free',
                accentColor: OptivusColors.goalsAccent,
              ),
              const SizedBox(height: 12),
              LiquidInput(
                controller: _purpose,
                labelText: 'Purpose statement',
                maxLines: 3,
                accentColor: OptivusColors.goalsAccent,
              ),
            ],
          ),
          LiquidDetailSection(
            title: 'Daily proof',
            children: [
              LiquidInput(
                controller: _proof,
                labelText: 'Normal proof',
                accentColor: OptivusColors.goalsAccent,
              ),
              const SizedBox(height: 12),
              LiquidInput(
                controller: _tiny,
                labelText: 'Tiny version',
                accentColor: OptivusColors.goalsAccent,
              ),
              const SizedBox(height: 12),
              LiquidInput(
                controller: _strong,
                labelText: 'Strong version',
                accentColor: OptivusColors.goalsAccent,
              ),
              const SizedBox(height: 12),
              _GoalSegment(
                options: const ['tiny', 'normal', 'strong'],
                selected: _difficulty,
                onSelected: (v) => setState(() => _difficulty = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: OptivusColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          _GoalPrimaryButton(label: 'Save goal', onTap: _saveGoal),
        ],
      ],
    );
  }

  void _saveGoal() {
    final identity = _identity.text.trim();
    final purpose = _purpose.text.trim();
    final proof = _proof.text.trim();
    if (identity.isEmpty || purpose.isEmpty || proof.isEmpty) {
      setState(() => _error = 'Identity, purpose, and proof are required.');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    ref
        .read(mockGoalProvider.notifier)
        .addGoal(
          GoalModel(
            id: 'goal-$now',
            identityTitle: identity,
            purposeStatement: purpose,
            dailyProof: GoalProof(
              id: 'proof-$now',
              title: proof,
              tinyVersion: _tiny.text.trim().isEmpty
                  ? 'Tiny version: do 2 minutes'
                  : _tiny.text.trim(),
              normalVersion: proof,
              strongVersion: _strong.text.trim().isEmpty
                  ? 'Strong: do 2x duration'
                  : _strong.text.trim(),
              selectedDifficulty: _difficulty,
            ),
          ),
        );
    widget.onBack();
  }
}

class GoalDetailInlineScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final String goalId;

  const GoalDetailInlineScreen({
    super.key,
    required this.onBack,
    required this.goalId,
  });

  @override
  ConsumerState<GoalDetailInlineScreen> createState() =>
      _GoalDetailInlineScreenState();
}

class _GoalDetailInlineScreenState
    extends ConsumerState<GoalDetailInlineScreen> {
  final _purpose = TextEditingController();
  final _proof = TextEditingController();
  String _difficulty = 'normal';
  bool _initialized = false;

  @override
  void dispose() {
    _purpose.dispose();
    _proof.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = ref
        .watch(mockGoalProvider)
        .firstWhere((goal) => goal.id == widget.goalId);
    final fakeDataAllowed = ref.watch(fakeDataAllowedProvider);
    if (!_initialized) {
      _purpose.text = goal.purposeStatement;
      _proof.text = goal.dailyProof.title;
      _difficulty = goal.dailyProof.selectedDifficulty;
      _initialized = true;
    }

    return LiquidDetailScaffold(
      eyebrow: 'Identity goal',
      title: goal.identityTitle,
      subtitle:
          '${goal.streakDays}-day streak · ${(goal.progressPercent * 100).round()}% progress',
      accentColor: OptivusColors.goalsAccent,
      onBack: widget.onBack,
      children: [
        LiquidDetailSection(
          title: 'Purpose statement',
          children: [
            LiquidInput(
              controller: _purpose,
              maxLines: 3,
              accentColor: OptivusColors.goalsAccent,
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Daily proof',
          children: [
            LiquidInput(
              controller: _proof,
              labelText: 'Proof action',
              accentColor: OptivusColors.goalsAccent,
            ),
            const SizedBox(height: 12),
            _GoalSegment(
              options: const ['tiny', 'normal', 'strong'],
              selected: _difficulty,
              onSelected: (v) => setState(() => _difficulty = v),
            ),
            const SizedBox(height: 14),
            Text(
              switch (_difficulty) {
                'tiny' => goal.dailyProof.tinyVersion,
                'strong' => goal.dailyProof.strongVersion,
                _ => goal.dailyProof.normalVersion,
              },
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
        if (fakeDataAllowed)
          LiquidDetailSection(
            title: 'Milestones',
            children: const [
              _MilestoneLine(label: 'Week 1: start identity', done: true),
              _MilestoneLine(label: 'Week 2: consistency proof', done: true),
              _MilestoneLine(label: 'Month 1: visible progress', done: false),
            ],
          ),
        LiquidDetailSection(
          title: 'Weekly progress',
          children: [
            GoalsGlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Progress',
                      value: '${(goal.progressPercent * 100).round()}%',
                      color: OptivusColors.goalsAccent,
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Streak',
                      value: '${goal.streakDays}d',
                      color: OptivusColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _GoalPrimaryButton(
                label: 'Save changes',
                onTap: () {
                  ref
                      .read(mockGoalProvider.notifier)
                      .updateGoal(
                        goal.copyWith(
                          purposeStatement: _purpose.text.trim(),
                          dailyProof: goal.dailyProof.copyWith(
                            title: _proof.text.trim().isEmpty
                                ? goal.dailyProof.title
                                : _proof.text.trim(),
                            selectedDifficulty: _difficulty,
                          ),
                        ),
                      );
                  widget.onBack();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GoalPrimaryButton(
                label: 'Archive goal',
                color: OptivusColors.danger,
                onTap: () {
                  ref.read(mockGoalProvider.notifier).archiveGoal(goal.id);
                  widget.onBack();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WeeklyReviewInlineScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const WeeklyReviewInlineScreen({super.key, required this.onBack});

  @override
  ConsumerState<WeeklyReviewInlineScreen> createState() =>
      _WeeklyReviewInlineScreenState();
}

class _WeeklyReviewInlineScreenState
    extends ConsumerState<WeeklyReviewInlineScreen> {
  final _worked = TextEditingController();
  final _failed = TextEditingController();
  final _adjustment = TextEditingController();
  bool _saved = false;

  @override
  void dispose() {
    _worked.dispose();
    _failed.dispose();
    _adjustment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(mockGoalProvider);
    final proofs = goals.where((g) => g.dailyProof.isCompleted).length;

    return LiquidDetailScaffold(
      eyebrow: 'Goals',
      title: 'Weekly Review',
      subtitle: 'Review proofs, failures, and next week adjustments.',
      accentColor: OptivusColors.goalsAccent,
      onBack: widget.onBack,
      children: [
        LiquidDetailSection(
          title: 'Weekly proof summary',
          children: [
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Proofs completed',
                    value: '$proofs/${goals.length}',
                    color: OptivusColors.goalsAccent,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Active identities',
                    value: '${goals.where((g) => !g.isArchived).length}',
                    color: OptivusColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Reflection',
          children: [
            LiquidInput(
              controller: _worked,
              labelText: 'What worked?',
              maxLines: 3,
              accentColor: OptivusColors.goalsAccent,
            ),
            const SizedBox(height: 12),
            LiquidInput(
              controller: _failed,
              labelText: 'What failed?',
              maxLines: 3,
              accentColor: OptivusColors.goalsAccent,
            ),
            const SizedBox(height: 12),
            LiquidInput(
              controller: _adjustment,
              labelText: 'Next week adjustment',
              maxLines: 3,
              accentColor: OptivusColors.goalsAccent,
            ),
          ],
        ),
        if (_saved)
          LiquidDetailSection(
            tint: OptivusColors.success.withValues(alpha: 0.08),
            children: const [
              Text(
                'Weekly review is still open in this session.',
                style: TextStyle(
                  color: OptivusColors.success,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        _GoalPrimaryButton(
          label: 'Save review',
          onTap: () => setState(() => _saved = true),
        ),
      ],
    );
  }
}

class ArchivedGoalsScreen extends ConsumerWidget {
  final VoidCallback onBack;
  final ValueChanged<String> onViewGoal;

  const ArchivedGoalsScreen({
    super.key,
    required this.onBack,
    required this.onViewGoal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(mockGoalProvider);
    final archived = goals.where((g) => g.isArchived).toList();
    final completed = goals.where((g) => g.progressPercent >= 1).toList();

    return LiquidDetailScaffold(
      eyebrow: 'Goals',
      title: 'Archived Identities',
      subtitle: 'Archived and completed identity goals.',
      accentColor: OptivusColors.goalsAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Archived',
          children: archived.isEmpty
              ? const [
                  Text(
                    'No archived identities yet.',
                    style: TextStyle(color: OptivusColors.textSecondary),
                  ),
                ]
              : archived
                    .map(
                      (goal) => _ArchivedGoalTile(
                        goal: goal,
                        onView: () => onViewGoal(goal.id),
                        onRestore: () => ref
                            .read(mockGoalProvider.notifier)
                            .restoreGoal(goal.id),
                      ),
                    )
                    .toList(),
        ),
        LiquidDetailSection(
          title: 'Completed',
          children: completed.isEmpty
              ? const [
                  Text(
                    'No completed identities yet.',
                    style: TextStyle(color: OptivusColors.textSecondary),
                  ),
                ]
              : completed
                    .map(
                      (goal) => _ArchivedGoalTile(
                        goal: goal,
                        onView: () => onViewGoal(goal.id),
                      ),
                    )
                    .toList(),
        ),
      ],
    );
  }
}

class GoalsSettingsInlineScreen extends StatelessWidget {
  final VoidCallback onBack;

  const GoalsSettingsInlineScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return LiquidDetailScaffold(
      eyebrow: 'Goals',
      title: 'Goal Settings',
      subtitle:
          'Identity load, proof difficulty, weekly review cadence, and archive rules.',
      accentColor: OptivusColors.goalsAccent,
      onBack: onBack,
      children: const [
        LiquidDetailSection(
          title: 'Overload guard',
          children: [
            Text(
              'Maximum 3 active identity goals. Strong proof mode is monitored to prevent attention overload.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Weekly review',
          children: [
            Text(
              'Default review: Sunday 6 PM. Reviews compare proof completion, failures, and next week adjustments.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoalSegment extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _GoalSegment({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: options.map((option) {
        final active = option == selected;
        return GestureDetector(
          onTap: () => onSelected(option),
          child: LiquidPill(
            label: option,
            color: OptivusColors.goalsAccent,
            filled: active,
          ),
        );
      }).toList(),
    );
  }
}

class _GoalPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _GoalPrimaryButton({
    required this.label,
    required this.onTap,
    this.color = OptivusColors.goalsAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: OptivusColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MilestoneLine extends StatelessWidget {
  final String label;
  final bool done;

  const _MilestoneLine({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: done ? OptivusColors.success : OptivusColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedGoalTile extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback onView;
  final VoidCallback? onRestore;

  const _ArchivedGoalTile({
    required this.goal,
    required this.onView,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GoalsGlassCard(
        padding: const EdgeInsets.all(16),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              goal.identityTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              goal.purposeStatement,
              style: const TextStyle(
                color: OptivusColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _TextAction(label: 'View detail', onTap: onView),
                if (onRestore != null)
                  _TextAction(label: 'Restore', onTap: onRestore!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: OptivusColors.goalsAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: OptivusColors.goalsAccent,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
