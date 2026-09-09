import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/onboarding_state.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/features/profile/screens/profile_control_screens.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AH-F009 save status contract', () {
    test('successful current revision transitions saving to synced', () {
      final notifier = OnboardingNotifier();
      notifier.setStepDirty(0, true);
      notifier.setStepLoading(0, true);
      final submittedRevision = notifier.state.draft.revision;
      final savedDraft = notifier.state.draft.copyWith(
        welcomeSaved: true,
        stepCompleted: _withValue(notifier.state.draft.stepCompleted, 0, true),
        stepDirty: _withValue(notifier.state.draft.stepDirty, 0, false),
      );

      expect(notifier.state.stepSaveStatus[0], SaveSyncStatus.saving);
      expect(
        notifier.acknowledgeStepSave(
          step: 0,
          submittedRevision: submittedRevision,
          savedDraft: savedDraft,
        ),
        isTrue,
      );
      expect(notifier.state.stepSaveStatus[0], SaveSyncStatus.synced);
      expect(notifier.state.hasUnsyncedChangesAt(0), isFalse);
    });

    test('failed write keeps current edit and records truthful failed state', () {
      final notifier = OnboardingNotifier();
      notifier.updateDraft(
        (draft) => draft.copyWith(patiencePledgeText: 'Current edit'),
      );
      notifier.setStepDirty(1, true);

      notifier.markStepSyncFailed(
        1,
        message:
            "Couldn't sync your changes. Your changes are still open here. Retry before leaving this step.",
      );

      expect(notifier.state.draft.patiencePledgeText, 'Current edit');
      expect(notifier.state.stepSaveStatus[1], SaveSyncStatus.failed);
      expect(notifier.state.hasUnsyncedChangesAt(1), isTrue);
      expect(notifier.state.validationMessage, contains("Couldn't sync"));
      expect(notifier.state.validationMessage, contains('still open here'));
      expect(notifier.state.validationMessage, isNot(contains('Saved')));
      expect(notifier.state.validationMessage, isNot(contains('locally')));
    });

    test('older success cannot mark or replace a newer edit', () {
      final notifier = OnboardingNotifier();
      notifier.updateDraft(
        (draft) => draft.copyWith(patiencePledgeText: 'Edit A'),
      );
      notifier.setStepDirty(1, true);
      notifier.setStepLoading(1, true);
      final submittedRevision = notifier.state.draft.revision;
      final savedA = notifier.state.draft.copyWith(
        stepCompleted: _withValue(notifier.state.draft.stepCompleted, 1, true),
        stepDirty: _withValue(notifier.state.draft.stepDirty, 1, false),
      );

      notifier.updateDraft(
        (draft) => draft.copyWith(patiencePledgeText: 'Edit B'),
      );
      notifier.setStepDirty(1, true);

      expect(
        notifier.acknowledgeStepSave(
          step: 1,
          submittedRevision: submittedRevision,
          savedDraft: savedA,
        ),
        isFalse,
      );
      expect(notifier.state.draft.patiencePledgeText, 'Edit B');
      expect(notifier.state.stepSaveStatus[1], SaveSyncStatus.dirty);
      expect(notifier.state.hasUnsyncedChangesAt(1), isTrue);
    });

    test('older failure does not clobber a newer edit', () {
      final notifier = OnboardingNotifier();
      notifier.updateDraft(
        (draft) => draft.copyWith(patiencePledgeText: 'Edit A'),
      );
      notifier.setStepDirty(1, true);
      notifier.updateDraft(
        (draft) => draft.copyWith(patiencePledgeText: 'Edit B'),
      );

      notifier.markStepSyncFailed(1, message: "Couldn't sync your changes.");

      expect(notifier.state.draft.patiencePledgeText, 'Edit B');
      expect(notifier.state.stepSaveStatus[1], SaveSyncStatus.failed);
    });

    test(
      'account reset clears dirty state while no-op same-UID refresh does not',
      () {
        final notifier = OnboardingNotifier()..reset('user-a');
        notifier.updateDraft(
          (draft) => draft.copyWith(patiencePledgeText: 'User A edit'),
        );
        notifier.setStepDirty(1, true);

        // AH-F008 same-UID refresh performs no onboarding reset.
        expect(notifier.state.draft.uid, 'user-a');
        expect(notifier.state.hasUnsyncedChangesAt(1), isTrue);

        notifier.reset('user-b');
        expect(notifier.state.draft.uid, 'user-b');
        expect(notifier.state.draft.patiencePledgeText, isNull);
        expect(notifier.state.hasUnsyncedChangesAt(1), isFalse);
      },
    );

    test(
      'fresh reconstruction derives state only from durable server draft',
      () {
        final serverDraft = OnboardingDraft(
          uid: 'user-a',
          stepCompleted: _withValue(
            const OnboardingDraft().stepCompleted,
            0,
            true,
          ),
          stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
        );
        final reconstructed = OnboardingState(draft: serverDraft);

        expect(reconstructed.stepSaveStatus[0], SaveSyncStatus.synced);
        expect(reconstructed.hasUnsyncedChangesAt(0), isFalse);
      },
    );

    test('new edit resets synced status to dirty immediately', () {
      final notifier = OnboardingNotifier();
      notifier.setStepCompleted(0, true);
      expect(notifier.state.stepSaveStatus[0], SaveSyncStatus.synced);

      notifier.setStepDirty(0, true);
      expect(notifier.state.stepSaveStatus[0], SaveSyncStatus.dirty);
      expect(notifier.state.hasUnsyncedChangesAt(0), isTrue);
    });

    test('role invalidation resets affected step save statuses to dirty', () {
      final notifier = OnboardingNotifier();
      notifier.setStepCompleted(2, true);
      notifier.setStepCompleted(4, true);
      expect(notifier.state.stepSaveStatus[2], SaveSyncStatus.synced);
      expect(notifier.state.stepSaveStatus[4], SaveSyncStatus.synced);

      notifier.updateLifeRoleSelection('working');
      expect(notifier.state.stepSaveStatus[2], SaveSyncStatus.dirty);
      expect(notifier.state.stepSaveStatus[4], SaveSyncStatus.dirty);
      expect(notifier.state.stepCompleted[2], isFalse);
      expect(notifier.state.stepCompleted[4], isFalse);
    });

    test(
      'core failure and process-death truth: in-memory edit vs server durable value',
      () async {
        const serverVal = 'VALUE_OLD';
        const userVal = 'VALUE_NEW';
        final repository = _ControlledRepository(failuresRemaining: 1);
        repository.durableDraft = const OnboardingDraft(
          uid: 'user-1',
          patiencePledgeText: serverVal,
        );

        final notifier = OnboardingNotifier();
        notifier.loadSeedData(repository.durableDraft!);
        expect(notifier.state.draft.patiencePledgeText, serverVal);

        // User makes an edit in process memory
        notifier.updateDraft((d) => d.copyWith(patiencePledgeText: userVal));
        notifier.setStepDirty(1, true);

        // Save fails
        try {
          await repository.saveDraft(notifier.state.draft);
        } catch (_) {
          notifier.markStepSyncFailed(
            1,
            message:
                "Couldn't sync your changes. Your changes are still open here. Retry before leaving this step.",
          );
        }

        // UI/Provider: VALUE_NEW remains visible in memory, status is failed/unsynced
        expect(notifier.state.draft.patiencePledgeText, userVal);
        expect(notifier.state.stepSaveStatus[1], SaveSyncStatus.failed);
        expect(notifier.state.hasUnsyncedChangesAt(1), isTrue);
        expect(notifier.state.validationMessage, contains("Couldn't sync"));
        expect(notifier.state.validationMessage, contains('still open here'));
        expect(
          notifier.state.validationMessage,
          isNot(contains('Saved locally')),
        );

        // Server: VALUE_OLD remains authoritative
        expect(repository.durableDraft?.patiencePledgeText, serverVal);

        // Simulate process death & fresh reconstruct from server: returns VALUE_OLD
        final freshProcessState = OnboardingState(
          draft: (await repository.fetchDraft('user-1'))!,
        );
        expect(freshProcessState.draft.patiencePledgeText, serverVal);
        expect(freshProcessState.hasUnsyncedChangesAt(1), isFalse);
      },
    );
  });

  group('AH-F009 onboarding failure UX', () {
    testWidgets('validation error is distinguished from sync error', (
      tester,
    ) async {
      final repository = _ControlledRepository();
      late OnboardingNotifier notifier;
      await _pumpFlow(tester, repository, (value) => notifier = value);

      // Navigate through step 0 to step 1
      await tester.tap(find.text('Get Started'));
      await _pumpAsyncUi(tester);
      expect(notifier.state.currentStep, 1);
      final initialCalls = repository.saveCalls;

      // Attempt to jump forward before step 1 is complete
      await tester.tapAt(
        tester.getCenter(find.byType(LiquidGlassOnboardingIndicator)) +
            const Offset(60, 0),
      );
      await tester.pump();

      // No network write attempted for step 1
      expect(repository.saveCalls, initialCalls);
      expect(notifier.state.stepSaveStatus[1], isNot(SaveSyncStatus.failed));
      expect(notifier.state.stepSaveStatus[1], isNot(SaveSyncStatus.saving));
      expect(
        notifier.state.validationMessage,
        contains('Use Next Step to unlock'),
      );
      expect(
        notifier.state.validationMessage,
        isNot(contains("Couldn't sync")),
      );
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('failed required save blocks progression and offers Retry', (
      tester,
    ) async {
      final repository = _ControlledRepository(failuresRemaining: 1);
      late OnboardingNotifier notifier;
      await _pumpFlow(tester, repository, (value) => notifier = value);

      await tester.tap(find.text('Get Started'));
      await _pumpAsyncUi(tester);

      expect(repository.saveCalls, 1);
      expect(notifier.state.currentStep, 0);
      expect(notifier.state.stepCompleted[0], isFalse);
      expect(notifier.state.stepSaveStatus[0], SaveSyncStatus.failed);
      expect(
        find.textContaining("Couldn't sync your changes."),
        findsOneWidget,
      );
      expect(
        find.textContaining('Your changes are still open here.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Saved locally'), findsNothing);

      notifier.updateDraft(
        (draft) => draft.copyWith(patiencePledgeText: 'Newest retry edit'),
      );
      notifier.setStepDirty(0, true);
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding-sync-retry')));
      await _pumpAsyncUi(tester);

      expect(repository.saveCalls, 2);
      expect(repository.durableDraft?.patiencePledgeText, 'Newest retry edit');
      expect(notifier.state.stepSaveStatus[0], SaveSyncStatus.synced);
      expect(notifier.state.stepCompleted[0], isTrue);
      expect(find.textContaining("Couldn't sync"), findsNothing);
    });

    testWidgets('repeated Next taps do not issue concurrent writes', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repository = _ControlledRepository(gate: gate);
      late OnboardingNotifier notifier;
      await _pumpFlow(tester, repository, (value) => notifier = value);

      await tester.tap(find.text('Get Started'));
      await tester.tap(find.text('Get Started'));
      await tester.pump();

      expect(repository.saveCalls, 1);
      expect(notifier.state.stepSaveStatus[0], SaveSyncStatus.saving);

      gate.complete();
      await _pumpAsyncUi(tester);
      expect(
        repository.saveCalls,
        2,
      ); // step save plus navigation metadata save
      expect(notifier.state.currentStep, 1);
    });

    testWidgets('late User A failure cannot dirty User B state', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repository = _ControlledRepository(
        gate: gate,
        failuresRemaining: 1,
      );
      late OnboardingNotifier notifier;
      await _pumpFlow(tester, repository, (value) => notifier = value);

      await tester.tap(find.text('Get Started'));
      await tester.pump();
      expect(notifier.state.stepSaveStatus[0], SaveSyncStatus.saving);

      notifier.reset('user-b');
      gate.complete();
      await _pumpAsyncUi(tester);

      expect(notifier.state.draft.uid, 'user-b');
      expect(notifier.state.stepSaveStatus[0], SaveSyncStatus.clean);
      expect(notifier.state.hasUnsyncedChangesAt(0), isFalse);
    });

    testWidgets('bug report submission is truthfully scoped to session', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(),
            ),
            appPreferencesRepositoryProvider.overrideWithValue(
              FakeAppPreferencesRepository(),
            ),
          ],
          child: MaterialApp(home: ReportBugScreen(onBack: () {})),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Bug title'),
        'Crash on scroll',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'What happened?'),
        'App froze on step 3',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Which screen?'),
        'Onboarding step 3',
      );
      await tester.pump();

      await tester.tap(find.text('Submit bug report'));
      await tester.pump();

      expect(
        find.text('Bug report recorded for this session.'),
        findsOneWidget,
      );
      expect(find.textContaining('submitted locally'), findsNothing);
      expect(find.textContaining('Saved locally'), findsNothing);
    });
  });
}

