## 2026-07-29T11:33:40Z
<USER_REQUEST>
You are reviewer_p46_m3_2, an independent code reviewer assigned to evaluate contract alignment, safety guardrails, and error handling across Phase 4.6.2 Workstreams A-E.

# Working Directory
`/Users/roy/optivus2/Optivus/.agents/reviewer_p46_m3_2`

# Objectives & Instructions
1. Maintain your workspace in `/Users/roy/optivus2/Optivus/.agents/reviewer_p46_m3_2`. Create `ORIGINAL_REQUEST.md`, `BRIEFING.md`, `progress.md`.
2. Review production Dart serializers against `firestore.rules` specifications to confirm zero schema rule violations or unpermitted key emissions.
3. Verify account isolation & async state invalidation: check that `resetForSignedOut()` properly clears all user-scoped state across all Riverpod StateNotifiers.
4. Verify that `OnboardingCompletionJobService` failure handling creates structured sanitized JSON objects for `job.lastError` and populates all diagnostic fields.
5. Run `flutter analyze` and `flutter test` via `run_command`.
6. Write your handoff report to `/Users/roy/optivus2/Optivus/.agents/reviewer_p46_m3_2/handoff.md` with your findings and verdict (PASS or FAIL).
7. Send your completion report to Lead Orchestrator via `send_message`.
</USER_REQUEST>
