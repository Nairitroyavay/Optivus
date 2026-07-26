# Handoff Report — Group D: Authentication & Account Lifecycle (Issues 16–21)

**Agent**: `explorer_group_d_1`  
**Working Directory**: `/Users/roy/optivus2/Optivus/.agents/explorer_group_d_1`  
**Target Scope**: Group D (Issues 16, 17, 18, 19, 20, 21)  
**Date**: 2026-07-25  

---

## Executive Summary

This investigation analyzed Group D (Issues 16–21: Authentication & account lifecycle) in the Optivus Onboarding Stabilization initiative. All six root causes have been traced to exact files and line numbers across the codebase (`lib/state/auth_state.dart`, `lib/core/router/app_router.dart`, `lib/repositories/auth_repository.dart`, `lib/core/utils/auth_error_mapper.dart`, `lib/features/onboarding/onboarding_flow.dart`, `lib/views/screens/verify_email_screen.dart`, `lib/features/profile/providers/profile_settings_provider.dart`, `lib/features/routine/controllers/habit_systems_controller.dart`, `lib/features/routine/routine_state.dart`, `lib/features/home/providers/home_dashboard_provider.dart`, `lib/features/home/providers/home_mind_note_provider.dart`, `lib/features/tracker/fitness/providers/fitness_provider.dart`, `lib/features/tracker/providers/tracker_settings_provider.dart`, `lib/state/routine_import_ai_state.dart`, `lib/state/upload_state.dart`, `lib/app/app_navigation_controller.dart`).

Concrete architectural fixes conforming strictly to requirements R1–R11 (zero data corruption, typed auth errors, seamless router integration, account data isolation, zero data deletion, email verification enforcement, and anonymous account linking preservation) have been formulated alongside targeted test plans.

---

## 1. Observation

### Key Codebase Files Inspected
1. `lib/state/auth_state.dart`
2. `lib/core/router/app_router.dart`
3. `lib/repositories/auth_repository.dart`
4. `lib/core/utils/auth_error_mapper.dart`
5. `lib/features/onboarding/onboarding_flow.dart`
6. `lib/views/screens/verify_email_screen.dart`
7. `lib/views/screens/login_screen.dart`
8. `lib/views/screens/signup_screen.dart`
9. `lib/features/profile/providers/profile_settings_provider.dart`
10. `lib/features/routine/controllers/habit_systems_controller.dart`
11. `lib/features/routine/routine_state.dart`
12. `lib/features/home/providers/home_dashboard_provider.dart`
13. `lib/features/home/providers/home_mind_note_provider.dart`
14. `lib/features/tracker/fitness/providers/fitness_provider.dart`
15. `lib/features/tracker/providers/tracker_settings_provider.dart`
16. `lib/state/routine_import_ai_state.dart`
17. `lib/state/upload_state.dart`
18. `lib/app/app_navigation_controller.dart`
19. `test/onboarding_routing_test.dart`
20. `test/onboarding_restore_test.dart`

---

### Verbatim Code Observations by Issue

#### Issue 16: Auth state stream synchronization across Riverpod and GoRouter
- **`lib/state/auth_state.dart` (lines 126–133)**:
  ```dart
  _authSubscription = _repository.authStateChanges.listen(
    _handleAuthStateChange,
  );
  final currentUser = _repository.currentUser;
  if (currentUser != null) {
    scheduleMicrotask(() => _handleAuthStateChange(currentUser));
  }
  ```
- **`lib/core/router/app_router.dart` (lines 23–30)**:
  ```dart
  class RouterNotifier extends ChangeNotifier {
    final Ref _ref;

    RouterNotifier(this._ref) {
      _ref.listen(authProvider, (previous, next) => notifyListeners());
      _ref.listen(mockUserProfileProvider, (previous, next) => notifyListeners());
    }
  }
  ```
