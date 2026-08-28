import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/auth_layout.dart';
import 'package:optivus/core/widgets/auth_text_field.dart';
import 'package:optivus/views/screens/auth_choice_screen.dart';
import 'package:optivus/views/screens/login_screen.dart';
import 'package:optivus/views/screens/signup_screen.dart';
import 'package:optivus/views/screens/verify_email_screen.dart';
import 'package:optivus/widgets/app_button.dart';
import 'package:optivus/widgets/auth_back_button.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('blank signup fits Realme 6 without user scrolling', (
    tester,
  ) async {
    await _setRealmeView(tester);
    await tester.pumpWidget(_authScreen(const SignupScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.getSize(find.byKey(const Key('signup-logo'))),
      const Size(88, 88),
    );
    expect(
      find.text('By joining, you agree to our Terms of Service.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('signup-submit')), findsNothing);
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('signup-form-scroll')),
          )
          .physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup tap outside dismisses the focused field', (tester) async {
    await tester.pumpWidget(_authScreen(const SignupScreen()));
    final fields = find.byType(TextField);

    await tester.tap(fields.first);
    await tester.pump();
    expect(tester.widget<TextField>(fields.first).focusNode!.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('signup-title')));
    await tester.pump();
    expect(tester.widget<TextField>(fields.first).focusNode!.hasFocus, isFalse);
  });

  testWidgets('password guidance is compact and focus-driven', (tester) async {
    await tester.pumpWidget(_authScreen(const SignupScreen()));
    final fields = find.byType(TextField);

    await tester.tap(fields.at(2));
    await tester.enterText(fields.at(2), 'Abc1');
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('signup-password-guidance-detailed')),
      findsOneWidget,
    );

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('signup-password-guidance-detailed')),
      findsNothing,
    );

    await tester.tap(fields.at(2));
    await tester.enterText(fields.at(2), 'Validpass1!');
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('signup-password-guidance-success')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('signup-password-guidance-detailed')),
      findsNothing,
    );

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('signup-password-guidance-success')),
      findsNothing,
    );
  });

  testWidgets('confirm mismatch clears immediately after correction', (
    tester,
  ) async {
    await tester.pumpWidget(_authScreen(const SignupScreen()));
    final fields = find.byType(TextField);

    await tester.enterText(fields.at(2), 'Validpass1!');
    await tester.tap(fields.at(3));
    await tester.enterText(fields.at(3), 'Mismatch1!');
    await tester.pump();
    expect(find.byKey(const Key('signup-confirm-error')), findsOneWidget);

    await tester.enterText(fields.at(3), 'Validpass1!');
    await tester.pump();
    expect(find.byKey(const Key('signup-confirm-error')), findsNothing);
  });

  testWidgets('signup CTA reveals once then stays stable and disables', (
    tester,
  ) async {
    await tester.pumpWidget(_authScreen(const SignupScreen()));
    final fields = find.byType(TextField);

    expect(find.byKey(const Key('signup-submit')), findsNothing);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'test@example.com');
    await tester.enterText(fields.at(2), 'Validpass1!');
    await tester.enterText(fields.at(3), 'Validpass1!');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('signup-submit')), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.byKey(const Key('signup-submit'))).enabled,
      isTrue,
    );

    await tester.enterText(fields.at(1), 'invalid-email');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('signup-submit')), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.byKey(const Key('signup-submit'))).enabled,
      isFalse,
    );
  });

  testWidgets('signup IME actions follow Next chain and Done unfocuses', (
    tester,
  ) async {
    await tester.pumpWidget(_authScreen(const SignupScreen()));
    final fields = find.byType(TextField);

    await tester.tap(fields.at(0));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(1)).focusNode!.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(2)).focusNode!.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(3)).focusNode!.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(3)).focusNode!.hasFocus, isFalse);
  });

  testWidgets('keyboard layout compacts header and does not dock CTA', (
    tester,
  ) async {
    await _setRealmeView(tester);
    await tester.pumpWidget(
      _authScreen(
        const SignupScreen(),
        viewInsets: const EdgeInsets.only(bottom: 297),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('signup-logo'))),
      const Size(44, 44),
    );
    expect(find.byKey(const Key('signup-submit')), findsNothing);
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('signup-form-scroll')),
          )
          .physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('login reuses outside-tap keyboard dismissal', (tester) async {
    await tester.pumpWidget(_authScreen(const LoginScreen()));
    final email = find.byType(TextField).first;

    await tester.tap(email);
    await tester.pump();
    expect(tester.widget<TextField>(email).focusNode!.hasFocus, isTrue);

    await tester.tap(find.text('Welcome back.'));
    await tester.pump();
    expect(tester.widget<TextField>(email).focusNode!.hasFocus, isFalse);
  });

  testWidgets('blank login fits Realme 6 without user scrolling', (
    tester,
  ) async {
    await _setRealmeView(tester);
    await tester.pumpWidget(_authScreen(const LoginScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.getSize(find.byKey(const Key('login-logo'))),
      const Size(AuthLayout.standardLogoSize, AuthLayout.standardLogoSize),
    );
    expect(find.byKey(const Key('login-submit')), findsNothing);
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('login-form-scroll')),
          )
          .physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth screens reuse canonical AuthBackButton', (tester) async {
    await tester.pumpWidget(_authScreen(const AuthChoiceScreen()));
    expect(find.byType(AuthBackButton), findsOneWidget);

    await tester.pumpWidget(_authScreen(const SignupScreen()));
    expect(find.byType(AuthBackButton), findsOneWidget);

    await tester.pumpWidget(_authScreen(const LoginScreen()));
    expect(find.byType(AuthBackButton), findsOneWidget);

    await tester.pumpWidget(_authScreen(const VerifyEmailScreen()));
    expect(find.byType(AuthBackButton), findsOneWidget);
  });

  testWidgets('all auth text fields share 50px standard height', (
    tester,
  ) async {
    await tester.pumpWidget(_authScreen(const SignupScreen()));
    final signupFields = tester.widgetList<AuthTextField>(
      find.byType(AuthTextField),
    );
    expect(signupFields.length, 4);
    for (final field in signupFields) {
      expect(field.height, AuthLayout.standardFieldHeight);
    }

    await tester.pumpWidget(_authScreen(const LoginScreen()));
    final loginFields = tester.widgetList<AuthTextField>(
      find.byType(AuthTextField),
    );
    expect(loginFields.length, 2);
    for (final field in loginFields) {
      expect(field.height, AuthLayout.standardFieldHeight);
    }
  });

  testWidgets('Login screen does not contain Apple button', (tester) async {
    await tester.pumpWidget(_authScreen(const LoginScreen()));
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.byKey(const Key('login-google')), findsOneWidget);
  });
}

Future<void> _setRealmeView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _authScreen(Widget screen, {EdgeInsets viewInsets = EdgeInsets.zero}) {
  return ProviderScope(
    child: MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(viewInsets: viewInsets),
          child: screen,
        ),
      ),
    ),
  );
}
