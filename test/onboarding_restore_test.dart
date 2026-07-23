import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/app/optivus_app.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/routine_import_review_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

void main() {
  test(
    'firebase incomplete user does not become onboarding incomplete until draft fetch completes',
    () async {
      const user = AuthUser(
        uid: 'restore-user',
        email: 'restore@example.com',
        emailVerified: true,
      );
      final authRepository = _ControllableAuthRepository();
      final profileRepository = await _profileRepositoryFor(
        user,
        onboardingCompleted: false,
      );
      final draftCompleter = Completer<OnboardingDraft?>();
      final onboardingRepository = _ControlledOnboardingRepository(
        draftCompleter: draftCompleter,
      );
      final container = ProviderContainer(
        overrides: _firebaseOverrides(
          authRepository: authRepository,
          profileRepository: profileRepository,
          onboardingRepository: onboardingRepository,
        ),
      );
      addTearDown(container.dispose);
      addTearDown(authRepository.dispose);

      final statuses = <AuthFlowStatus>[];
      final subscription = container.listen<AuthState>(
        authProvider,
        (_, next) => statuses.add(next.status),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      authRepository.emit(user);
      await pumpEventQueue(times: 10);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.restoringOnboarding,
      );
      expect(
        statuses,
        isNot(contains(AuthFlowStatus.signedInOnboardingIncomplete)),
      );
      expect(container.read(mockOnboardingProvider).draft.currentStep, 0);

      draftCompleter.complete(_draftFor(user.uid, currentStep: 4));
      await pumpEventQueue(times: 10);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.signedInOnboardingIncomplete,
      );
      expect(container.read(mockOnboardingProvider).draft.currentStep, 4);
    },
  );

  testWidgets('saved onboarding draft currentStep 4 opens directly at step 4', (
    tester,
  ) async {
    final draft = _draftFor('draft-user', currentStep: 4);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
        ],
        child: const MaterialApp(home: OnboardingFlow()),
      ),
    );
    await tester.pump();

    expect(find.text('Classes & Job'), findsOneWidget);
    expect(find.text('Welcome to\nOptivus'), findsNothing);
  });

  testWidgets(
    'router shows restoring setup and no onboarding welcome while draft is fetching',
    (tester) async {
      const user = AuthUser(
        uid: 'router-restore-user',
        email: 'router@example.com',
        emailVerified: true,
      );
      final authRepository = _ControllableAuthRepository();
      final profileRepository = await _profileRepositoryFor(
        user,
        onboardingCompleted: false,
      );
      final draftCompleter = Completer<OnboardingDraft?>();
      final onboardingRepository = _ControlledOnboardingRepository(
        draftCompleter: draftCompleter,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _firebaseOverrides(
            authRepository: authRepository,
            profileRepository: profileRepository,
            onboardingRepository: onboardingRepository,
          ),
          child: const OptivusApp(),
        ),
      );
      addTearDown(authRepository.dispose);

      authRepository.emit(user);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      expect(find.text('Restoring your setup...'), findsOneWidget);
      expect(find.text('Welcome to\nOptivus'), findsNothing);
      expect(find.text('Get Started'), findsNothing);
    },
  );

  test(
    'draft fetch failure shows restore error, allows retry, and does not reset draft',
    () async {
      const user = AuthUser(
        uid: 'retry-restore-user',
        email: 'retry@example.com',
        emailVerified: true,
      );
      final existingDraft = _draftFor(user.uid, currentStep: 4);
      final authRepository = _ControllableAuthRepository();
      final profileRepository = await _profileRepositoryFor(
        user,
        onboardingCompleted: false,
      );
      final onboardingRepository = _ControlledOnboardingRepository(
        draft: existingDraft,
        draftFailures: 1,
      );
      final container = ProviderContainer(
        overrides: _firebaseOverrides(
          authRepository: authRepository,
          profileRepository: profileRepository,
          onboardingRepository: onboardingRepository,
        ),
      );
      addTearDown(container.dispose);
      addTearDown(authRepository.dispose);

      container
          .read(mockOnboardingProvider.notifier)
          .loadSeedData(existingDraft);
      container.read(authProvider);

      authRepository.emit(user);
      await pumpEventQueue(times: 10);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.backendRestoreFailed,
      );
      expect(
        container.read(authProvider).errorMessage,
        'Could not restore setup. Check your connection and try again.',
      );
      expect(container.read(mockOnboardingProvider).draft.currentStep, 4);

      await container.read(authProvider.notifier).retryBackendRestore();
      await pumpEventQueue(times: 10);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.signedInOnboardingIncomplete,
      );
      expect(container.read(mockOnboardingProvider).draft.currentStep, 4);
    },
  );

  test('fake mode starts at welcome step when no draft exists', () async {
    const user = AuthUser(
      uid: 'fake-new-user',
      email: 'fake@example.com',
      emailVerified: true,
    );
    final authRepository = _ControllableAuthRepository();
    final container = ProviderContainer(
      overrides: [
        optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        authRepositoryProvider.overrideWithValue(authRepository),
        onboardingRepositoryProvider.overrideWithValue(
          _ControlledOnboardingRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authRepository.dispose);

    container.read(authProvider);
    authRepository.emit(user);
    await pumpEventQueue(times: 10);

    final auth = container.read(authProvider);
    final draft = container.read(mockOnboardingProvider).draft;
    expect(auth.status, AuthFlowStatus.signedInOnboardingIncomplete);
    expect(draft.uid, user.uid);
    expect(draft.currentStep, 0);
  });

  test('fake mode resumes a saved draft when one exists', () async {
    const user = AuthUser(
      uid: 'fake-saved-user',
      email: 'fake-saved@example.com',
      emailVerified: true,
    );
    final authRepository = _ControllableAuthRepository();
    final onboardingRepository = _ControlledOnboardingRepository(
      draft: _draftFor(user.uid, currentStep: 4),
    );
    final container = ProviderContainer(
      overrides: [
        optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        authRepositoryProvider.overrideWithValue(authRepository),
        onboardingRepositoryProvider.overrideWithValue(onboardingRepository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authRepository.dispose);

    container.read(authProvider);
    authRepository.emit(user);
    await pumpEventQueue(times: 10);

    expect(
      container.read(authProvider).status,
      AuthFlowStatus.signedInOnboardingIncomplete,
    );
    expect(container.read(mockOnboardingProvider).draft.currentStep, 4);
  });
}

List<Override> _firebaseOverrides({
  required AuthRepository authRepository,
  required ProfileRepository profileRepository,
  required OnboardingRepository onboardingRepository,
}) {
  return [
    optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
    authRepositoryProvider.overrideWithValue(authRepository),
    profileRepositoryProvider.overrideWithValue(profileRepository),
    regionSettingsRepositoryProvider.overrideWithValue(
      FakeRegionSettingsRepository(),
    ),
    appPreferencesRepositoryProvider.overrideWithValue(
      FakeAppPreferencesRepository(),
    ),
    onboardingRepositoryProvider.overrideWithValue(onboardingRepository),
    routineImportReviewRepositoryProvider.overrideWithValue(
      FakeRoutineImportReviewRepository(),
    ),
    routineRepositoryProvider.overrideWithValue(FakeRoutineRepository()),
    routineHistoryRepositoryProvider.overrideWithValue(
      FakeRoutineHistoryRepository(),
    ),
  ];
}

Future<FakeProfileRepository> _profileRepositoryFor(
  AuthUser user, {
  required bool onboardingCompleted,
}) async {
  final repository = FakeProfileRepository();
  await repository.saveUserProfile(
    UserProfile.empty(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
    ).copyWith(
      onboardingCompleted: onboardingCompleted,
      onboardingStep: onboardingCompleted ? OnboardingDraft.lastStepIndex : 0,
      updatedAt: DateTime.utc(2026, 6, 5),
    ),
  );
  return repository;
}

OnboardingDraft _draftFor(String uid, {required int currentStep}) {
  final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
  for (var i = 0; i < currentStep; i++) {
    completed[i] = true;
  }
  return OnboardingDraft(
    uid: uid,
    currentStep: currentStep,
    stepCompleted: completed,
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks(),
    createdAt: DateTime.utc(2026, 6, 5, 8),
    updatedAt: DateTime.utc(2026, 6, 5, 9),
  );
}

class _ControllableAuthRepository implements AuthRepository {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  void emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  void dispose() {
    _controller.close();
  }

  @override
  Future<String?> currentIdToken() async =>
      _currentUser == null ? null : 'token';

  @override
  Future<AuthUser?> reloadCurrentUser() async => _currentUser;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signIn(String email, String password) async {
    final user =
        _currentUser ??
        AuthUser(uid: 'login-user', email: email, emailVerified: true);
    emit(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    emit(null);
  }

  @override
  Future<AuthUser> signUp(String email, String password, {String? name}) async {
    final user = AuthUser(
      uid: 'signup-user',
      email: email,
      displayName: name,
      emailVerified: false,
    );
    emit(user);
    return user;
  }
}

class _ControlledOnboardingRepository implements OnboardingRepository {
  final Completer<OnboardingDraft?>? draftCompleter;
  OnboardingDraft? draft;
  int draftFailures;

  _ControlledOnboardingRepository({
    this.draftCompleter,
    this.draft,
    this.draftFailures = 0,
  });

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    if (draftFailures > 0) {
      draftFailures--;
      throw Exception('draft fetch failed');
    }
    final completer = draftCompleter;
    if (completer != null) {
      return completer.future;
    }
    return draft?.uid == uid ? draft : null;
  }

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async {
    return null;
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    this.draft = draft;
  }

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {}

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    draft = finalDraft;
    return RoutineProjectionResult(
      outcome: RoutineProjectionOutcome.projected,
      receipt: RoutineOnboardingProjection.build(bundle).receipt,
    );
  }
}
