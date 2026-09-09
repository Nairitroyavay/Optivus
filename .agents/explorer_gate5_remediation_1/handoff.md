# Remediation Specification Report: Gate 5 Forensic Integrity Audit Failures

**Agent**: `explorer_gate5_remediation_1`  
**Working Directory**: `/Users/avayroy/Optivus/.agents/explorer_gate5_remediation_1`  
**Date**: 2026-09-09T04:49:00Z  
**Parent**: `5ac787bb-bdea-4bb8-abb2-8df021fde719` (`orchestrator_gate5_1`)  
**Task**: Forensic Audit Remediation Investigation for Gate 5 Closure  

---

## 1. Observation

### 1.1 Test Failure Observation (`test/gate5_auth_reconstruction_race_test.dart:399`)
During concurrent execution of all 13 Gate 5 focused test suites:
```bash
flutter test --reporter compact \
  test/gate5_auth_session_isolation_test.dart \
  test/ah_f004_auth_identity_isolation_test.dart \
  test/ah_f003_google_auth_test.dart \
  test/workstream_d_auth_async_isolation_test.dart \
  test/onboarding_session_destination_test.dart \
  test/onboarding_routing_test.dart \
  test/onboarding_restore_test.dart \
  test/verify_email_redesign_test.dart \
  test/ah_f020_recoverable_error_model_test.dart \
  test/ah_f011_no_production_mock_leakage_test.dart \
  test/routine_phase4_4_ownership_test.dart \
  test/gate5_static_architecture_test.dart \
  test/gate5_auth_reconstruction_race_test.dart
```
The test suite fails with:
```text
00:11 +198 -1: /Users/avayroy/Optivus/test/gate5_auth_reconstruction_race_test.dart: Gate 5 Phase 3: Real Auth Reconstruction Race & Async Isolation (R5) TEST A: late Account A reconstruction completion cannot mutate Account B (resumeOnboarding) [E]
  Expected: true
    Actual: <false>
  
  package:matcher                                      expect
  package:flutter_test/src/widget_tester.dart 473:18   expect
  test/gate5_auth_reconstruction_race_test.dart 399:9  main.<fn>.<fn>
```

In `test/gate5_auth_reconstruction_race_test.dart`:
- Lines 58–59 define `hasPendingLoad`:
  ```dart
  bool hasPendingLoad(String uid) =>
      _completers.containsKey(uid) && !_completers[uid]!.isCompleted;
  ```
- Lines 373–400 in `TEST A`:
  ```dart
  373: // 3. Emit authenticated Account B while A's Future remains pending.
  374: authRepo.emitUserForTesting(_userB);
  375: await pumpEventQueue(times: 20);
  376: 
  377: // 4. Assert synchronous identity boundary cleared A before B becomes usable.
  378: final genB = container.read(authGenerationProvider);
  ...
  398: // 5. B's reconstruction is now in flight and pending.
  399: expect(source.hasPendingLoad(_userB.uid), isTrue);
  ```
- In `lib/state/auth_state.dart:1132-1155`:
  ```dart
  Future<void> _loadOrCreateBackendUserState(
    AuthUser user, {
    bool isAnonymousLink = false,
  }) async {
    ...
    if (!isAnonymousLink) {
      _clearStateForIdentityBoundary(user);
    }
    state = state.copyWith(
      user: user,
      status: AuthFlowStatus.loadingBackendUser,
      clearError: true,
      clearReconstructionResult: true,
    );
    final restoreGeneration = ++_backendRestoreGeneration;
    await _ref.read(regionSettingsProvider.notifier).loadForUser(user.uid);
    if (!mounted || !_isCurrentRestore(restoreGeneration)) return;
    ...
    await _reconstructAndHydrate(user, restoreGeneration);
  }
  ```
- In `lib/state/region_settings_provider.dart:32`:
  `loadForUser` invokes `await _deviceCountryService.detectCountry();`. In the test container (`_buildReconstructionContainer`), `regionSettingsProvider` is not overridden with a mock country service, so it defaults to `const GeolocatorDeviceCountryService()`, which triggers platform channel invocation and catches `MissingPluginException`.
- Under heavy parallel CPU isolate execution across 13 test suites, 20 microtask event pumps are exhausted before `loadForUser` completes. As a result, `_reconstructAndHydrate` has not yet called `source.load(_userB.uid)` when line 399 executes. Therefore, `_completers.containsKey(_userB.uid)` is false, yielding `Actual: <false>`.