- **`lib/core/router/app_router.dart` (lines 78–138)**:
  ```dart
  redirect: (context, state) {
    final authState = ref.read(authProvider);
    ...
    final userProfile = ref.read(mockUserProfileProvider);
    final onboardingInputCompleted = userProfile.onboardingInputCompleted;
    final onboardingCompleted = userProfile.onboardingCompleted;
  ```
- **Observation**:
  1. In `AuthNotifier` constructor, subscribing to `_repository.authStateChanges` (which immediately emits current user in `FirebaseAuthRepository`) AND scheduling microtask for `currentUser` causes `_handleAuthStateChange` to execute TWICE concurrently on startup. The second invocation increments `_backendRestoreGeneration` (line 415), invalidating the first restore execution in progress (`_isCurrentRestore` check bails out), leaving `AuthNotifier` state desynchronized or stuck in `loadingBackendUser`.
  2. `RouterNotifier` listens to both `authProvider` and `mockUserProfileProvider`. During state updates, `authState` and `userProfile` updates can be out-of-sync by one frame or microtask tick, leading GoRouter's `redirect` function to evaluate desynchronized state and trigger transient redirect loops or route flashes (e.g. between `/loading`, `/onboarding`, and `/app`).
  3. During `logout()`, `AuthNotifier` awaits `_repository.signOut()`, then manually resets state. Simultaneously, `_repository.signOut()` causes `authStateChanges` stream to emit `null`, executing `_handleAuthStateChange(null)` which resets state a second time. This triggers `GoRouter` listeners twice in rapid succession during sign-out transition.

---

#### Issue 17: User sign-out state invalidation for all cached feature controllers
- **`lib/state/auth_state.dart` (lines 766–776 & 801–814)**:
  ```dart
  void _resetSignedOutState() {
    _ref.read(routineNotifierProvider.notifier).resetForSignedOut();
    _ref.read(habitSystemsNotifierProvider.notifier).resetForSignedOut();
    _ref.read(mockUserProfileProvider.notifier).resetEmpty();
    _ref.read(mockOnboardingProvider.notifier).reset('');
    _ref.read(profileSettingsProvider.notifier).resetForSignedOut();
    _ref.read(regionSettingsProvider.notifier).loadSettings(RegionSettings.defaultForUser('signed-out'));
    _resetUserScopedMockState();
  }

  void _resetUserScopedMockState() {
    _ref.read(routineNotifierProvider.notifier).resetForSignedOut();
    if (!_useFirebaseBackend) {
      _ref.read(mockRoutineProvider.notifier).resetEmpty();
    }
    _ref.read(mockTrackerProvider.notifier).resetEmpty();
    _ref.read(mockGoalProvider.notifier).resetEmpty();
    _ref.read(mockMindNoteProvider.notifier).resetEmpty();
    _ref.read(mockCoachProvider.notifier).resetEmpty();
    _ref.read(mockCoachPreferencesProvider.notifier).resetEmpty();
    _ref.read(mockNotificationPreferencesProvider.notifier).resetEmpty();
    _ref.read(mockPermissionProvider.notifier).resetEmpty();
  }
  ```
- **Observation**:
  1. `_resetSignedOutState()` only invalidates `routineNotifierProvider`, `habitSystemsNotifierProvider`, `mockUserProfileProvider`, `mockOnboardingProvider`, `profileSettingsProvider`, and mock app state providers.
  2. Omits feature controllers: `HomeDashboardNotifier` (`homeDashboardProvider`), `HomeMindNoteNotifier` (`homeMindNoteProvider`), `FitnessCenterNotifier` (`fitnessCenterProvider`), `TrackerSettingsNotifier` (`trackerSettingsProvider`), `RoutineImportAiController` (`routineImportAiControllerProvider`), `UploadController` (`uploadControllerProvider`), `AppNavigationController` (`appNavigationProvider`), and navigation detail request StateProviders (`homeDetailViewRequestProvider`, `trackerDetailViewRequestProvider`, `profileDetailViewRequestProvider`, `routineDetailViewRequestProvider`, `coachDetailViewRequestProvider`, `goalsDetailViewRequestProvider`).
  3. Consequently, cached dashboard metrics, fitness logs, AI import results, uploaded asset pointers, and screen navigation targets from the previous signed-in user linger in memory across sign-out boundaries.

