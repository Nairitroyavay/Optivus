# OPTIVUS Phase 4.6.4 Initial Audit

Audit date: 2026-08-03 (Asia/Kolkata)  
Authority: initial, pre-implementation audit for Phase 4.6.4  
Production-code state: untouched for this audit  
Allowed initial statuses: `NOT_VERIFIED`, `FAIL`, `ENVIRONMENT_BLOCKED`, `PASS_WITH_EVIDENCE`

## 1. Git baseline

- Status: `PASS_WITH_EVIDENCE`
- Repository: `/Users/roy/optivus2/Optivus`
- Branch: `main`
- HEAD: `7cbd617ae5a617c6f05b3534573f1be7ccdc9dd1`
- Initial `git status --short`: empty.
- Initial `git diff --stat`: empty.
- Status after all read-only baseline commands and the debug build: empty.
- No repository `AGENTS.md` was found.
- No production file was edited before this report was created.

## 2. Compilation, formatter, analyzer and test baseline

| Check | Initial status | Exact evidence |
|---|---|---|
| `flutter pub get` | `PASS_WITH_EVIDENCE` | Exit 0; dependencies resolved; 28 packages have newer incompatible versions. |
| `dart format --output=none --set-exit-if-changed .` | `FAIL` | Reported 11 files as changed out of 451. `--output=none` made no edits. Affected files: `lib/app/configuration_failure_app.dart`, `lib/features/recovery/models/onboarding_recovery_models.dart`, `lib/features/recovery/screens/onboarding_recovery_screen.dart`, `lib/services/onboarding_completion_job_service.dart`, `lib/state/auth_state.dart`, and six test files. |
| `flutter analyze` | `PASS_WITH_EVIDENCE` | Exit 0; “No issues found!” in 9.1 seconds. |
| `flutter test` | `PASS_WITH_EVIDENCE` | Exit 0; 889 tests passed in about 56 seconds. This count alone does not establish the Phase 4.6.4 invariants. |
| Firestore emulator suite | `PASS_WITH_EVIDENCE` | Actual repository command used Firebase CLI 15.19.0 with Java 21.0.10; `tests/firestore_rules.test.js`: 27 passed, 0 failed/skipped. Fixtures do not match the required exact serializers (notably completion job and bundle), so contract equivalence is `FAIL`. |
| `flutter build apk --debug` | `PASS_WITH_EVIDENCE` | Exit 0; Gradle `assembleDebug` completed in 6.9 seconds. Artifact: `build/app/outputs/flutter-apk/app-debug.apk`, 192,451,417 bytes. Flutter warned that the project and `image_picker_android` still apply the Kotlin Gradle Plugin. |
| Configured staging build | `NOT_VERIFIED` | Not attempted before contract remediation. |

## 3. Complete production-path map

1. Bootstrap: `lib/main.dart` loads dotenv, calls `OptivusRuntimeConfig.validateForStartup()`, initializes Firebase, constructs Firebase repositories/providers, and runs `ProviderScope(child: OptivusApp())`.
2. Authentication: Firebase auth state feeds `AuthNotifier` in `lib/state/auth_state.dart`; sign-up creates the root user document, and sign-in/restore reloads profile, preferences, onboarding draft/bundle, projection receipt and controller state.
3. Settings: `FirestoreProfileRepository` persists full `UserProfile` at `/users/{uid}`, profile settings at `/users/{uid}/profile/main`, region localization at `/users/{uid}/settings/regionLocalization`, and app preferences at `/users/{uid}/settings/appPreferences`.
4. Onboarding UI/state: onboarding screens mutate `OnboardingNotifier`; draft saves flow through `OnboardingDraftSaveCoordinator` and `FirestoreOnboardingRepository` to `/users/{uid}/onboarding/draft`.
5. Completion entry: `OnboardingCompletionService.completeOnboarding` builds a `CompletionBundle`, flushes pending draft work, writes the final draft, persists/reloads a completion job, and invokes staged persistence/projection.
6. Bundle/profile transaction: `FirestoreOnboardingRepository.saveCompletionBundleAndProfilePatch` writes `/onboarding/completionBundle` and currently writes `userProfilePatch` to `/profile/main`.
7. Routine projection: completion job service writes deterministic `routineItems`, maintains `/routineProjections/onboarding-initial-v1`, and uses `RoutineOnboardingEventProjector` for append-only `/routineEvents` records.
8. Habit projection/frontend hydration: `OnboardingFrontendHydrationService` reloads Routine state, reconciles `/habitSystems`, validates ID presence, and reloads Habit controllers; `/habitSystemProjections` stores projection metadata.
9. Profile finalization: `OnboardingCompletionJobService` currently writes a full `UserProfile` to `/profile/main`, updates local profile state, then marks the job complete. A separate `AuthNotifier.markOnboardingComplete` path can finalize the root profile independently.
10. Router/home: auth/profile completion state selects onboarding, recovery, or the authenticated home shell.
11. Restart/recovery: `AuthNotifier._restoreUserData` reads root profile, draft, bundle, projection receipt and frontend data; inconsistency creates recovery actions. `OnboardingCompletionService.recoverCompletionState` can currently rebuild artifacts and fabricate a completed draft.
12. Sign-out/account switch: auth state is cleared and static completion entries are removed, then the next Firebase user is restored. Already-running futures are not cancelled or fenced by auth/operation generation.

