## 2026-07-29T09:45:37Z
You are worker_workstream_b_2 assigned to execute Workstream B: Firestore Contracts for Optivus Phase 4.6.2 Final Corrective Closure.

# Working Directories
- Project Root: /Users/roy/optivus2/Optivus
- Your Working Directory: /Users/roy/optivus2/Optivus/.agents/worker_workstream_b_2

# MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

# YOUR TASKS
1. Set up your agent directory at `/Users/roy/optivus2/Optivus/.agents/worker_workstream_b_2` with `BRIEFING.md` and `progress.md`.
2. Inspect and verify all production Firestore serializers against `firestore.rules` and emulator fixtures:
   - `UserProfile.toFirestoreMap()` vs `validUserProfileKeys`
   - `RegionSettings.toFirestoreMap()` vs `validSettingsDoc`
   - `UserPreferences.toFirestoreMap()` vs `validProfileSubdoc`
   - `OnboardingDraft.toFirestoreMap()` vs `validOnboardingDraftKeys`
   - `OnboardingCompletionBundle.toFirestoreMap()` vs `validOnboardingCompletionBundleKeys`
   - `OnboardingCompletionJob.toMap()` vs `validOnboardingCompletionJob` (ensure `lastFailureOccurredAt` timestamp format is compatible)
   - `RoutineItem`, `RoutineOccurrence`, `RoutineEventRecord`, `RoutineProjectionReceipt` serializers vs rules
   - `HabitSystem` serializer vs rules
3. Verify that cross-user access, immutable ownership changes, unknown fields, and invalid statuses/timestamps are denied by rules and correctly serialized by production code.
4. Run `flutter analyze` using `run_command` in `/Users/roy/optivus2/Optivus`.
5. Run target serializer/rules unit tests: `flutter test test/work_package_c_remediation_test.dart`.
6. Document each verified or updated contract using the 18-step Issue Execution Loop format.
7. Write `handoff.md` at `/Users/roy/optivus2/Optivus/.agents/worker_workstream_b_2/handoff.md` and send completion report back to Lead Orchestrator via `send_message`.
