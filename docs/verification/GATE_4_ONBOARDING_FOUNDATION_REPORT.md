# Gate 4 Onboarding Foundation — Completion Report

## A. Current source checkout

- Repository: `Optivus`
- Branch: `main`
- Base revision verified: `fb57d7a` (`gate 4`)
- Verification date: 2026-09-08
- Scope: onboarding foundation/read compatibility only
- Firestore shape or rules changed: **No**
- Worker changes: **None**
- R2 changes: **None**
- Auth architecture, Step 4/5/7 UX, Step 14 completion semantics, and Routine
  production behavior changed: **No**

## B. Gate 4 requirements 1–9

| Requirement | Result | Current-source evidence |
|---|---|---|
| 1. Repair 12→15 migration | PASS | One document-level `PersistedOnboardingStepLayout` decision controls `currentStep`, `stepCompleted`, `stepDirty`, and `stepLoading`; only clear legacy data is semantically migrated. |
| 2. Test partial legacy migration | PASS | Partial completed, dirty, and loading vectors plus malformed/mixed/round-trip cases are covered in `onboarding_step_layout_migration_test.dart`. |
| 3. Introduce semantic step IDs | PASS | `OnboardingStepId`, `currentOnboardingStepOrder`, semantic page construction/readiness/ownership, and explicit legacy mapping are active. Steps 1–3 no longer mutate numeric literals. |
| 4. Rename Steps 8–14 files/classes | PASS | Current files and widget classes use product position and semantic names; no stale production class aliases remain. |
| 5. Remove unused `validateForRole` | PASS | Repository-wide search has zero `BaseTimelineDraft.validateForRole` declarations or calls; active specific validators remain. |
| 6. Extract live Step 4 ownership | PASS | `onboarding_step_4_schedule_models.dart` owns the shared models/providers; `onboarding_step4_unified.dart` owns current UI. |
| 7. Remove confirmed dead Step 4/14 code | PASS | The old split Step 4 widget/file, `_showLegacyEditDialog`, unused unified day-chip/parser chain, Step 14 attention/conflict UI chain, and unused role validator are removed. |
| 8. Normalize evidence-backed legacy values on read | PASS | Meal goal and exercise aliases are canonicalized in `fromMap`; current values survive and unknown values become `null`. |
| 9. Classify remaining compatibility | PASS | G4-C01–G4-C14 were rechecked against current symbols and are classified below with owner and removal condition. |

## C. Persisted-layout decision table

Data schema and page topology are separate contracts. Detection evaluates all
three progression vectors once for the whole document.

| Evidence | Decision | Read behavior | Result |
|---|---|---|---|
| schema v1 + 12 vector | `legacy12` | Explicit old identity → current identity mapping | PASS |
| missing schema + clear 12 vector | `legacy12` | Explicit semantic migration | PASS |
| schema v2 + 15 vector | `current15` | Preserve numeric meaning | PASS |
| schema v2 + exact 12 vector | `ambiguous` | Preserve positions; pad 12–14 false; no fan-out | PASS |
| schema v2 + short vector | `ambiguous` | Preserve positions; pad false | PASS |
| schema v3/current + exact 12 vector | `current15` | Preserve positions; pad 12–14 false | PASS |
| schema v3/current + other short vector | `current15` | Preserve positions; pad false | PASS |
| mixed 15/12 vectors | `ambiguous` | One fail-safe positional interpretation | PASS |
| no usable topology evidence | `ambiguous` | Clamp `currentStep`; normalize vectors to 15 | PASS |

Ambiguous data is not shifted. `validateOnboardingResume()` and
`durableOnboardingResumeStep()` remain the final monotonic resume authority.
Serialization writes current schema v3 and 15 positions, making the next read
unequivocally current.

## D. Legacy12 → Current15 mapping

