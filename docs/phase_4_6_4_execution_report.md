# OPTIVUS Phase 4.6.4 Execution Report

Report date: 2026-08-03 (Asia/Kolkata)  
Authority: current Phase 4.6.4 source, automated-test, emulator, and build evidence  
Baseline: `main` at `7cbd617ae5a617c6f05b3534573f1be7ccdc9dd1`; initially clean  
Final verdict: `BLOCKED — NOT READY FOR REAL-DEVICE TESTING`

The P0 contract, recovery, durability, projection, account-isolation, and
startup defects found by the initial audit are closed in source and automated
evidence. P1-07 remains `ENVIRONMENT_BLOCKED`: this workspace contains no
approved staging targets, release signing variables, or release certificate
fingerprint evidence. No staging artifact is accepted by this report.

## Verification summary

| Gate | Evidence status | Exact result |
|---|---|---|
| Dependency resolution | `PASS_BUILD_VERIFIED` | `flutter pub get` exited 0; 28 constrained packages have newer incompatible versions. |
| Formatting | `PASS_BUILD_VERIFIED` | `dart format --output=none --set-exit-if-changed .`: 453 files checked, 0 changed. |
| Analyzer | `PASS_BUILD_VERIFIED` | `flutter analyze`: 0 issues. |
| Flutter tests | `PASS_AUTOMATED_TESTED` | 969 passed, 0 failed, 0 skipped, 0 error events. |
| Firestore Rules emulator | `PASS_EMULATOR_VERIFIED` | `tests/firestore_rules.test.js`: 39 passed, 0 failed, 0 skipped. Expected-denial tests emit `PERMISSION_DENIED` warnings. |
| Debug Android build | `PASS_BUILD_VERIFIED` | `build/app/outputs/flutter-apk/app-debug.apk`; 192,473,311 bytes; SHA-256 `2cdcd710a2d11fd81541b96e7ddb0d746141582ac79b735c294747d809320c17`; 21.03 seconds. |
| Release signing guard | `PASS_BUILD_VERIFIED` | `./gradlew app:assembleRelease --dry-run` failed closed: four `OPTIVUS_ANDROID_*` signing variables are absent. |
| Configured staging APK/AAB | `ENVIRONMENT_BLOCKED` | No approved staging project/endpoint definitions and no release signing credentials or SHA evidence are available. |
| Worker endpoint verification | `ENVIRONMENT_BLOCKED` | There are no authorized staging endpoints to probe or validate. Development defaults are not staging evidence. |

Exact emulator command:

```sh
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' PATH='/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin' firebase emulators:exec --only firestore 'npm test'
```

The emulator fixture source is `tests/firestore_rules.test.js`. Its Phase 4.6.4
fixtures use the production paths and exact canonical fields for root profile,
profile settings, region localization, app preferences, completion draft,
completion bundle, completion job, Routine, History, and Habit records.

## Canonical contracts delivered

| Artifact | Canonical path/shape | Enforcement and readback |
|---|---|---|
| UserProfile | `/users/{uid}` only | Exact root serializer and Rules; full profile at `/profile/main` denied. |
| Profile settings | `/users/{uid}/profile/main` | Small settings-only full replacement; exact Rule. |
| RegionLocalization | `/users/{uid}/settings/regionLocalization` | Owner, schema v1, exact localization fields, Firestore timestamps; full replacement and round-trip. |
| AppPreferences | `/users/{uid}/settings/appPreferences` | Owner, schema v1, seven preference fields, Firestore timestamps; full replacement and every field round-tripped. |
| Onboarding draft | `/users/{uid}/onboarding/draft` | Owner, schema v2, revision, fingerprint, Firestore timestamps; final write and content readback. |
| Completion bundle | `/users/{uid}/onboarding/completionBundle` | Owner, schema, source fingerprint, draft revision, expected/accepted/generated IDs, Firestore timestamps; full readback. |
| Completion job | `/users/{uid}/onboardingCompletionJobs/current` | `ownerUid`, schema v2, exact stages/statuses, accounting, typed failure metadata, Firestore timestamps. |
| Routine | `/users/{uid}/routineItems/{id}` | Deterministic onboarding source/fingerprint; conflicting user/source conversion fails closed. |
| History | `/users/{uid}/routineHistory/{id}` | Deterministic occurrence projection with source/projection/fingerprint and full created/existing/repaired/failed readback. |
| Habit | `/users/{uid}/habitSystems/{id}` | Deterministic source/projection/fingerprint and full repository/controller readback. |

