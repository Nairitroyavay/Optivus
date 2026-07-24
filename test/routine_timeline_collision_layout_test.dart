import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/timeline/timeline_visual_layout.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';

class _VisualItem implements TimelineVisualItem {
  @override
  final String id;
  @override
  final int startMinute;
  @override
  final int endMinute;
  @override
  final double minHeight;
  @override
  final int priority = 50;

  const _VisualItem({
    required this.id,
    required this.startMinute,
    required this.endMinute,
    this.minHeight = 72,
  });
}

void main() {
  group('Routine timeline collision layout', () {
    test(
      'minute/y conversion round-trips across stretch and overnight ranges',
      () {
        final result = TimelineVisualLayout.build<_VisualItem>(
          items: const [
            _VisualItem(id: 'evening', startMinute: 1320, endMinute: 1500),
          ],
          pixelsPerMinute: 2,
          timelineWidth: 360,
          focusedItemId: null,
          visibleStartMinute: 0,
          visibleEndMinute: 1560,
          topPadding: 12,
          stretchedSegments: const [
            TimelineStretchedSegment(
              startMinute: 600,
              endMinute: 660,
              extraStretch: 72,
            ),
          ],
        );

        for (final minute in <int>[
          0,
          1,
          300,
          600,
          630,
          660,
          1439,
          1500,
          1560,
        ]) {
          final y = result.scale.yForMinute(minute);
          expect(
            result.scale.minuteForY(y),
            closeTo(minute, 0.001),
            reason: 'minute $minute should survive yForMinute/minuteForY',
          );
        }

        expect(result.scale.minuteForY(-100), 0);
        expect(
          result.scale.minuteForY(result.scale.yForMinute(2000)),
          closeTo(1560, 0.001),
        );
      },
    );

    test(
      'overlapping short tasks remain readable with deterministic front item',
      () {
        final result = TimelineVisualLayout.build<_VisualItem>(
          items: const [
            _VisualItem(
              id: 'a',
              startMinute: 600,
              endMinute: 610,
              minHeight: 88,
            ),
            _VisualItem(
              id: 'b',
              startMinute: 605,
              endMinute: 615,
              minHeight: 88,
            ),
            _VisualItem(
              id: 'c',
              startMinute: 607,
              endMinute: 617,
              minHeight: 88,
            ),
          ],
          pixelsPerMinute: 1.4,
          timelineWidth: 320,
          focusedItemId: null,
          visibleStartMinute: 540,
          visibleEndMinute: 720,
        );

        expect(result.entries, hasLength(3));
        expect(result.entries.every((entry) => entry.hasOverlap), isTrue);
        expect(result.entries.every((entry) => entry.height >= 88), isTrue);
        expect(result.entries.every((entry) => entry.top >= 0), isTrue);
        expect(result.entries.every((entry) => entry.left >= 0), isTrue);
        expect(result.entries.every((entry) => entry.right >= 0), isTrue);
        expect(result.entries.where((entry) => entry.isFront), hasLength(1));
        expect(result.entries.map((entry) => entry.lane).toSet(), contains(2));
      },
    );

    test('back-to-back short tasks stretch so cards never crush', () {
      final result = TimelineVisualLayout.build<_VisualItem>(
        items: const [
          _VisualItem(
            id: 'first',
            startMinute: 600,
            endMinute: 605,
            minHeight: 88,
          ),
          _VisualItem(
            id: 'second',
            startMinute: 605,
            endMinute: 610,
            minHeight: 88,
          ),
        ],
        pixelsPerMinute: 1.4,
        timelineWidth: 320,
        focusedItemId: null,
        visibleStartMinute: 540,
        visibleEndMinute: 720,
      );

      final first = result.entries.singleWhere(
        (entry) => entry.item.id == 'first',
      );
      final second = result.entries.singleWhere(
        (entry) => entry.item.id == 'second',
      );

      expect(first.height, greaterThanOrEqualTo(88));
      expect(second.height, greaterThanOrEqualTo(88));
      expect(second.top, greaterThanOrEqualTo(first.top + first.height));
      expect(result.scale.yForMinute(605), first.top + first.height);
    });

    test('focus promotion changes only the visual front item', () {
      final result = TimelineVisualLayout.build<_VisualItem>(
        items: const [
          _VisualItem(id: 'primary', startMinute: 600, endMinute: 690),
          _VisualItem(id: 'background', startMinute: 615, endMinute: 660),
        ],
        pixelsPerMinute: 1.5,
        timelineWidth: 360,
        focusedItemId: 'primary',
        visibleStartMinute: 540,
        visibleEndMinute: 720,
      );

      final primary = result.entries.singleWhere(
        (entry) => entry.item.id == 'primary',
      );
      final background = result.entries.singleWhere(
        (entry) => entry.item.id == 'background',
      );
      expect(primary.isFront, isTrue);
      expect(background.isFront, isFalse);
      expect(primary.left, greaterThan(background.left));
    });

    test(
      'overnight collision layout has positive rails and tap-width budget',
      () {
        final result = TimelineVisualLayout.build<_VisualItem>(
          items: const [
            _VisualItem(id: 'sleep', startMinute: 1380, endMinute: 1500),
            _VisualItem(id: 'water', startMinute: 1440, endMinute: 1445),
          ],
          pixelsPerMinute: 1.2,
          timelineWidth: 220,
          focusedItemId: 'water',
          visibleStartMinute: 1320,
          visibleEndMinute: 1560,
        );

        expect(result.entries, hasLength(2));
        for (final entry in result.entries) {
          final railHeight =
              result.scale.yForMinute(entry.item.endMinute) -
              result.scale.yForMinute(entry.item.startMinute);
          expect(railHeight, greaterThan(0));
          expect(220 - entry.left - entry.right, greaterThanOrEqualTo(44));
        }
      },
    );
  });
}
