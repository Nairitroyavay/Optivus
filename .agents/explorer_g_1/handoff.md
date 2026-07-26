# Handoff Report — Group G (Issues 31–32: Class Timetable Validation)

## 1. Observation

Direct observations from codebase inspection and terminal command execution:

1. **Test Failures & Compilation Errors**:
   - Running `flutter test test/group_g_issues_31_to_32_test.dart` (via `run_command`):
     ```
     test/group_g_issues_31_to_32_test.dart:55:36: Error: Required named parameter 'hardBlock' must be provided.
             RoutineImportCandidateBlock(
                                        ^
     lib/models/routine_import_review.dart:279:3: Context: Found this candidate, but the arguments don't match.
       RoutineImportCandidateBlock({
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^
     test/group_g_issues_31_to_32_test.dart:88:21: Error: The argument type 'List<dynamic>' can't be assigned to the parameter type 'List<RoutineImportCandidateBlock>'.
             candidates: candidates,
                         ^
     ```

2. **Issue 31: Classification Defect in `RoutineConflictEngine.detect`**:
   - File: `lib/features/routine/services/routine_conflict_engine.dart`, lines 94–106:
     ```dart
     if (isAUnavailable || isBUnavailable) {
       conflictType = RoutineConflictType.unavailableTime;
       blocking = true;
       canKeepBoth = false;
     } else if (isASleep || isBSleep) {
       conflictType = RoutineConflictType.sleepConflict;
       blocking = true;
       canKeepBoth = false;
     } else if (a.isHardBlock && b.isHardBlock) {
       conflictType = RoutineConflictType.hardBlockConflict;
       blocking = true;
       canKeepBoth = false;
     }
     ```
   - Line 261:
     ```dart
     static bool _isUnavailableTime(RoutineItem item) {
       return _isStrictHard(item);
     }
     static bool _isStrictHard(RoutineItem item) {
       return item.category == RoutineCategory.classBlock ||
           item.category == RoutineCategory.job;
     }
     ```
   - When a `classBlock` overlaps a soft block (e.g., Lunch/`eating` or a `habit`), `isAUnavailable` evaluates to `true`. Because of `isAUnavailable || isBUnavailable` (OR), the conflict is classified as `unavailableTime` with `blocking = true`.
   - `RoutineValidationService.validate()` line 331 checks `conflicts.any((c) => c.blocking)`, returning `isValid = false` (blocking failure) instead of `isValid = true` for soft block overlaps.

3. **Issue 32: Destructive Exam Priority Override in `mapOnboarding4Candidates`**:
   - File: `lib/features/onboarding/steps/onboarding_step4_unified.dart`, lines 470–493:
     ```dart
     // Issue 32: Exam schedule priority override
     // If an exam overlaps with a regular class, remove the overlapping day(s) from the regular class.
     final resolvedBlocks = <ClassRoutineBlock>[];
     for (final block in blocks) {
       var currentRepeatDays = List<int>.from(block.repeatDays);
       final isExam = block.subject.toLowerCase().contains('exam');
       if (!isExam) {
         for (final other in blocks) {
           if (block.id == other.id) continue;
           final isOtherExam = other.subject.toLowerCase().contains('exam');
           if (isOtherExam) {
             final overlaps = block.startMinute < other.endMinute && block.endMinute > other.startMinute;
             if (overlaps) {
               currentRepeatDays.removeWhere((day) => other.repeatDays.contains(day));
             }
           }
         }
       }
       if (currentRepeatDays.isNotEmpty) {
         resolvedBlocks.add(
           block.copyWith(repeatDays: currentRepeatDays),
         );
       }
     }
     ```
   - Line 483 mutates `currentRepeatDays.removeWhere(...)`, removing repeat days permanently from regular class blocks when an exam overlaps. Line 488 drops the regular class block entirely if `currentRepeatDays.isEmpty`.

4. **Missing Onboarding Cross-Section Overlap Validation**:
   - File: `lib/features/onboarding/steps/onboarding_step4_unified.dart`: `OnboardingStep4Unified` writes directly to `draft.baseTimeline.blocks` without validating against Step 6 fixed sleep/bath blocks or Step 5 eating blocks.
   - File: `lib/services/onboarding_completion_service.dart`, lines 214–246: `_scheduleRoutineItems()` maps `baseBlocks` directly into `scheduled` without cross-checking hard block overlaps among base blocks.

