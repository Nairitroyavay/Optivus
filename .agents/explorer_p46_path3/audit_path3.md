# OPTIVUS PRODUCTION AUDIT REPORT — PATH 3
**Scope**: Steps 12 through 17 & Security / Firestore Rules (`firestore.rules`)  
**Phase**: 4.6 Final Production Closure  
**Date**: 2026-07-27  
**Auditor**: explorer_p46_path3  

---

## 1. Executive Summary

A comprehensive read-only code audit was performed on the real production execution path for Steps 12 through 17 (Router Transition, Home Screen, Cold Restart, Sign Out, Sign In, Recovery) as well as the Security Gaps & Firestore Security Rules (`firestore.rules`) of Optivus.

All previous `PASSED` claims from prior phases were treated as **NOT VERIFIED** and subjected to direct line-by-line inspection against actual codebase files (`app_router.dart`, `auth_state.dart`, `home_tab.dart`, `onboarding_recovery_screen.dart`, `firestore.rules`, etc.).

### Key Vulnerabilities & Defect Summary
- **P0 Critical Defect 1 (Step 12 Router)**: Ambiguous & conflicting route guards in `optivusAuthRedirect` cause infinite navigation loops and screen flashing between `/onboarding` and `/onboarding/recovery` during partial onboarding or backend restore states.
- **P0 Critical Defect 2 (Step 15 Sign Out / Step 16 Account Switch)**: Incomplete state purge during `logout()` leaves mounted `IndexedStack` widget controllers, active timer instances (`RecoveryRetryController`), and un-invalidated Riverpod provider family streams intact. When switching accounts on the same device, cached user data and UI inputs leak across user sessions.
- **P0 Critical Defect 3 (Step 17 Recovery)**: `SynthesizeBundleAction` silently fabricates empty onboarding draft and bundle data, bypassing validation and marking onboarding as complete. Furthermore, retry loops in recovery trigger infinite restore failure loops when projection receipt validation fails.
- **P0 Security Vulnerability 1 (Firestore Rules)**: Development catch-all match rule `match /users/{uid}/{collectionId}/{document=**}` allows authenticated users to read/write arbitrary unvalidated JSON into all un-enumerated subcollections (Goals, Coach, Tracker, Home, Settings, MindNotes), completely bypassing schema, field length, and data type validation.
- **P0 Security Vulnerability 2 (Firestore Rules)**: Loose rule `match /users/{uid}/onboarding/{docId}` allows writing arbitrary malformed documents into onboarding draft and completion bundle collections without schema validation.

---

## 2. Master Finding Index

