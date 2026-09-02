import 'package:flutter/material.dart';

import 'optivus_colors.dart';

/// Optivus Typography Presets
/// Text styles using system font. These complement the theme-level TextTheme.
class OptivusTypography {
  OptivusTypography._();

  // Display styles — hero headings
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: OptivusColors.textPrimary,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: OptivusColors.textPrimary,
    letterSpacing: -0.4,
    height: 1.25,
  );

  // Title styles — card titles, section headers
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: OptivusColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: OptivusColors.textPrimary,
    height: 1.35,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: OptivusColors.textPrimary,
    height: 1.4,
  );

  // Body styles — paragraphs, descriptions
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: OptivusColors.textBody,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: OptivusColors.textBody,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: OptivusColors.textSecondary,
    height: 1.4,
  );

  // Label styles — buttons, chips, tabs
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: OptivusColors.textPrimary,
    letterSpacing: 0.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: OptivusColors.textSecondary,
    letterSpacing: 0.5,
  );

  // Caption — metadata, timestamps
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: OptivusColors.textMuted,
    letterSpacing: 0.3,
  );

  // Section header — uppercase category labels
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    color: OptivusColors.textSecondary,
    letterSpacing: 1.2,
  );

  // ── Shared Semantic Hierarchy Tokens (AH-F022) ───────────────────────────
  /// Canonical screen title style for onboarding / hero presentations
  static const TextStyle screenTitle = displayLarge;

  /// Canonical screen subtitle style for onboarding / hero presentations
  static const TextStyle screenSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: OptivusColors.textSecondary,
    height: 1.4,
  );

  /// Canonical section heading style
  static const TextStyle sectionTitle = titleLarge;

  /// Canonical card title style
  static const TextStyle cardTitle = titleMedium;

  /// Canonical primary body text
  static const TextStyle body = bodyLarge;

  /// Canonical helper / secondary explanatory text
  static const TextStyle helper = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: OptivusColors.textSecondary,
    height: 1.4,
  );
}
