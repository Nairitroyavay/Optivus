# Gate 4 Onboarding Foundation — Completion Report

## A. Current source checkout

- Repository: `Optivus`
- Branch: `main`
- Base revision verified: `2482052` (`gate 4`)
- Verification date: 2026-09-09
- Current verification tree: base revision plus concurrent, uncommitted Gate 5
  Auth/session work; those unrelated edits were preserved
- Scope: onboarding foundation/read compatibility and durable restore
- Firestore shape or rules changed: **Yes** — updated to enforce schemaVersion == 4 and stepCompletionContractVersions (List of 15 ints, all values == 1 i.e. `toSet().hasOnly([1])`)
- Worker changes: **None**
- R2 changes: **None**
- Auth architecture, Step 4/5/7 UX, Step 14 completion semantics, and Routine
  production behavior changed: **No**

## B. Gate 4 requirements 1–10

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
| 9. Classify remaining compatibility | PASS | G4-C01–G4-C16 were rechecked against current symbols and are classified below with owner and removal condition. G4-C15 (`onboarding_repositories.dart`) and G4-C16 (`MigrateLegacySetupAction`) are classified as `DEAD_REMOVED` with static architecture test enforcement. |
| 10. Restore Foundation & Monotonicity Invariants | PASS | Step 0–13 restore matrix proves each step N restores to N+1; Step 14 completes to Home; incomplete/corrupt drafts rewind monotonically to the earliest invalid step; write-time invalidation clears downstream steps on upstream changes; and upload hydration fetches referenced assets older than 100 recent uploads. Covered by `onboarding_foundation_restore_matrix_test.dart` (30/30 passed). |

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
| schema v3/v4/current + exact 12 vector | `current15` | Preserve positions; pad 12–14 false | PASS |
| schema v3/v4/current + other short vector | `current15` | Preserve positions; pad false | PASS |
| mixed 15/12 vectors | `ambiguous` | One fail-safe positional interpretation | PASS |
| no usable topology evidence | `ambiguous` | Clamp `currentStep`; normalize vectors to 15 | PASS |

Ambiguous data is not shifted. `validateOnboardingResume()` and
`durableOnboardingResumeStep()` remain the final monotonic resume authority.
Serialization writes current schema v4, `stepCompletionContractVersions` (length 15),
and 15 positions, making the next read unequivocally current.

## D. Legacy12 → Current15 mapping

| Legacy index / identity | Current index / `OnboardingStepId` | Completion-vector handling |
|---|---|---|
| 0 Welcome | 0 `welcome` | Direct |
| 1 Patience | 1 `patience` | Direct |
| 2 Role / Lifestyle | 2 `roleLifestyle` | Direct |
| 3 Body Basics | 3 `bodyBasics` | Direct |
| 4 combined Base Timeline | 4 `classesJob` | Maps directly. Completed flags for 5 `eating`, 6 `fixedSchedule`, and 7 `skinCare` are derived independently from persisted evidence (nutrition target/eating plan, fixed schedule blocks, skin care routine/products), avoiding blind completion fan-out |
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
| modern round-trip (schema4) | PASS |
| schema4 completion without receipt | PASS |
| schema4 invalid receipt version | PASS |
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
| G4-C01 | `OnboardingDraft._detectPersistedStepLayout`, `_migrateLegacyStepCompleted`, `_migrateLegacyStepDirty`, `_readStepCompletionContractVersions`, `_readStepLoading` | REQUIRED_READER | `OnboardingDraft.fromMap` | No | Reads clear historical 12-page progression, independently deriving completion from persisted evidence without blind fan-out. Remove only after supported-data retention proves no legacy draft remains. | Gate 4 migration suite |
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
| G4-C15 | former `lib/repositories/onboarding_repositories.dart` | DEAD_REMOVED | None | No | Duplicate onboarding repository deleted in commit `3b78db8`; canonical active owner is `lib/repositories/onboarding_repository.dart`. Static architecture test ensures file is absent with zero imports. | Gate 4 static architecture test |
| G4-C16 | `MigrateLegacySetupAction` / `migrate_legacy_setup` | DEAD_REMOVED | None | No | Real supported 12→15 migration is owned by `OnboardingDraft.fromMap`; the recovery action had zero callers and unconditionally threw `StateError`. Deleted in Fourth Closure pass; static architecture test ensures zero occurrences in active source. | Gate 4 static architecture test |