## 4. Firestore contract table

| Artifact/path | Active writer/serializer | Rules contract | Initial status |
|---|---|---|---|
| `/users/{uid}` full profile | `UserProfile.toFirestoreMap`; `FirestoreProfileRepository.saveUserProfile` | `validUserProfile` | `PASS_WITH_EVIDENCE` for the repository writer; `FAIL` because other finalization writers target `/profile/main`, and the completion patch includes unsupported `source`. |
| `/users/{uid}/profile/main` profile settings | `ProfileSettings.toMap`; profile repository | `validProfileSubdoc` | `FAIL`: active completion paths write full/full-ish profile data here. |
| `/users/{uid}/settings/regionLocalization` | `RegionSettings.toFirestoreMap` | `validRegionLocalization` | `FAIL`: serializer has the intended 19 settings and timestamps but no explicit schema version; Rules validate owner only and do not enforce exact field types/schema. |
| `/users/{uid}/settings/appPreferences` | `UserPreferences.toFirestoreMap` plus repository-added `uid` | `validAppPreferences`/settings rule | `FAIL`: serializer includes unrelated profile fields (`id`, `bio`, `avatarUrl`, `theme`), does not itself own the full canonical owner/timestamp contract, and merge writes can preserve unknown/legacy fields. |
| `/users/{uid}/onboarding/draft` | `OnboardingDraft.toMap` | `validOnboardingDraft` | `FAIL`: active writer stores string timestamps; model has no durable revision or source fingerprint; readback does not prove schema/revision/fingerprint/content equality. |
| `/users/{uid}/onboarding/completionBundle` | `CompletionBundle.toMap` | `validOnboardingCompletionBundle` | `FAIL`: active write uses ISO strings while Rules require server timestamps on create; bundle lacks source fingerprint, draft revision and canonical expected/generated ID sets. Emulator uses a hand-built fixture with server timestamps, not the production serializer. |
| `/users/{uid}/onboardingCompletionJobs/current` | `OnboardingCompletionJob.toMap` | `validOnboardingCompletionJob` | `FAIL`: production uses legacy `uid`, coarse stage names, `in_progress`, schema v1 and string timestamps; required owner/stage/status/accounting contract is absent. Emulator repeats the legacy fixture rather than exact serialized output. |
| `/users/{uid}/routineItems/{id}` | routine record Firestore serializer | routine item Rules | `NOT_VERIFIED`: deterministic IDs exist, but completion accounting does not perform the required full metadata readback for every expected entity. |
| `/users/{uid}/routineProjections/onboarding-initial-v1` | projection receipt serializer | projection Rules | `PASS_WITH_EVIDENCE` only for existing receipt transition tests; `FAIL` as proof of actual History documents. |
| `/users/{uid}/routineEvents/{id}` | `RoutineOnboardingEventProjector` | append-only event Rules | `FAIL`: records are events rather than the required Routine History occurrences; top-level projection/source/fingerprint proof is incomplete; completed receipt can short-circuit without reading documents. |
| `/users/{uid}/routineHistory/{id}` | normal routine occurrence repository | occurrence Rules | `FAIL`: onboarding completion does not project or verify the required History occurrence set here. |
| `/users/{uid}/habitSystems/{id}` | habit-system repository | habit-system Rules | `FAIL`: IDs are read back, but owner/projection/source/schema/fingerprint and full content are not verified; source fingerprint is absent. |
| `/users/{uid}/habitSystemProjections/{id}` | habit projection serializer | habit projection Rules | `NOT_VERIFIED`: receipt existence is not accepted as proof of each Habit document. |

