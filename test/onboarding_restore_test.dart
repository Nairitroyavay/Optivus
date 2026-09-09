import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/app/optivus_app.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/routine_import_review_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/device_country_service.dart';
import 'package:optivus/views/screens/app_shell.dart';

void main() {
  test(
    'new verified Firebase account opens a local Step 0 draft without entering restore',
    () async {
      const user = AuthUser(
        uid: 'brand-new-user',
        email: 'brand-new@example.com',
        displayName: 'Brand New',
        emailVerified: true,
      );
      final authRepository = _ControllableAuthRepository();
      final profileRepository = FakeProfileRepository();
      final onboardingRepository = _ControlledOnboardingRepository();
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
      await pumpEventQueue(times: 20);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.signedInOnboardingIncomplete,
      );
      expect(container.read(authProvider).needsAction, isFalse);
      expect(statuses, isNot(contains(AuthFlowStatus.restoringOnboarding)));
      expect(onboardingRepository.draft, isNull);
      expect(
        container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .blocks
            .map((block) => block.id),
        containsAll(<String>[
          BaseTimelineDraft.fixedSleepId,
          BaseTimelineDraft.fixedBathId,
        ]),
      );
      expect(container.read(onboardingStateProvider).draft.uid, user.uid);
    },
  );

  testWidgets(
    'fresh account never shows restore copy while checking for a draft',
    (tester) async {
      const user = AuthUser(
        uid: 'fresh-delayed-user',
        email: 'fresh-delayed@example.com',
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

      expect(find.text('Starting Optivus...'), findsOneWidget);
      expect(find.text('Restoring your setup...'), findsNothing);

      draftCompleter.complete(null);
      for (var i = 0; i < 12; i++) {
        await tester.pump();
      }

      expect(find.text('Welcome to\nOptivus'), findsOneWidget);
      expect(find.text('Restoring your setup...'), findsNothing);
      expect(onboardingRepository.draft, isNull);
    },
  );

  testWidgets(
    'completed account never publishes restoringOnboarding while final reconstruction is pending',
    (tester) async {
      const user = AuthUser(
        uid: 'completed-delayed-user',
        email: 'completed-delayed@example.com',
        emailVerified: true,
      );
      final completedDraft = _completedDraftFor(user.uid);
      final authRepository = _ControllableAuthRepository();
      final profileRepository = await _profileRepositoryFor(
        user,
        onboardingCompleted: true,
      );
      final draftCompleter = Completer<OnboardingDraft?>();
      final onboardingRepository = _ControlledOnboardingRepository(
        draftCompleter: draftCompleter,
        completionBundle: _completionBundleFor(user.uid, completedDraft),
      );
      final statuses = <AuthFlowStatus>[];

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

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OptivusApp)),
      );
      final subscription = container.listen<AuthState>(
        authProvider,
        (_, next) => statuses.add(next.status),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      authRepository.emit(user);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      expect(find.text('Starting Optivus...'), findsOneWidget);
      expect(find.text('Restoring your setup...'), findsNothing);
      expect(statuses, isNot(contains(AuthFlowStatus.restoringOnboarding)));

      draftCompleter.complete(completedDraft);
      for (var i = 0; i < 20; i++) {
        await tester.pump();
      }

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.text('Restoring your setup...'), findsNothing);
      expect(statuses, isNot(contains(AuthFlowStatus.restoringOnboarding)));
    },
  );

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
        onboardingStep: 4,
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
      expect(container.read(onboardingStateProvider).draft.currentStep, 0);

      draftCompleter.complete(_draftFor(user.uid, currentStep: 4));
      await pumpEventQueue(times: 10);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.signedInOnboardingIncomplete,
      );
      expect(container.read(onboardingStateProvider).draft.currentStep, 4);
    },
  );

  testWidgets('saved onboarding draft currentStep 4 opens directly at step 4', (
    tester,
  ) async {
    final draft = _draftFor('draft-user', currentStep: 4);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingStateProvider.overrideWith(
            (_) => OnboardingNotifier()..loadSeedData(draft),
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
        onboardingStep: 4,
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
          .read(onboardingStateProvider.notifier)
          .loadSeedData(existingDraft);
      container.read(authProvider);

      authRepository.emit(user);
      await pumpEventQueue(times: 10);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.reconnectRequired,
      );
      expect(
        container.read(authProvider).errorMessage,
        "We couldn't reconnect yet.",
      );
      expect(container.read(onboardingStateProvider).draft.currentStep, 4);

      await container.read(authProvider.notifier).retryBackendRestore();
      await pumpEventQueue(times: 10);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.signedInOnboardingIncomplete,
      );
      expect(container.read(onboardingStateProvider).draft.currentStep, 4);
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
    await pumpEventQueue(times: 20);

    final auth = container.read(authProvider);
    final draft = container.read(onboardingStateProvider).draft;
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
    await pumpEventQueue(times: 20);

    expect(
      container.read(authProvider).status,
      AuthFlowStatus.signedInOnboardingIncomplete,
    );
    expect(container.read(onboardingStateProvider).draft.currentStep, 4);
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
    deviceCountryServiceProvider.overrideWithValue(
      const _NoDeviceCountryService(),
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
    routineTransactionRepositoryProvider.overrideWithValue(
      FakeRoutineTransactionRepository(
        routineRepository: FakeRoutineRepository(),
        historyRepository: FakeRoutineHistoryRepository(),
      ),
    ),
  ];
}

