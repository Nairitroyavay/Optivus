import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_save_success_view.dart';

void main() {
  group('BaseTimelineSaveSuccessView Glass & Visual Contract Tests', () {
    testWidgets(
      'Uses true Optivus glass with BackdropFilter and zero BoxShadow',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BaseTimelineSaveSuccessView(
                title: 'Eating plan saved',
                subtitle: 'Your meal plan is now active.',
                accent: OptivusColors.roseAccent,
                onComplete: () {},
              ),
            ),
          ),
        );

        // Verify text rendered
        expect(find.text('Eating plan saved'), findsOneWidget);
        expect(find.text('Your meal plan is now active.'), findsOneWidget);

        // Verify BackdropFilter exists
        final backdropFinder = find.byType(BackdropFilter);
        expect(backdropFinder, findsOneWidget);

        final backdropFilter = tester.widget<BackdropFilter>(backdropFinder);
        expect(
          backdropFilter.filter,
          equals(ImageFilter.blur(sigmaX: 16, sigmaY: 16)),
        );

        // Verify ClipRRect with surfaceLarge radius
        final clipRRectFinder = find.byType(ClipRRect);
        expect(clipRRectFinder, findsOneWidget);

        final clipRRect = tester.widget<ClipRRect>(clipRRectFinder);
        expect(
          clipRRect.borderRadius,
          equals(BorderRadius.circular(OptivusRadii.surfaceLarge)),
        );

        // Verify subtle domain-accent border
        final cardContainers = tester.widgetList<Container>(
          find.byType(Container),
        );
        final decoratedCard = cardContainers.firstWhere(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).border != null,
        );
        final boxDec = decoratedCard.decoration as BoxDecoration;
        expect(boxDec.border!.top.width, equals(1.5));
        expect(
          boxDec.border!.top.color,
          equals(OptivusColors.roseAccent.withValues(alpha: 0.30)),
        );

        // Verify ABSOLUTELY ZERO BoxShadow anywhere in the widget tree
        final containers = tester.widgetList<Container>(find.byType(Container));
        for (final container in containers) {
          final decoration = container.decoration;
          if (decoration is BoxDecoration) {
            expect(
              decoration.boxShadow == null || decoration.boxShadow!.isEmpty,
              isTrue,
              reason: 'BoxDecoration must not contain any BoxShadow',
            );
          }
        }

        // Check checkmark icon
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      },
    );

    testWidgets('Supports domain accents for Classes, Work, and Eating', (
      tester,
    ) async {
      final domains = [
        (
          name: 'Classes',
          title: 'Classes updated',
          subtitle: 'Your new timetable is now active.',
          accent: OptivusColors.blueAccent,
        ),
        (
          name: 'Work',
          title: 'Work schedule saved',
          subtitle: 'Your Base Timeline has been updated.',
          accent: OptivusColors.warning,
        ),
        (
          name: 'Eating',
          title: 'Eating plan saved',
          subtitle: 'Your meal plan is now active.',
          accent: OptivusColors.roseAccent,
        ),
      ];

      for (final domain in domains) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BaseTimelineSaveSuccessView(
                title: domain.title,
                subtitle: domain.subtitle,
                accent: domain.accent,
                onComplete: () {},
              ),
            ),
          ),
        );

        expect(find.text(domain.title), findsOneWidget);
        expect(find.text(domain.subtitle), findsOneWidget);

        // Verify domain icon has correct accent color
        final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
        expect(icon.color, equals(domain.accent));

        // Verify zero shadow for each domain
        final containers = tester.widgetList<Container>(find.byType(Container));
        for (final container in containers) {
          final decoration = container.decoration;
          if (decoration is BoxDecoration) {
            expect(
              decoration.boxShadow == null || decoration.boxShadow!.isEmpty,
              isTrue,
            );
          }
        }
      }
    });

    testWidgets('Renders cleanly on narrow screen (320px) without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BaseTimelineSaveSuccessView(
              title: 'Eating plan saved',
              subtitle: 'Setup saved. Routine projection update pending.',
              accent: OptivusColors.roseAccent,
              onComplete: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Eating plan saved'), findsOneWidget);
      expect(
        find.text('Setup saved. Routine projection update pending.'),
        findsOneWidget,
      );
    });

    testWidgets('Renders cleanly under accessibility large text scale (2.0x)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: BaseTimelineSaveSuccessView(
                title: 'Eating plan saved',
                subtitle: 'Your meal plan is now active.',
                accent: OptivusColors.roseAccent,
                onComplete: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Eating plan saved'), findsOneWidget);
    });

    testWidgets(
      'Reduced motion displays immediately and completes after hold duration',
      (tester) async {
        var completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: BaseTimelineSaveSuccessView(
                  title: 'Work schedule saved',
                  subtitle: 'Your Base Timeline has been updated.',
                  accent: OptivusColors.warning,
                  holdDuration: const Duration(milliseconds: 200),
                  onComplete: () => completed = true,
                ),
              ),
            ),
          ),
        );

        // Glass card is rendered immediately
        expect(find.text('Work schedule saved'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(completed, isFalse);

        // Fast forward past hold duration
        await tester.pump(const Duration(milliseconds: 250));
        expect(completed, isTrue);
      },
    );
  });
}