| ID | Step | Title | Severity | Production File(s) | Line Numbers |
|---|---|---|---|---|---|
| **PATH3-12-01** | Step 12: Router | Route Guard Ambiguity & Infinite Redirect Loop between `/onboarding` and `/onboarding/recovery` | **P0** | `lib/core/router/app_router.dart` | 53-96 |
| **PATH3-12-02** | Step 12: Router | Side-Effect State Mutations Inside GoRouter `redirect` Callbacks | **P1** | `lib/core/router/app_router.dart` | 104-140, 186-463 |
| **PATH3-12-03** | Step 12: Router | Query Parameter Tab Index Mismatch with `AppNavigationController` State | **P1** | `lib/views/screens/app_shell.dart`<br>`lib/core/router/app_router.dart` | `app_shell.dart`: 51-65<br>`app_router.dart`: 178-185 |
| **PATH3-13-01** | Step 13: Home | Hardcoded User Name Fallbacks & Mock Dashboard State Fallback in Production Path | **P1** | `lib/features/home/home_tab.dart` | 35-39, 155-196 |
| **PATH3-13-02** | Step 13: Home | Home Check-in Interactions Mutate In-Memory Mock State Without Firebase Sync | **P2** | `lib/features/home/widgets/today_check_in_card.dart` | 83-117 |
| **PATH3-14-01** | Step 14: Cold Restart | Pre-Fetch State Reset Leads to Data Loss and Unhandled Exceptions on Cold Restart | **P0** | `lib/state/auth_state.dart` | 537-575, 798-817 |
| **PATH3-14-02** | Step 14: Cold Restart | Cold Restart with Missing Draft Triggers Inconsistent Onboarding State | **P1** | `lib/state/auth_state.dart` | 656-665 |
| **PATH3-15-01** | Step 15: Sign Out | Incomplete State Purge on Sign Out (Leaked Timers, Streams, and Mounted Widgets) | **P0** | `lib/state/auth_state.dart`<br>`lib/features/recovery/services/recovery_retry_controller.dart`<br>`lib/features/profile/profile_tab.dart` | `auth_state.dart`: 299-318, 953-985<br>`recovery_retry_controller.dart`: 35-93<br>`profile_tab.dart`: 31-73 |
| **PATH3-16-01** | Step 16: Sign In | Account Switch Data Leak / Cross-Account Data Contamination | **P0** | `lib/state/auth_state.dart` | 159-194, 537-575, 877-900 |
| **PATH3-16-02** | Step 16: Sign In | Anonymous-to-Email Account Data Migration Race & Immediate Reset Overwrite | **P1** | `lib/state/auth_state.dart` | 248-297 |
| **PATH3-17-01** | Step 17: Recovery | Synthesize Recovery Action Fabricates Fake Completion Data & Causes Infinite Retry Loops | **P0** | `lib/state/auth_state.dart`<br>`lib/features/recovery/screens/onboarding_recovery_screen.dart` | `auth_state.dart`: 736-747, 987-1085<br>`onboarding_recovery_screen.dart`: 265-278 |
| **PATH3-17-02** | Step 17: Recovery | Incomplete PII Redaction and Raw Diagnostic Data Display | **P1** | `lib/features/recovery/services/diagnostic_bundle_service.dart`<br>`lib/features/recovery/screens/onboarding_recovery_screen.dart` | `diagnostic_bundle_service.dart`: 17-26, 49-78<br>`onboarding_recovery_screen.dart`: 98-121 |
| **PATH3-SEC-01** | Security / Firestore | Wildcard Subcollection Catch-All Rule Bypasses All Schema & Type Validation | **P0** | `firestore.rules` | 985-996 |
| **PATH3-SEC-02** | Security / Firestore | Permissive Onboarding Collection Rule Allows Malformed Document Injection | **P0** | `firestore.rules` | 929-931 |
| **PATH3-SEC-03** | Security / Firestore | Root User Profile Document (`/users/{uid}`) Lacks Key & Field Length Rules | **P1** | `firestore.rules` | 977-979 |

---

## 3. Detailed Audit Findings

### Step 12: Router Transition

#### PATH3-12-01: Route Guard Ambiguity & Infinite Redirect Loop between `/onboarding` and `/onboarding/recovery`
- **Severity**: **P0**
- **Execution Step**: Step 12 (Router Transition)
- **Production Files**: `lib/core/router/app_router.dart` (Lines 53–96)
- **Root Cause Analysis**:
  In `optivusAuthRedirect`:
  ```dart
  // Lines 53-60:
  final isProjectionFailed = userProfile.onboardingProjectionStatus == 'failed' ||
      authState.backendRestoreFailed ||
      authState.onboardingFailureReason != null;

  if (isProjectionFailed && authState.onboardingIncomplete != true) {
    return uri.path == '/onboarding/recovery' ? null : '/onboarding/recovery';
  }
  ...
  // Lines 79-89:
  if (!onboardingInputCompleted || authState.onboardingIncomplete) {
    if (uri.path != '/onboarding') return '/onboarding';
    return null;
  }

  if (onboardingInputCompleted && !onboardingCompleted) {
    if (uri.path != '/onboarding/recovery' && uri.path != '/loading') {
      return '/onboarding/recovery';
    }
    return null;
  }
  ```
  When `userProfile.onboardingInputCompleted == true` and `userProfile.onboardingCompleted == false`, but `authState.status == AuthFlowStatus.signedInOnboardingIncomplete` (`authState.onboardingIncomplete == true`):
  Line 79 checks `!onboardingInputCompleted || authState.onboardingIncomplete`. Since `authState.onboardingIncomplete` is `true`, line 79 evaluates to `true` and returns `/onboarding`.
  However, once on `/onboarding`, if `markOnboardingComplete` or recovery occurs, or if state transitions to `backendRestoreFailed`, line 84 sees `onboardingInputCompleted && !onboardingCompleted` and evaluates to `true`, returning `/onboarding/recovery`.
  Because `onboardingIncomplete` and `onboardingInputCompleted && !onboardingCompleted` have overlapping, contradictory conditions depending on `authState.status` vs `userProfile` flags, the router enters an infinite navigation loop or rapidly flashes screens between `/onboarding` and `/onboarding/recovery`.
