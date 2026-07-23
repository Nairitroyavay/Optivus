import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';

void main() {
  group('OnboardingTimelineLayout Monotonicity & Lens Tests', () {
    test('without stretching, ticks map linearly and monotonically', () {
      final layout = OnboardingTimelineLayout(
        startMinute: 480, // 8:00 AM
        rangeMinutes: 720, // 12 hours
        pxPerMinute: 1.0,
        topPadding: 10.0,
        segments: const [],
      );

      expect(layout.yFor(480), 10.0);
      expect(layout.yFor(540), 70.0);
      expect(layout.yFor(1200), 730.0);

      // Verify strict monotonicity
      for (int m = 480; m < 1200; m += 5) {
        expect(layout.yFor(m) < layout.yFor(m + 5), true);
      }
    });

    test('single stretched segment increases local height and is monotonic', () {
      final layout = OnboardingTimelineLayout(
        startMinute: 480, // 8:00 AM
        rangeMinutes: 720,
        pxPerMinute: 1.0,
        topPadding: 10.0,
        segments: const [
          StretchedSegment(
            startMinute: 600,
            endMinute: 620,
            extraStretch: 50.0,
          ),
        ],
      );

      // Ticks before stretch are unaffected in duration (relative distance)
      expect(layout.yFor(600) - layout.yFor(540), 60.0);

      // Segment duration: 20m. Normal height: 20px. Extrastretch: 50px. Total: 70px.
      expect(layout.yFor(620) - layout.yFor(600), 70.0);

      // Ticks after stretch are shifted but their relative distance is stable
      expect(layout.yFor(1200) - layout.yFor(620), 580.0);

      // Verify strict monotonicity
      for (int m = 480; m < 1200; m += 5) {
        expect(layout.yFor(m) < layout.yFor(m + 5), true);
      }
    });

    test(
      'overlapping segments merge and preserve monotonicity and stability',
      () {
        // Segment 1: 600 - 620, extra: 50
        // Segment 2: 615 - 635, extra: 30
        // Union: 600 - 635, combined extra: 80
        final layout = OnboardingTimelineLayout(
          startMinute: 480,
          rangeMinutes: 720,
          pxPerMinute: 1.0,
          topPadding: 10.0,
          segments: const [
            StretchedSegment(
              startMinute: 600,
              endMinute: 620,
              extraStretch: 50.0,
            ),
            StretchedSegment(
              startMinute: 615,
              endMinute: 635,
              extraStretch: 30.0,
            ),
          ],
        );

        // Union range: 600 - 635.
        // Normal height: 35. Combined extra stretch: 80. Total: 115.
        expect(layout.yFor(635) - layout.yFor(600), closeTo(115.0, 0.001));

        // Check monotonicity
        for (int m = 480; m < 1200; m += 1) {
          expect(layout.yFor(m) < layout.yFor(m + 1), true);
        }
      },
    );

    test('adjacent segments merge and preserve monotonicity and stability', () {
      // Segment 1: 600 - 620, extra: 50
      // Segment 2: 620 - 640, extra: 40
      // Union: 600 - 640, combined extra: 90
      final layout = OnboardingTimelineLayout(
        startMinute: 480,
        rangeMinutes: 720,
        pxPerMinute: 1.0,
        topPadding: 10.0,
        segments: const [
          StretchedSegment(
            startMinute: 600,
            endMinute: 620,
            extraStretch: 50.0,
          ),
          StretchedSegment(
            startMinute: 620,
            endMinute: 640,
            extraStretch: 40.0,
          ),
        ],
      );

      expect(layout.yFor(640) - layout.yFor(600), closeTo(130.0, 0.001));

      for (int m = 480; m < 1200; m += 1) {
        expect(layout.yFor(m) < layout.yFor(m + 1), true);
      }
    });
  });
}
