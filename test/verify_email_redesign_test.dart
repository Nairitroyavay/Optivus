import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/services/native/email_launcher_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/views/screens/verify_email_screen.dart';
import 'package:optivus/widgets/auth_back_button.dart';

class _FakeEmailLauncherService implements EmailLauncherService {
  bool shouldSucceed = true;
  int openEmailCallCount = 0;

  @override
  Future<bool> openEmailApp() async {
    openEmailCallCount++;
    return shouldSucceed;
  }
}

class _TestAuthRepo implements AuthRepository {
  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  AuthUser? user;
  bool verificationEmailSent = false;
  int reloadCount = 0;
  bool shouldVerifyOnReload = false;
  Exception? reloadException;
  Exception? resendException;

  _TestAuthRepo({required this.user});

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(user);

  @override
  Future<AuthUser> signIn(String email, String password) async => user!;

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
    if (resendException != null) throw resendException!;
    verificationEmailSent = true;
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    reloadCount++;
    if (reloadException != null) throw reloadException!;
    if (shouldVerifyOnReload && user != null) {
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
    user = null;
  }
}

Future<void> _setRealmeView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, super.ref, AuthState initialState) {
    state = initialState;
  }
}

Widget _buildTestScreen({
  required AuthState authState,
  required AuthRepository repo,
  required EmailLauncherService emailLauncher,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      authProvider.overrideWith(
        (ref) => _TestAuthNotifier(repo, ref, authState),
      ),
      emailLauncherServiceProvider.overrideWithValue(emailLauncher),
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
    child: const MaterialApp(home: VerifyEmailScreen()),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
    'VerifyEmailScreen fits Realme 6 viewport and displays simplified hierarchy',
    (tester) async {
      await _setRealmeView(tester);

      final user = const AuthUser(
        uid: 'user-123',
        email: 'testuser@example.com',
        emailVerified: false,
      );
      final repo = _TestAuthRepo(user: user);
      final launcher = _FakeEmailLauncherService();

      await tester.pumpWidget(
        _buildTestScreen(
          authState: AuthState(
            user: user,
            status: AuthFlowStatus.signedInEmailUnverified,
          ),
          repo: repo,
          emailLauncher: launcher,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Canonical Back Button
      expect(find.byType(AuthBackButton), findsOneWidget);

      // Hero Elements
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('We sent a verification link to:'), findsOneWidget);
      expect(find.text('testuser@example.com'), findsOneWidget);
      expect(
        find.text(
          'Check your inbox and tap the link.\nWe’ll continue automatically when you return.',
        ),
        findsOneWidget,
      );

      // Action Hierarchy
      expect(
        find.byKey(const Key('verify-email-open-email')),
        findsOneWidget,
      ); // Primary
      expect(
        find.byKey(const Key('verify-email-resend')),
        findsOneWidget,
      ); // Secondary
      expect(
        find.byKey(const Key('verify-email-manual-check')),
        findsOneWidget,
      ); // Fallback
      expect(
        find.text('Didn’t receive it? Check Spam or Promotions.'),
        findsOneWidget,
      ); // Help
      expect(
        find.byKey(const Key('verify-email-use-another')),
        findsOneWidget,
      ); // Tertiary
      expect(
        find.byKey(const Key('verify-email-sign-out')),
        findsOneWidget,
      ); // Lowest emphasis

      // Verify no duplicate actions
      expect(find.text('Use another email'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);

      // Verify no obsolete large troubleshooting cards or old duplicate buttons
      expect(find.text('Try another email'), findsNothing);
      expect(find.text('Log out'), findsNothing);
      expect(find.text('Make sure the email address is correct'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Open email action dispatches to platform EmailLauncherService and handles failure gracefully',
    (tester) async {
      final user = const AuthUser(
        uid: 'user-123',
        email: 'test@example.com',
        emailVerified: false,
      );
      final repo = _TestAuthRepo(user: user);
      final launcher = _FakeEmailLauncherService()..shouldSucceed = false;

      await tester.pumpWidget(
        _buildTestScreen(
          authState: AuthState(
            user: user,
            status: AuthFlowStatus.signedInEmailUnverified,
          ),
          repo: repo,
          emailLauncher: launcher,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final openBtn = find.byKey(const Key('verify-email-open-email'));
      await tester.tap(openBtn);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(launcher.openEmailCallCount, 1);
      // Fallback message shown when opening fails
      expect(
        find.text(
          'We couldn’t open an email app. Open your inbox manually, then return here.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Resend button enforces cooldown and shows contained progress and success',
    (tester) async {
      final user = const AuthUser(
        uid: 'user-123',
        email: 'test@example.com',
        emailVerified: false,
      );
      final repo = _TestAuthRepo(user: user);
      final launcher = _FakeEmailLauncherService();

      await tester.pumpWidget(
        _buildTestScreen(
          authState: AuthState(
            user: user,
            status: AuthFlowStatus.signedInEmailUnverified,
          ),
          repo: repo,
          emailLauncher: launcher,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final resendBtn = find.byKey(const Key('verify-email-resend'));
      expect(find.text('Resend email'), findsOneWidget);

      await tester.tap(resendBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.verificationEmailSent, isTrue);
      expect(
        find.text('Verification email sent. Check your inbox.'),
        findsOneWidget,
      );
      expect(find.textContaining('Resend in'), findsOneWidget);
    },
  );

  testWidgets(
    'Manual check "I’ve verified" does not fake verification if server reports unverified',
    (tester) async {
      final user = const AuthUser(
        uid: 'user-123',
        email: 'test@example.com',
        emailVerified: false,
      );
      final repo = _TestAuthRepo(user: user)..shouldVerifyOnReload = false;
      final launcher = _FakeEmailLauncherService();

      await tester.pumpWidget(
        _buildTestScreen(
          authState: AuthState(
            user: user,
            status: AuthFlowStatus.signedInEmailUnverified,
          ),
          repo: repo,
          emailLauncher: launcher,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final manualCheckBtn = find.byKey(const Key('verify-email-manual-check'));
      await tester.tap(manualCheckBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.reloadCount, 1);
      expect(
        find.text(
          'We couldn’t confirm it yet. Tap the link in your email, then try again.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Automatic check on AppLifecycleState.resumed triggers verification check and shows success if verified',
    (tester) async {
      final user = const AuthUser(
        uid: 'user-123',
        email: 'test@example.com',
        emailVerified: false,
      );
      final repo = _TestAuthRepo(user: user)..shouldVerifyOnReload = true;
      final launcher = _FakeEmailLauncherService();

      await tester.pumpWidget(
        _buildTestScreen(
          authState: AuthState(
            user: user,
            status: AuthFlowStatus.signedInEmailUnverified,
          ),
          repo: repo,
          emailLauncher: launcher,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Simulate app backgrounding and resuming
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.reloadCount, 1);
      expect(find.text('Email verified ✓'), findsOneWidget);
    },
  );

  testWidgets(
    'Back button opens confirmation dialog and does not silently sign out on cancel',
    (tester) async {
      final user = const AuthUser(
        uid: 'user-123',
        email: 'test@example.com',
        emailVerified: false,
      );
      final repo = _TestAuthRepo(user: user);
      final launcher = _FakeEmailLauncherService();

      await tester.pumpWidget(
        _buildTestScreen(
          authState: AuthState(
            user: user,
            status: AuthFlowStatus.signedInEmailUnverified,
          ),
          repo: repo,
          emailLauncher: launcher,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final backButton = find.byType(AuthBackButton);
      await tester.tap(backButton);
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog is displayed
      expect(find.text('Leave verification?'), findsOneWidget);
      expect(find.text('Stay here'), findsOneWidget);

      // Cancel leaves user on the screen
      await tester.tap(find.text('Stay here'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Leave verification?'), findsNothing);
      expect(find.text('Verify your email'), findsOneWidget);
    },
  );

  testWidgets('Back button dialog "Sign out" triggers sign out', (
    tester,
  ) async {
    final user = const AuthUser(
      uid: 'user-123',
      email: 'test@example.com',
      emailVerified: false,
    );
    final repo = _TestAuthRepo(user: user);
    final launcher = _FakeEmailLauncherService();

    await tester.pumpWidget(
      _buildTestScreen(
        authState: AuthState(
          user: user,
          status: AuthFlowStatus.signedInEmailUnverified,
        ),
        repo: repo,
        emailLauncher: launcher,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final backButton = find.byType(AuthBackButton);
    await tester.tap(backButton);
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Sign out button inside dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign out'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.currentUser, isNull);
  });

  testWidgets('Tertiary "Use another email" triggers sign out', (tester) async {
    final user = const AuthUser(
      uid: 'user-123',
      email: 'test@example.com',
      emailVerified: false,
    );
    final repo = _TestAuthRepo(user: user);
    final launcher = _FakeEmailLauncherService();

    await tester.pumpWidget(
      _buildTestScreen(
        authState: AuthState(
          user: user,
          status: AuthFlowStatus.signedInEmailUnverified,
        ),
        repo: repo,
        emailLauncher: launcher,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('verify-email-use-another')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.currentUser, isNull);
  });

  testWidgets(
    'Friendly error mapping presents clean message on resend failure without raw exception details',
    (tester) async {
      final user = const AuthUser(
        uid: 'user-123',
        email: 'test@example.com',
        emailVerified: false,
      );
      final repo = _TestAuthRepo(user: user)
        ..resendException = Exception('network-request-failed');
      final launcher = _FakeEmailLauncherService();

      await tester.pumpWidget(
        _buildTestScreen(
          authState: AuthState(
            user: user,
            status: AuthFlowStatus.signedInEmailUnverified,
          ),
          repo: repo,
          emailLauncher: launcher,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('verify-email-resend')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Network error. Check your connection and retry.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Exception: network-request-failed'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Resend cooldown reconciles remaining time from lastVerificationEmailSent on mount',
    (tester) async {
      final user = const AuthUser(
        uid: 'user-123',
        email: 'test@example.com',
        emailVerified: false,
      );
      final repo = _TestAuthRepo(user: user);
      final launcher = _FakeEmailLauncherService();

      // Email was sent 20 seconds ago -> 40 seconds remaining
      final lastSent = DateTime.now().subtract(const Duration(seconds: 20));

      await tester.pumpWidget(
        _buildTestScreen(
          authState: AuthState(
            user: user,
            status: AuthFlowStatus.signedInEmailUnverified,
            lastVerificationEmailSent: lastSent,
          ),
          repo: repo,
          emailLauncher: launcher,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Resend in'), findsOneWidget);
    },
  );
}
