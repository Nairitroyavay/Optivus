# Task Assignment: Phase 3 Real Auth Reconstruction Race & Async Isolation Tests (R5)

Your working directory is: `/Users/avayroy/Optivus/.agents/worker_gate5_phase3_1`
You are a worker agent (`teamwork_preview_worker`).

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Context & Inputs
- MANDATORY: Read `/Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md` completely.
- Read `/Users/avayroy/Optivus/.agents/orchestrator_gate5_1/AUDIT_TABLE.md`.
- Read `/Users/avayroy/Optivus/.agents/explorer_gate5_03/handoff.md` (specifically Section 4: Design of Tests A, B, C, D using Completer-based ServerReconstructionSource).
- Inspect `lib/services/server_reconstructor.dart`, `lib/state/auth_state.dart`, `lib/state/auth_generation.dart`.
- Inspect existing tests in `test/gate5_auth_session_isolation_test.dart`.

## Exclusive Write Ownership
You own and may edit ONLY these files:
- `test/gate5_auth_reconstruction_race_test.dart` (new test file dedicated to Tests A, B, C, D)
- `test/gate5_auth_session_isolation_test.dart` (if wiring Tests A, B, C, D into the suite)

Do NOT edit any file outside `test/gate5_auth_reconstruction_race_test.dart` or `test/gate5_auth_session_isolation_test.dart`.

## Instructions
1. Implement `CompleterServerReconstructionSource` implementing `ServerReconstructionSource` (`lib/services/server_reconstructor.dart`):
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

2. Implement **TEST A — A reconstruction completes after B**:
   - Start `AuthNotifier` in Firebase mode (`OptivusBackendMode.firebase`) with `serverReconstructorProvider` overridden by `ServerReconstructor(source: source)`.
   - Emit authenticated Account A (`userA`).
   - A's `ServerReconstructionSource.load(A)` begins.
   - DO NOT complete A's Future (leave completer pending).
   - Seed/observe clearly identifiable A state where appropriate (e.g. mock goal, routine preference).
   - Emit authenticated Account B (`userB`).
   - Assert synchronous identity boundary has already cleared A before B is published/usable (`authGenerationProvider` incremented, user profile empty, goal empty, routine preference default).
   - Begin B reconstruction: B's completer is pending.
   - Complete B reconstruction with B-owned profile, onboarding draft, completion state.
   - Pump event queue until B reaches its final `SessionDestination` (e.g. `resumeOnboarding` or `home`).
   - **ONLY NOW** complete A's old reconstruction Future (`source.completerFor('user-a').complete(snapshotA)`).
   - Pump event queue.
   - Assert:
     - `AuthState.user.uid == B.uid`
     - `AuthState.sessionDestination` belongs to B
     - `authGeneration` belongs to current boundary
     - `userProfileProvider.uid == B.uid`
     - `onboardingStateProvider.draft.uid == B.uid`
     - routine, habit, upload, region, home, fitness states contain NO Account A data
     - no A error becomes `AuthState.error`
     - no A `reconstructionResult` becomes active
     - no A route/destination becomes active

3. Implement **TEST B — A reconstruction completes after sign-out**:
   - A reconstruction starts and is pending (completer pending).
   - Sign out succeeds (`AuthNotifier.logout()`).
   - Synchronous reset occurs: `AuthState.status == AuthFlowStatus.signedOut`, user is null.
   - Complete old A Future (`source.completerFor('user-a').complete(snapshotA)`).
   - Pump queue.
   - Assert: still `signedOut`, no A state returns, no A error published, no destination changes.

4. Implement **TEST C — Failed logout preserves Account A**:
   - Account A fully hydrated.
   - `signOut` repository throws typed/mappable failure.
   - Attempt `logout()`.
   - Assert: A remains current, no identity reset occurs, `authGeneration` unchanged, A state remains, `AuthState.error` is `RecoverableError`.
   - Verify Verify Email screen (or state) renders this same typed failure.

5. Implement **TEST D — Same UID refresh**:
   - Start `AuthNotifier`, emit `userA`, complete A's completer.
   - Record `authGeneration` and `source.loadCalls.length`.
   - Emit updated `AuthUser` with same UID.
   - Pump event queue.
   - Assert: no privacy reset, no `authGeneration` increment, no `appNavigation` reset, `source.loadCalls.length` did NOT increment (no reconstruction restart), current projections remain intact.

6. **Verification**:
   - Run `dart format --output=none --set-exit-if-changed <your changed/created test files>`
   - Run `flutter analyze <your changed/created test files>`
   - Run `flutter test <your changed/created test files>`
   - Run `flutter test test/gate5_auth_session_isolation_test.dart`
   - Write your handoff report to `/Users/avayroy/Optivus/.agents/worker_gate5_phase3_1/handoff.md`.

## 2026-09-09T04:19:39Z
You are worker_gate5_phase3_1. Your working directory is /Users/avayroy/Optivus/.agents/worker_gate5_phase3_1.
Read your instructions in /Users/avayroy/Optivus/.agents/worker_gate5_phase3_1/DISPATCH.md.
MANDATORY: Read /Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md before starting work.
MANDATORY INTEGRITY WARNING: DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
Exclusive write ownership:
- test/gate5_auth_reconstruction_race_test.dart
- test/gate5_auth_session_isolation_test.dart
Implement Phase 3: Real Auth Reconstruction Race & Async Isolation Tests (R5: Tests A, B, C, D) using CompleterServerReconstructionSource.
Run format, analyze, and tests.
Write your handoff report to /Users/avayroy/Optivus/.agents/worker_gate5_phase3_1/handoff.md and report back via send_message.
