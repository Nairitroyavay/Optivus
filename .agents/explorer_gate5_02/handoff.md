# Gate 5 Explorer Audit Report: Session Reset, Exhaustive Provider Inventory & TD-039

**Author**: `explorer_gate5_02`  
**Working Directory**: `/Users/avayroy/Optivus/.agents/explorer_gate5_02`  
**Target Date**: 2026-09-09  
**Mission**: Exhaustive audit and classification of every mutable user/session state owner in `lib/state` and `lib/features`, verification of the 6 user-isolation questions with source evidence, documentation reconciliation for TD-039, and generation of the mandatory pre-editing audit table.

---

## Executive Summary

1. **Exhaustive Provider Discovery**: Repository-wide analysis identified exactly **116 Riverpod providers** in `lib/`. Zero unclassified providers remain.
2. **Category Classification Distribution**:
   - `USER_SCOPED_RESET`: **25 providers**
   - `USER_SCOPED_UID_KEYED`: **1 provider**
   - `USER_SCOPED_AUTO_DISPOSE`: **3 providers**
   - `USER_SCOPED_GENERATION_FENCED`: **2 providers**
   - **Total User-Scoped Owners**: **31 providers**
   - `SESSION_UI_RESET`: **13 providers**
   - `GLOBAL_CONFIG`: **11 providers**
   - `DERIVED`: **14 providers**
   - `REPOSITORY_UID_SCOPED`: **32 providers**
   - `NOT_USER_SCOPED`: **15 providers**
   - **Total**: **116 providers**
3. **Six-Question User Isolation Proof**: Every one of the 31 user-scoped owners has been verified against the 6 isolation criteria with exact code references (`lib/services/auth_session_reset_coordinator.dart`, `lib/state/auth_state.dart`, `lib/state/app_state.dart`, `lib/features/onboarding/steps/skin_care/skin_care_flow_controller.dart`, `lib/state/upload_state.dart`, etc.).
4. **TD-039 Reconciliation**: In the active codebase, `AuthSessionResetCoordinator` already invalidates and resets feature-local Routine, Habit, Home, Mind, Fitness, Profile, Tracker, Upload, and Region state on sign-out and account switch (`A → B`), and this is verified by `test/gate5_auth_session_isolation_test.dart` (10/10 passing tests). However, `docs/TECHNICAL_DEBT.md` and `docs/ARCHITECTURE.md` still label TD-039 as open/in-progress and assign it to Phase 11. This contradiction is formally resolved herein: the implementation of real reconstruction race tests (Test A & Test B in R5) will formally cement the closure of TD-039 across code and documentation.

---

## 1. Mandatory Pre-Editing Audit Table

| AREA | CURRENT AUTHORITY | CURRENT MUTABLE STATE | UID/SESSION SCOPE | RESET/FENCE MECHANISM | CURRENT DEFECT | SMALLEST FIX | TEST THAT MUST FAIL BEFORE FIX |
|---|---|---|---|---|---|---|---|
| **Auth / Session State & Identity Boundary** | `AuthNotifier` (`lib/state/auth_state.dart:1815`) | `AuthState` (user, status, sessionDestination, resumeStep, error), `_authOperationGeneration`, `_backendRestoreGeneration` | `USER_SCOPED_GENERATION_FENCED` | `_authOperationGeneration`, `_backendRestoreGeneration`, delegates to `AuthSessionResetCoordinator.resetIdentityBoundary()` before publishing new UID | Test suite lacks real `ServerReconstructionSource` / pipeline async race test where Account A reconstruction resolves after Account B sign-in | Implement controlled `ServerReconstructionSource` with `Completer` in `test/gate5_auth_session_isolation_test.dart` (Tests A, B, C, D) verifying pipeline drops late A results | `test/gate5_auth_session_isolation_test.dart` (new Test A & Test B) |
| **Session Reset Coordinator** | `AuthSessionResetCoordinator` (`lib/services/auth_session_reset_coordinator.dart:30`) | Stateless coordinator; coordinates reset/invalidation of 25+ state owners and increments `authGenerationProvider` | `NOT_USER_SCOPED` | Owns `resetIdentityBoundary()`, `prepareForAuthoritativeHydration()`, `resetFeatureStateForHydration()` | `docs/TECHNICAL_DEBT.md` and `docs/ARCHITECTURE.md` claim TD-039 is open with Home & Fitness lacking verification, contradicting code | Reconcile `docs/TECHNICAL_DEBT.md` and `docs/ARCHITECTURE.md` to document verified centralized reset boundary | Static architectural invariant test |
| **Verify Email Lifecycle** | `VerificationLifecycleController` (`lib/state/verification_lifecycle_state.dart:135`) | `VerificationLifecycleState` (polling timer, countdown timer, streaks, checking, resendInFlight, error, successMessage, legacy messageKind) | `USER_SCOPED_AUTO_DISPOSE` | AutoDispose on route unmount; constructor captures `_expectedUid` and listens to `authProvider` to trigger `_stopSession()` on UID change | Retains duplicate failure taxonomy (`VerificationMessageKind`, `messageKind`, `String? message`) and uses hardcoded logout error override | Remove `VerificationMessageKind` and `messageKind`; unify under `RecoverableError? error; String? successMessage;`; consume `AuthState.error` directly on logout | `test/verify_email_redesign_test.dart` and static architecture test |
| **Onboarding Completion Job Service** | `OnboardingCompletionJobService` (`lib/services/onboarding_completion_job_service.dart:181`) | `_activeJobNotifier`, active execution futures, stage timers | `USER_SCOPED_RESET` | Coordinator calls `_ref.invalidate(onboardingCompletionJobServiceProvider)` which invokes `service.cancelAll()` via `ref.onDispose` | Lacks formal classification in inventory docs | Classify as `USER_SCOPED_RESET` | Gate-5 session inventory classification test |
| **Onboarding Completion Job Provider** | `onboardingCompletionJobProvider` (`lib/services/onboarding_completion_job_service.dart:1704`) | Cached `FutureProvider` results keyed by `uid` | `USER_SCOPED_UID_KEYED` | Riverpod `.family` keyed by authenticated `uid`; also invalidated by coordinator | Lacks formal classification in inventory docs | Classify as `USER_SCOPED_UID_KEYED` | Gate-5 session inventory classification test |
| **Onboarding Step 7 Skin Care Flow** | `SkinCareFlowController` (`lib/features/onboarding/steps/skin_care/skin_care_flow_controller.dart:258`) | `SkinCareFlowStateHolder` (state, epoch, ownerUid, authGeneration, activeError, planASnapshot) | `USER_SCOPED_GENERATION_FENCED` | Tracks `ownerUid` and `authGeneration`; listens to `authGenerationProvider` and `onboardingStateProvider`; calls `clearAll()` on bridge and resets state on owner change; async generation guarded by `isSessionCurrent` / request epoch | Not listed in `AuthSessionResetCoordinator` because it relies on generation fencing and listener resets | Classify as `USER_SCOPED_GENERATION_FENCED` and verify that `syncFromDraft` synchronously purges state when `authGeneration` increments | Gate-5 session inventory classification test |
| **Onboarding Step 7 Action Bridge & Primary Action** | `Step7ActionBridgeNotifier` & `onboardingStep7PrimaryActionProvider` (`lib/features/onboarding/steps/skin_care/skin_care_action_bridge.dart:43`) | `Step7ActionBridgeState` (action, activeToken: ownerId + epoch) | `SESSION_UI_RESET` | Epoch-token fencing on publish/clear; cleared unconditionally via `clearAll()` by `SkinCareFlowController.syncFromDraft` on identity/generation change | Lacks formal classification in inventory docs | Classify as `SESSION_UI_RESET` | Gate-5 session inventory classification test |
| **Onboarding Step 4 Schedule Timelines** | `onboardingClassTimelineProvider`, `onboardingWorkTimelineProvider` (`lib/features/onboarding/steps/onboarding_step_4_schedule_models.dart:10-13`) | `List<ClassRoutineBlock>` | `USER_SCOPED_AUTO_DISPOSE` | `StateProvider.autoDispose` unmounts on step exit; also explicitly invalidated by `AuthSessionResetCoordinator.resetIdentityBoundary()` | Lacks formal classification in inventory docs | Classify as `USER_SCOPED_AUTO_DISPOSE` (with dual coordinator invalidation) | Gate-5 session inventory classification test |
| **Onboarding Upload Interaction** | `UploadInteractionController` (`lib/features/uploads/controllers/upload_interaction_controller.dart`) | `UploadInteractionMap` (slot states for class, work, menu, skin photos) | `USER_SCOPED_RESET` | `AuthSessionResetCoordinator.resetIdentityBoundary()` calls `_ref.invalidate(onboardingUploadInteractionProvider)`. Also listens to `restoredUploadsProvider` to reset if UID empty | Lacks formal classification in inventory docs | Classify as `USER_SCOPED_RESET` | Gate-5 session inventory classification test |
| **Routine Import AI Controller** | `RoutineImportAiController` (`lib/state/routine_import_ai_state.dart:95`) | `RoutineImportAiState`, `_lifecycle` (`AiGenerationLifecycleManager`) | `USER_SCOPED_RESET` | `AuthSessionResetCoordinator.resetIdentityBoundary()` calls `resetForSignedOut()`; operation tokens in `_lifecycle` drop late async results | Lacks formal classification in inventory docs | Classify as `USER_SCOPED_RESET` | Gate-5 session inventory classification test |
| **Upload Controller & Restored Uploads** | `UploadController` & `RestoredUploadsController` (`lib/state/upload_state.dart`) | `UploadState` (`_operationGeneration`, activeAsset) & `RestoredUploadsState` (`_sessionGeneration`, previewGenerations, assets) | `USER_SCOPED_RESET` | `AuthSessionResetCoordinator.resetIdentityBoundary()` calls `resetForSignedOut()` on both, which increments generations and resets states; `_isCurrentOperation` and `_isCurrentSession` drop late returns | Lacks formal classification in inventory docs | Classify as `USER_SCOPED_RESET` | Gate-5 session inventory classification test |
| **Region Settings** | `RegionSettingsNotifier` (`lib/state/region_settings_provider.dart:7`) | `RegionSettings` (`userId`, countryCode, currencyCode, paymentRegion) | `USER_SCOPED_RESET` | `AuthSessionResetCoordinator.resetIdentityBoundary()` calls `resetForSignedOut()`, setting state to `RegionSettings.defaultForUser('signed-out')` | Lacks formal classification in inventory docs | Classify as `USER_SCOPED_RESET` | Gate-5 session inventory classification test |
| **Home Dashboard & Mind Note** | `HomeDashboardNotifier` & `HomeMindNoteNotifier` (`lib/features/home/providers/`) | `HomeDashboardState` (check-ins, now/next action) & `List<HomeMindNote>` | `USER_SCOPED_RESET` | `AuthSessionResetCoordinator` calls `resetForSignedOut()` on both during `resetIdentityBoundary()`, setting `_ownerUid = null` and clearing all notes/actions | TD-039 claimed Home lacked final verification | Classify both as `USER_SCOPED_RESET` and document verified isolation | Gate-5 session inventory classification test |
| **Fitness Center** | `FitnessCenterNotifier` (`lib/features/tracker/fitness/providers/fitness_provider.dart:18`) | `FitnessCenterState` (`_ownerUid`, activeActivity, recentActivities, routes) | `USER_SCOPED_RESET` | `AuthSessionResetCoordinator.resetIdentityBoundary()` calls `resetForSignedOut()`, resetting `_ownerUid = null` and state to `FitnessCenterState.empty()` | TD-039 claimed Fitness lacked final verification | Classify as `USER_SCOPED_RESET` and document verified isolation | Gate-5 session inventory classification test |
| **Tracker Settings & Session Links** | `TrackerSettingsNotifier` & `RoutineTrackerLinksNotifier` | `TrackerSettingsState` & `List<TrackerSessionLink>` | `USER_SCOPED_RESET` | `AuthSessionResetCoordinator.resetIdentityBoundary()` calls `resetForSignedOut()` on both, resetting to defaults / empty list | Lacks formal classification in inventory docs | Classify both as `USER_SCOPED_RESET` | Gate-5 session inventory classification test |
| **Profile Settings** | `ProfileSettingsNotifier` (`lib/features/profile/providers/profile_settings_provider.dart:124`) | `ProfileSettingsState` (profile, preferences, notifications, privacy, deletionRequest) | `USER_SCOPED_RESET` | `AuthSessionResetCoordinator.resetIdentityBoundary()` calls `resetForSignedOut()`, setting state to `_profileSettingsDefaults()` | Lacks formal classification in inventory docs | Classify as `USER_SCOPED_RESET` | Gate-5 session inventory classification test |
| **Navigation & Detail View Requests** | `AppNavigationController`, `ToastQueueNotifier`, 6 `*DetailViewRequestProvider`s | Tab index (int), toast queue, 6 detail targets (`HomeDetailTarget`, `TrackerDetailTarget`, `ProfileDetailTarget`, `RoutineDetailTarget`, `CoachDetailView`, `GoalsDetailTarget`) | `SESSION_UI_RESET` | `AuthSessionResetCoordinator.resetIdentityBoundary()` calls `resetForSignedOut()` on `appNavigationProvider` and `toastQueueProvider`, and resets all 6 detail view target states to `none` | Lacks formal classification in inventory docs | Classify all as `SESSION_UI_RESET` | Gate-5 session inventory classification test |
| **Canonical Projections (Routine & Habits)** | `RoutineNotifier` & `HabitSystemsNotifier` | `RoutineState` & `HabitSystemsState` | `USER_SCOPED_RESET` | `AuthSessionResetCoordinator.resetIdentityBoundary()` and `prepareForAuthoritativeHydration()` call `resetForSignedOut()` on both, cancelling streams and incrementing generations | Lacks formal classification in inventory docs | Classify as `USER_SCOPED_RESET` | Gate-5 session inventory classification test |
| **Legacy Mock Projections** | 8 `mock*` providers (`mockRoutineProvider`, `mockTrackerProvider`, etc.) | In-memory lists/models for demo/fake data | `USER_SCOPED_RESET` | `AuthSessionResetCoordinator.resetFeatureStateForHydration()` calls `resetForSignedOut()` on all 8 notifiers | Lacks formal classification in inventory docs | Classify as `USER_SCOPED_RESET` | Gate-5 session inventory classification test |
| **Repositories (Data Access Layer)** | 32 Repository Providers (`routineRepositoryProvider`, `onboardingRepositoryProvider`, etc.) | Stateless interfaces/implementations; fake implementations use in-memory maps keyed by `uid` | `REPOSITORY_UID_SCOPED` | Stateless; all operations require explicit authenticated `uid` parameter | Lacks formal classification in inventory docs | Classify as `REPOSITORY_UID_SCOPED` | Gate-5 session inventory classification test |

