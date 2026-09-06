import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Returns the run identity Firestore Rules can derive from the authoritative
/// draft without trusting a client-supplied opaque identifier.
String stableOnboardingRunId({
  required String ownerUid,
  required String sourceFingerprint,
  required int draftRevision,
}) {
  final fingerprint = sourceFingerprint.trim();
  if (ownerUid.trim().isEmpty ||
      draftRevision < 1 ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)) {
    throw ArgumentError(
      'Onboarding run identity requires an owner, revision, and canonical fingerprint.',
    );
  }
  return 'run_$fingerprint';
}

/// Compatibility identity used by completion runs created before the
/// server-verifiable pointer replacement contract.
String legacyOnboardingRunId({
  required String ownerUid,
  required String sourceFingerprint,
  required int draftRevision,
}) {
  final digest = sha256.convert(
    utf8.encode(
      'onboarding-run-v1\u001f$ownerUid\u001f$draftRevision\u001f$sourceFingerprint',
    ),
  );
  return 'run_${digest.toString().substring(0, 40)}';
}

bool matchesOnboardingRunIdentity({
  required String runId,
  required String ownerUid,
  required String sourceFingerprint,
  required int draftRevision,
}) {
  return runId ==
          stableOnboardingRunId(
            ownerUid: ownerUid,
            sourceFingerprint: sourceFingerprint,
            draftRevision: draftRevision,
          ) ||
      runId ==
          legacyOnboardingRunId(
            ownerUid: ownerUid,
            sourceFingerprint: sourceFingerprint,
            draftRevision: draftRevision,
          );
}