---

#### Issue 18: Account switching data leak prevention across user scopes
- **`lib/state/auth_state.dart` (lines 396–431)**:
  ```dart
  Future<void> _loadOrCreateBackendUserState(AuthUser user) async {
    ...
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.loadingBackendUser,
      clearError: true,
    );
    _ref.read(routineNotifierProvider.notifier).resetForSignedOut();
    _ref.read(habitSystemsNotifierProvider.notifier).resetForSignedOut();
  ```
- **`lib/features/profile/providers/profile_settings_provider.dart` (lines 156–175)**:
  ```dart
  String get _currentUid => _ref.read(mockUserProfileProvider).uid;

  Future<void> updateProfile(UserProfileSettings profile) async {
    state = state.copyWith(profile: profile);
    final uid = _currentUid;
    if (uid.isEmpty) return;
    await _profileRepository.saveProfileSettings(uid, profile);
  }
  ```
- **Observation**:
  1. When switching accounts (User A -> User B), `_loadOrCreateBackendUserState` begins loading User B's state asynchronously. However, before fetching User B's remote profile, settings, region, and preferences, `_loadOrCreateBackendUserState` only resets `routineNotifierProvider` and `habitSystemsNotifierProvider`. It does NOT execute an immediate, atomic reset of `mockUserProfileProvider`, `profileSettingsProvider`, `homeDashboardProvider`, `fitnessCenterProvider`, or `uploadControllerProvider`.
  2. During the multi-step async network latency window of loading User B's state, UI components rendering Riverpod providers display User A's private data under User B's session.
  3. Lack of strict UID validation on incoming mutations in `ProfileSettingsNotifier`, `HomeDashboardNotifier`, `FitnessCenterNotifier`, and `UploadController` means pending asynchronous mutations can execute against User B's UID using User A's payload or vice versa.

---

#### Issue 19: Typed auth failure mapping for network interruptions and invalid tokens
- **`lib/core/utils/auth_error_mapper.dart` (lines 6–21 & 34–45)**:
  ```dart
  String friendlyAuthError(Object error) {
    if (error is firebase_auth.FirebaseAuthException) {
      return _messageForCode(error.code);
    }
    final raw = error.toString();
    for (final code in _codeMessages.keys) {
      if (raw.contains(code)) return _messageForCode(code);
    }
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    return 'Something went wrong. Please try again.';
  }
  ```
- **`lib/state/auth_state.dart` (lines 50–63 & 158–164)**:
  ```dart
  class AuthState {
    final AuthUser? user;
    final AuthFlowStatus status;
    final String? errorMessage;
    final OnboardingFailureReason? failureReason;
    final List<OnboardingRecoveryAction> recoveryActions;
  ```
- **Observation**:
  1. `friendlyAuthError` returns generic strings (`'Something went wrong. Please try again.'`) and lacks typed exception taxonomy.
  2. `AuthRepository` implementations (`FirebaseAuthRepository` and `FakeAuthRepository`) throw raw `FirebaseAuthException` or generic `Exception` objects without wrapping them into strongly typed Optivus domain exceptions.
  3. `AuthState` contains only unstructured `errorMessage: String?` and onboarding-specific `failureReason: OnboardingFailureReason?`. It lacks strongly typed authentication failure classifications (`AuthFailureReason`), preventing UI screens from distinguishing network interruptions (retryable with backoff) from invalid tokens/credentials (requires re-authentication / sign-out) or rate limits.

---