Future<void> _pumpAsyncUi(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpFlow(
  WidgetTester tester,
  OnboardingRepository repository,
  ValueChanged<OnboardingNotifier> capture,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        optivusDebugBuildProvider.overrideWithValue(true),
        onboardingStateProvider.overrideWith((_) {
          final notifier = OnboardingNotifier()..reset('test-user');
          capture(notifier);
          return notifier;
        }),
        authProvider.overrideWith((_) => _FakeAuthNotifier()),
        onboardingRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: OnboardingFlow()),
    ),
  );
  await tester.pump();
}

List<bool> _withValue(List<bool> source, int index, bool value) {
  final result = List<bool>.from(source);
  result[index] = value;
  return result;
}

class _ControlledRepository implements OnboardingRepository {
  _ControlledRepository({this.failuresRemaining = 0, this.gate});

  int failuresRemaining;
  int saveCalls = 0;
  final Completer<void>? gate;
  OnboardingDraft? durableDraft;

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    saveCalls++;
    if (gate != null && !gate!.isCompleted) await gate!.future;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw Exception('injected write failure');
    }
    durableDraft = draft;
  }

  @override
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) =>
      saveDraft(draft);

  @override
  Future<void> flushPendingDraftSave() async {}

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async => durableDraft;

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async =>
      null;

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {}

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async => RoutineProjectionResult(
    outcome: RoutineProjectionOutcome.projected,
    receipt: RoutineOnboardingProjection.build(bundle).receipt,
  );

  @override
  void dispose() {}
}

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier()
    : super(
        const AuthState(
          user: AuthUser(
            uid: 'test-user',
            email: 'test@example.com',
            emailVerified: true,
          ),
          status: AuthFlowStatus.signedInOnboardingIncomplete,
        ),
      );

  @override
  Future<void> acceptCanonicalOnboardingCompletion(AuthUser user) async {}
  @override
  Future<void> checkEmailVerification() async {}
  @override
  Future<void> executeRecoveryAction(OnboardingRecoveryAction action) async {}
  @override
  Future<void> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {}
  @override
  Future<void> login(String email, String password) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<void> markOnboardingComplete(AuthUser user) async {}
  @override
  Future<void> markOnboardingIncomplete(AuthUser user) async {}
  @override
  Future<void> resendEmailVerification() async {}
  @override
  Future<void> retryBackendRestore() async {}
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<bool> signInWithGoogle() async => false;
  @override
  Future<void> signup(String name, String email, String password) async {}
}