## Persisted completion state machine

The canonical stages are:

`validateInput → persistDraft → verifyDraft → persistBundle → verifyBundle → reconcileRoutines → verifyRoutines → projectRoutineHistory → verifyRoutineHistory → reconcileHabitSystems → verifyHabitSystems → reloadControllers → verifyFrontendState → finalizeProfile → completed`.

The only canonical statuses are `pending`, `running`, `retryableFailure`,
`fatalFailure`, and `completed`. Rules permit bounded forward transitions, deny
skipped stages, and make a completed job immutable. Legacy stage/status aliases
are decode-only and normalize on the next canonical write.

## Issue register

### P0-01 — Canonical UserProfile path

- **Issue ID / Severity / Status:** P0-01 / P0 / `PASS_EMULATOR_VERIFIED`.
- **Production path:** root profile, profile settings, onboarding transaction, finalization, and matching Rules.
- **Symptom / Reproduction:** full profile data was written to `/profile/main`; compare production serializers with Rules or run the negative emulator fixture.
- **Root cause / Required invariant:** completion reused the settings path; full `UserProfile` must exist only at `/users/{uid}` and finalization must use that root.
- **Files inspected / Files changed:** profile/onboarding repositories, completion service/job service, profile settings model, `firestore.rules`; all corresponding writers and Rules were changed.
- **Tests added:** root serializer accepted, full profile at `/profile/main` denied, settings serializer accepted, owner/UID/unknown-field negatives.
- **Rules impact / Migration impact:** strict root/settings split; owner-readable legacy data remains readable, while canonical writes normalize the root without a destructive migration.
- **Commands executed / Exact evidence:** Flutter suite 969/969 and emulator 39/39; canonical profile tests pass.
- **Remaining risk / Final verdict:** remote deployment is not exercised here; contract blocker resolved.

### P0-02 — Region and AppPreferences contracts

- **Issue ID / Severity / Status:** P0-02 / P0 / `PASS_EMULATOR_VERIFIED`.
- **Production path:** region and app-preference model, repository, provider, settings paths, and Rules.
- **Symptom / Reproduction:** preferences contained profile fields and merge writes retained drift; Region lacked strict schema enforcement.
- **Root cause / Required invariant:** split serializers evolved independently; each document now has one exact owner/schema/timestamp contract and full replacement semantics.
- **Files inspected / Files changed:** `region_settings.dart`, `profile_settings_models.dart`, region/app-preference repositories, Rules.
- **Tests added:** exact key/type/unknown-field/owner emulator tests plus all-field Region and AppPreferences Firestore round-trips.
- **Rules impact / Migration impact:** exact v1 schemas deny drift; the next save replaces legacy fields rather than merging them.
- **Commands executed / Exact evidence:** `work_package_c_remediation_test.dart` passes; emulator canonical settings tests pass.
- **Remaining risk / Final verdict:** deployed legacy documents normalize only when saved; blocker resolved without destructive migration.

### P0-03 — CompletionBundle contract

- **Issue ID / Severity / Status:** P0-03 / P0 / `PASS_EMULATOR_VERIFIED`.
- **Production path:** completion service, bundle model/repository, `/onboarding/completionBundle`, Rules.
- **Symptom / Reproduction:** production wrote ISO timestamps and lacked revision/fingerprint/expected-set metadata while emulator used a different hand-built shape.
- **Root cause / Required invariant:** `toMap` and `toFirestoreMap` diverged; one canonical Firestore map must carry source identity and real expected sets.
- **Files inspected / Files changed:** bundle/draft models, onboarding repository, completion service/job service, Rules and emulator fixture.
- **Tests added:** timestamp/fingerprint/revision/unknown-field negatives, serializer shape, persistence/readback and recovery rebuild cases.
- **Rules impact / Migration impact:** schema/timestamps are strict; legacy ISO timestamps remain decode-compatible and normalize on rewrite.
- **Commands executed / Exact evidence:** bundle contract and recovery suites are included in 969/969; emulator canonical bundle test passes.
- **Remaining risk / Final verdict:** remote Firestore is not used in this phase; blocker resolved.