| Legacy index / identity | Current index / `OnboardingStepId` | Completion-vector handling |
|---|---|---|
| 0 Welcome | 0 `welcome` | Direct |
| 1 Patience | 1 `patience` | Direct |
| 2 Role / Lifestyle | 2 `roleLifestyle` | Direct |
| 3 Body Basics | 3 `bodyBasics` | Direct |
| 4 combined Base Timeline | 4 `classesJob` | Maps directly and, when completed, fans out completion to 5 `eating`, 6 `fixedSchedule`, and 7 `skinCare` |
| 5 Bad Habits | 8 `badHabits` | Explicit semantic map |
| 6 Good Habits | 9 `goodHabits` | Explicit semantic map |
| 7 Identity Goals | 10 `identityGoals` | Explicit semantic map |
| 8 Coach Setup | 11 `coachSetup` | Explicit semantic map |
| 9 Slip-up | 12 `slipUp` | Explicit semantic map |
| 10 Notifications | 13 `notifications` | Explicit semantic map |
| 11 Today Ready | 14 `todayReady` | Explicit semantic map |

No `+3` arithmetic migration is used.

## E. Required migration matrix

| Case | Result |
|---|---|
| schema1 + 12 vector | PASS |
| missing schema + 12 vector | PASS |
| schema2 + 15 vector | PASS |
| schema2 + 12 vector | PASS |
| schema2 + short partial vector | PASS |
| schema3 + 12 vector | PASS |
| schema3 + short vector | PASS |
| mixed 15/12 vectors | PASS |
| legacy partial dirty | PASS |
| legacy partial loading | PASS |
| invalid `currentStep` | PASS |
| string `currentStep` | PASS |
| legacy round-trip | PASS |
| ambiguous schema2 round-trip | PASS |
| modern round-trip | PASS |
| completed legacy user | PASS |

## F. Semantic step registry

The one current order is:

`welcome → patience → roleLifestyle → bodyBasics → classesJob → eating →`
`fixedSchedule → skinCare → badHabits → goodHabits → identityGoals →`
`coachSetup → slipUp → notifications → todayReady`

`OnboardingDraft.stepCount`, the page factory, readiness definitions, CTA
ownership, navigation, and Step-owned mutations are checked against that
registry. Production ownership searches found no numeric literals in
`setStepDirty`, `setStepLoading`, `setStepCompleted`, `validateStep`, or
`onJumpToStep` calls.

## G. Step files and classes renamed

| Current file | Current class |
|---|---|
| `onboarding_step_8_bad_habits.dart` | `OnboardingBadHabitsStep` |
| `onboarding_step_9_good_habits.dart` | `OnboardingGoodHabitsStep` |
| `onboarding_step_10_identity_goals.dart` | `OnboardingIdentityGoalsStep` |
| `onboarding_step_11_coach_setup.dart` | `OnboardingCoachSetupStep` |
| `onboarding_step_12_slip_up.dart` | `OnboardingSlipUpStep` |
| `onboarding_step_13_notifications.dart` | `OnboardingNotificationsStep` |
| `onboarding_step_14_today_ready.dart` | `OnboardingTodayReadyStep` |

## H. Step 4 extraction and deletion

The current source audit found zero `OnboardingClassSetupWidget`
instantiations. Seven regression-test families imported the old file only to
obtain its re-exported `ClassRoutineBlock`, `ScheduleSetupConfig`, and class/work
timeline providers. Those imports now point directly to
`onboarding_step_4_schedule_models.dart`.

`onboarding_class_setup_timeline.dart` was then deleted. A static regression
test proves both that the file is absent and that no Dart file under `lib/` or
`test/` imports the old path.

## I. Dead code removed

- `BaseTimelineDraft.validateForRole` (zero callers; active specific validators
  retained)
- split `OnboardingClassSetupWidget` and its old 1,700-line file
- unified Step 4 `_showLegacyEditDialog`
- unused unified Step 4 day-chip and clock-parser chain
- Step 14 `_buildAttentionSection` and its unreachable legacy conflict-action
  UI chain

No active Step 4 edit adapter or Step 14 completion path was removed.

## J. Legacy-value normalization