- **Step-by-Step Repro Steps**:
  1. Create a user account that completes onboarding input (`onboardingInputCompleted = true`), but set `onboardingCompleted = false` or trigger backend restore failure.
  2. Cold start the app or sign in.
  3. Observe GoRouter evaluating `optivusAuthRedirect`. Line 79 matches `authState.onboardingIncomplete == true` and redirects to `/onboarding`.
  4. On `/onboarding`, the state update for `backendRestoreFailed` fires, matching line 58 or line 84, returning `/onboarding/recovery`.
  5. The router rapidly loops between `/onboarding` and `/onboarding/recovery`.
- **Recommended Minimal Safe Fix**:
  Disambiguate route guard precedence in `optivusAuthRedirect`. Check `isProjectionFailed` first, and ensure `authState.onboardingIncomplete` is only checked when `!onboardingInputCompleted`:
  ```dart
  if (!onboardingInputCompleted) {
    return uri.path == '/onboarding' ? null : '/onboarding';
  }
  if (!onboardingCompleted || isProjectionFailed) {
    return uri.path == '/onboarding/recovery' ? null : '/onboarding/recovery';
  }
  ```

---

#### PATH3-12-02: Side-Effect State Mutations Inside GoRouter `redirect` Callbacks
- **Severity**: **P1**
- **Execution Step**: Step 12 (Router Transition)
- **Production Files**: `lib/core/router/app_router.dart` (Lines 104–140, 186–463)
- **Root Cause Analysis**:
  Functions `openTrackerDetail`, `openHomeDetail`, `openProfileDetail`, `openRoutineDetail`, `openCoachDetail`, and `openGoalsDetail` mutate Riverpod provider state directly inside route `redirect` handlers:
  ```dart
  String openTrackerDetail(TrackerDetailView detail) {
    ref.read(appNavigationProvider.notifier).goToTracker();
    ref.read(trackerDetailViewRequestProvider.notifier).state =
        TrackerDetailTarget.view(detail);
    return '/app?tab=2';
  }
  ```
  Calling `ref.read(...).state = ...` inside GoRouter's `redirect` callback occurs during Flutter's build / route-matching phase. Mutating state in the build phase causes Flutter to throw `"Cannot update a provider while the widget tree is building"` or creates race conditions where listeners trigger duplicate route evaluations.
- **Step-by-Step Repro Steps**:
  1. Trigger deep link `/tracker/money` or navigate to `/profile/edit`.
  2. GoRouter matches line 194 `redirect: (context, state) => openTrackerDetail(TrackerDetailView.money)`.
  3. `openTrackerDetail` executes `ref.read(...).state = ...` synchronously inside `redirect`.
  4. Observe framework warnings / assertion failures in Flutter debug logs and UI frame skips.
- **Recommended Minimal Safe Fix**:
  Defer provider mutations using `WidgetsBinding.instance.addPostFrameCallback` or handle sub-feature tab navigation inside `AppShell` / feature controllers rather than mutating providers directly inside GoRouter `redirect`.

---

#### PATH3-12-03: Query Parameter Tab Index Mismatch with `AppNavigationController` State
- **Severity**: **P1**
- **Execution Step**: Step 12 (Router Transition)
- **Production Files**: `lib/views/screens/app_shell.dart` (Lines 51–65), `lib/core/router/app_router.dart` (Lines 178–185)
- **Root Cause Analysis**:
  In `AppShell.initState()`, `initialIndex` is clamped and passed to `appNavigationProvider.notifier.setTab(initialIndex)`.
  However, if `AppShell` receives `initialIndex` via `/app?tab=2`, but the user previously had `appNavigationProvider` set to `0`, `AppShell` renders `_tabCache` based on `ref.watch(appNavigationProvider)`. If a re-render occurs before `initState` post-frame callback completes, `AppShell` displays tab 0 while the URL parameter specifies tab 2.
- **Step-by-Step Repro Steps**:
  1. Open app at `/app?tab=3`.
  2. `AppShell` initializes with `initialIndex = 3`.
  3. If an auth state refresh occurs, `AppShell` re-reads `appNavigationProvider`. If `appNavigationProvider` was not updated synchronously, tab 0 is rendered.
- **Recommended Minimal Safe Fix**:
  Synchronize `appNavigationProvider` state directly in `AppShell` constructor or ensure `AppShell` listens to URL parameter changes consistently.

---

### Step 13: Home Screen