### P0-04 — CompletionJob contract

- **Issue ID / Severity / Status:** P0-04 / P0 / `PASS_EMULATOR_VERIFIED`.
- **Production path:** job model/service, `/onboardingCompletionJobs/current`, Rules.
- **Symptom / Reproduction:** legacy `uid`, `in_progress`, coarse stages, strings, and synthetic accounting were accepted.
- **Root cause / Required invariant:** the durable workflow predated verification stages; job writes now use only `ownerUid`, schema v2, canonical enums, timestamps, accounting, and typed failure fields.
- **Files inspected / Files changed:** job model, job service, completion/repository layers, Rules and emulator fixtures.
- **Tests added:** alternate owner/status denial, invalid stage/status/unknown field, skipped transition, completed immutability, legacy decode normalization.
- **Rules impact / Migration impact:** strict canonical creates/transitions; decode-only legacy aliases are written back canonically on retry.
- **Commands executed / Exact evidence:** state-machine Flutter suites pass; emulator completion-job tests pass.
- **Remaining risk / Final verdict:** an authorized production migration run is outside scope; blocker resolved.

### P0-05 — Unsafe recovery fabrication

- **Issue ID / Severity / Status:** P0-05 / P0 / `PASS_AUTOMATED_TESTED`.
- **Production path:** restore classifier, recovery action model/screen, auth action executor, completion recovery service.
- **Symptom / Reproduction:** a partial or missing draft could be promoted or synthesized as completed.
- **Root cause / Required invariant:** fallback recovery mixed resume, repair, migration, and reset; no completed setup may be created from missing or partial input.
- **Files inspected / Files changed:** recovery models/screen, auth state, completion service and repository.
- **Tests added:** no-draft fail-closed, partial resume, verified-completed rebuild, owner mismatch, corrupt/migration/reset paths, no-fabrication adversarial cases.
- **Rules impact / Migration impact:** no Rules weakening; migration is an explicit recovery classification and reset is explicit/confirmed.
- **Commands executed / Exact evidence:** M3.1/M3.2 recovery suites and full 969-test run pass.
- **Remaining risk / Final verdict:** UX must still be exercised on devices later; fabrication blocker resolved.

### P0-06 — Durable final draft

- **Issue ID / Severity / Status:** P0-06 / P0 / `PASS_AUTOMATED_TESTED`.
- **Production path:** draft save coordinator/repository, completion service/job stages, draft model.
- **Symptom / Reproduction:** existence and completion flags were treated as durable proof.
- **Root cause / Required invariant:** draft identity lacked revision/fingerprint; pending saves must flush, the final revision must persist, and owner/schema/revision/fingerprint/content must read back equal.
- **Files inspected / Files changed:** draft model, onboarding repository, completion service/job service.
- **Tests added:** final draft revision/fingerprint/readback, pending-save flush, stale/mismatched owner and partial draft cases.
- **Rules impact / Migration impact:** Rules require canonical final shape; schema-v1/string-timestamp reads are migrated safely on the next write.
- **Commands executed / Exact evidence:** completion/recovery suites pass within 969/969; emulator rejects incomplete completed draft.
- **Remaining risk / Final verdict:** actual network interruption remains a later device exercise; blocker resolved in deterministic evidence.

### P0-07 — Real Routine History verification

- **Issue ID / Severity / Status:** P0-07 / P0 / `PASS_AUTOMATED_TESTED`.
- **Production path:** Routine projection, History repository/projector, completion accounting and Rules.
- **Symptom / Reproduction:** append-only Routine events/receipt IDs were treated as proof of History; actual occurrence records were absent.
- **Root cause / Required invariant:** event projection and History persistence were conflated; deterministic History records now require complete metadata/content readback.
- **Files inspected / Files changed:** occurrence model, history repository, projection/event projector, completion job/service, Rules.
- **Tests added:** History create/readback, completed-receipt verification, mixed create/existing/repair, wrong-source conversion and overnight occurrence coverage.
- **Rules impact / Migration impact:** History source identity is immutable; user-modified/source-conflicting records fail closed and are not overwritten.
- **Commands executed / Exact evidence:** projection/outbox/stress suites pass; emulator accepts exact onboarding History and rejects conversion.
- **Remaining risk / Final verdict:** live Firestore latency is deferred; integrity blocker resolved.

