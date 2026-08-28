import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/profile/providers/profile_navigation_provider.dart';
import 'package:optivus/features/recovery/services/recovery_retry_controller.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/state/auth_state.dart';

class TestFailingAuthRepository extends FakeAuthRepository {
  bool sendVerificationShouldThrow = false;
  bool signOutShouldThrow = false;

  @override
  Future<void> sendEmailVerification() async {
    if (sendVerificationShouldThrow) {
      throw Exception('Network error sending verification email');
    }
    await super.sendEmailVerification();
  }

  @override
  Future<void> signOut() async {
    if (signOutShouldThrow) {
      throw Exception('Network error during sign out');
    }
    await super.signOut();
  }
}

class TestFailingProfileRepository extends FakeProfileRepository {
  bool fetchUserProfileShouldThrow = false;

  @override
  Future<UserProfile?> fetchUserProfile(String uid) async {
    if (fetchUserProfileShouldThrow) {
      throw Exception('Backend fetch failed due to network hiccup');
    }
    return super.fetchUserProfile(uid);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Work Package A - PATH3-14-01: Pre-fetch reset removal', () {
    test(
      'Cached state is retained when backend user restore fails on network hiccup',
      () async {
        final fakeAuth = TestFailingAuthRepository();
        final fakeProfileRepo = TestFailingProfileRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.firebase,
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(authProvider);
        await fakeAuth.signIn('user14@optivus.dev', 'password123');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        fakeProfileRepo.fetchUserProfileShouldThrow = true;
        try {
          await container.read(authProvider.notifier).retryBackendRestore();
        } catch (_) {}

        final authState = container.read(authProvider);
        expect(authState.status, equals(AuthFlowStatus.reconnectRequired));
        expect(authState.user, isNotNull);
      },
    );
  });

  group('Work Package A - PATH3-15-01: Full state purge on logout', () {
    test(
      'Logout cancels RecoveryRetryController timer and purges states',
      () async {
        final fakeAuth = TestFailingAuthRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.fake,
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(authProvider);
        await fakeAuth.signIn('logout-test@optivus.dev', 'password123');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final recoveryController = container.read(
          recoveryRetryControllerProvider.notifier,
        );
        recoveryController.recordAttemptAndStartCooldown();
        expect(
          container.read(recoveryRetryControllerProvider).isCoolingDown,
          isTrue,
        );

        container.read(profileDetailViewRequestProvider.notifier).state =
            const ProfileDetailTarget(view: ProfileDetailView.editProfile);

        fakeAuth.signOutShouldThrow = true;
        try {
          await container.read(authProvider.notifier).logout();
        } catch (_) {}

        expect(
          container.read(authProvider).status,
          equals(AuthFlowStatus.signedOut),
        );
        expect(
          container.read(recoveryRetryControllerProvider).isCoolingDown,
          isFalse,
        );
        expect(
          container.read(recoveryRetryControllerProvider).attemptCount,
          equals(0),
        );
        expect(
          container.read(profileDetailViewRequestProvider).view,
          equals(ProfileDetailView.none),
        );
      },
    );
  });

  group(
    'Work Package A - PATH3-16-01 & FINDING-P1-08: Account switch isolation & status order',
    () {
      test(
        'Account switch sets loadingBackendUser before resetting state when UID changes',
        () async {
          final fakeAuth = FakeAuthRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuth),
              optivusBackendModeProvider.overrideWithValue(
                OptivusBackendMode.fake,
              ),
            ],
          );
          addTearDown(container.dispose);

          container.read(authProvider);
          await fakeAuth.signIn('userA@optivus.dev', 'password123');
          await Future<void>.delayed(const Duration(milliseconds: 100));

          final initialUser = container.read(authProvider).user;
          expect(initialUser?.email, equals('userA@optivus.dev'));

          final statusHistory = <AuthFlowStatus>[];
          container.listen<AuthState>(authProvider, (previous, next) {
            statusHistory.add(next.status);
          });

          await fakeAuth.signIn('userB@optivus.dev', 'password123');
          await Future<void>.delayed(const Duration(milliseconds: 50));

          final newUser = container.read(authProvider).user;
          expect(newUser?.email, equals('userB@optivus.dev'));
          expect(statusHistory, contains(AuthFlowStatus.loadingBackendUser));
        },
      );
    },
  );

  group(
    'Work Package A - FINDING-P1-03: Signup retains user on sendEmailVerification failure',
    () {
      test(
        'Signup retains AuthUser if signUp succeeds even if sendEmailVerification throws',
        () async {
          final fakeAuth = TestFailingAuthRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuth),
              profileRepositoryProvider.overrideWithValue(
                FakeProfileRepository(),
              ),
              optivusBackendModeProvider.overrideWithValue(
                OptivusBackendMode.firebase,
              ),
            ],
          );
          addTearDown(container.dispose);

          fakeAuth.sendVerificationShouldThrow = true;

          try {
            await container
                .read(authProvider.notifier)
                .signup('New User', 'newuser@optivus.dev', 'Password123!');
          } catch (_) {}

          final authState = container.read(authProvider);
          expect(authState.user, isNotNull);
          expect(authState.user?.email, equals('newuser@optivus.dev'));
          expect(
            authState.status,
            equals(AuthFlowStatus.signedInEmailUnverified),
          );
          expect(authState.errorMessage, isNotNull);
        },
      );
    },
  );

  group('Work Package A - PATH3-16-02: Anonymous link flag', () {
    test(
      'linkAnonymousWithEmail completes migration without wiping migrated memory state',
      () async {
        final fakeAuth = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.fake,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authProvider.notifier).signInAnonymously();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final anonUser = container.read(authProvider).user;
        expect(anonUser?.isAnonymous, isTrue);

        await container
            .read(authProvider.notifier)
            .linkAnonymousWithEmail('linked_anon@optivus.dev', 'Password123!');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final linkedState = container.read(authProvider);
        expect(linkedState.user?.email, equals('linked_anon@optivus.dev'));
      },
    );
  });
}
