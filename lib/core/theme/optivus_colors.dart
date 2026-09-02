import 'package:flutter/material.dart';

class OptivusColors {
  // Global Text & Surface Tokens
  static const Color backgroundBottom = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF11131A);
  static const Color textBody = Color(0xFF2B2E36);
  static const Color textSecondary = Color(0xFF6F737C);
  static const Color textMuted = Color(0xFF8A8E96);
  static const Color disabled = Color(0xFFB8BBC1);
  static const Color borderSoft = Color(0xFFE8E8E8);

  // Canonical warm-neutral gray border tokens (AH-F022)
  /// Base warm-neutral gray for standard surface and control outlines.
  static const Color borderNeutral = Color(0xFFB8B4AC);
  /// Subtle border for standard glass cards and passive panels (alpha ~0.35)
  static const Color borderSubtle = Color(0x59B8B4AC);
  /// Standard border for interactive cards, text fields, and panels (alpha ~0.55)
  static const Color borderStandard = Color(0x8CB8B4AC);
  /// Strong border for elevated, active, or selected surfaces (alpha ~0.75)
  static const Color borderStrong = Color(0xBFB8B4AC);
  /// Disabled border (alpha ~0.20)
  static const Color borderDisabled = Color(0x33B8B4AC);
  /// Focus state border (outline remains gray while glow provides accent)
  static const Color borderFocus = Color(0xFFB8B4AC);

  // Status Indicators
  static const Color success = Color(0xFF38C172);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger = Color(0xFFEF5B5B);
  static const Color info = Color(0xFF36C6D4);
  static const Color pending = Color(0xFFA0A4AD);

  // Tab Colors
  // Home
  static const Color homeTop = Color(0xFFFFE0E0);
  static const Color homeAccent = Color(0xFFF36F78);
  static const Color homeCardTint = Color(0xFFFFF1F1);

  // Routine
  static const Color routineTop = Color(0xFFE1FFAD);
  static const Color routineAccent = Color(0xFF72C95F);
  static const Color routineCardTint = Color(0xFFF2FCEC);

  // Tracker
  static const Color trackerTop = Color(0xFFD6FFFE);
  static const Color trackerBottom = Color(0xFFF5FFFF);
  static const Color trackerAccent = Color(0xFF3ED8E6);
  static const Color trackerCardTint = Color(0xFFEEFFFF);

  // Coach
  static const Color coachTop = Color(0xFFF7E0FF);
  static const Color coachBottom = Color(0xFFFCF2FF);
  static const Color coachAccent = Color(0xFFA56CF0);
  static const Color coachCardTint = Color(0xFFFCF2FF);

  // Goals
  static const Color goalsTop = Color(0xFFFFEBF8);
  static const Color goalsBottom = Color(0xFFFFF2FB);
  static const Color goalsAccent = Color(0xFFEC5FAE);
  static const Color goalsCardTint = Color(0xFFFFF0FA);

  // Profile
  static const Color profileTop = Color(0xFFFFE5CF);
  static const Color profileBottom = Color(0xFFFFEEE6);
  static const Color profileAccent = Color(0xFFF36F78);
  static const Color profileCardTint = Color(0xFFFEFFE9);

  // Onboarding & Auth
  static const Color onboardingTop = Color(0xFFFFF4D8);
  static const Color onboardingBottom = Color(0xFFFFFFFF);
  static const Color onboardingDarkTop = Color(0xFF1A1C24);
  static const Color onboardingDarkBottom = Color(0xFF0F1015);
  static const Color darkGlassFill = Color(0x1FFFFFFF);
  static const Color darkGlassBorder = Color(0x33FFFFFF);
  static const Color textPrimaryDark = Color(0xFFF1F3F9);
  static const Color textBodyDark = Color(0xFFE2E8F0);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);
  static const Color brandAccent = Color(0xFFE0B51F);
  static const Color aquaAccent = Color(0xFFF36F78);

  // ── Old-codebase-matched tokens (liquid_ui.dart kXxx equivalents) ─────────
  // These are the EXACT colour values from the original Optivus Routine UI.
  // Every Routine widget must use these instead of raw hex.

  /// Primary text — matches old `OptivusColors.ink` (0xFF0F111A)
  static const Color ink = Color(0xFF0F111A);

  /// Secondary text — matches old `OptivusColors.sub` (0xFF6B7280)
  static const Color sub = Color(0xFF6B7280);

  // ── Routine background (old LiquidBg green gradient) ───────────────────
  static const Color routineBgTop = Color(0xFFA3FF91);
  static const Color routineBgBottom = Color(0xFFEFFEEC);

  // ── Routine specific tokens ──────────────────────────────────────────────
  static const Color routineSheetTop = Color(0xFFF0FFF0);
  static const Color routineSheetBottom = Color(0xFFDCFFCC);
  static const Color routineInkDark = Color(0xFF1C1C2E);
  static const Color routineIconDark = Color(0xFF0F172A);
  static const Color routineTextDark = Color(0xFF334155);
  static const Color routinePrismBlue = Color(0xFF60A5FA);
  static const Color routinePrismYellow = Color(0xFFFBBF24);
  static const Color routinePrismPink = Color(0xFFF472B6);

  // ── Category accent colours (old liquid_ui palette) ────────────────────
  static const Color mintAccent = Color(
    0xFF60D4A0,
  ); // OptivusColors.mintAccent — skin care
  static const Color blueAccent = Color(
    0xFF60B8FF,
  ); // OptivusColors.blueAccent — classes
  static const Color roseAccent = Color(
    0xFFFF9560,
  ); // OptivusColors.roseAccent — eating/time
  static const Color purpleAccent = Color(
    0xFF9B8FFF,
  ); // OptivusColors.purpleAccent — AI/fixed
  static const Color tealAccent = Color(0xFF14B8A6); // supplements

  // ── Block-type rail colours ────────────────────────────────────────────
  static const Color blockHard = Color(0xFF8B5CF6);
  static const Color blockSoft = Color(0xFF10B981);
  static const Color blockFlex = Color(0xFF8B5CF6);
  static const Color blockTracker = Color(0xFFF59E0B);
  static const Color blockCheckIn = Color(0xFFEC4899);
  static const Color blockMoney = Color(0xFF14B8A6);

  // ── Glass surface ─────────────────────────────────────────────────────
  static const Color glassFill = Color(0x33FFFFFF);
  static const Color glassBorder = Color(0x66FFFFFF);

  // ── Header action button colours ──────────────────────────────────────
  static const Color headerAI = Color(0xFF86EFAC);
  static const Color headerAdd = Color(0xFFD8B4FE);

  // Soft rainbow gradient for liquid borders
  static const List<Color> liquidBorderGradient = [
    Color(0xFFFFB3B3),
    Color(0xFFA3FF91),
    Color(0xFF78EFFF),
    Color(0xFFDCCBFF),
    Color(0xFFFFB6DC),
  ];
}