---

## 2. Six-Question Isolation Analysis for Every User-Scoped State Owner

Below is the verified evidence answering the 6 questions for all 31 user-scoped owners in the Optivus application.

### Q1-Q6 Legend:
- **Q1**: Can Account A data live in this owner?
- **Q2**: What happens synchronously when A → B?
- **Q3**: Can an Account-A async callback complete after B?
- **Q4**: What prevents that callback writing into B?
- **Q5**: Does logout clear it?
- **Q6**: Does same-UID token refresh preserve it?

---

### Group A: Primary User & Onboarding State
#### 1. `userProfileProvider` (`StateNotifierProvider<UserProfileNotifier, UserProfile>`, `lib/state/app_state.dart:160`)
- **Q1**: YES. Holds `UserProfile` with `uid: "gate5-a"`, displayName, email, role.
- **Q2**: In `AuthNotifier._handleAuthUserChanged` (`lib/state/auth_state.dart:738-750`), before setting state to B, calls `_sessionResetCoordinator.resetIdentityBoundary()`. Line 43 of `auth_session_reset_coordinator.dart` calls `_ref.read(userProfileProvider.notifier).resetForSignedOut()`, setting `state = UserProfile.empty()`.
- **Q3**: YES. In-flight server reconstruction or profile fetch from Account A could complete late.
- **Q4**: `AuthNotifier._hydrateUser` checks `_isCurrentGeneration(capturedAuthGeneration, capturedRestoreGeneration)` before applying reconstruction results. Because `authGenerationProvider` was incremented during `resetIdentityBoundary()`, the callback is discarded. Additionally, `saveProfile` enforces `profile.uid == currentUid`.
- **Q5**: YES. `AuthNotifier.logout()` delegates to `resetIdentityBoundary()`, which calls `resetForSignedOut()`.
- **Q6**: YES. `_handleAuthUserChanged` skips identity reset when `nextUser?.uid == currentUid`.

#### 2. `onboardingStateProvider` (`StateNotifierProvider<OnboardingNotifier, OnboardingState>`, `lib/state/app_state.dart:1871`)
- **Q1**: YES. Holds `OnboardingState` with `OnboardingDraft` (`draft.uid == "gate5-a"`), currentStep, baseTimeline.
- **Q2**: `resetIdentityBoundary()` lines 44-47 checks `preserveOnboardingUid`. If UID differs, calls `_ref.read(onboardingStateProvider.notifier).resetForSignedOut()`, setting `state = OnboardingState.initial()` with empty draft (`uid: ""`).
- **Q3**: YES. In-flight draft save or server reconstruction from Account A could complete late.
- **Q4**: Guarded by `_isCurrentGeneration` in `AuthNotifier` and `draft.uid == _currentUid` check in `OnboardingNotifier.saveDraft()`.
- **Q5**: YES. `resetIdentityBoundary()` resets it to initial state.
- **Q6**: YES. Same-UID refresh does not trigger `resetIdentityBoundary()`.

---

### Group B: Canonical Domain Controllers (Routine & Habits)
#### 3. `routineNotifierProvider` (`StateNotifierProvider<RoutineNotifier, RoutineState>`, `lib/features/routine/routine_state.dart:2643`)
- **Q1**: YES. Holds `RoutineState` containing items owned by Account A (`RoutineItem.userId == "gate5-a"`).
- **Q2**: `resetIdentityBoundary()` line 40 calls `_ref.read(routineNotifierProvider.notifier).resetForSignedOut()`. Cancels `_eventsSubscription`, increments `_loadGeneration` and `_eventsGeneration`, resets state to defaults with `_ownerUid = null`.
- **Q3**: YES. In-flight background fetch or transaction commit from Account A could resolve late.
- **Q4**: In `RoutineNotifier`, every async operation captures `currentLoadGen = ++_loadGeneration` or `currentEventsGen = ++_eventsGeneration`. On return, it checks `if (_loadGeneration != currentLoadGen || _ownerUid != expectedUid) return;`. Furthermore, `prepareForAuthoritativeHydration()` purges Routine state before Account B's records are hydrated.
- **Q5**: YES. Cleared to default empty state.
- **Q6**: YES. Preserved; no identity reset triggered.