#### PATH3-13-01: Hardcoded User Name Fallbacks & Mock Dashboard State Fallback in Production Path
- **Severity**: **P1**
- **Execution Step**: Step 13 (Home Screen)
- **Production Files**: `lib/features/home/home_tab.dart` (Lines 35–39, 155–196)
- **Root Cause Analysis**:
  In `_safeHomeDisplayName`:
  ```dart
  if (emailValue == 'test@optivus.dev') return 'Nairit';
  return 'there';
  ```
  Line 194 hardcodes a check for `test@optivus.dev` returning `'Nairit'`. In production execution, if `profile.displayName` or `auth.user?.displayName` is missing, it falls back to a hardcoded string rather than attempting to extract from UserProfile repository or showing user email local part. Furthermore, `HomeTab` displays `dashboardState = ref.watch(homeDashboardProvider)`, which initializes with static mock state (`_initialMockState()`) rather than fetching real Firestore data in Firebase mode.
- **Step-by-Step Repro Steps**:
  1. Sign in as `test@optivus.dev` in production mode.
  2. Observe Home header displaying `'Nairit'` regardless of profile settings.
  3. Sign in as any user; observe Home dashboard check-ins and insights showing static mock data instead of live Firestore documents.
- **Recommended Minimal Safe Fix**:
  Remove hardcoded email checks in `_safeHomeDisplayName`. Wire `homeDashboardProvider` to listen to real user profile and Firestore repository streams when `OptivusBackendConfig.useFirebase` is enabled.

---

#### PATH3-13-02: Home Check-in Interactions Mutate In-Memory Mock State Without Firebase Sync
- **Severity**: **P2**
- **Execution Step**: Step 13 (Home Screen)
- **Production Files**: `lib/features/home/widgets/today_check_in_card.dart` (Lines 83–117)
- **Root Cause Analysis**:
  When a user taps a check-in option on the Home tab, `today_check_in_card.dart` calls:
  `ref.read(mockTrackerProvider.notifier).saveMoneyToday(...)` and `ref.read(homeDashboardProvider.notifier).completeCheckIn(...)`.
  These calls update in-memory Riverpod state only. In Firebase mode, no repository write or Firestore document update (`/users/{uid}/routineHistory` or `/users/{uid}/trackers`) is dispatched, causing user check-ins to be lost upon app restart.
- **Step-by-Step Repro Steps**:
  1. Complete a Check-In card on the Home Screen.
  2. Restart the app.
  3. Observe check-in state reverted to uncompleted.
- **Recommended Minimal Safe Fix**:
  Dispatch repository save calls (`routineRepository.saveOccurrence` or `trackerRepository.saveLog`) inside `completeCheckIn` when running in Firebase mode.

---

### Step 14: Cold Restart

#### PATH3-14-01: Pre-Fetch State Reset Leads to Data Loss and Unhandled Exceptions on Cold Restart
- **Severity**: **P0**
- **Execution Step**: Step 14 (Cold Restart)
- **Production Files**: `lib/state/auth_state.dart` (Lines 537–575, 798–817)
- **Root Cause Analysis**:
  In `_loadOrCreateBackendUserState(AuthUser user)`:
  ```dart
  // Line 538:
  _resetSignedOutState(targetUserUid: user.uid);
  ...
  try {
    var profile = await profileRepository.fetchUserProfile(user.uid);
    ...
  } catch (e) {
    if (!_isCurrentRestore(restoreGeneration)) return;
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.backendRestoreFailed,
      errorMessage: mapped.message,
      failureReason: mapped.reason,
    );
  }
  ```
  `_resetSignedOutState` is invoked on Line 538 **BEFORE** the network call to `fetchUserProfile` completes. If `fetchUserProfile` or subsequent fetches fail due to network offline / timeout:
  1. All local user state has already been erased by `_resetSignedOutState`.
  2. The app sets state to `backendRestoreFailed`.
  3. If the user is offline, all previously cached in-memory state is lost, forcing the user into a dead-end recovery state.
- **Step-by-Step Repro Steps**:
  1. Open app while network connectivity is poor or offline during cold restart.
  2. `_loadOrCreateBackendUserState` runs `_resetSignedOutState` at line 538.
  3. `fetchUserProfile` throws a network exception.
  4. App enters `backendRestoreFailed`, but all cached user data in Riverpod notifiers was wiped beforehand.
- **Recommended Minimal Safe Fix**:
  Do not call `_resetSignedOutState` before fetching backend user state. Only reset or replace state after backend user state has been successfully retrieved or validated.

---

