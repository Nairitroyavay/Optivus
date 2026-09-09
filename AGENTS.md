# Optivus Repository Instructions

This file is the canonical repository instruction source for coding agents.

# Current engineering phase

**CURRENT PHASE: PHASE 4 — ROUTINE PRODUCTION DEVELOPMENT (GATE 7 COMPLETED)**

The Pre-Routine stabilization gate passed on 2026-09-09 (`PASS — READY FOR ROUTINE PHASE`), and Gate 7 (Routine Entry Gate / Routine Production Foundation) has passed (`GATE 7 PASSED`). Routine feature development is now unblocked.

Current baseline:

* AUTH: FROZEN EXCEPT VERIFIED REGRESSION / PRODUCT DEFECT FIXES
* ONBOARDING 0–14: FROZEN EXCEPT VERIFIED REGRESSION / PRODUCT DEFECT FIXES
* ONBOARDING STEP 7: FROZEN / REGRESSION FIXES ONLY
* STEP 4/5 STEP7-STYLE UX: FROZEN
* ROUTINE PRODUCTION DEVELOPMENT: UNBLOCKED (GATE 7 FOUNDATION COMPLETE)
* ARCHITECTURAL CLEANUP / MODERNIZATION: FROZEN UNLESS REQUIRED BY A VERIFIED DEFECT

This is a stabilization phase, not an authorization to redesign Auth or Onboarding.

A frozen area may change only when all of the following are true:

1. A reproducible regression, blocker, security issue, persistence-contract defect, state-ownership defect, or product defect exists.
2. Evidence identifies the owning contract or implementation.
3. The change addresses the root cause rather than hiding the symptom.
4. A focused regression test is added or strengthened.
5. The smallest coherent production-safe fix is used.
6. Relevant Auth/Onboarding regression tests are run afterward.
7. The change does not introduce unrelated UX, architecture, dependency, naming, or cleanup work.

Do not improve, modernize, clean up, rename, split, rebuild, or reorganize Auth/Onboarding merely because a file is large, old naming exists, historical material suggests a better architecture, or a coding agent prefers another design.

# Explicitly authorized stabilization scope

The following known areas are authorized for investigation and correction during the current phase, but only after the current source proves the defect still exists.

## 1. Step 14 completion persistence

Authorized scope:

* onboarding completion job state transitions
* persisted completion stages
* retry/resume/idempotency
* Firestore onboarding-run rules
* final completion → session destination → Home behavior
* focused tests and Firestore emulator/rules coverage

The preferred outcome is for the client and Firestore rules to share one legal monotonic completion contract.

Do not broadly weaken Firestore security rules.

## 2. `currentRun` retry/replacement semantics

Authorized scope:

* failed-run retry
* failed run → edited draft → legitimate replacement run
* source fingerprint / draft revision handling
* stale-run protection
* ownership and account isolation
* focused Firestore rule/integration tests

Arbitrary replacement of `currentRun` must remain denied.

## 3. Skin Care Step 7 regressions

Authorized regression-only scope:

* Back navigation after a valid/current routine
* stale `Build skin routine` footer action
* expected review CTA `Next Step`
* zero-usable-routine handling
* regeneration failure behavior
* preservation of the previous valid routine
* stale async-generation responses
* focused Step 7 regression tests

Do not redesign Step 7 UX.

Do not split/rebuild the entire Step 7 implementation merely because the file is large.

## 4. Eating generated-routine correctness

Authorized scope:

* repeated-meal structural defect
* generated day × meal-slot representation
* worker response contract
* generated-plan persistence/serialization
* meal-plan validation
* compatibility required to safely read existing generated drafts
* focused tests

The fix must address the data contract, not merely add stronger prompt wording.

Eating import behavior must remain working unless evidence proves it shares the defect.

## 5. Canonical nutrition targets

Authorized scope:

* conflicting active BMR / TDEE / maintenance / calorie-target / protein-target calculations
* creation or consolidation of one production nutrition-target calculation path
* updates required for Eating generation and validation
* focused deterministic tests

Do not perform unrelated Profile, Goals, Home, or Routine redesign.

If legacy formulas remain solely for migration compatibility, isolate and document them rather than treating them as active production truth.

## 6. Eating completion validation

Authorized scope:

* required day/meal-slot coverage
* generated calories/protein metadata
* practical target validation
* weekly diversity validation
* Step 14 use of the same canonical Eating contract
* actionable domain validation failures
* focused tests

Do not add unsupported health or nutrition assumptions that Optivus does not collect or model.

## 7. AI generation transaction safety

Authorized scope where evidence exists:

* empty-but-HTTP-success responses
* malformed results
* retries
* duplicate requests
* stale responses
* widget disposal
* sign-out/account switching while requests are active
* candidate validation before replacing currently valid Eating/Skin Care data

Do not redesign the general AI architecture unless required to fix a proven regression.

# Still frozen during this phase

The following are explicitly NOT authorized merely as cleanup:

* broad `auth_state.dart` decomposition
* renaming production providers only because they contain `mock` in the name
* general provider architecture modernization
* broad router redesign
* general onboarding state-machine rewrite
* Step 7 full rewrite
* mass dead-code removal
* mass legacy cleanup
* onboarding source-file renumbering
* cosmetic renaming of Step files/classes
* package upgrades
* Flutter upgrades
* Gradle/AGP/Kotlin upgrades
* Routine implementation
* Profile/Tracker/Goals redesign

These may be audited and reported, but they must not be changed unless:

1. a current reproducible defect requires the change, or
2. the user explicitly authorizes a separate cleanup/refactor phase.

# Stabilization gate

Routine development must not begin until the current repository demonstrates, with available automated/runtime evidence:

## Auth/session

* signup works
* email verification works
* verified login works
* restart/reconstruction works
* sign-out works
* account switching preserves user isolation

## Onboarding

* onboarding resumes after restart
* forward/back navigation remains correct
* existing working Step 4 flows remain working

## Eating

* AI generation represents all required days and meal slots
* generated days can contain different meals
* canonical nutrition targets are used
* calories/protein are validated where required by the generated-plan contract
* weekly diversity is validated
* import flow remains working
* failed regeneration does not destroy valid persisted data

## Skin Care

* has-products flow works
* build-for-me flow works
* skip works
* usable success works
* zero-plan response fails safely
* retry works
* review → Back returns to choice
* valid review CTA is `Next Step`
* stale `Build skin routine` CTA does not survive
* failed regeneration does not incorrectly replace a valid routine

## Step 14 / completion

* fresh completion reaches Home
* failed completion can retry
* failed completion → edit → replacement run works
* app restart during completion is recoverable
* duplicate completion action is safe
* Firestore stage transitions are legal
* `currentRun` replacement is controlled
* stale/unauthorized writes remain rejected

# Evidence standard

For any claimed fix, report:

* reproduced or source-proven defect
* owning contract
* root cause
* files changed
* smallest fix used
* regression test added/changed
* commands actually run
* results
* anything not verified

Compilation alone is not evidence of correctness.

A historical report, old log, previous agent statement, or earlier audit is not sufficient proof that a defect still exists in the current checkout.

# End-of-phase rule

The implementation agent may report:

`STABILIZATION IMPLEMENTATION GATE PASSED`

It must not independently declare the repository ready for Routine development.

After implementation, perform a separate read-only verification pass.

Routine development may begin only after that independent verification returns:

`PASS — READY FOR ROUTINE PHASE`

or, if the user explicitly accepts the remaining non-blocking debt:

`CONDITIONAL PASS — ROUTINE MAY START WITH NON-BLOCKING DEBT`

Any unresolved P0 or P1 keeps Routine blocked.
