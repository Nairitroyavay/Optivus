import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';

void main() {
  for (final domain in <(String, Color)>[
    ('Classes', Colors.blue),
    ('Work', Colors.amber),
    ('Eating', Colors.pink),
  ]) {
    testWidgets(
      '${domain.$1} keeps accessible icon-only Edit schedule action',
      (tester) async {
        var edited = false;
        var changedSource = false;
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BaseTimelineCurrentSetupHeader(
                title: domain.$1,
                summary: 'A long current setup summary that may wrap safely',
                accent: domain.$2,
                onBack: () {},
                primaryButtonLabel: 'Edit schedule',
                primaryButtonKey: const Key(
                  'base-timeline-header-edit-schedule-button',
                ),
                iconOnly: true,
                onPrimaryAction: () => edited = true,
                onChangeSource: () => changedSource = true,
              ),
            ),
          ),
        );

        final edit = find.byKey(
          const Key('base-timeline-header-edit-schedule-button'),
        );
        final menu = find.byKey(const Key('base-timeline-header-menu-button'));
        expect(edit, findsOneWidget);
        expect(menu, findsOneWidget);
        expect(find.text('Edit schedule'), findsNothing);
        expect(find.bySemanticsLabel('Edit schedule'), findsOneWidget);
        expect(tester.getSize(edit).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(edit).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(edit).overlaps(tester.getRect(menu)), isFalse);

        await tester.tap(edit);
        expect(edited, isTrue);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Change source'));
        expect(changedSource, isTrue);
        semantics.dispose();
      },
    );
  }

  testWidgets('icon-only header has no overflow across width and text scales', (
    tester,
  ) async {
    for (final width in <double>[320, 360, 390, 412, 430, 768]) {
      for (final scale in [1.0, 1.3, 1.5, 2.0]) {
        tester.view.physicalSize = Size(width, 240);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: BaseTimelineCurrentSetupHeader(
                  title: 'Eating',
                  summary: 'Built for me · Gain weight · 2,450 kcal target',
                  accent: Colors.pink,
                  onBack: () {},
                  primaryButtonLabel: 'Edit schedule',
                  iconOnly: true,
                  onPrimaryAction: () {},
                  onChangeSource: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'width=$width scale=$scale',
        );
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
