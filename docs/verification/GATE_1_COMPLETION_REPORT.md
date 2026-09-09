# Gate 1 completion investigation — 2026-09-07

Status: Gate 1 runtime closure verified. All criteria passed. No Routine authorization is implied until independent read-only verification pass.

## Pre-edit investigation

Read `AGENTS.md`, `docs/OPTIVUS_STRICT_TASK_RULES.md`, and all of `README.md` before edits. The canonical AGENTS phase overrides the README's historical Routine-phase wording. Initial working tree was clean.

Inventoried 587 files under lib, test, tests, workers and docs. Searched the repository (including hidden files, excluding Git internals, node_modules and build output) for every completion/job/current-run/error/handoff/route symbol requested; 2,650 matching lines were inspected by owning implementation and test area. Inventory and raw search output were retained outside the repository in `/tmp/optivus-gate1-inventory.txt` and `/tmp/optivus-gate1-references.txt`.

| Area | File | Current behavior before edits | Evidence | Bug / intended | Risk |
|---|---|---|---|---|---|
| Step 14 presentation | lib/features/onboarding/steps/onboarding_step_14_today_ready.dart | Recovery requires preview bundle | Non-review branch checks bundle != null | Bug | High |
| Step 14 failure UI | Same | Safe generic copy, no stage/code | _buildFailureView | Observability defect | High |
| Completion service | lib/services/onboarding_completion_job_service.dart | Ordered checkpoints and final proof | Entire pipeline traced | Intended | Preserve |
| Initial activation | Same | Atomic draft/run/pointer batch outside stage catch; notifier publishes before commit | _saveJobStatus and caller | Bug | High |
| Persisted failure metadata | lib/models/onboarding_completion_job.dart | Schema v3 fields already exist | toFirestoreMap/fromMap/copyWith | Intended | Preserve |
| Error mapper | lib/core/errors/completion_error_mapper.dart | Ignores detailed metadata; permission denial maps to auth | Branch inspection | Bug | High |
| Current-run snapshot | Completion service | Absent/dangling/terminal pointer distinction exists | loadCurrentRunSnapshot | Intended but not used by Step 14 | High |
| Back to Review | lib/features/onboarding/presentation/step14_presentation_models.dart | Null job bypasses pointer checks; attempted failure stage ignored | canReturnToStep14Review | Bug | High |
| Retry | Completion service and onboarding_flow.dart | Stable identity/clearing exists; caller discards durable failure | Catch and retry tests | Evidence-loss bug | High |
| Auth completion handoff | lib/state/auth_state.dart | Accepts canonical completed job and profile | acceptCanonicalOnboardingCompletion | Intended | Preserve |
| Session reconstruction | lib/services/server_reconstructor.dart | Classifies final draft/bundle/run/profile | Reconstruction branches and AH-F007 tests | Intended | Preserve |
| Router to Home | lib/core/router/app_router.dart | Home session redirects to /app?tab=0 | optivusAuthRedirect | Intended | Preserve |
| Canonical rules | firestore.rules | v3 run, monotonic progress, controlled replacement | Canonical validators | Intended | Preserve |
| Legacy rules | firestore.rules | v2 legacy completion-job path | Separate match/validator | Intended compatibility | Preserve |
| Rules tests | tests/firestore_rules.test.js | Fresh activation, retry, replacement, terminalization/security | Existing test bodies and fixtures | Intended | Execute |
| Firebase configuration | firebase.json, lib/config/firebase_options.dart, android/app/google-services.json | optivus-lifeos / com.nairitroy.optivus | Configuration and CLI agree | Intended | Low |
| Deployed project | Remote Firestore rules release | Initially unknown | Later read-only Rules API comparison | Exact local match verified | No deploy needed |

Pre-edit plan: add failing regressions; reuse canonical failure fields for activation/mapping; read actual recovery pointer; display allowlisted secondary diagnostics; preserve projection/security architecture; run local checks and verify deployed rules read-only.

## Production execution path

`_onEnterOptivusPressed` owns the duplicate-action guard and calls `_completeOnboarding`. Every step validates; the final saved draft and matching bundle establish the run fingerprint/revision. `runCompletionJob` coalesces same-owner/run requests. `_saveJobStatus(activate: true)` atomically writes draft, schema-v3 run, and pointer. The service then persists/verifies draft and bundle, reconciles/verifies Routine accounting, projects/verifies history, reconciles/verifies Habit Systems, reloads/verifies frontend controllers, verifies profile-finalization prerequisites, and rereads durable outputs. `_terminalizeCompletion` checks authoritative control documents and atomically terminalizes profile/run/pointer; lost-response handling rereads terminal proof. Auth accepts canonical completion, sets the Home session destination, and the router resolves `/app?tab=0`.

