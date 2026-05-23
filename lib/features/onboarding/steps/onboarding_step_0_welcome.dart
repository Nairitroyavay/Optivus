import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';

class OnboardingStep0 extends ConsumerWidget {
  final TextEditingController nameController;
  final FocusNode nameFocus;

  const OnboardingStep0({
    super.key,
    required this.nameController,
    required this.nameFocus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
      userScrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 18),
          Column(
            children: [
              Text(
                'OPTIVUS',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  letterSpacing: 6.0,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                  fontSize: 34,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Biological routine scheduler & focus sandbox',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 46),
          OnboardingGlassPanel(
            hasPins: true,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 260),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome to\nOptivus',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your AI Life Operating System',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 22),
                  Text(
                    'Seamlessly organize your tasks, goals, and health with an intelligence that adapts to you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4B5563),
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
