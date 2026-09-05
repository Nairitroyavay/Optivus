import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_spacing.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_0_welcome.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_10_notifications.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_11_today_ready.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_1_patience.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_2_role_lifestyle.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_3_body_basics.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_base_timeline.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_bad_habits.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_6_fixed_schedule.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_6_good_habits.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_identity_goals.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_8_coach_setup.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_9_slip_up.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier([AuthState? initial])
    : super(
        initial ??
            const AuthState(
              user: AuthUser(
                uid: 'test-user',
                email: 'test@example.com',
                emailVerified: true,
                isAnonymous: false,
              ),
              status: AuthFlowStatus.signedInOnboardingIncomplete,
            ),
      );

  @override
  Future<void> acceptCanonicalOnboardingCompletion(AuthUser user) async {}
  @override
  Future<void> checkEmailVerification() async {}
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<bool> signInWithGoogle() async => false;
  @override
  Future<void> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {}
  @override
  Future<void> login(String email, String password) async {}
  @override
  Future<void> signup(String name, String email, String password) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<void> markOnboardingComplete(AuthUser user) async {}
  @override
  Future<void> markOnboardingIncomplete(AuthUser user) async {}
  @override
  Future<void> resendEmailVerification() async {}
  @override
  Future<void> retryBackendRestore() async {}
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<void> executeRecoveryAction(dynamic action) async {}
}

Widget _wrapStep(Widget stepWidget, {OnboardingDraft? draft}) {
  return ProviderScope(
    overrides: [
      mockOnboardingProvider.overrideWith((_) {
        final notifier = MockOnboardingNotifier();
        if (draft != null) notifier.loadSeedData(draft);
        return notifier;
      }),
      authProvider.overrideWith((ref) => _FakeAuthNotifier()),
      onboardingRepositoryProvider.overrideWithValue(
        FakeOnboardingRepository(),
      ),
      activeOnboardingCompletionJobProvider.overrideWith(
        (ref) => ValueNotifier<OnboardingCompletionJob?>(null),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: stepWidget)),
  );
}