| Persisted field | Historical values | Canonical value |
|---|---|---|
| `mealPlanningGoal` | `gain_weight`, `build_muscle`, `muscle_gain` | `gain` |
| `mealPlanningGoal` | `lose_fat`, `fat_loss`, `weight_loss` | `lose` |
| `mealPlanningGoal` | `maintenance`, `eat_healthier`, `balanced` | `maintain` |
| `exerciseLevel` | `low`, `sedentary` | `rarely` |
| `exerciseLevel` | `medium`, `moderate` | `3_4_days` |
| `exerciseLevel` | `high`, `active` | `5_plus_days` |

Current values are unchanged. Unknown enum-like values deserialize to `null` so
validation remains authoritative. No free-form text is normalized. Searches of
fixtures, tests, current normalizers, migration comments, and current docs found
no additional evidence-backed persisted aliases.

## K. Current compatibility inventory

“New writes” below means canonical product persistence introduced after this
gate; reader-only fields may still exist in memory while an old document is
being handled.

| Compat ID | Current symbol/path | Category | Actual read/write path | New writes use it? | Current reason and removal condition | Test owner |
|---|---|---|---|---|---|---|
| G4-C01 | `OnboardingDraft._detectPersistedStepLayout`, `_migrateLegacyStepBoolList` | REQUIRED_READER | `OnboardingDraft.fromMap` | No | Reads clear historical 12-page progression. Remove only after supported-data retention proves no legacy draft remains. | Gate 4 migration suite |
| G4-C02 | `BaseTimelineDraft.acceptedConflictKeys` | REQUIRED_READER | `BaseTimelineDraft.fromMap`; excluded from `toMap` | No | Reads schema-v2 schedule-unbound acceptances. Remove after supported drafts use typed `conflictAcceptances` and migration telemetry is zero. | AH-F015 durable overlap suite |
| G4-C03 | `isLegacyGeneratedEatingPlan` | REQUIRED_READER | Eating draft validation/read | No | Detects obsolete generated-plan shapes and forces safe regeneration. Remove after all supported drafts carry the current generated-plan version/fingerprint. | Gate 2 weekly-plan suite |
| G4-C04 | goal/exercise alias normalizers | REQUIRED_READER | `BaseTimelineDraft.fromMap`, `LifeRoleDraft.fromMap` | No | Canonicalizes repository-evidenced aliases. Remove only after the supported retention window contains canonical values exclusively. | Gate 4 migration suite |
| G4-C05 | exact-identity Skin Care upload migration | REQUIRED_READER | Skin Care upload/draft reconciliation | No | Restores only the established owned legacy upload slot. Remove after legacy upload metadata leaves support. | Gate 3 upload/Step 7 suites |
| G4-C06 | `legacyOnboardingRunId`, `matchesOnboardingRunIdentity` | REQUIRED_READER | Completion run verification | No | Accepts pre-stable run identity without using it for new attempts. Remove when no incomplete/retryable legacy run can remain. | Gate 1 retry/idempotency suites |
| G4-C07 | fixed completion-job document fallback | REQUIRED_READER | `OnboardingCompletionJobService._loadCurrentRunSnapshot` | No | Server-reads the historical fixed job only when no `currentRun` pointer exists. Remove when no recoverable fixed-job document remains. | Gate 1 terminalization suite |
| G4-C08 | interrupted micro-checkpoint recovery | REQUIRED_READER | Completion-job resume/final receipt verification | No | Resumes jobs stored at historical intermediate stages. Remove when supported jobs cannot contain those stages. | Gate 1 completion stress suites |
| G4-C09 | `durableOnboardingResumeStep` compatibility name | TEMPORARY_BRIDGE | Active in-process callers delegate to `validateOnboardingResume` | No | Keeps existing callers on the canonical result. Remove in a separately authorized caller cleanup. | Resume monotonicity/session suites |
| G4-C10 | former split Step 4 widget/path | DEAD_REMOVED | None | No | Tests used only re-exported current model symbols; imports were redirected and the file was deleted. Static test prevents resurrection. | Gate 4 migration suite |
| G4-C11 | deprecated completion stage/status/recovery aliases | TEMPORARY_BRIDGE | Source/in-memory compatibility; canonical serialization remains current | No | Keeps pre-current callers/documents readable. Remove after all supported callers/data use canonical cases. | Gate 1 bundle/terminalization suites |
| G4-C12 | legacy `:` conflict-key parser | REQUIRED_READER | `TimelineConflict.blockIdsForKey` read path | No | Reads pre-canonical conflict keys; current keys use encoded `|` form. Remove after no supported draft contains legacy keys. | AH-F015 durable overlap suite |
| G4-C13 | former legacy dialog/day chip/attention UI/role validator | DEAD_REMOVED | None | No | Source-proven zero-caller code removed during Gate 4. | Static audit plus focused Step 4/14 suites |
| G4-C14 | Auth migration/status, generic AI-card, Routine/Worker compatibility | OUT_OF_SCOPE | Non-Gate-4 owners | No | No Gate 4 writer uses these paths. Re-audit only in an owner-specific authorized phase. | Owning Auth/Routine/Worker suites |

