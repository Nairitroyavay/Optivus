# Optivus Phase 4.6.7 Initial Audit

Audit date: 2026-08-04 (Asia/Kolkata)  
Audit scope: production source, Firestore Rules, existing automated tests, the Phase 4.6.7 closure prompt, and the 2026-08-03 bug/gap register.  
Audit rule: this document records the pre-implementation state. No Phase 4.6.7 production edit was made before it was saved.

## 1. Git and baseline state

| Check | Result | Status |
| --- | --- | --- |
| Branch | `main` | PASS_WITH_EVIDENCE |
| HEAD | `13d6ab3245b1eb5cc233e7da9218aa84d3e5c230` | PASS_WITH_EVIDENCE |
| `git status --short` | empty | PASS_WITH_EVIDENCE |
| `git diff --stat` | empty | PASS_WITH_EVIDENCE |
| Full analyzer/tests/Rules emulator/build at this HEAD | Not run during the audit-only phase | NOT_VERIFIED |

HEAD already contains a narrow earlier change which added a final-step **Keep both** button and a fresh-profile draft initialization. Those changes are part of this audit baseline, not evidence that the end-to-end contract is closed.

## 2. Production-path diagrams

### 2.1 Accepted overlap path

```text
BaseTimelineDraft.blocks
  -> OnboardingDraft.timelineConflictsRequiringAcceptance()
  -> broad _isOnboardingResponsibilityOverlap() exemption (unsafe)
  -> OnboardingStep11TodayReady final preview
  -> BaseTimelineDraft.acceptConflict(legacy string key)
  -> OnboardingDraft.toMap()/source fingerprint
  -> OnboardingCompletionService.buildBundle()
  -> acceptance is dropped
  -> RoutineOnboardingProjection.build() maps source item IDs to onb_* IDs
  -> no acceptance projection/write/read-back
  -> RoutineNotifier.loadForOwner()
  -> RoutineConflictEngine.detectConflicts()
  -> embedded RoutineConflictAllowance only; accepted conflicts are omitted
  -> conflict summary/timeline cannot display "allowed by user"
  -> schedule edits do not reliably invalidate onboarding keys
  -> Start Over only changes the root profile completion flag
```

Firestore path evidence:

- draft: `users/{uid}/onboarding/draft`
- bundle: `users/{uid}/onboarding/completionBundle`
- Routine templates: `users/{uid}/routineItems/{itemId}`
- projection receipt: `users/{uid}/routineProjections/{projectionId}`
- no canonical conflict-acceptance path exists

### 2.2 Completion and recovery path

```text
Firebase signup/verification
  -> AuthNotifier backend restore
  -> root profile create/fetch
  -> draft decision partly gated by createdProfile
  -> final OnboardingDraft + schema-v1 completion bundle
  -> OnboardingCompletionJobService (static global generation/in-flight map)
  -> users/{uid}/onboardingCompletionJobs/current
  -> Routine transaction/receipt
  -> Routine History projector
  -> Habit reconciliation
  -> frontend hydration without an owner/session callback
  -> profile + finalizeProfile-stage batch
  -> separate completed-job write (not one atomic truth boundary)
  -> cold restore or recovery screen
  -> exposed MigrateLegacySetupAction always throws
  -> ResetSetupSafelyAction calls markOnboardingIncomplete only
```

### 2.3 Runtime/device path

```text
main()
  -> WidgetsFlutterBinding.ensureInitialized()
  -> await immersive SystemChrome platform call
  -> await buildOptivusRoot()
       -> runtime validation
       -> await Firebase.initializeApp()
  -> runApp()
  -> auth restoration
  -> first interactive screen
  -> optional GeolocatorDeviceCountryService when requested
  -> Routine timeline sized from MediaQuery screen width
```

The platform-mode call and Firebase initialization happen before `runApp`, so the first Flutter frame is blocked. Location lookup is provider-driven rather than in `main`, which is the desired lazy boundary but is not yet device-verified.

## 3. Current conflict decision matrix

