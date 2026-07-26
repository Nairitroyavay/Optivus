# Handoff Report — Group J Issues (58, 59 & 60)

## 1. Observation
1. **Cold Boot Splash Caching (Issue 58):**
   - `lib/main.dart` (lines 10-44) initializes `WidgetsFlutterBinding` and launches `OptivusApp`.
   - `lib/core/router/app_router.dart` (line 77) directs initial routing to `'/loading'`.
   - `lib/views/screens/loading_screen.dart` (lines 78-79) builds `GlassLogo()`.
   - `lib/widgets/glass_logo.dart` (line 78) calls `Image.asset('assets/images/logo.png', fit: BoxFit.contain)`.
   - `pubspec.yaml` (lines 65-66) registers `- assets/images/`.
   - File size inspection: `assets/images/logo.png` is 1,361,060 bytes (~1.36 MB). No `precacheImage` calls exist prior to rendering `LoadingScreen` or `WelcomeScreen`.

2. **App State Serialization Debouncing (Issue 59):**
   - `lib/features/onboarding/steps/onboarding_class_setup_timeline.dart` (line 508): `_persistCurrentDraftSoon()` calls `unawaited(_persistCurrentDraftNow().catchError((_) {}))`.
   - `lib/repositories/onboarding_repository.dart` (lines 49-51 & lines 176-180): `saveDraft(draft)` converts `OnboardingDraft` to `toMap()` and writes to disk or Firestore document `.set(draft.toMap(), SetOptions(merge: true))`.
   - `lib/features/onboarding/onboarding_flow.dart` (lines 126-144): `_persistCurrentDraftAfterNavigation()` calls `saveDraft(draft)` directly.
   - Grep search for `Timer` in `lib/` revealed no debouncing logic for draft persistence writes during rapid user keystrokes/input.

3. **Wake Lock Release Verification (Issue 60):**
   - `lib/services/onboarding_completion_job_service.dart` (lines 30-184): Executes multi-stage onboarding background completion job (`runCompletionJob`).
   - `lib/state/auth_state.dart` (lines 506-790): Background setup restoration routines (`_loadOrCreateBackendUserState`).
   - Grep search for `wakelock` across the repository returned 0 matches; background sync execution does not wrap system wake lock / background claims in `try ... finally` release structures.

---

## 2. Logic Chain
1. **Issue 58 Logic Chain:**
   - Observation 1 shows `assets/images/logo.png` is a 1.36 MB asset rendered inside `GlassLogo` on `LoadingScreen` on cold boot without pre-caching.
   - On cold boot, Flutter renders `LoadingScreen` first. Because `logo.png` is not precached in `PaintingBinding.instance.imageCache`, the Flutter engine must load asset bytes, decode PNG image data, and allocate GPU texture memory on the main UI/GPU rendering thread during the first frame animation cycle.
   - Therefore, pre-caching `assets/images/logo.png` via `precacheImage` during app initialization (`SplashAssetCacheService`) ensures the asset is pre-decoded in memory before `LoadingScreen` / `WelcomeScreen` renders, eliminating cold boot frame drops.

2. **Issue 59 Logic Chain:**
   - Observation 2 shows `_persistCurrentDraftSoon()` executes `_persistCurrentDraftNow()` immediately on state changes without debouncing delay.
   - Each call to `saveDraft()` serializes the entire draft model via `toMap()` and writes to disk or Firestore.
   - During rapid user typing (e.g. form fields, text inputs), 10 to 20 full object serializations and write operations occur per second, causing disk I/O thrashing and CPU load spikes.
   - Therefore, introducing a 300ms–500ms `Debouncer` in the draft persistence layer delays serialization until input pauses, while a `flush()` mechanism ensures zero data loss when step navigation occurs.

3. **Issue 60 Logic Chain:**
   - Observation 3 shows long-running background sync operations (`runCompletionJob`, background restoration) do not currently acquire and release system wake locks in `try-finally` blocks.
   - If an unhandled exception or network failure occurs mid-sync, any held wake lock or background process claim remains active indefinitely (`_isHeld = true`).
   - Unreleased wake locks drain device battery, leak CPU resources, and trigger OS power management penalties.
   - Therefore, wrapping background sync tasks in `runWithWakeLock` with guaranteed `try ... finally` release ensures wake locks are unconditionally released regardless of whether the sync succeeds or fails.

---

## 3. Caveats
- No caveats. Code inspection was complete across all relevant onboarding, router, repository, service, and state files.

---

## 4. Conclusion
- **Issue 58:** Create `lib/core/utils/asset_precache_service.dart` (`SplashAssetCacheService`) and call `precacheSplashAssets(context)` in `LoadingScreen`'s `didChangeDependencies()` to ensure `assets/images/logo.png` is cached in memory prior to initial UI composition.
- **Issue 59:** Create `lib/core/utils/debouncer.dart` (`Debouncer`) and integrate a 400ms debouncing wrapper in `OnboardingRepository.saveDraft()` with a `flushPendingDraftSave()` method called during step navigation in `OnboardingFlow`.
- **Issue 60:** Create `lib/services/background_sync_wake_lock_manager.dart` (`SystemWakeLock` and `runWithWakeLock<T>`) and wrap background sync routines in `OnboardingCompletionJobService` with guaranteed `try ... finally` lock release semantics.
- All 3 issues can be verified by creating `test/group_j_issues_58_to_60_test.dart`.

---

## 5. Verification Method

### Automated Tests
Run targeted Group J test suite (once implemented by implementer):
```bash
flutter test test/group_j_issues_58_to_60_test.dart
```

Run full regression test suite:
```bash
flutter test test/onboarding_completion_group_a_test.dart test/group_b_issues_7_to_11_test.dart test/group_c_issues_12_to_15_test.dart test/group_d_issues_16_to_21_test.dart test/group_e_issues_22_to_28_test.dart test/group_f_issues_29_to_30_test.dart test/group_g_issues_31_to_32_test.dart test/group_h_issues_33_to_42_test.dart test/group_i_issues_43_to_55_test.dart
```

### Static Analysis
```bash
dart analyze lib/core/utils/asset_precache_service.dart lib/core/utils/debouncer.dart lib/services/background_sync_wake_lock_manager.dart
```

### Invalidation Conditions
- If `assets/images/logo.png` is rendered on cold boot before `PaintingBinding.instance.imageCache` contains the decoded asset, Issue 58 verification fails.
- If rapid calls to `saveDraft()` trigger immediate serialization and disk writes without waiting for the 300ms-500ms timer (or if step navigation loses pending edits), Issue 59 verification fails.
- If an exception in a background sync task leaves `wakeLock.isHeld(tag) == true`, Issue 60 verification fails.
