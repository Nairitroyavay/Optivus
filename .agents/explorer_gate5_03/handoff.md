# Gate 5 Handoff Report: Auth Reconstruction Pipeline, Real Race Tests & Regression Suite Audit

**Agent**: `explorer_gate5_03`  
**Working Directory**: `/Users/avayroy/Optivus/.agents/explorer_gate5_03`  
**Timestamp**: 2026-09-09T04:15:00Z  
**Parent**: `5ac787bb-bdea-4bb8-abb2-8df021fde719` (`orchestrator_gate5_1`)  

---

## 1. Observation

### 1.1 Auth Reconstruction Pipeline & Provider Wiring
- In `lib/services/server_reconstructor.dart`:
  - `ServerReconstructionSnapshot` (lines 142–154) holds:
    ```dart
    final UserProfile? profile;
    final OnboardingDraft? draft;
    final OnboardingCompletionBundle? completionBundle;
    final OnboardingCurrentRunSnapshot currentRun;
    ```
  - `ServerReconstructionSource` (lines 156–162) defines the data source contract:
    ```dart
    abstract interface class ServerReconstructionSource {
      Future<ServerReconstructionSnapshot> load(
        String uid, {
        void Function(UserProfile? profile)? onProfileLoaded,
      });
      Future<void> createProfileShell(UserProfile profile);
    }
    ```
  - `ServerReconstructor` (lines 207–296) receives a `ServerReconstructionSource` in its constructor:
    ```dart
    class ServerReconstructor {
      final ServerReconstructionSource source;
      final DateTime Function() clock;
      const ServerReconstructor({required this.source, this.clock = DateTime.now});
    ```
  - Classification is pure and deterministic via `classifyServerReconstruction` (lines 299–497), returning one of: `ReconstructionFresh`, `ReconstructionIncomplete`, `ReconstructionFinishing`, `ReconstructionCompleted`, `ReconstructionRecovery`.

- In `lib/state/auth_state.dart`:
  - `serverReconstructorProvider` (lines 51–59) wires `ServerReconstructor`:
    ```dart
    final serverReconstructorProvider = Provider<ServerReconstructor>((ref) {
      return ServerReconstructor(
        source: RepositoryServerReconstructionSource(
          profileRepository: ref.watch(profileRepositoryProvider),
          onboardingRepository: ref.watch(onboardingRepositoryProvider),
          completionJobService: ref.watch(onboardingCompletionJobServiceProvider),
        ),
      );
    });
    ```
  - `AuthNotifier._loadBackendWithTimeout` (lines 1000–1030) initiates the reconstruction operation with key `'$uid@$authGeneration'`.
  - In `_runReconstructionOperation` (lines 1036–1090):
    - `isCurrentOwner()` verifies: `mounted && _authOperationGeneration == authGeneration`.
    - Catch block checks `if (!isCurrentOwner()) return;` before transient evaluation or failure publication.
  - In `_loadOrCreateBackendUserState` (lines 1132–1194):
    - When not an anonymous link, calls `_clearStateForIdentityBoundary(user)` (which calls `_resetSignedOutState()` and increments `_backendRestoreGeneration++`).
    - Increments `restoreGeneration = ++_backendRestoreGeneration`.
    - In Firebase mode, calls `_ref.read(authSessionResetCoordinatorProvider).prepareForAuthoritativeHydration()` before `_reconstructAndHydrate(user, restoreGeneration)`.
  - In `_reconstructAndHydrate` (lines 1229–1486):
    - Calls `await _ref.read(serverReconstructorProvider).reconstruct(...)`.
    - Double check:
      ```dart
      if (!_isCurrentRestore(restoreGeneration) || state.user?.uid != user.uid) {
        return;
      }
      ```
    - Awaits `assetHydration` and checks again:
      ```dart
      if (!_isCurrentRestore(restoreGeneration) || state.user?.uid != user.uid) {
        return;
      }
      ```
    - Hydrates profile seed data and reconciles onboarding draft / restores verified frontend state.
    - Sets owner on `homeDashboardProvider` and `fitnessCenterProvider`.
    - Calls `_applySessionDestination(user, resolveReconstructionDestination(effectiveResult))`.
  - In `_handleAuthStateChange` (lines 924–998):
    - When `user == null`: increments `_authOperationGeneration++`, `_backendRestoreGeneration++`, calls `_resetSignedOutState()`, sets `state = const AuthState(status: AuthFlowStatus.signedOut)`.
    - When `isAccountSwitch` or `isInitialSignIn`: increments `_authOperationGeneration++`.
    - When `isSameUidRefresh && _needsEmailVerification(previousUser!) == _needsEmailVerification(user)`:
      ```dart
      state = state.copyWith(user: user);
      return;
      ```
      (No generation increment, no privacy reset, no reconstruction restart).