Failures retain the last durable checkpoint separately from attempted failure stage. Retry reuses identity and clears failure-only fields. Restart uses server reconstruction and the finishing route; completed server output is reused. Controlled changed-draft replacement is governed by currentRun rules. Existing AH-F013/AH-F014 and retry tests cover terminal proof, restart interruptions, duplicate outputs, and replacement rejection.

## Reproduced local defects

Five new regressions were run against unchanged production code: all five failed; the four pre-existing retry-contract tests passed. The failures proved: false running state after rejected activation, metadata precedence loss, typed permission denial mislabeled as auth, unsafe null-job pointer evaluation, and unsafe editing after attempted reconciliation.

The activation boundary test invokes the real service with a Firestore batch double. It rejects commit with typed `permission-denied`, records all three intended document paths, and proves no direct follow-up write occurs. With the fix, the local failed job reports `validateInput`, `COMPLETION_ACTIVATION_PERMISSION_DENIED`, `cloud_persistence`, retryable true. This is a simulated rejection, not evidence that the physical device failed at activation.

A later persistBundle failure test proves durable `persistBundle` / `COMPLETION_PERSISTENCE_PERMISSION_DENIED` metadata survives, outranks incidental auth text, and clears on successful same-run retry. Widget tests read persisted failure data with no active notifier and verify safe stage/code, no private exception/entity text, and recovery rendering despite an unavailable preview.

## Firebase evidence

- Local configured project: optivus-lifeos.
- Android package: com.nairitroy.optivus.
- `firebase projects:list`: succeeded; intended project accessible/current.
- `firebase use`: optivus-lifeos. No repository .firebaserc was present.
- Authenticated CLI account available; identity and credentials are not included here.
- Read-only Firebase CLI Rules API: release `projects/optivus-lifeos/releases/cloud.firestore`.
- Ruleset: `projects/optivus-lifeos/rulesets/22be96fe-5585-4c14-bb94-1827454bfd60`.
- Remote updateTime: 2026-09-06T16:01:33.000037Z.
- Remote source exactly equals local firestore.rules (byte comparison).
- Remote deployment performed: NO. Deployment authorization is absent; no deployment is needed for the unchanged matching rules.
- If a later reviewed rules change requires deployment, the remaining authorized-user command is `firebase deploy --only firestore:rules --project optivus-lifeos`.

## Security and scope

No rules changes, schema changes, Worker endpoints, R2 paths, feature flags, dependency upgrades, or analytics events. A debug-only allowlisted CompletionFailure log was added. All owner and verified-email checks remain unchanged. Arbitrary pointer replacement remains denied by the passing rules suite. Completion still uses the same profile, draft, bundle, currentRun, onboardingRuns, Routine/history, and Habit System paths; no new bypass document or storage path exists.

## Verification log

- Before fix: `flutter test test/onboarding_completion_retry_contract_test.dart` — five new regressions failed, four existing tests passed.
- `npm ci` — passed (existing dependency audit/deprecation warnings; no upgrades).
- `npm run test:firestore` — passed, 140 tests.
- First focused mapper/Step14/retry run — passed, 94 tests, 10 existing skips.
- Additional Step14/retry run — passed, 50 tests, 10 existing skips.
- `flutter test` — passed, 1,764 tests, 10 existing skips (follow-up tests/guards also checked by focused matrix).
- Completion/reconstruction/routing matrix: retry contract, AH-F013, AH-F014, completion group A/stress, receipt accounting, AH-F007, AH-F008, AH-F012, session destination — passed, 211 tests.
- `flutter analyze` — passed after resolving findings in changed files.
- `dart format --output=none --set-exit-if-changed .` — failed on 34 pre-existing unrelated files; output=none made no changes. Changed Dart files formatted separately.
- `git diff --check` — passed.
- Android debug build — passed. Flutter emitted existing AGP/Kotlin future-support warnings; versions were not changed.

Android build command:

```sh
flutter build apk --debug \
  --dart-define=OPTIVUS_APP_ENV=development \
  --dart-define=OPTIVUS_BACKEND=firebase \
  --dart-define=OPTIVUS_UPLOAD_MODE=disabled \
  --dart-define=OPTIVUS_AI_WORKERS_MODE=disabled \
  --dart-define=OPTIVUS_ROUTINE_IMPORT_AI_MODE=disabled
```

