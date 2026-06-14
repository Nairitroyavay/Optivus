import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';

void main() {
  group('AiThinkingCard', () {
    const testStages = [
      AiThinkingStage(title: 'Stage 1', detail: 'Detail 1'),
      AiThinkingStage(title: 'Stage 2', detail: 'Detail 2'),
      AiThinkingStage(title: 'Stage 3', detail: 'Detail 3'),
    ];

    testWidgets('shows first stage immediately', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              stages: testStages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Stage 1'), findsOneWidget);
      expect(find.text('Detail 1'), findsOneWidget);
      expect(find.text('Stage 2'), findsNothing);
    });

    testWidgets('progresses to next stage after interval', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              stages: testStages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
              stageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Stage 1'), findsOneWidget);
      
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Stage 2'), findsOneWidget);
      expect(find.text('Detail 2'), findsOneWidget);
    });

    testWidgets('does not loop back to first stage after final stage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              stages: testStages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
              stageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Stage 1'), findsOneWidget);
      
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Stage 2'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Stage 3'), findsOneWidget);

      // Verify it stays on the last stage
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Stage 3'), findsOneWidget);
      expect(find.text('Stage 1'), findsNothing);
    });

    testWidgets('shows long-wait helper only after configured delay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              stages: testStages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
              stageInterval: Duration(seconds: 1), // slow progression
            ),
          ),
        ),
      );

      // Initial state (0s)
      expect(find.text('Large images can take a little longer. Keep this screen open.'), findsNothing);

      // Advance past 15 seconds
      await tester.pump(const Duration(seconds: 16));
      expect(find.text('Large images can take a little longer. Keep this screen open.'), findsOneWidget);
    });

    testWidgets('does not overflow at 200px width', (tester) async {
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
                stages: [
                  AiThinkingStage(
                    title: 'This is a very long title that should wrap safely',
                    detail: 'This is a very long detail that should also wrap safely without any overflow exceptions.',
                  ),
                ],
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

    testWidgets('resets to first stage when inactive then active again', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              stages: testStages,
              accent: OptivusColors.aquaAccent,
              isActive: false,
              stageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Stage 1'), findsNothing);

      // Rebuild with isActive: true
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              stages: testStages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
              stageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Stage 1'), findsOneWidget);

      // Advance to stage 2
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Stage 2'), findsOneWidget);

      // Rebuild with isActive: false
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              stages: testStages,
              accent: OptivusColors.aquaAccent,
              isActive: false,
              stageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );
      
      expect(find.text('Stage 2'), findsNothing);

      // Rebuild with isActive: true again
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              stages: testStages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
              stageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      // Should reset to first stage
      expect(find.text('Stage 1'), findsOneWidget);
    });

    testWidgets('shows safe fallback message when stages list is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              stages: [],
              messages: [],
              accent: OptivusColors.aquaAccent,
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Processing'), findsOneWidget);
    });
  });
}
