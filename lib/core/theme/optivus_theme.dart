import 'package:flutter/material.dart';
import 'optivus_colors.dart';

class OptivusTheme {
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
          side: const BorderSide(color: OptivusColors.borderSoft, width: 1),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: OptivusColors.borderSoft,
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