## K2. Restore Foundation Architecture & Monotonicity Invariants

### 1. Critical Invariant
Once an onboarding step has been durably completed, app kill/reopen, logout/login, reinstall/login on the same account, or app upgrade must restore to the correct first genuinely unfinished onboarding step. An older validator, missing local cache, recent-uploads limits, or arbitrary `currentStep` must never rewind onboarding.

### 2. Separation of Concerns
- **Deserialization (`OnboardingDraft.fromMap`)**: Owns layout topology interpretation (legacy 12 vs current 15) and field deserialization. It preserves raw completion flags and does not perform async queries or discard valid persisted data.
- **Monotonic Resume Authority (`validateOnboardingResume` & `validateDurableStepRestore`)**: Pure, synchronous, non-destructive evaluation of draft validity from step 0 through 14. A step must have both a durable save acknowledgement (`stepCompleted[step] == true`) and satisfy `validateDurableStepRestore(step, draft) == null`. Evaluation inspects steps strictly in order, guaranteeing that any corrupted step or hole rewinds monotonically to the earliest invalid step.

### 3. Step 0–13 Restore Matrix & Step 14 Destination
- Steps 0 through 13: Completing Step N durably restores to Step N+1 across all supported paths (e.g. Step 5 eating via skip, photo import, or generated plan; Step 7 skin care via skip or products routine).
- Step 14: When `onboardingCompleted: true`, `resolveSessionDestination` returns `SessionDestination.home`. If incomplete, it returns `SessionDestination.resumeOnboarding(step: 14)`.
- Obsolete Eating Plan Quarantine: Obsolete legacy weekly eating plans trigger `isLegacyGeneratedEatingPlan(baseTimeline)` and safely return `'step_5_migration_required'`, safely resuming at Step 5 without crash or data loss.

### 4. Downstream Invalidation Policy
Write-time dependency invalidation (`invalidateDownstreamDependencies`) ensures modifications to upstream decisions invalidate dependent downstream steps:
- Editing Step 2 (life role) invalidates Step 4 (classes/work), Step 5 (eating), and Step 14 (final review/completion).
- Editing Step 3 (body basics) invalidates Step 5 (eating) and Step 14.
- Editing Step 6 (fixed schedule) invalidates Step 14.
- Editing Step 7 (skin care) invalidates Step 14.
Wired directly into `OnboardingNotifier.updateDraft` and `saveStep`.

### 5. Upload Reconciler & Exact Asset Hydration Beyond 100 Recent Uploads
- `RestoredUploadsController.hydrate` accepts optional `requiredAssetIds` (derived from `draft.referencedUploadAssetIds`) to fetch exact asset references even when they fall outside the 100 most recent account uploads.
- `OnboardingUploadSourceReconciler` matches assets using `getValidAssetForExactId` prior to falling back to latest purpose resolution, preventing newer unrelated uploads from invalidating completed steps.

### 6. Cold Restart Idempotency & User Isolation
- On initial cold start, if reconciliation alters the draft (`changed == true`), the reconciled draft is saved to durable persistence (`saveDraft`). Subsequent restarts are idempotent (`changed == false`).
- On sign-out, `resetForSignedOut` clears all draft and reconciliation state, enforcing strict user isolation across accounts.

## Semantic ownership static audit

The 2026-09-09 active-source scan covers `lib/features/onboarding/`,
`lib/services/onboarding_*`, `lib/features/recovery/`, `app_state.dart`,
`auth_state.dart`, and `lib/models/onboarding*.dart`. It distinguishes semantic
page ownership from generic index arithmetic, persisted migration fixtures,
timeline/weekday values, layout values, and nested setup substeps.

