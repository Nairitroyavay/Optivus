import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/verification_lifecycle_state.dart';
import 'package:optivus/views/screens/verify_email_screen.dart';

class _TestAuthRepo implements AuthRepository, AuthProfileEnrichmentRepository {
  AuthUser? user;
  bool verificationEmailSent = false;
  int reloadCount = 0;
  int signOutCount = 0;
  int tokenRefreshCount = 0;
  int verificationEmailSendCount = 0;
  int displayNameUpdateCount = 0;
  bool verifyOnReload = false;
  int? verifyOnReloadNumber;
  Object? reloadError;
  Object? resendError;
  Object? signOutError;
  Completer<void>? reloadGate;
  Completer<void>? resendGate;
  Completer<void>? signupGate;
  Completer<void>? displayNameUpdateGate;
  Object? displayNameUpdateError;
  final authEvents = StreamController<AuthUser?>.broadcast();

  _TestAuthRepo({required this.user});

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get authStateChanges => authEvents.stream;

  @override
  Future<AuthUser> signIn(String email, String password) async => user!;

  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  @override
  Future<AuthUser> signUp(String email, String password, {String? name}) async {
    await signupGate?.future;
    return user!;
  }

  @override
  Future<AuthUser> signInAnonymously() async => user!;

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async => user!;

  @override
  Future<void> sendEmailVerification() async {
    verificationEmailSendCount++;
    await resendGate?.future;
    if (resendError case final error?) throw error;
    verificationEmailSent = true;
  }

  @override
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    displayNameUpdateCount++;
    await displayNameUpdateGate?.future;
    if (displayNameUpdateError case final error?) throw error;
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    reloadCount++;
    await reloadGate?.future;
    if (reloadError case final error?) throw error;
    if ((verifyOnReload || verifyOnReloadNumber == reloadCount) &&
        user != null) {
      user = AuthUser(
        uid: user!.uid,
        email: user!.email,
        displayName: user!.displayName,
        emailVerified: true,
        isAnonymous: user!.isAnonymous,
        providerIds: user!.providerIds,
      );
    }
    return user;
  }

  @override
  Future<String?> currentIdToken() async {
    tokenRefreshCount++;
    return 'fake-token';
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {
    signOutCount++;
    if (signOutError case final error?) throw error;
    user = null;
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, super.ref, AuthState initialState) {
    state = initialState;
  }
}

const _defaultUser = AuthUser(
  uid: 'user-123',
  email: 'testuser@example.com',
  emailVerified: false,
);

Widget _buildScreen({
  required _TestAuthRepo repo,
  AuthState? state,
  TextScaler textScaler = TextScaler.noScaling,
  VerificationLifecyclePolicy policy = const VerificationLifecyclePolicy(),
  DateTime Function()? now,
}) {
  final authState =
      state ??
      const AuthState(
        user: _defaultUser,
        status: AuthFlowStatus.signedInEmailUnverified,
        verificationEmailSendStatus: VerificationEmailSendStatus.sent,
      );
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      authProvider.overrideWith(
        (ref) => _TestAuthNotifier(repo, ref, authState),
      ),
      verificationLifecyclePolicyProvider.overrideWithValue(policy),
      if (now != null) verificationClockProvider.overrideWithValue(now),
      userProfileProvider.overrideWith(
        (ref) => UserProfileNotifier()
          ..loadSeedData(
            UserProfile.empty(
              uid: authState.user?.uid ?? '',
              email: authState.user?.email ?? '',
            ),
          ),
      ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const VerifyEmailScreen(),
    ),
  );
}

Future<void> _setLogicalViewport(
  WidgetTester tester, {
  Size logicalSize = const Size(393, 873),
  double devicePixelRatio = 1.0,
}) async {
  tester.view.physicalSize = Size(
    logicalSize.width * devicePixelRatio,
    logicalSize.height * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(VerifyEmailScreen)),
  );
}