### P0-08 — Real Habit verification

- **Issue ID / Severity / Status:** P0-08 / P0 / `PASS_AUTOMATED_TESTED`.
- **Production path:** Habit models/repositories/projection, controller hydration, accounting and Rules.
- **Symptom / Reproduction:** matching IDs were accepted without owner/source/projection/fingerprint/content verification.
- **Root cause / Required invariant:** reconciliation returned ID-only evidence; all expected Habit records and the controller-visible set now receive full verification.
- **Files inspected / Files changed:** Habit models, fake/Firebase repositories, onboarding projection, frontend hydration and job service.
- **Tests added:** create/existing/repair/failure accounting, metadata mismatch, readback, controller reload and frontend-visible ID verification.
- **Rules impact / Migration impact:** source/projection identity is immutable; safe repair preserves user-modified records and conflicts fail closed.
- **Commands executed / Exact evidence:** Habit and hydration suites pass within 969/969; emulator exact Habit/source-conversion tests pass.
- **Remaining risk / Final verdict:** remote controller reload is a device-gate item; integrity blocker resolved.

### P0-09 — Final profile integrity

- **Issue ID / Severity / Status:** P0-09 / P0 / `PASS_AUTOMATED_TESTED`.
- **Production path:** completion state machine, root profile repository, auth completion acceptance and frontend hydration.
- **Symptom / Reproduction:** profile completion could occur on the wrong path or independently of verified projections.
- **Root cause / Required invariant:** multiple completion entry points existed; root finalization must be the last stage, exactly once, after every artifact/frontend verification.
- **Files inspected / Files changed:** profile/onboarding repositories, job/completion/hydration services, auth state and Rules.
- **Tests added:** stage ordering, failure-before-finalization, exactly-once finalization, completed-job/root-profile acceptance and wrong-path denial.
- **Rules impact / Migration impact:** root profile lifecycle fields are canonical/immutable as appropriate; incomplete legacy users enter recovery instead of forced completion.
- **Commands executed / Exact evidence:** completion stage suites pass; emulator root/profile-settings split passes.
- **Remaining risk / Final verdict:** device navigation is deferred; blocker resolved.

### P1-01 — Fine-grained persisted state machine

- **Issue ID / Severity / Status:** P1-01 / P1 / `PASS_EMULATOR_VERIFIED`.
- **Production path:** job model/service and Rules transition logic.
- **Symptom / Reproduction:** seven coarse stages collapsed writes and verification and could skip proof gates.
- **Root cause / Required invariant:** the job contract lacked independent checkpoints; exact persisted stages/statuses and bounded transitions are now enforced.
- **Files inspected / Files changed:** job model/service, Rules and fixtures.
- **Tests added:** exact enum serialization, transition ordering, resume/idempotency, failed-stage metadata and invalid-transition denial.
- **Rules impact / Migration impact:** stage may advance at most one canonical step; old aliases decode and normalize.
- **Commands executed / Exact evidence:** Flutter state-machine tests and emulator transition negatives pass.
- **Remaining risk / Final verdict:** remote retry timing is a later device concern; blocker resolved.

### P1-02 — Real completion accounting

- **Issue ID / Severity / Status:** P1-02 / P1 / `PASS_AUTOMATED_TESTED`.
- **Production path:** job accounting, Routine/History/Habit reconciliations and frontend verification.
- **Symptom / Reproduction:** expected/applied History and Habit sets could be synthetic or incomplete.
- **Root cause / Required invariant:** receipts were trusted instead of entity readback; accounting now records readback-derived expected/created/existing/repaired/failed sets.
- **Files inspected / Files changed:** job model/service, projectors, repositories and hydration.
- **Tests added:** mixed reconciliation, failed IDs, set consistency and frontend verification.
- **Rules impact / Migration impact:** Rules validate accounting arrays/types; legacy jobs normalize on retry.
- **Commands executed / Exact evidence:** group C/K, work-package C and completion stress suites pass.
- **Remaining risk / Final verdict:** remote metrics are deferred; blocker resolved.