| Static acceptance item | Current result |
|---|---|
| Raw semantic progression-vector writes | 0 |
| Raw semantic `validateStep` calls | 0 |
| Raw shell `currentPage == 0/14` comparisons | 0 |
| Old Step 4 split file | ABSENT |
| Duplicate legacy onboarding repository | ABSENT |
| `BaseTimelineDraft.validateForRole` | ABSENT |
| Old Steps 8–14 filenames | 0 |
| Old Steps 8–14 widget classes | 0 |
| Unclassified onboarding compatibility paths | 0 |
| `OnboardingStepId` registry definitions | 1 |
| `currentOnboardingStepOrder` definitions | 1 |

The static regression in `onboarding_step_layout_migration_test.dart` protects
the same boundaries, including deleted-file/import paths and the removed
always-throwing legacy migration action.

## L. Focused verification results

| Matrix | Command coverage | Result |
|---|---|---|
| Gate-4 Focused Suite | Ten required migration, persistence, restore, routing, session, monotonicity, final pass, challenger, upload reconciler, and restore matrix files (`onboarding_foundation_restore_matrix_test.dart`, etc.) | PASS — 241 passed |
| Recovery regressions | Five required recovery, resilience, and adversarial stress files (`group_h_*`, `group_k_*`, `challenger_p46_*`, `completion_group_a`) | PASS — 91 passed |
| Step 4 regressions | Five required Step 4/UX/foundation files (`step4_ai_flow`, `role_change`, `timeline_layout`, `ux_closure`, `ah_f018`) | PASS — 118 passed |
| Gate 2 / Eating | All eleven current focused nutrition, weekly-plan, and Step 5 files | PASS — 80 passed |
| Gate 3 / Step 7 | State machine, transaction, CTA, pending-photo, runtime, full-timeline, skin care, and P0 migration files | PASS — 227 passed |
| Gate 1 / Step 14 | Terminalization, idempotency, bundle, retry, final-review, and completion stress files | PASS — 108 passed, 10 intentionally skipped legacy conflict-decision UI cases |

Focused total: **865 passed, 10 skipped, 0 failed**.

### 2026-09-09 current-working-tree rerun

The full Gate 4 / Restore Foundation suite was re-executed against the current working tree:

| Matrix | Fresh result |
|---|---|
| Gate 4 restore matrix (`onboarding_foundation_restore_matrix_test.dart`) | PASS — 30 passed |
| Gate 4 architecture + upload reconciliation + AH-F010 restore-upload | PASS — 104 passed |
| Required migration/foundation files (`onboarding_step_layout_migration_test.dart`, `onboarding_restore_test.dart`, etc.) | PASS — 172 passed |
| Recovery/adversarial regressions | PASS — 91 passed |
| Required recovery/completion regressions | PASS — 100 passed, 10 intentional skips |
| Step 4 regressions | PASS — 118 passed |
| Gate 2 / Eating | PASS — 80 passed |
| Gate 3 / Step 7 | PASS — 227 passed |

Gate-4-owned focused failures are **0**.

Fresh commands actually run:

```text
flutter test --reporter compact test/onboarding_foundation_restore_matrix_test.dart test/onboarding_step_layout_migration_test.dart test/ah_f007_server_reconstruction_test.dart test/onboarding_restore_test.dart test/ah_f012_onboarding_resume_monotonicity_test.dart test/onboarding_upload_source_reconciler_test.dart test/ah_f010_restore_uploaded_asset_test.dart test/onboarding_persistence_phase2b_test.dart
flutter test --reporter compact test/group_h_adversarial_stress_test.dart test/group_h_issues_33_to_42_test.dart test/group_k_issues_63_to_68_test.dart test/challenger_p46_m3_2_adversarial_test.dart test/onboarding_completion_group_a_test.dart
flutter test --reporter compact test/ah_f013_completion_terminalization_test.dart test/ah_f014_step14_idempotency_test.dart test/ah_f021_step14_final_review_test.dart test/onboarding_completion_bundle_test.dart test/onboarding_completion_retry_contract_test.dart
flutter test --reporter compact test/onboarding_step4_ai_flow_test.dart test/onboarding_step4_role_change_test.dart test/onboarding_step4_timeline_layout_test.dart test/features/onboarding/onboarding_step4_step5_ux_closure_test.dart test/ah_f018_timeline_foundation_test.dart
flutter test --reporter compact test/nutrition_target_service_test.dart test/onboarding_eating_weekly_plan_test.dart test/onboarding_step5_all_dishes_mapping_test.dart test/onboarding_step5_eating_ai_flow_test.dart test/onboarding_step5_error_mapping_test.dart test/onboarding_step5_generated_no_fake_fallback_test.dart test/onboarding_step5_local_timeline_lens_overlap_test.dart test/onboarding_step5_regeneration_test.dart test/onboarding_step5_save_test.dart test/onboarding_step5_short_meal_timeline_alignment_test.dart test/onboarding_step5_worker_error_mapping_test.dart
flutter test --reporter compact test/onboarding_step7_state_machine_test.dart test/onboarding_step7_transaction_test.dart test/onboarding_step7_cta_navigation_test.dart test/onboarding_step7_pending_photo_generation_test.dart test/onboarding_step7_runtime_ui_stability_test.dart test/onboarding_step7_full_timeline_regression_test.dart test/onboarding_step7_skin_care_test.dart test/onboarding_step7_p0_migration_test.dart
dart format --output=none --set-exit-if-changed test/onboarding_foundation_restore_matrix_test.dart lib/models/onboarding_draft.dart lib/services/onboarding_resume_validator.dart lib/state/upload_state.dart lib/services/onboarding_upload_source_reconciler.dart lib/services/server_reconstructor.dart lib/state/auth_state.dart lib/state/app_state.dart
flutter analyze
git diff --check
flutter test
```

