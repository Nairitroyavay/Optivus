import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';

void main() {
  group('AiThinkingCard', () {
    const testMessages = [
      'Message 1',
      'Message 2',
      'Message 3',
    ];

    testWidgets('shows first message immediately when active', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              messages: testMessages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.text('Message 1'), findsOneWidget);
      expect(find.text('Message 2'), findsNothing);
    });

    testWidgets('rotates to second message after one interval', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              messages: testMessages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
              messageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Message 1'), findsOneWidget);
      
      // Advance time by 1 interval
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Message 2'), findsOneWidget);
    });

    testWidgets('cycles through all messages', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              messages: testMessages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
              messageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Message 1'), findsOneWidget);
      
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Message 2'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Message 3'), findsOneWidget);

      // Verify it stays on the last message
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Message 3'), findsOneWidget);
    });

    testWidgets('shows reassurance text steps correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              messages: testMessages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
              reassuranceInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      // Initial state (0-5s)
      expect(find.text('This usually takes a few moments.'), findsOneWidget);

      // Advance past 6 ticks (6s)
      await tester.pump(const Duration(milliseconds: 650));
      expect(
          find.text(
              'Still reading the details — timetable and meal photos can take longer.'),
          findsOneWidget);

      // Advance past 12 ticks (12s)
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('AI is checking the structure carefully.'),
          findsOneWidget);

      // Advance past 20 ticks (20s)
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Almost there. Please don\'t close the app.'),
          findsOneWidget);
    });

    testWidgets('does not overflow on small width', (tester) async {
      final oldSize = tester.view.physicalSize;
      tester.view.physicalSize = const Size(200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = oldSize;
        tester.view.devicePixelRatio = 3.0;
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: AiThinkingCard(
                messages: [
                  'This is a very long message that should wrap softly without any overflow errors in the widget tree.',
                ],
                accent: OptivusColors.aquaAccent,
                isActive: true,
              ),
            ),
          ),
        ),
      );

      // Wait for layout and check for exceptions
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('resets message index on isActive false->true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              messages: testMessages,
              accent: OptivusColors.aquaAccent,
              isActive: false,
              messageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Message 1'), findsNothing);

      // Rebuild with isActive: true
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              messages: testMessages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
              messageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      expect(find.text('Message 1'), findsOneWidget);

      // Advance to message 2
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Message 2'), findsOneWidget);

      // Rebuild with isActive: false
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              messages: testMessages,
              accent: OptivusColors.aquaAccent,
              isActive: false,
              messageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );
      
      expect(find.text('Message 2'), findsNothing);

      // Rebuild with isActive: true again
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              messages: testMessages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
              messageInterval: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      // Should reset to first message
      expect(find.text('Message 1'), findsOneWidget);
    });

    testWidgets('no visible DEBUG text is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiThinkingCard(
              messages: testMessages,
              accent: OptivusColors.aquaAccent,
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.textContaining('DEBUG'), findsNothing);
    });
  });
}
