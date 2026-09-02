import 'package:flutter/widgets.dart';

/// Optivus Spacing Tokens
/// Consistent spacing values used throughout the app.
class OptivusSpacing {
  OptivusSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // ── Screen Layout & Inset Tokens (AH-F022) ─────────────────────────────────
  /// Canonical horizontal page padding across standard screens
  static const double screenHorizontal = 24.0;

  /// Compact horizontal page padding for constrained viewports
  static const double screenHorizontalCompact = 16.0;

  /// Standard vertical separation between distinct sections
  static const double sectionVertical = 24.0;

  /// Compact vertical separation for dense sections
  static const double sectionVerticalCompact = 16.0;

  /// Standard gap between sibling controls in a section
  static const double elementGap = 12.0;

  /// Canonical padding for modal sheets and dialogs
  static const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(24, 16, 24, 24);

  /// Canonical top corner radius for bottom sheets
  static const double sheetTopRadius = 28.0;

  /// Height of the floating liquid tab bar area
  static const double tabBarHeight = 80;

  /// Bottom padding for scroll content so it doesn't hide behind the tab bar
  static const double contentBottomPadding = 120;
}