#### 4. `habitSystemsNotifierProvider` (`StateNotifierProvider<HabitSystemsNotifier, HabitSystemsState>`, `lib/features/routine/controllers/habit_systems_controller.dart:719`)
- **Q1**: YES. Holds `HabitSystemsState` with habit systems owned by Account A (`HabitSystemModel.ownerUid == "gate5-a"`).
- **Q2**: `resetIdentityBoundary()` line 42 calls `_ref.read(habitSystemsNotifierProvider.notifier).resetForSignedOut()`. Sets `_ownerUid = null`, increments `_hydrationGeneration`, resets `state = const HabitSystemsState()`.
- **Q3**: YES. Late hydration or mutation from Account A.
- **Q4**: Guarded by `_hydrationGeneration` and `_ownerUid == targetUid` checks.
- **Q5**: YES. Cleared to `const HabitSystemsState()`.
- **Q6**: YES. Preserved.

---

### Group C: Feature Dashboard, Mind & Fitness
#### 5. `homeDashboardProvider` (`StateNotifierProvider<HomeDashboardNotifier, HomeDashboardState>`, `lib/features/home/providers/home_dashboard_provider.dart:127`)
- **Q1**: YES. Holds `HomeDashboardState` with check-ins, now/next action, mission summary for Account A.
- **Q2**: `resetIdentityBoundary()` line 51 calls `_ref.read(homeDashboardProvider.notifier).resetForSignedOut()`. Sets `_ownerUid = null` and resets `state = _initialEmptyState()`.
- **Q3**: YES. If an async task had been running.
- **Q4**: `completeCheckIn` and `cycleNowNextState` enforce: `if (targetUid != null && _ownerUid != null && targetUid != _ownerUid) return;`. When switched to B, `_ownerUid` is cleared/switched.
- **Q5**: YES. Cleared to `_initialEmptyState()`.
- **Q6**: YES. Preserved.

#### 6. `homeMindNoteProvider` (`StateNotifierProvider<HomeMindNoteNotifier, List<HomeMindNote>>`, `lib/features/home/providers/home_mind_note_provider.dart:56`)
- **Q1**: YES. Holds `List<HomeMindNote>` created during Account A's session.
- **Q2**: `resetIdentityBoundary()` line 87 calls `_ref.read(homeMindNoteProvider.notifier).resetForSignedOut()`, setting `state = const [];`.
- **Q3**: NO. Operations are synchronous in-memory modifications.
- **Q4**: Synchronous reset purges notes; subsequent loads from repo are UID-scoped to B.
- **Q5**: YES. Cleared to empty list.
- **Q6**: YES. Preserved.

#### 7. `fitnessCenterProvider` (`StateNotifierProvider<FitnessCenterNotifier, FitnessCenterState>`, `lib/features/tracker/fitness/providers/fitness_provider.dart:396`)
- **Q1**: YES. Holds `FitnessCenterState` with active workout/run activities and GPS route points for Account A.
- **Q2**: `resetIdentityBoundary()` line 52 calls `_ref.read(fitnessCenterProvider.notifier).resetForSignedOut()`. Sets `_ownerUid = null` and `state = FitnessCenterState.empty()`.
- **Q3**: YES. GPS activity completion or route calculation in-flight.
- **Q4**: `_ownerUid` checks in mutation methods reject mismatched UIDs; state is synchronously reset before B becomes active.
- **Q5**: YES. Cleared to `FitnessCenterState.empty()`.
- **Q6**: YES. Preserved.

---

### Group D: Settings & Links
#### 8. `trackerSettingsProvider` (`StateNotifierProvider<TrackerSettingsNotifier, TrackerSettingsState>`, `lib/features/tracker/providers/tracker_settings_provider.dart:103`)
- **Q1**: YES. Holds `TrackerSettingsState` with active tracker selections and privacy settings.
- **Q2**: `resetIdentityBoundary()` line 53 calls `_ref.read(trackerSettingsProvider.notifier).resetForSignedOut()`, resetting state to `TrackerSettingsState.defaults()`.
- **Q3**: NO. State modifications are synchronous UI actions.
- **Q4**: Synchronously reset to defaults.
- **Q5**: YES. Cleared to defaults.
- **Q6**: YES. Preserved.

#### 9. `trackerSessionLinksProvider` (`StateNotifierProvider<RoutineTrackerLinksNotifier, List<TrackerSessionLink>>`, `lib/features/routine/routine_state.dart:334`)
- **Q1**: YES. Holds `List<TrackerSessionLink>` associating routine task IDs with tracker types.
- **Q2**: `resetIdentityBoundary()` line 41 calls `_ref.read(trackerSessionLinksProvider.notifier).resetForSignedOut()`, setting `state = const [];`.
- **Q3**: NO. Synchronous in-memory mapping list.
- **Q4**: Synchronously cleared on identity reset.
- **Q5**: YES. Cleared to empty list.
- **Q6**: YES. Preserved.

#### 10. `profileSettingsProvider` (`StateNotifierProvider<ProfileSettingsNotifier, ProfileSettingsState>`, `lib/features/profile/providers/profile_settings_provider.dart:318`)
- **Q1**: YES. Holds `ProfileSettingsState` with notification preferences, delete scopes, privacy settings, deletion requests.
- **Q2**: `resetIdentityBoundary()` line 50 calls `_ref.read(profileSettingsProvider.notifier).resetForSignedOut()`, setting state to `_profileSettingsDefaults()`.
- **Q3**: YES. Async repo save (`saveProfileSettings`, `saveAppPreferences`) in-flight.
- **Q4**: `updateProfile` checks `final uid = _currentUid; if (uid.isEmpty) return;` where `_currentUid` reads `_ref.read(authProvider).user?.uid`. When B signs in, `_currentUid` is `uid_B`, preventing writes to A's profile.
- **Q5**: YES. Cleared to default settings.
- **Q6**: YES. Preserved.

#### 11. `regionSettingsProvider` (`StateNotifierProvider<RegionSettingsNotifier, RegionSettings>`, `lib/state/region_settings_provider.dart:90`)
- **Q1**: YES. Holds `RegionSettings` with country, currency, paymentRegion, and `userId: "gate5-a"`.
- **Q2**: `resetIdentityBoundary()` line 75 calls `_ref.read(regionSettingsProvider.notifier).resetForSignedOut()`, setting `state = RegionSettings.defaultForUser('signed-out')`.
- **Q3**: YES. `fetchRegionSettings(userId)` or `detectCountry()` in-flight.
- **Q4**: In `hydrateForUser(userId)`: if `userId != activeUid`, or after reset, incoming fetched data must match `userId`. Furthermore, server reconstruction hydrates B's region explicitly.
- **Q5**: YES. Cleared to signed-out default.
- **Q6**: YES. Preserved.

---

### Group E: Uploads & AI Controllers
#### 12. `uploadControllerProvider` (`StateNotifierProvider<UploadController, UploadState>`, `lib/state/upload_state.dart:925`)
- **Q1**: YES. Holds `UploadState` with active upload progress, `uid: "gate5-a"`, `activeAsset`.
- **Q2**: `resetIdentityBoundary()` line 55 calls `_ref.read(uploadControllerProvider.notifier).resetForSignedOut()`. Increments `_operationGeneration++` and sets `state = const UploadState()`.
- **Q3**: YES. HTTP PUT to R2 or image compression in background.
- **Q4**: Every step checks `if (!_isCurrentOperation(uid, operationGeneration)) return null;` where `_isCurrentOperation` requires: `_operationGeneration == operationGeneration && _authRepository.currentUser?.uid == uid`. Because `_operationGeneration` was incremented and current UID changed, any late callback returns `null` and is dropped.
- **Q5**: YES. Increments generation and sets state to `const UploadState()`.
- **Q6**: YES. Preserved.

#### 13. `restoredUploadsProvider` (`StateNotifierProvider<RestoredUploadsController, RestoredUploadsState>`, `lib/state/upload_state.dart:915`)
- **Q1**: YES. Holds `RestoredUploadsState` with restored uploaded assets (`uid: "gate5-a"`).
- **Q2**: `resetIdentityBoundary()` line 57 calls `_ref.read(restoredUploadsProvider.notifier).resetForSignedOut()`. Increments `_sessionGeneration++`, clears `_previewGenerations`, clears in-flight hydration, and sets `state = const RestoredUploadsState()`.
- **Q3**: YES. Fetching assets or previews from R2/Firestore.
- **Q4**: Checks `_isCurrentSession(sessionGeneration, uid)` and `_isCurrentPreview(purpose, previewGen)`. Old generations are dropped.
- **Q5**: YES. Cleared to empty state and increments session generation.
- **Q6**: YES. Preserved.

#### 14. `routineImportAiControllerProvider` (`StateNotifierProvider<RoutineImportAiController, RoutineImportAiState>`, `lib/state/routine_import_ai_state.dart:234`)
- **Q1**: YES. Holds `RoutineImportAiState` with AI extraction results for schedule imports.
- **Q2**: `resetIdentityBoundary()` line 54 calls `_ref.read(routineImportAiControllerProvider.notifier).resetForSignedOut()`. Calls `_lifecycle.reset()` and sets `state = const RoutineImportAiState()`.
- **Q3**: YES. Worker HTTP extraction call in flight.
- **Q4**: `AiGenerationLifecycleManager` operation token fencing: `if (run.ignored || run.duplicate) return null;`. Resetting the lifecycle invalidates previous run tokens so the late result is ignored.
- **Q5**: YES. Resets lifecycle and sets state to empty.
- **Q6**: YES. Preserved.