class _MutableClock {
  DateTime value = DateTime(2026, 1, 1, 12);

  DateTime call() => value;

  void advance(Duration duration) => value = value.add(duration);
}

const _fastPollingPolicy = VerificationLifecyclePolicy(
  pollIntervals: [
    Duration(milliseconds: 100),
    Duration(milliseconds: 200),
    Duration(milliseconds: 300),
  ],
);

void main() {
  setUp(() {
    // Default setup
  });

  test('signup records initial verification send only after success', () async {
    final repo = _TestAuthRepo(user: _defaultUser);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        userProfileProvider.overrideWith(
          (ref) => UserProfileNotifier()
            ..loadSeedData(
              UserProfile.empty(
                uid: _defaultUser.uid,
                email: _defaultUser.email ?? '',
              ),
            ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authProvider.notifier)
        .signup('Test User', 'testuser@example.com', 'Password123!');

    final auth = container.read(authProvider);
    expect(auth.status, AuthFlowStatus.signedInEmailUnverified);
    expect(auth.lastVerificationEmailSent, isNotNull);
    expect(auth.verificationEmailSendStatus, VerificationEmailSendStatus.sent);
    expect(repo.verificationEmailSendCount, 1);
  });

  test(
    'signup owns Firebase initial auth event until verification is sent once',
    () async {
      final repo = _TestAuthRepo(user: _defaultUser)
        ..signupGate = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          userProfileProvider.overrideWith(
            (ref) => UserProfileNotifier()
              ..loadSeedData(
                UserProfile.empty(
                  uid: _defaultUser.uid,
                  email: _defaultUser.email ?? '',
                ),
              ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final signup = container
          .read(authProvider.notifier)
          .signup('Test User', 'testuser@example.com', 'Password123!');
      repo.authEvents.add(_defaultUser);
      await Future<void>.delayed(Duration.zero);
      repo.authEvents.add(_defaultUser);
      await Future<void>.delayed(Duration.zero);
      repo.signupGate!.complete();
      await signup;

      expect(repo.verificationEmailSendCount, 1);
      expect(
        container.read(authProvider).verificationEmailSendStatus,
        VerificationEmailSendStatus.sent,
      );
    },
  );

  test(
    'initial verification send completes before a hanging display-name update',
    () async {
      final repo = _TestAuthRepo(user: _defaultUser)
        ..displayNameUpdateGate = Completer<void>();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signup('Test User', 'testuser@example.com', 'Password123!');

      expect(repo.verificationEmailSendCount, 1);
      expect(repo.displayNameUpdateCount, 1);
      expect(
        container.read(authProvider).verificationEmailSendStatus,
        VerificationEmailSendStatus.sent,
      );
    },
  );

  test(
    'display-name failure preserves the completed verification-email flow',
    () async {
      final repo = _TestAuthRepo(user: _defaultUser)
        ..displayNameUpdateError = Exception('profile-update-failed');
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signup('Test User', 'testuser@example.com', 'Password123!');
      await Future<void>.delayed(Duration.zero);

      final auth = container.read(authProvider);
      expect(repo.verificationEmailSendCount, 1);
      expect(repo.displayNameUpdateCount, 1);
      expect(auth.status, AuthFlowStatus.signedInEmailUnverified);
      expect(auth.lastVerificationEmailSent, isNotNull);
      expect(
        auth.verificationEmailSendStatus,
        VerificationEmailSendStatus.sent,
      );
      expect(auth.errorMessage, isNull);
    },
  );

  test(
    'signup ignores stale signed-out auth event and still sends email',
    () async {
      final repo = _TestAuthRepo(user: _defaultUser)
        ..signupGate = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          userProfileProvider.overrideWith(
            (ref) => UserProfileNotifier()
              ..loadSeedData(
                UserProfile.empty(
                  uid: _defaultUser.uid,
                  email: _defaultUser.email ?? '',
                ),
              ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final signup = container
          .read(authProvider.notifier)
          .signup('Test User', 'testuser@example.com', 'Password123!');
      repo.authEvents.add(null);
      await Future<void>.delayed(Duration.zero);
      repo.signupGate!.complete();
      await signup;

      expect(repo.verificationEmailSendCount, 1);
      expect(
        container.read(authProvider).verificationEmailSendStatus,
        VerificationEmailSendStatus.sent,
      );
    },
  );

  test('email verification source instrumentation is debug-only', () {
    final authStateSource = File(
      'lib/state/auth_state.dart',
    ).readAsStringSync();
    final repositorySource = File(
      'lib/repositories/auth_repository.dart',
    ).readAsStringSync();
    final verifyScreenSource = File(
      'lib/views/screens/verify_email_screen.dart',
    ).readAsStringSync();

    expect(authStateSource, contains('[OptivusBuild] commit='));
    expect(authStateSource, contains('stage=before_initial_send'));
    expect(repositorySource, contains('stage=before_firebase_send'));
    expect(repositorySource, contains('stage=firebase_send_success'));
    expect(verifyScreenSource, contains('stage=verify_screen_entered'));
    expect(repositorySource, contains('if (kDebugMode)'));
  });

  test('unrelated UID auth event invalidates an in-flight signup', () async {
    final repo = _TestAuthRepo(user: _defaultUser)
      ..signupGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final signup = container
        .read(authProvider.notifier)
        .signup('Test User', 'testuser@example.com', 'Password123!');
    repo.authEvents.add(
      const AuthUser(
        uid: 'other-user',
        email: 'other@example.com',
        emailVerified: false,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    repo.signupGate!.complete();
    await signup;

    expect(repo.verificationEmailSendCount, 0);
    expect(container.read(authProvider).user?.uid, 'other-user');
  });

  test(
    'failed initial verification send keeps resend immediately available',
    () async {
      final repo = _TestAuthRepo(user: _defaultUser)
        ..resendError = Exception('network-request-failed');
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          userProfileProvider.overrideWith(
            (ref) => UserProfileNotifier()
              ..loadSeedData(
                UserProfile.empty(
                  uid: _defaultUser.uid,
                  email: _defaultUser.email ?? '',
                ),
              ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signup('Test User', 'testuser@example.com', 'Password123!');

      var auth = container.read(authProvider);
      expect(auth.status, AuthFlowStatus.signedInEmailUnverified);
      expect(auth.lastVerificationEmailSent, isNull);
      expect(
        auth.verificationEmailSendStatus,
        VerificationEmailSendStatus.failed,
      );

      repo.resendError = null;
      await container.read(authProvider.notifier).resendEmailVerification();
      auth = container.read(authProvider);
      expect(auth.lastVerificationEmailSent, isNotNull);
      expect(
        auth.verificationEmailSendStatus,
        VerificationEmailSendStatus.sent,
      );
    },
  );

  test('identity switch clears verification send state', () async {
    const nextUser = AuthUser(
      uid: 'user-456',
      email: 'next@example.com',
      emailVerified: false,
    );
    final repo = _TestAuthRepo(user: nextUser);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        userProfileProvider.overrideWith(
          (ref) => UserProfileNotifier()
            ..loadSeedData(
              UserProfile.empty(
                uid: _defaultUser.uid,
                email: _defaultUser.email ?? '',
              ),
            ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authProvider.notifier);
    notifier.state = AuthState(
      user: _defaultUser,
      status: AuthFlowStatus.signedInEmailUnverified,
      lastVerificationEmailSent: DateTime(2026, 1, 1, 12),
      verificationEmailSendStatus: VerificationEmailSendStatus.sent,
    );

    repo.authEvents.add(nextUser);
    await Future<void>.delayed(Duration.zero);

    final auth = container.read(authProvider);
    expect(auth.user, nextUser);
    expect(auth.status, AuthFlowStatus.signedInEmailUnverified);
    expect(auth.lastVerificationEmailSent, isNull);
    expect(
      auth.verificationEmailSendStatus,
      VerificationEmailSendStatus.pending,
    );
  });

  testWidgets(
    'renders single primary verification card, identity, steps, and bounded CTA',
    (tester) async {
      await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
      final repo = _TestAuthRepo(user: _defaultUser);
      await tester.pumpWidget(_buildScreen(repo: repo));
      await tester.pump();

      // Top title and copy
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('We sent you a verification link'), findsOneWidget);

      // Exactly ONE primary verification card
      final cardFinder = find.byKey(const Key('verify-email-card'));
      expect(cardFinder, findsOneWidget);

      // Identity inside verification card
      expect(
        find.descendant(of: cardFinder, matching: find.text('SENT TO')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('testuser@example.com'),
        ),
        findsOneWidget,
      );

      // Step 1 inside card
      expect(
        find.descendant(of: cardFinder, matching: find.text('Open your email')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('Tap the verification link we sent.'),
        ),
        findsOneWidget,
      );

      // Step 2 inside card
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('Return to Optivus'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('We\'ll check it automatically.'),
        ),
        findsOneWidget,
      );

      // Passive waiting status inside card
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('Waiting for verification'),
        ),
        findsOneWidget,
      );

      expect(find.byKey(const Key('verify-email-check')), findsNothing);
      expect(find.text('Check verification'), findsNothing);

      // Compact resend line
      expect(find.text('Didn\'t get it?'), findsOneWidget);
      expect(find.text('Resend email'), findsOneWidget);

      // Tertiary actions
      expect(find.text('Use another email'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);

      // No permanent spam / promotions sentence in primary hierarchy
      expect(
        find.text('Didn\'t receive it? Check Spam or Promotions.'),
        findsNothing,
      );

      // No uncaught exceptions
      expect(tester.takeException(), isNull);

      // Fits on common Android screen without scrolling
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('verify-email-scroll-view')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, 0);
    },
  );

  testWidgets(
    'pending initial send does not claim verification link was sent',
    (tester) async {
      await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
      final repo = _TestAuthRepo(user: _defaultUser);
      await tester.pumpWidget(
        _buildScreen(
          repo: repo,
          state: const AuthState(
            user: _defaultUser,
            status: AuthFlowStatus.signedInEmailUnverified,
            verificationEmailSendStatus: VerificationEmailSendStatus.pending,
          ),
        ),
      );

      expect(find.text('Sending your verification link...'), findsOneWidget);
      expect(find.text('We sent you a verification link'), findsNothing);
      await tester.pump();
      expect(repo.reloadCount, 0);
    },
  );

  testWidgets('removes mail launcher UI, failure copy, and old action label', (
    tester,
  ) async {
    await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
    final repo = _TestAuthRepo(user: _defaultUser);
    await tester.pumpWidget(_buildScreen(repo: repo));

    expect(find.text('Open email'), findsNothing);
    expect(find.text('Open inbox'), findsNothing);
    expect(find.textContaining('couldn\'t open an email app'), findsNothing);
    expect(find.text('I\'ve verified'), findsNothing);
    expect(find.text('I’ve verified'), findsNothing);
  });

  testWidgets('automatic check uses authoritative action and coalesces', (
    tester,
  ) async {
    await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
    final gate = Completer<void>();
    final repo = _TestAuthRepo(user: _defaultUser)..reloadGate = gate;
    await tester.pumpWidget(_buildScreen(repo: repo));
    await tester.pump();
    final controller = _container(
      tester,
    ).read(verificationLifecycleProvider.notifier);

    controller.checkNow();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.reloadCount, 1);
    expect(
      _container(tester).read(verificationLifecycleProvider).checking,
      isTrue,
    );
    gate.complete();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Waiting for verification'), findsOneWidget);
    expect(find.textContaining('invalid'), findsNothing);
  });

  testWidgets('check failure is compact and keeps message region stable', (
    tester,
  ) async {
    await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
    final repo = _TestAuthRepo(user: _defaultUser)
      ..reloadError = Exception('internal-firebase-detail');
    await tester.pumpWidget(_buildScreen(repo: repo));
    final before = tester.getTopLeft(
      find.byKey(const Key('verify-email-message-region')),
    );

    await _container(
      tester,
    ).read(verificationLifecycleProvider.notifier).checkNow();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Couldn\'t check verification. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('firebase'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('verify-email-message-region'))),
      before,
    );
  });

  testWidgets(
    'resend preserves ready, progress, temporary helper, and cooldown states',
    (tester) async {
      await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
      final repo = _TestAuthRepo(user: _defaultUser);
      await tester.pumpWidget(_buildScreen(repo: repo));
      expect(find.text('Resend email'), findsOneWidget);

      final resend = find.text('Resend email');
      await tester.ensureVisible(resend);
      await tester.tap(resend);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(repo.verificationEmailSent, isTrue);
      expect(
        find.text(
          'Sent again. Check Spam or Promotions if it doesn\'t arrive.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Resend available in'), findsOneWidget);
    },
  );

  testWidgets('existing cooldown renders in its reserved action region', (
    tester,
  ) async {
    await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
    final repo = _TestAuthRepo(user: _defaultUser);
    await tester.pumpWidget(
      _buildScreen(
        repo: repo,
        state: AuthState(
          user: _defaultUser,
          status: AuthFlowStatus.signedInEmailUnverified,
          lastVerificationEmailSent: DateTime.now().subtract(
            const Duration(seconds: 18),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Resend available in'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('verify-email-resend'))).height,
      greaterThanOrEqualTo(36),
    );
  });

  testWidgets('use another email and sign out both use transactional logout', (
    tester,
  ) async {
    await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
    for (final key in const [
      Key('verify-email-use-another'),
      Key('verify-email-sign-out'),
    ]) {
      final repo = _TestAuthRepo(user: _defaultUser);
      await tester.pumpWidget(_buildScreen(repo: repo));
      final action = find.byKey(key);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump();
      expect(repo.signOutCount, 1);
      expect(repo.currentUser, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'failed logout retains verified-route identity and shows safe error',
    (tester) async {
      await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
      final repo = _TestAuthRepo(user: _defaultUser)
        ..signOutError = Exception('firebase-raw-signout-detail');
      await tester.pumpWidget(_buildScreen(repo: repo));
      final signOut = find.byKey(const Key('verify-email-sign-out'));
      await tester.ensureVisible(signOut);
      await tester.tap(signOut);
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.currentUser, same(_defaultUser));
      expect(find.text('Verify your email'), findsOneWidget);
      expect(
        find.text('Couldn\'t sign out. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('raw-signout'), findsNothing);
    },
  );

  testWidgets('visual and Android back cannot bypass verification', (
    tester,
  ) async {
    await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
    final repo = _TestAuthRepo(user: _defaultUser);
    await tester.pumpWidget(_buildScreen(repo: repo));

    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Verify your email'), findsOneWidget);
    expect(repo.currentUser, same(_defaultUser));
  });

  testWidgets(
    'representative logical viewports render cleanly without overflow',
    (tester) async {
      for (final logicalSize in const [
        Size(360, 800), // compact Android
        Size(393, 873), // common Android / RMX2001 logical equivalent
        Size(412, 915), // larger Android
      ]) {
        await _setLogicalViewport(tester, logicalSize: logicalSize);
        final repo = _TestAuthRepo(user: _defaultUser);
        await tester.pumpWidget(_buildScreen(repo: repo));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Verify your email'), findsOneWidget);
        expect(find.byKey(const Key('verify-email-card')), findsOneWidget);
        expect(find.text('Check verification'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('long email, missing email, and large text remain usable', (
    tester,
  ) async {
    await _setLogicalViewport(tester, logicalSize: const Size(360, 800));
    const longUser = AuthUser(
      uid: 'long-email-user',
      email:
          'a.very.long.production.account.identity.for.mobile.testing@example-long-domain.com',
      emailVerified: false,
    );
    final repo = _TestAuthRepo(user: longUser);
    await tester.pumpWidget(
      _buildScreen(
        repo: repo,
        state: const AuthState(
          user: longUser,
          status: AuthFlowStatus.signedInEmailUnverified,
        ),
        textScaler: const TextScaler.linear(1.5),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text(longUser.email!), findsOneWidget);
    expect(find.text('Check verification'), findsNothing);

    const missingEmailUser = AuthUser(
      uid: 'missing-email-user',
      emailVerified: false,
    );
    final missingRepo = _TestAuthRepo(user: missingEmailUser);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _buildScreen(
        repo: missingRepo,
        state: const AuthState(
          user: missingEmailUser,
          status: AuthFlowStatus.signedInEmailUnverified,
        ),
      ),
    );
    expect(find.text('Email address unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'foreground polling pauses, resumes immediately, and stays single',
    (tester) async {
      await _setLogicalViewport(tester);
      final repo = _TestAuthRepo(user: _defaultUser);
      await tester.pumpWidget(
        _buildScreen(repo: repo, policy: _fastPollingPolicy),
      );
      await tester.pump();
      expect(repo.reloadCount, 1);
      expect(repo.verificationEmailSendCount, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(repo.reloadCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(repo.reloadCount, 2);
      expect(repo.verificationEmailSendCount, 0);
      await tester.pump(const Duration(milliseconds: 110));
      expect(repo.reloadCount, 3);

      for (var cycle = 0; cycle < 3; cycle++) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      }
      expect(repo.reloadCount, 6);
      await tester.pump(const Duration(milliseconds: 110));
      expect(repo.reloadCount, 7);
    },
  );

  testWidgets(
    'resume during an old check queues one fresh follow-up without concurrent reloads',
    (tester) async {
      await _setLogicalViewport(tester);
      final firstReload = Completer<void>();
      final repo = _TestAuthRepo(user: _defaultUser)..reloadGate = firstReload;
      await tester.pumpWidget(
        _buildScreen(repo: repo, policy: _fastPollingPolicy),
      );
      await tester.pump();
      expect(repo.reloadCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(repo.reloadCount, 1);

      repo
        ..reloadGate = null
        ..verifyOnReloadNumber = 2;
      firstReload.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.reloadCount, 2);
      expect(repo.tokenRefreshCount, 1);
      expect(
        _container(
          tester,
        ).read(verificationLifecycleProvider).verificationConfirmed,
        isTrue,
      );
    },
  );

  testWidgets(
    'verified reload refreshes token once and uses destination pipeline',
    (tester) async {
      await _setLogicalViewport(tester);
      final repo = _TestAuthRepo(user: _defaultUser)..verifyOnReload = true;
      await tester.pumpWidget(_buildScreen(repo: repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final auth = _container(tester).read(authProvider);
      expect(repo.reloadCount, 1);
      expect(repo.tokenRefreshCount, 1);
      expect(auth.user?.uid, _defaultUser.uid);
      expect(auth.user?.emailVerified, isTrue);
      expect(
        auth.sessionDestination.kind,
        isNot(SessionDestinationKind.verifyEmail),
      );
      await tester.pump(const Duration(seconds: 31));
      expect(repo.reloadCount, 1);
    },
  );

  testWidgets('automatic and manual checks share one in-flight success', (
    tester,
  ) async {
    await _setLogicalViewport(tester);
    final gate = Completer<void>();
    final repo = _TestAuthRepo(user: _defaultUser)
      ..reloadGate = gate
      ..verifyOnReload = true;
    await tester.pumpWidget(_buildScreen(repo: repo));
    await tester.pump();
    final controller = _container(
      tester,
    ).read(verificationLifecycleProvider.notifier);

    controller.checkNow(manual: true);
    controller.checkNow(manual: true);
    expect(repo.reloadCount, 1);
    gate.complete();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repo.tokenRefreshCount, 1);
    expect(
      _container(
        tester,
      ).read(verificationLifecycleProvider).verificationConfirmed,
      isTrue,
    );
  });

  testWidgets(
    'failed initial send does not claim success or start resend cooldown',
    (tester) async {
      await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
      final repo = _TestAuthRepo(user: _defaultUser);
      await tester.pumpWidget(
        _buildScreen(
          repo: repo,
          state: const AuthState(
            user: _defaultUser,
            status: AuthFlowStatus.signedInEmailUnverified,
            error: RecoverableError(
              category: RecoverableErrorCategory.authentication,
              publicMessage:
                  'We couldn\'t send the verification email. Please resend it.',
              severity: RecoverableErrorSeverity.error,
              isBlocking: true,
              retryAction: RecoverableRetryAction.retry,
              retrySafe: true,
              diagnosticCode: DiagnosticCodes.verifyEmailResendFailed,
            ),
            verificationEmailSendStatus: VerificationEmailSendStatus.failed,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('We sent you a verification link'), findsNothing);
      expect(
        find.text('We couldn\'t send the verification link'),
        findsOneWidget,
      );
      expect(
        find.text(
          'We couldn\'t send the verification email. Please resend it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Resend email'), findsOneWidget);
      expect(find.textContaining('Resend available in'), findsNothing);
    },
  );

  testWidgets(
    'resend is deduplicated and deadline accounts for background time',
    (tester) async {
      await _setLogicalViewport(tester);
      final clock = _MutableClock();
      final gate = Completer<void>();
      final repo = _TestAuthRepo(user: _defaultUser)..resendGate = gate;
      await tester.pumpWidget(_buildScreen(repo: repo, now: clock.call));
      await tester.pump();
      final controller = _container(
        tester,
      ).read(verificationLifecycleProvider.notifier);

      controller.resend();
      controller.resend();
      expect(repo.verificationEmailSendCount, 1);
      gate.complete();
      await tester.pump();
      expect(
        _container(
          tester,
        ).read(verificationLifecycleProvider).resendSecondsRemaining,
        60,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      clock.advance(const Duration(seconds: 55));
      await tester.pump(const Duration(seconds: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        _container(
          tester,
        ).read(verificationLifecycleProvider).resendSecondsRemaining,
        5,
      );
      expect(repo.verificationEmailSendCount, 1);
    },
  );

  testWidgets('resend distinguishes network and escalating capped throttles', (
    tester,
  ) async {
    await _setLogicalViewport(tester);
    final clock = _MutableClock();
    final repo = _TestAuthRepo(user: _defaultUser)
      ..resendError = Exception('network-request-failed');
    await tester.pumpWidget(_buildScreen(repo: repo, now: clock.call));
    await tester.pump();
    final container = _container(tester);
    final controller = container.read(verificationLifecycleProvider.notifier);

    await controller.resend();
    expect(
      container.read(verificationLifecycleProvider).messageKind,
      VerificationMessageKind.network,
    );
    expect(
      container.read(verificationLifecycleProvider).message,
      contains('connection'),
    );

    repo.resendError = Exception('too-many-requests');
    const expected = [120, 240, 480, 900, 900];
    for (var index = 0; index < expected.length; index++) {
      await controller.resend();
      final lifecycle = container.read(verificationLifecycleProvider);
      expect(lifecycle.resendThrottleStreak, index + 1);
      expect(lifecycle.resendSecondsRemaining, expected[index]);
      expect(lifecycle.messageKind, VerificationMessageKind.rateLimited);
      clock.advance(Duration(seconds: expected[index]));
      await tester.pump(const Duration(seconds: 1));
    }

    repo.resendError = null;
    await controller.resend();
    final recovered = container.read(verificationLifecycleProvider);
    expect(recovered.resendThrottleStreak, 0);
    expect(recovered.resendSecondsRemaining, 60);
  });

  testWidgets('check errors distinguish network, rate limit, and unknown', (
    tester,
  ) async {
    await _setLogicalViewport(tester);
    final clock = _MutableClock();
    final repo = _TestAuthRepo(user: _defaultUser)
      ..reloadError = Exception('network-request-failed');
    await tester.pumpWidget(_buildScreen(repo: repo, now: clock.call));
    await tester.pump();
    var lifecycle = _container(tester).read(verificationLifecycleProvider);
    expect(lifecycle.messageKind, VerificationMessageKind.network);
    expect(lifecycle.message, contains('connection'));

    repo.reloadError = Exception('too-many-requests');
    await _container(
      tester,
    ).read(verificationLifecycleProvider.notifier).checkNow(manual: true);
    lifecycle = _container(tester).read(verificationLifecycleProvider);
    expect(lifecycle.messageKind, VerificationMessageKind.rateLimited);
    expect(lifecycle.verificationThrottleStreak, 1);

    clock.advance(const Duration(seconds: 120));
    repo.reloadError = Exception('firebase-internal-secret');
    await _container(
      tester,
    ).read(verificationLifecycleProvider.notifier).checkNow(manual: true);
    lifecycle = _container(tester).read(verificationLifecycleProvider);
    expect(lifecycle.messageKind, VerificationMessageKind.firebaseFailure);
    expect(lifecycle.message, isNot(contains('secret')));
  });

  testWidgets('UID switch and disposal ignore late verification results', (
    tester,
  ) async {
    await _setLogicalViewport(tester);
    final gate = Completer<void>();
    final repo = _TestAuthRepo(user: _defaultUser)..reloadGate = gate;
    await tester.pumpWidget(_buildScreen(repo: repo));
    await tester.pump();

    const userB = AuthUser(
      uid: 'user-b',
      email: 'b@example.com',
      emailVerified: false,
    );
    repo.user = userB;
    repo.authEvents.add(userB);
    await tester.pump();
    gate.complete();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_container(tester).read(authProvider).user?.uid, userB.uid);
    expect(repo.tokenRefreshCount, 0);

    final disposeGate = Completer<void>();
    final disposeRepo = _TestAuthRepo(user: _defaultUser)
      ..reloadGate = disposeGate;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_buildScreen(repo: disposeRepo));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    disposeGate.complete();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('same UID refresh preserves the active verification session', (
    tester,
  ) async {
    await _setLogicalViewport(tester);
    final gate = Completer<void>();
    final repo = _TestAuthRepo(user: _defaultUser)..reloadGate = gate;
    await tester.pumpWidget(_buildScreen(repo: repo));
    await tester.pump();

    repo.authEvents.add(
      const AuthUser(
        uid: 'user-123',
        email: 'refreshed@example.com',
        emailVerified: false,
      ),
    );
    await tester.pump();
    expect(
      _container(tester).read(verificationLifecycleProvider).foreground,
      isTrue,
    );
    gate.complete();
    await tester.pump();
    expect(repo.reloadCount, 1);
  });

  testWidgets(
    'sign-out during reload ignores late verification result safely',
    (tester) async {
      await _setLogicalViewport(tester);
      final gate = Completer<void>();
      final repo = _TestAuthRepo(user: _defaultUser)
        ..reloadGate = gate
        ..verifyOnReload = true;
      await tester.pumpWidget(_buildScreen(repo: repo));
      await tester.pump();

      final authNotifier = _container(tester).read(authProvider.notifier);
      await authNotifier.logout();
      await tester.pump();

      expect(_container(tester).read(authProvider).isSignedOut, isTrue);
      gate.complete();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.tokenRefreshCount, 0);
      expect(_container(tester).read(authProvider).isSignedOut, isTrue);
    },
  );
}