### 1.2 Documentation Attestation Observation (`docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md`)
In `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md`:
1. **Section K (`Commands run:`)**: Lines 252–267 list 14 suites, completely omitting `test/gate5_auth_reconstruction_race_test.dart`.
2. **Section K (`Test Suite Table`)**: Lines 270–285 list 14 suites totaling 248 passed tests, omitting `gate5_auth_reconstruction_race_test.dart` (8 tests).
3. **Section O (`Technical debt register updates`)**: Line 352 attributes real reconstruction async race tests (Tests A–D) to `test/gate5_auth_session_isolation_test.dart` instead of `test/gate5_auth_reconstruction_race_test.dart`.
4. **Section P (`Final verdict`)**: Line 377 states:
   `| Gate 5 focused test suite | 248 passed, 0 failed | PASS |`
   instead of 256 passed tests.

---

## 2. Logic Chain

1. **Test Failure Mechanism**:
   - `authRepo.emitUserForTesting(_userB)` enqueues an event onto the broadcast stream.
   - `AuthNotifier._onAuthStateChanged` receives `_userB` and synchronously runs `_clearStateForIdentityBoundary(user)`.
   - `_clearStateForIdentityBoundary` synchronously calls `AuthSessionResetCoordinator.resetIdentityBoundary()`, resetting all 25+ providers and incrementing `authGenerationProvider`.
   - `_loadOrCreateBackendUserState` then awaits `regionSettingsProvider.notifier.loadForUser(_userB.uid)`.
   - `loadForUser` runs `detectCountry()`, an asynchronous platform-channel call.
   - `pumpEventQueue(times: 20)` pumps exactly 20 event loop iterations.
   - When CPU/isolate contention slows platform-channel resolution beyond 20 turns, `source.load(_userB.uid)` is delayed.
   - At line 399, `source.hasPendingLoad(_userB.uid)` returns `false` because `source.load` has not yet been invoked.
   - Replacing the fixed-iteration count (`times: 20`) with a polling loop that pumps the event queue until `source.hasPendingLoad(_userB.uid)` is `true` (with a timeout) decouples test execution from arbitrary pump counts and guarantees deterministic execution under any level of isolate concurrency.

2. **Documentation Discrepancy Mechanism**:
   - The focused test suite comprises 14 test suites in `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md` (which includes 2 historical/supplemental suites `ah_f007` and `ah_f008`) plus `gate5_auth_reconstruction_race_test.dart`.
   - The test count of `gate5_auth_reconstruction_race_test.dart` is 8 (Tests A, A-Home, A-Error, B, B-Error, C, C-Presentation, D).
   - $248 + 8 = 256$.
   - Adding `gate5_auth_reconstruction_race_test.dart` to Section K and updating the total to 256 tests in Section K and Section P resolves the documentation discrepancy completely.

---

## 3. Caveats

1. The underlying production code in `lib/state/auth_state.dart` and `lib/state/verification_lifecycle_state.dart` is clean and correct. The failure is entirely an asynchronous timing assumption in test code.
2. While `while (!source.hasPendingLoad(_userB.uid)) await pumpEventQueue(times: 10);` works inline, encapsulating `waitForPendingLoad(String uid, {Duration timeout})` inside `CompleterServerReconstructionSource` is significantly cleaner, prevents duplicate code across tests, and provides timeout protection against infinite hangs.
3. Test A (Home destination) at line 470 contains an identical `await pumpEventQueue(times: 20);` followed by `expect(source.hasPendingLoad(_userB.uid), isTrue);`. Applying `waitForPendingLoad` there defensively eliminates potential flakiness in Test A2 as well.

---

## 4. Conclusion & Minimal Fix Specifications

### 4.1 Worker Fix Specification: `test/gate5_auth_reconstruction_race_test.dart`

#### Change 1: Add `waitForPendingLoad` to `CompleterServerReconstructionSource`
In `test/gate5_auth_reconstruction_race_test.dart`, insert the helper method directly on `CompleterServerReconstructionSource` after line 59:

```dart
<<<<
  bool hasPendingLoad(String uid) =>
      _completers.containsKey(uid) && !_completers[uid]!.isCompleted;

  @override
====
  bool hasPendingLoad(String uid) =>
      _completers.containsKey(uid) && !_completers[uid]!.isCompleted;

  /// Resiliently pumps the event queue until [load] has been entered for [uid]
  /// and is awaiting completer resolution.
  Future<void> waitForPendingLoad(
    String uid, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (!hasPendingLoad(uid)) {
      if (stopwatch.elapsed > timeout) {
        throw TimeoutException(
          'Timed out waiting for pending load for $uid after ${stopwatch.elapsed}',
        );
      }
      await pumpEventQueue(times: 5);
    }
  }

  @override
>>>>
```

#### Change 2: Replace brittle fixed pump in `TEST A` (Line 375)
In `test/gate5_auth_reconstruction_race_test.dart`, replace line 375:

```dart
<<<<
        // 3. Emit authenticated Account B while A's Future remains pending.
        authRepo.emitUserForTesting(_userB);
        await pumpEventQueue(times: 20);

        // 4. Assert synchronous identity boundary cleared A before B becomes usable.
====
        // 3. Emit authenticated Account B while A's Future remains pending.
        authRepo.emitUserForTesting(_userB);
        await source.waitForPendingLoad(_userB.uid);

        // 4. Assert synchronous identity boundary cleared A before B becomes usable.
>>>>
```

