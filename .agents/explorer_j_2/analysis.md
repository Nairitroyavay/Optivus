# Group J Issues (58, 59 & 60) Deep Code Analysis & Stabilization Plan

## Executive Summary
This report presents a thorough investigation of Group J Onboarding Stabilization Issues (Issues 58, 59, and 60) in Optivus.
- **Issue 58:** Cold boot splash image caching optimization to eliminate cold boot frame drops caused by synchronous/on-demand loading of large PNG assets (`assets/images/logo.png`, 1.36 MB).
- **Issue 59:** App state serialization debouncing for disk I/O reduction to prevent disk I/O thrashing during rapid user input by introducing a 300ms–500ms debounce timer with immediate `flush()` capability.
- **Issue 60:** System wake lock release verification after background sync to guarantee that all system wake locks and background process claims are acquired before sync execution and unconditionally released in `try-finally` blocks regardless of sync outcome or errors.

---

## 1. Deep Code Inspection & Root Cause Analysis

### Issue 58: Cold Boot Splash Image Caching Optimization
- **Observed Code Locations:**
  - `lib/main.dart` (lines 10-44): Application entry point bootstraps Flutter engine, configures edge-to-edge UI, validates runtime config, initializes Firebase, and runs `OptivusApp`.
  - `lib/app/optivus_app.dart` (lines 7-20): Initializes `MaterialApp.router` with `routerProvider`.
  - `lib/core/router/app_router.dart` (line 77): Defines `initialLocation: '/loading'`.
  - `lib/views/screens/loading_screen.dart` (lines 78-79): Renders `GlassLogo()`.
  - `lib/widgets/glass_logo.dart` (lines 77-80): Instantiates `Image.asset('assets/images/logo.png', fit: BoxFit.contain)`.
  - `pubspec.yaml` (lines 65-66): Declares asset path `assets/images/`.
  - Disk asset: `assets/images/logo.png` is 1,361,060 bytes (~1.36 MB).
- **Exact Root Cause:**
  - When the application starts up on cold boot, `LoadingScreen` is displayed immediately while auth and profile states resolve.
  - `GlassLogo` inside `LoadingScreen` invokes `Image.asset('assets/images/logo.png')` without prior image pre-caching.
  - Because `logo.png` is 1.36 MB compressed (decoding to ~4 MB uncompressed RGBA pixel buffer), Flutter must perform asset bundle retrieval, PNG byte decoding, and texture memory allocation on the main UI/GPU rendering thread during the very first animation frame of `LoadingScreen`'s pulsing animation (`AnimationController` running at 1400ms duration).
  - This synchronous on-demand image load during initial widget rendering causes frame drops (jank) and startup rendering latency.

### Issue 59: App State Serialization Debouncing for Disk I/O Reduction
- **Observed Code Locations:**
  - `lib/features/onboarding/onboarding_flow.dart` (lines 126-144, 205, 261, 489, 585): Invokes `_persistCurrentDraftAfterNavigation()` and `onboardingRepositoryProvider.saveDraft(draft)`.
  - `lib/features/onboarding/steps/onboarding_class_setup_timeline.dart` (lines 496-510): `_persistCurrentDraftSoon()` calls `unawaited(_persistCurrentDraftNow().catchError((_) {}))`.
  - `lib/repositories/onboarding_repository.dart` (lines 49-51, 176-180): `saveDraft(draft)` serializes the entire `OnboardingDraft` object using `draft.toMap()` and writes to disk or Firestore document (`_firestore.doc(FirestoreUserPaths.onboardingDraft(draft.uid)).set(draft.toMap(), SetOptions(merge: true))`).
  - `lib/state/app_state.dart` (lines 1500-1647): `MockOnboardingNotifier` updates state on user interactions.
- **Exact Root Cause:**
  - In `onboarding_class_setup_timeline.dart` line 508, `_persistCurrentDraftSoon()` attempts to persist draft state asynchronously, but it immediately executes `_persistCurrentDraftNow()` without any debouncing delay timer.
  - As users rapidly type text into input fields (e.g. course names, work schedules, custom meal descriptions, habit titles) or interact with form controls, state updates trigger 10 to 20 full object serializations (`toMap()`) and disk/Firestore writes per second.
  - This high-frequency disk I/O thrashing consumes excess CPU cycles, degrades app responsiveness, drains battery, and risks out-of-order write race conditions.

### Issue 60: System Wake Lock Release Verification After Background Sync
- **Observed Code Locations:**
  - `lib/services/onboarding_completion_job_service.dart` (lines 30-184): Executes multi-stage onboarding completion background jobs (`persistDraft`, `persistBundle`, `projectRoutines`, `projectHabits`, `updateProfile`).
  - `lib/services/uploads/r2_upload_service.dart`: Handles background file and asset uploads.
  - `lib/state/auth_state.dart` (lines 506-790): Manages background user state synchronization and backend restoration.
  - `lib/repositories/routine_transaction_repository.dart` (lines 481, 565): Uses `try ... finally` for completer completion, but background sync execution lacks a unified system wake lock manager with guaranteed `try-finally` release.