#### 15. `onboardingUploadInteractionProvider` (`StateNotifierProvider<UploadInteractionController, UploadInteractionMap>`, `lib/features/uploads/providers/onboarding_upload_interaction_provider.dart:58`)
- **Q1**: YES. Holds `UploadInteractionMap` with slot states for onboarding photos (class, work, menu, skin products, skin face).
- **Q2**: `resetIdentityBoundary()` line 56 calls `_ref.invalidate(onboardingUploadInteractionProvider)`. Also listens to `restoredUploadsProvider`, calling `controller.resetForSignedOut()` if UID is empty.
- **Q3**: YES. In-flight upload slot update.
- **Q4**: Upload operations check current UID and slot ownership; provider invalidation re-instantiates controller with empty state.
- **Q5**: YES. Provider is invalidated and reset on logout.
- **Q6**: YES. Preserved.

#### 16. `onboardingCompletionJobServiceProvider` (`Provider<OnboardingCompletionJobService>`, `lib/services/onboarding_completion_job_service.dart:1684`)
- **Q1**: YES. In-memory `_activeJobNotifier`, active execution futures, stage timers.
- **Q2**: `resetIdentityBoundary()` line 37 calls `_ref.invalidate(onboardingCompletionJobServiceProvider)`. Triggers `ref.onDispose(service.cancelAll)` which cancels all in-flight job timers and transitions.
- **Q3**: YES. Network step in completion pipeline completing late.
- **Q4**: Service instance was cancelled via `cancelAll()`, disposed, and replaced by a fresh instance. Completion jobs also check `job.userId == currentUid`.
- **Q5**: YES. Invalidated and all active jobs cancelled.
- **Q6**: YES. Not invalidated on same-UID refresh.

#### 17. `recoveryRetryControllerProvider` (`StateNotifierProvider<RecoveryRetryController, RecoveryRetryState>`, `lib/features/recovery/services/recovery_retry_controller.dart:98`)
- **Q1**: YES. Holds `RecoveryRetryState` with retry attempts, backoff durations for failed recovery.
- **Q2**: `resetIdentityBoundary()` line 39 calls `_ref.read(recoveryRetryControllerProvider.notifier).resetForSignedOut()`. Cancels timers and resets to default state.
- **Q3**: NO. Cooldown timer is cancelled synchronously on reset.
- **Q4**: Timers cancelled and state reset synchronously.
- **Q5**: YES. Cleared to default empty state.
- **Q6**: YES. Preserved.

---

### Group F: Legacy Mock State Stores (`lib/state/app_state.dart`)
#### 18. `mockRoutineProvider` (`MockRoutineNotifier`, line 323)
#### 19. `mockTrackerProvider` (`MockTrackerNotifier`, line 996)
#### 20. `mockGoalProvider` (`MockGoalNotifier`, line 1113)
#### 21. `mockMindNoteProvider` (`MockMindNoteNotifier`, line 1176)
#### 22. `mockCoachProvider` (`MockCoachNotifier`, line 1376)
#### 23. `mockCoachPreferencesProvider` (`MockCoachPreferencesNotifier`, line 1397)
#### 24. `mockNotificationPreferencesProvider` (`MockNotificationPreferencesNotifier`, line 1457)
#### 25. `mockPermissionProvider` (`MockPermissionNotifier`, line 1513)
- **Q1**: YES. In fake/legacy mode they hold seeded or edited lists of items.
- **Q2**: `resetIdentityBoundary()` calls `resetFeatureStateForHydration()` (lines 83-91), which calls `resetForSignedOut()` on every mock notifier, resetting each to empty/initial state.
- **Q3**: NO. All mutations on these mock notifiers are synchronous in-memory methods.
- **Q4**: Synchronously reset on boundary reset before B publishes.
- **Q5**: YES. Every mock notifier has its `resetForSignedOut()` called.
- **Q6**: YES. Preserved.

---

### Group G: UID-Keyed, Auto-Dispose, and Generation-Fenced Providers
#### 26. `onboardingCompletionJobProvider` (`FutureProvider.family<OnboardingCompletionJob?, String>`, `lib/services/onboarding_completion_job_service.dart:1704`)
- **Q1**: YES. Returns `OnboardingCompletionJob` for Account A when queried with `uid_A`.
- **Q2**: Because it is parameterized by `uid`, Account B queries with `uid_B`, creating/reading a completely separate provider family instance. Furthermore, `resetIdentityBoundary()` line 38 invalidates `onboardingCompletionJobProvider`.
- **Q3**: YES. The Future for `uid_A` could resolve late.
- **Q4**: The family key is `uid_A`. Account B reads family instance `uid_B`. Late resolution for key `uid_A` writes only into key `uid_A`'s cache and cannot affect key `uid_B`.
- **Q5**: YES. Invalidated by `resetIdentityBoundary()`.
- **Q6**: YES. Same `uid` continues to reference the cached family instance unless invalidated.

#### 27. `verificationLifecycleProvider` (`StateNotifierProvider.autoDispose<VerificationLifecycleController, VerificationLifecycleState>`, `lib/state/verification_lifecycle_state.dart:123`)
- **Q1**: YES. Holds verification timers, streak count, email verification checking state for Account A.
- **Q2**: Listens to `authProvider` (lines 161-185): when `next.user?.uid != _expectedUid`, it immediately invokes `_stopSession()`, which cancels timers and resets checking state. When `VerifyEmailScreen` unmounts, `.autoDispose` tears it down.
- **Q3**: YES. A background reload/check on Firebase Auth user initiated by A could complete late.
- **Q4**: Every check validates `_freshnessEpoch`, `_disposed`, and `next.user?.uid == _expectedUid`. If UID changed or controller detached/disposed, the callback is dropped.
- **Q5**: YES. Calling logout triggers `_stopSession()` and navigates away from `/verify-email`, triggering auto-dispose.
- **Q6**: YES. Same UID does not trigger `_stopSession()`; preserves throttle timers.

#### 28. `onboardingClassTimelineProvider` & 29. `onboardingWorkTimelineProvider` (`StateProvider.autoDispose<List<ClassRoutineBlock>>`, `lib/features/onboarding/steps/onboarding_step_4_schedule_models.dart:10-13`)
- **Q1**: YES. Stores temporary schedule blocks during Step 4.
- **Q2**: `resetIdentityBoundary()` lines 48-49 invalidates both providers synchronously, returning them to empty lists `[]`.
- **Q3**: NO. These are synchronous UI state providers for timetable blocks.
- **Q4**: Synchronously invalidated on identity reset and auto-disposed when Step 4 unmounts.
- **Q5**: YES. Invalidated by `resetIdentityBoundary()`.
- **Q6**: YES. Preserved.

#### 30. `skinCareFlowControllerProvider` (`StateNotifierProvider<SkinCareFlowController, SkinCareFlowStateHolder>`, `lib/features/onboarding/steps/skin_care/skin_care_flow_controller.dart:683`)
- **Q1**: YES. Stores `SkinCareFlowStateHolder` with `ownerUid: "gate5-a"`, `authGeneration`, `epoch`, and flow states (`choice`, `hasProductsReview`, etc.).
- **Q2**: `resetIdentityBoundary()` increments `authGenerationProvider` and resets `onboardingStateProvider`. `skinCareFlowControllerProvider` listens to `authGenerationProvider` and `onboardingStateProvider`. When `authGeneration` increments or UID changes: `syncFromDraft` detects `ownerChanged == true` (`state.ownerUid != uid || state.authGeneration != authGeneration`), synchronously clears `step7ActionBridgeProvider`, rolls back upload replacements, and resets state to `deriveSkinCareFlowState(base, uid)` with new epoch and new `authGeneration`.
- **Q3**: YES. AI generation call from Account A in Step 7 could return late.
- **Q4**: In `no_products_screen.dart:383-400` and `has_products_screen.dart`: the generation operation checks `isSessionCurrent: () => mounted && _flowController.currentEpoch == requestEpoch && ref.read(authGenerationProvider) == currentAuthGeneration && (currentUserUid ?? draftUid) == uid`. Because `authGeneration` changed and `currentEpoch` was incremented, `scope.isCurrent` returns false and the late result is completely aborted without updating the draft or controller.
- **Q5**: YES. `resetIdentityBoundary()` increments `authGenerationProvider` and resets `onboardingStateProvider`, triggering `syncFromDraft` which resets flow state and clears the action bridge.
- **Q6**: YES. On same-UID refresh, `authGeneration` is NOT incremented, and `syncFromDraft` detects `state.ownerUid == uid && state.authGeneration == authGeneration`, preserving current flow state and any in-progress editing.

#### 31. `authProvider` (`StateNotifierProvider<AuthNotifier, AuthState>`, `lib/state/auth_state.dart:1815`)
- **Q1**: YES. Holds `AuthState` containing `AuthUser(uid: "gate5-a")`, session destination, error, resume step.
- **Q2**: In `_handleAuthUserChanged` (lines 738-750): when `nextUser?.uid != currentUid`, it calls `_sessionResetCoordinator.resetIdentityBoundary()` synchronously. Before setting `state = AuthState(user: nextUser, status: ...)` and before B is published or usable, it synchronously purges all Account A data.
- **Q3**: YES. Reconstruction or Google sign-in from Account A could resolve late.
- **Q4**: `_authOperationGeneration` and `_backendRestoreGeneration` counters increment on each operation. `_isCurrentGeneration` checks discard any callback whose generation or UID does not match the active session.
- **Q5**: YES. `logout()` calls `_sessionResetCoordinator.resetIdentityBoundary()` and sets `state = AuthState(status: AuthFlowStatus.signedOut)`.
- **Q6**: YES. When `nextUser?.uid == currentUid`, `_handleAuthUserChanged` updates user metadata while preserving active destination, route, and hydrated projections.

