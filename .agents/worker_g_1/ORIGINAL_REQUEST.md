## 2026-07-26T12:02:30Z

<USER_REQUEST>
You are Worker 1 for Group G (Issues 31–32: Class Timetable Validation).
Your working directory is /Users/roy/optivus2/Optivus/.agents/worker_g_1.

Task:
Implement the fixes for Group G (Issues 31–32):
- **Issue 31**: Class timetable overlap detection with routine items.
- **Issue 32**: Exam schedule priority override during class onboarding import.

Detailed Requirements & Findings:
1. **Issue 31 Fix** (`lib/features/routine/services/routine_conflict_engine.dart`):
   - `RoutineConflictEngine.detect()` currently has `if (isAUnavailable || isBUnavailable)` which flags any overlap between a strict hard block (`classBlock` or `job`) and a soft block (`eating`, habit, etc.) as a blocking `unavailableTime` conflict (`blocking: true`).
   - Change `if (isAUnavailable || isBUnavailable)` to `if (isAUnavailable && isBUnavailable)` so that blocking `unavailableTime` conflicts ONLY occur between TWO strict hard/unavailable blocks (e.g. Class vs Class).
   - Single hard vs soft block overlaps should fall through to `timeOverlap` (`blocking: false`, `canKeepBoth: true`), allowing `RoutineValidationService.validate()` to return `isValid = true` with a soft warning.

2. **Issue 32 Fix** (`lib/features/onboarding/steps/onboarding_step4_unified.dart`):
   - In `mapOnboarding4Candidates()`, exam keyword matching should be expanded beyond `'exam'` to include `'exam'`, `'midterm'`, `'final'`, `'quiz'`, `'test'`, and `'assessment'`.
   - Do NOT delete or strip `repeatDays` from regular class blocks when an exam overlaps! Mutating `repeatDays.removeWhere(...)` or dropping class blocks destroys user class template data (violates R11 - no silent data deletion).
   - Keep regular class blocks intact in `resolvedBlocks`. Mark exam candidate blocks with `hardBlock: true` and high priority (`mustDo`) so they take precedence during date materialization/scheduling without destroying regular class schedule templates.

3. **Test Suite Fix & Verification** (`test/group_g_issues_31_to_32_test.dart`):
   - Fix constructor parameters in `test/group_g_issues_31_to_32_test.dart` (pass `hardBlock: true` to `RoutineImportCandidateBlock` constructors where missing, and fix `List<dynamic>` type assignment to `List<RoutineImportCandidateBlock>`).
   - Run `flutter test test/group_g_issues_31_to_32_test.dart`.
   - Run `flutter test test/routine_conflict_engine_test.dart` and other related tests.
   - Run `flutter analyze` and `dart format --output=none --set-exit-if-changed .`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Deliver your changes, command execution results, and detailed handoff in /Users/roy/optivus2/Optivus/.agents/worker_g_1/handoff.md.
</USER_REQUEST>
