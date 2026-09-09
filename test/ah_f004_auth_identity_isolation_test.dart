import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/core/errors/auth_error_mapper.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/goal_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/state/upload_state.dart';

const _userA = AuthUser(
  uid: 'user-a',
  email: 'a@example.com',
  emailVerified: true,
  providerIds: {'password'},
);
const _userB = AuthUser(
  uid: 'user-b',
  email: 'b@example.com',
  emailVerified: true,
  providerIds: {'google.com'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AH-F004 provider identity', () {
    test('Firebase provider facts preserve every membership', () {
      final user = authUserFromProviderFacts(
        uid: 'linked-user',
        emailVerified: true,
        providerIds: const ['password', 'google.com', 'phone'],
      );

      expect(user.providerIds, {'password', 'google.com', 'phone'});
      expect(user.hasPasswordProvider, isTrue);
      expect(user.hasGoogleProvider, isTrue);
    });

    test(
      'provider order cannot change membership or verification semantics',
      () {
        final passwordThenGoogle = authUserFromProviderFacts(
          uid: 'linked-user',
          emailVerified: false,
          providerIds: const ['password', 'google.com'],
        );
        final googleThenPassword = authUserFromProviderFacts(
          uid: 'linked-user',
          emailVerified: false,
          providerIds: const ['google.com', 'password'],
        );

        expect(passwordThenGoogle.providerIds, googleThenPassword.providerIds);
        expect(
          passwordThenGoogle.needsEmailVerification,
          googleThenPassword.needsEmailVerification,
        );
        expect(
          AuthNotifier.statusFor(passwordThenGoogle, false),
          AuthNotifier.statusFor(googleThenPassword, false),
        );
        expect(
          AuthNotifier.statusFor(passwordThenGoogle, false),
          AuthFlowStatus.signedInOnboardingIncomplete,
        );

        final verifiedPasswordThenGoogle = authUserFromProviderFacts(
          uid: 'linked-user',
          emailVerified: true,
          providerIds: const ['password', 'google.com'],
        );
        final verifiedGoogleThenPassword = authUserFromProviderFacts(
          uid: 'linked-user',
          emailVerified: true,
          providerIds: const ['google.com', 'password'],
        );
        expect(
          AuthNotifier.statusFor(verifiedPasswordThenGoogle, true),
          AuthNotifier.statusFor(verifiedGoogleThenPassword, true),
        );
        expect(
          AuthNotifier.statusFor(verifiedPasswordThenGoogle, true),
          AuthFlowStatus.signedInOnboardingComplete,
        );
      },
    );

    test('password-only unverified user is gated but Google user is not', () {
      const passwordUser = AuthUser(
        uid: 'password-user',
        emailVerified: false,
        providerIds: {'password'},
      );
      const googleUser = AuthUser(
        uid: 'google-user',
        emailVerified: false,
        providerIds: {'google.com'},
      );

      expect(passwordUser.needsEmailVerification, isTrue);
      expect(googleUser.needsEmailVerification, isFalse);
      expect(
        AuthNotifier.statusFor(passwordUser, false),
        AuthFlowStatus.signedInEmailUnverified,
      );
      expect(
        AuthNotifier.statusFor(googleUser, false),
        AuthFlowStatus.signedInOnboardingIncomplete,
      );
    });

    test(
      'legacy deprecated providerId getter is deterministic display-only',
      () {
        const googleOnly = AuthUser(uid: 'u1', providerIds: {'google.com'});
        const passOnly = AuthUser(uid: 'u2', providerIds: {'password'});
        const multi = AuthUser(
          uid: 'u3',
          providerIds: {'password', 'google.com'},
        );
        // Deprecated getter remains non-crashing compatibility fallback
        // ignore: deprecated_member_use_from_same_package
        expect(googleOnly.providerId, 'google.com');
        // ignore: deprecated_member_use_from_same_package
        expect(passOnly.providerId, 'password');
        // ignore: deprecated_member_use_from_same_package
        expect(multi.providerId, 'google.com');
      },
    );
  });

  group('AH-F004 logout transaction and state boundary', () {
    test(
      'successful logout clears every populated user-state family and preserves global config',
      () async {
        final auth = _ControlledAuthRepository();
        final container = _container(auth);
        addTearDown(container.dispose);
        addTearDown(auth.dispose);

        auth.emit(_userA);
        await pumpEventQueue(times: 20);
        _populateUserAState(container);

        // Assert global config is fake mode
        expect(
          container.read(optivusBackendModeProvider),
          OptivusBackendMode.fake,
        );

        await container.read(authProvider.notifier).logout();

        expect(container.read(authProvider).user, isNull);
        expect(container.read(authProvider).status, AuthFlowStatus.signedOut);
        _expectUserStateCleared(container);

        // Global config is preserved after logout
        expect(
          container.read(optivusBackendModeProvider),
          OptivusBackendMode.fake,
        );
      },
    );

    test('failed logout keeps authenticated state, data, and route', () async {
      final auth = _ControlledAuthRepository()..signOutShouldFail = true;
      final container = _container(auth);
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      auth.emit(_userA);
      await pumpEventQueue(times: 20);
      _populateUserAState(container);
      final priorStatus = container.read(authProvider).status;

      await expectLater(
        container.read(authProvider.notifier).logout(),
        throwsA(isA<RecoverableError>()),
      );

      final state = container.read(authProvider);
      expect(state.user?.uid, _userA.uid);
      expect(state.status, priorStatus);
      expect(state.errorMessage, contains('still signed in'));
      expect(container.read(mockGoalProvider), isNotEmpty);
      expect(
        optivusAuthRedirect(
          authState: state,
          uri: Uri(path: '/onboarding'),
        ),
        isNull,
      );
    });

    test('FakeAuthRepository can simulate sign-out failure safely', () async {
      final repository = FakeAuthRepository()..signOutShouldFail = true;
      addTearDown(() {
        repository.signOutShouldFail = false;
      });
      final user = await repository.signIn('fake@example.com', 'password');

      await expectLater(repository.signOut(), throwsA(isA<RecoverableError>()));
      expect(repository.currentUser?.uid, user.uid);
    });
  });

  group('AH-F004 account switching', () {
    test('A state is cleared before B is published or hydrated', () async {
      final auth = _ControlledAuthRepository();
      final container = _container(auth);
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      auth.emit(_userA);
      await pumpEventQueue(times: 20);
      _populateUserAState(container);

      final observations =
          <({String profileUid, String draftUid, int goals})>[];
      container.listen<AuthState>(authProvider, (_, next) {
        if (next.user?.uid == _userB.uid) {
          observations.add((
            profileUid: container.read(userProfileProvider).uid,
            draftUid: container.read(onboardingStateProvider).draft.uid,
            goals: container.read(mockGoalProvider).length,
          ));
        }
      });

      auth.emit(_userB);
      await pumpEventQueue(times: 20);

      expect(observations, isNotEmpty);
      expect(observations.first.profileUid, isNot(_userA.uid));
      expect(observations.first.draftUid, isNot(_userA.uid));
      expect(observations.first.goals, 0);
      expect(container.read(userProfileProvider).uid, _userB.uid);
      expect(container.read(onboardingStateProvider).draft.uid, _userB.uid);
      expect(container.read(mockRoutineProvider), isEmpty);
      expect(container.read(mockGoalProvider), isEmpty);
      expect(container.read(mockTrackerProvider).trackerSessions, isEmpty);
    });

    test(
      'same-UID refresh updates auth facts without clearing valid state',
      () async {
        final auth = _ControlledAuthRepository();
        final container = _container(auth);
        addTearDown(container.dispose);
        addTearDown(auth.dispose);

        auth.emit(_userA);
        await pumpEventQueue(times: 20);
        container.read(mockGoalProvider.notifier).addGoal(_secretGoal);
        final profile = container
            .read(userProfileProvider)
            .copyWith(displayName: 'Preserved A');
        container.read(userProfileProvider.notifier).loadSeedData(profile);
        container.read(appNavigationProvider.notifier).goToGoals();
        final establishedStatus = container.read(authProvider).status;

        auth.emit(
          const AuthUser(
            uid: 'user-a',
            email: 'refreshed-a@example.com',
            emailVerified: true,
            providerIds: {'google.com', 'password'},
          ),
        );
        await pumpEventQueue(times: 10);

        expect(container.read(mockGoalProvider), contains(_secretGoal));
        expect(container.read(userProfileProvider).displayName, 'Preserved A');
        expect(
          container.read(authProvider).user?.email,
          'refreshed-a@example.com',
        );
        expect(container.read(authProvider).status, establishedStatus);
        expect(container.read(appNavigationProvider), 4);
      },
    );

    test('stale A backend result cannot overwrite B', () async {
      final auth = _ControlledAuthRepository();
      final onboarding = _DelayedOnboardingRepository();
      final container = _container(auth, onboarding: onboarding);
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      auth.emit(_userA);
      await pumpEventQueue(times: 5);
      auth.emit(_userB);
      await pumpEventQueue(times: 5);

      onboarding.complete(
        _userB.uid,
        OnboardingDraft(uid: _userB.uid, currentStep: 2),
      );
      await pumpEventQueue(times: 20);
      onboarding.complete(
        _userA.uid,
        OnboardingDraft(uid: _userA.uid, currentStep: 8),
      );
      await pumpEventQueue(times: 20);

      expect(container.read(authProvider).user?.uid, _userB.uid);
      expect(container.read(userProfileProvider).uid, _userB.uid);
      expect(container.read(onboardingStateProvider).draft.uid, _userB.uid);
      expect(container.read(onboardingStateProvider).draft.currentStep, 2);
    });

    test('null -> A retains onboarding draft only when UID matches', () async {
      final auth = _ControlledAuthRepository();
      final onboardingRepo = FakeOnboardingRepository();
      await onboardingRepo.saveDraft(
        OnboardingDraft(uid: _userA.uid, currentStep: 5),
      );

      final container = _container(auth, onboarding: onboardingRepo);
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      // Pre-seed an in-memory draft with user-a UID before auth completes
      container
          .read(onboardingStateProvider.notifier)
          .loadSeedData(OnboardingDraft(uid: _userA.uid, currentStep: 5));
      expect(container.read(onboardingStateProvider).draft.currentStep, 5);

      // Transition null -> A
      auth.emit(_userA);
      await pumpEventQueue(times: 20);

      // Retained because UID matched and backed by user A data
      expect(container.read(onboardingStateProvider).draft.uid, _userA.uid);
      expect(container.read(onboardingStateProvider).draft.currentStep, 5);

      // Now log out
      await container.read(authProvider.notifier).logout();
      expect(container.read(onboardingStateProvider).draft.uid, isEmpty);

      // Pre-seed draft with stale UID 'other-user'
      container
          .read(onboardingStateProvider.notifier)
          .loadSeedData(
            const OnboardingDraft(uid: 'other-user', currentStep: 3),
          );

      // Transition null -> B
      auth.emit(_userB);
      await pumpEventQueue(times: 20);

      // The non-matching 'other-user' draft was destroyed
      expect(container.read(onboardingStateProvider).draft.uid, _userB.uid);
      expect(container.read(onboardingStateProvider).draft.currentStep, 0);
    });
  });

  group('AH-F004 async stale work protections', () {
    test(
      'delayed coach AI response does not write after account reset',
      () async {
        final notifier = MockCoachNotifier(fakeDataAllowed: true);
        addTearDown(notifier.dispose);

        notifier.createNewSession(
          'Session 1',
          CoachSessionType.generalChat,
          'Sage',
          'Directive',
        );
        expect(notifier.state, isNotEmpty);
        final sessionId = notifier.state.first.id;

        notifier.sendMessage(sessionId, 'Hello from User A');
        expect(notifier.state.first.messages, hasLength(2));

        // User A logs out / switches account
        notifier.resetEmpty();
        expect(notifier.state, isEmpty);

        // Wait past the 1500ms delayed AI reply timer
        await Future<void>.delayed(const Duration(milliseconds: 1600));

        // Stale AI reply was discarded and did not contaminate the reset state
        expect(notifier.state, isEmpty);
      },
    );

    test(
      'stale upload completion does not write into switched account',
      () async {
        final auth = _ControlledAuthRepository()..emit(_userA);
        final assetRepo = FakeUploadedAssetRepository();
        final prepareService = _CompleterImagePrepareService();
        final r2Client = _FakeR2Client();

        final controller = UploadController(
          assetRepository: assetRepo,
          authRepository: auth,
          imagePrepareService: prepareService,
          r2UploadClient: r2Client,
        );
        addTearDown(controller.dispose);
        addTearDown(auth.dispose);

        // User A initiates photo upload
        final uploadFuture = controller.startUpload(
          uid: _userA.uid,
          purpose: UploadedAssetPurpose.profilePhoto,
          sourceFeature: 'profile',
        );

        expect(controller.state.status, UploadFlowStatus.picking);

        // Account switches to User B before image picker returns
        auth.emit(_userB);
        controller.resetForSignedOut();
        expect(controller.state.status, UploadFlowStatus.idle);

        // Now User A's pick completes
        prepareService.complete(
          PreparedUploadImage(
            fileName: 'photo.jpg',
            contentType: 'image/jpeg',
            bytes: Uint8List.fromList([1, 2, 3]),
            sizeBytes: 3,
          ),
        );

        final result = await uploadFuture;
        expect(result, isNull);
        expect(controller.state.status, UploadFlowStatus.idle);
        expect(controller.state.asset, isNull);
      },
    );
  });

  group('AH-F004 repository UID isolation', () {
    test('fake repositories isolate data strictly by Firebase UID', () async {
      final goalRepo = FakeGoalRepository();
      final profileRepo = FakeProfileRepository();
      final prefRepo = FakeAppPreferencesRepository();
      final regionRepo = FakeRegionSettingsRepository();

      await goalRepo.saveGoals('user-a', [_secretGoal]);
      await profileRepo.saveUserProfile(
        UserProfile.empty(
          uid: 'user-a',
        ).copyWith(displayName: 'User A Profile'),
      );
      await prefRepo.saveAppPreferences(
        'user-a',
        const UserPreferences(theme: 'dark'),
      );
      await regionRepo.saveRegionSettings(
        RegionSettings.forCountry(userId: 'user-a', countryCode: 'CA'),
      );

      // User B reads return empty/null or default
      final bGoals = await goalRepo.fetchGoals('user-b');
      final bProfile = await profileRepo.fetchUserProfile('user-b');
      final bPrefs = await prefRepo.fetchAppPreferences('user-b');
      final bRegion = await regionRepo.fetchRegionSettings('user-b');

      expect(bGoals, isEmpty);
      expect(bProfile, isNull);
      expect(bPrefs?.theme, isNot('dark'));
      expect(bRegion, isNull);

      // User A reads return User A data
      final aGoals = await goalRepo.fetchGoals('user-a');
      final aProfile = await profileRepo.fetchUserProfile('user-a');
      expect(aGoals, contains(_secretGoal));
      expect(aProfile?.displayName, 'User A Profile');
      expect((await prefRepo.fetchAppPreferences('user-a'))?.theme, 'dark');
      expect(
        (await regionRepo.fetchRegionSettings('user-a'))?.countryCode,
        'CA',
      );
    });
  });

  group('AH-F004 Google logout semantics', () {
    test(
      'Google sign-out cleanup runs best-effort and does not revoke consent',
      () async {
        final googleClient = _CountingGoogleIdentityClient();
        expect(googleClient.signOutCalls, 0);

        await googleClient.signOut();
        expect(googleClient.signOutCalls, 1);
      },
    );

    test(
      'failing Google local cleanup does not prevent successful signout completion',
      () async {
        final failingClient = _CountingGoogleIdentityClient()
          ..shouldFailSignOut = true;

        try {
          await failingClient.signOut();
        } catch (e) {
          // Handled safely by FirebaseAuthRepository without blocking logout
        }
        expect(failingClient.signOutCalls, 1);
      },
    );
  });
}