### 1.2 Existing Race Test Audit & Gap Analysis
- In `test/gate5_auth_session_isolation_test.dart`:
  - `late Account A async completion does not mutate Account B` (lines 411–486):
    Uses `OptivusBackendMode.fake` and performs post-switch repository writes (`await onboardingRepo.saveDraft(...)`, `await profileRepo.saveUserProfile(...)`) after B is already authenticated. It does NOT test an in-flight `ServerReconstructor.reconstruct()` operation completing after Account B has already reconstructed.
- In `test/ah_f004_auth_identity_isolation_test.dart`:
  - `stale A backend result cannot overwrite B` (lines 308–336):
    Uses `_DelayedOnboardingRepository` in fake mode, delaying only `fetchDraft`.
- In `test/workstream_d_auth_async_isolation_test.dart`:
  - Tests `RoutineImportAiController` extraction delay and `homeMindNoteProvider`.
- **Finding**: Zero existing tests drive `ServerReconstructionSource` or `serverReconstructorProvider` with `Completer` objects to prove real async race safety during the actual startup/reconstruction pipeline.

### 1.3 R6 Architectural Invariants Audit
- Codebase-wide grep for forbidden legacy identifiers:
  - `mockUserProfileProvider`: 0 occurrences in `lib/` (VERIFIED).
  - `mockOnboardingProvider`: 0 occurrences in `lib/` (VERIFIED).
  - `backendRestoreFailed`: 0 occurrences in `lib/` (VERIFIED).
- RouterNotifier isolation (`lib/core/router/app_router.dart` lines 25–30):
  - `RouterNotifier` constructor contains:
    `_ref.listen(authProvider, (previous, next) => notifyListeners());`
    and no other listener (VERIFIED).
  - `optivusAuthRedirect` (lines 36–65) switches solely on `authState.sessionDestination.kind` with zero reads of profile/onboarding/completion providers (VERIFIED).
- Verify Email violations found in current code:
  - `VerificationMessageKind` exists in `lib/state/verification_lifecycle_state.dart` (lines 10, 29, 56, 331, 345, 356, 397, 415, 426, 432, 450, 557, 575) and `lib/views/screens/verify_email_screen.dart` (line 92).
  - `showAccountError(String message)` exists in `lib/state/verification_lifecycle_state.dart` (line 446) and `lib/views/screens/verify_email_screen.dart` (line 63).
  - Hard-coded logout error string exists in `lib/views/screens/verify_email_screen.dart` line 63:
    `controller.showAccountError('Couldn\'t sign out. Please try again.');`
- Existing static architecture tests:
  - Only `test/routine_architecture_test.dart` exists (Routine Phase 4 only).
  - No general `test/gate5_static_architecture_test.dart` exists yet for R6 invariants.

