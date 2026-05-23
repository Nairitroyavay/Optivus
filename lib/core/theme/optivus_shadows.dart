import 'package:flutter/material.dart';

/// Optivus Shadow Presets
/// Reusable box shadow configurations for the liquid glass design system.
class OptivusShadows {
  OptivusShadows._();

  /// Subtle shadow for flat cards and inputs
  static final List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  /// Medium shadow for elevated cards and panels
  static final List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  /// Strong shadow for modals and floating elements
  static final List<BoxShadow> elevated = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 30,
      offset: const Offset(0, 12),
    ),
  ];

  /// Glass card shadow with white top highlight
  static final List<BoxShadow> glassCard = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.8),
      blurRadius: 0,
      offset: const Offset(-1, -1),
    ),
  ];

  /// Colored glow shadow — pass accent color for tab-aware glow
  static List<BoxShadow> glow(Color color, {double intensity = 0.3}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: intensity),
        blurRadius: 20,
        spreadRadius: 2,
      ),
    ];
  }
}