## M. Full Flutter test result

`flutter test`

**PASS — 2,042 passed, 10 skipped, 0 failed (1 minute 4 seconds).**

The ten skips remain the explicitly disabled AH-F021 legacy onboarding conflict-decision UI group.
There are **0 test failures** across the entire repository.

## N. Static analysis and formatting

- `flutter analyze`: **PASS — no issues found (ran in 4.5 seconds).**
- `git diff --check`: **PASS.**
- Static architecture searches: **PASS** for deleted Step 4 path, deleted duplicate
  onboarding repository, deleted `MigrateLegacySetupAction` / `migrate_legacy_setup`,
  removed dead symbols, current renamed paths/classes, single registry/order,
  and semantic production step ownership.
- Gate-4 touched files: **PASS — 100% format-clean after scoped formatting (`dart format`).**

## O. Gate 1 regression result

**PASS.** The focused completion matrix passed 108 tests (10 intentional
legacy UI skips). No completion persistence, stage,
`currentRun`, Firestore, or session-destination behavior was broken.

## P. Gate 2 regression result

**PASS.** All current focused nutrition/Eating/Step 5 suites passed 80 tests.
Generated-plan behavior was preserved.

## Q. Gate 3 regression result

**PASS.** Current Step 7 state-machine, transaction, CTA, pending-photo,
runtime, timeline, main, and migration suites passed 227 tests. Skin Care
behavior was preserved.

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
| 10. Restore Foundation & Monotonicity Invariants | PASS |
| Gate 1 regressions | PASS |
| Gate 2 regressions | PASS |
| Gate 3 regressions | PASS |
| Gate-4 focused tests | PASS |
| Full Flutter suite | PASS — 2,042 passed, 10 skipped, 0 failed |
| Flutter analyze | PASS |
| Gate-4 changed-file formatting | PASS |

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

The completed Gate 4 commits changed the semantic registry/order, draft
topology reader and alias normalizers, current flow/readiness/step ownership,
Step 4 model ownership, Steps 8–14 filenames/classes, dead Step 4/14 code,
imports/tests, and architecture/evidence documentation. This verification pass
confirmed that the source already contains the third-closure semantic ownership,
duplicate-repository deletion, and static guards. It only added scoped formatting
for two Gate-4-owned files and refreshed this report with current dirty-tree
evidence; it did not modify onboarding behavior.

## Remaining compatibility debt

G4-C01–C09 and G4-C11–C12 remain intentionally bounded readers/bridges with
explicit removal conditions. The exact active callers of G4-C09 are
`onboarding_flow.dart` and `session_destination_resolver.dart`. G4-C11 has no
active production caller of its deprecated aliases; its in-repo compatibility
exercise is `onboarding_completion_group_a_stress_test.dart`, while the aliases
remain source-compatible for supported downstream callers. G4-C14 remains
owner-scoped and unchanged. G4-C15 and G4-C16 are permanently removed and
statically protected. The repository formatting baseline is maintained; all test
suites pass with 0 failures (2,042 passed, 10 skipped, 0 failed across the entire
repository).

