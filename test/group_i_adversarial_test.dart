import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_theme.dart';
import 'package:optivus/core/utils/liquid_toast_manager.dart';
import 'package:optivus/core/widgets/liquid_buttons.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier()
    : super(
        const AuthState(
          user: AuthUser(
            uid: 'test-adversarial-uid',
            email: 'adv@example.com',
            emailVerified: true,
          ),
          status: AuthFlowStatus.signedInOnboardingIncomplete,
        ),
      );

  @override
  Future<void> checkEmailVerification() async {}
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<void> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {}
  @override
  Future<void> login(String email, String password) async {}
  Future<void> register(String email, String password) async {}
  @override
  Future<void> logout() async {}
  Future<void> resetPassword(String email) async {}
  Future<void> updateProfile({String? displayName, String? photoURL}) async {}
  @override
  Future<void> executeRecoveryAction(OnboardingRecoveryAction action) async {}
  @override
  Future<void> markOnboardingComplete(AuthUser user) async {}
  @override
  Future<void> acceptCanonicalOnboardingCompletion(AuthUser user) async {}
  @override
  Future<void> markOnboardingIncomplete(AuthUser user) async {}
  @override
  Future<void> resendEmailVerification() async {}
  @override
  Future<void> retryBackendRestore() async {}
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<void> signup(String name, String email, String password) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOnboardingRepository implements OnboardingRepository {
  @override
  Future<void> saveDraft(OnboardingDraft draft) async {}
  Future<OnboardingDraft?> getDraft(String uid) async => null;
  Future<void> deleteDraft(String uid) async {}
  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group I Adversarial & Stress Tests', () {
    // ──────────────────────────────────────────────────────────────────────────
    // 1. 200% Font Scaling & Long Strings Layout Overflow Stress Tests
    // ──────────────────────────────────────────────────────────────────────────
    group('Adversarial Test 1: 200% Font Scale & Long Strings Overflow Protection', () {
      testWidgets(
        'OnboardingChip withstands 200% font scale and 250-char string in narrow container',
        (tester) async {
          const longString =
              'Extremely_Long_Adversarial_Chip_Label_String_1234567890_That_Exceeds_Normal_Container_Bounds_And_Tests_Text_Scaler_Clamping_And_Fitted_Box_Overflow_Protection_In_Optivus_UI_Component_Library_Verification_Test_Suite_Padding_Border_Check';

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 180,
                      child: OnboardingChip(
                        label: longString,
                        selected: true,
                        icon: Icons.star,
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester.takeException(),
            isNull,
            reason:
                'OnboardingChip threw an exception under 200% font scale with long string',
          );
          expect(find.byType(OnboardingChip), findsOneWidget);
        },
      );

      testWidgets(
        'OnboardingActionPill withstands 200% font scale and long string in narrow container',
        (tester) async {
          const longString =
              'Adversarial_Action_Pill_Label_Under_200_Percent_Text_Scale_Factor_Extreme_Length_Test_Case';

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 160,
                      child: OnboardingActionPill(
                        label: longString,
                        selected: true,
                        icon: Icons.bolt,
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester.takeException(),
            isNull,
            reason: 'OnboardingActionPill overflowed or threw exception',
          );
          expect(find.byType(OnboardingActionPill), findsOneWidget);
        },
      );

      testWidgets(
        'OnboardingChoiceTile withstands 200% font scale with massive title and subtitle',
        (tester) async {
          const longTitle =
              'Adversarial Choice Tile Title That Is Unusually Extended Beyond Standard Component Width Requirements';
          const longSubtitle =
              'Adversarial Subtitle With Multiple Words Explaining Details Under Extremely High Display Scale Settings';

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 260,
                      child: OnboardingChoiceTile(
                        title: longTitle,
                        subtitle: longSubtitle,
                        icon: Icons.check_circle,
                        selected: true,
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester.takeException(),
            isNull,
            reason: 'OnboardingChoiceTile threw layout overflow exception',
          );
          expect(find.byType(OnboardingChoiceTile), findsOneWidget);
        },
      );

      testWidgets(
        'Multiple chip/pill flex row renders under 200% font scale without render flex overflow',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
                child: Scaffold(
                  body: SizedBox(
                    width: 320,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        OnboardingChip(
                          label: 'Very Long Option Pill 1',
                          selected: true,
                        ),
                        OnboardingChip(
                          label: 'Very Long Option Pill 2',
                          selected: false,
                        ),
                        OnboardingActionPill(
                          label: 'Action Button 1',
                          selected: true,
                        ),
                        OnboardingActionPill(
                          label: 'Action Button 2',
                          selected: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          expect(find.byType(OnboardingChip), findsNWidgets(2));
          expect(find.byType(OnboardingActionPill), findsNWidgets(2));
        },
      );
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 2. Rapid Back-to-Back Toast Error Triggers & FIFO Queue Verification
    // ──────────────────────────────────────────────────────────────────────────
    group(
      'Adversarial Test 2: Rapid Toast Error Triggers & FIFO Queue Management',
      () {
        test(
          'ToastQueueNotifier processes rapid triggers in exact FIFO sequence',
          () {
            final container = ProviderContainer();
            addTearDown(container.dispose);

            final notifier = container.read(toastQueueProvider.notifier);
            expect(container.read(toastQueueProvider).current, isNull);

            // Trigger 5 errors back-to-back in rapid succession
            notifier.showToast('Error 1: Network failure');
            notifier.showToast('Error 2: Invalid input value');
            notifier.showToast('Error 3: Storage quota exceeded');
            notifier.showToast('Error 4: Session timeout');
            notifier.showToast('Error 5: Server internal error');

            final state = container.read(toastQueueProvider);
            expect(state.current?.message, equals('Error 1: Network failure'));
            expect(state.queue.length, equals(4));

            final queuedMessages = state.queue.map((e) => e.message).toList();
            expect(
              queuedMessages,
              equals([
                'Error 2: Invalid input value',
                'Error 3: Storage quota exceeded',
                'Error 4: Session timeout',
                'Error 5: Server internal error',
              ]),
            );
          },
        );

        test(
          'ToastQueueNotifier deduplicates rapid identical toast requests',
          () {
            final container = ProviderContainer();
            addTearDown(container.dispose);

            final notifier = container.read(toastQueueProvider.notifier);

            notifier.showToast('Duplicate Error Message');
            notifier.showToast(
              'Duplicate Error Message',
            ); // Should be ignored (matches current)
            notifier.showToast('Unique Error Message');
            notifier.showToast(
              'Duplicate Error Message',
            ); // Should be ignored (matches queued)

            final state = container.read(toastQueueProvider);
            expect(state.current?.message, equals('Duplicate Error Message'));
            expect(state.queue.length, equals(1));
            expect(state.queue.first.message, equals('Unique Error Message'));
          },
        );

        test(
          'ToastQueueNotifier dismissCurrent advances FIFO queue sequentially to empty',
          () async {
            final container = ProviderContainer();
            addTearDown(container.dispose);

            final notifier = container.read(toastQueueProvider.notifier);

            notifier.showToast('Toast A');
            notifier.showToast('Toast B');
            notifier.showToast('Toast C');

            expect(
              container.read(toastQueueProvider).current?.message,
              equals('Toast A'),
            );

            // Dismiss Toast A -> Toast B becomes active after 150ms delay
            notifier.dismissCurrent();
            await Future.delayed(const Duration(milliseconds: 200));
            expect(
              container.read(toastQueueProvider).current?.message,
              equals('Toast B'),
            );
            expect(container.read(toastQueueProvider).queue.length, equals(1));

            // Dismiss Toast B -> Toast C becomes active after 150ms delay
            notifier.dismissCurrent();
            await Future.delayed(const Duration(milliseconds: 200));
            expect(
              container.read(toastQueueProvider).current?.message,
              equals('Toast C'),
            );
            expect(container.read(toastQueueProvider).queue, isEmpty);

            // Dismiss Toast C -> Queue is fully empty
            notifier.dismissCurrent();
            await Future.delayed(const Duration(milliseconds: 200));
            expect(container.read(toastQueueProvider).current, isNull);
            expect(container.read(toastQueueProvider).queue, isEmpty);
          },
        );

        test(
          'ToastQueueNotifier clearAll immediately purges active and queued toasts',
          () {
            final container = ProviderContainer();
            addTearDown(container.dispose);

            final notifier = container.read(toastQueueProvider.notifier);

            notifier.showToast('Alert 1');
            notifier.showToast('Alert 2');
            notifier.showToast('Alert 3');

            expect(container.read(toastQueueProvider).current, isNotNull);
            expect(container.read(toastQueueProvider).queue.length, equals(2));

            notifier.clearAll();

            expect(container.read(toastQueueProvider).current, isNull);
            expect(container.read(toastQueueProvider).queue, isEmpty);
          },
        );

        testWidgets(
          'Toast error banner renders correctly in OnboardingStepShell',
          (tester) async {
            await tester.pumpWidget(
              MaterialApp(
                home: OnboardingStepShell(
                  currentPage: 1,
                  pageOffset: 1.0,
                  completedSteps: const [true, true, false],
                  validationMessage: 'Adversarial Toast Error Banner',
                  onDotTap: (_) {},
                  onIndicatorDraggedTo: (_) {},
                  onNext: () {},
                  onSave: null,
                  showSave: false,
                  isSaving: false,
                  isSaved: false,
                  saveEnabled: true,
                  ctaLabel: 'Continue',
                  ctaEnabled: true,
                  ctaLoading: false,
                  child: const Text('Shell Body Content'),
                ),
              ),
            );

            await tester.pump(const Duration(milliseconds: 300));
            expect(find.text('Adversarial Toast Error Banner'), findsOneWidget);
          },
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 3. Back Swipe Gesture Handling on Dirty vs Clean Draft Steps
    // ──────────────────────────────────────────────────────────────────────────
    group(
      'Adversarial Test 3: Back Swipe / Pop Gesture on Dirty vs Clean Draft Steps',
      () {
        testWidgets('Pop gesture on DIRTY step triggers Unsaved Changes dialog', (
          tester,
        ) async {
          final dirtyDraft = const OnboardingDraft().copyWith(
            currentStep: 1,
            stepCompleted: List.generate(15, (i) => i < 1),
          );

          final container = ProviderContainer(
            overrides: [
              mockOnboardingProvider.overrideWith((_) {
                final notifier = MockOnboardingNotifier()
                  ..loadSeedData(dirtyDraft);
                notifier.setStepDirty(1, true);
                return notifier;
              }),
              authProvider.overrideWith((ref) => _FakeAuthNotifier()),
              onboardingRepositoryProvider.overrideWithValue(
                _FakeOnboardingRepository(),
              ),
            ],
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: OnboardingFlow()),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
          expect(popScopeFinder, findsOneWidget);

          final dynamic popScopeWidget = tester.widget(popScopeFinder);
          // Invoke pop gesture callback twice if needed to bypass primary focus unfocus
          popScopeWidget.onPopInvokedWithResult?.call(false, null);
          await tester.pump();
          popScopeWidget.onPopInvokedWithResult?.call(false, null);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Expect Unsaved Changes dialog to be visible
          expect(find.text('Unsaved Changes'), findsOneWidget);
          expect(
            find.text(
              'You have unsaved changes on this step. Do you want to save or discard before going back?',
            ),
            findsOneWidget,
          );
          expect(find.text('Discard'), findsOneWidget);
          expect(find.text('Save & Go Back'), findsOneWidget);

          // Tap Discard -> returns true and pops dialog
          await tester.tap(find.text('Discard'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('Unsaved Changes'), findsNothing);
        });

        testWidgets(
          'Pop gesture on CLEAN step navigates back directly without Unsaved Changes dialog',
          (tester) async {
            final cleanDraft = const OnboardingDraft().copyWith(
              currentStep: 1,
              stepCompleted: List.generate(15, (i) => i < 1),
            );

            final container = ProviderContainer(
              overrides: [
                mockOnboardingProvider.overrideWith((_) {
                  final notifier = MockOnboardingNotifier()
                    ..loadSeedData(cleanDraft);
                  notifier.setStepDirty(1, false);
                  return notifier;
                }),
                authProvider.overrideWith((ref) => _FakeAuthNotifier()),
                onboardingRepositoryProvider.overrideWithValue(
                  _FakeOnboardingRepository(),
                ),
              ],
            );

            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: const MaterialApp(home: OnboardingFlow()),
              ),
            );

            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
            expect(popScopeFinder, findsOneWidget);

            final dynamic popScopeWidget = tester.widget(popScopeFinder);
            popScopeWidget.onPopInvokedWithResult?.call(false, null);
            await tester.pump();
            popScopeWidget.onPopInvokedWithResult?.call(false, null);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            // Verify Unsaved Changes dialog is NOT shown
            expect(find.text('Unsaved Changes'), findsNothing);

            // Verify page controller navigated back to step 0
            final onboardingState = container.read(mockOnboardingProvider);
            expect(onboardingState.currentStep, equals(0));
          },
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 4. Dark Mode Theme Brightness Switching & Token Consistency
    // ──────────────────────────────────────────────────────────────────────────
    group(
      'Adversarial Test 4: Dark Mode Theme Brightness Switching & Tokens',
      () {
        testWidgets(
          'Onboarding widgets adapt theme brightness switching dynamically',
          (tester) async {
            final themeNotifier = ValueNotifier<ThemeData>(
              OptivusTheme.lightTheme,
            );

            await tester.pumpWidget(
              ValueListenableBuilder<ThemeData>(
                valueListenable: themeNotifier,
                builder: (context, theme, child) {
                  return MaterialApp(
                    home: Theme(
                      data: theme,
                      child: Scaffold(
                        body: Column(
                          children: const [
                            OnboardingGlassCard(
                              child: Text('Glass Card Content'),
                            ),
                            OnboardingChip(
                              label: 'Dark Mode Chip',
                              selected: false,
                            ),
                            OnboardingActionPill(
                              label: 'Dark Mode Pill',
                              selected: true,
                            ),
                            OnboardingChoiceTile(
                              title: 'Choice Title',
                              subtitle: 'Choice Subtitle',
                              icon: Icons.star,
                              selected: false,
                            ),
                            LiquidPrimaryButton(label: 'Liquid Button'),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );

            await tester.pump(const Duration(milliseconds: 300));

            // Initial Light Mode Check
            BuildContext contextLight = tester.element(
              find.text('Glass Card Content'),
            );
            expect(Theme.of(contextLight).brightness, equals(Brightness.light));
            expect(tester.takeException(), isNull);

            // Switch Theme to Dark Mode dynamically
            themeNotifier.value = OptivusTheme.darkTheme;
            await tester.pump(const Duration(milliseconds: 300));

            // Re-query context after rebuild
            BuildContext contextDark = tester.element(
              find.text('Glass Card Content'),
            );
            expect(Theme.of(contextDark).brightness, equals(Brightness.dark));
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'Switching theme brightness to dark mode caused rendering exception',
            );

            // Check text colors and tokens in dark theme
            final displayLargeColor = Theme.of(
              contextDark,
            ).textTheme.displayLarge?.color;
            expect(displayLargeColor, equals(OptivusColors.textPrimaryDark));

            // Switch Theme back to Light Mode dynamically
            themeNotifier.value = OptivusTheme.lightTheme;
            await tester.pump(const Duration(milliseconds: 300));

            BuildContext contextLightAgain = tester.element(
              find.text('Glass Card Content'),
            );
            expect(
              Theme.of(contextLightAgain).brightness,
              equals(Brightness.light),
            );
            expect(tester.takeException(), isNull);
          },
        );

        test(
          'OptivusTheme darkTheme defines valid contrast dark color palette',
          () {
            final darkTheme = OptivusTheme.darkTheme;
            expect(darkTheme.brightness, equals(Brightness.dark));
            expect(
              darkTheme.colorScheme.surface,
              equals(const Color(0xFF1E202A)),
            );
          },
        );
      },
    );
  });
}