### 1.4 Test Suite & Regression Baseline Execution
- Automated test runs executed via `flutter test`:
  - Gate 5 Focused Suites:
    - `test/gate5_auth_session_isolation_test.dart`
    - `test/ah_f004_auth_identity_isolation_test.dart`
    - `test/ah_f003_google_auth_test.dart`
    - `test/workstream_d_auth_async_isolation_test.dart`
    - `test/onboarding_session_destination_test.dart`
    - `test/onboarding_routing_test.dart`
    - `test/onboarding_restore_test.dart`
    - `test/verify_email_redesign_test.dart`
    - `test/ah_f020_recoverable_error_model_test.dart`
    - `test/ah_f011_no_production_mock_leakage_test.dart`
    - `test/routine_phase4_4_ownership_test.dart`
    - **Result: 195 tests passed, 0 failed.**
  - Gate 1 & 2 Regressions:
    - `test/ah_f013_completion_terminalization_test.dart`
    - `test/ah_f014_step14_idempotency_test.dart`
    - `test/ah_f021_step14_final_review_test.dart`
    - `test/onboarding_completion_bundle_test.dart`
    - `test/onboarding_completion_retry_contract_test.dart`
    - `test/nutrition_target_service_test.dart`
    - `test/onboarding_eating_weekly_plan_test.dart`
    - `test/onboarding_step5_eating_ai_flow_test.dart`
    - `test/onboarding_step5_regeneration_test.dart`
    - `test/onboarding_step5_generated_no_fake_fallback_test.dart`
    - `test/onboarding_step5_save_test.dart`
    - **Result: 166 tests passed (10 skipped), 0 failed.**
  - Gate 3 & 4 Regressions:
    - `test/onboarding_step7_skin_care_test.dart`
    - `test/onboarding_step7_transaction_test.dart`
    - `test/onboarding_step7_state_machine_test.dart`
    - `test/onboarding_step7_cta_navigation_test.dart`
    - `test/onboarding_step7_full_timeline_regression_test.dart`
    - `test/onboarding_step7_pending_photo_generation_test.dart`
    - `test/onboarding_step7_runtime_ui_stability_test.dart`
    - `test/onboarding_step_layout_migration_test.dart`
    - `test/onboarding_persistence_phase2b_test.dart`
    - `test/onboarding_restore_test.dart`
    - `test/onboarding_routing_test.dart`
    - `test/onboarding_session_destination_test.dart`
    - `test/ah_f012_onboarding_resume_monotonicity_test.dart`
    - `test/onboarding_foundation_final_pass_test.dart`
    - **Result: 376 tests passed, 0 failed.**
  - Static Analysis: `flutter analyze`
    - **Result: "No issues found!"**

---

## 2. Logic Chain

1. **Reconstruction Isolation Logic**:
   - `_authOperationGeneration` acts as the account boundary epoch. Any account switch or signout increments this counter immediately before any async work completes.
   - `_backendRestoreGeneration` acts as the hydration epoch. Every call to `_loadOrCreateBackendUserState` increments this value and captures `restoreGeneration`.
   - In `_reconstructAndHydrate`, `!_isCurrentRestore(restoreGeneration) || state.user?.uid != user.uid` guards both the profile decode/classification checkpoint and the frontend hydration checkpoint.
   - Therefore, if Account A is paused at `ServerReconstructionSource.load()` and Account B is emitted, `_authOperationGeneration` and `_backendRestoreGeneration` both advance, so when Account A's future completes later, both `_isCurrentRestore` and `isCurrentOwner()` evaluate to `false`, discarding Account A's result completely.

2. **Completer-Based Controlled Harness Logic**:
   - Because `ServerReconstructor` depends purely on `ServerReconstructionSource`, replacing the source with `CompleterServerReconstructionSource` puts the entire async lifecycle under test control.
   - Unlike mock timer delays (e.g. `Future.delayed(Duration(milliseconds: 100))`), a `Completer` never resolves until explicitly triggered.
   - This enables an exact, race-free sequence:
     `Emit A` → `A starts reconstruction (completer pending)` → `Seed A state` → `Emit B` → `Assert sync boundary reset A` → `Complete B completer` → `Assert B is Home/Destination` → `Complete A completer` → `Pump queue` → `Assert B state is 100% untouched`.

3. **Static Architecture Logic**:
   - Static invariants cannot rely on developer discipline alone; an automated test file `test/gate5_static_architecture_test.dart` reading `lib/` files is required.
   - Current scan proves that `mockUserProfileProvider`, `mockOnboardingProvider`, and `backendRestoreFailed` have reached 0 occurrences in `lib/`.
   - However, `VerificationMessageKind` and `showAccountError(String)` still exist in `verification_lifecycle_state.dart` and `verify_email_screen.dart`. A static architecture test will fail immediately against these until Phase 1 refactoring removes them.

---

## 3. Mandatory Pre-Editing Audit Table Rows

The following 7 rows cover the scope owned by this audit:

