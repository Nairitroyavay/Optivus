## 2026-07-25T21:56:25+05:30
<USER_REQUEST>
You are Worker Agent for Group F (Issues 29-30: Meal Onboarding Validation).

Working Directory: /Users/roy/optivus2/Optivus/.agents/worker_group_f_1

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your Task:
Execute the 13-step loop (Steps 3 through 11) for Group F:
- **Issue 29 (Meal Schedule Density and Spacing Validation)**:
  - Enforce minimum 120 minutes spacing between meal start times on the same day.
  - Enforce maximum 6 meals per day per repeatDay.
  - Update `validateMealScheduleDensity()` and `validateEatingSetup()` in `lib/models/onboarding_draft.dart`.
  - Update `EatingRoutineSetupScreen` in `lib/features/routine/managers/base_timeline/screens/eating_routine_setup_screen.dart` save modal validation.
  - Update `RoutineValidationService` in `lib/features/routine/services/routine_validation_service.dart` if needed.
- **Issue 30 (Multi-Dish Meal Timing Collision Resolution)**:
  - Consolidate multi-dish candidates in `mapOnboarding5MealCandidates` (`lib/features/onboarding/steps/onboarding_step_5_eating_setup.dart`) so concurrent/overlapping dish candidates in the same meal window merge into a single `TimelineBlockDraft` with consolidated `dishes`.
  - Add pre-merging of overlapping eating blocks in `OnboardingCompletionService` (`lib/services/onboarding_completion_service.dart`) prior to `_scheduleRoutineItems` to guarantee zero timeline collisions and zero dish data loss.

Steps to execute:
1. Write failing tests in `test/group_f_issues_29_to_30_test.dart` reproducing Issues 29 and 30.
2. Implement clean, zero-side-effect solutions in `lib/` files.
3. Run `dart format .` on changed files.
4. Run `flutter analyze` ensuring 0 errors / 0 lints.
5. Run `flutter test test/group_f_issues_29_to_30_test.dart` verifying all targeted tests pass.
6. Run related regression tests (`flutter test test/onboarding_step5_eating_setup_test.dart`, `flutter test test/onboarding_persistence_phase2b_test.dart`).
7. Write your handoff report to `/Users/roy/optivus2/Optivus/.agents/worker_group_f_1/handoff.md` with full details of changes and test outputs, then send a completion message.
</USER_REQUEST>