## L. Focused verification results

| Matrix | Command coverage | Result |
|---|---|---|
| Migration/resume | Four required migration, persistence, restore, and monotonicity files | PASS — 82 passed |
| Step 4 | Eight required Step 4/UX/foundation/Group G files | PASS — 217 passed |
| Foundation | Routing, session destination, final pass, challenger | PASS — 89 passed |
| Gate 2 / Eating | All current focused nutrition, weekly-plan, and Step 5 files | PASS — 80 passed |
| Gate 3 / Step 7 | State, transaction, CTA, pending-photo, runtime, full-timeline, main and P0 migration | PASS — 227 passed |
| Gate 1 / Step 14 | Terminalization, idempotency, bundle, retry, final-review and completion stress | PASS — 124 passed, 10 intentionally skipped legacy conflict-decision UI cases |

Focused total: **819 passed, 10 skipped, 0 failed**.

Commands actually run (files on each line were executed together as one Flutter
test process):

```text
flutter test --reporter compact test/onboarding_step_layout_migration_test.dart test/onboarding_persistence_phase2b_test.dart test/onboarding_restore_test.dart test/ah_f012_onboarding_resume_monotonicity_test.dart
flutter test --reporter compact test/onboarding_step4_ai_flow_test.dart test/onboarding_step4_role_change_test.dart test/onboarding_step4_timeline_layout_test.dart test/features/onboarding/onboarding_step4_step5_ux_closure_test.dart test/ah_f018_timeline_foundation_test.dart test/group_g_adversarial_test.dart test/group_g_adversarial_stress_test.dart test/group_g_issues_31_to_32_test.dart
flutter test --reporter compact test/onboarding_routing_test.dart test/onboarding_session_destination_test.dart test/onboarding_foundation_final_pass_test.dart test/challenger_p46_m3_1_adversarial_test.dart
flutter test --reporter compact test/nutrition_target_service_test.dart test/onboarding_eating_weekly_plan_test.dart test/onboarding_step5_all_dishes_mapping_test.dart test/onboarding_step5_eating_ai_flow_test.dart test/onboarding_step5_error_mapping_test.dart test/onboarding_step5_generated_no_fake_fallback_test.dart test/onboarding_step5_local_timeline_lens_overlap_test.dart test/onboarding_step5_regeneration_test.dart test/onboarding_step5_save_test.dart test/onboarding_step5_short_meal_timeline_alignment_test.dart test/onboarding_step5_worker_error_mapping_test.dart
flutter test --reporter compact test/onboarding_step7_state_machine_test.dart test/onboarding_step7_transaction_test.dart test/onboarding_step7_cta_navigation_test.dart test/onboarding_step7_pending_photo_generation_test.dart test/onboarding_step7_runtime_ui_stability_test.dart test/onboarding_step7_full_timeline_regression_test.dart test/onboarding_step7_skin_care_test.dart test/onboarding_step7_p0_migration_test.dart
flutter test --reporter compact test/ah_f013_completion_terminalization_test.dart test/ah_f014_step14_idempotency_test.dart test/ah_f021_step14_final_review_test.dart test/onboarding_completion_bundle_test.dart test/onboarding_completion_group_a_test.dart test/onboarding_completion_group_a_stress_test.dart test/onboarding_completion_retry_contract_test.dart
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --reporter compact
git diff --check
```

