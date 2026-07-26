# Handoff Report — Reviewer 1 (Group G: Issues 31–32)

## 1. Observation

### Build and Test Commands & Output
- Static Analysis: `flutter analyze`
  - Output: 2 issues total in unrelated files (`lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart:1386:7` and `lib/services/skin_care_ai_client.dart:450:68`).
  - **0 errors or warnings in Group G files** (`lib/features/routine/services/routine_conflict_engine.dart`, `lib/features/onboarding/steps/onboarding_step4_unified.dart`, `test/group_g_issues_31_to_32_test.dart`).
- Group G Unit Test Suite: `flutter test test/group_g_issues_31_to_32_test.dart`
  - Output: All 20 tests passed (`00:20 +20: All tests passed!`).

### Code Inspection Details

#### Issue 31: `lib/features/routine/services/routine_conflict_engine.dart`
- Lines 85–106:
```dart
          final isAUnavailable = _isUnavailableTime(a);
          final isBUnavailable = _isUnavailableTime(b);
          final isASleep = _isSleep(a);
          final isBSleep = _isSleep(b);

          RoutineConflictType conflictType = RoutineConflictType.timeOverlap;
          bool blocking = false;
          bool canKeepBoth = true;

          if (isAUnavailable && isBUnavailable) {
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
            canKeepBoth = false; // Two hard blocks cannot be kept together
          }
```
- Lines 261–268:
```dart
  static bool _isUnavailableTime(RoutineItem item) {
    return _isStrictHard(item);
  }

  static bool _isStrictHard(RoutineItem item) {
    return item.category == RoutineCategory.classBlock ||
        item.category == RoutineCategory.job;
  }
```

#### Issue 32: `lib/features/onboarding/steps/onboarding_step4_unified.dart`
- Lines 408–412:
```dart
bool isExamCandidateTitle(String title) {
  final lower = title.toLowerCase();
  const keywords = ['exam', 'midterm', 'final', 'quiz', 'test', 'assessment'];
  return keywords.any((k) => lower.contains(k));
}
```
- Lines 461–489:
```dart
    final isExam = isExamCandidateTitle(title);
    final effectiveCandidate = isExam
        ? candidate.copyWith(
            hardBlock: true,
            blockType: TimelineBlockDraft.hardBlockKey,
          )
        : candidate;

    blocks.add(
      ClassRoutineBlock(
        id: effectiveCandidate.id,
        subject: title,
        room:
            extractRoomLabelFromOnboarding4Candidate(effectiveCandidate) ?? '',
        startMinute: effectiveCandidate.startMinute.clamp(0, 24 * 60 - 1),
        endMinute: effectiveCandidate.endMinute.clamp(1, 24 * 60),
        repeatDays: repeatDays,
        icon: config.icon,
        color: config.colorCycle[blocks.length % config.colorCycle.length],
        hasTopTape: true,
        hasBottomTape: true,
      ),
    );
  }

  // Issue 32: Exam schedule priority override
  // Regular class schedule templates are kept intact in resolvedBlocks without mutating or stripping repeatDays.
  // Exam blocks take precedence during date materialization/scheduling as hard blocks with mustDo priority.
  final resolvedBlocks = List<ClassRoutineBlock>.unmodifiable(blocks);
```

---

## 2. Logic Chain

1. **Issue 31 Logic Chain**:
   - `_isUnavailableTime(item)` evaluates whether an item is a strict hard block (`classBlock` or `job`).
   - When detecting overlaps in `RoutineConflictEngine.detect`, `isAUnavailable && isBUnavailable` checks if BOTH items are strict hard/unavailable blocks.
   - If both are strict hard blocks, `unavailableTime` conflict with `blocking: true` and `canKeepBoth: false` is emitted.
   - If only one item is a strict hard block (e.g. `classBlock`) and the other is a soft block (e.g. `eating` or `habit`), `isAUnavailable && isBUnavailable` evaluates to `false`. Furthermore, `a.isHardBlock && b.isHardBlock` evaluates to `false` because the soft block has `isHardBlock = false`.
   - As a result, single hard vs soft overlaps correctly fall through to `RoutineConflictType.timeOverlap` with `blocking: false` and `canKeepBoth: true`.
   - `RoutineValidationService.validate` checks `conflicts.any((c) => c.blocking)`, which evaluates to `false`, allowing `result.isValid` to return `true`.

2. **Issue 32 Logic Chain**:
   - In `onboarding_step4_unified.dart`, candidate import is processed by `mapOnboarding4Candidates`.
   - `isExamCandidateTitle(title)` converts title to lowercase and checks against keywords `['exam', 'midterm', 'final', 'quiz', 'test', 'assessment']`.
   - Candidates matching exam keywords are cloned with `hardBlock: true` and `blockType: TimelineBlockDraft.hardBlockKey`.
   - Regular class blocks are appended alongside exam candidate blocks in `blocks` without deleting or modifying `repeatDays` (rule R11 data preservation).
   - `resolvedBlocks` returns all blocks unmodifiable, preserving all regular class schedule templates while marking exam candidate blocks as hard blocks.

3. **Integrity & Verification Chain**:
   - Checked for integrity violations (hardcoded test results, facade implementations, test bypasses). None found. All logic is dynamically computed.
   - Ran `flutter test test/group_g_issues_31_to_32_test.dart` and confirmed all 20 tests pass cleanly.

---

## 3. Caveats

No caveats for Group G files. (Note: `flutter analyze` reported 2 linter info/warnings in unrelated files outside Group G scope: `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart` and `lib/services/skin_care_ai_client.dart`).

---

## 4. Conclusion

**Verdict**: **APPROVE**

The changes for Group G (Issues 31–32) are correct, fully verified, free of integrity violations, and conform strictly to design requirements.

---

## 5. Verification Method

To independently verify this review:
1. Run `flutter analyze` in the workspace root. Confirm 0 errors/warnings in Group G files.
2. Run `flutter test test/group_g_issues_31_to_32_test.dart`. Confirm 20/20 tests pass.
3. Inspect `lib/features/routine/services/routine_conflict_engine.dart` lines 94–106 & 261–268 for strict dual-unavailable condition.
4. Inspect `lib/features/onboarding/steps/onboarding_step4_unified.dart` lines 408–489 for expanded exam keywords and non-destructive candidate block mapping.
