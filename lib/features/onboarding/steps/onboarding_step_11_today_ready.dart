import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/state/mock_app_state.dart';

class OnboardingStep11 extends ConsumerWidget {
  final ValueChanged<int>? onJumpToStep;

  const OnboardingStep11({super.key, this.onJumpToStep});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(mockUserProfileProvider);
    final routines = ref.watch(mockRoutineProvider);
    final onboarding = ref.watch(mockOnboardingProvider);
    final missing = <String>[
      if (profile.lifeRole.isEmpty) 'Role and lifestyle',
      if (routines.any((item) => item.hasConflict)) 'Timeline conflicts',
      if (!onboarding.stepCompleted.sublist(0, 11).every((done) => done))
        'Unsaved setup steps',
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
                    missing.join('\n'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: OptivusColors.textSecondary,
                      height: 1.45,
                    ),
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
                  'Your identity',
                  profile.lifeRole.isEmpty ? 'Not selected' : profile.lifeRole,
                ),
                _row('Today timeline', '${routines.length} local anchors'),
                _row('Habit focus', 'Good habits, bad habit intercepts'),
                _row('Coach', profile.coachName),
                _row('Coach style', profile.coachStyle),
                _row('Slip-up handling', profile.slipUpStyle),
                _row('Notifications', 'Mock preferences only'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OnboardingGlassCard(
            tint: OptivusColors.aquaAccent.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today timeline preview',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ...routines
                    .take(6)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${_time(item.startMinute)} - ${item.title}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
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
}
