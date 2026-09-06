import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Step 7-owned behavior presented by the shared onboarding footer.
///
/// The screen retains ownership of validation and generation; this small
/// bridge only lets the shell place that action safely above system UI.
class OnboardingStep7PrimaryAction {
  final String label;
  final bool enabled;
  final bool loading;
  final FutureOr<void> Function() onPressed;

  const OnboardingStep7PrimaryAction({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });
}

final onboardingStep7PrimaryActionProvider =
    StateProvider<OnboardingStep7PrimaryAction?>((ref) => null);
