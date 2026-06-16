import 'dart:io';

void main() {
  var file = File('test/onboarding_step7_skin_care_test.dart');
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    "expect(find.text('Routine built'), findsOneWidget);",
    """
    final finder = find.byType(Text);
    print('Text widgets found: \${tester.widgetList<Text>(finder).map((t) => t.data).toList()}');
    expect(find.text('Routine built'), findsOneWidget);
    """
  );
  file.writeAsStringSync(content);
}
