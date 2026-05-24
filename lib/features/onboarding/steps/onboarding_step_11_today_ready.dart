import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingStep11 extends ConsumerWidget {
  final ValueChanged<int>? onJumpToStep;

  const OnboardingStep11({super.key, this.onJumpToStep});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(mockOnboardingProvider);
    final draft = onboarding.draft;
    final bundle = OnboardingCompletionService.buildBundle(draft);
    final missing = <_MissingSetup>[
      if (draft.lifeRole.validate() != null)
        const _MissingSetup('Role and lifestyle', 2),
      if (draft.bodyBasics.validate() != null)
        const _MissingSetup('Body basics', 3),
      if (draft.baseTimeline.validateForRole(draft.lifeRole.lifeRole) != null)
        const _MissingSetup('Base timeline', 4),
      if (!draft.badHabitsNotNow && draft.badHabits.isEmpty)
        const _MissingSetup('Bad habits', 5),
      if (!draft.goodHabitsNotNow && draft.goodHabits.isEmpty)
        const _MissingSetup('Good habits', 6),
      if (draft.identityGoals.isEmpty) const _MissingSetup('Identity goals', 7),
      if (draft.coachSetup.validate() != null)
        const _MissingSetup('Coach setup', 8),
      if (draft.slipUpHandling == null)
        const _MissingSetup('Slip-up handling', 9),
      if (!onboarding.stepCompleted.sublist(0, 11).every((done) => done))
        const _MissingSetup('Unsaved setup steps', 0),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(
            title: 'Today Is Ready',
            subtitle:
                'Review the local onboarding setup before entering Optivus.',
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (missing.isNotEmpty)
                  OnboardingGlassCard(
                    tint: OptivusColors.warning.withValues(alpha: 0.10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: OptivusColors.warning,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Missing required setup',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          missing.map((item) => item.label).join('\n'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: OptivusColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: missing
                              .map(
                                (item) => OnboardingChip(
                                  label: 'Edit ${item.label}',
                                  selected: false,
                                  accent: OptivusColors.warning,
                                  onTap: () => onJumpToStep?.call(item.step),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  )
                else
                  OnboardingGlassCard(
                    tint: OptivusColors.success.withValues(alpha: 0.10),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: OptivusColors.success,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Required onboarding setup is complete.',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: OptivusColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                OnboardingGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Final preview',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          OnboardingActionPill(
                            label: 'Edit Setup',
                            icon: Icons.edit_rounded,
                            accent: OptivusColors.brandAccent,
                            compact: true,
                            onTap: () => onJumpToStep?.call(2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _row(
                        'Your identity goals',
                        draft.identityGoals.isEmpty
                            ? 'Not selected'
                            : draft.identityGoals
                                  .map((goal) => goal.displayName)
                                  .join(', '),
                      ),
                      _row(
                        'Today timeline',
                        '${bundle.routineItemsForApp.length} generated blocks',
                      ),
                      _row('Habit focus', _habitFocus(draft)),
                      _row(
                        'Coach',
                        draft.coachSetup.coachName ?? 'Not selected',
                      ),
                      _row(
                        'Coach style',
                        _displayKey(draft.coachSetup.coachStyle),
                      ),
                      _row(
                        'Slip-up handling',
                        _displayKey(draft.slipUpHandling),
                      ),
                      _row(
                        'Notifications',
                        draft.notifications.selectedLabels().isEmpty
                            ? 'None selected'
                            : draft.notifications.selectedLabels().join(', '),
                      ),
                      if (bundle.duplicateSystemKeysMerged.isNotEmpty)
                        _row(
                          'Merged duplicates',
                          bundle.duplicateSystemKeysMerged
                              .map(identitySystemTitle)
                              .join(', '),
                        ),
                    ],
                  ),
                ),
                if (bundle.warnings.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  OnboardingGlassCard(
                    tint: OptivusColors.warning.withValues(alpha: 0.10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Warnings',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bundle.warnings.join('\n'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: OptivusColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                OnboardingGlassCard(
                  tint: OptivusColors.aquaAccent.withValues(alpha: 0.08),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today timeline preview',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...bundle.routineItemsForApp
                          .take(12)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${_time(item.startMinute)} - ${_time(item.endMinute)}  ${item.title}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: OptivusColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      if (bundle.routineItemsForApp.length > 12)
                        Text(
                          '+${bundle.routineItemsForApp.length - 12} more generated blocks',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                    ], // end OnboardingGlassCard Column children
                  ), // end OnboardingGlassCard Column
                ), // end OnboardingGlassCard
              ], // end OnboardingScrollView inner Column children
            ), // end OnboardingScrollView inner Column
          ), // end OnboardingScrollView
        ), // end Expanded
      ], // end outer Column children
    );
  }

  static Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _time(int minute) {
    final hour = minute ~/ 60;
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${(minute % 60).toString().padLeft(2, '0')} ${hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _habitFocus(OnboardingDraft draft) {
    final parts = [
      if (draft.goodHabits.isNotEmpty)
        draft.goodHabits.map((habit) => habit.displayName).join(', '),
      if (draft.badHabits.isNotEmpty)
        '${draft.badHabits.length} bad habit check-in${draft.badHabits.length == 1 ? '' : 's'}',
    ];
    return parts.isEmpty ? 'Not now' : parts.join(' + ');
  }

  static String _displayKey(String? key) {
    if (key == null || key.isEmpty) return 'Not selected';
    return key
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}

class _MissingSetup {
  final String label;
  final int step;

  const _MissingSetup(this.label, this.step);
}
