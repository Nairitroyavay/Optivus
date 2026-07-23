import 'dart:io';

void main() {
  var file = File('test/onboarding_step7_skin_care_test.dart');
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    "expect(tester.takeException(), isNull);",
    "final exc = tester.takeException(); print('Exception: \$exc'); expect(exc, isNull);",
  );
  file.writeAsStringSync(content);
}