#### PATH3-14-02: Cold Restart with Missing Draft Triggers Inconsistent Onboarding State
- **Severity**: **P1**
- **Execution Step**: Step 14 (Cold Restart)
- **Production Files**: `lib/state/auth_state.dart` (Lines 656–665)
- **Root Cause Analysis**:
  When restoring onboarding state (`!profile.onboardingCompleted`), line 653 fetches the draft. If `savedDraft == null`, line 663 calls:
  `_ref.read(mockOnboardingProvider.notifier).reset(user.uid)`.
  However, `profile.onboardingInputCompleted` may still be `true`. This causes a state split: `userProfile` says input is completed, but `mockOnboardingProvider` has a blank draft at step 0. Router redirects to `/onboarding/recovery`, but recovery sees no bundle and no draft, throwing `missingDraftAndBundle`.
- **Step-by-Step Repro Steps**:
  1. Create a user where `onboardingInputCompleted = true` and `onboardingCompleted = false`, but delete or fail to load `onboarding/draft`.
  2. Cold restart the app.
  3. Observe app entering `OnboardingRecoveryScreen` with `Missing Bundle & Draft`.
- **Recommended Minimal Safe Fix**:
  Handle missing draft gracefully by synthesizing a draft from existing profile attributes or prompting the user to resume at the last completed step.

---

### Step 15: Sign Out

#### PATH3-15-01: Incomplete State Purge on Sign Out (Leaked Timers, Streams, and Mounted Widgets)
- **Severity**: **P0**
- **Execution Step**: Step 15 (Sign Out)
- **Production Files**: `lib/state/auth_state.dart` (Lines 299–318, 953–985), `lib/features/recovery/services/recovery_retry_controller.dart` (Lines 35–93), `lib/features/profile/profile_tab.dart` (Lines 31–73)
- **Root Cause Analysis**:
  When `logout()` is called:
  `_resetSignedOutState()` resets several StateNotifiers. However:
  1. **Timers Not Cancelled**: `recoveryRetryControllerProvider` manages an active `Timer.periodic`. `_resetSignedOutState()` does NOT call `recoveryRetryControllerProvider.notifier.reset()`. The cooldown timer continues running in the background after sign out!
  2. **Mounted Screen State Retained**: `AppShell` uses an `IndexedStack` to keep `ProfileTab` and `HomeTab` mounted. `_ProfileTabState` holds local state `_activeDetail` (e.g. `ProfileDetailView.editProfile`). Calling `logout()` resets global providers, but does NOT reset `_activeDetail` in `_ProfileTabState` or clear `TextEditingController` instances inside `EditProfileScreen`.
  3. **Repository Streams Left Active**: `onboardingCompletionJobProvider` family streams are not cancelled upon sign out.
- **Step-by-Step Repro Steps**:
  1. Open `OnboardingRecoveryScreen` and trigger a retry to start the cooldown timer.
  2. Tap `Sign Out`.
  3. Observe in debugger: `RecoveryRetryController` timer continues firing `_timer.periodic` callbacks every second after sign out.
  4. Open `ProfileTab` -> `EditProfileScreen`, type custom text into `Name` field, and click `Log Out`.
  5. Sign in as a different user on the same device.
  6. Navigate to Profile tab; observe `_ProfileTabState` is still displaying `EditProfileScreen` with User A's typed input!
- **Recommended Minimal Safe Fix**:
  In `_resetSignedOutState()`:
  1. Add `_ref.read(recoveryRetryControllerProvider.notifier).reset()`.
  2. Reset all feature sub-navigation request states to `.none()`.
  3. Provide a global state version key or invalidate `AppShell` tab cache on auth status transition to `signedOut`.

---

### Step 16: Sign In

#### PATH3-16-01: Account Switch Data Leak / Cross-Account Data Contamination
- **Severity**: **P0**
- **Execution Step**: Step 16 (Sign In)
- **Production Files**: `lib/state/auth_state.dart` (Lines 159–194, 537–575, 877–900)
- **Root Cause Analysis**:
  When User A logs out and User B logs in on the same app instance:
  `_loadOrCreateBackendUserState(userB)` is executed.
  If `_loadOrCreateBackendUserState` encounters an error during restoration (e.g., `fetchProfileSettings` throws an exception), execution jumps to `catch (e)` at line 807.
  Because `_loadOrCreateBackendUserState` resets states at the beginning, but feature state notifiers (like `homeMindNoteProvider` or `homeDashboardProvider`) are NOT scoped by user ID via `.family`, any un-cleared state from User A remains in Riverpod memory.
  When User B logs in, User B sees User A's cached mind notes, goals, or check-ins until a full state reload occurs.
- **Step-by-Step Repro Steps**:
  1. User A logs in, creates a private mind note ("Secret Note User A") and custom tracker logs.
  2. User A logs out.
  3. User B logs in, but network drops during profile settings fetch.
  4. User B is shown the app UI or fallback screen; `homeMindNoteProvider` still contains "Secret Note User A".