---

## 2. Logic Chain

1. **Observation 1 → Test Unblock Needed**:
   - `test/group_g_issues_31_to_32_test.dart` cannot execute until `RoutineImportCandidateBlock` instantiations include `hardBlock: true` and `candidates` is explicitly typed as `List<RoutineImportCandidateBlock>`.

2. **Observation 2 → Root Cause for Issue 31**:
   - `RoutineConflictEngine.detect` uses `isAUnavailable || isBUnavailable` (OR logic).
   - This causes an overlap between a Class (`classBlock`) and a Soft Block (`eating`/Lunch or `habit`) to be categorized as `unavailableTime` with `blocking: true`.
   - `RoutineValidationService.validate()` sees `blocking == true` and marks validation invalid (`isValid: false`).
   - Changing `isAUnavailable || isBUnavailable` to `isAUnavailable && isBUnavailable` (AND logic) for `unavailableTime` correctly restricts blocking `unavailableTime` to conflicts between TWO strict hard/unavailable blocks (e.g. Class vs Class or Class vs Work).
   - An overlap between ONE strict hard block (Class) and ONE soft block (Lunch) will fall through to `timeOverlap` (`blocking: false`, `canKeepBoth: true`), allowing `RoutineValidationService.validate()` to return `isValid: true`.

3. **Observation 3 → Root Cause for Issue 32**:
   - `mapOnboarding4Candidates` mutates `repeatDays.removeWhere(...)` and drops regular class blocks when `currentRepeatDays.isEmpty`.
   - This permanently alters or deletes user class data in regular schedule templates.
   - To prevent data loss while preserving priority override: exam blocks must be assigned high priority (`hardBlock: true`, `mustDo`) and allowed to take precedence during date materialization/scheduling without destroying the underlying regular class template blocks in `resolvedBlocks`. Keyword recognition must also expand beyond `'exam'` to include `'midterm'`, `'final'`, `'quiz'`, `'test'`, `'assessment'`.

4. **Observation 4 → Onboarding Overlap Gap**:
   - Neither Step 4 nor `OnboardingCompletionService._scheduleRoutineItems()` validates base blocks against each other during onboarding creation. Adding cross-section validation or overlap resolution ensures onboarding draft blocks don't violate hard block constraints.

---

## 3. Caveats

- **No Source Modifications Made**: As an Explorer agent, no files in `lib/` or `test/` were modified.
- **Scope Limit**: Investigated Group G (Issues 31 & 32). Did not investigate Group A–F or Group H issues except where shared services (`RoutineValidationService`, `RoutineConflictEngine`, `OnboardingCompletionService`) intersect.

---

## 4. Conclusion

- **Issue 31 Root Cause**: `RoutineConflictEngine.detect()` incorrectly uses OR logic (`isAUnavailable || isBUnavailable`) instead of AND logic (`isAUnavailable && isBUnavailable`), causing Class vs Soft Block overlaps to be flagged as blocking `unavailableTime` conflicts instead of non-blocking `timeOverlap` warnings.
- **Issue 32 Root Cause**: `mapOnboarding4Candidates()` permanently strips `repeatDays` and deletes regular class blocks when exams overlap, causing user data loss. Recognition is also overly restricted to `'exam'`.
- **Test Fix Required**: Fix constructor arguments and type annotations in `test/group_g_issues_31_to_32_test.dart`.

---

## 5. Verification Method

1. **Fix & Run Test File**:
   - Command: `flutter test test/group_g_issues_31_to_32_test.dart`
   - Invalidation condition: Test fails to compile or fails expectations.
2. **Run Core Routine & Onboarding Test Suites**:
   - Command: `flutter test test/routine_conflict_engine_test.dart`
   - Command: `flutter test test/routine_validation_service_test.dart`
   - Command: `flutter test test/onboarding_step4_timeline_layout_test.dart`
   - Command: `flutter test test/onboarding_step6_fixed_schedule_test.dart`
3. **Files to Inspect**:
   - `lib/features/routine/services/routine_conflict_engine.dart`
   - `lib/features/onboarding/steps/onboarding_step4_unified.dart`
   - `test/group_g_issues_31_to_32_test.dart`