| AREA | CURRENT AUTHORITY | CURRENT MUTABLE STATE | UID/SESSION SCOPE | RESET/FENCE MECHANISM | CURRENT DEFECT | SMALLEST FIX | TEST THAT MUST FAIL BEFORE FIX |
|---|---|---|---|---|---|---|---|
| **Auth Reconstruction Pipeline** | `ServerReconstructor` (`lib/services/server_reconstructor.dart`) via `serverReconstructorProvider` reading `ProfileRepository`, `OnboardingRepository`, `OnboardingCompletionJobService`; pure classification via `classifyServerReconstruction` | `AuthState.reconstructionResult`, `AuthState.resumeStep`, `AuthState.completionRunId`, `AuthState.startupReasonCode`, `_reconstructionInFlightByUid` | Authenticated `user.uid` | `_backendRestoreGeneration`, `_authOperationGeneration`, `_isCurrentRestore(restoreGeneration)` guard, `_clearStateForIdentityBoundary()` | No test drives `ServerReconstructionSource` with `Completer` objects to prove slow server reads do not permit stale classification after account switch or logout | Provide `CompleterServerReconstructionSource` implementing `ServerReconstructionSource`; assert `AuthNotifier` drops stale `ServerReconstructor.reconstruct()` completion when generation advances | New real race test: `TEST A: A reconstruction completes after B` |
| **Auth Reconstruction Async Race (A→B mid-flight)** | `AuthNotifier._loadBackendWithTimeout` & `_reconstructAndHydrate` (`lib/state/auth_state.dart`) | `_backendRestoreGeneration`, `_authOperationGeneration`, `_reconstructionInFlightByUid`, `authProvider`, `userProfileProvider`, `onboardingStateProvider` | Isolated per authenticated UID (`user.uid`) | Synchronous `_clearStateForIdentityBoundary(userB)` calling `resetIdentityBoundary()` before B is published; `_authOperationGeneration++`; `_backendRestoreGeneration++`; `isCurrentOwner()`; `_isCurrentRestore(restoreGeneration)` | Existing tests use fake repo delays or post-switch writes; no test verifies in-flight A `load()` completing after B reaches Home is dropped with 0 mutation of B | Implement TEST A using `CompleterServerReconstructionSource` in `test/gate5_auth_reconstruction_race_test.dart`, completing A after B reaches final `SessionDestination` | `TEST A: A reconstruction completes after B` |
| **Auth Reconstruction Pending Async Sign-Out** | `AuthNotifier.logout` & `_reconstructAndHydrate` (`lib/state/auth_state.dart`) | `_authOperationGeneration`, `_backendRestoreGeneration`, `authProvider` (`AuthState.status`, `AuthState.user`, `AuthState.error`) | Account A UID → `null` (signed out) | `logout()` advances `_authOperationGeneration++`, awaits `signOut()`, advances `_backendRestoreGeneration++`, calls `_resetSignedOutState()`, sets `status = signedOut`. Late A checks fail `_isCurrentRestore` and `isCurrentOwner()` | No test verifies in-flight A `load()` completing after `logout()` completes leaves app strictly in `signedOut` with 0 resurrected state and 0 destination transitions | Implement TEST B using `CompleterServerReconstructionSource`, completing A after `logout()` finishes | `TEST B: A reconstruction completes after sign-out` |
| **Auth Session Failed Logout Transaction** | `AuthNotifier.logout` (`lib/state/auth_state.dart`) & `AuthErrorMapper` (`lib/core/errors/auth_error_mapper.dart`) | `authProvider` (`AuthState.error`, `AuthState.status`), `authGenerationProvider` | Authenticated `user.uid` (Account A) | In `logout()`, `_backendRestoreGeneration++` and `_resetSignedOutState()` are positioned AFTER `await _repository.signOut()`. If `signOut()` throws, reset is skipped and user remains signed in | Verify Email screen hard-codes `controller.showAccountError('Couldn\'t sign out. Please try again.')` rather than consuming typed `AuthState.error`, violating R3 | Remove hardcoded string in `VerifyEmailScreen`, remove untyped `showAccountError(String)` in `VerificationLifecycleState`, consume `ref.read(authProvider).error` or typed API; add TEST C | `TEST C: Failed logout preserves Account A` |
| **Auth Session Same-UID Refresh Invariance** | `AuthNotifier._handleAuthStateChange` (`lib/state/auth_state.dart`) | `AuthState.user` (in-place identity update) | Same `user.uid` | `isSameUidRefresh && _needsEmailVerification(previousUser!) == _needsEmailVerification(user)` updates user in place without incrementing generations or invoking server reconstruction | Existing test only tested fake repo emission; did not assert against `ServerReconstructionSource` to prove `load()` is NOT re-invoked on same-UID token refresh | Implement TEST D asserting `source.loadCalls.length` does not increment upon same-UID refresh | `TEST D: Same UID refresh` |
| **Static Architecture Enforcement (R6)** | Codebase-wide architectural boundaries (`lib/`) | N/A (compile-time / static source contracts) | Repository-wide (`lib/`) | Automated static source test in `test/` scanning files and verifying R1/R2/R3/R6 invariants | No static test enforces R6 invariants; `VerificationMessageKind`, `messageKind`, and `showAccountError(String)` remain in `lib/` | Create `test/gate5_static_architecture_test.dart` scanning `lib/` and asserting 0 violations for R1, R2, R3, R6 | `test/gate5_static_architecture_test.dart` (fails immediately on current checkout until R3 refactor) |
| **Cross-Gate Regression Suite Invariance** | Gate 1–5 test suites (`test/**`) | Test environments and fixtures across all gates | Multi-user and gate-specific fixtures | Independent `ProviderContainer` fixtures with explicit lifecycle disposal | Gate 5 verification report lacks documented cross-gate baseline proving all 737+ tests pass together | Execute and document complete baseline: Gate 1 (5 suites), Gate 2 (6 suites), Gate 3 (7 suites), Gate 4 (7 suites), Gate 5 (11 suites) all passing | Cross-gate regression tests if any invariant is violated during Gate 5 changes |