#### Issue 20: Email verification step enforcement before post-onboarding navigation
- **`lib/state/auth_state.dart` (lines 304–328)**:
  ```dart
  Future<void> markOnboardingComplete(AuthUser user) async {
    ...
    if (_useFirebaseBackend && !_needsEmailVerification(user)) {
      await _ref.read(profileRepositoryProvider).saveUserProfile(profile);
    }
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.signedInOnboardingComplete,
      clearError: true,
    );
  }
  ```
- **`lib/features/onboarding/onboarding_flow.dart` (lines 290–298)**:
  ```dart
  final uid = _currentPersistenceUid();
  if (uid == null) {
    ref.read(mockOnboardingProvider.notifier).setValidationMessage(
      'Please verify your email before finishing onboarding.',
    );
    return;
  }
  ```
- **Observation**:
  1. In `AuthNotifier.markOnboardingComplete(AuthUser user)`, `markOnboardingComplete` does NOT check `_needsEmailVerification(user)` BEFORE updating `status: AuthFlowStatus.signedInOnboardingComplete`. If called with an unverified email/password user, it updates `status` to `signedInOnboardingComplete`, bypassing `emailUnverified` status checks.
  2. In `OnboardingFlow._completeOnboarding()`, `_currentPersistenceUid()` checks if user is signed in, but does not verify whether `user.emailVerified` is true. If an unverified user completes step 11, `_completeOnboarding` executes completion hydration and navigates to `/app?tab=0`.
  3. In `app_router.dart`, `redirect` checks `authState.emailUnverified`. However, once `status` is set to `signedInOnboardingComplete`, `authState.emailUnverified` evaluates to `false`, allowing unverified users to enter `/app?tab=0` and persist `onboardingCompleted: true` in Firestore documents.

---

#### Issue 21: Anonymous-to-authenticated account link state preservation
- **`lib/repositories/auth_repository.dart` (lines 25–43)**:
  ```dart
  abstract class AuthRepository {
    Stream<AuthUser?> get authStateChanges;
    AuthUser? get currentUser;
    Future<AuthUser> signIn(String email, String password);
    Future<AuthUser> signUp(String email, String password, {String? name});
    Future<void> sendEmailVerification();
    Future<AuthUser?> reloadCurrentUser();
    Future<String?> currentIdToken();
    Future<void> sendPasswordResetEmail(String email);
    Future<void> signOut();
  }
  ```
- **Observation**:
  1. `AuthRepository` interface lacks contracts for `signInAnonymously()` and `linkAnonymousWithEmail(String email, String password, {String? name})`.
  2. When an anonymous user builds an onboarding draft, routine items, habit systems, and profile settings under `oldAnonUid`, and subsequently signs up or links their account to permanent email/password credentials, current code creates a new user `newUid` (or detects UID change) and re-initializes `_loadOrCreateBackendUserState` with blank state for `newUid`.
  3. The anonymous data (draft, routine items, habit systems, goals, preferences) remains orphaned under `oldAnonUid` and is lost for the newly authenticated account, violating requirement R11 (zero data deletion and seamless user migration).

---

## 2. Logic Chain

### Issue 16: Auth state stream synchronization across Riverpod and GoRouter
1. **Observation**: `AuthNotifier` constructor subscribes to `_repository.authStateChanges` and schedules a microtask to invoke `_handleAuthStateChange(currentUser)`. `FirebaseAuthRepository` emits `currentUser` immediately upon subscription to `authStateChanges()`.
2. **Logic Step 1**: When `AuthNotifier` is initialized, `_handleAuthStateChange` is called twice in rapid succession.
3. **Logic Step 2**: The second execution increments `_backendRestoreGeneration`, invalidating the first restoration in progress.
4. **Logic Step 3**: GoRouter's `RouterNotifier` listens to both `authProvider` and `mockUserProfileProvider`. When state updates occur asynchronously, GoRouter evaluates inconsistent states between `authState` and `userProfile`, triggering transient redirect loops or route flashes.
5. **Conclusion**: Removing duplicate microtask invocation and making `authState.status` the canonical single source of truth in GoRouter ensures synchronous, deterministic stream synchronization.