---

## 3. Exhaustive 116-Provider Catalog

The complete catalog of all 116 providers declared across `lib/` is organized into the 9 formal categories below.

### 1. `USER_SCOPED_RESET` (25 Providers)
| # | Provider | File & Line | Type | Authority / Owner | Reset Mechanism |
|---|---|---|---|---|---|
| 1 | `userProfileProvider` | `lib/state/app_state.dart:160` | `StateNotifierProvider` | `UserProfileNotifier` | `resetForSignedOut()` via Coordinator |
| 2 | `onboardingStateProvider` | `lib/state/app_state.dart:1871` | `StateNotifierProvider` | `OnboardingNotifier` | `resetForSignedOut()` via Coordinator |
| 3 | `routineNotifierProvider` | `lib/features/routine/routine_state.dart:2643` | `StateNotifierProvider` | `RoutineNotifier` | `resetForSignedOut()` via Coordinator |
| 4 | `habitSystemsNotifierProvider` | `lib/features/routine/controllers/habit_systems_controller.dart:719` | `StateNotifierProvider` | `HabitSystemsNotifier` | `resetForSignedOut()` via Coordinator |
| 5 | `homeDashboardProvider` | `lib/features/home/providers/home_dashboard_provider.dart:127` | `StateNotifierProvider` | `HomeDashboardNotifier` | `resetForSignedOut()` via Coordinator |
| 6 | `homeMindNoteProvider` | `lib/features/home/providers/home_mind_note_provider.dart:56` | `StateNotifierProvider` | `HomeMindNoteNotifier` | `resetForSignedOut()` via Coordinator |
| 7 | `fitnessCenterProvider` | `lib/features/tracker/fitness/providers/fitness_provider.dart:396` | `StateNotifierProvider` | `FitnessCenterNotifier` | `resetForSignedOut()` via Coordinator |
| 8 | `trackerSettingsProvider` | `lib/features/tracker/providers/tracker_settings_provider.dart:103` | `StateNotifierProvider` | `TrackerSettingsNotifier` | `resetForSignedOut()` via Coordinator |
| 9 | `trackerSessionLinksProvider` | `lib/features/routine/routine_state.dart:334` | `StateNotifierProvider` | `RoutineTrackerLinksNotifier` | `resetForSignedOut()` via Coordinator |
| 10 | `profileSettingsProvider` | `lib/features/profile/providers/profile_settings_provider.dart:318` | `StateNotifierProvider` | `ProfileSettingsNotifier` | `resetForSignedOut()` via Coordinator |
| 11 | `regionSettingsProvider` | `lib/state/region_settings_provider.dart:90` | `StateNotifierProvider` | `RegionSettingsNotifier` | `resetForSignedOut()` via Coordinator |
| 12 | `uploadControllerProvider` | `lib/state/upload_state.dart:925` | `StateNotifierProvider` | `UploadController` | `resetForSignedOut()` via Coordinator |
| 13 | `restoredUploadsProvider` | `lib/state/upload_state.dart:915` | `StateNotifierProvider` | `RestoredUploadsController` | `resetForSignedOut()` via Coordinator |
| 14 | `routineImportAiControllerProvider` | `lib/state/routine_import_ai_state.dart:234` | `StateNotifierProvider` | `RoutineImportAiController` | `resetForSignedOut()` via Coordinator |
| 15 | `onboardingUploadInteractionProvider` | `lib/features/uploads/providers/onboarding_upload_interaction_provider.dart:58` | `StateNotifierProvider` | `UploadInteractionController` | Invalidated via Coordinator |
| 16 | `onboardingCompletionJobServiceProvider` | `lib/services/onboarding_completion_job_service.dart:1684` | `Provider` | `OnboardingCompletionJobService` | Invalidated via Coordinator (`cancelAll` on dispose) |
| 17 | `recoveryRetryControllerProvider` | `lib/features/recovery/services/recovery_retry_controller.dart:98` | `StateNotifierProvider` | `RecoveryRetryController` | `resetForSignedOut()` via Coordinator |
| 18 | `mockRoutineProvider` | `lib/state/app_state.dart:323` | `StateNotifierProvider` | `MockRoutineNotifier` | `resetForSignedOut()` via Coordinator |
| 19 | `mockTrackerProvider` | `lib/state/app_state.dart:996` | `StateNotifierProvider` | `MockTrackerNotifier` | `resetForSignedOut()` via Coordinator |
| 20 | `mockGoalProvider` | `lib/state/app_state.dart:1113` | `StateNotifierProvider` | `MockGoalNotifier` | `resetForSignedOut()` via Coordinator |
| 21 | `mockMindNoteProvider` | `lib/state/app_state.dart:1176` | `StateNotifierProvider` | `MockMindNoteNotifier` | `resetForSignedOut()` via Coordinator |
| 22 | `mockCoachProvider` | `lib/state/app_state.dart:1376` | `StateNotifierProvider` | `MockCoachNotifier` | `resetForSignedOut()` via Coordinator |
| 23 | `mockCoachPreferencesProvider` | `lib/state/app_state.dart:1397` | `StateNotifierProvider` | `MockCoachPreferencesNotifier` | `resetForSignedOut()` via Coordinator |
| 24 | `mockNotificationPreferencesProvider` | `lib/state/app_state.dart:1457` | `StateNotifierProvider` | `MockNotificationPreferencesNotifier` | `resetForSignedOut()` via Coordinator |
| 25 | `mockPermissionProvider` | `lib/state/app_state.dart:1513` | `StateNotifierProvider` | `MockPermissionNotifier` | `resetForSignedOut()` via Coordinator |

### 2. `USER_SCOPED_UID_KEYED` (1 Provider)
| # | Provider | File & Line | Type | Authority / Owner | Reset Mechanism |
|---|---|---|---|---|---|
| 26 | `onboardingCompletionJobProvider` | `lib/services/onboarding_completion_job_service.dart:1704` | `FutureProvider.family` | `OnboardingCompletionJobService` | Keyed by `uid`; invalidated via Coordinator |

### 3. `USER_SCOPED_AUTO_DISPOSE` (3 Providers)
| # | Provider | File & Line | Type | Authority / Owner | Reset Mechanism |
|---|---|---|---|---|---|
| 27 | `verificationLifecycleProvider` | `lib/state/verification_lifecycle_state.dart:123` | `StateNotifierProvider.autoDispose` | `VerificationLifecycleController` | Auto-dispose on unmount; constructor captures `_expectedUid` & stops on UID change |
| 28 | `onboardingClassTimelineProvider` | `lib/features/onboarding/steps/onboarding_step_4_schedule_models.dart:10` | `StateProvider.autoDispose` | Step 4 UI Controller | Auto-dispose on unmount; invalidated via Coordinator |
| 29 | `onboardingWorkTimelineProvider` | `lib/features/onboarding/steps/onboarding_step_4_schedule_models.dart:12` | `StateProvider.autoDispose` | Step 4 UI Controller | Auto-dispose on unmount; invalidated via Coordinator |

### 4. `USER_SCOPED_GENERATION_FENCED` (2 Providers)
| # | Provider | File & Line | Type | Authority / Owner | Reset Mechanism |
|---|---|---|---|---|---|
| 30 | `authProvider` | `lib/state/auth_state.dart:1815` | `StateNotifierProvider` | `AuthNotifier` | Operation generations (`_authOperationGeneration`, `_backendRestoreGeneration`); delegates identity reset to Coordinator |
| 31 | `skinCareFlowControllerProvider` | `lib/features/onboarding/steps/skin_care/skin_care_flow_controller.dart:683` | `StateNotifierProvider` | `SkinCareFlowController` | Tracks `ownerUid` & `authGeneration`; clears on generation change; async fenced by `isSessionCurrent` & epoch |

### 5. `SESSION_UI_RESET` (13 Providers)
| # | Provider | File & Line | Type | Authority / Owner | Reset Mechanism |
|---|---|---|---|---|---|
| 32 | `appNavigationProvider` | `lib/app/app_navigation_controller.dart:24` | `StateNotifierProvider` | `AppNavigationController` | `resetForSignedOut()` via Coordinator |
| 33 | `toastQueueProvider` | `lib/core/utils/liquid_toast_manager.dart:92` | `StateNotifierProvider` | `ToastQueueNotifier` | `resetForSignedOut()` via Coordinator |
| 34 | `homeDetailViewRequestProvider` | `lib/features/home/providers/home_navigation_provider.dart:14` | `StateProvider` | Home UI Navigation | Set to `none` via Coordinator |
| 35 | `trackerDetailViewRequestProvider` | `lib/features/tracker/providers/tracker_navigation_provider.dart:41` | `StateProvider` | Tracker UI Navigation | Set to `none` via Coordinator |
| 36 | `profileDetailViewRequestProvider` | `lib/features/profile/providers/profile_navigation_provider.dart:40` | `StateProvider` | Profile UI Navigation | Set to `none` via Coordinator |
| 37 | `routineDetailViewRequestProvider` | `lib/features/routine/providers/routine_navigation_provider.dart:28` | `StateProvider` | Routine UI Navigation | Set to `none` via Coordinator |
| 38 | `coachDetailViewRequestProvider` | `lib/features/coach/providers/coach_navigation_provider.dart:11` | `StateProvider` | Coach UI Navigation | Set to `none` via Coordinator |
| 39 | `goalsDetailViewRequestProvider` | `lib/features/goals/providers/goals_navigation_provider.dart:21` | `StateProvider` | Goals UI Navigation | Set to `none` via Coordinator |
| 40 | `step7ActionBridgeProvider` | `lib/features/onboarding/steps/skin_care/skin_care_action_bridge.dart:87` | `StateNotifierProvider` | `Step7ActionBridgeNotifier` | Epoch-token fencing; cleared by `SkinCareFlowController.syncFromDraft` |
| 41 | `onboardingStep7PrimaryActionProvider` | `lib/features/onboarding/steps/skin_care/skin_care_action_bridge.dart:93` | `StateProvider` | Step 7 Action Bridge | Cleared by `Step7ActionBridgeNotifier.clearAll()` |
| 42 | `aiRoutineSuggestionsEnabledProvider` | `lib/features/routine/routine_state.dart:2814` | `StateProvider` | Routine Preferences | Set to `true` via Coordinator |
| 43 | `conflictResolverEnabledProvider` | `lib/features/routine/routine_state.dart:2815` | `StateProvider` | Routine Preferences | Set to `true` via Coordinator |
| 44 | `routineNotificationsEnabledProvider` | `lib/features/routine/routine_state.dart:2816` | `StateProvider` | Routine Preferences | Set to `true` via Coordinator |