## 5. Exact serializer-versus-Rule mismatches

- `OnboardingCompletionJob.toMap()` writes `uid`, `status: in_progress`, coarse stages and ISO timestamps. The required contract uses one canonical owner key, exact camelCase status values, the fine-grained stage enum, real created/existing/repaired/failed accounting, and Firestore timestamps. Current Rules and emulator fixture accept the old alternative.
- `CompletionBundle.toMap()` writes ISO top-level timestamps. `validOnboardingCompletionBundle` requires create timestamps equal to `request.time`. `CompletionBundle.toFirestoreMap()` exists but is not used by the repository transaction. Nested records also remain string-timestamp maps.
- `OnboardingDraft.toMap()` is used for active writes although a Firestore conversion exists. Rules tolerate this, but the required durable contract demands a revision and source fingerprint that neither serializer nor Rules currently requires.
- The completion bundle’s `userProfilePatch` includes `source`; root profile Rules do not allow that key. The transaction instead writes the patch to `/profile/main`, whose strict settings Rule rejects its profile fields (`uid`, lifecycle and onboarding fields, life/body/coach data).
- Final job persistence calls `profile.toFirestoreMap()` but writes the result to `/profile/main`; `validProfileSubdoc` rejects the full root model.
- Region localization has an owner field and intended settings values but no schema version; Rules only enforce `userId == uid`, leaving types and exact schema underconstrained.
- App preferences serialize legacy profile presentation fields and repository-added fields rather than a single exact owned preferences schema. Merge semantics can retain fields the canonical serializer no longer intends.
- Current Rules permit timestamp strings in multiple onboarding contracts, while exact production closure requires Firestore timestamp values for owned server artifacts.

## 6. Exact recovery paths capable of completing onboarding

1. `OnboardingCompletionService.recoverCompletionState` Tier 2: any saved draft is copied with `onboardingCompleted: true` and last-step state, then a completion bundle is generated. This can promote a partial draft.
2. The same method Tier 3: when only a profile exists, it synthesizes a completed draft from profile/default values, saves a bundle, and returns synthesized recovery.
3. `AuthNotifier._restoreUserData`: an incomplete profile with no draft causes a partial draft to be synthesized from profile data and persisted rather than entering an explicit missing-setup recovery state.
4. `AuthNotifier.executeRecoveryAction`: retry-network and repair-projection paths can fall through to `recoverCompletionState`, activating the two fabrication tiers.
5. `MigrateLegacySetupAction` and `ResetSetupSafelyAction` both reduce to marking onboarding incomplete rather than executing clearly separated migration versus confirmed reset semantics.
6. `AuthNotifier.markOnboardingComplete` can update root completion independently of the full job verification/finalization gate.

All six paths are `FAIL` against the non-fabrication/finalization invariants until removed or fenced.

## 7. Current persisted completion stages

Current job stages are:

`init → persistDraft → persistBundle → projectRoutines → projectHabits → updateProfile → completed`

Current statuses are:

`pending`, `inProgress` (serialized as `in_progress`), `completed`, `failed`.

The current stages combine persistence and verification, conflate Routine reconciliation with History projection, conflate Habit persistence with frontend verification, and do not persist separate verification gates. They do not match the required sequence:

`validateInput → persistDraft → verifyDraft → persistBundle → verifyBundle → reconcileRoutines → verifyRoutines → projectRoutineHistory → verifyRoutineHistory → reconcileHabitSystems → verifyHabitSystems → reloadControllers → verifyFrontendState → finalizeProfile → completed`.

Initial status: `FAIL`.

## 8. Current History and Habit verification behavior

- Routine History: onboarding emits deterministic append-only `/routineEvents` created/repaired events. If the projection receipt is already complete, the projector returns the expected IDs without fetching those event documents. After a new commit it likewise trusts applied IDs without full document readback. It does not create/verify onboarding occurrences in `/routineHistory`. Initial status: `FAIL`.
- Mixed create/repair: the event type can distinguish created versus edited/repaired items, but the completion job does not persist complete created/existing/repaired History sets and does not validate all record metadata. Initial status: `FAIL`.
- Habits: expected systems are reconciled, fetched, and compared by ID; the controller is reloaded and visible IDs are compared. Owner, projection ID, source ID, schema version, fingerprint and complete content are not checked. Existing records with conflicting metadata can therefore satisfy the current test. Initial status: `FAIL`.
- Completion accounting: `expectedHistoryIds` can be populated from event expectations while hydration returns no actual History verification data; created/existing/repaired History distinctions are missing. Initial status: `FAIL`.