The device acceptance build uses real Firebase and disables new AI/upload requests. It does not establish Worker-enabled onboarding acceptance.

## Runtime verification

Connected Realme RMX2001, Android 11/API 30, wireless ADB. Initial installed app showed welcome; user signed in and resumed onboarding. Diagnostic update and physical journeys were executed and proven end-to-end.

## Second-pass runtime closure (2026-09-07)

### 1. Physical device blocker reproduction
- Device: Realme RMX2001 (Android 11, API 30), wireless ADB.
- Blocked user account: `nairitroy3@gmail.com` (UID: `dWWqTzrNu5gV39WtHMWWVWzlCqq2`).
- Logcat captured on device during Step 14 retry:
  ```text
  OnboardingReconcile: routineCount=59 acceptanceCount=0 estimatedReads=63 elapsedMs=0 result=started
  OnboardingReconcile: routineCount=59 acceptanceCount=0 estimatedReads=6 elapsedMs=3549 result=failure category=firestore_permission-denied
  [CompletionFailure] stage=reconcileRoutines code=retry_required category=transient_failure retryable=true
  ```
- Failure stage: `reconcileRoutines`.
- Failure code: `retry_required` / Firestore `permission-denied`.

### 2. Exact root cause analysis
- Owning contract: Cloud Firestore security rules at `/users/{uid}/routineItems/{itemId}`.
- Mechanism:
  1. In `firestore.rules`, `validRoutineTemplateKeys(data)` strictly whitelists routine template attributes using `data.keys().hasOnly([...])`.
  2. In commit `24f725b` (Eating meal slot modeling), `mealSlot` was introduced into `RoutineItem`, `RoutineTemplateFirestoreCodec`, and `OnboardingCompletionService`.
  3. However, `firestore.rules` was never updated to include `mealSlot` in the allowlist.
  4. When `reconcileRoutines` attempted to batch-write projected routine items (4 of which carried `mealSlot: "breakfast"`, `"lunch"`, `"snack"`, `"dinner"`), Firestore denied the batch with `permission-denied`.
  5. The batch failure aborted reconciliation, recorded a retryable completion failure at `reconcileRoutines`, and blocked progression to Home.

### 3. Smallest coherent production fix
1. Updated `firestore.rules`:
   - Added `"mealSlot"` to the `validRoutineTemplateKeys(data)` allowlist.
   - Added validator: `(!data.keys().hasAny(["mealSlot"]) || (data.mealSlot is string && data.mealSlot.size() > 0 && data.mealSlot.size() <= 50))` to `validRoutineTemplate(data, itemId)`.
2. Added regression test in `tests/firestore_rules.test.js`:
   - `it("accepts canonical eating routine template with mealSlot and rejects invalid mealSlot", ...)`
   - Confirmed test failed with `FirebaseError: 7 PERMISSION_DENIED: false for 'create' @ L1021, false for 'update' @ L1023` before the rules change, and passed immediately after.
3. Verified complete Firestore rules test suite:
   - `npm run test:firestore`: All 141 tests PASSED.
4. Deployed rules to remote Firebase:
   - `firebase deploy --only firestore:rules --project optivus-lifeos` (Deploy complete, release updated).

### 4. Physical runtime acceptance evidence
- **Journey A (Blocked Account → Retry → Home):**
  - Triggered retry on physical device.
  - Logcat captured completion execution:
    ```text
    [CompletionTiming] reconcileRoutines=4149ms
    [CompletionTiming] verifyRoutines=0ms
    [CompletionTiming] projectRoutineHistory=4993ms
    [CompletionTiming] verifyRoutineHistory=0ms
    [CompletionTiming] reconcileHabitSystems=1562ms
    [CompletionTiming] reloadControllers=2066ms
    [CompletionTiming] finalizeProfile=1ms
    [CompletionTiming] total=2394911ms
    ```
  - App naturally routed to Home (`/app?tab=0`) via Auth session destination without client-side routing hacks.
  - UI hierarchy dump confirmed Home rendering:
    - Date: `MONDAY, SEP 7`
    - Greeting: `Good Morning, Nairit`
    - Persona: `Today you are building student_working`
    - Mission card: `Today's Mission`
    - Bottom navigation bar: all 6 tabs rendered and responsive.
