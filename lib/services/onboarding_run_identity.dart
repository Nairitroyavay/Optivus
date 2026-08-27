import 'dart:convert';

import 'package:crypto/crypto.dart';

String stableOnboardingRunId({
  required String ownerUid,
  required String sourceFingerprint,
  required int draftRevision,
}) {
  if (ownerUid.trim().isEmpty || sourceFingerprint.trim().isEmpty) {
    throw ArgumentError(
      'Onboarding run identity requires owner and fingerprint.',
    );
  }
  final digest = sha256.convert(
    utf8.encode(
      'onboarding-run-v1\u001f$ownerUid\u001f$draftRevision\u001f$sourceFingerprint',
    ),
  );
  return 'run_${digest.toString().substring(0, 40)}';
}
