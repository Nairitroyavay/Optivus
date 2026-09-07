# Gate 1 completion investigation — 2026-09-07

Status: in progress. No Routine authorization is implied.

## Pre-edit investigation

Read `AGENTS.md`, `docs/OPTIVUS_STRICT_TASK_RULES.md`, and all of `README.md` before edits. The canonical AGENTS phase overrides the README's historical Routine-phase wording. Initial working tree was clean.

Inventoried 587 files under lib, test, tests, workers and docs. Searched the repository (including hidden files, excluding Git internals, node_modules and build output) for every completion/job/current-run/error/handoff/route symbol requested; 2,650 matching lines were inspected by owning implementation and test area. Inventory and raw search output were retained outside the repository in `/tmp/optivus-gate1-inventory.txt` and `/tmp/optivus-gate1-references.txt`.

| Area | File | Current behavior before edits | Evidence | Bug / intended | Risk |
|---|---|---|---|---|---|
| Step 14 presentation | lib/features/onboarding/steps/onboarding_step_11_today_ready.dart | Recovery requires preview bundle | Non-review branch checks bundle != null | Bug | High |
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

Connected Realme RMX2001, Android 11/API 30, wireless ADB. Initial installed app showed welcome; user signed in and resumed onboarding. Diagnostic update and remaining physical journeys are in progress. Actual device failure stage/code, successful terminalization, accepted Home handoff, restart-to-Home, and logout/login acceptance must still be recorded before a gate verdict can pass.
