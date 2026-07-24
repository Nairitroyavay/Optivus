import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Routine Phase 4 Source-Level Architecture Tests', () {
    test(
      'production Routine screens do not import or watch legacy mock routine providers',
      () {
        final routineDir = Directory('lib/features/routine');
        expect(
          routineDir.existsSync(),
          isTrue,
          reason: 'lib/features/routine directory must exist.',
        );

        final dartFiles = routineDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        final forbiddenPatterns = [
          'mockRoutineProvider',
          'legacyRoutineProvider',
          'fakeRoutineNotifier',
        ];

        final violations = <String>[];

        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          for (final pattern in forbiddenPatterns) {
            if (content.contains(pattern)) {
              violations.add('${file.path}: contains "$pattern"');
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Production Routine screens must not use legacy mock routine providers:\n${violations.join('\n')}',
        );
      },
    );
  });
}
