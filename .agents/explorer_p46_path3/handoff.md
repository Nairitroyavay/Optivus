# HANDOFF REPORT — Explorer Path 3 (Phase 4.6)

**Agent Role**: `explorer_p46_path3`  
**Target Scope**: Steps 12 through 17 & Security/Firestore Rules (`firestore.rules`)  
**Working Directory**: `/Users/roy/optivus2/Optivus/.agents/explorer_p46_path3`  
**Audit Report Location**: `/Users/roy/optivus2/Optivus/.agents/explorer_p46_path3/audit_path3.md`  

---

## 1. Observation

Direct code examination of the production files yielded the following exact findings:

- **`lib/core/router/app_router.dart` (Lines 53–96)**:
  `optivusAuthRedirect` contains overlapping condition blocks: `isProjectionFailed` (lines 53–60), `!onboardingInputCompleted || authState.onboardingIncomplete` (lines 79–83), and `onboardingInputCompleted && !onboardingCompleted` (lines 84–89). When `authState.onboardingIncomplete` is true while `onboardingInputCompleted` is true, line 79 routes to `/onboarding`, whereas state updates immediately evaluate line 84 to route to `/onboarding/recovery`, causing a redirect loop.
- **`lib/core/router/app_router.dart` (Lines 104–140, 186–463)**:
  Redirect helper functions `openTrackerDetail`, `openHomeDetail`, `openProfileDetail`, `openRoutineDetail`, `openCoachDetail`, and `openGoalsDetail` call `ref.read(...).state = ...` synchronously inside GoRouter `redirect` callbacks during the widget build phase.
- **`lib/features/home/home_tab.dart` (Lines 35–39, 155–196)**:
  `_safeHomeDisplayName` contains hardcoded email matching: `if (emailValue == 'test@optivus.dev') return 'Nairit'`. Furthermore, `HomeTab` listens to `homeDashboardProvider`, which defaults to in-memory `_initialMockState()` instead of connecting to real Firestore streams when `OptivusBackendConfig.useFirebase` is true.
- **`lib/state/auth_state.dart` (Lines 537–575, 798–817)**:
  `_loadOrCreateBackendUserState` invokes `_resetSignedOutState(targetUserUid: user.uid)` at line 538 *before* attempting `profileRepository.fetchUserProfile(user.uid)`. When the network call throws an error, local state has already been cleared, stranding the user in `backendRestoreFailed` without local fallback data.
- **`lib/state/auth_state.dart` (Lines 299–318, 953–985)** & **`lib/features/recovery/services/recovery_retry_controller.dart` (Lines 35–93)** & **`lib/features/profile/profile_tab.dart` (Lines 31–73)**:
  `logout()` calls `_resetSignedOutState()`, but does not reset active background `Timer.periodic` instances in `RecoveryRetryController`, does not reset mounted `_ProfileTabState._activeDetail` inside `AppShell`'s `IndexedStack`, and does not cancel `onboardingCompletionJobProvider` family streams.
- **`lib/state/auth_state.dart` (Lines 159–194, 248–297, 877–900)**:
  `linkAnonymousWithEmail` calls `OnboardingAccountMigrationService.migrateAccountData`, then immediately calls `_loadOrCreateBackendUserState`, which invokes `_resetSignedOutState` and erases the migrated in-memory state. When switching accounts, un-scoped Riverpod providers (`homeMindNoteProvider`, `homeDashboardProvider`) retain User A's data if User B's restore encounters an error.
- **`lib/state/auth_state.dart` (Lines 736–747, 987–1085)** & **`lib/features/recovery/screens/onboarding_recovery_screen.dart` (Lines 265–278)**:
  `SynthesizeBundleAction` creates a blank `OnboardingDraft` with `onboardingCompleted: true` and saves it, silently fabricating empty setup data. Tapping recovery retry actions invokes `retryBackendRestore()`, which runs `_loadOrCreateBackendUserState` and fails projection receipt validation again, locking the UI in an infinite recovery loop.
- **`firestore.rules` (Lines 985–996)**:
  Contains a wildcard development catch-all: `match /users/{uid}/{collectionId}/{document=**} { allow read, write: if verifiedOwner(uid) && ... }`. This allows verified users to write arbitrary, unvalidated JSON to any un-enumerated subcollection (Goals, Coach, Tracker, MindNotes, Settings).
