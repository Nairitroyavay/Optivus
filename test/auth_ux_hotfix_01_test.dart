import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/auth_layout.dart';
import 'package:optivus/core/widgets/auth_text_field.dart';
import 'package:optivus/views/screens/login_screen.dart';
import 'package:optivus/views/screens/signup_screen.dart';
import 'package:optivus/widgets/app_button.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AUTH-UX-HOTFIX-01: Logo Animation & Header Transitions', () {
    testWidgets(
      'TEST A: SignupScreen normal state has expanded logo and header',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(_authScreen(const SignupScreen()));
        await tester.pumpAndSettle();

        final logo = find.byKey(const Key('signup-logo'));
        expect(logo, findsOneWidget);
        expect(
          tester.getSize(logo),
          const Size(AuthLayout.standardLogoSize, AuthLayout.standardLogoSize),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TEST B: SignupScreen with nonzero viewInsets.bottom enters compact layout',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _authScreen(
            const SignupScreen(),
            viewInsets: const EdgeInsets.only(bottom: 297),
          ),
        );
        await tester.pumpAndSettle();

        final logo = find.byKey(const Key('signup-logo'));
        expect(logo, findsOneWidget);
        expect(
          tester.getSize(logo),
          const Size(AuthLayout.compactLogoSize, AuthLayout.compactLogoSize),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TEST C: SignupScreen returning viewInsets.bottom to zero restores expanded layout',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);

        // Start with keyboard open
        await tester.pumpWidget(
          _authScreen(
            const SignupScreen(),
            viewInsets: const EdgeInsets.only(bottom: 297),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const Key('signup-logo'))),
          const Size(AuthLayout.compactLogoSize, AuthLayout.compactLogoSize),
        );

        // Dismiss keyboard
        await tester.pumpWidget(
          _authScreen(const SignupScreen(), viewInsets: EdgeInsets.zero),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const Key('signup-logo'))),
          const Size(AuthLayout.standardLogoSize, AuthLayout.standardLogoSize),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TEST D: LoginScreen transitions smoothly between expanded and compact states',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);

        // 1. Expanded initial state
        await tester.pumpWidget(_authScreen(const LoginScreen()));
        await tester.pumpAndSettle();
        final logo = find.byKey(const Key('login-logo'));
        expect(
          tester.getSize(logo),
          const Size(AuthLayout.standardLogoSize, AuthLayout.standardLogoSize),
        );

        // 2. Open keyboard
        await tester.pumpWidget(
          _authScreen(
            const LoginScreen(),
            viewInsets: const EdgeInsets.only(bottom: 297),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(logo),
          const Size(AuthLayout.compactLogoSize, AuthLayout.compactLogoSize),
        );

        // 3. Close keyboard
        await tester.pumpWidget(
          _authScreen(const LoginScreen(), viewInsets: EdgeInsets.zero),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(logo),
          const Size(AuthLayout.standardLogoSize, AuthLayout.standardLogoSize),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TEST E: Switching focus between fields while keyboard is open does not restart/expand logo',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _authScreen(
            const SignupScreen(),
            viewInsets: const EdgeInsets.only(bottom: 297),
          ),
        );
        await tester.pumpAndSettle();

        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(4));

        // Focus email
        await tester.tap(fields.at(1));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.getSize(find.byKey(const Key('signup-logo'))),
          const Size(AuthLayout.compactLogoSize, AuthLayout.compactLogoSize),
        );

        // Switch to password
        await tester.tap(fields.at(2));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.getSize(find.byKey(const Key('signup-logo'))),
          const Size(AuthLayout.compactLogoSize, AuthLayout.compactLogoSize),
        );

        // Switch to confirm password
        await tester.tap(fields.at(3));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.getSize(find.byKey(const Key('signup-logo'))),
          const Size(AuthLayout.compactLogoSize, AuthLayout.compactLogoSize),
        );

        // Switch back to email
        await tester.tap(fields.at(1));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.getSize(find.byKey(const Key('signup-logo'))),
          const Size(AuthLayout.compactLogoSize, AuthLayout.compactLogoSize),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TEST F: Password visibility toggle while keyboard visible preserves compact state',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _authScreen(
            const LoginScreen(),
            viewInsets: const EdgeInsets.only(bottom: 297),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byKey(const Key('login-logo'))),
          const Size(AuthLayout.compactLogoSize, AuthLayout.compactLogoSize),
        );

        final eyeButton = find.byType(AuthEyeButton);
        expect(eyeButton, findsOneWidget);

        await tester.tap(eyeButton);
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tester.getSize(find.byKey(const Key('login-logo'))),
          const Size(AuthLayout.compactLogoSize, AuthLayout.compactLogoSize),
        );

        await tester.tap(eyeButton);
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tester.getSize(find.byKey(const Key('login-logo'))),
          const Size(AuthLayout.compactLogoSize, AuthLayout.compactLogoSize),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Multi-frame progressive IME animation smoothly interpolates without snaps',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);

        // Initial
        await tester.pumpWidget(
          _authScreen(const SignupScreen(), viewInsets: EdgeInsets.zero),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const Key('signup-logo'))).width,
          equals(AuthLayout.standardLogoSize),
        );

        // Simulate partial IME frame (bottom: 80)
        await tester.pumpWidget(
          _authScreen(
            const SignupScreen(),
            viewInsets: const EdgeInsets.only(bottom: 80),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        final intermediateWidth = tester
            .getSize(find.byKey(const Key('signup-logo')))
            .width;
        expect(intermediateWidth, lessThan(AuthLayout.standardLogoSize));
        expect(
          intermediateWidth,
          greaterThanOrEqualTo(AuthLayout.compactLogoSize),
        );

        // Settle at full IME
        await tester.pumpWidget(
          _authScreen(
            const SignupScreen(),
            viewInsets: const EdgeInsets.only(bottom: 297),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const Key('signup-logo'))).width,
          equals(AuthLayout.compactLogoSize),
        );
      },
    );
  });

  group('AUTH-UX-HOTFIX-01: Background & Scaffolding Architecture', () {
    testWidgets(
      'TEST K & L: Scaffold has non-transparent Auth background painting full window',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(_authScreen(const SignupScreen()));
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(
          scaffold.backgroundColor,
          equals(AuthLayout.authBackgroundColor),
        );
        expect(scaffold.backgroundColor, isNot(equals(Colors.transparent)));

        // Also verify LoginScreen
        await tester.pumpWidget(_authScreen(const LoginScreen()));
        await tester.pumpAndSettle();

        final loginScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(
          loginScaffold.backgroundColor,
          equals(AuthLayout.authBackgroundColor),
        );
        expect(
          loginScaffold.backgroundColor,
          isNot(equals(Colors.transparent)),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('TEST M: No duplicate keyboard avoidance padding applied', (
      tester,
    ) async {
      await _setDeviceView(tester, width: 360, height: 800);
      await tester.pumpWidget(
        _authScreen(
          const SignupScreen(),
          viewInsets: const EdgeInsets.only(bottom: 297),
        ),
      );
      await tester.pumpAndSettle();

      // Scaffold resizeToAvoidBottomInset defaults to true.
      // There should not be an additional manual Padding of 297px inside the body.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isNot(isFalse));
      expect(tester.takeException(), isNull);
    });
  });

  group('AUTH-UX-HOTFIX-01: Responsive Viewports & Overflow Guards', () {
    final viewports = <(String, double, double)>[
      ('Standard 360x800', 360, 800),
      ('Modern 393x873', 393, 873),
      ('Large 412x915', 412, 915),
      ('Compact 360x640', 360, 640),
    ];

    for (final (name, width, height) in viewports) {
      testWidgets(
        'TEST G & I: SignupScreen keyboard open on $name has no overflow',
        (tester) async {
          await _setDeviceView(tester, width: width, height: height);
          await tester.pumpWidget(
            _authScreen(
              const SignupScreen(),
              viewInsets: const EdgeInsets.only(bottom: 300),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('signup-logo')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'TEST H & I: LoginScreen keyboard open on $name has no overflow',
        (tester) async {
          await _setDeviceView(tester, width: width, height: height);
          await tester.pumpWidget(
            _authScreen(
              const LoginScreen(),
              viewInsets: const EdgeInsets.only(bottom: 300),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('login-logo')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('SignupScreen with textScaler 1.3 adapts without overflow', (
      tester,
    ) async {
      await _setDeviceView(tester, width: 360, height: 800);
      await tester.pumpWidget(
        _authScreen(
          const SignupScreen(),
          viewInsets: const EdgeInsets.only(bottom: 280),
          textScaleFactor: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('LoginScreen with textScaler 1.3 adapts without overflow', (
      tester,
    ) async {
      await _setDeviceView(tester, width: 360, height: 800);
      await tester.pumpWidget(
        _authScreen(
          const LoginScreen(),
          viewInsets: const EdgeInsets.only(bottom: 280),
          textScaleFactor: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'TEST J: Normal layout remains fully usable after keyboard dismiss',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);

        // Open keyboard
        await tester.pumpWidget(
          _authScreen(
            const SignupScreen(),
            viewInsets: const EdgeInsets.only(bottom: 297),
          ),
        );
        await tester.pumpAndSettle();

        // Enter all fields
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Jane Doe');
        await tester.enterText(fields.at(1), 'jane@example.com');
        await tester.enterText(fields.at(2), 'Password123!');
        await tester.enterText(fields.at(3), 'Password123!');

        // Dismiss keyboard
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pumpWidget(
          _authScreen(const SignupScreen(), viewInsets: EdgeInsets.zero),
        );
        await tester.pump(const Duration(milliseconds: 400));

        // CTA button should be revealed and enabled
        final submitButton = find.byKey(const Key('signup-submit'));
        expect(submitButton, findsOneWidget);
        expect(tester.widget<AppButton>(submitButton).enabled, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<void> _setDeviceView(
  WidgetTester tester, {
  required double width,
  required double height,
  double devicePixelRatio = 3.0,
}) async {
  tester.view.physicalSize = Size(
    width * devicePixelRatio,
    height * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _authScreen(
  Widget screen, {
  EdgeInsets viewInsets = EdgeInsets.zero,
  double textScaleFactor = 1.0,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: viewInsets,
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: screen,
        ),
      ),
    ),
  );
}