Widget _wrapFlow({int currentStep = 2, Widget? child}) {
  final completed = [for (int i = 0; i < 15; i++) i < currentStep];
  return ProviderScope(
    overrides: [
      mockOnboardingProvider.overrideWith((_) {
        final notifier = MockOnboardingNotifier()
          ..loadSeedData(
            OnboardingDraft(
              currentStep: currentStep,
              welcomeSaved: true,
              patiencePledgeAccepted: true,
              stepCompleted: completed,
            ),
          );
        return notifier;
      }),
      authProvider.overrideWith((ref) => _FakeAuthNotifier()),
      onboardingRepositoryProvider.overrideWithValue(
        FakeOnboardingRepository(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: OnboardingStepShell(
          currentPage: currentStep,
          pageOffset: currentStep.toDouble(),
          completedSteps: completed,
          validationMessage: null,
          onDotTap: (_) {},
          onIndicatorDraggedTo: (_) {},
          onSave: null,
          showSave: false,
          isSaving: false,
          isSaved: false,
          saveEnabled: false,
          ctaLabel: 'Next Step',
          ctaEnabled: true,
          ctaLoading: false,
          child: child ?? const OnboardingStep2(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding Header Spacing Tokens', () {
    test('OptivusSpacing defines normalized onboarding header tokens', () {
      expect(OptivusSpacing.onboardingProgressToHeaderGap, 2.0);
      expect(OptivusSpacing.onboardingHeaderToContentGap, 26.0);
      expect(
        OptivusSpacing.onboardingHeaderPadding,
        const EdgeInsets.fromLTRB(24, 2, 24, 0),
      );
      expect(
        OptivusSpacing.onboardingContentPadding,
        const EdgeInsets.fromLTRB(24, 26, 24, 32),
      );
    });
  });

  group('A. Progress Indicator remains above Header', () {
    testWidgets(
      'LiquidGlassOnboardingIndicator sits vertically above OnboardingSectionTitle',
      (tester) async {
        await tester.pumpWidget(_wrapFlow(currentStep: 2));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final indicatorFinder = find.byType(LiquidGlassOnboardingIndicator);
        final titleFinder = find.byType(OnboardingSectionTitle);

        expect(indicatorFinder, findsOneWidget);
        expect(titleFinder, findsOneWidget);

        final indicatorBottom = tester.getBottomLeft(indicatorFinder).dy;
        final titleTop = tester.getTopLeft(titleFinder).dy;

        expect(titleTop, greaterThan(indicatorBottom));
        // Top spacing between indicator bar and title is compact and normalized
        expect(titleTop - indicatorBottom, greaterThan(0));
      },
    );
  });

  group('B. Title + Subtitle Move as One Group', () {
    testWidgets('OnboardingSectionTitle keeps title and subtitle together', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapStep(
          const Padding(
            padding: OptivusSpacing.onboardingHeaderPadding,
            child: OnboardingSectionTitle(
              title: 'Currently Who Are You?',
              subtitle:
                  'This unlocks the right class, work, and lifestyle setup blocks.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text('Currently Who Are You?');
      final subtitleFinder = find.text(
        'This unlocks the right class, work, and lifestyle setup blocks.',
      );

      expect(titleFinder, findsOneWidget);
      expect(subtitleFinder, findsOneWidget);

      final titleBottom = tester.getBottomLeft(titleFinder).dy;
      final subtitleTop = tester.getTopLeft(subtitleFinder).dy;

      expect(subtitleTop - titleBottom, 6.0);
    });
  });

  group('C & D. Standard Steps Use Shared Spacing Tokens', () {
    final standardStepCases = <String, Widget>{
      'Step 2 (Role & Lifestyle)': const OnboardingStep2(),
      'Step 3 (Body Basics)': const OnboardingStep3(),
      'Step 4 Fallback (OnboardingStepBody)': const OnboardingStepBody(
        title: 'Classes & Job',
        subtitle: 'No class or work schedule is needed for this role.',
        children: [Text('Content')],
      ),
      'Step 8 (Bad Habits)': const OnboardingStep8(),
      'Step 9 (Good Habits)': const OnboardingStep9(),
      'Step 10 (Identity Goals)': const OnboardingStep10(),
      'Step 11 (Coach Setup)': const OnboardingStep11(),
      'Step 12 (Slip-up Handling)': const OnboardingStep12(),
      'Step 13 (Notifications)': const OnboardingStep13(),
    };

    for (final entry in standardStepCases.entries) {
      testWidgets('${entry.key} applies normalized header and content padding', (
        tester,
      ) async {
        await tester.pumpWidget(_wrapStep(entry.value));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final sectionTitleFinder = find.byType(OnboardingSectionTitle);
        expect(sectionTitleFinder, findsOneWidget);

        // Header padding is OptivusSpacing.onboardingHeaderPadding
        final headerPaddingFinder = find.ancestor(
          of: sectionTitleFinder,
          matching: find.byType(Padding),
        );
        expect(headerPaddingFinder, findsWidgets);
        final headerPadding = tester.widget<Padding>(headerPaddingFinder.first);
        expect(headerPadding.padding, OptivusSpacing.onboardingHeaderPadding);

        // Content ScrollView padding is OptivusSpacing.onboardingContentPadding
        final scrollViewFinder = find.byType(OnboardingScrollView);
        expect(scrollViewFinder, findsOneWidget);
        final scrollView = tester.widget<OnboardingScrollView>(
          scrollViewFinder,
        );
        expect(scrollView.padding, OptivusSpacing.onboardingContentPadding);
      });
    }

    testWidgets(
      'Step 2 subtitle-to-content gap provides at least 26px breathing room',
      (tester) async {
        await tester.pumpWidget(_wrapStep(const OnboardingStep2()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final subtitleFinder = find.text(
          'This unlocks the right class, work, and lifestyle setup blocks.',
        );
        final firstCardFinder = find.text('Student / School / College');

        expect(subtitleFinder, findsOneWidget);
        expect(firstCardFinder, findsOneWidget);

        final subtitleBottom = tester.getBottomLeft(subtitleFinder).dy;
        final firstCardTop = tester.getTopLeft(firstCardFinder).dy;

        // The gap between subtitle and first content widget includes the 26px padding
        expect(firstCardTop - subtitleBottom, greaterThanOrEqualTo(26.0));
      },
    );
  });

  group('E. Multi-Line Subtitles Do Not Overlap First Content Widget', () {
    testWidgets('Multi-line subtitle pushes content down naturally', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapStep(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: OptivusSpacing.onboardingHeaderPadding,
                child: OnboardingSectionTitle(
                  title: 'Long Subtitle Test Step',
                  subtitle:
                      'This is an extremely long subtitle that will inevitably wrap across multiple lines of text '
                      'in order to verify that dynamic layout expands naturally and pushes the scrollable content down.',
                ),
              ),
              Expanded(
                child: OnboardingScrollView(
                  padding: OptivusSpacing.onboardingContentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        key: const ValueKey('first-content-card'),
                        height: 60,
                        color: Colors.yellow,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final subtitleFinder = find.byType(Text).at(1);
      final cardFinder = find.byKey(const ValueKey('first-content-card'));

      final subtitleBottom = tester.getBottomLeft(subtitleFinder).dy;
      final cardTop = tester.getTopLeft(cardFinder).dy;

      expect(cardTop, greaterThan(subtitleBottom));
      expect(cardTop - subtitleBottom, greaterThanOrEqualTo(26.0));
    });
  });

  group('F. Text Scale 1.6 Does Not Overflow', () {
    testWidgets(
      'Step 2 with text scale 1.6 renders without layout exceptions or overflow',
      (tester) async {
        tester.view.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(
          () => tester.view.platformDispatcher.clearTextScaleFactorTestValue(),
        );

        await tester.pumpWidget(_wrapFlow(currentStep: 2));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byType(OnboardingSectionTitle), findsOneWidget);
      },
    );
  });

  group('G-J. Responsive Viewport Verifications', () {
    final viewports = <String, Size>{
      'G. 360x640': const Size(360, 640),
      'H. 360x800': const Size(360, 800),
      'I. 393x873': const Size(393, 873),
      'J. 412x915': const Size(412, 915),
    };

    for (final entry in viewports.entries) {
      testWidgets('Step 2 renders correctly on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapFlow(currentStep: 2));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byType(LiquidGlassOnboardingIndicator), findsOneWidget);
        expect(find.byType(OnboardingSectionTitle), findsOneWidget);
        expect(find.text('Currently Who Are You?'), findsOneWidget);
      });
    }
  });

  group('K. CTA/Footer Clearance Remains Intact', () {
    testWidgets('OnboardingScrollView includes bottom footer reserve for CTA', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapFlow(currentStep: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final scrollViewFinder = find.byType(OnboardingScrollView);
      expect(scrollViewFinder, findsOneWidget);

      final scrollView = tester.widget<OnboardingScrollView>(scrollViewFinder);
      expect(scrollView.includeBottomReserve, isTrue);
    });
  });

  group('L. Special Screens Are Not Forced into Standard Layout', () {
    testWidgets('Step 0 (Welcome) maintains full hero layout', (tester) async {
      await tester.pumpWidget(_wrapStep(const OnboardingStep0()));
      await tester.pumpAndSettle();

      expect(find.text('OPTIVUS'), findsOneWidget);
      expect(find.text('Welcome to\nOptivus'), findsOneWidget);
      expect(find.byType(OnboardingSectionTitle), findsNothing);
    });

    testWidgets('Step 1 (Patience) maintains full pledge card layout', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapStep(const OnboardingStep1()));
      await tester.pumpAndSettle();

      expect(find.text('The Spike vs. Compound Rule'), findsOneWidget);
      expect(find.text('Patience Pledge'), findsOneWidget);
      expect(find.byType(OnboardingSectionTitle), findsNothing);
    });

    testWidgets('Step 4 (Unified Timeline) maintains full timeline layout', (
      tester,
    ) async {
      const studentDraft = OnboardingDraft(
        lifeRole: LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
      );
      await tester.pumpWidget(
        _wrapStep(const OnboardingStep4(), draft: studentDraft),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Classes'), findsWidgets);
      expect(find.byType(OnboardingSectionTitle), findsNothing);
    });

    testWidgets('Step 6 (Fixed Schedule) maintains 24h timeline layout', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapStep(const OnboardingStep6()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('onboarding-step6-header')), findsOneWidget);
      expect(find.text('Fixed Schedule'), findsOneWidget);
      expect(find.byType(OnboardingSectionTitle), findsNothing);
    });

    testWidgets('Step 14 (Today Ready) maintains final review layout', (
      tester,
    ) async {
      final draft = OnboardingDraft(
        uid: 'test-user',
        currentStep: 14,
        welcomeSaved: true,
        patiencePledgeAccepted: true,
        lifeRole: const LifeRoleDraft(
          lifeRole: LifeRoleDraft.studentKey,
          exerciseLevel: '3_4_days',
          waterIntake: 'medium',
          stressLevel: 'medium',
          sleepQuality: 'good',
        ),
        bodyBasics: const BodyBasicsDraft(
          ageRange: '18-24',
          heightCm: 175,
          weightKg: 70,
          gender: 'male',
        ).withEstimates(),
        baseTimeline: const BaseTimelineDraft(
          eatingMode: 'home',
          blocks: [
            TimelineBlockDraft(
              id: 'class1',
              section: 'classes',
              title: 'Physics',
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              repeatDays: [1, 2, 3, 4, 5],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'eating1',
              section: 'eating',
              title: 'Breakfast',
              startMinute: 8 * 60,
              endMinute: 8 * 60 + 30,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedSleepId,
              section: 'fixed',
              title: 'Sleep',
              startMinute: 23 * 60,
              endMinute: 7 * 60,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedBathId,
              section: 'fixed',
              title: 'Bath',
              startMinute: 7 * 60,
              endMinute: 7 * 60 + 30,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        ),
        stepCompleted: [for (int i = 0; i < 15; i++) i < 14],
      );
      await tester.pumpWidget(
        _wrapStep(const OnboardingStep14(), draft: draft),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OnboardingStep14), findsOneWidget);
      expect(find.byType(OnboardingSectionTitle), findsNothing);
    });
  });
}
