import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_motion.dart';
import 'package:optivus/core/theme/optivus_radii.dart';

void main() {
  test('corner-radius tokens preserve the approved ascending scale', () {
    expect(const [
      OptivusRadii.none,
      OptivusRadii.xs,
      OptivusRadii.sm,
      OptivusRadii.md,
      OptivusRadii.lg,
      OptivusRadii.xl,
      OptivusRadii.xxl,
      OptivusRadii.xxxl,
      OptivusRadii.pill,
    ], orderedEquals(const [0, 4, 8, 12, 16, 20, 24, 30, 999]));
  });

  test('motion tokens preserve durations, curves, and reduced motion', () {
    expect(OptivusMotion.reducedDuration, Duration.zero);
    expect(OptivusMotion.pressDuration, const Duration(milliseconds: 120));
    expect(OptivusMotion.fastDuration, const Duration(milliseconds: 180));
    expect(OptivusMotion.standardDuration, const Duration(milliseconds: 300));
    expect(OptivusMotion.slowDuration, const Duration(milliseconds: 400));
    expect(OptivusMotion.standardCurve, same(Curves.easeInOut));
    expect(OptivusMotion.enterCurve, same(Curves.easeOutCubic));
    expect(OptivusMotion.exitCurve, same(Curves.easeIn));
  });
}