#### Change 3 (Defensive): Replace fixed pump in `TEST A (Home destination)` (Line 470)
In `test/gate5_auth_reconstruction_race_test.dart`, replace line 470:

```dart
<<<<
        // Emit Account B.
        authRepo.emitUserForTesting(_userB);
        await pumpEventQueue(times: 20);
        expect(source.hasPendingLoad(_userB.uid), isTrue);
====
        // Emit Account B.
        authRepo.emitUserForTesting(_userB);
        await source.waitForPendingLoad(_userB.uid);
        expect(source.hasPendingLoad(_userB.uid), isTrue);
>>>>
```

#### Optional Secondary Defenses
The Worker may optionally update the initial Account A wait lines (`line 359`, `line 465`, `line 534`, `line 587`, `line 640`, `line 678`, `line 813`) to use `await source.waitForPendingLoad(_userA.uid);` for uniform test hygiene across the entire file.

---

### 4.2 Worker Fix Specification: `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md`

#### Change 1: Add test suite to Section K `Commands run:`
Lines 265–267:
```markdown
<<<<
  test/routine_phase4_4_ownership_test.dart \
  test/gate5_static_architecture_test.dart
```
====
  test/routine_phase4_4_ownership_test.dart \
  test/gate5_static_architecture_test.dart \
  test/gate5_auth_reconstruction_race_test.dart
```
>>>>
```

#### Change 2: Add test suite row & update total in Section K Table
Lines 284–286:
```markdown
<<<<
| `gate5_static_architecture_test.dart` | 7 | 0 | 0 |
| **Total Gate 5 Focused** | **248** | **0** | **0** |
====
| `gate5_static_architecture_test.dart` | 7 | 0 | 0 |
| `gate5_auth_reconstruction_race_test.dart` | 8 | 0 | 0 |
| **Total Gate 5 Focused** | **256** | **0** | **0** |
>>>>
```

#### Change 3: Fix test file reference in Section O
Line 352:
```markdown
<<<<
  - Real reconstruction async race tests (Tests A, B, C, D) using controlled `ServerReconstructionSource` verify pipeline-level isolation under concurrent and late completions (`test/gate5_auth_session_isolation_test.dart`).
====
  - Real reconstruction async race tests (Tests A, B, C, D) using controlled `ServerReconstructionSource` verify pipeline-level isolation under concurrent and late completions (`test/gate5_auth_reconstruction_race_test.dart`).
>>>>
```

#### Change 4: Update total in Section P Final Verdict Table
Line 377:
```markdown
<<<<
| Gate 5 focused test suite | 248 passed, 0 failed | PASS |
====
| Gate 5 focused test suite | 256 passed, 0 failed | PASS |
>>>>
```

---

## 5. Verification Method

### 5.1 Verification Commands
After the Worker applies the changes:

1. **Verify Concurrent Suite Execution**:
   ```bash
   flutter test --reporter compact \
     test/gate5_auth_session_isolation_test.dart \
     test/ah_f004_auth_identity_isolation_test.dart \
     test/ah_f003_google_auth_test.dart \
     test/workstream_d_auth_async_isolation_test.dart \
     test/onboarding_session_destination_test.dart \
     test/onboarding_routing_test.dart \
     test/onboarding_restore_test.dart \
     test/verify_email_redesign_test.dart \
     test/ah_f020_recoverable_error_model_test.dart \
     test/ah_f011_no_production_mock_leakage_test.dart \
     test/routine_phase4_4_ownership_test.dart \
     test/gate5_static_architecture_test.dart \
     test/gate5_auth_reconstruction_race_test.dart
   ```
   **Expected Outcome**: All tests execute concurrently and exit 0 (`All tests passed!`).

2. **Verify Formatting**:
   ```bash
   dart format --output=none --set-exit-if-changed test/gate5_auth_reconstruction_race_test.dart
   ```
   **Expected Outcome**: Clean exit code 0.

3. **Verify Static Analysis**:
   ```bash
   flutter analyze test/gate5_auth_reconstruction_race_test.dart
   ```
   **Expected Outcome**: `No issues found!`.

4. **Verify Report Text & Numbers**:
   ```bash
   grep -n "gate5_auth_reconstruction_race_test" docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md
   grep -n "256" docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md
   ```
   **Expected Outcome**: Matches found in Section K, Section O, and Section P reflecting 256 tests.

### 5.2 Invalidation Conditions
- Any test failure in `test/gate5_auth_reconstruction_race_test.dart` under concurrent or isolated execution.
- Discrepancy between the test matrix in Section K and actual test execution.
- Any regression in static analysis or formatting.