## M. Full Flutter test result

`flutter test --reporter compact`

**PASS — 1,944 passed, 10 skipped, 0 failed (57 seconds).** The ten skips are
the explicitly disabled AH-F021 legacy onboarding conflict-decision UI group;
conflicts are advisory in Routine under the current contract.

## N. Static analysis and formatting

- `flutter analyze`: **PASS — no issues found (4.6 seconds).**
- `git diff --check`: **PASS.**
- Static architecture searches: **PASS** for deleted Step 4 path, removed dead
  symbols, current renamed paths/classes, single registry/order, and semantic
  production step ownership.
- `dart format --output=none --set-exit-if-changed .`: **NON-GREEN BASELINE
  CHECK — 39 tracked files would be reformatted.** The command made no writes.
  The listed debt includes unrelated Auth, Routine, core widgets, and tests that
  were not changed for this bounded gate. Gate 4 does not mass-format those
  frozen/out-of-scope files. Analyzer and all tests remain green.

## O. Gate 1 regression result

**PASS.** The focused completion matrix passed 124 tests (10 intentional legacy
UI skips), and the full suite passed. No completion persistence, stage,
`currentRun`, Firestore, or session-destination behavior was changed.

## P. Gate 2 regression result

**PASS.** All current focused nutrition/Eating/Step 5 suites passed 80 tests,
and the full suite passed. Generated-plan behavior was not changed.

## Q. Gate 3 regression result

**PASS.** Current Step 7 state-machine, transaction, CTA, pending-photo,
runtime, timeline, main, and migration suites passed 227 tests, and the full
suite passed. Skin Care behavior was not changed.

## R. Final verdict

| Required final item | Result |
|---|---|
| 1. 12→15 step migration | PASS |
| 2. partial legacy migration tests | PASS |
| 3. semantic step IDs | PASS |
| 4. Steps 8–14 files/classes renamed | PASS |
| 5. unused `validateForRole` removed | PASS |
| 6. live Step-4 code extracted from legacy file | PASS |
| 7. confirmed dead Step-4/14 code removed | PASS |
| 8. evidence-backed legacy values normalized during deserialization | PASS |
| 9. remaining compatibility code classified | PASS |
| Gate 1 regressions | PASS |
| Gate 2 regressions | PASS |
| Gate 3 regressions | PASS |
| Full Flutter suite | PASS |
| Flutter analyze | PASS |

**GATE 4 PASSED**

This is the Gate 4 implementation verdict only. Per the repository phase rule,
Routine remains blocked until a separate read-only verification returns the
required Routine-readiness verdict.

## Files inspected

The implementation pass inspected the repository instructions, strict task
rules, architecture, navigation, product blueprint, data-source guide,
technical-debt register, and current Gate 1–4 verification reports. Source
inspection covered `onboarding_step_id.dart`, `onboarding_flow.dart`,
`onboarding_step_readiness.dart`, `onboarding_draft.dart`, nutrition and resume
services, completion identity/job/service models, repositories/path helpers,
the onboarding step barrel, every top-level Step 0–14 file, all Step 7 Skin Care
subfiles, Step 4 timeline adapters/models/providers, and current Auth onboarding
integration. Test inspection covered the migration/persistence/restore suites,
every former old-Step-4 import, all requested Gate 1/2/3/foundation suites, and
legacy fixtures/normalizer/static-architecture assertions.

## Files changed and why

Gate 4 changed the semantic registry/order, draft topology reader and alias
normalizers, current flow/readiness/step ownership, Step 4 model ownership,
Steps 8–14 filenames/classes, dead Step 4/14 code, imports/tests, and the
architecture/blueprint/evidence documentation. The final closure addendum
specifically changed Steps 1–3 ownership, schema-v2 ambiguous precedence,
former Step 4 test imports/deletion, static migration coverage, and this report.

## Remaining compatibility debt

G4-C01–C09, C11–C12 remain intentionally bounded readers/bridges with explicit
removal conditions. G4-C14 remains owner-scoped and unchanged. The repository's
39-file formatting baseline is recorded above; changing it is unrelated cleanup
and was not authorized by Gate 4.