## S. Final Closure Pass — 2026-09-09

### FIRESTORE SCHEMA-V4 CONTRACT

App write contract (from `lib/models/onboarding_draft.dart`):
- `schemaVersion = 4` (static const)
- `stepCompletionContractVersions`: `List<int>`, length 15, all values = 1

Firestore rules contract (`firestore.rules`, function `validOnboardingDraft`):
- `data.schemaVersion == 4` (line 1214)
- `data.stepCompletionContractVersions is list` (line 1229)
- `data.stepCompletionContractVersions.size() == 15` (line 1230)
- `data.stepCompletionContractVersions.toSet().hasOnly([1])` (line 1231)
- `data.stepCompleted is list && size() == 15` (lines 1226–1228)
- `data.stepDirty is list && size() == 15` (lines 1232–1234)
- `data.stepLoading is list && size() == 15` (lines 1235–1237)

App contract and rules contract are **in exact parity**. No inconsistency.

Note: `stepCompletionContractVersions` is a **list** (not a map). Only contract version **1** is the current supported durable version. Version 0 and version 2 are explicitly rejected at the Firestore rules level.

### FIRESTORE RULE EMULATOR RESULT

Date: 2026-09-09

Command:
```bash
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
npm run test:firestore
```

Result:
- **Total: 142 passed, 0 failed**
- Exit code: 0

New edge cases added and verified in this pass (`enforces all schema-v4 stepCompletionContractVersions edge cases`):

| Case | Result |
|---|---|
| valid schema-v4 draft | ALLOW |
| schemaVersion = 3 | DENY |
| schemaVersion = 2 | DENY |
| missing stepCompletionContractVersions | DENY |
| stepCompletionContractVersions length = 14 | DENY |
| stepCompletionContractVersions length = 16 | DENY |
| all versions = 0 | DENY |
| one version = 0 | DENY |
| one version = 2 (unsupported) | DENY |
| wrong UID | DENY |
| malformed stepCompleted length (14) | DENY |
| malformed stepDirty length (16) | DENY |
| malformed stepLoading length (14) | DENY |

### FIREBASE PROJECT IDENTITY

All project identity checks pass:

| Source | Value | Match |
|---|---|---|
| `android/app/google-services.json` | `optivus-lifeos` (project_number: 783577835780) | ✓ |
| `lib/config/firebase_options.dart` | `optivus-lifeos` (appId: `1:783577835780:android:e451817a3d87bbb34d8851`) | ✓ |
| `firebase use` (CLI active project) | `optivus-lifeos` | ✓ |
| `firebase projects:list` | `optivus-lifeos (current)` | ✓ |

ANDROID PROJECT = DART PROJECT = FIREBASE DEPLOY TARGET = `optivus-lifeos`. **MATCH = YES**.

### REMOTE FIRESTORE RULE DEPLOYMENT

Command: `firebase deploy --only firestore:rules --project optivus-lifeos`
Timestamp: 2026-09-09T14:43:28+05:30
Exit code: 0
Result: `✔ cloud.firestore: rules file firestore.rules compiled successfully`
         `✔ firestore: released rules firestore.rules to cloud.firestore`
         `✔ Deploy complete!`

(Firebase CLI noted: `latest version of firestore.rules already up to date, skipping upload` — confirming the previously deployed rules are identical to the current source.)

Rules URL: https://console.firebase.google.com/project/optivus-lifeos/firestore/rules

### REAL SCHEMA-V4 FIRESTORE WRITE ACCEPTANCE

Live `optivus-lifeos` project requires `request.auth.token.email_verified == true` for all onboarding draft writes. Anonymous/unauthenticated headless REST writes are blocked by design.

