# Gate 4 Onboarding Foundation — Compatibility Inventory

This inventory classifies current onboarding compatibility after the Gate 4
foundation repair. It is limited to onboarding-owned paths; similarly worded
fallbacks in Auth, Routine, Workers, and generic UI are outside this gate.

The current draft data schema is version 3. The historical page topology is a
separate contract: legacy documents had 12 pages, while the current product has
15. Firestore continues to persist numeric progression fields; no field or
rules change is required.

| Compat ID | File / symbol | Category | Read or write path | New writes use it? | Why it exists | Removal condition | Gate owner / test owner |
|---|---|---|---|---|---|---|---|
| G4-C01 | `OnboardingDraft._detectPersistedStepLayout`, `_migrateLegacyStepBoolList` | REQUIRED_READER | Draft read | No | Safely reads historical 12-page progression and maps it to semantic current IDs | Remove only after the supported-data retention policy proves no legacy drafts remain | Gate 4 / `onboarding_step_layout_migration_test.dart` |
| G4-C02 | `BaseTimelineDraft.acceptedConflictKeys` | REQUIRED_READER | Draft read | No | Reads schema-v2 schedule-unbound conflict acceptances | All supported drafts use typed `conflictAcceptances` and migration telemetry is zero | Gate 1 / durable overlap tests |
| G4-C03 | `isLegacyGeneratedEatingPlan` | REQUIRED_READER | Draft validation/read | No | Detects obsolete generated weekly-plan shapes and requires safe regeneration | All supported drafts carry the current generated-plan version and fingerprint | Gate 2 / Eating weekly-plan tests |
| G4-C04 | legacy body-goal and exercise aliases | REQUIRED_READER | Draft read | No | Canonicalizes repository-evidenced stored aliases before any consumer sees them | Supported persisted data contains canonical values only | Gate 4 / `onboarding_step_layout_migration_test.dart` |
| G4-C05 | Skin Care upload exact-identity migration in reconciler/helpers | REQUIRED_READER | Upload/draft read | No | Restores an established owned legacy upload slot without adopting arbitrary assets | Legacy upload metadata is outside the supported retention window | Gate 3 / upload and Step 7 migration tests |
| G4-C06 | `legacyOnboardingRunId`, `matchesOnboardingRunIdentity` | REQUIRED_READER | Completion-run read/verification | No | Accepts run IDs created before the server-verifiable stable identity | No incomplete/retryable legacy run can remain | Gate 1 / completion retry and idempotency tests |
| G4-C07 | fixed completion-job document fallback | REQUIRED_READER | Completion-job read | No | Recovers a job written before `currentRun` and per-run documents | No recoverable fixed-job documents remain | Gate 1 / terminalization tests |
| G4-C08 | interrupted completion micro-checkpoint recovery | REQUIRED_READER | Completion-job resume | No | Resumes jobs persisted at former intermediate stages | No supported job can contain those stages | Gate 1 / completion job stress tests |
| G4-C09 | `durableOnboardingResumeStep` compatibility name | TEMPORARY_BRIDGE | Active in-process API | Yes | Existing callers delegate to the canonical `validateOnboardingResume` result | All callers consume `OnboardingResumeValidation` directly in a separately authorized cleanup | Onboarding / resume monotonicity tests |
| G4-C10 | `OnboardingClassSetupWidget` file | TEMPORARY_BRIDGE | Test-only old Step 4 UI | No | Historical regression suites still instantiate the old split widget; production imports only the extracted current models/providers | Migrate or retire the named legacy widget suites, then delete the file | Gate 4 / Group G legacy widget tests |
| G4-C11 | deprecated completion recovery enum aliases | TEMPORARY_BRIDGE | Source compatibility | No | Keeps callers compiled against pre-current recovery result names | All in-repo and supported downstream callers use canonical cases | Gate 1 / completion bundle tests |
| G4-C12 | legacy conflict-key `:` parser | REQUIRED_READER | Draft read | No | Reads pre-canonical conflict acceptance keys | No supported draft contains schedule-unbound legacy keys | Gate 1 / durable overlap tests |
| G4-C13 | `_showLegacyEditDialog`, unified Step 4 `_buildDayChip`, Step 14 `_buildAttentionSection`, `BaseTimelineDraft.validateForRole` | DEAD_REMOVED | None | No | Zero callers and current adapter/day-chip/conflict/specific-validator replacements were source-proven | Removed in Gate 4 | Gate 4 / static scan and focused suites |
| G4-C14 | Auth deprecated statuses, account migration, generic `AiThinkingCard` compatibility, Routine/Worker fallbacks | OUT_OF_SCOPE | Other owners | Varies | Not owned by the bounded onboarding-foundation cleanup | Owner-specific authorized phase and evidence | Auth/Routine/Workers |

## Evidence-backed value normalization

| Field | Legacy values | Current canonical value | Evidence |
|---|---|---|---|
| `BaseTimelineDraft.mealPlanningGoal` | `gain_weight`, `build_muscle`, `muscle_gain` | `gain` | Existing Step 5 body-goal normalizer |
| `BaseTimelineDraft.mealPlanningGoal` | `lose_fat`, `fat_loss`, `weight_loss` | `lose` | Existing Step 5 body-goal normalizer |
| `BaseTimelineDraft.mealPlanningGoal` | `maintenance`, `eat_healthier`, `balanced` | `maintain` | Existing Step 5 body-goal normalizer |
| `LifeRoleDraft.exerciseLevel` | `low`, `sedentary` | `rarely` | Existing `NutritionTargetService.activityFactor` compatibility cases |
| `LifeRoleDraft.exerciseLevel` | `medium`, `moderate` | `3_4_days` | Existing service compatibility cases and persisted fixtures |
| `LifeRoleDraft.exerciseLevel` | `high`, `active` | `5_plus_days` | Existing service compatibility cases |

Unknown values in these enum-like fields deserialize to `null`, preserving the
existing validation requirement instead of silently selecting a different
valid choice. Free-form user text is never normalized.
