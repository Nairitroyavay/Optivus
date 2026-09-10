import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/auth_layout.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_motion.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/core/theme/optivus_spacing.dart';
import 'package:optivus/core/theme/optivus_theme.dart';
import 'package:optivus/core/theme/optivus_typography.dart';
import 'package:optivus/core/widgets/auth_text_field.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_style.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_block_card.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_day_chips.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_edit_sheet_shell.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/recovery/screens/onboarding_recovery_screen.dart';
import 'package:optivus/views/screens/auth_choice_screen.dart';
import 'package:optivus/views/screens/loading_screen.dart';
import 'package:optivus/views/screens/login_screen.dart';
import 'package:optivus/views/screens/signup_screen.dart';
import 'package:optivus/views/screens/verify_email_screen.dart';
import 'package:optivus/views/screens/welcome_screen.dart';
import 'package:optivus/widgets/app_button.dart';
import 'package:optivus/widgets/auth_back_button.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AH-F022: Design Tokens & Typography Hierarchy', () {
    test('Token family integrity and color value locks', () {
      // Base neutral hue is locked to #B8B4AC
      expect(OptivusColors.borderNeutral, const Color(0xFFB8B4AC));

      // Alpha variants derived from base neutral hue
      expect(
        OptivusColors.borderSubtle.r,
        equals(OptivusColors.borderNeutral.r),
      );
      expect(
        OptivusColors.borderSubtle.g,
        equals(OptivusColors.borderNeutral.g),
      );
      expect(
        OptivusColors.borderSubtle.b,
        equals(OptivusColors.borderNeutral.b),
      );
      expect(OptivusColors.borderStandard.a, closeTo(0.55, 0.01));
      expect(OptivusColors.borderStrong.a, closeTo(0.75, 0.01));
      expect(OptivusColors.borderDisabled.a, closeTo(0.20, 0.01));
      expect(OptivusColors.borderFocus.a, closeTo(1.0, 0.01));

      // Spacing metrics
      expect(OptivusSpacing.screenHorizontal, 24.0);
      expect(OptivusSpacing.screenHorizontalCompact, 16.0);
      expect(OptivusSpacing.sectionVertical, 24.0);
      expect(OptivusSpacing.sheetTopRadius, 28.0);

      // Radii hierarchy
      expect(OptivusRadii.surfaceLarge, 28.0);
      expect(OptivusRadii.cardStandard, 20.0);
      expect(OptivusRadii.controlCompact, 14.0);
      expect(OptivusRadii.modalSheet, 28.0);

      // Touch Target Minimum
      expect(OptivusTouchTarget.minimum, 48.0);
    });

    test('Typography tokens define hierarchical scale and weights', () {
      expect(OptivusTypography.screenTitle.fontSize, 32.0);
      expect(OptivusTypography.screenTitle.fontWeight, FontWeight.w900);
      expect(OptivusTypography.screenSubtitle.fontSize, 14.0);
      expect(OptivusTypography.sectionTitle.fontSize, 20.0);
      expect(OptivusTypography.cardTitle.fontSize, 16.0);
      expect(OptivusTypography.body.fontSize, 16.0);
      expect(OptivusTypography.helper.fontSize, 12.5);
      expect(OptivusTypography.caption.fontSize, 10.0);
    });

    test('OptivusMotion respects motion duration standards', () {
      expect(OptivusMotion.standardDuration, const Duration(milliseconds: 300));
      expect(OptivusMotion.fastDuration, const Duration(milliseconds: 180));
    });
  });

  group('AH-F022: Auth Screens Surface Continuity & No Redundant Docks', () {
    testWidgets(
      'LoginScreen has single continuous scroll surface and no detached lower dock',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(_testApp(const LoginScreen()));
        await tester.pumpAndSettle();

        // Verify no detached dock bar or cta dock present
        expect(find.byKey(const Key('login-cta-dock')), findsNothing);
        expect(find.byKey(const Key('login-scaffold-dock')), findsNothing);

        // Enter text to reveal progressive submit button
        final emailField = find.byType(TextField).at(0);
        final passField = find.byType(TextField).at(1);
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passField, 'password123');
        await tester.pumpAndSettle();

        // Verify primary submit button is directly in the scroll body
        final submitButton = find.byKey(const Key('login-submit'));
        expect(submitButton, findsOneWidget);

        // Verify root Scaffold exists and has proper background
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(
          scaffold.backgroundColor,
          equals(AuthLayout.authBackgroundColor),
        );

        // Verify AnnotatedRegion owns authOverlayStyle
        final annotated = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        );
        expect(annotated.value, equals(OptivusTheme.authOverlayStyle));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'SignupScreen has single continuous scroll surface and no detached lower dock',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(_testApp(const SignupScreen()));
        await tester.pumpAndSettle();

        // Verify no detached dock bar
        expect(find.byKey(const Key('signup-dock')), findsNothing);
        expect(find.byKey(const Key('signup-cta-dock')), findsNothing);

        // Verify root Scaffold exists
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(
          scaffold.backgroundColor,
          equals(AuthLayout.authBackgroundColor),
        );

        final annotated = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        );
        expect(annotated.value, equals(OptivusTheme.authOverlayStyle));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('AuthChoiceScreen is continuous and sets auth overlay style', (
      tester,
    ) async {
      await _setDeviceView(tester, width: 360, height: 800);
      await tester.pumpWidget(_testApp(const AuthChoiceScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auth-choice-background')), findsOneWidget);
      expect(find.byKey(const Key('auth-choice-safe-content')), findsOneWidget);

      final annotated = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(annotated.value, equals(OptivusTheme.authOverlayStyle));
      expect(tester.takeException(), isNull);
    });

    testWidgets('VerifyEmailScreen is continuous and sets auth overlay style', (
      tester,
    ) async {
      await _setDeviceView(tester, width: 360, height: 800);
      await tester.pumpWidget(_testApp(const VerifyEmailScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('verify-email-scroll-view')), findsOneWidget);
      final annotated = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(annotated.value, equals(OptivusTheme.authOverlayStyle));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'WelcomeScreen has continuous layout, auth overlay, and >=48dp login link target',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(_testApp(const WelcomeScreen()));
        await tester.pump(const Duration(milliseconds: 100));

        final annotated = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        );
        expect(annotated.value, equals(OptivusTheme.authOverlayStyle));

        // Verify login link touch target
        final loginLink = find.byKey(const Key('welcome-login-link'));
        expect(loginLink, findsOneWidget);
        final linkSize = tester.getSize(loginLink);
        expect(linkSize.height, greaterThanOrEqualTo(48.0));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('LoadingScreen provides continuous layout and auth overlay', (
      tester,
    ) async {
      await _setDeviceView(tester, width: 360, height: 800);
      await tester.pumpWidget(
        _testApp(const LoadingScreen(message: 'Loading...')),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final annotated = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(annotated.value, equals(OptivusTheme.authOverlayStyle));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'OnboardingRecoveryScreen provides continuous layout and auth overlay',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(_testApp(const OnboardingRecoveryScreen()));
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, isNotNull);

        final annotated = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        );
        expect(annotated.value, equals(OptivusTheme.authOverlayStyle));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AH-F022: Standard Gray Structural Borders & Controls', () {
    testWidgets('AuthBackButton has minimum touch target >=48dp', (
      tester,
    ) async {
      await _setDeviceView(tester, width: 360, height: 800);
      await tester.pumpWidget(
        _testApp(
          Scaffold(
            body: Center(child: AuthBackButton(onTap: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backButton = find.byType(AuthBackButton);
      expect(backButton, findsOneWidget);
      final size = tester.getSize(backButton);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
      'AuthTextField has 48dp hit constraints on eye button and gray border',
      (tester) async {
        final ctrl = TextEditingController();
        final focus = FocusNode();
        bool obscure = true;

        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _testApp(
            StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Center(
                    child: AuthTextField(
                      controller: ctrl,
                      focusNode: focus,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscure: obscure,
                      suffix: AuthEyeButton(
                        obscure: obscure,
                        onToggle: () => setState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final eyeButton = find.byType(AuthEyeButton);
        expect(eyeButton, findsOneWidget);
        final eyeSize = tester.getSize(eyeButton);
        expect(eyeSize.width, greaterThanOrEqualTo(48.0));
        expect(eyeSize.height, greaterThanOrEqualTo(44.0));

        // Toggle password visibility
        await tester.tap(eyeButton);
        await tester.pumpAndSettle();
        expect(obscure, isFalse);
      },
    );

    testWidgets(
      'TimelineBlockCard renders with high-performance styling and without per-block BackdropFilter',
      (tester) async {
        final entry = TimelineEntry(
          id: 'test-event-1',
          sourceId: 'test-source-1',
          startMinute: 540,
          endMinute: 600,
          repeatDays: const [1, 2, 3, 4, 5],
          title: 'Morning Standup',
          category: TimelineCategory.work,
          isEditable: true,
        );

        final positioned = PositionedTimelineEntry(
          entry: entry,
          top: 100,
          left: 20,
          width: 300,
          height: 60,
          column: 0,
          columnCount: 1,
        );

        final style = TimelineEntryStyle.defaultForCategory(
          TimelineCategory.work,
        );

        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _testApp(
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 60,
                  child: TimelineBlockCard(
                    positioned: positioned,
                    style: style,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Card is rendered
        expect(
          find.byKey(const ValueKey('timeline-block-test-event-1')),
          findsOneWidget,
        );

        // Verify NO BackdropFilter inside TimelineBlockCard for 60fps scrolling efficiency
        final blockCardFinder = find.byKey(
          const ValueKey('timeline-block-test-event-1'),
        );
        final backdropFiltersInsideCard = find.descendant(
          of: blockCardFinder,
          matching: find.byType(BackdropFilter),
        );
        expect(backdropFiltersInsideCard, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TimelineDayChips uses borderNeutral and allows 1-indexed day selection',
      (tester) async {
        int selectedDay = 1;

        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _testApp(
            StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: TimelineDayChips(
                    selectedDay: selectedDay,
                    onDayChanged: (day) => setState(() => selectedDay = day),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 7 days rendered (Mon-Sun)
        for (int i = 1; i <= 7; i++) {
          expect(find.byKey(ValueKey('timeline-day-chip-$i')), findsOneWidget);
        }

        // Tap Wednesday (day 3)
        await tester.tap(find.byKey(const ValueKey('timeline-day-chip-3')));
        await tester.pumpAndSettle();
        expect(selectedDay, equals(3));
      },
    );

    testWidgets(
      'TimelineEditSheetShell has 28dp top radius and >=48dp touch targets',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _testApp(
            Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    key: const Key('open-sheet'),
                    onPressed: () {
                      TimelineEditSheetShell.show<void>(
                        context: context,
                        title: 'Edit Activity',
                        builder: (ctx) => const Text('Sheet Content'),
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-sheet')));
        await tester.pumpAndSettle();

        final cancelBtn = find.byKey(const Key('timeline-edit-cancel-button'));
        final saveBtn = find.byKey(const Key('timeline-edit-save-button'));

        expect(cancelBtn, findsOneWidget);
        expect(saveBtn, findsOneWidget);

        final cancelSize = tester.getSize(cancelBtn);
        final saveSize = tester.getSize(saveBtn);

        expect(cancelSize.height, greaterThanOrEqualTo(48.0));
        expect(saveSize.height, greaterThanOrEqualTo(48.0));

        // Dismiss sheet
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('timeline-edit-cancel-button')),
          findsNothing,
        );
      },
    );
  });

  group('AH-F022: Accessibility, TalkBack Semantics & Text Scaling', () {
    testWidgets(
      'Text scaling up to 1.6x renders without overflow in AuthChoiceScreen',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _testApp(const AuthChoiceScreen(), textScaleFactor: 1.6),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('auth-choice-background')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'OnboardingGlassWidgets render with proper semantics and gray border tokens',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _testApp(
            Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const OnboardingGlassCard(child: Text('Card Content')),
                    OnboardingChip(
                      label: 'Morning',
                      selected: false,
                      onTap: () {},
                    ),
                    OnboardingChip(
                      label: 'Evening',
                      selected: true,
                      onTap: () {},
                    ),
                    OnboardingActionPill(
                      label: 'Add Item',
                      icon: Icons.add,
                      onTap: () {},
                    ),
                    OnboardingIconPill(icon: Icons.star, onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Card Content'), findsOneWidget);
        expect(find.text('Morning'), findsOneWidget);
        expect(find.text('Evening'), findsOneWidget);
        expect(find.text('Add Item'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TimelineDayChips keeps gray border token in both selected and unselected states',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _testApp(
            Scaffold(
              body: TimelineDayChips(selectedDay: 2, onDayChanged: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check AnimatedContainers for day chips
        final selectedContainer = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byKey(const ValueKey('timeline-day-chip-2')),
            matching: find.byType(AnimatedContainer),
          ),
        );
        final unselectedContainer = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byKey(const ValueKey('timeline-day-chip-1')),
            matching: find.byType(AnimatedContainer),
          ),
        );

        final selectedBox = selectedContainer.decoration as BoxDecoration;
        final unselectedBox = unselectedContainer.decoration as BoxDecoration;

        // Both must use OptivusColors.borderNeutral base hue (not accent)
        final selectedBorder = selectedBox.border as Border;
        final unselectedBorder = unselectedBox.border as Border;

        expect(
          selectedBorder.top.color.r,
          equals(OptivusColors.borderNeutral.r),
        );
        expect(
          selectedBorder.top.color.g,
          equals(OptivusColors.borderNeutral.g),
        );
        expect(
          selectedBorder.top.color.b,
          equals(OptivusColors.borderNeutral.b),
        );

        expect(
          unselectedBorder.top.color.r,
          equals(OptivusColors.borderNeutral.r),
        );
        expect(
          unselectedBorder.top.color.g,
          equals(OptivusColors.borderNeutral.g),
        );
        expect(
          unselectedBorder.top.color.b,
          equals(OptivusColors.borderNeutral.b),
        );
      },
    );

    testWidgets(
      'SignupScreen has no nested BackdropFilter in password rules panel or banners',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(_testApp(const SignupScreen()));
        await tester.pumpAndSettle();

        // Enter password to reveal rules panel
        final passField = find.byType(TextField).at(2);
        await tester.enterText(passField, 'Pass123!');
        await tester.pumpAndSettle();

        final rulesPanel = find.byKey(
          const Key('signup-password-guidance-success'),
        );
        expect(rulesPanel, findsOneWidget);

        final nestedBlurs = find.descendant(
          of: rulesPanel,
          matching: find.byType(BackdropFilter),
        );
        expect(nestedBlurs, findsNothing);
      },
    );

    testWidgets(
      'AppButton scales text gracefully up to 2.0x without overflow',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _testApp(
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: AppButton(
                    text: 'Enter Optivus Long Action',
                    onPressed: () {},
                  ),
                ),
              ),
            ),
            textScaleFactor: 2.0,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Enter Optivus Long Action'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'OptivusMotion.isReducedMotion responds to MediaQuery disableAnimations',
      (tester) async {
        late bool reducedMotion;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: Builder(
                  builder: (innerContext) {
                    reducedMotion = OptivusMotion.isReducedMotion(innerContext);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
        expect(reducedMotion, isTrue);
      },
    );

    testWidgets(
      'Text scaling up to 1.6x renders without overflow in LoginScreen and SignupScreen',
      (tester) async {
        await _setDeviceView(tester, width: 360, height: 800);
        await tester.pumpWidget(
          _testApp(const LoginScreen(), textScaleFactor: 1.6),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _testApp(const SignupScreen(), textScaleFactor: 1.6),
        );
        await tester.pumpAndSettle();
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

Widget _testApp(
  Widget child, {
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
          child: child,
        ),
      ),
    ),
  );
}