| Pair/condition | Onboarding baseline | Routine baseline | Required outcome | Status |
| --- | --- | --- | --- | --- |
| Class + breakfast/meal | Automatically exempted when both sections fall in the broad responsibility set; otherwise legacy approval by weekday | Hard-hard becomes prohibited; no projected onboarding approval | Blocking by default; recurring approval can preserve both | FAIL |
| Class + job | Automatically exempted | `unavailableTime`, Keep Both forbidden | Only allow when an explicit compatible/simultaneous policy applies | FAIL |
| Class + compatible fixed personal block | Automatically exempted | Hard-hard prohibited | Blocking by default, approval may be allowed | FAIL |
| Compatible fixed + fixed | Automatically exempted | Hard-hard prohibited | Blocking by default, approval may be allowed | FAIL |
| Sleep overlap | Can be swallowed by the broad `fixed` exemption | Onboarding sleep projects as `fixed`, while the engine recognizes only category `sleep` | Always blocking; Keep Both forbidden | FAIL |
| Invalid/zero duration | Onboarding validation is separate | Routine blocks as invalid schedule | Always blocking | PASS_WITH_EVIDENCE |
| Hard + hard generally | Broad exemption for selected sections; otherwise warning | Always prohibited | Never globally permit; shared pair policy decides | FAIL |
| Soft/informational | Mostly omitted from hard-conflict list | Informational classifications exist | Preserve only when shared policy says coexistence is safe | NOT_VERIFIED |
| Valid user allowance | Legacy key suppresses final blocker | Matching embedded allowance executes `continue`, removing the conflict from output | Emit explicit `allowedByUser`; exclude from blocker count but keep visible | FAIL |
| Stale/malformed/wrong-owner allowance | Key is not schedule-bound | Partial schedule fingerprint and no owner in embedded allowance | Must never authorize | FAIL |

There is no shared domain policy. Onboarding policy is in `lib/models/onboarding_draft.dart`; Routine policy is in `lib/features/routine/services/routine_conflict_engine.dart`.

## 4. Draft, bundle, Routine, and allowance schema comparison

| Contract | Baseline schema/storage | Semantics present | Missing/unsafe | Status |
| --- | --- | --- | --- | --- |
| Onboarding draft | schema 2, `baseTimeline.acceptedConflictKeys: List<String>` | pair source IDs + weekday | owner, scope, timezone, recurrence set, full schedule fingerprints, lifecycle, projection/run binding | FAIL |
| Completion bundle | schema 1 | source fingerprint; expected Routine/History/Habit IDs | acceptances, run ID/generation, expected acceptance IDs/accounting | FAIL |
| Routine template | schema 1, embedded `allowedConflicts`, max 10 in Rules | pair ID, date, type, partial fingerprint | recurring approval, owner, acceptance lifecycle, projection/source binding; cap is incompatible with recurrence | FAIL |
| Projection receipt | schema 1 | deterministic projected item IDs and item accounting | acceptance accounting | FAIL |
| Completion job | schema 2 at fixed `current` path | stage accounting for Routine/History/Habit | run lifecycle and acceptance accounting | FAIL |
| Canonical acceptance | absent | none | entire versioned owner-scoped contract | FAIL |

Backward compatibility must be reader-only for `acceptedConflictKeys`; new writes must use one canonical, dedicated acceptance schema rather than both embedded allowances and `syncAllowances`.

## 5. Source ID to projected ID mapping

`RoutineOnboardingProjection` currently computes a stable ID with a SHA-256 input equivalent to `routine-onboarding-v1|ownerUid|sourceKey`, prefixes it with `onb_`, and keeps `onboardingSourceItemId` on the projected Routine template. The projection ID is fixed as `onboarding-initial-v1`.

| Source value | Projected value | Round-trip evidence | Status |
| --- | --- | --- | --- |
| base/final Routine source item ID | deterministic `onb_<40 hex>` | `RoutineItem.onboardingSourceItemId` | PASS_WITH_EVIDENCE |
| source pair | projected pair | no pair/acceptance projection | FAIL |
| source schedule fingerprint | projected schedule fingerprint | absent | FAIL |
| bundle fingerprint | receipt fingerprint | present for Routine item receipt | PASS_WITH_EVIDENCE |
| run/revision identity | projected documents | fixed projection ID does not define a run lifecycle | FAIL |

## 6. Serializer, Rules, and emulator fixture table

| Document | Production serializer | Rules validator | Existing fixture coverage | Status |
| --- | --- | --- | --- | --- |
| Onboarding draft | `OnboardingDraft.toFirestoreMap()` | `validOnboardingDraft`, exact top-level keys but shallow nested maps | draft tests exist; no structured acceptance fixture | FAIL |
| Completion bundle | `OnboardingCompletionBundle.toFirestoreMap()` | `validOnboardingCompletionBundle`, schema 1 and shallow nested lists/maps | bundle Rules coverage exists | FAIL |
| Routine template | `RoutineTemplateFirestoreCodec` | `validRoutineTemplate`, embedded allowance schema 1/max 10 | `tests/firestore_rules.test.js` has a v1 allowance fixture | FAIL |
| Completion job | `OnboardingCompletionJob.toFirestoreMap()` | `validOnboardingCompletionJob` + transition validator | fixed-current lifecycle fixtures exist | FAIL |
| Conflict acceptance | absent | absent | absent | FAIL |
| Onboarding run | absent | absent | absent | FAIL |

