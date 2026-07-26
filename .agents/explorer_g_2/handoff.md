# Handoff Report — Group G (Issues 31–32: Class Timetable Validation)

## 1. Observation

1. **File Locations & Inspected Source Code**:
   - `lib/features/routine/services/routine_conflict_engine.dart` (lines 94–106):
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
     and `_isUnavailableTime` (lines 261–268):
     ```dart
     static bool _isUnavailableTime(RoutineItem item) {
       return _isStrictHard(item);
     }
     static bool _isStrictHard(RoutineItem item) {
       return item.category == RoutineCategory.classBlock ||
           item.category == RoutineCategory.job;
     }
     ```
   - `lib/features/onboarding/steps/onboarding_step4_unified.dart` (lines 470–493):
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
   - `test/group_g_issues_31_to_32_test.dart` (lines 54–85):
     ```dart
     final candidates = [
       RoutineImportCandidateBlock(
         id: 'c1',
         title: 'Physics 101',
         category: 'classes',
         blockType: 'hard',
         startMinute: 10 * 60,
         endMinute: 11 * 60,
         hasFixedTime: true,
         repeatDays: [1],
       ),
       ...
     ```

2. **Terminal Execution Command & Verbatim Compilation Errors**:
   Command: `flutter test test/group_g_issues_31_to_32_test.dart`
   Output:
   ```
   test/group_g_issues_31_to_32_test.dart:55:36: Error: Required named parameter 'hardBlock' must be provided.
           RoutineImportCandidateBlock(
   test/group_g_issues_31_to_32_test.dart:65:36: Error: Required named parameter 'hardBlock' must be provided.
           RoutineImportCandidateBlock(
   test/group_g_issues_31_to_32_test.dart:75:36: Error: Required named parameter 'hardBlock' must be provided.
           RoutineImportCandidateBlock(
   test/group_g_issues_31_to_32_test.dart:88:21: Error: The argument type 'List<dynamic>' can't be assigned to the parameter type 'List<RoutineImportCandidateBlock>'.
   ```

---

## 2. Logic Chain

1. **Issue 31 (Class Timetable Overlap Classification Defect)**:
   - Observation 1 shows `_isUnavailableTime` returns `true` whenever `item.category == RoutineCategory.classBlock` or `job`.
   - In `RoutineConflictEngine.detect()`, `if (isAUnavailable || isBUnavailable)` uses logical OR.
   - When a Class block (hard block) overlaps with any soft block (e.g. Lunch/`eating` or a habit), `isAUnavailable` evaluates to `true`, causing the conflict to be classified as `unavailableTime` with `blocking: true`.
   - `RoutineValidationService.validate()` rejects candidate items with `blocking: true` as invalid (`isValid: false`), preventing soft routine blocks from co-existing alongside fixed class schedules.
   - Therefore, `isAUnavailable || isBUnavailable` must be refactored so that soft block vs hard block overlaps produce non-blocking `timeOverlap` (`blocking: false`, `canKeepBoth: true`), while hard block vs hard block overlaps produce `hardBlockConflict` or `unavailableTime` (`blocking: true`).

2. **Issue 32 (Destructive Exam Priority Override Defect)**:
   - Observation 1 shows `mapOnboarding4Candidates()` executes `currentRepeatDays.removeWhere((day) => other.repeatDays.contains(day))`.
   - If an exam takes place on a day when a class normally repeats, that weekday is permanently stripped from the class schedule template. If all repeat days overlap, the class is deleted from `resolvedBlocks`.
   - This causes permanent data loss in weekly timetable templates, violating zero-data-loss guidelines.
   - Furthermore, matching relies solely on `subject.toLowerCase().contains('exam')`, missing common terms like `midterm`, `final`, `quiz`, `test`, `assessment`.
   - Therefore, exam priority override must preserve class templates intact while establishing date-specific occurrence precedence for exams.

3. **Test Suite Compilation Failure**:
   - Observation 2 shows `test/group_g_issues_31_to_32_test.dart` fails to compile because `RoutineImportCandidateBlock` requires `hardBlock: bool`, which was omitted in the test file, and `candidates` was untyped.

---

## 3. Caveats

1. Network mode is `CODE_ONLY` — all investigation was conducted using local filesystem tools and local Dart/Flutter CLI.
2. `test/routine_conflict_engine_test.dart` and `test/routine_state_test.dart` currently contain assertions tied to the old conflict engine behavior. Updating `RoutineConflictEngine` will require updating these test files to maintain consistency across the test suite.

---

## 4. Conclusion

- **Issue 31 Root Cause**: `RoutineConflictEngine.detect` uses `isAUnavailable || isBUnavailable`, misclassifying Class vs Soft Block overlaps as blocking `unavailableTime` conflicts instead of non-blocking `timeOverlap` warnings.
- **Issue 32 Root Cause**: `mapOnboarding4Candidates` mutates `repeatDays` by removing exam collision days from regular class blocks, permanently destroying weekly class templates.
- **Test Blockers**: `test/group_g_issues_31_to_32_test.dart` requires `hardBlock: true` constructor arguments and explicit type annotations.

---

## 5. Verification Method

To independently verify all findings and validate the proposed implementation:

1. **Verify Test Compilation & Execution**:
   Run:
   `flutter test test/group_g_issues_31_to_32_test.dart`

2. **Inspect Relevant Code Sections**:
   - `lib/features/routine/services/routine_conflict_engine.dart` (lines 94–106)
   - `lib/features/onboarding/steps/onboarding_step4_unified.dart` (lines 470–493)
   - `lib/models/routine_import_review.dart` (lines 279–315)

3. **Verify Regression Test Suite**:
   Run:
   `flutter test test/routine_conflict_engine_test.dart`
   `flutter test test/routine_validation_service_test.dart`
   `flutter test test/routine_state_test.dart`