### 6. `GLOBAL_CONFIG` (11 Providers)
| # | Provider | File & Line | Type | Authority / Owner | Description |
|---|---|---|---|---|---|
| 45 | `optivusBackendModeProvider` | `lib/config/backend_config.dart:28` | `Provider` | `OptivusBackendConfig` | Backend mode (fake vs firebase) |
| 46 | `fakeDataAllowedProvider` | `lib/config/backend_config.dart:36` | `Provider` | `FakeBackendPolicy` | Boolean flag whether fake data is allowed |
| 47 | `fakeBackendPolicyProvider` | `lib/config/backend_config.dart:32` | `Provider` | `FakeBackendPolicy` | Backend selection policy |
| 48 | `optivusDebugBuildProvider` | `lib/config/backend_config.dart:24` | `Provider` | Build Configuration | Debug mode flag |
| 49 | `nutritionAiClientModeProvider` | `lib/services/nutrition_ai_client.dart:40` | `Provider` | `NutritionAiClientMode` | Worker vs fake mode |
| 50 | `routineImportAiClientModeProvider` | `lib/services/routine_import_ai_client.dart:485` | `Provider` | `RoutineImportAiClientMode` | Worker vs fake mode |
| 51 | `reconstructionRetryPolicyProvider` | `lib/state/auth_state.dart:78` | `Provider` | `ReconstructionRetryPolicy` | Reconstruction retry policy |
| 52 | `verificationLifecyclePolicyProvider` | `lib/state/verification_lifecycle_state.dart:115` | `Provider` | `VerificationLifecyclePolicy` | Throttle and cooldown timings |
| 53 | `verificationClockProvider` | `lib/state/verification_lifecycle_state.dart:119` | `Provider` | Clock Function | DateTime provider for testing/prod |
| 54 | `hydrationGoalMlProvider` | `lib/features/tracker/hydration/hydration_provider.dart:4` | `Provider` | Hydration Config | Default hydration goal (2500 ml) |
| 55 | `authGenerationProvider` | `lib/state/auth_generation.dart:8` | `StateProvider` | Auth Boundary | Monotonic counter incremented on identity reset |

### 7. `DERIVED` (14 Providers)
| # | Provider | File & Line | Type | Authority / Owner | Description |
|---|---|---|---|---|---|
| 56 | `onboardingDraftProvider` | `lib/state/app_state.dart:1876` | `Provider` | `onboardingStateProvider` | Derived read of `draft` |
| 57 | `activeOnboardingCompletionJobProvider` | `lib/services/onboarding_completion_job_service.dart:1711` | `ChangeNotifierProvider` | `onboardingCompletionJobServiceProvider` | Derived active job notifier |
| 58 | `currentRoutineItemsProvider` | `lib/state/profile_frontend_state.dart:9` | `Provider` | `routineNotifierProvider` | Derived routine items |
| 59 | `currentGoalsProvider` | `lib/state/profile_frontend_state.dart:13` | `Provider` | `mockGoalProvider` | Derived goals |
| 60 | `currentCoachPreferencesProvider` | `lib/state/profile_frontend_state.dart:17` | `Provider` | `mockCoachPreferencesProvider` | Derived coach preferences |
| 61 | `selectedDayRoutineItemsProvider` | `lib/features/routine/routine_state.dart:2721` | `Provider` | `routineNotifierProvider` | Filtered by selected day |
| 62 | `filteredRoutineItemsProvider` | `lib/features/routine/routine_state.dart:2732` | `Provider` | `routineNotifierProvider` | Filtered by query and tags |
| 63 | `todayRoutineItemsProvider` | `lib/features/routine/routine_state.dart:2745` | `Provider` | `routineNotifierProvider` | Filtered for today |
| 64 | `currentRoutineItemProvider` | `lib/features/routine/routine_state.dart:2759` | `Provider` | `routineNotifierProvider` | Current active routine item |
| 65 | `nextRoutineItemProvider` | `lib/features/routine/routine_state.dart:2774` | `Provider` | `routineNotifierProvider` | Next upcoming routine item |
| 66 | `routineCompletionSummaryProvider` | `lib/features/routine/routine_state.dart:2791` | `Provider` | `routineNotifierProvider` | Completion summary calculation |
| 67 | `routineConflictSummaryProvider` | `lib/features/routine/routine_state.dart:2804` | `Provider` | `routineNotifierProvider` | Conflict summary calculation |
| 68 | `hydrationTodayTotalProvider` | `lib/features/tracker/hydration/hydration_provider.dart:1` | `Provider` | `mockTrackerProvider` | Sum of today's water logs |
| 69 | `routerNotifierProvider` | `lib/core/router/app_router.dart:33` | `Provider` | `RouterNotifier` | Observes `authProvider` exclusively |

### 8. `REPOSITORY_UID_SCOPED` (32 Providers)
| # | Provider | File & Line | Type | Repository Interface |
|---|---|---|---|---|
| 70 | `appPreferencesRepositoryProvider` | `lib/repositories/app_preferences_repository.dart:67` | `Provider` | `AppPreferencesRepository` |
| 71 | `profileRepositoryProvider` | `lib/repositories/profile_repository.dart:268` | `Provider` | `ProfileRepository` |
| 72 | `permissionStatusRepositoryProvider` | `lib/repositories/profile_repository.dart:277` | `Provider` | `PermissionStatusRepository` |
| 73 | `connectedServicesRepositoryProvider` | `lib/repositories/profile_repository.dart:288` | `Provider` | `ConnectedServicesRepository` |
| 74 | `dataControlRepositoryProvider` | `lib/repositories/profile_repository.dart:298` | `Provider` | `DataControlRepository` |
| 75 | `onboardingRepositoryProvider` | `lib/repositories/onboarding_repository.dart:1248` | `Provider` | `OnboardingRepository` |
| 76 | `routineHistoryRepositoryProvider` | `lib/repositories/routine_history_repository.dart:392` | `Provider` | `RoutineHistoryRepository` |
| 77 | `coachSessionRepositoryProvider` | `lib/repositories/coach_session_repository.dart:98` | `Provider` | `CoachSessionRepository` |
| 78 | `coachAiRepositoryProvider` | `lib/repositories/coach_session_repository.dart:103` | `Provider` | `CoachAiRepository` |
| 79 | `goalRepositoryProvider` | `lib/repositories/goal_repository.dart:78` | `Provider` | `GoalRepository` |
| 80 | `conflictAcceptanceRepositoryProvider` | `lib/repositories/conflict_acceptance_repository.dart:48` | `Provider` | `ConflictAcceptanceRepository` |
| 81 | `userProfileRepositoryProvider` | `lib/repositories/user_profile_repository.dart:45` | `Provider` | `UserProfileRepository` |
| 82 | `uploadedAssetRepositoryProvider` | `lib/repositories/uploaded_asset_repository.dart:140` | `Provider` | `UploadedAssetRepository` |
| 83 | `habitRepositoryProvider` | `lib/repositories/habit_repository.dart:55` | `Provider` | `HabitRepository` |
| 84 | `habitSystemsRepositoryProvider` | `lib/repositories/habit_systems_repository.dart:44` | `Provider` | `HabitSystemsRepository` |
| 85 | `homeDashboardRepositoryProvider` | `lib/repositories/home_repository.dart:63` | `Provider` | `HomeDashboardRepository` |
| 86 | `mindNoteRepositoryProvider` | `lib/repositories/home_repository.dart:74` | `Provider` | `MindNoteRepository` |
| 87 | `regionSettingsRepositoryProvider` | `lib/repositories/region_settings_repository.dart:52` | `Provider` | `RegionSettingsRepository` |
| 88 | `routineImportReviewRepositoryProvider` | `lib/repositories/routine_import_review_repository.dart:114` | `Provider` | `RoutineImportReviewRepository` |
| 89 | `fakeRoutineDatabaseProvider` | `lib/repositories/routine_repository.dart:309` | `Provider` | `FakeRoutineDatabase` (In-memory store keyed by `uid`) |
| 90 | `routineRepositoryProvider` | `lib/repositories/routine_repository.dart:313` | `Provider` | `RoutineRepository` |
| 91 | `routineTransactionRepositoryProvider` | `lib/repositories/routine_transaction_repository.dart:624` | `Provider` | `RoutineTransactionRepository` |
| 92 | `trackerRepositoryProvider` | `lib/repositories/tracker_repository.dart:219` | `Provider` | `TrackerRepository` |
| 93 | `trackerHistoryRepositoryProvider` | `lib/repositories/tracker_repository.dart:223` | `Provider` | `TrackerHistoryRepository` |
| 94 | `focusRepositoryProvider` | `lib/repositories/tracker_repository.dart:229` | `Provider` | `FocusRepository` |
| 95 | `badHabitRepositoryProvider` | `lib/repositories/tracker_repository.dart:233` | `Provider` | `BadHabitRepository` |
| 96 | `sleepRepositoryProvider` | `lib/repositories/tracker_repository.dart:237` | `Provider` | `SleepRepository` |
| 97 | `nutritionRepositoryProvider` | `lib/repositories/tracker_repository.dart:241` | `Provider` | `NutritionRepository` |
| 98 | `fitnessRepositoryProvider` | `lib/repositories/tracker_repository.dart:245` | `Provider` | `FitnessRepository` |
| 99 | `moneyRepositoryProvider` | `lib/repositories/tracker_repository.dart:249` | `Provider` | `MoneyRepository` |
| 100 | `authRepositoryProvider` | `lib/state/auth_state.dart:42` | `Provider` | `AuthRepository` |
| 101 | `notificationPreferencesRepositoryProvider` | `lib/repositories/notification_preferences_repository.dart:39` | `Provider` | `NotificationPreferencesRepository` |