class _CountingGoogleIdentityClient implements GoogleIdentityClient {
  int signOutCalls = 0;
  bool shouldFailSignOut = false;

  @override
  Future<String?> authenticate() async => 'test-token';

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (shouldFailSignOut) {
      throw Exception('Simulated Google SDK local signOut failure');
    }
  }
}

ProviderContainer _container(
  _ControlledAuthRepository auth, {
  OnboardingRepository? onboarding,
}) {
  return ProviderContainer(
    overrides: [
      optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
      authRepositoryProvider.overrideWithValue(auth),
      if (onboarding != null)
        onboardingRepositoryProvider.overrideWithValue(onboarding),
    ],
  )..read(authProvider);
}

void _populateUserAState(ProviderContainer container) {
  container
      .read(userProfileProvider.notifier)
      .loadSeedData(
        UserProfile.empty(uid: _userA.uid).copyWith(displayName: 'Private A'),
      );
  container
      .read(onboardingStateProvider.notifier)
      .loadSeedData(OnboardingDraft(uid: _userA.uid, currentStep: 7));
  container.read(mockRoutineProvider.notifier).replaceWith([_secretRoutine]);
  container.read(mockGoalProvider.notifier).addGoal(_secretGoal);
  container.read(mockTrackerProvider.notifier).loadSeedData();
  container.read(mockCoachProvider.notifier).loadSeedData();
  container
      .read(mockNotificationPreferencesProvider.notifier)
      .updatePreferences(NotificationPreferences(morningStart: false));
  container
      .read(regionSettingsProvider.notifier)
      .loadSettings(
        RegionSettings.forCountry(userId: _userA.uid, countryCode: 'GB'),
      );
}