Real schema-v4 write acceptance is verified via:
1. Firestore emulator test suite with authenticated, email-verified test contexts (142 passing tests including schema-v4 contract cases).
2. Client serialization contract verified in `test/work_package_c_remediation_test.dart` (Contract 4: `OnboardingDraft.toFirestoreMap()` includes `stepCompletionContractVersions`, `schemaVersion: 4`, all 15 required keys).
3. `test/onboarding_persistence_phase2b_test.dart` (63 tests including Firestore persistence round-trips with schema v4 and receipts vector).

Direct production write with a live user session requires the physical Android device. See PHYSICAL STEP 2/5/7 sections below.

### FRESH-SESSION AUTOMATED RESTORE

Suites run from current checkout (2026-09-09):

| Suite | Passed |
|---|---|
| `onboarding_restore_test.dart` | Included in 252 total below |
| `onboarding_foundation_restore_matrix_test.dart` | 30 |
| `onboarding_step_layout_migration_test.dart` | 48 |
| `ah_f012_onboarding_resume_monotonicity_test.dart` | 15 |
| `ah_f007_server_reconstruction_test.dart` | 8 |
| `onboarding_upload_source_reconciler_test.dart` | 36 |
| `ah_f010_restore_uploaded_asset_test.dart` | 45 |
| `onboarding_persistence_phase2b_test.dart` | 63 |
| **Total** | **252 passed, 0 failed** |

Fresh-session coverage confirmed running:
- Steps 0–13 restore matrix (30 step-N→step-N+1 cases)
- Step 5 skip, generated Eating, uploaded Eating → Step 6
- Step 7 skip, has-products, build-for-me → Step 8
- completed onboarding → Home
- exact asset older than 150 uploads
- deleted A + newer B → reopen affected step / never silently adopt B
- explicit A→B replacement (authorized substitution)
- temporary upload failure → reconnect
- owner mismatch → integrity recovery
- R2 key mismatch → integrity recovery
- purpose mismatch → integrity recovery
- missing completion contract → migration reason code
- unsupported completion version → typed reason code
- Account A → B isolation (zero state bleed)

All cases pass.

### PHYSICAL STEP 2 RESTORE

**NOT RUN** — No physical Android device connected (`flutter devices` reports macOS desktop only; `adb` not found in PATH).

Required result when device is available:
- Complete Step 2 → reach Step 3 → force-kill → reopen → Step 3 ✓
- logout → login same UID → Step 3 ✓

### PHYSICAL STEP 5 RESTORE

**NOT RUN** — No physical Android device connected.

Required result when device is available:
- Complete Step 5 → reach Step 6 → force-kill → reopen → Step 6 ✓
- logout/login same UID → Step 6 ✓
- uninstall → fresh install → login same UID → Step 6 ✓
- photo/import Eating path → Step 6 ✓

### PHYSICAL STEP 7 RESTORE

**NOT RUN** — No physical Android device connected.

Required result when device is available:
- Complete Step 7 → reach Step 8 → force-kill → reopen → Step 8 ✓
- logout/login same UID → Step 8 ✓
- uninstall → fresh install → login same UID → Step 8 ✓
- photo-backed (has-products or build-for-me) path ✓

### PHYSICAL COMPLETED-ACCOUNT RESTORE

**NOT RUN** — No physical Android device connected.

Required result when device is available:
- Complete Step 14 → Home → force-kill → reopen → Home ✓
- logout/login → Home ✓
- reinstall/login → Home ✓

---

## G. Physical Device Defect Resolution: `completion_run_input_mismatch`

### 1. Defect Description & Root Cause
Physical Android testing exposed a Gate 4 restore failure:
```text
[Reconstruction] classified ... lifecycle=recovery
[OnboardingRestore] {code: completion_run_input_mismatch}
```
**Root Cause**:
When a user completed onboarding and later tapped "Re-run Setup" / "Start Over", `markOnboardingIncomplete()` marked `onboardingCompleted = false` on `UserProfile`, but left `/users/{uid}/onboarding/currentRun` pointing to the previous completion run.
On cold restart after completing Steps 0–2, `classifyServerReconstruction` evaluated `job.draftRevision != draft.revision` against the old completion run (from setup 0) before checking incomplete draft resumption. Because the new draft was at revision 1–3 and the old job was at revision 15, `classifyServerReconstruction` aborted into `Recovery` with diagnostic code `completion_run_input_mismatch` instead of resuming at Step 3.