### Issue 17: User sign-out state invalidation for all cached feature controllers
1. **Observation**: `AuthNotifier._resetSignedOutState()` calls `resetForSignedOut()` on routine, habit systems, and profile settings notifiers, but omits `HomeDashboardNotifier`, `HomeMindNoteNotifier`, `FitnessCenterNotifier`, `TrackerSettingsNotifier`, `RoutineImportAiController`, `UploadController`, `AppNavigationController`, and navigation detail request providers.
2. **Logic Step 1**: When a user signs out, omitted controllers maintain state in memory.
3. **Logic Step 2**: A subsequent signed-in user or unauthenticated view can inspect or render residual state from the previous user.
4. **Conclusion**: Adding explicit `resetForSignedOut()` methods to all feature controllers and updating `AuthNotifier._resetSignedOutState()` guarantees complete memory wiping upon sign-out.

### Issue 18: Account switching data leak prevention across user scopes
1. **Observation**: `_loadOrCreateBackendUserState` begins loading User B's state asynchronously, but only resets routine and habit system notifiers initially. User A's profile settings, home dashboard, fitness data, and upload state remain active until remote fetches complete.
2. **Logic Step 1**: During the network latency window of loading User B's state, UI components rendering Riverpod providers display User A's private data under User B's session.
3. **Logic Step 2**: Pending async mutations in feature notifiers lacking `_ownerUid` guards can overwrite User B's state with User A's payload.
4. **Conclusion**: Immediate atomic reset (`_resetSignedOutState()`) at the start of `_loadOrCreateBackendUserState` combined with strict `_ownerUid` matching guards across all feature controllers eliminates cross-user data leaks.

### Issue 19: Typed auth failure mapping for network interruptions and invalid tokens
1. **Observation**: `friendlyAuthError` returns generic strings, `AuthRepository` throws raw `FirebaseAuthException` objects, and `AuthState` stores only unstructured `errorMessage: String?`.
2. **Logic Step 1**: Without typed error taxonomy (`AuthFailureReason`), the UI cannot distinguish network interruptions (retryable with backoff) from invalid tokens/credentials (requires re-auth) or rate limits.
3. **Logic Step 2**: App errors present generic messages without offering actionable user recovery pathways.
4. **Conclusion**: Introducing `AuthFailureReason` enum and `AuthFailureException` class enables strongly typed error handling and programmatic UI recovery options.

### Issue 20: Email verification step enforcement before post-onboarding navigation
1. **Observation**: `AuthNotifier.markOnboardingComplete(AuthUser user)` updates `status: AuthFlowStatus.signedInOnboardingComplete` without checking `_needsEmailVerification(user)`. `OnboardingFlow._completeOnboarding()` does not check email verification status before executing hydration and navigating to `/app?tab=0`.
2. **Logic Step 1**: An unverified password user completing step 11 transitions `AuthState` status to `signedInOnboardingComplete`.
3. **Logic Step 2**: Once status is `signedInOnboardingComplete`, GoRouter's `redirect` evaluates `authState.emailUnverified` as `false`, allowing unverified users to enter `/app?tab=0` and persist `onboardingCompleted: true` in Firestore.
4. **Conclusion**: Validating `!_needsEmailVerification(user)` in `markOnboardingComplete`, `_completeOnboarding()`, and `app_router.dart` strictly enforces email verification before post-onboarding navigation.

### Issue 21: Anonymous-to-authenticated account link state preservation
1. **Observation**: `AuthRepository` lacks contracts for `signInAnonymously()` and `linkAnonymousWithEmail()`. When an anonymous user links or signs up, `_loadOrCreateBackendUserState` treats the new UID as a blank user.
2. **Logic Step 1**: Anonymous onboarding draft steps, routine projections, habit systems, and profile choices are orphaned under `oldAnonUid`.
3. **Logic Step 2**: The user loses all progress created during the anonymous session, violating requirement R11.
4. **Conclusion**: Adding anonymous auth & account linking methods to `AuthRepository` and implementing `OnboardingAccountMigrationService` preserves 100% of anonymous onboarding data upon account linking.