- **Exact Root Cause:**
  - Background synchronization, cloud data restoration, and multi-stage completion jobs require CPU execution continuity to prevent OS background suspension or process termination mid-sync.
  - Currently, background sync operations do not wrap system wake lock / background execution process claims (`SystemWakeLock` / `BackgroundProcessClaim`) in strict `try ... finally` blocks.
  - If a network error, timeout, server failure, or state exception occurs during background sync, held wake locks remain active (`_isHeld = true`), causing CPU power leakage, battery drain, OS power management warnings, and background process deadlocks.

---

## 2. Comprehensive Fix Architecture & Design

### Architecture for Issue 58 (Splash Image Pre-Caching)
1. **New Utility:** Create `lib/core/utils/asset_precache_service.dart`.
   - Define `SplashAssetCacheService` with constant list of critical splash/boot asset paths: `['assets/images/logo.png']`.
   - Provide `Future<void> precacheSplashAssets(BuildContext context)` using Flutter's `precacheImage(AssetImage(path), context)`.
2. **Integration in Startup Flow:**
   - In `LoadingScreenState` (`lib/views/screens/loading_screen.dart`), override `didChangeDependencies()` to invoke `SplashAssetCacheService.precacheSplashAssets(context)`.
   - Alternatively, add an early precache step in `OptivusApp` / `main.dart` using `WidgetsBinding.instance.addPostFrameCallback` so image decoding occurs before initial frame composition.
3. **Verification Invariant:**
   - Before `GlassLogo` widget is mounted or rendered on screen, `logo.png` must already exist in `PaintingBinding.instance.imageCache`.

### Architecture for Issue 59 (App State Serialization Debouncing)
1. **New Debouncer Utility:** Create `lib/core/utils/debouncer.dart`.
   - Generic `Debouncer` class with configurable `Duration` (default 400ms, range 300ms–500ms).
   - Methods: `run(VoidCallback action)`, `cancel()`, `bool get isPending`, and `flush(VoidCallback action)`.
2. **Debounced Repository Wrapper:** Modify `lib/repositories/onboarding_repository.dart` (or create `DebouncedOnboardingRepository`).
   - Wrap `saveDraft(OnboardingDraft draft)` with a 400ms `Debouncer`.
   - Rapid calls to `saveDraft()` cancel previous timers and reset the 400ms countdown. Serialization (`draft.toMap()`) and disk/Firestore I/O are delayed until typing stops.
   - Implement `Future<void> flushPendingDraftSave()`: If a timer is active, cancel the timer and immediately execute the pending save operation asynchronously and return a `Future`.
3. **Integration in Onboarding Navigation:**
   - In `OnboardingFlow` (`lib/features/onboarding/onboarding_flow.dart`), call `flushPendingDraftSave()` on step transition ("Next" / "Back" / "Complete Onboarding") or screen dispose to ensure zero data loss.
   - Update `_persistCurrentDraftSoon()` in `onboarding_class_setup_timeline.dart` to utilize the debounced draft saver.

### Architecture for Issue 60 (System Wake Lock Release Verification)
1. **New Wake Lock Manager:** Create `lib/services/background_sync_wake_lock_manager.dart`.
   - Define `abstract class SystemWakeLock` and `class DefaultSystemWakeLock implements SystemWakeLock`.
   - Maintain a set of active claim tags `Set<String> _activeClaims`.
   - Provide helper function:
     ```dart
     Future<T> runWithWakeLock<T>({
       required String tag,
       required SystemWakeLock wakeLock,
       required Future<T> Function() syncTask,
     }) async {
       await wakeLock.acquire(tag: tag);
       try {
         return await syncTask();
       } finally {
         await wakeLock.release(tag: tag);
       }
     }
     ```
2. **Integration in Background Sync Services:**
   - In `OnboardingCompletionJobService` (`lib/services/onboarding_completion_job_service.dart`), wrap `runCompletionJob` execution inside `runWithWakeLock(tag: 'onboarding_completion_$uid', ...)`.
   - In `R2UploadService` and `AuthState` backend restoration routines, wrap background sync tasks inside `runWithWakeLock` or explicit `try ... finally` blocks.
3. **Verification Invariant:**
   - For any background sync task executed via `runWithWakeLock`, regardless of whether `syncTask` returns normally or throws an error/exception, `wakeLock.isHeld(tag)` MUST equal `false` after function exit.

---

## 3. Files to Modify & Files to Create

