import 'dart:io';

void main() {
  var file = File('test/onboarding_step7_skin_care_test.dart');
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    "print('Blocks length: \$b');",
    """
    print('Blocks length: \$b');
    final p = ProviderScope.containerOf(tester.element(find.byType(OnboardingStep7))).read(mockOnboardingProvider).draft.baseTimeline.skinCareSetupPath;
    print('Path: \$p');
    """
  );
  file.writeAsStringSync(content);
}