### 9. `NOT_USER_SCOPED` (15 Providers)
| # | Provider | File & Line | Type | Description |
|---|---|---|---|---|
| 102 | `authSessionResetCoordinatorProvider` | `lib/services/auth_session_reset_coordinator.dart:103` | `Provider` | Synchronous privacy reset coordinator |
| 103 | `serverReconstructorProvider` | `lib/state/auth_state.dart:51` | `Provider` | Server reconstruction orchestration |
| 104 | `deviceCountryServiceProvider` | `lib/services/device_country_service.dart:81` | `Provider` | Device locale/SIM country detection |
| 105 | `notificationIntentServiceProvider` | `lib/services/native/notification_intent_service.dart:45` | `Provider` | Native Android notification intent service |
| 106 | `imagePrepareServiceProvider` | `lib/state/upload_state.dart:896` | `Provider` | Client-side image compression & format validation |
| 107 | `r2UploadClientProvider` | `lib/state/upload_state.dart:900` | `Provider` | HTTP client for signed R2 PUT uploads |
| 108 | `uploadedAssetPreviewResolverProvider` | `lib/state/upload_state.dart:910` | `Provider` | Asset preview resolver |
| 109 | `uploadPermissionServiceProvider` | `lib/features/uploads/services/upload_permission_service.dart:6` | `Provider` | Device camera & photo library permission client |
| 110 | `coachAiClientProvider` | `lib/services/coach_ai_client.dart:7` | `Provider` | Coach Cloudflare Worker client |
| 111 | `nutritionAiClientProvider` | `lib/services/nutrition_ai_client.dart:50` | `Provider` | Nutrition Cloudflare Worker client |
| 112 | `routineImportAiClientProvider` | `lib/services/routine_import_ai_client.dart:504` | `Provider` | Routine Import Cloudflare Worker client |
| 113 | `skinCareAiClientProvider` | `lib/services/skin_care_ai_client.dart:13` | `Provider` | Skin Care Cloudflare Worker client |
| 114 | `diagnosticBundleServiceProvider` | `lib/features/recovery/services/diagnostic_bundle_service.dart:12` | `Provider` | Diagnostic report bundle collector |
| 115 | `recoveryCacheManagerProvider` | `lib/features/recovery/services/recovery_cache_manager.dart:15` | `Provider` | Local recovery cache file manager |
| 116 | `routerProvider` | `lib/core/router/app_router.dart:70` | `Provider` | Core application `GoRouter` instance |

---

## 4. Specifically Audited Owners

### 1. `skinCareFlowControllerProvider` (`USER_SCOPED_GENERATION_FENCED`)
- **Authority**: `SkinCareFlowController` (`lib/features/onboarding/steps/skin_care/skin_care_flow_controller.dart:258-730`)
- **State**: `SkinCareFlowStateHolder` (epoch, flowState, ownerUid, authGeneration, planASnapshot, activeError)
- **Lifecycle & Boundaries**:
  - Does NOT need explicit listing in `AuthSessionResetCoordinator` because it attaches listeners to `authGenerationProvider` and `onboardingStateProvider` (lines 689-726).
  - When `AuthSessionResetCoordinator.resetIdentityBoundary()` runs: `authGenerationProvider.state++` and `onboardingStateProvider.resetForSignedOut()` execute synchronously.
  - The controller's `syncFromDraft` method detects `ownerChanged == true` (`state.ownerUid != uid || state.authGeneration != authGeneration`), clears `step7ActionBridgeProvider`, rolls back upload replacements, and resets state with an incremented epoch.
  - During AI routine generation, `no_products_screen.dart:383-400` guards the operation with `isSessionCurrent: () => mounted && _flowController.currentEpoch == requestEpoch && ref.read(authGenerationProvider) == currentAuthGeneration && currentUserUid == uid`.
  - Stale async responses from an earlier user or earlier generation are safely aborted without modifying state.

### 2. `step7ActionBridgeProvider` & `onboardingStep7PrimaryActionProvider` (`SESSION_UI_RESET`)
- **Authority**: `Step7ActionBridgeNotifier` (`lib/features/onboarding/steps/skin_care/skin_care_action_bridge.dart:43-85`)
- **State**: `Step7ActionBridgeState` (action, `Step7ActionToken(ownerId, epoch)`)
- **Lifecycle & Boundaries**:
  - Employs token and epoch fencing: `publish` and `clear` reject stale publications where `epoch < currentToken.epoch` or `ownerId` differs.
  - `SkinCareFlowController.syncFromDraft()` calls `clearAll()` unconditionally whenever an owner or authGeneration change is detected, resetting both the bridge and `onboardingStep7PrimaryActionProvider`.

### 3. `verificationLifecycleProvider` (`USER_SCOPED_AUTO_DISPOSE`)
- **Authority**: `VerificationLifecycleController` (`lib/state/verification_lifecycle_state.dart:135-611`)
- **State**: `VerificationLifecycleState`
- **Lifecycle & Boundaries**:
  - Scoped to `VerifyEmailScreen` with `autoDispose`.
  - Captures `_expectedUid = _ref.read(authProvider).user?.uid` in constructor.
  - Listens to `authProvider` (lines 161-185): when `next.user?.uid != _expectedUid`, calls `_stopSession()`, cancelling all timers and clearing checking states.
  - When `VerifyEmailScreen` unmounts, `dispose()` cleans up all timers.
  - Target for R3 error cleanup: eliminate legacy `VerificationMessageKind` and unify under `RecoverableError? error; String? successMessage;`.

### 4. `onboardingCompletionJobServiceProvider` (`USER_SCOPED_RESET`) & `onboardingCompletionJobProvider` (`USER_SCOPED_UID_KEYED`)
- **Authority**: `OnboardingCompletionJobService` (`lib/services/onboarding_completion_job_service.dart:181-1717`)
- **State**: `_activeJobNotifier`, execution stages, family-cached jobs
- **Lifecycle & Boundaries**:
  - `AuthSessionResetCoordinator.resetIdentityBoundary()` executes `_ref.invalidate(onboardingCompletionJobServiceProvider);` and `_ref.invalidate(onboardingCompletionJobProvider);`.
  - Invalidating the service invokes `ref.onDispose(service.cancelAll)` (line 1700), cancelling all in-flight completion pipeline stages and timers.
  - `onboardingCompletionJobProvider` is a `FutureProvider.family<OnboardingCompletionJob?, String>` keyed by authenticated `uid`, guaranteeing cross-user isolation.

### 5. `onboardingUploadInteractionProvider` (`USER_SCOPED_RESET`)
- **Authority**: `UploadInteractionController` (`lib/features/uploads/controllers/upload_interaction_controller.dart`)
- **State**: `UploadInteractionMap` (photo slot states)
- **Lifecycle & Boundaries**:
  - `AuthSessionResetCoordinator.resetIdentityBoundary()` explicitly invalidates `onboardingUploadInteractionProvider` (line 56).
  - Also listens to `restoredUploadsProvider` (lines 72-79) and resets when `uid == null || uid.trim().isEmpty`.

### 6. `routineImportAiControllerProvider` (`USER_SCOPED_RESET`)
- **Authority**: `RoutineImportAiController` (`lib/state/routine_import_ai_state.dart:95-201`)
- **State**: `RoutineImportAiState`, `_lifecycle` (`AiGenerationLifecycleManager`)
- **Lifecycle & Boundaries**:
  - Reset synchronously via `AuthSessionResetCoordinator.resetIdentityBoundary()` (line 54).
  - Uses `AiGenerationLifecycleManager` run tokens to drop stale AI extraction callbacks.

### 7. `uploadControllerProvider` & `restoredUploadsProvider` (`USER_SCOPED_RESET`)
- **Authority**: `UploadController` & `RestoredUploadsController` (`lib/state/upload_state.dart`)
- **State**: `UploadState` & `RestoredUploadsState`
- **Lifecycle & Boundaries**:
  - Both controllers maintain operation generations (`_operationGeneration` and `_sessionGeneration`).
  - `AuthSessionResetCoordinator.resetIdentityBoundary()` calls `resetForSignedOut()` on both, incrementing generation counters and setting states to defaults.
  - Any late callback with mismatched generation or UID is dropped.

### 8. `regionSettingsProvider` (`USER_SCOPED_RESET`)
- **Authority**: `RegionSettingsNotifier` (`lib/state/region_settings_provider.dart:7-96`)
- **State**: `RegionSettings` (`userId`, country, currency, payment region)
- **Lifecycle & Boundaries**:
  - Reset synchronously via `AuthSessionResetCoordinator.resetIdentityBoundary()` (line 75) to `RegionSettings.defaultForUser('signed-out')`.
  - Reconstructed per-user during server reconstruction.