| File Path | Action | Description / Responsibility |
|---|---|---|
| `lib/core/utils/asset_precache_service.dart` | CREATE | Utility for pre-caching cold-boot splash asset images (`logo.png`) into Flutter imageCache before rendering main UI. |
| `lib/core/utils/debouncer.dart` | CREATE | Generic timer-based debouncer supporting 300ms-500ms delay and synchronous/async `flush()` execution. |
| `lib/services/background_sync_wake_lock_manager.dart` | CREATE | System wake lock and background process claim manager enforcing `try-finally` release semantics. |
| `lib/views/screens/loading_screen.dart` | MODIFY | Integrate `SplashAssetCacheService` in `didChangeDependencies` / startup lifecycle. |
| `lib/repositories/onboarding_repository.dart` | MODIFY | Add debouncing wrapper around `saveDraft()` with `flushPendingDraftSave()` method. |
| `lib/features/onboarding/onboarding_flow.dart` | MODIFY | Ensure step transitions, completion, and exit handlers flush pending debounced saves before proceeding. |
| `lib/features/onboarding/steps/onboarding_class_setup_timeline.dart` | MODIFY | Update `_persistCurrentDraftSoon()` to use debounced persistence instead of immediate unawaited execution. |
| `lib/services/onboarding_completion_job_service.dart` | MODIFY | Wrap multi-stage completion job in `runWithWakeLock` with guaranteed `try-finally` release. |
| `test/group_j_issues_58_to_60_test.dart` | CREATE | Comprehensive targeted and regression test suite verifying Issues 58, 59, and 60. |

---

## 4. Targeted & Regression Test Specifications

### New Test Suite: `test/group_j_issues_58_to_60_test.dart`

```dart
// Test cases to implement in group_j_issues_58_to_60_test.dart

void main() {
  group('Group J - Issue 58: Cold Boot Splash Image Caching Optimization', () {
    testWidgets('SplashAssetCacheService pre-caches logo asset before LoadingScreen render', (tester) async {
      // 1. Initialize test binding and precache service
      // 2. Call SplashAssetCacheService.precacheSplashAssets(context)
      // 3. Verify logo.png is present in PaintingBinding.instance.imageCache
      // 4. Pump LoadingScreen widget and verify smooth initial frame render without asset loading exceptions
    });
  });

  group('Group J - Issue 59: App State Serialization Debouncing', () {
    test('Rapid consecutive saveDraft calls (20 writes in 50ms) result in exactly 1 serialization write after 400ms', () async {
      // 1. Initialize FakeOnboardingRepository with DebouncedOnboardingRepository wrapper (400ms duration)
      // 2. Rapidly call repository.saveDraft(draft) 20 times within 50ms
      // 3. Verify write count remains 0 immediately after calls
      // 4. Advance fake async clock by 200ms -> verify write count is still 0
      // 5. Advance fake async clock past 400ms -> verify write count equals exactly 1
    });

    test('Calling flushPendingDraftSave() immediately executes pending save without waiting for timer', () async {
      // 1. Call repository.saveDraft(draft)
      // 2. Immediately call repository.flushPendingDraftSave()
      // 3. Verify write count equals 1 immediately without delay
    });

    test('Onboarding step transition flushes pending draft before navigating', () async {
      // 1. Trigger draft change in OnboardingFlow
      // 2. Invoke step transition (_saveStep / _onNextPressed)
      // 3. Confirm pending draft is persisted completely prior to step increment
    });
  });

  group('Group J - Issue 60: System Wake Lock Release Verification After Background Sync', () {
    test('Successful background sync acquires and releases system wake lock', () async {
      // 1. Instantiate FakeSystemWakeLock
      // 2. Run background sync task via runWithWakeLock(tag: 'sync_test', ...)
      // 3. Verify wakeLock was acquired during sync execution
      // 4. Verify wakeLock.isHeld('sync_test') is false after completion
    });

    test('Failed background sync throwing exception STILL releases wake lock via try-finally', () async {
      // 1. Instantiate FakeSystemWakeLock
      // 2. Run failing background sync task throwing StateError inside runWithWakeLock
      // 3. Expect exception to be thrown to caller
      // 4. Verify wakeLock.isHeld('sync_test') is false despite exception
    });

    test('OnboardingCompletionJobService releases wake lock claim on job completion or failure', () async {
      // 1. Run completion job service with injected failing stage
      // 2. Verify wake lock claim is released in all terminal states
    });
  });
}
```

---

## 5. Verification Method

To verify the fixes independently after implementation:
1. Run static analysis:
   ```bash
   dart analyze lib/core/utils/asset_precache_service.dart lib/core/utils/debouncer.dart lib/services/background_sync_wake_lock_manager.dart
   ```
2. Run targeted Group J unit & widget tests:
   ```bash
   flutter test test/group_j_issues_58_to_60_test.dart
   ```
3. Run existing onboarding & recovery test suites for regression testing:
   ```bash
   flutter test test/onboarding_completion_group_a_test.dart test/group_b_issues_7_to_11_test.dart test/group_c_issues_12_to_15_test.dart test/group_d_issues_16_to_21_test.dart test/group_e_issues_22_to_28_test.dart test/group_f_issues_29_to_30_test.dart test/group_g_issues_31_to_32_test.dart test/group_h_issues_33_to_42_test.dart test/group_i_issues_43_to_55_test.dart
   ```