### 2. Architecture & Lineage Contract Fix
Instead of deleting Firestore data or ignoring mismatches, a durable setup lineage identity was established:
- **`setupGeneration` / `currentSetupGeneration` (int, default 0)**:
  - Stored consistently across `UserProfile` (`currentSetupGeneration`), `OnboardingDraft` (`setupGeneration`), `OnboardingCompletionJob` (`setupGeneration`), `OnboardingCompletionBundle` (`setupGeneration`), and `OnboardingCurrentRunSnapshot` (`setupGeneration`).
  - Added `lastResetOperationId` (String?) to `UserProfile` and `OnboardingDraft` to ensure atomic, idempotent reset operations.
- **Firestore Security Rules**:
  - `validUserProfileKeys` and `validUserProfile`: includes `currentSetupGeneration` and optional `lastResetOperationId`.
  - `validOnboardingDraftKeys` and `validOnboardingDraft`: includes `setupGeneration` and optional `lastResetOperationId`.
  - `validOnboardingCompletionBundleKeys` and `validOnboardingCompletionBundle`: includes `setupGeneration`.
  - `validOnboardingCompletionJob` and `validOnboardingRun`: includes `setupGeneration`.
  - `validOnboardingCurrentRun`: allows `setupGeneration` and valid statuses `["active", "completed", "superseded"]`.
  - Added transitions: `validOnboardingCurrentRunSupersededTransition` and `validOnboardingSupersededToFreshRun` without deleting the currentRun pointer document (`allow delete: false` preserved).
  - Terminal state lineage fencing: requires `pointer.setupGeneration == profile.currentSetupGeneration && run.setupGeneration == profile.currentSetupGeneration`.
- **Atomic Reset Coordinator (`OnboardingSetupResetCoordinator`)**:
  - Atomically runs Firestore transaction:
    1. Marks existing `currentRun` pointer status as `'superseded'`.
    2. Writes clean schema-v4 draft with `setupGeneration = nextGeneration`.
    3. Updates `UserProfile` with `currentSetupGeneration = nextGeneration`, `onboardingCompleted = false`, `onboardingProjectionStatus = 'pending'`, `onboardingStep = 0`.
  - Prevents stale completion workers from committing writes to a newer setup generation.
- **Server Reconstructor Classification (`classifyServerReconstruction`)**:
  - Deterministic 3-way lineage comparison:
    1. `draft.setupGeneration != currentSetupGeneration` $\rightarrow$ Recovery(`setup_lineage_corrupt`).
    2. `currentRun.setupGeneration > currentSetupGeneration` $\rightarrow$ Recovery(`setup_lineage_corrupt`).
    3. `currentRun.setupGeneration < currentSetupGeneration` or `pointerStatus == 'superseded'` $\rightarrow$ marked `isRunSuperseded = true` and ignored for incomplete draft resumption.
    4. `profile.onboardingCompleted && isRunSuperseded` $\rightarrow$ Recovery(`completed_profile_with_superseded_run`).
    5. Same-lineage runs (`currentRun.setupGeneration == currentSetupGeneration`) $\rightarrow$ strict `completion_run_input_mismatch` and `completion_run_fatal` checks strictly preserved.
- **UI Synchronization**:
  - `ProfileControlScreens` `_showResetSetupDialog` shows loading indicator and awaits durable server reset before navigating to `/onboarding`.

### 3. Automated Verification Results
- **Lineage Regression Suite**: `test/onboarding_setup_lineage_regression_test.dart` (17/17 passed):
  - Physical Android regression at Steps 3, 6, and 8 resumes onboarding without recovery.
  - Complete 12-state lineage matrix.
  - Step-14 completion writer lineage fencing.
  - Atomic reset coordinator idempotency and state updates.
- **Firestore Security Rules**: `tests/firestore_rules.test.js` (143/143 passed in emulator).
- **Onboarding Restore Matrix**: `test/onboarding_restore_test.dart` (30/30 passed).
- **Remediation & Serialization**: `test/work_package_c_remediation_test.dart` (20/20 passed).
- **Static Analysis**: `flutter analyze` — No issues found!
- **Whitespace Integrity**: `git diff --check` — Clean.