- **Recommended Minimal Safe Fix**:
  Scope user-dependent providers by User ID using `.family` or unconditionally invalidate all user-data providers in Riverpod on any `authState` transition where `user.uid` changes.

---

#### PATH3-16-02: Anonymous-to-Email Account Data Migration Race & Immediate Reset Overwrite
- **Severity**: **P1**
- **Execution Step**: Step 16 (Sign In)
- **Production Files**: `lib/state/auth_state.dart` (Lines 248–297)
- **Root Cause Analysis**:
  In `linkAnonymousWithEmail`:
  ```dart
  if (oldAnonUid != null && oldAnonUid != user.uid) {
    await OnboardingAccountMigrationService.migrateAccountData(
      oldAnonUid: oldAnonUid,
      newUid: user.uid,
      read: _ref.read,
    );
  }
  ...
  await _loadOrCreateBackendUserState(user);
  ```
  `OnboardingAccountMigrationService.migrateAccountData` copies memory state from `oldAnonUid` to `user.uid`.
  Immediately afterward, `_loadOrCreateBackendUserState(user)` is called, which begins with `_resetSignedOutState(targetUserUid: user.uid)`.
  `_resetSignedOutState` calls `_resetUserScopedMockState()` and resets providers, erasing the in-memory data just migrated by `OnboardingAccountMigrationService`!
- **Step-by-Step Repro Steps**:
  1. Sign in anonymously, set up onboarding draft and local routine items.
  2. Link account with email and password.
  3. Observe `OnboardingAccountMigrationService` run, followed immediately by `_loadOrCreateBackendUserState`.
  4. Observe `_resetSignedOutState` wiping the newly migrated memory state.
- **Recommended Minimal Safe Fix**:
  Pass a flag to `_loadOrCreateBackendUserState` indicating an account migration has just occurred so that `_resetSignedOutState` does not wipe the newly migrated memory state.

---

### Step 17: Recovery

#### PATH3-17-01: Synthesize Recovery Action Fabricates Fake Completion Data & Causes Infinite Retry Loops
- **Severity**: **P0**
- **Execution Step**: Step 17 (Recovery)
- **Production Files**: `lib/state/auth_state.dart` (Lines 736–747, 987–1085), `lib/features/recovery/screens/onboarding_recovery_screen.dart` (Lines 265–278)
- **Root Cause Analysis**:
  1. **Data Fabrication**: `SynthesizeBundleAction` in `executeRecoveryAction`:
     ```dart
     if (action is SynthesizeBundleAction) {
       final synthesizedDraft = OnboardingDraft(uid: currentUser.uid).copyWith(
         onboardingCompleted: true,
         currentStep: OnboardingDraft.lastStepIndex,
       );
       final bundle = OnboardingCompletionService.buildBundle(synthesizedDraft);
       await _ref.read(onboardingRepositoryProvider).saveDraft(synthesizedDraft);
       await _ref.read(onboardingRepositoryProvider).saveCompletionBundle(bundle);
       await retryBackendRestore();
       return;
     }
     ```
     Creating a blank `OnboardingDraft` with `onboardingCompleted: true` fabricates empty routine items, empty goals, and empty user profile attributes, saving them to Firestore and permanently overwriting user setup data.
  2. **Infinite Recovery Loop**:
     When projection receipt validation fails in `_loadOrCreateBackendUserState` (line 736), it throws `_RoutineProjectionRestoreException` with actions `[ForceResyncProjectionsAction(), RetryCompletionJobAction(), RebuildBundleFromDraftAction()]`.
     When the user taps any of these actions on `OnboardingRecoveryScreen`, `executeRecoveryAction` runs and calls `retryBackendRestore()`.
     `retryBackendRestore()` invokes `_loadOrCreateBackendUserState(user)`.
     `_loadOrCreateBackendUserState` executes the exact same validation check, fails again, throws `_RoutineProjectionRestoreException`, and sets status to `backendRestoreFailed`.
     The user is trapped in an infinite retry loop with no way out except signing out.
- **Step-by-Step Repro Steps**:
  1. Cause projection receipt validation to fail (e.g. invalid receipt status in Firestore).
  2. App navigates to `OnboardingRecoveryScreen`.
  3. Tap `Retry Setup Verification` or `Force Resync Projections`.
  4. Observe app re-executing `retryBackendRestore`, failing validation again, and returning to the exact same recovery screen infinitely.