class _NoDeviceCountryService implements DeviceCountryService {
  const _NoDeviceCountryService();

  @override
  Future<DeviceCountry?> detectCountry() async => null;
}

Future<FakeProfileRepository> _profileRepositoryFor(
  AuthUser user, {
  required bool onboardingCompleted,
  int? onboardingStep,
}) async {
  final repository = FakeProfileRepository();
  await repository.saveUserProfile(
    UserProfile.empty(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
    ).copyWith(
      onboardingCompleted: onboardingCompleted,
      onboardingStep:
          onboardingStep ??
          (onboardingCompleted ? OnboardingDraft.lastStepIndex : 0),
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
    patiencePledgeAccepted: true,
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'other',
    ),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks(),
    createdAt: DateTime.utc(2026, 6, 5, 8),
    updatedAt: DateTime.utc(2026, 6, 5, 9),
  );
}

OnboardingDraft _completedDraftFor(String uid) {
  final draft = _draftFor(uid, currentStep: OnboardingDraft.lastStepIndex);
  return draft.copyWith(
    currentStep: OnboardingDraft.lastStepIndex,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    onboardingCompleted: true,
    finalPreview: draft.buildFinalPreview(),
    incrementRevision: false,
  );
}

OnboardingCompletionBundle _completionBundleFor(
  String uid,
  OnboardingDraft draft,
) {
  return OnboardingCompletionBundle(
    uid: uid,
    runId: 'run-completed-startup',
    createdAt: DateTime.utc(2026, 6, 5, 10),
    updatedAt: DateTime.utc(2026, 6, 5, 10),
    userProfilePatch: const {},
    baseTimelineBlocks: const [],
    finalTimelineItems: const [],
    routineItemsForApp: const [],
    goodHabitTemplates: const [],
    badHabitCheckIns: const [],
    identityGoalSystems: const [],
    notificationPreferences: NotificationPreferences(),
    coachPreferences: CoachPreferences(),
    moneyGoal: null,
    uploadedAssetReferences: const [],
    warnings: const [],
    duplicateSystemKeysMerged: const [],
    sourceFingerprint: draft.effectiveSourceFingerprint,
    draftRevision: draft.revision,
  );
}

class _ControllableAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<AuthUser> signInAnonymously() async =>
      _currentUser ?? const AuthUser(uid: 'anon-id', email: 'anon@test.dev');

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async =>
      _currentUser ?? AuthUser(uid: 'anon-id', email: email, displayName: name);

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
  @override
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) async {
    await saveDraft(draft);
  }

  final Completer<OnboardingDraft?>? draftCompleter;
  final OnboardingCompletionBundle? completionBundle;
  OnboardingDraft? draft;
  int draftFailures;

  _ControlledOnboardingRepository({
    this.draftCompleter,
    this.completionBundle,
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
    return completionBundle?.uid == uid ? completionBundle : null;
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    this.draft = draft;
  }

  @override
  Future<void> flushPendingDraftSave() async {}

  @override
  void dispose() {}

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