Rules disallow deletion of draft, bundle, and completion jobs. A real reset therefore needs a versioned run/tombstone or an explicitly validated reset transition; it cannot be implemented as client deletion under the current policy.

## 7. Job lifecycle and Rules-transition table

| Transition/operation | Service behavior | Rules behavior | Status |
| --- | --- | --- | --- |
| New job | creates `current` at `validateInput` | allowed only pending/running and empty completed stages | PASS_WITH_EVIDENCE |
| Advance stage | marks prior stage and advances one rank | monotonic rank, maximum +1 | PASS_WITH_EVIDENCE |
| Retry same run | reuses same fingerprint/revision | same-stage update is possible while not completed | NOT_VERIFIED |
| Changed draft/new setup | service can replace/reinitialize fixed `current` | transition requires immutable fingerprint/revision/schema | FAIL |
| Retry after completed | service path still resolves to fixed `current` | updates forbidden when previous status is completed | FAIL |
| Finalize profile | profile and job with `finalizeProfile` completed are batched | individual documents validate, but cross-document terminal truth is not proven | FAIL |
| Mark job completed | separate write after profile batch | allowed only as another stage transition | FAIL (not atomic) |
| Start Over/new run | no first-class state | no legal lifecycle | FAIL |

## 8. Recovery state matrix

| Backend state | Baseline routing/action | Required safe behavior | Status |
| --- | --- | --- | --- |
| New profile + no draft | creates draft only when local `createdProfile` is true | idempotent first-run state durable across duplicate restore callbacks | FAIL |
| Existing incomplete profile + valid draft | resume draft | immediate save/read-back before navigation | FAIL |
| Existing profile + missing draft | recovery screen | typed choice: safe migration when supported or real reset | FAIL |
| Completed profile + valid projections | app | verify owner/run/accounting on cold restart | NOT_VERIFIED |
| Completed profile + partial projections | recovery | typed reason and scoped repair actions | FAIL |
| Migration offered | `MigrateLegacySetupAction` throws unconditionally | implement migration or do not expose the action | FAIL |
| Start Over | only marks profile incomplete | new run generation, reset/supersede old setup-owned data and acceptances | FAIL |
| Restore error | some messages interpolate exception/failure text | public typed message, private structured diagnostic only | FAIL |

## 9. Async ownership and cancellation map

| Boundary | Current guard | Gap | Status |
| --- | --- | --- | --- |
| Auth restore | `_backendRestoreGeneration` / `_authOperationGeneration` at outer boundaries | nested hydration does not receive or check the session token around every mutation | FAIL |
| Completion job | static `_operationGeneration`; static `_inFlight` keyed partly by owner/fingerprint | starting any operation invalidates other owners globally; static state spans provider lifetimes | FAIL |
| Frontend hydration | none inside `reloadControllers` | can mutate old/new account providers after sign-out or switch | FAIL |
| Routine load | owner UID and in-flight UID/generation checks | failure state uses `e.toString()` and acceptance restore is absent | FAIL |
| Habit reconciliation | multiple silent `catch (_) {}` paths | failed writes can be suppressed and later accounting trusted | FAIL |
| Skin-care async work | local mounted checks exist in UI; several silent catches/debug prints remain | owner/operation isolation and privacy-safe logging not proven end-to-end | NOT_VERIFIED |

The minimum safe contract is an immutable operation context containing owner UID, auth generation, run ID, operation ID, and an `isCurrent` callback checked before and after every await and immediately before every frontend/provider mutation.

## 10. Startup critical-path timing map

| Phase | Before first frame? | Instrumented? | Status |
| --- | --- | --- | --- |
| Flutter binding | yes | no | PASS_WITH_EVIDENCE |
| immersive system UI platform call | yes, awaited | only fallback logging | FAIL |
| runtime configuration validation | yes | no duration metric | FAIL |
| Firebase initialization | yes, awaited | generic debug message | FAIL |
| `runApp` / safe failure root | after all above | startup type-only error log | FAIL |
| auth restoration | after root | sequential portions and limited timing evidence | FAIL |
| Geolocator country lookup | lazy service/provider | not device-verified | NOT_VERIFIED |
| Routine timeline layout | interactive path | uses screen `MediaQuery` width, not parent constraints | FAIL |
| background/foreground restoration | app lifecycle code exists in surrounding state | Realme evidence not available | NOT_VERIFIED |

## 11. P0/P1 issue register with code evidence

All Phase 4.6.7 P0 items fail at the audit baseline.