- **Recommended Minimal Safe Fix**:
  1. Remove automatic fabrication of blank completion bundles in `SynthesizeBundleAction`. If draft is missing, prompt user to restart onboarding input rather than fabricating fake data.
  2. In `executeRecoveryAction`, track retry attempts per action and gracefully degrade to `RestartOnboardingInputAction` if repeated resync attempts fail validation.

---

#### PATH3-17-02: Incomplete PII Redaction and Raw Diagnostic Data Display
- **Severity**: **P1**
- **Execution Step**: Step 17 (Recovery)
- **Production Files**: `lib/features/recovery/services/diagnostic_bundle_service.dart` (Lines 17–26, 49–78), `lib/features/recovery/screens/onboarding_recovery_screen.dart` (Lines 98–121)
- **Root Cause Analysis**:
  In `DiagnosticBundleService`:
  ```dart
  static String redactPii(String input, {String? userName}) {
    var redacted = input.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    if (userName != null && userName.trim().isNotEmpty) {
      final namePattern = RegExp(RegExp.escape(userName.trim()), caseSensitive: false);
      redacted = redacted.replaceAll(namePattern, '[REDACTED_NAME]');
    }
    return redacted;
  }
  ```
  `redactPii` only redacts standard email format and exact matches of `userName`. It does NOT redact:
  - Local file system paths (e.g. `/Users/username/...`).
  - Auth user IDs or device tokens embedded inside exception messages (`errorMessage`).
  - Names containing special regex characters or non-standard whitespace.
  Additionally, `OnboardingRecoveryScreen` displays this JSON directly in a selectable dialog on screen.
- **Step-by-Step Repro Steps**:
  1. Trigger a recovery failure where `errorMessage` contains local file paths or token IDs.
  2. On `OnboardingRecoveryScreen`, tap `Diagnostics`.
  3. Observe un-redacted local file paths and internal system details in the JSON viewer.
- **Recommended Minimal Safe Fix**:
  Enhance `redactPii` to redact system paths (`/Users/...`, `/data/user/...`) and internal auth tokens. Sanitize `errorMessage` strings before inclusion in diagnostic export bundles.

---

### Security Gaps & Firestore Rules (`firestore.rules`)

#### PATH3-SEC-01: Wildcard Subcollection Catch-All Rule Bypasses All Schema & Type Validation
- **Severity**: **P0**
- **Execution Step**: Security / Firestore Rules
- **Production Files**: `firestore.rules` (Lines 985–996)
- **Root Cause Analysis**:
  `firestore.rules` contains the following catch-all rule at the end of the database match block:
  ```firestore
  // Temporary verified-owner development catchall.
  // Home/Routine/Tracker/Goals/Coach backend collections must get specific
  // collection rules before production release. Uploads and import reviews
  // are excluded here because their stricter rules above already apply.
  match /users/{uid}/{collectionId}/{document=**} {
    allow read, write: if verifiedOwner(uid)
      && collectionId != "uploads"
      && collectionId != "routineImportReviews"
      && collectionId != "routineItems"
      && collectionId != "routineHistory"
      && collectionId != "routineEvents"
      && collectionId != "routineProjections"
      && collectionId != "habitSystems"
      && collectionId != "syncAllowances"
      && collectionId != "syncEvents";
  }
  ```
  This rule acts as an open `allow read, write` for **ALL** other subcollections under `/users/{uid}/`, including `goals`, `trackers`, `coach`, `mindNotes`, `settings`, `profile`, `home`, etc.
  Because no field validation, key validation, or data type checking exists for these collections:
  1. Any user can write arbitrary JSON payloads of any structure or size (up to 1 MB per document).
  2. Malicious or malformed client writes can inject invalid types (e.g., string where int is expected), breaking app parsers and causing client crashes.
  3. Development catch-all rules violate production security guidelines.
- **Step-by-Step Repro Steps**:
  1. Authenticate as a verified user in Firebase.
  2. Execute a Firestore write to `/users/{uid}/goals/malicious_doc` containing `{ "invalidField": 99999, "hugeString": "..." }`.
  3. Observe write succeeding without any security rule rejection.
- **Recommended Minimal Safe Fix**:
  Remove the wildcard catch-all rule `match /users/{uid}/{collectionId}/{document=**}`. Replace it with explicit, schema-validated match rules for every feature collection (`goals`, `trackers`, `coachSessions`, `mindNotes`, `settings`).

---