## 9. Current sign-out and async-cancellation behavior

- `AuthNotifier` has a backend restore generation, but no canonical auth generation plus per-operation generation captured across completion, recovery and AI workflows.
- Completion uses a static `_inFlight` map. Sign-out removes map entries but cannot cancel an already-running future or prevent it from resuming writes/local notifier updates.
- Local providers are cleared during signed-out reset, but stale completion/recovery results are not consistently rejected against both UID and captured generation.
- Account-switch isolation is therefore not established even though basic provider clearing exists.
- AI import/result flows still require an explicit stale-result audit and generation fencing.

Initial status: `FAIL`.

## 10. Current startup and release configuration

- `OptivusRuntimeConfig.validateForStartup()` is called before the guarded startup block; a thrown configuration error can occur before `ConfigurationFailureApp` is mounted. Status: `FAIL`.
- Firebase initialization failures only force the safe app under a conditional live-service mode; a Firebase-mode failure can continue toward Firebase-backed repositories. Raw exception text is debug-printed. Status: `FAIL`.
- Android `namespace` and `applicationId` are `com.nairitroy.optivus`; the checked-in Google Services Android package matches. Firebase project is a non-production-category project by naming/configuration, subject to staging confirmation.
- Android compiles against Java 17; the baseline toolchain used JDK 21.0.10, AGP 8.11.1, Kotlin 2.2.20 and Gradle 8.14.
- Release currently uses `signingConfigs.getByName("debug")`. Status: `FAIL`; this is not acceptable configured staging release evidence.
- Release has no established minification/R8/proguard configuration in the inspected app Gradle file. Status: `NOT_VERIFIED` as a requirement, documented release debt.
- Runtime release/staging definitions force Firebase/R2/Worker modes and require five HTTPS endpoint definitions, but distinctness/reachability has not yet been verified. Status: `NOT_VERIFIED`.
- Debug artifact exists at `build/app/outputs/flutter-apk/app-debug.apk` (192,451,417 bytes). Configured staging APK/AAB, release signing category and endpoint evidence remain `NOT_VERIFIED`.

## 11. Prioritized P0/P1 issue table

| ID | Severity | Initial status | Production symptom/root cause | Required invariant / smallest remediation |
|---|---|---|---|---|
| P0-01 Canonical UserProfile path | P0 | `FAIL` | Full/full-ish profile writes target `/profile/main`; completion patch also has unsupported `source`. Files: onboarding repository, completion job service, profile repository, profile model, Rules. | Full `UserProfile` only at `/users/{uid}`; settings only at `/profile/main`; exact serializer/Rules emulator tests. |
| P0-02 Region/AppPreferences | P0 | `FAIL` | Region Rules are underconstrained; preferences mix profile fields, repository-added ownership and merge-preserved legacy data. | Distinct exact owner/schema/timestamp contracts and complete round-trip tests. |
| P0-03 CompletionBundle | P0 | `FAIL` | Production ISO timestamps conflict with server-timestamp Rules; fingerprint/revision/expected sets absent. | One exact Firestore serializer, strict Rules, production-fixture emulator test and full readback. |
| P0-04 CompletionJob | P0 | `FAIL` | Legacy `uid`/`in_progress`, coarse state machine, incomplete accounting and string timestamps are accepted. | One exact owner/status/stage schema; deny alternate spellings/shapes; strict transitions/accounting. |
| P0-05 Unsafe recovery fabrication | P0 | `FAIL` | Partial or missing drafts can be synthesized/promoted to completed artifacts. | Recovery may resume/repair verified data only; missing data yields explicit safe recovery. |
| P0-06 Durable final draft | P0 | `FAIL` | Immediate write/readback checks only existence/UID/completion flag; no revision/fingerprint/content equality. | Flush/cancel pending work, persist final revision, and prove owner/schema/revision/fingerprint/content. |
| P0-07 Real Routine History | P0 | `FAIL` | Receipt/expected event IDs are treated as History proof; no actual History occurrence readback. | Deterministic actual History projection plus owner/projection/source/schema/fingerprint/content verification and mixed create/repair accounting. |
| P0-08 Real Habit verification | P0 | `FAIL` | ID-only repository/controller checks permit wrong metadata/content. | Verify every expected Habit document and frontend-visible set using full canonical metadata/content. |
| P0-09 Final profile integrity | P0 | `FAIL` | Wrong-path final write; parallel public completion path; finalization does not depend on all exact gates. | Root profile finalization last, once, after durable verified draft/bundle/Routine/History/Habit/frontend success. |
| P1-01 Fine-grained persisted state machine | P1 | `FAIL` | Seven coarse stages combine writes and verification. | Implement the exact 16-stage sequence and allowed status values with retry semantics. |
| P1-02 Real completion accounting | P1 | `FAIL` | History/Habit created/existing/repaired/failed sets are missing or synthetic. | Persist only readback-derived, mutually consistent entity sets. |
| P1-03 Structured failure flow | P1 | `FAIL` | Blocking paths use free-form strings, `e.toString()`, broad catches and dropped context. | Typed stage/entity/retryability/public-message/diagnostic causes, with safe UI messages. |
| P1-04 Auth/operation generations | P1 | `FAIL` | Static in-flight future survives sign-out; UID and generation are not checked at every resume point. | Auth generation + operation generation fences for completion, recovery, restore and AI results. |
| P1-05 One recovery architecture | P1 | `FAIL` | Action classes, type dispatch and fallback recovery overlap; migration/reset semantics are conflated. | One authoritative action executor with explicit preconditions, confirmation and typed outcomes. |
| P1-06 Safe startup failure | P1 | `FAIL` | Runtime validation can throw before safe UI; Firebase failure may continue and raw diagnostics can surface in logs. | Guard the whole bootstrap and render deterministic safe configuration UI for runtime/Firebase failures. |
| P1-07 Release/staging evidence | P1 | `FAIL` | Release uses debug signing; staging artifacts/endpoints not verified. | Non-debug configured staging signing, redacted reproducible build commands, existing artifact size and verified required endpoints. |