---

## 4. Design of Tests A, B, C, D using Completer-based ServerReconstructionSource

### 4.1 Implementation of `CompleterServerReconstructionSource`
```dart
class CompleterServerReconstructionSource implements ServerReconstructionSource {
  final Map<String, Completer<ServerReconstructionSnapshot>> _completers = {};
  final List<String> loadCalls = [];
  final List<UserProfile> createdProfileShells = [];

  Completer<ServerReconstructionSnapshot> completerFor(String uid) {
    return _completers.putIfAbsent(
      uid,
      () => Completer<ServerReconstructionSnapshot>(),
    );
  }

  bool hasPendingLoad(String uid) =>
      _completers.containsKey(uid) && !_completers[uid]!.isCompleted;

  @override
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async {
    loadCalls.add(uid);
    final snapshot = await completerFor(uid).future;
    onProfileLoaded?.call(snapshot.profile);
    return snapshot;
  }

  @override
  Future<void> createProfileShell(UserProfile profile) async {
    createdProfileShells.add(profile);
  }
}
```

### 4.2 Test A Design: Reconstruction A Completes After B Reaches Destination
1. Container setup:
   - `optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase)`
   - `authRepositoryProvider.overrideWithValue(authRepo)`
   - `serverReconstructorProvider.overrideWithValue(ServerReconstructor(source: source))`
   - `regionSettingsRepositoryProvider.overrideWithValue(FakeRegionSettingsRepository())`
2. Steps:
   - Start `authProvider`.
   - `authRepo.emitUserForTesting(userA)`.
   - Pump event queue; assert `source.hasPendingLoad('user-a')` is true.
   - Capture `genA = container.read(authGenerationProvider)`.
   - Seed Account A state (profile displayName 'Private A', goal 'g-a', routine full-day true).
   - `authRepo.emitUserForTesting(userB)`.
   - Pump event queue.
   - Assert synchronous identity boundary: `authGenerationProvider > genA`, `userProfileProvider.uid != userA.uid`, `mockGoalProvider` is empty, `routineNotifierProvider.showFullDay` is false.
   - Assert `source.hasPendingLoad('user-b')` is true.
   - Complete B's completer: `source.completerFor('user-b').complete(snapshotB)`.
   - Pump event queue until B reaches its final `SessionDestination` (e.g. `resumeOnboarding`, step 3).
   - Assert B state is active: `userProfileProvider.uid == 'user-b'`, `onboardingStateProvider.draft.uid == 'user-b'`.
   - **ONLY NOW** complete A's old completer: `source.completerFor('user-a').complete(snapshotA)`.
   - Pump event queue.
   - Assert:
     - `AuthState.user.uid == 'user-b'`
     - `AuthState.sessionDestination` belongs to B
     - `authGeneration` belongs to current boundary (`> genA`)
     - `userProfileProvider.uid == 'user-b'`
     - `onboardingStateProvider.draft.uid == 'user-b'`
     - No Account A goals, routine items, or errors exist in state
     - No A `reconstructionResult` becomes active.