### P1-03 — Structured failure flow

- **Issue ID / Severity / Status:** P1-03 / P1 / `PASS_AUTOMATED_TESTED`.
- **Production path:** completion/recovery/auth/projection/AI failure and diagnostic paths.
- **Symptom / Reproduction:** raw/free-form exception text and private AI/onboarding payloads could reach logs or in-memory diagnostics.
- **Root cause / Required invariant:** broad catches logged object text; blocking failures now carry type, stage, code, category, retryability, public message key, entity IDs, and bounded diagnostic text.
- **Files inspected / Files changed:** job service, auth/recovery, AI clients/screens, Habit repository, wake-lock manager, platform-channel boundary, asset precache, country fallback, and startup logging.
- **Tests added:** typed failure structure, sensitive exception content omission, safe UI messages and startup failure tests.
- **Rules impact / Migration impact:** canonical job persistence stores typed metadata, not raw exception text; no destructive migration.
- **Commands executed / Exact evidence:** structured-failure/adversarial tests and 969/969 full suite pass; source re-audit found no raw payload logs in the scoped paths.
- **Remaining risk / Final verdict:** external SDK logging is not controlled by application code; blocker resolved for Optivus-owned paths.

### P1-04 — Auth and operation generations

- **Issue ID / Severity / Status:** P1-04 / P1 / `PASS_AUTOMATED_TESTED`.
- **Production path:** sign-out/account switch, completion, restore, recovery and AI result application.
- **Symptom / Reproduction:** an in-flight future could resume after sign-out or update the next account.
- **Root cause / Required invariant:** UID checks were not paired with canonical auth/operation generations; every async resume now validates both owner and generation.
- **Files inspected / Files changed:** new `auth_generation.dart`, auth state, job service, Routine-import state and onboarding AI steps.
- **Tests added:** sign-out invalidation, account switch, late completion/navigation, stale source/request/auth generation and AI rejection.
- **Rules impact / Migration impact:** no Rules/migration impact; this is client-side isolation.
- **Commands executed / Exact evidence:** auth/account-isolation and AI suites pass within 969/969.
- **Remaining risk / Final verdict:** OS process termination is covered by persisted recovery, not cancellation; blocker resolved.

### P1-05 — One recovery architecture

- **Issue ID / Severity / Status:** P1-05 / P1 / `PASS_AUTOMATED_TESTED`.
- **Production path:** recovery classifier, action interface, action screen and auth executor.
- **Symptom / Reproduction:** action subclasses, type dispatch, and fallback synthesis implemented overlapping behavior.
- **Root cause / Required invariant:** actions had no authoritative operations contract; one action executor now applies explicit preconditions and operations.
- **Files inspected / Files changed:** recovery models/screen, auth state, completion/repository services.
- **Tests added:** verified bundle, verified draft rebuild, partial resume, missing setup, corrupt data, migration, owner mismatch and explicit reset.
- **Rules impact / Migration impact:** no Rules weakening; migration and reset are distinct and reset preserves projected records unless separately authorized.
- **Commands executed / Exact evidence:** M3.1/M3.2 recovery suites pass.
- **Remaining risk / Final verdict:** device UX confirmation remains later; blocker resolved.

### P1-06 — Safe startup failure

- **Issue ID / Severity / Status:** P1-06 / P1 / `PASS_AUTOMATED_TESTED`.
- **Production path:** `main.dart`, runtime validation, Firebase initialization, `ConfigurationFailureApp`.
- **Symptom / Reproduction:** runtime validation could throw before safe UI and Firebase failure could expose raw error or continue.
- **Root cause / Required invariant:** validation sat outside the bootstrap guard; the complete bootstrap now returns a deterministic safe failure app and logs runtime type only.
- **Files inspected / Files changed:** startup, configuration-failure UI and runtime config.
- **Tests added:** widget rendering, invalid runtime short-circuit, Firebase failure, invalid staging definitions, valid staging definitions.
- **Rules impact / Migration impact:** none.
- **Commands executed / Exact evidence:** five explicit startup tests and full suite pass; debug APK builds.
- **Remaining risk / Final verdict:** real Firebase outage display is a device-gate exercise; source blocker resolved.

