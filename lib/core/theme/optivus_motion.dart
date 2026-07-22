import 'package:flutter/animation.dart';

/// Canonical motion durations and curves for new and touched Optivus UI.
///
/// Callers must replace decorative motion with [reducedDuration] when the
/// current MediaQuery requests disabled animations.
class OptivusMotion {
  OptivusMotion._();

  static const Duration reducedDuration = Duration.zero;
  static const Duration pressDuration = Duration(milliseconds: 120);
  static const Duration fastDuration = Duration(milliseconds: 180);
  static const Duration standardDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 400);

  static const Curve standardCurve = Curves.easeInOut;
  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeIn;
}
