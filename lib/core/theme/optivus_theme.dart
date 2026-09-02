import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'optivus_colors.dart';

/// Canonical minimum accessible interactive touch target tokens (AH-F022).
class OptivusTouchTarget {
  OptivusTouchTarget._();

  /// Minimum accessible interactive tap target size (Android 48dp standard).
  static const double minimum = 48.0;

  /// Box constraints enforcing minimum 48x48dp interactive area.
  static const BoxConstraints minConstraints = BoxConstraints(
    minWidth: minimum,
    minHeight: minimum,
  );
}

/// Canonical icon sizing tokens across the Optivus design system (AH-F022).
class OptivusIconSize {
  OptivusIconSize._();

  static const double small = 16.0;
  static const double standard = 20.0;
  static const double medium = 24.0;
  static const double large = 32.0;
  static const double hero = 48.0;
}

class OptivusTheme {
  /// Canonical overlay style for warm-cream Auth surfaces.
  static const authOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Color(0xFFFCF8EE),
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );

  /// Canonical overlay style for light onboarding & timeline surfaces.
  static const onboardingOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Color(0xFFFFFFFF),
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );

  /// Canonical overlay style for dark surfaces.
  static const darkOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Color(0xFF0F1015),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );

  /// Legacy alias maintained for backwards compatibility.
  static const lightSystemUiOverlayStyle = authOverlayStyle;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,

      // Seed color for material widgets
      colorScheme: ColorScheme.fromSeed(
        seedColor: OptivusColors.brandAccent,
        primary: OptivusColors.brandAccent,
        secondary: OptivusColors.aquaAccent,
        surface: Colors.white,
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: OptivusColors.textPrimary,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: OptivusColors.textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: OptivusColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: OptivusColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: OptivusColors.textBody,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: OptivusColors.textSecondary,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: OptivusColors.textMuted,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: OptivusColors.borderStandard, width: 1),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: OptivusColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,

      colorScheme: ColorScheme.fromSeed(
        seedColor: OptivusColors.brandAccent,
        brightness: Brightness.dark,
        primary: OptivusColors.brandAccent,
        secondary: OptivusColors.aquaAccent,
        surface: const Color(0xFF1E202A),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: OptivusColors.textPrimaryDark,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: OptivusColors.textPrimaryDark,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: OptivusColors.textPrimaryDark,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: OptivusColors.textPrimaryDark,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: OptivusColors.textBodyDark,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: OptivusColors.textSecondaryDark,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: OptivusColors.textMutedDark,
        ),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1E202A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x33FFFFFF), width: 1),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0x33FFFFFF),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