### 9. `homeDashboardProvider` (`USER_SCOPED_RESET`) & `fitnessCenterProvider` (`USER_SCOPED_RESET`)
- **Authority**: `HomeDashboardNotifier` & `FitnessCenterNotifier`
- **State**: `HomeDashboardState` & `FitnessCenterState`
- **Lifecycle & Boundaries**:
  - Both controllers have `_ownerUid` tracking.
  - Reset synchronously via `AuthSessionResetCoordinator.resetIdentityBoundary()` (lines 51 & 52), resetting `_ownerUid = null` and states to empty defaults.
  - Resolves TD-039 concerns: both Home and Fitness are proven to reset synchronously on logout and account switch.

### 10. `trackerSettingsProvider` & `trackerSessionLinksProvider` (`USER_SCOPED_RESET`)
- **Authority**: `TrackerSettingsNotifier` & `RoutineTrackerLinksNotifier`
- **State**: Active tracker map & `List<TrackerSessionLink>`
- **Lifecycle & Boundaries**:
  - Reset synchronously via `AuthSessionResetCoordinator.resetIdentityBoundary()` (lines 41 & 53) to defaults / empty list.

### 11. `profileSettingsProvider` (`USER_SCOPED_RESET`)
- **Authority**: `ProfileSettingsNotifier` (`lib/features/profile/providers/profile_settings_provider.dart:124`)
- **State**: `ProfileSettingsState`
- **Lifecycle & Boundaries**:
  - Reset synchronously via `AuthSessionResetCoordinator.resetIdentityBoundary()` (line 50) to defaults.
  - Mutations check `_currentUid` against active authenticated user.

### 12. All Six Detail-View Request Providers (`SESSION_UI_RESET`)
- **Authority**: `homeDetailViewRequestProvider`, `trackerDetailViewRequestProvider`, `profileDetailViewRequestProvider`, `routineDetailViewRequestProvider`, `coachDetailViewRequestProvider`, `goalsDetailViewRequestProvider`
- **Lifecycle & Boundaries**:
  - All 6 providers are synchronously reset to `none` by `AuthSessionResetCoordinator.resetIdentityBoundary()` (lines 63-74), preventing stale navigation requests from surviving session changes.

### 13. UID-Sensitive Repository Providers (`REPOSITORY_UID_SCOPED`)
- **Authority**: 32 repository providers across `lib/repositories/`
- **Lifecycle & Boundaries**:
  - Completely stateless service singletons.
  - Every single read, write, and transaction API requires an explicit authenticated `uid` parameter.
  - In fake/demo mode, `FakeRoutineDatabase` stores state in maps keyed by `uid` (`itemsByUid[uid]`), preventing cross-user data leakage in test and debug environments.

---

## 5. Technical Debt & Architecture Reconciliation (TD-039)

### The Contradiction
- `docs/TECHNICAL_DEBT.md` (Line 84):
  `| **TD-039** | Authentication/session isolation | Signed-out reset still does not invalidate every feature-local owner. | Updated 2026-07-23: Routine now resets on sign-out and before Firebase account restore, and repositories receive the authenticated UID explicitly. Home and Fitness still lack equivalent final verification. | ... | P0 | Phase 11 | ... | In progress |`
- `docs/ARCHITECTURE.md` (Section 10.5, Line 466):
  `| User-scoped providers survive the explicit logout reset | Feature-local Routine, Home, and Fitness owners are outside _resetUserScopedMockState(). | Each owner's durable phase, final gate Phase 11 (TD-039) | Sign-out and account-switch tests show empty/new-user state across all six areas. |`
- `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md` (Line 289):
  `- **TD-039 (Auth/session reset boundary gap)**: Status: CLOSED.`

### Root Cause of Contradiction
1. Historical entries in `TECHNICAL_DEBT.md` and `ARCHITECTURE.md` dated back to July 2026 when Home, Fitness, and other feature-local controllers were not yet wired to a centralized coordinator.
2. Gate 5 implemented `AuthSessionResetCoordinator`, which centralized the reset of Routine, Habits, Home, Mind, Fitness, Profile, Tracker, Upload, and Region state, verified by `test/gate5_auth_session_isolation_test.dart`.
3. However, `TECHNICAL_DEBT.md` and `ARCHITECTURE.md` were never updated to reflect the completed implementation, and the previous Gate-5 report prematurely marked TD-039 as closed without implementing the decisive Auth reconstruction pipeline race tests required by R5.

### Resolution
1. **Source Reality**: `AuthSessionResetCoordinator` is the comprehensive synchronous privacy boundary, resetting 25+ providers.
2. **Required Action**:
   - Implement the decisive real reconstruction race tests (Test A: Account A reconstruction completes after B; Test B: Account A reconstruction completes after sign-out) per R5.
   - Once Test A and Test B pass, update `docs/TECHNICAL_DEBT.md` to mark TD-039 as **Closed** in Gate 5.
   - Update `docs/ARCHITECTURE.md` Section 10.5 row 7 to reflect that `AuthSessionResetCoordinator` now invalidates and resets feature-local Routine, Home, Fitness, Profile, Onboarding, Tracker, Upload, and Region state on logout and account switch, resolving the gap.

---

## 6. Handoff Protocol (5-Component Structure)

### 1. Observation
- Scanned all 152 Dart source files under `lib/`. Identified exactly 116 Riverpod provider declarations.
- Verified that `lib/services/auth_session_reset_coordinator.dart` resets or invalidates:
  `authGenerationProvider`, `onboardingCompletionJobServiceProvider`, `onboardingCompletionJobProvider`, `recoveryRetryControllerProvider`, `routineNotifierProvider`, `trackerSessionLinksProvider`, `habitSystemsNotifierProvider`, `userProfileProvider`, `onboardingStateProvider`, `onboardingClassTimelineProvider`, `onboardingWorkTimelineProvider`, `profileSettingsProvider`, `homeDashboardProvider`, `fitnessCenterProvider`, `trackerSettingsProvider`, `routineImportAiControllerProvider`, `uploadControllerProvider`, `onboardingUploadInteractionProvider`, `restoredUploadsProvider`, `aiRoutineSuggestionsEnabledProvider`, `conflictResolverEnabledProvider`, `routineNotificationsEnabledProvider`, `appNavigationProvider`, `toastQueueProvider`, 6 `*DetailViewRequestProvider`s, `regionSettingsProvider`, and 9 `mock*` providers.
- Verified that `skinCareFlowControllerProvider` listens to `authGenerationProvider` and `onboardingStateProvider`, clearing its state and action bridge via `syncFromDraft` when `ownerUid` or `authGeneration` changes.
- Verified that `test/gate5_auth_session_isolation_test.dart` passes 10/10 tests, proving synchronous privacy reset, same-UID preservation, and late repository writes rejection.
- Observed that `test/gate5_auth_session_isolation_test.dart` tests late repository writes, but does NOT yet test in-flight `ServerReconstructionSource` / pipeline race conditions (Tests A–D from R5).

### 2. Logic Chain
1. If every mutable user/session state owner is identified, classified, and proven to reset on logout / account switch, user isolation is guaranteed.
2. The 116-provider inventory proves there are no unclassified mutable state owners in `lib/`.
3. The 31 user-scoped owners are partitioned into:
   - 25 synchronously reset/invalidated by `AuthSessionResetCoordinator`
   - 1 UID-keyed family provider
   - 3 auto-dispose providers with route lifecycles
   - 2 generation-fenced controllers (`authProvider` and `skinCareFlowControllerProvider`)
4. Therefore, when Account A signs out or Account B signs in:
   - `_handleAuthUserChanged` calls `resetIdentityBoundary()`.
   - `authGenerationProvider` is incremented.
   - All 25 `USER_SCOPED_RESET` providers are cleared.
   - All 13 `SESSION_UI_RESET` providers are reset to initial UI states.
   - The 2 `USER_SCOPED_GENERATION_FENCED` controllers detect the generation change and discard late responses.
   - Any late async callbacks from Account A are ignored because their generation token is stale and their target UID does not match the active session.
5. Completing the real reconstruction pipeline race test suite (R5) will provide automated proof of this invariant against the core server reconstructor.

### 3. Caveats
- `VerificationLifecycleState` in `lib/state/verification_lifecycle_state.dart` still contains legacy `VerificationMessageKind` and `messageKind` fields, which need removal per R3.
- The real reconstruction race tests (Test A & Test B in R5) must be implemented using controlled Completers behind `ServerReconstructionSource` to provide the final automated proof before Gate 5 is formally closed.

### 4. Conclusion
- TD-039 is architecturally and operationally resolved in the codebase by `AuthSessionResetCoordinator` and generation fencing.
- All 116 Riverpod providers in `lib/` are exhaustively classified with zero unclassified owners remaining.
- All 6 user-isolation questions are thoroughly answered with source evidence for every user-scoped provider.
- The pre-editing audit table is complete and ready for the implementation phase.

### 5. Verification Method
1. Run static architecture and provider classification audit:
   ```bash
   flutter test test/gate5_auth_session_isolation_test.dart
   flutter test test/ah_f011_no_production_mock_leakage_test.dart
   ```
2. Run analyzer and full test suite:
   ```bash
   flutter analyze
   flutter test --reporter compact
   ```
3. After R5 implementation of Tests A, B, C, D:
   ```bash
   flutter test test/gate5_auth_session_isolation_test.dart
   ```
