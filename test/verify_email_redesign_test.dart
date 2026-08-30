import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/views/screens/verify_email_screen.dart';

class _TestAuthRepo implements AuthRepository {
  AuthUser? user;
  bool verificationEmailSent = false;
  int reloadCount = 0;
  int signOutCount = 0;
  bool verifyOnReload = false;
  Object? reloadError;
  Object? resendError;
  Object? signOutError;
  Completer<void>? reloadGate;

  _TestAuthRepo({required this.user});

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  Future<AuthUser> signIn(String email, String password) async => user!;

  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  @override
  Future<AuthUser> signUp(
    String email,
    String password, {
    String? name,
  }) async => user!;

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
    if (resendError case final error?) throw error;
    verificationEmailSent = true;
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    reloadCount++;
    await reloadGate?.future;
    if (reloadError case final error?) throw error;
    if (verifyOnReload && user != null) {
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
  Future<String?> currentIdToken() async => 'fake-token';

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
}) {
  final authState =
      state ??
      const AuthState(
        user: _defaultUser,
        status: AuthFlowStatus.signedInEmailUnverified,
      );
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      authProvider.overrideWith(
        (ref) => _TestAuthNotifier(repo, ref, authState),
      ),
      mockUserProfileProvider.overrideWith(
        (ref) => MockUserProfileNotifier()
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

Future<void> _tapAnimatedButton(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    // Default setup
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
        find.descendant(
          of: cardFinder,
          matching: find.text('SENT TO'),
        ),
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
        find.descendant(
          of: cardFinder,
          matching: find.text('Open your email'),
        ),
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

      // Check verification CTA exists with bounded dimensions
      final checkFinder = find.byKey(const Key('verify-email-check'));
      expect(checkFinder, findsOneWidget);
      expect(find.text('Check verification'), findsOneWidget);
      final checkSize = tester.getSize(checkFinder);
      expect(checkSize.height, inInclusiveRange(54.0, 58.0));
      expect(checkSize.width, lessThanOrEqualTo(340.0));
      expect(checkSize.width, lessThan(393.0)); // Not edge-to-edge

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

  testWidgets('check uses authoritative action and blocks concurrent taps', (
    tester,
  ) async {
    await _setLogicalViewport(tester, logicalSize: const Size(393, 873));
    final gate = Completer<void>();
    final repo = _TestAuthRepo(user: _defaultUser)..reloadGate = gate;
    await tester.pumpWidget(_buildScreen(repo: repo));

    final check = find.byKey(const Key('verify-email-check'));
    await _tapAnimatedButton(tester, check);
    await tester.tap(check);
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.reloadCount, 1);
    expect(find.text('Checking...'), findsOneWidget);
    gate.complete();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(
        'Not verified yet. Tap the link in your email, then try again.',
      ),
      findsOneWidget,
    );
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

    await _tapAnimatedButton(
      tester,
      find.byKey(const Key('verify-email-check')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Couldn\'t check verification. Try again.'),
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

  testWidgets('representative logical viewports render cleanly without overflow', (
    tester,
  ) async {
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
      expect(find.text('Check verification'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

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
    expect(find.text('Check verification'), findsOneWidget);

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
}
