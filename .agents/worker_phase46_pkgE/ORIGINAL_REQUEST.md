## 2026-07-28T09:34:45Z

Remediate the following 3 Firestore Security Rules issues in genuine rules logic following the Evidence-Based Fix Protocol (R5) and Production Safety Rules (R3/R4):

1. ISSUE-SEC-01 / PATH3-SEC-01 (P0): Wildcard Subcollection Catch-All Rule Bypasses Validation
   Files: firestore.rules (lines 985-996)
   Fix: Replace permissive wildcard catch-all rule with strict owner-scoped, schema-validated rules for all subcollections (routineHistory, trackers, routines, etc.).

2. ISSUE-SEC-02 / PATH3-SEC-02 (P1): Permissive Onboarding Collection Rule Allows Malformed Document Injection
   Files: firestore.rules (lines 929-931)
   Fix: Replace permissive onboarding matching rule with schema-validated rules checking owner UID, valid schema version, and required field structures for onboarding drafts, completion bundles, and completion jobs.

3. ISSUE-SEC-03 / PATH3-SEC-03 (P1): Root User Profile Document (/users/{uid}) Lacks Key & Field Length Rules
   Files: firestore.rules (lines 977-979)
   Fix: Add strict field length restrictions, required string formats, enum bounds, and uid matching rules for `/users/{uid}` document updates.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Verification Requirements:
1. Validate syntax and semantics of `firestore.rules`.
2. Run Firestore Security Rules unit/emulator tests or `flutter test test/firestore_rules_test.dart` (or relevant rules test file).
3. Run `flutter analyze` and `flutter test`.
4. Write your report to `/Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgE/changes_pkgE.md` and `/Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgE/handoff.md`.
5. Send a completion message to parent when done.