Common issue-record fields for this initial audit:

- Reproduction/commands: the exact baseline commands in section 2 plus source/Rules inspection and serializer/fixture comparison.
- Files inspected: active models, repositories, completion/recovery/auth services, startup/runtime config, `firestore.rules`, `tests/firestore_rules.test.js`, Android Gradle/Google Services configuration, and prior Phase 4 reports.
- Files changed: this audit only.
- Tests added: none before the audit.
- Rules impact: P0-01 through P0-04, P0-06 through P0-09 and P1-01/P1-02 require Rules/fixture changes; recovery, generation and startup issues principally require Dart tests.
- Migration impact: existing legacy settings/onboarding/job/projection documents need read-compatible decoding and idempotent normalization; no destructive migration is authorized.
- Remaining risk/final verdict for every listed issue: blocker until implementation and its required automated/emulator/build evidence complete. No issue is closed by this initial report.

## 12. Exact implementation order

1. Mark all prior closure/readiness reports historical and keep the three Phase 4.6.4 reports authoritative.
2. Define canonical Firestore maps and strict Rules for root profile, profile settings, region localization and app preferences; add serializer-equivalent emulator fixtures.
3. Define canonical draft, completion bundle and completion job schemas (owner, schema, Firestore timestamps, revision/fingerprint, exact stages/statuses and accounting); retain read-compatible legacy decoding only.
4. Add contract/negative emulator tests first, including cross-user, unknown field, wrong owner, wrong timestamp, legacy `uid`/`in_progress`, invalid stage transition and immutable-finalization cases.
5. Make final-draft persistence durable and readback-verified; then make completion-bundle persistence/readback use the exact canonical serializer.
6. Replace the coarse completion flow with the exact persisted state machine and typed failure model.
7. Reconcile and fully read back Routine records; project and verify actual deterministic Routine History documents with mixed create/existing/repair accounting.
8. Reconcile and fully read back Habit records; reload controllers and verify full frontend-visible identity/metadata sets.
9. Move profile finalization to canonical root, make it last/exactly-once, and remove/bound every bypass.
10. Delete unsafe recovery fabrication; consolidate recovery actions; add safe missing/partial/corrupt data outcomes and non-destructive reset/migration behavior.
11. Add auth and operation generations to completion/recovery/restore/AI flows; prove sign-out/account-switch cancellation and stale-result rejection.
12. Guard complete startup, add safe failure UI tests, repair staging signing/configuration, verify endpoints, run formatter/analyzer/all tests/emulator/debug and configured staging builds, and write the execution/pre-device reports.

Initial executive verdict: `FAIL`. The repository is not ready for real-device testing because all known P0 and P1 contracts are not yet closed. The highest permissible eventual verdict in this phase remains `READY FOR CONTROLLED REAL-DEVICE TESTING`.