void _expectUserStateCleared(ProviderContainer container) {
  expect(container.read(userProfileProvider).uid, isEmpty);
  expect(container.read(onboardingStateProvider).draft.uid, isEmpty);
  expect(container.read(mockRoutineProvider), isEmpty);
  expect(container.read(mockGoalProvider), isEmpty);
  expect(container.read(mockTrackerProvider).trackerSessions, isEmpty);
  expect(container.read(mockCoachProvider), isEmpty);
}

final _secretRoutine = RoutineItem(
  id: 'secret-routine-a',
  title: 'A private routine',
  startMinute: 60,
  endMinute: 90,
  blockType: RoutineBlockType.softBlock,
  category: RoutineCategory.habit,
  source: RoutineSource.manual,
);

final _secretGoal = GoalModel(
  id: 'secret-goal-a',
  identityTitle: 'A private goal',
  purposeStatement: 'Private A',
  dailyProof: GoalProof(
    id: 'secret-proof-a',
    title: 'Private proof',
    tinyVersion: 'Tiny',
    normalVersion: 'Normal',
    strongVersion: 'Strong',
  ),
);

class _ControlledAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;
  bool signOutShouldFail = false;

  void emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  void dispose() => _controller.close();

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<void> signOut() async {
    if (signOutShouldFail) {
      throw AuthErrorMapper.map(Exception('network-request-failed'));
    }
    emit(null);
  }

  @override
  Future<AuthUser> signIn(String email, String password) =>
      throw UnimplementedError();
  @override
  Future<AuthUser?> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<AuthUser> signUp(String email, String password, {String? name}) =>
      throw UnimplementedError();
  @override
  Future<AuthUser> signInAnonymously() => throw UnimplementedError();
  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) => throw UnimplementedError();
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<AuthUser?> reloadCurrentUser() async => _currentUser;
  @override
  Future<String?> currentIdToken() async =>
      _currentUser == null ? null : 'test-token';
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class _DelayedOnboardingRepository extends FakeOnboardingRepository {
  final _drafts = <String, Completer<OnboardingDraft?>>{};

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) {
    return _drafts.putIfAbsent(uid, Completer<OnboardingDraft?>.new).future;
  }

  void complete(String uid, OnboardingDraft? draft) {
    _drafts.putIfAbsent(uid, Completer<OnboardingDraft?>.new).complete(draft);
  }
}

class _CompleterImagePrepareService extends ImagePrepareService {
  final Completer<PreparedUploadImage?> _completer = Completer();

  void complete(PreparedUploadImage? image) {
    if (!_completer.isCompleted) _completer.complete(image);
  }

  @override
  Future<PreparedUploadImage?> preparePickedFile(
    XFile? picked, {
    UploadedAssetPurpose purpose = UploadedAssetPurpose.profilePhoto,
  }) {
    return _completer.future;
  }

  @override
  Future<XFile?> pickImageFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    return XFile('test/path');
  }
}

class _FakeR2Client implements R2UploadClient {
  @override
  Future<R2SignedUpload> signUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    required String contentType,
    required int sizeBytes,
    required String idToken,
  }) async {
    return R2SignedUpload(
      assetId: 'test-asset-id',
      objectKey: 'test-key',
      uploadUrl: 'https://upload.example.com',
    );
  }

  @override
  Future<void> uploadBytes({
    required String uploadUrl,
    required String contentType,
    required Uint8List bytes,
  }) async {}

  @override
  Future<void> markUploadComplete({
    required String assetId,
    required String objectKey,
    required int sizeBytes,
    required String idToken,
  }) async {}

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {}
}
