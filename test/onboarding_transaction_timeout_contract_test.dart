import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/repositories/onboarding_repository.dart';

void main() {
  test('heavy onboarding reconcile has an explicit 120 second timeout', () {
    expect(onboardingReconcileTransactionTimeout, const Duration(seconds: 120));
  });

  test(
    'explicit timeout is scoped to the onboarding reconcile transaction',
    () {
      final source = File(
        'lib/repositories/onboarding_repository.dart',
      ).readAsStringSync();

      expect(
        RegExp(
          r'timeout:\s*onboardingReconcileTransactionTimeout',
        ).allMatches(source),
        hasLength(1),
      );
    },
  );
}