#### PATH3-SEC-02: Permissive Onboarding Collection Rule Allows Malformed Document Injection
- **Severity**: **P0**
- **Execution Step**: Security / Firestore Rules
- **Production Files**: `firestore.rules` (Lines 929–931)
- **Root Cause Analysis**:
  In `firestore.rules`:
  ```firestore
  // Phase 2B onboarding draft/completion bundle. Validation stays light for
  // early development; production backend modules must add specific schemas.
  match /users/{uid}/onboarding/{docId} {
    allow read, write: if verifiedOwner(uid);
  }
  ```
  The `/users/{uid}/onboarding/{docId}` collection (which stores `draft` and `completion_bundle`) has **NO** validation functions attached.
  Any verified user can overwrite their `draft` or `completion_bundle` with arbitrary JSON, null values, or corrupted structures, which breaks `OnboardingFrontendHydrationService` and causes persistent app crashes or recovery loops.
- **Step-by-Step Repro Steps**:
  1. Authenticate as a verified user.
  2. Write `{ "corrupted": true }` to `/users/{uid}/onboarding/completion_bundle`.
  3. Restart the app.
  4. Observe `_loadOrCreateBackendUserState` throwing corrupted bundle exceptions and failing restoration.
- **Recommended Minimal Safe Fix**:
  Implement helper functions `validOnboardingDraft(data)` and `validOnboardingCompletionBundle(data)` in `firestore.rules` requiring schema version, UID match, allowed keys, and type assertions on required fields.

---

#### PATH3-SEC-03: Root User Profile Document (`/users/{uid}`) Lacks Key & Field Length Rules
- **Severity**: **P1**
- **Execution Step**: Security / Firestore Rules
- **Production Files**: `firestore.rules` (Lines 977–979)
- **Root Cause Analysis**:
  In `firestore.rules`:
  ```firestore
  match /users/{uid} {
    allow read, write: if verifiedOwner(uid);
  }
  ```
  The root user profile document `/users/{uid}` allows `write` for any verified owner without restricting keys, checking field types, or validating string lengths (e.g. `displayName`, `bio`).
- **Step-by-Step Repro Steps**:
  1. Write an oversized string or unexpected keys to `/users/{uid}`.
  2. Observe Firestore accepting the document write.
- **Recommended Minimal Safe Fix**:
  Define a `validUserProfile(data)` function in `firestore.rules` validating allowed keys (`uid`, `email`, `displayName`, `onboardingCompleted`, `onboardingInputCompleted`, `createdAt`, `updatedAt`, etc.) and enforcing max length limits on string fields.

---

## 4. Verification Matrix

| Step | Area | Verification Method | Status |
|---|---|---|---|
| 12 | Router Transition | Code inspection of `app_router.dart` (`optivusAuthRedirect`) | **FAILED** (Loop & ambiguity found) |
| 13 | Home Screen | Code inspection of `home_tab.dart` & `today_check_in_card.dart` | **FAILED** (Hardcoded name & mock mutation) |
| 14 | Cold Restart | Code inspection of `auth_state.dart` (`_loadOrCreateBackendUserState`) | **FAILED** (Pre-fetch state reset hazard) |
| 15 | Sign Out | Code inspection of `auth_state.dart` (`logout`) & widget states | **FAILED** (Leaked timers & mounted screens) |
| 16 | Sign In | Code inspection of `auth_state.dart` (account switch & link) | **FAILED** (Cross-account leakage & race condition) |
| 17 | Recovery | Code inspection of `onboarding_recovery_screen.dart` & `auth_state.dart` | **FAILED** (Fabrication & infinite retry loop) |
| Sec | Security / Rules | Line-by-line validation of `firestore.rules` | **FAILED** (Wildcard catch-all & unvalidated onboarding) |

---

## 5. Conclusion & Actionable Recommendations

The real production execution path for Steps 12–17 and Firestore Rules contains **6 P0 Critical Defects/Vulnerabilities** and **6 P1 High Severity Issues**. 

### Immediate Remediation Priority:
1. **Firestore Rules Hardening**: Remove the development catch-all rule (`match /users/{uid}/{collectionId}/{document=**}`) and add strict schema validation to `/users/{uid}/onboarding/{docId}` and `/users/{uid}`.
2. **Router Disambiguation**: Refactor `optivusAuthRedirect` in `app_router.dart` to eliminate overlapping conditions between `onboardingIncomplete` and `onboardingInputCompleted`.
3. **Sign Out / Sign In Purge**: Ensure `logout()` cancels background timers (`RecoveryRetryController`), invalidates family providers, and resets nested screen widget controllers.
4. **Recovery Integrity**: Remove data fabrication in `SynthesizeBundleAction` and cap retry attempts in `executeRecoveryAction` to break infinite restore loops.