### P1-07 — Release and staging evidence

- **Issue ID / Severity / Status:** P1-07 / P1 / `ENVIRONMENT_BLOCKED`.
- **Production path:** Android Gradle signing/build types, runtime definitions, Firebase identity, Worker/R2 endpoints and build artifacts.
- **Symptom / Reproduction:** no authorized staging target/signing inputs exist; environment-name checks alone could previously be misreported as a staging build.
- **Root cause / Required invariant:** deployment authorization and signing material are external; release must use non-debug signing, Firebase/R2/Worker live modes, an approved staging project, five approved endpoints, SHA registration, endpoint contract checks, and an existing current artifact.
- **Files inspected / Files changed:** `android/app/build.gradle.kts`, `proguard-rules.pro`, Gradle settings/wrapper, runtime configs, Firebase options, `google-services.json`, README and prior reports; Gradle now fails closed without signing.
- **Tests added:** startup runtime-definition tests; actual debug build and release dry-run signing-guard evidence.
- **Rules impact / Migration impact:** none; no secret or key was committed.
- **Commands executed / Exact evidence:** all four signing variables and six candidate staging-target variables are unset; zero release credential files; zero Android OAuth certificate-hash entries; checked-in project `optivus-lifeos` matches Firebase options but is unclassified; release dry-run fails closed.
- **Remaining risk / Final verdict:** staging identity, SHA-1/SHA-256 registration, five endpoint deployments/contracts and release artifact are unverified; issue remains environment-blocked.

## Migration strategy

No destructive migration is authorized or required by this change set.

- Legacy draft, bundle, and job decoders accept known string timestamps and
  legacy stage/status aliases only for reads, then emit the canonical schema on
  the next safe write.
- Region and preference saves are full replacements, removing legacy unknown
  fields instead of preserving them through merge semantics.
- Recovery distinguishes verified, partial, missing, corrupt, migration, and
  owner-mismatch states. It never manufactures completed input.
- Deterministic Routine/History/Habit IDs make retries idempotent. Existing
  onboarding-owned records may be verified or safely repaired; source-conflict
  and user-modified records fail closed.
- Rules remain owner-scoped and strict. Cross-user and unknown-field writes are
  denied throughout migration.

## Android and staging evidence

- Namespace/application ID: `com.nairitroy.optivus`.
- Google Services Android package: matching `com.nairitroy.optivus` client.
- Checked-in Firebase project: `optivus-lifeos`; category `unclassified`, not
  accepted as an approved staging identity.
- AGP 8.11.1; Kotlin 2.2.20; Gradle 8.14; Java source/target 17; build JDK 21.
- Release signing: environment-backed `optivusRelease`; debug signing is not
  referenced; missing variables fail release configuration.
- R8/resource shrinking: enabled for release with optimized default ProGuard
  plus `android/app/proguard-rules.pro`.
- Fresh debug artifact: `build/app/outputs/flutter-apk/app-debug.apk`,
  192,473,311 bytes.
- A stale `build/app/outputs/flutter-apk/app-release.apk` exists from
  2026-08-02, is 72,956,841 bytes, predates this closure, and is explicitly not
  accepted as Phase 4.6.4 staging evidence.
- Redacted staging command template is documented in README. It was not run
  because substituting development, placeholder, repeated, or unapproved
  endpoints would fabricate evidence.

## Remaining P2/P3 debt

- Flutter warns that the project and `image_picker_android` still apply the
  Kotlin Gradle Plugin; a future Flutter version requires Built-in Kotlin.
- 28 dependencies have newer versions outside current constraints.
- The active Coach screen remains locally deterministic even though runtime
  configuration requires a Coach endpoint for live builds.
- Physical-device, remote Firebase, real R2, Worker deployment, and two-account
  journey evidence are deliberately deferred to the separate controlled device
  gate after staging authorization.

## Smallest safe next action

Provide an approved staging authorization record containing: the exact staging
Firebase project, five distinct service URLs where architecture requires
separation, release keystore access through the four environment variables,
and registered release SHA-1/SHA-256 fingerprints. Then verify endpoint health
and response contracts, run the documented release command, record the current
artifact path/size/signing identity, and rerun the final gate. Do not begin
Phase 5 from this report.
