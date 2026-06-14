import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';

void main() {
  group('AiThinkingCard', () {
    testWidgets('Shows title immediately', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.textContaining('Test Title'), findsOneWidget);
    });

    testWidgets('Shows detail immediately', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Test Detail'), findsOneWidget);
    });

    testWidgets('Animated dots appear after title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: true,
              dotInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Test Title.'), findsOneWidget);
    });

    testWidgets('Dot count changes after interval', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: true,
              dotInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Test Title.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Test Title..'), findsOneWidget);
    });

    testWidgets('Dot count cycles from 1 to 4', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: true,
              dotInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Test Title.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Test Title..'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Test Title...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Test Title....'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Test Title.'), findsOneWidget);
    });

    testWidgets('Long-wait helper appears after the configured delay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: true,
              firstLongWaitDelay: Duration(seconds: 1),
              secondLongWaitDelay: Duration(seconds: 2),
            ),
          ),
        ),
      );

      expect(find.text('Detailed photos can take a little longer'), findsNothing);
      expect(find.text('Still working. Keep this screen open'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Detailed photos can take a little longer'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Still working. Keep this screen open'), findsOneWidget);
    });

    testWidgets('No progress line exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('No CircularProgressIndicator exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('No fake percentage or step count appears', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('Step'), findsNothing);
    });

    testWidgets('No overflow at 200px width', (tester) async {
      final oldSize = tester.view.physicalSize;
      final oldDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = oldSize;
        tester.view.devicePixelRatio = oldDpr;
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: AiThinkingCard(
                title: 'This is a very long title that should wrap safely',
                detail: 'This is a very long detail that should also wrap safely without any overflow exceptions.',
                accent: OptivusColors.aquaAccent,
                isActive: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dots reset when inactive then active again', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: false,
              dotInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.textContaining('Test Title'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: true,
              dotInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Test Title.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Test Title..'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: false,
              dotInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.textContaining('Test Title'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              title: 'Test Title',
              detail: 'Test Detail',
              accent: OptivusColors.aquaAccent,
              isActive: true,
              dotInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Test Title.'), findsOneWidget);
    });
  });
}
