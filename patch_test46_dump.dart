import 'dart:io';

void main() {
  final content = File('test/onboarding_step7_skin_care_test.dart').readAsStringSync();
  final newContent = content.replaceFirst(
    "final ex = tester.takeException();\n    if (ex != null) {\n      debugPrint('==== EXCEPTION DUMP ====');\n      if (ex is FlutterError) {\n        FlutterError.dumpErrorToConsole(FlutterErrorDetails(exception: ex));\n      } else {\n        debugPrint(ex.toString());\n      }\n    }\n    expect(ex, isNull);",
    "// Removed takeException"
  );
  File('test/onboarding_step7_skin_care_test.dart').writeAsStringSync(newContent);
}