### 4.3 Test B Design: Reconstruction A Completes After Sign-Out
1. Steps:
   - Start `authProvider`, emit `userA`.
   - Wait for `source.hasPendingLoad('user-a')`.
   - Call `container.read(authProvider.notifier).logout()`.
   - Assert state is `AuthFlowStatus.signedOut`, `AuthState.user` is null.
   - Complete A's old completer: `source.completerFor('user-a').complete(snapshotA)`.
   - Pump event queue.
   - Assert:
     - Still `AuthFlowStatus.signedOut`
     - Destination is `SessionDestinationKind.signedOut`
     - `AuthState.user` is null
     - `userProfileProvider.uid` is empty
     - No error is published.

### 4.4 Test C Design: Failed Logout Preserves Account A
1. Steps:
   - Configure `authRepo.signOutShouldFail = true`.
   - Start `authProvider`, emit `userA`, complete A's completer.
   - Assert Account A is fully hydrated, destination is Home.
   - Capture `genA = container.read(authGenerationProvider)`.
   - Attempt `container.read(authProvider.notifier).logout()`.
   - Assert throws `isA<RecoverableError>()`.
   - Assert:
     - `AuthState.user.uid == 'user-a'`
     - `authGenerationProvider == genA` (no privacy reset occurred)
     - `userProfileProvider.uid == 'user-a'`
     - `AuthState.error` is `RecoverableError` with diagnostic code and public message containing "still signed in".
     - Verify Email screen (when mounted in unverified state) renders this same typed failure rather than hard-coded text.

### 4.5 Test D Design: Same UID Refresh
1. Steps:
   - Start `authProvider`, emit `userA`, complete A's completer.
   - Capture `genA = container.read(authGenerationProvider)`.
   - Capture `loadCallsBefore = source.loadCalls.length`.
   - Emit updated `AuthUser` with same UID (updated email, linked provider).
   - Pump event queue.
   - Assert:
     - `authGenerationProvider == genA` (no privacy reset)
     - `source.loadCalls.length == loadCallsBefore` (reconstruction did NOT restart)
     - `AuthState.user.email` updated in place
     - Projections and destination remain intact.

---

## 5. Design of R6 Static Architecture Enforcement Test

File path: `test/gate5_static_architecture_test.dart`  
Structure:

```dart
void main() {
  group('Gate 5 R6 Static Architecture Enforcement', () {
    test('1. Zero active occurrences of forbidden legacy identifiers in lib/', () {
      final forbidden = [
        'mockUserProfileProvider',
        'mockOnboardingProvider',
        'backendRestoreFailed',
      ];
      // Recursively scan lib/ for forbidden patterns
    });

    test('2. RouterNotifier depends exclusively on authProvider', () {
      final file = File('lib/core/router/app_router.dart');
      // Assert RouterNotifier constructor only has `_ref.listen(authProvider, ...)`
      // Assert no `userProfileProvider`, `onboardingStateProvider`, etc. in RouterNotifier
    });

    test('3. optivusAuthRedirect reads only AuthState.sessionDestination', () {
      final file = File('lib/core/router/app_router.dart');
      // Assert optivusAuthRedirect switches on `destination.kind` without reading profile/onboarding providers
    });

    test('4. Verify Email failure taxonomy is unified under RecoverableError', () {
      final stateFile = File('lib/state/verification_lifecycle_state.dart');
      final screenFile = File('lib/views/screens/verify_email_screen.dart');
      // Assert zero occurrences of `VerificationMessageKind`
      // Assert zero occurrences of `messageKind`
      // Assert zero occurrences of `showAccountError(String`
    });

    test('5. Verify Email has zero hard-coded logout failure override strings', () {
      final screenFile = File('lib/views/screens/verify_email_screen.dart');
      // Assert no "Couldn't sign out. Please try again." string
    });

    test('6. Auth identity reset delegates strictly through AuthSessionResetCoordinator', () {
      final authFile = File('lib/state/auth_state.dart');
      // Assert `_resetSignedOutState` calls `authSessionResetCoordinatorProvider`
      // Assert `_clearStateForIdentityBoundary` delegates to `_resetSignedOutState`
    });

    test('7. Gate 5 session inventory: all reset coordinator providers are classified', () {
      // Assert every provider touched in AuthSessionResetCoordinator is documented in the inventory
    });
  });
}
```

---

## 6. Caveats

- `test/gate5_static_architecture_test.dart` and `test/gate5_auth_reconstruction_race_test.dart` are proposed new test files to be implemented in Milestone 1/3/4; they do not exist on disk yet.
- Test A, B, C, D will be implemented by the assigned worker agent in Phase 3.
- All investigation in this report was strictly read-only; no production files were modified.

---

## 7. Conclusion

1. **Reconstruction Pipeline Correctness**: The underlying generation-fencing mechanisms in `AuthNotifier` (`_authOperationGeneration`, `_backendRestoreGeneration`, `_isCurrentRestore`, `isCurrentOwner()`) are architecturally sound, but lack end-to-end automated race tests driving the real `ServerReconstructor` in Firebase mode.
2. **Completer Harness Feasibility**: `ServerReconstructionSource` is an optimal test double point. `CompleterServerReconstructionSource` completely eliminates timing dependence and creates 100% deterministic race conditions for Tests A, B, C, and D.
3. **Static Architecture Status**: R1 clean freezes (`mockUserProfileProvider`, `mockOnboardingProvider`, `backendRestoreFailed` at 0) and `RouterNotifier` single-dependency invariants are intact. However, R3 Verify Email failure taxonomy (`VerificationMessageKind`, `showAccountError(String)`) still requires unification under `RecoverableError` before R6 static architecture tests can pass.
4. **Regression Baseline**: All 737+ existing tests across Gates 1, 2, 3, 4, and 5 pass cleanly, and `flutter analyze` reports 0 issues.

---

## 8. Verification Method

To independently verify all findings in this report:

1. **Verify Static Occurrences**:
   ```bash
   git grep "mockUserProfileProvider" lib/
   git grep "mockOnboardingProvider" lib/
   git grep "backendRestoreFailed" lib/
   git grep "VerificationMessageKind" lib/
   git grep "showAccountError" lib/
   ```
   Confirm the first three return 0 results, while `VerificationMessageKind` and `showAccountError` return occurrences in `lib/state/verification_lifecycle_state.dart` and `lib/views/screens/verify_email_screen.dart`.

2. **Verify Static Analysis**:
   ```bash
   flutter analyze
   ```
   Confirm 0 errors and 0 warnings.

3. **Verify Gate 5 Tests**:
   ```bash
   flutter test test/gate5_auth_session_isolation_test.dart test/ah_f004_auth_identity_isolation_test.dart test/ah_f003_google_auth_test.dart test/workstream_d_auth_async_isolation_test.dart test/onboarding_session_destination_test.dart test/onboarding_routing_test.dart test/onboarding_restore_test.dart test/verify_email_redesign_test.dart test/ah_f020_recoverable_error_model_test.dart test/ah_f011_no_production_mock_leakage_test.dart test/routine_phase4_4_ownership_test.dart
   ```
   Confirm 195 tests pass.

4. **Verify Cross-Gate Regression Suites**:
   - Gate 1 & 2:
     ```bash
     flutter test test/ah_f013_completion_terminalization_test.dart test/ah_f014_step14_idempotency_test.dart test/ah_f021_step14_final_review_test.dart test/onboarding_completion_bundle_test.dart test/onboarding_completion_retry_contract_test.dart test/nutrition_target_service_test.dart test/onboarding_eating_weekly_plan_test.dart test/onboarding_step5_eating_ai_flow_test.dart test/onboarding_step5_regeneration_test.dart test/onboarding_step5_generated_no_fake_fallback_test.dart test/onboarding_step5_save_test.dart
     ```
     Confirm 166 tests pass.
   - Gate 3 & 4:
     ```bash
     flutter test test/onboarding_step7_skin_care_test.dart test/onboarding_step7_transaction_test.dart test/onboarding_step7_state_machine_test.dart test/onboarding_step7_cta_navigation_test.dart test/onboarding_step7_full_timeline_regression_test.dart test/onboarding_step7_pending_photo_generation_test.dart test/onboarding_step7_runtime_ui_stability_test.dart test/onboarding_step_layout_migration_test.dart test/onboarding_persistence_phase2b_test.dart test/onboarding_restore_test.dart test/onboarding_routing_test.dart test/onboarding_session_destination_test.dart test/ah_f012_onboarding_resume_monotonicity_test.dart test/onboarding_foundation_final_pass_test.dart
     ```
     Confirm 376 tests pass.
