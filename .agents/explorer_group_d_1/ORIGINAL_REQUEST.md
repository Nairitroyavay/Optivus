## 2026-07-25T14:57:18Z

<USER_REQUEST>
You are the Explorer subagent for Group D (Issues 16–21: Authentication & account lifecycle) of Optivus Onboarding Stabilization.

Working directory: /Users/roy/optivus2/Optivus/.agents/explorer_group_d_1
Report location: /Users/roy/optivus2/Optivus/.agents/explorer_group_d_1/handoff.md

Scope: Group D (Issues 16–21)
- Issue 16: Auth state stream synchronization across Riverpod and GoRouter
- Issue 17: User sign-out state invalidation for all cached feature controllers
- Issue 18: Account switching data leak prevention across user scopes
- Issue 19: Typed auth failure mapping for network interruptions and invalid tokens
- Issue 20: Email verification step enforcement before post-onboarding navigation
- Issue 21: Anonymous-to-authenticated account link state preservation

Task:
1. Initialize your working directory .agents/explorer_group_d_1 with BRIEFING.md and progress.md.
2. Inspect auth-related codebase files: `lib/state/auth_state.dart`, `lib/core/router/app_router.dart`, `lib/repositories/auth_repository.dart`, `lib/features/auth/`, `lib/features/onboarding/`, Riverpod providers for feature controllers (`RoutineNotifier`, `HabitSystemsNotifier`, etc.), `test/onboarding_routing_test.dart`, `test/auth_test.dart`, etc.
3. Read `docs/onboarding_stabilization_report.md` for background and context.
4. For each issue (Issues 16, 17, 18, 19, 20, 21):
   - Identify the exact root cause in the current implementation.
   - Trace stream listeners, state invalidations on sign-out/switch, typed failure exceptions, email verification checks, and anonymous account linking data migration.
   - Formulate concrete architectural fixes conforming to requirements R1–R11 (zero data corruption, typed auth errors, seamless router integration, account data isolation).
   - Specify targeted test cases to add or update.
5. Write your comprehensive analysis and fix plan into `.agents/explorer_group_d_1/handoff.md`.
6. Send a message back to the orchestrator with a summary of findings and the handoff path.
</USER_REQUEST>
