import 'dart:io';

void main() {
  var file = File('test/onboarding_step7_skin_care_test.dart');
  var content = file.readAsStringSync();
  content = content.replaceFirst("final finder = find.byType(Text);", """
    final b = ProviderScope.containerOf(tester.element(find.byType(OnboardingStep7))).read(mockOnboardingProvider).draft.baseTimeline.blocks.length;
    print('Blocks length: \$b');
    final finder = find.byType(Text);
    """);
  file.writeAsStringSync(content);
}