| ID | Evidence | Status |
| --- | --- | --- |
| P0-01 canonical policy | policy split between `OnboardingDraft.timelineConflictsRequiringAcceptance` and `RoutineConflictEngine` | FAIL |
| P0-02 structured acceptance | `TimelineConflictDraft.keyFor` produces a weekday/source-ID string | FAIL |
| P0-03 recurring UX | final step renders one action per detected day; no grouped recurrence scope | FAIL |
| P0-04 completion projection | bundle/projection have no acceptance field/path | FAIL |
| P0-05 Routine resolution state | valid embedded allowance causes engine `continue`; no `allowedByUser` result | FAIL |
| P0-06 overlap rendering | no allowed badge; covered card first tap only changes focus | FAIL |
| P0-07 final blocker UX | validation message does not scroll/focus/edit the relevant grouped conflict | FAIL |
| P0-08 daily scheduling | `_scheduleRoutineItems` carries a mutable placement across weekdays and creates `[Tiny]` 00:00 fallback | FAIL |
| P0-09 eating merge | `mergeOverlappingEatingBlocks` unions weekdays for blocks overlapping on only one day | FAIL |
| P0-10 run lifecycle | `FirestoreUserPaths.onboardingCompletionJob` returns `.../current` | FAIL |
| P0-11 safe Start Over | `ResetSetupSafelyAction` delegates only to `markOnboardingIncomplete` | FAIL |
| P0-12 new-account restore | missing-draft initialization depends on local `createdProfile` | FAIL |
| P0-13 owner/session async | completion uses a static global generation; hydration has no session validator | FAIL |
| P0-14 atomic finalization | terminal completed job write occurs after profile/finalize-stage batch | FAIL |
| P0-15 contract/accounting | no acceptance/run accounting at finalization | FAIL |
| P1-01..04 conflict UI/layout | allowance omitted; no badge; global width; no blocker navigation | FAIL |
| P1-05..10 recovery/failures | throwing migration action, collapsed reasons, debounced resume, raw error interpolation, fake History success | FAIL |
| P1-11..14 Rules/allowance audit | shallow bundle, partial fingerprint, ambiguous pair ID, no lifecycle events | FAIL |
| P1-15..16 persistence IDs | silent Habit catches and timestamp mutation IDs found by repository search | FAIL |
| P1-17..19 startup/device | pre-frame awaits, limited instrumentation, unresolved Realme layout/performance evidence | FAIL |
| P1-20..21 Android environment | Firebase config exists; Play Services and signed staging artifact not proven | NOT_VERIFIED |
| P1-22 skin care | multiple plan transformations plus silent catches/debug logs; device consistency not proven | NOT_VERIFIED |
| P1-23..25 observability/schema | incomplete structured metrics, inconsistent error hygiene, schemas unchanged despite material contracts | FAIL |

## 12. Implementation order and file ownership plan

There is one implementation owner for this pass (Codex in the current workspace); no parallel writer is assigned. The order is chosen to keep serializer, Rules, and fixtures synchronized.

1. Add a shared conflict policy and canonical `ConflictAcceptance` model/fingerprint/legacy reader.
2. Replace draft writes with structured acceptance and group recurring onboarding conflicts; retain legacy read migration only.
3. Advance completion bundle/projection schemas, map source IDs to projected IDs, and add a dedicated owner-scoped acceptance repository/path.
4. Load canonical acceptances into Routine, emit explicit resolution state, fix blocker counts, edit invalidation, badges, card access, and parent-constrained layout.
5. Correct per-day scheduling, remove fabricated `[Tiny]` timed data, and make eating merge semantics lossless.
6. Introduce versioned onboarding run paths and a Rules-valid reset/supersession lifecycle; make first-run restore idempotent.
7. Add owner/session operation context to completion and hydration; eliminate fake persistence success and silent reconciliation failures.
8. Make terminal profile/job truth atomic and expand verifiable accounting.
9. Advance/harden Firestore schemas and emulator fixtures in the same change set.
10. Move nonessential startup work behind the first safe frame, harden typed failures/logging, and verify skin-care plan consistency.
11. Run formatter, analyzer, targeted tests, full Flutter tests, Rules emulator tests, debug APK build, artifact hashing, and re-read all touched source.
12. Produce the execution, verification, device-retest, and authoritative tracker reports. Prior closure reports will be marked historical rather than silently overwritten.

## Audit verdict

`FAIL`

The code baseline is not ready for the second controlled real-device test. The user-visible Keep Both action does preserve both source cards in one narrow onboarding case, but the decision is discarded before Routine, contradicts the Routine policy, is not securely persisted, and cannot survive the required lifecycle/recovery paths.
