import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';

void main() {
  testWidgets(
    'OnboardingStageBackButton uses compact layout (icon only) to prevent overlap',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OnboardingStageBackButton(onTap: () {})),
        ),
      );
      await tester.pumpAndSettle();

      // Verify it contains an Icon but NO Text ('Back')
      expect(find.byType(Icon), findsOneWidget);
      expect(find.text('Back'), findsNothing);

      // Verify container size constraint
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(OnboardingStageBackButton),
              matching: find.byType(Container),
            )
            .first,
      );

      // Assert it is 32x32 based on our changes
      expect(container.constraints?.maxWidth, 32);
      expect(container.constraints?.maxHeight, 32);
    },
  );
}