---

## 3. Caveats

1. **Firebase Auth vs Fake Auth behavior**: Firebase Auth `authStateChanges()` stream emits initial user state upon subscription, whereas test fakes must simulate stream emissions consistently.
2. **Network latency simulation**: Account switching and restoration tests must simulate artificial latency during remote fetches to verify zero data leakage during latency windows.
3. **Email verification delivery**: In automated testing environments, email verification state is controlled via `FakeAuthRepository.reloadCurrentUser()` and `AuthUser.emailVerified` flags.

---

## 4. Conclusion

All 6 Group D issues (Issues 16–21) have clear root causes and robust architectural solutions that conform to Optivus requirements R1–R11:
- **Issue 16**: Eliminating double microtask initialization in `AuthNotifier` and establishing `authState.status` as GoRouter's canonical source of truth solves stream synchronization issues.
- **Issue 17**: Exhaustive `resetForSignedOut()` implementation across all feature controllers ensures zero stale memory lingering after sign-out.
- **Issue 18**: Immediate atomic reset at the start of `_loadOrCreateBackendUserState` and strict `_ownerUid` matching guards prevent account switching data leaks.
- **Issue 19**: `AuthFailureReason` enum and `AuthFailureException` class map raw errors into strongly typed domain failures.
- **Issue 20**: Strict email verification checks in `markOnboardingComplete`, `_completeOnboarding()`, and GoRouter `redirect` prevent unverified navigation.
- **Issue 21**: `signInAnonymously()`, `linkAnonymousWithEmail()`, and `OnboardingAccountMigrationService` preserve 100% of onboarding state during anonymous account linking.

---

## 5. Verification Method

### Automated Test Suite Specification
Create `test/group_d_issues_16_to_21_test.dart` to cover all Group D issues:

1. **Issue 16 Tests**:
   - `AuthNotifier` startup stream synchronization test (single restoration execution, zero duplicate generation increments).
   - GoRouter redirect synchronization test (no transient route flashing or redirect loops).

2. **Issue 17 Tests**:
   - Comprehensive sign-out state invalidation test (populating data in all feature controllers, executing `logout()`, verifying every controller state is reset to empty defaults).

3. **Issue 18 Tests**:
   - Account switching data isolation test (populating User A's data, switching to User B with simulated fetch latency, verifying User A's data is 100% purged during restore phase and zero cross-user mutations occur).

4. **Issue 19 Tests**:
   - Strongly typed auth failure mapping test (mapping `network-request-failed`, `invalid-user-token`, `user-disabled`, `too-many-requests`, and `SocketException` to exact `AuthFailureReason` enum values).

5. **Issue 20 Tests**:
   - Email verification enforcement test (verifying unverified password users cannot mark onboarding complete, cannot bypass `/verify-email`, and are routed to `/app` only after verification is confirmed).

6. **Issue 21 Tests**:
   - Anonymous-to-authenticated account link state preservation test (signing in anonymously, completing onboarding steps 1–5, linking account to email/password, verifying 100% data preservation under linked UID).

### Command Verification
```bash
flutter analyze
flutter test test/group_d_issues_16_to_21_test.dart
flutter test test/onboarding_routing_test.dart
flutter test test/onboarding_restore_test.dart
```

### Invalidation Conditions
- Any occurrence of stale user data in feature controllers after sign-out.
- Any cross-user mutation or data leak during account switching latency.
- Unverified email users reaching `/app?tab=0`.
- Loss of anonymous onboarding draft data upon account linking.
- GoRouter redirect loops or `/loading` lockouts during auth state transitions.
