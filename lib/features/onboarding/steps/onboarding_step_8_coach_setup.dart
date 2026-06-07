import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/widgets/animated_bot_avatar.dart';

class OnboardingStep11 extends ConsumerStatefulWidget {
  const OnboardingStep11({super.key});

  @override
  ConsumerState<OnboardingStep11> createState() => _OnboardingStep11State();
}

class _OnboardingStep11State extends ConsumerState<OnboardingStep11> {
  final _customCtrl = TextEditingController();
  static const coaches = [
    'Coach',
    'Mentor',
    'Sensei',
    'Friend',
    'Mom / Maa',
    'Dad',
    'Custom',
  ];
  static const styles = [
    ('supportive', 'Supportive'),
    ('tough_love', 'Tough Love'),
    ('analytical', 'Analytical'),
    ('zen', 'Zen'),
    ('motivational', 'Motivational'),
    ('friendly', 'Friendly'),
  ];

  @override
  void initState() {
    super.initState();
    // We can't use ref.read here safely without Future.microtask if it's a provider that hasn't initialized,
    // but mockOnboardingProvider is already initialized since we are in Step 8.
    // However, in Riverpod it's safer to read it in didChangeDependencies or read it here if it's synchronous.
    // Since mockOnboardingProvider is a StateNotifierProvider, we can read it.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize the text controller once
    if (_customCtrl.text.isEmpty) {
      final draft = ref.read(mockOnboardingProvider).draft;
      if (draft.coachSetup.customCoachName != null) {
        _customCtrl.text = draft.coachSetup.customCoachName!;
      }
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final coach = draft.coachSetup;
    final selectedCoachName = coach.coachName;
    final isCustom = coach.customCoachName != null;
    final previewCoach = selectedCoachName?.isEmpty ?? true
        ? 'Coach'
        : selectedCoachName!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(
            title: 'Coach Setup',
            subtitle:
                'Choose how your coach should sound during routine nudges.',
          ),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnboardingGlassCard(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: coaches.map((coachNameOption) {
                      final selected = coachNameOption == 'Custom'
                          ? isCustom
                          : selectedCoachName == coachNameOption && !isCustom;
                      return OnboardingChip(
                        label: coachNameOption,
                        selected: selected,
                        onTap: () {
                          final next = coachNameOption == 'Custom'
                              ? (_customCtrl.text.trim().isEmpty
                                    ? 'My Coach'
                                    : _customCtrl.text.trim())
                              : coachNameOption;
                          ref
                              .read(mockOnboardingProvider.notifier)
                              .updateDraft(
                                (current) => current.copyWith(
                                  coachSetup: current.coachSetup.copyWith(
                                    coachName: next,
                                    customCoachName: coachNameOption == 'Custom'
                                        ? next
                                        : null,
                                  ),
                                  clearFinalPreview: true,
                                ),
                              );
                          ref
                              .read(mockOnboardingProvider.notifier)
                              .setStepDirty(11, true);
                        },
                      );
                    }).toList(),
                  ),
                ),
                if (isCustom) ...[
                  const SizedBox(height: 12),
                  OnboardingGlassCard(
                    child: TextField(
                      controller: _customCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Custom coach name',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (value) {
                        final trimmed = value.trim();
                        final next = trimmed.isEmpty ? 'My Coach' : trimmed;
                        ref
                            .read(mockOnboardingProvider.notifier)
                            .updateDraft(
                              (current) => current.copyWith(
                                coachSetup: current.coachSetup.copyWith(
                                  coachName: next,
                                  customCoachName: next,
                                ),
                                clearFinalPreview: true,
                              ),
                            );
                        ref
                            .read(mockOnboardingProvider.notifier)
                            .setStepDirty(11, true);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OnboardingGlassCard(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: styles
                        .map(
                          (style) => OnboardingChip(
                            label: style.$2,
                            selected: coach.coachStyle == style.$1,
                            accent: OptivusColors.aquaAccent,
                            onTap: () {
                              ref
                                  .read(mockOnboardingProvider.notifier)
                                  .updateDraft(
                                    (current) => current.copyWith(
                                      coachSetup: current.coachSetup.copyWith(
                                        coachStyle: style.$1,
                                      ),
                                      clearFinalPreview: true,
                                    ),
                                  );
                              ref
                                  .read(mockOnboardingProvider.notifier)
                                  .setStepDirty(11, true);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),
                OnboardingGlassCard(
                  tint: OptivusColors.aquaAccent.withValues(alpha: 0.12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Liquid ambient blob behind the avatar
                      Positioned(
                        left: -10,
                        top: -10,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: OptivusColors.aquaAccent.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AnimatedBotAvatar(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$previewCoach preview',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: OptivusColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Good morning. We start small, protect the timeline, and recover fast if anything slips.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: OptivusColors.textBody,
                                    height: 1.5,
                                  ),
                                ),
                              ], // end Column children
                            ), // end Column
                          ), // end Expanded
                        ], // end Row children
                      ), // end Row
                    ], // end Stack children
                  ), // end Stack
                ), // end OnboardingGlassCard
              ], // end OnboardingScrollView inner Column children
            ), // end OnboardingScrollView inner Column
          ), // end OnboardingScrollView
        ), // end Expanded
      ], // end outer Column children
    );
  }
}