- **`firestore.rules` (Lines 929–931, 977–979)**:
  `match /users/{uid}/onboarding/{docId}` and `match /users/{uid}` allow `read, write` for `verifiedOwner(uid)` without schema, key, or field length validation functions.

---

## 2. Logic Chain

1. **Router Loop**: In `app_router.dart`, `optivusAuthRedirect` evaluates multiple `if` blocks sequentially. When a user has completed input but has not completed projection, `authState.onboardingIncomplete` causes Line 79 to redirect to `/onboarding`. Once on `/onboarding`, the state update for `backendRestoreFailed` or `onboardingCompleted == false` triggers Line 84 to redirect to `/onboarding/recovery`. Because these two rules check conflicting sources of truth (`authState.status` vs `userProfile` flags), the router alternates between the two locations endlessly.
2. **Account Contamination & Sign Out Leak**: `logout()` clears specific top-level Riverpod notifiers, but does not tear down `StateNotifier` timer instances or unmount `AppShell` `IndexedStack` child widget states. When User B logs in after User A, any UI controller state or un-resetted provider in memory presents User A's state to User B. Furthermore, `linkAnonymousWithEmail` migrates data into memory, but `_loadOrCreateBackendUserState` immediately wipes memory state before saving to Firestore.
3. **Recovery Data Fabrication & Loop**: `SynthesizeBundleAction` constructs a default empty draft and marks `onboardingCompleted = true`. If a user's completion bundle is corrupted or missing, executing this action overwrites the user's data with empty defaults. If projection receipt validation fails, retrying the action re-triggers `_loadOrCreateBackendUserState`, which throws the exact same exception, creating an inescapable loop.
4. **Security Vulnerability**: `firestore.rules` line 985 provides a wildcard match `match /users/{uid}/{collectionId}/{document=**}` for all subcollections except 10 excluded names. This leaves collections like `goals`, `trackers`, `coachSessions`, `mindNotes`, and `userSettings` completely unvalidated. Any verified owner can upload corrupted or malformed documents into Firestore.

---

## 3. Caveats

- **Runtime Execution**: This investigation was conducted purely via static source code inspection and logic tracing. Actual runtime behavior under specific latency conditions should be verified with unit and integration tests.
- **Firebase vs Fake Mode**: In fake mode (`OptivusBackendMode.fake`), Firestore security rules are not enforced by the local client. The `firestore.rules` vulnerabilities only manifest when connected to an actual Firebase emulator or production Firebase project.

---

## 4. Conclusion

All previous `PASSED` claims for Steps 12 through 17 and Security/Firestore rules are **NOT VERIFIED** and have been invalidated. A total of **6 P0 Critical Defects/Security Vulnerabilities**, **6 P1 High Severity Defects**, and **1 P2 Defect** were identified and documented in detail in `audit_path3.md`.

Remediation requires:
1. Hardening `firestore.rules` by removing the wildcard catch-all and adding strict schema checkers for onboarding and feature collections.
2. Disambiguating GoRouter route guard logic in `app_router.dart`.
3. Ensuring atomic, complete state purges on sign out and user switching.
4. Eliminating fake data synthesis and endless retry loops in onboarding recovery.

---

## 5. Verification Method

To independently verify these findings:
1. **Router Loop**: Set `userProfile.onboardingInputCompleted = true`, `userProfile.onboardingCompleted = false`, and `authState.status = AuthFlowStatus.signedInOnboardingIncomplete`. Launch the app and inspect GoRouter log output for redirect cycles between `/onboarding` and `/onboarding/recovery`.
2. **Sign Out / Account Switch Leak**: Log in as User A, navigate to `ProfileTab` -> `EditProfileScreen`, type input, then log out. Log in as User B; inspect `ProfileTab` to see User A's typed input still present in the text controller.
3. **Firestore Security Rules**: Deploy `firestore.rules` to a Firebase project or local emulator (`firebase emulators:start --only firestore`). Attempt to write `{ "malicious_field": "unvalidated_data" }` to `/users/{uid}/goals/test_doc`. Confirm the write succeeds under the wildcard catch-all rule on Line 985.
4. **Audit Report Inspection**: Read `/Users/roy/optivus2/Optivus/.agents/explorer_p46_path3/audit_path3.md`.
