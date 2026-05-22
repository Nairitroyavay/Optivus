import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/widgets/app_button.dart';

void main() {
  testWidgets('AppButton renders text and triggers onPressed', (WidgetTester tester) async {
    bool pressed = false;

    // Build the AppButton.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            text: 'Test Button',
            onPressed: () {
              pressed = true;
            },
          ),
        ),
      ),
    );

    // Verify that the button text renders correctly.
    expect(find.text('Test Button'), findsOneWidget);

    // Tap the button and pump in multiple small steps to allow async futures to resolve.
    await tester.tap(find.text('Test Button'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }

    // Verify that onPressed was triggered.
    expect(pressed, isTrue);
  });
}