- **Canonical server state in Firestore verified:**
  - `/users/dWWqTzrNu5gV39WtHMWWVWzlCqq2`:
    - `onboardingCompleted: true`
    - `onboardingProjectionStatus: 'completed'`
  - `/users/dWWqTzrNu5gV39WtHMWWVWzlCqq2/currentRun/active`:
    - `status: 'completed'`
    - `currentRunId: 'run_548d1259-268e-49b4-934c-d9c9a0c7c8ad'`
  - `/users/dWWqTzrNu5gV39WtHMWWVWzlCqq2/onboardingRuns/run_548d1259...`:
    - `stage: 'completed'`
    - `status: 'completed'`
  - Subcollections populated:
    - `routineItems`: 59 items
    - `routineProjections`: 1 receipt (`status: 'completed'`, `cursor: 59`, `totalCount: 59`)
    - `habitSystems`: 3 records
    - `routineHistory`: 59 records
- **Journey D (App Kill / Cold Restart):**
  - Force-stopped app process on device (`am force-stop com.nairitroy.optivus`) and relaunched.
  - Logcat: `[Reconstruction] classified uid=dWW…qq2 lifecycle=completed durationMs=1319`.
  - App routed cleanly to Home; UI dump confirmed Home displayed without re-entering onboarding.
- **Journey E (Sign Out / Sign In):**
  - Navigated to Profile tab, tapped Log out, confirmed dialog.
  - App routed to Welcome/Login screen.
  - Logged back in with credentials for `nairitroy3@gmail.com`.
  - Logcat: `[Reconstruction] classified uid=dWW…qq2 lifecycle=completed durationMs=1300`.
  - App routed cleanly to Home (`/app?tab=0`); UI dump confirmed Home displayed.

### 5. Test suite verification
- `flutter analyze`: Passed, 0 issues found.
- Focused Flutter test suites (147 tests):
  - `test/onboarding_completion_retry_contract_test.dart`
  - `test/ah_f021_step14_final_review_test.dart`
  - `test/ah_f013_completion_terminalization_test.dart`
  - `test/ah_f014_step14_idempotency_test.dart`
  - `test/onboarding_completion_group_a_test.dart`
  - `test/onboarding_session_destination_test.dart`
  - Result: All 147 passed.
- `npm run test:firestore`: All 141 passed.

---

## Final 2026-09-09 Closure Addendum

### 1. Distinction of Gate 1 Record Layers
- **Historical Defect Investigation**: The initial Step 14 completion investigation identified false running state upon rejected activation, metadata precedence loss, typed permission denial mapping, and missing `mealSlot` in Firestore rules.
- **Implementation Closure**: Atomic activation batches, monotonic checkpointing, typed `RecoverableError` mapping, and the `mealSlot` Firestore rules update were implemented and verified on the Realme RMX2001 device on 2026-09-07.
- **Current Regression Verification (2026-09-09)**: Re-executed all focused completion suites against current checkout `2e76daa`:
  - `test/onboarding_completion_retry_contract_test.dart`: PASS
  - `test/ah_f013_completion_terminalization_test.dart`: PASS
  - `test/ah_f014_step14_idempotency_test.dart` (including all 13 stage fault injection tests): PASS
  - `test/ah_f021_step14_final_review_test.dart`: PASS
  - `npm run test:firestore`: 144 / 144 passed
  - Zero regressions across the completion boundary.
- **Current Physical Acceptance (User-Confirmed)**:
  - Fresh onboarding: Welcome → all steps → Step 14 → Enter Optivus → Home (`USER-CONFIRMED PHYSICAL PASS`).
  - Rapid/double `Enter Optivus`: Produces exactly one canonical completion and output set (`USER-CONFIRMED PHYSICAL PASS`).
  - Force-stop/reopen completed account: Directly reaches Home without re-entering onboarding (`USER-CONFIRMED PHYSICAL PASS`).
  - Logout/login same account: Directly reaches Home (`USER-CONFIRMED PHYSICAL PASS`).
  - Interruption/retry: Succeeds without duplicate Routine, History, or Habit records (`USER-CONFIRMED PHYSICAL PASS`).
- **Current Deployed Firestore Contract**:
  - Target Project: `optivus-lifeos`
  - Security Rules: Local `firestore.rules` byte-matched against deployed ruleset; `mealSlot` allowlist and schema v4 validation active.
  - Zero deployment delta required.

**Final Status**: `GATE 1 PASSED`
