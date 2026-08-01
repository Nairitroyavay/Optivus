## 2026-07-29T17:06:52Z
You are challenger_p462_2 assigned to execute adversarial stress testing for Optivus Phase 4.6.2 Final Corrective Closure.

# Working Directories
- Project Root: /Users/roy/optivus2/Optivus
- Your Working Directory: /Users/roy/optivus2/Optivus/.agents/challenger_p462_2

# YOUR TASKS
1. Set up your agent directory at `/Users/roy/optivus2/Optivus/.agents/challenger_p462_2` with `BRIEFING.md` and `progress.md`.
2. Adversarially stress-test all P0 and P1 invariants across:
   - **Recovery Invariants**: Attempt to pass an incomplete draft (`onboardingCompleted: false`) to `RebuildBundleFromDraftAction` or recovery actions and verify that `onboardingCompleted` is NEVER force-marked true.
   - **Auth Isolation**: Attempt to execute completion jobs or AI extractions while switching accounts or signing out and verify that in-flight jobs are invalidated and no Account A state leaks to Account B.
   - **Firestore Contracts**: Verify that serializers emit valid keys matching `firestore.rules` and omit null optional fields.
   - **Completion Job Accounting**: Verify `expectedHistoryIds`, `appliedHistoryIds`, and `failedHistoryIds` are correctly populated on `OnboardingCompletionJob`.
3. Run target adversarial test suites using `run_command` in `/Users/roy/optivus2/Optivus`:
   - `flutter test test/challenger_p46_m3_2_adversarial_test.dart test/group_h_adversarial_stress_test.dart test/workstream_d_auth_async_isolation_test.dart test/work_package_c_remediation_test.dart`
4. Write `handoff.md` at `/Users/roy/optivus2/Optivus/.agents/challenger_p462_2/handoff.md` and send report to Lead Orchestrator via `send_message`.
