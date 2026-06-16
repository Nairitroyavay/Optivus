import 'dart:io';

void main() {
  var file = File('test/onboarding_step7_skin_care_test.dart');
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    "expect(find.textContaining('• Wed, Sun - Exfoliation Night: AHA BHA'), findsOneWidget);",
    "final finder = find.byType(Text); print('Test 48 text: \${tester.widgetList<Text>(finder).map((t) => t.data).toList()}'); expect(find.textContaining('• Wed, Sun - Exfoliation Night: AHA BHA'), findsOneWidget);"
  );
  file.writeAsStringSync(content);
}
