import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/views/screens/auth_choice_screen.dart';
import 'package:optivus/views/screens/signup_screen.dart';
import 'package:optivus/views/screens/welcome_screen.dart';
import 'package:optivus/widgets/app_button.dart';

void main() {
  testWidgets(
    'auth choice exposes exactly two primary options on Realme size',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auth-choice-create')), findsOneWidget);
      expect(find.byKey(const Key('auth-choice-google')), findsOneWidget);
      expect(find.byKey(const Key('auth-choice-login')), findsOneWidget);
      expect(find.byType(Scrollable), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Create New Account' &&
              widget.properties.button == true,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Continue with Google' &&
              widget.properties.button == true,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Create New Account uses the expected navigation stack', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.tap(find.byKey(const Key('auth-choice-create')));
    await tester.pumpAndSettle();
    expect(find.text('create-account-destination'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AuthChoiceScreen), findsOneWidget);
  });

  testWidgets('existing Login path remains reachable', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.tap(find.byKey(const Key('auth-choice-login')));
    await tester.pumpAndSettle();
    expect(find.text('login-destination'), findsOneWidget);
  });

  testWidgets('Get Started routes to Auth Choice', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
        GoRoute(path: '/signup', builder: (_, _) => const AuthChoiceScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthChoiceScreen), findsOneWidget);
  });

  testWidgets(
    'signup uses neutral hint and progressive CTA stays disabled in place',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SignupScreen())),
      );
      await tester.pump();

      expect(find.text('Your full name'), findsOneWidget);
      expect(find.text('Nairit Roy'), findsNothing);
      expect(find.byKey(const Key('signup-submit')), findsNothing);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('signup-form-scroll')),
      );
      expect(scroll.physics, isA<NeverScrollableScrollPhysics>());
      expect(tester.takeException(), isNull);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4));
      await tester.enterText(fields.at(0), 'Test User');
      await tester.enterText(fields.at(1), 'test@example.com');
      await tester.enterText(fields.at(2), 'Validpass1!');
      await tester.enterText(fields.at(3), 'Validpass1!');
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('signup-submit')), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.byKey(const Key('signup-submit')))
            .enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);

      await tester.enterText(fields.at(1), 'not-an-email');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('signup-submit')), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.byKey(const Key('signup-submit')))
            .enabled,
        isFalse,
      );

      await tester.tap(fields.at(0));
      await tester.pump();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.liveRegion == true &&
              widget.properties.label == 'Please enter a valid email address.',
        ),
        findsOneWidget,
      );

      await tester.enterText(fields.at(1), 'corrected@example.com');
      await tester.pump();
      expect(find.text('Please enter a valid email address.'), findsNothing);
    },
  );
}

Widget _testApp() {
  final router = GoRouter(
    initialLocation: '/signup',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('welcome')),
      GoRoute(path: '/signup', builder: (_, _) => const AuthChoiceScreen()),
      GoRoute(
        path: '/signup/create',
        builder: (_, _) => const Text('create-account-destination'),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Text('login-destination'),
      ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}
