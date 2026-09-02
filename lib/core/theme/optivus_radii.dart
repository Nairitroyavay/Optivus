/// Canonical corner-radius scale for new and touched Optivus UI.
///
/// Existing screens are migrated to this scale only during scheduled feature
/// work so Phase 0 does not introduce broad visual changes.
class OptivusRadii {
  OptivusRadii._();

  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 30;
  static const double pill = 999;

  // ── Semantic Surface Radius Hierarchy (AH-F022) ───────────────────────────
  /// Large hero cards and top-level glass panels
  static const double surfaceLarge = 28.0;

  /// Standard card and container corner radius
  static const double cardStandard = 20.0;

  /// Compact chips, inner tags, and small controls
  static const double controlCompact = 14.0;

  /// Modal bottom sheet top corners
  static const double modalSheet = 28.0;
}
