import 'package:flutter/material.dart';

import 'optivus_colors.dart';

/// Optivus Gradient Presets
/// Per-tab and per-screen gradient builders using the blueprint color tokens.
class OptivusGradients {
  OptivusGradients._();

  /// Standard 3-stop formula: topColor → white → white
  /// This creates the signature Optivus pastel-to-white vertical gradient.
  static LinearGradient tabGradient(Color topColor) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        topColor,
        Color.lerp(topColor, Colors.white, 0.8) ?? Colors.white,
        const Color(0xFFF2F4F7), // Soft cool off-white for 3D contrast
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  // ── Per-tab gradients ─────────────────────────────────────────────────────

  static LinearGradient get home => tabGradient(OptivusColors.homeTop);
  static LinearGradient get routine => tabGradient(OptivusColors.routineTop);
  static LinearGradient get tracker => tabGradient(OptivusColors.trackerTop);
  static LinearGradient get coach => tabGradient(OptivusColors.coachTop);
  static LinearGradient get goals => tabGradient(OptivusColors.goalsTop);
  static LinearGradient get profile => tabGradient(OptivusColors.profileTop);

  // ── Special gradients ─────────────────────────────────────────────────────

  static LinearGradient get onboarding =>
      tabGradient(OptivusColors.onboardingTop);

  static LinearGradient get auth => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [OptivusColors.onboardingTop, Colors.white, Colors.white],
    stops: [0.0, 0.6, 1.0],
  );

  /// Get gradient by tab index (matches AppShell tab order)
  static LinearGradient forTab(int index) {
    switch (index) {
      case 0:
        return home;
      case 1:
        return routine;
      case 2:
        return tracker;
      case 3:
        return coach;
      case 4:
        return goals;
      case 5:
        return profile;
      default:
        return home;
    }
  }

  /// Get accent color by tab index
  static Color accentForTab(int index) {
    switch (index) {
      case 0:
        return OptivusColors.homeAccent;
      case 1:
        return OptivusColors.routineAccent;
      case 2:
        return OptivusColors.trackerAccent;
      case 3:
        return OptivusColors.coachAccent;
      case 4:
        return OptivusColors.goalsAccent;
      case 5:
        return OptivusColors.profileAccent;
      default:
        return OptivusColors.homeAccent;
    }
  }

  /// Get top color by tab index
  static Color topColorForTab(int index) {
    switch (index) {
      case 0:
        return OptivusColors.homeTop;
      case 1:
        return OptivusColors.routineTop;
      case 2:
        return OptivusColors.trackerTop;
      case 3:
        return OptivusColors.coachTop;
      case 4:
        return OptivusColors.goalsTop;
      case 5:
        return OptivusColors.profileTop;
      default:
        return OptivusColors.homeTop;
    }
  }
}
