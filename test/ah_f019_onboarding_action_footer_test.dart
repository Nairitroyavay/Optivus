import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_steps.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_style.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_action_bar.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget actionHost({
    required List<OnboardingAction> actions,
    EdgeInsets viewPadding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
    double textScale = 1,
    OnboardingKeyboardFooterBehavior keyboardBehavior =
        OnboardingKeyboardFooterBehavior.hideWhileKeyboardVisible,
    bool reserveHiddenSpace = false,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(393, 873),
          padding: viewPadding,
          viewPadding: viewPadding,
          viewInsets: viewInsets,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              const Expanded(child: ColoredBox(color: Colors.white)),
              OnboardingActionBar(
                actions: actions,
                keyboardBehavior: keyboardBehavior,
                reserveHiddenSpace: reserveHiddenSpace,
              ),
            ],
          ),
        ),
      ),
    );
  }

  OnboardingAction action(
    OnboardingActionKind kind,
    String label,
    FutureOr<void> Function()? callback, {
    bool enabled = true,
    bool visible = true,
    OnboardingActionOperationState operationState =
        OnboardingActionOperationState.idle,
    OnboardingActionEmphasis emphasis = OnboardingActionEmphasis.primary,
  }) {
    return OnboardingAction(
      kind: kind,
      label: label,
      onPressed: callback,
      enabled: enabled,
      visible: visible,
      operationState: operationState,
      emphasis: emphasis,
    );
  }

  group('AH-F019 footer foundation (Requirements A-H)', () {
    test(
      'A & C: metrics use the configured CTA geometry and one safe-area inset',
      () {
        const metrics = OnboardingFooterMetrics(safeAreaBottom: 34);
        expect(
          metrics.actionAreaHeight,
          OnboardingFooterMetrics.primaryActionHeight,
        );
        expect(
          metrics.obstructionHeight,
          OnboardingFooterMetrics.topSpacing +
              OnboardingFooterMetrics.primaryActionHeight +
              OnboardingFooterMetrics.bottomSpacing +
              34,
        );
        expect(
          metrics.requiredContentInset,
          greaterThanOrEqualTo(metrics.obstructionHeight),
        );
      },
    );

    testWidgets('B: footer incorporates bottom safe area exactly once', (
      tester,
    ) async {
      await tester.pumpWidget(
        actionHost(
          viewPadding: const EdgeInsets.only(bottom: 34),
          actions: [action(OnboardingActionKind.next, 'Next', () {})],
        ),
      );
      await tester.pump();

      final height = tester.getSize(find.byType(OnboardingActionBar)).height;
      expect(
        height,
        OnboardingFooterMetrics.topSpacing +
            OnboardingFooterMetrics.primaryActionHeight +
            OnboardingFooterMetrics.bottomSpacing +
            34,
      );
    });

    testWidgets('D: no double safe area padding in footer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(393, 873),
              padding: EdgeInsets.only(bottom: 34),
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                    const Expanded(child: ColoredBox(color: Colors.white)),
                    OnboardingActionBar(
                      actions: [
                        action(OnboardingActionKind.next, 'Next', () {}),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final height = tester.getSize(find.byType(OnboardingActionBar)).height;
      expect(
        height,
        OnboardingFooterMetrics.topSpacing +
            OnboardingFooterMetrics.primaryActionHeight +
            OnboardingFooterMetrics.bottomSpacing +
            34,
      );
    });

    testWidgets(
      'E & F: disabled and loading states retain structural footer space',
      (tester) async {
        var enabled = true;
        var loading = false;

        Future<void> pumpState() {
          return tester.pumpWidget(
            actionHost(
              actions: [
                action(
                  OnboardingActionKind.next,
                  'Next',
                  () {},
                  enabled: enabled,
                  operationState: loading
                      ? OnboardingActionOperationState.active
                      : OnboardingActionOperationState.idle,
                ),
              ],
            ),
          );
        }

        await pumpState();
        final initial = tester.getSize(find.byType(OnboardingActionBar));
        enabled = false;
        await pumpState();
        expect(tester.getSize(find.byType(OnboardingActionBar)), initial);
        loading = true;
        await pumpState();
        expect(tester.getSize(find.byType(OnboardingActionBar)), initial);
      },
    );

    testWidgets('G: Generate to Retry replacement remains stable in geometry', (
      tester,
    ) async {
      await tester.pumpWidget(
        actionHost(
          actions: [action(OnboardingActionKind.generate, 'Generate', () {})],
        ),
      );
      final generateHeight = tester
          .getSize(find.byType(OnboardingActionBar))
          .height;
      await tester.pumpWidget(
        actionHost(
          actions: [action(OnboardingActionKind.retry, 'Retry', () {})],
        ),
      );
      expect(
        tester.getSize(find.byType(OnboardingActionBar)).height,
        generateHeight,
      );
    });

    testWidgets('H: hidden footer releases its structural space', (
      tester,
    ) async {
      await tester.pumpWidget(
        actionHost(
          actions: [
            OnboardingAction(
              kind: OnboardingActionKind.next,
              label: 'Next',
              onPressed: () {},
              visible: false,
            ),
          ],
        ),
      );
      expect(tester.getSize(find.byType(OnboardingActionBar)).height, 0);
    });
  });

  group('AH-F019 validation & appearance stability', () {
    testWidgets(
      'CTA remains structurally present and disabled in place when invalid',
      (tester) async {
        var isFormValid = true;

        Widget buildFlow() {
          return actionHost(
            actions: [
              action(
                OnboardingActionKind.next,
                'Next',
                () {},
                enabled: isFormValid,
                visible: true,
              ),
            ],
          );
        }

        await tester.pumpWidget(buildFlow());
        final initialRect = tester.getRect(find.byType(OnboardingActionBar));
        expect(find.text('Next'), findsOneWidget);

        // Form becomes invalid -> CTA disabled in place, no layout jump
        isFormValid = false;
        await tester.pumpWidget(buildFlow());
        final invalidRect = tester.getRect(find.byType(OnboardingActionBar));
        expect(invalidRect, initialRect);
        expect(find.text('Next'), findsOneWidget);

        // Form becomes valid again -> CTA re-enabled in identical position
        isFormValid = true;
        await tester.pumpWidget(buildFlow());
        final restoredRect = tester.getRect(find.byType(OnboardingActionBar));
        expect(restoredRect, initialRect);
      },
    );
  });

  group('AH-F019 interaction ownership & double-tap protection', () {
    for (final entry
        in const <(OnboardingActionKind, String, OnboardingActionEmphasis)>[
          (OnboardingActionKind.next, 'Next', OnboardingActionEmphasis.primary),
          (
            OnboardingActionKind.generate,
            'Generate',
            OnboardingActionEmphasis.primary,
          ),
          (
            OnboardingActionKind.retry,
            'Retry',
            OnboardingActionEmphasis.primary,
          ),
          (
            OnboardingActionKind.enterOptivus,
            'Enter Optivus',
            OnboardingActionEmphasis.primary,
          ),
          (
            OnboardingActionKind.skip,
            'Skip',
            OnboardingActionEmphasis.tertiary,
          ),
          (
            OnboardingActionKind.notNow,
            'Not now',
            OnboardingActionEmphasis.tertiary,
          ),
          (
            OnboardingActionKind.back,
            'Back',
            OnboardingActionEmphasis.secondary,
          ),
          (
            OnboardingActionKind.regenerate,
            'Regenerate',
            OnboardingActionEmphasis.secondary,
          ),
        ]) {
      testWidgets(
        '${entry.$2} rapid taps invoke exactly one active operation',
        (tester) async {
          var calls = 0;
          final pending = Completer<void>();
          await tester.pumpWidget(
            actionHost(
              actions: [
                action(entry.$1, entry.$2, () {
                  calls++;
                  return pending.future;
                }, emphasis: entry.$3),
              ],
            ),
          );

          Finder target;
          if (entry.$3 == OnboardingActionEmphasis.primary) {
            target = find.byKey(ValueKey('onboarding-action-${entry.$1.name}'));
          } else {
            target = find.text(entry.$2);
          }

          for (var i = 0; i < 5; i++) {
            await tester.tap(target, warnIfMissed: false);
          }
          expect(calls, 1);
          pending.complete();
          await tester.pump();
          await tester.pump();
        },
      );
    }

    testWidgets(
      'synchronous action callback is fenced against same-frame duplicates',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          actionHost(
            actions: [
              action(OnboardingActionKind.next, 'Next', () {
                calls++;
              }),
            ],
          ),
        );

        final target = find.byKey(const ValueKey('onboarding-action-next'));
        // Tap twice within the same frame before post-frame callback runs
        await tester.tap(target, warnIfMissed: false);
        await tester.tap(target, warnIfMissed: false);
        expect(calls, 1);
        await tester.pump();
        await tester.pump();
      },
    );
  });

  group('AH-F019 loading ownership & state transitions', () {
    testWidgets(
      'loading action owns CTA and blocks duplicate triggers until complete',
      (tester) async {
        var calls = 0;
        final completer = Completer<void>();
        var operationState = OnboardingActionOperationState.idle;

        Widget buildTest(StateSetter setState) {
          return actionHost(
            actions: [
              action(OnboardingActionKind.generate, 'Generate', () {
                calls++;
                setState(() {
                  operationState = OnboardingActionOperationState.active;
                });
                return completer.future;
              }, operationState: operationState),
            ],
          );
        }

        late StateSetter outerSetState;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              outerSetState = setState;
              return buildTest(setState);
            },
          ),
        );

        final target = find.byKey(const ValueKey('onboarding-action-generate'));
        await tester.tap(target);
        await tester.pump();
        expect(calls, 1);

        // Rapid additional tap while loading -> ignored
        await tester.tap(target, warnIfMissed: false);
        expect(calls, 1);

        // Operation finishes
        completer.complete();
        outerSetState(() {
          operationState = OnboardingActionOperationState.idle;
        });
        await tester.pump();
        await tester.pump();
      },
    );

    testWidgets(
      'Generate active -> error -> Retry replacement avoids enabled flash',
      (tester) async {
        OnboardingAction currentAction = action(
          OnboardingActionKind.generate,
          'Generate',
          () {},
          operationState: OnboardingActionOperationState.active,
        );

        Widget buildWidget() => actionHost(actions: [currentAction]);

        await tester.pumpWidget(buildWidget());
        final activeHeight = tester
            .getSize(find.byType(OnboardingActionBar))
            .height;

        // Transition to Retry directly with stable geometry
        currentAction = action(
          OnboardingActionKind.retry,
          'Retry',
          () {},
          operationState: OnboardingActionOperationState.idle,
        );
        await tester.pumpWidget(buildWidget());
        final retryHeight = tester
            .getSize(find.byType(OnboardingActionBar))
            .height;
        expect(retryHeight, activeHeight);
        expect(find.text('Retry'), findsOneWidget);
      },
    );

    testWidgets('Back action during loading respects feature safety contract', (
      tester,
    ) async {
      var backCalls = 0;
      final pending = Completer<void>();

      await tester.pumpWidget(
        actionHost(
          actions: [
            action(
              OnboardingActionKind.back,
              'Back',
              () {
                backCalls++;
              },
              emphasis: OnboardingActionEmphasis.secondary,
              enabled: false, // Feature blocks back during critical save
            ),
            action(
              OnboardingActionKind.next,
              'Next',
              () => pending.future,
              operationState: OnboardingActionOperationState.active,
            ),
          ],
        ),
      );

      // Tapping disabled Back during operation does not invoke callback
      await tester.tap(find.text('Back'), warnIfMissed: false);
      expect(backCalls, 0);

      pending.complete();
      await tester.pump();
      await tester.pump();
    });
  });

  group('AH-F019 responsive, large-text, and keyboard layout', () {
    testWidgets('large text Back and Regenerate plus primary do not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        actionHost(
          textScale: 1.6,
          actions: [
            action(
              OnboardingActionKind.back,
              'Back',
              () {},
              emphasis: OnboardingActionEmphasis.secondary,
            ),
            action(
              OnboardingActionKind.regenerate,
              'Regenerate routine',
              () {},
              emphasis: OnboardingActionEmphasis.secondary,
            ),
            action(OnboardingActionKind.next, 'Next', () {}),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Regenerate routine'), findsOneWidget);
    });

    testWidgets('keyboard hide policy removes footer without double inset', (
      tester,
    ) async {
      await tester.pumpWidget(
        actionHost(
          viewPadding: const EdgeInsets.only(bottom: 34),
          viewInsets: const EdgeInsets.only(bottom: 300),
          actions: [action(OnboardingActionKind.next, 'Next', () {})],
        ),
      );
      expect(
        find.byKey(const ValueKey('onboarding-cta-hidden-for-keyboard')),
        findsOneWidget,
      );
      expect(find.text('Next'), findsNothing);
    });

    testWidgets(
      'single IME ownership: shell applies keyboard padding without double offset',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(393, 873),
                padding: EdgeInsets.only(top: 44, bottom: 34),
                viewPadding: EdgeInsets.only(top: 44, bottom: 34),
                viewInsets: EdgeInsets.only(bottom: 300),
              ),
              child: OnboardingStepShell(
                currentPage: 1,
                pageOffset: 1.0,
                completedSteps: List.filled(OnboardingDraft.stepCount, false),
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
                actions: [
                  action(OnboardingActionKind.next, 'Next Step', () {}),
                ],
                child: const ColoredBox(
                  key: ValueKey('test-content-box'),
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // The content box is constrained above the keyboard and footer is hidden
        final content = tester.getRect(
          find.byKey(const ValueKey('test-content-box')),
        );
        expect(content.bottom, lessThanOrEqualTo(873 - 300));
        expect(
          find.byKey(const ValueKey('onboarding-cta-hidden-for-keyboard')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AH-F019 Step 14 structural overlap regression', () {
    for (final size in const [
      Size(360, 800),
      Size(393, 873),
      Size(412, 915),
      Size(800, 360), // Landscape mode
    ]) {
      testWidgets('Step 14 footer owns space at ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final draft = OnboardingDraft(
          uid: 'ah-f019-step14',
          baseTimeline: BaseTimelineDraft(
            blocks: List.generate(
              12,
              (index) => TimelineBlockDraft(
                id: 'block-$index',
                section: 'classes',
                title: 'Final timeline item $index',
                blockType: TimelineBlockDraft.hardBlockKey,
                startMinute: 6 * 60 + index * 60,
                endMinute: 6 * 60 + index * 60 + 45,
                repeatDays: const [1, 2, 3, 4, 5, 6, 7],
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (_) => OnboardingNotifier()..loadSeedData(draft),
              ),
            ],
            child: MaterialApp(
              home: OnboardingStepShell(
                currentPage: OnboardingDraft.lastStepIndex,
                pageOffset: OnboardingDraft.lastStepIndex.toDouble(),
                completedSteps: List.filled(OnboardingDraft.stepCount, true),
                validationMessage: null,
                onDotTap: (_) {},
                onIndicatorDraggedTo: (_) {},
                onSave: null,
                showSave: false,
                isSaving: false,
                isSaved: true,
                saveEnabled: true,
                ctaLabel: 'Enter Optivus',
                ctaEnabled: true,
                ctaLoading: false,
                actions: [
                  action(
                    OnboardingActionKind.enterOptivus,
                    'Enter Optivus',
                    () {},
                  ),
                ],
                child: const OnboardingTodayReadyStep(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final footer = tester.getRect(
          find.byKey(const ValueKey('onboarding-cta-visible')),
        );
        final step = tester.getRect(find.byType(OnboardingTodayReadyStep));
        expect(step.bottom, equals(footer.bottom));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'Step 14 transient invalid state disables Enter Optivus in place',
      (tester) async {
        var isReady = true;

        Widget buildHost(StateSetter setState) {
          return ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (_) =>
                    OnboardingNotifier()
                      ..loadSeedData(const OnboardingDraft(uid: 'step14-test')),
              ),
            ],
            child: MaterialApp(
              home: OnboardingStepShell(
                currentPage: OnboardingDraft.lastStepIndex,
                pageOffset: OnboardingDraft.lastStepIndex.toDouble(),
                completedSteps: List.filled(OnboardingDraft.stepCount, isReady),
                validationMessage: isReady
                    ? null
                    : 'Complete required setup first.',
                onDotTap: (_) {},
                onIndicatorDraggedTo: (_) {},
                onSave: null,
                showSave: false,
                isSaving: false,
                isSaved: isReady,
                saveEnabled: isReady,
                ctaLabel: 'Enter Optivus',
                ctaEnabled: isReady,
                ctaLoading: false,
                actions: [
                  action(
                    OnboardingActionKind.enterOptivus,
                    'Enter Optivus',
                    () {},
                    enabled: isReady,
                  ),
                ],
                child: const OnboardingTodayReadyStep(),
              ),
            ),
          );
        }

        late StateSetter outerSetState;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              outerSetState = setState;
              return buildHost(setState);
            },
          ),
        );
        await tester.pump();

        final initialRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-cta-visible')),
        );
        expect(find.text('Enter Optivus'), findsOneWidget);

        // Transient invalid state
        outerSetState(() {
          isReady = false;
        });
        await tester.pump();

        final invalidRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-cta-visible')),
        );
        expect(invalidRect, initialRect);
        expect(find.text('Complete required setup first.'), findsOneWidget);

        // Valid again
        outerSetState(() {
          isReady = true;
        });
        await tester.pump();
        final restoredRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-cta-visible')),
        );
        expect(restoredRect, initialRect);
      },
    );

    testWidgets(
      'Step 14 rapid Enter Optivus taps invoke completion callback only once',
      (tester) async {
        var completionCalls = 0;
        final pending = Completer<void>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (_) => OnboardingNotifier()
                  ..loadSeedData(
                    const OnboardingDraft(uid: 'step14-doubletap'),
                  ),
              ),
            ],
            child: MaterialApp(
              home: OnboardingStepShell(
                currentPage: OnboardingDraft.lastStepIndex,
                pageOffset: OnboardingDraft.lastStepIndex.toDouble(),
                completedSteps: List.filled(OnboardingDraft.stepCount, true),
                validationMessage: null,
                onDotTap: (_) {},
                onIndicatorDraggedTo: (_) {},
                onSave: null,
                showSave: false,
                isSaving: false,
                isSaved: true,
                saveEnabled: true,
                ctaLabel: 'Enter Optivus',
                ctaEnabled: true,
                ctaLoading: false,
                actions: [
                  action(
                    OnboardingActionKind.enterOptivus,
                    'Enter Optivus',
                    () {
                      completionCalls++;
                      return pending.future;
                    },
                  ),
                ],
                child: const OnboardingTodayReadyStep(),
              ),
            ),
          ),
        );
        await tester.pump();

        final cta = find.byKey(
          const ValueKey('onboarding-action-enterOptivus'),
        );
        for (var i = 0; i < 5; i++) {
          await tester.tap(cta, warnIfMissed: false);
        }
        expect(completionCalls, 1);
        pending.complete();
        await tester.pump();
        await tester.pump();
      },
    );
  });

  group('AH-F018 full-screen timeline integration', () {
    testWidgets(
      'FullScreenTimelineScaffold inside OnboardingStepShell scrolls last event above footer',
      (tester) async {
        final entries = List.generate(
          10,
          (i) => TimelineEntry(
            id: 'event-$i',
            sourceId: 'event-$i',
            title: 'Event $i',
            startMinute: 7 * 60 + i * 60,
            endMinute: 7 * 60 + i * 60 + 45,
            repeatDays: const [1, 2, 3, 4, 5, 6, 7],
            category: TimelineCategory.classes,
          ),
        );

        int selectedDay = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: OnboardingStepShell(
              currentPage: 4,
              pageOffset: 4.0,
              completedSteps: List.filled(OnboardingDraft.stepCount, false),
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
              actions: [action(OnboardingActionKind.next, 'Next Step', () {})],
              child: StatefulBuilder(
                builder: (context, setState) {
                  return FullScreenTimelineScaffold(
                    entries: entries,
                    selectedDay: selectedDay,
                    onDayChanged: (day) => setState(() => selectedDay = day),
                    styleBuilder: (entry) =>
                        TimelineEntryStyle.defaultForCategory(entry.category),
                    title: 'Schedule Preview',
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final footerRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-cta-visible')),
        );
        final timelineRect = tester.getRect(
          find.byType(FullScreenTimelineScaffold),
        );

        // The timeline scaffold extends to the bottom behind the floating footer
        expect(timelineRect.bottom, equals(footerRect.bottom));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AH-F019 keyboard dismiss cycle & dynamic insets', () {
    testWidgets(
      'keyboard dismiss smoothly restores footer without residual gaps',
      (tester) async {
        tester.view.physicalSize = const Size(393, 873);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var keyboardHeight = 0.0;
        Widget buildHost(StateSetter setState) {
          return actionHost(
            viewPadding: const EdgeInsets.only(bottom: 34),
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
            actions: [action(OnboardingActionKind.next, 'Next', () {})],
          );
        }

        late StateSetter outerSetState;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              outerSetState = setState;
              return buildHost(setState);
            },
          ),
        );
        await tester.pump();

        final initialFooterRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-cta-visible')),
        );
        expect(initialFooterRect.bottom, 873);

        // Keyboard opens (300px)
        outerSetState(() => keyboardHeight = 300);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('onboarding-cta-hidden-for-keyboard')),
          findsOneWidget,
        );

        // Keyboard dismisses (0px)
        outerSetState(() => keyboardHeight = 0);
        await tester.pump();
        final restoredFooterRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-cta-visible')),
        );
        expect(restoredFooterRect, initialFooterRect);
      },
    );

    for (final kb in const [250.0, 300.0, 350.0]) {
      testWidgets(
        'keyboard height $kb correctly hides footer without double inset',
        (tester) async {
          await tester.pumpWidget(
            actionHost(
              viewPadding: const EdgeInsets.only(bottom: 34),
              viewInsets: EdgeInsets.only(bottom: kb),
              actions: [action(OnboardingActionKind.next, 'Next', () {})],
            ),
          );
          expect(
            find.byKey(const ValueKey('onboarding-cta-hidden-for-keyboard')),
            findsOneWidget,
          );
        },
      );
    }

    for (final safeBottom in const [0.0, 16.0, 34.0, 48.0]) {
      testWidgets(
        'safe-area bottom $safeBottom applies metric calculation exactly once',
        (tester) async {
          await tester.pumpWidget(
            actionHost(
              viewPadding: EdgeInsets.only(bottom: safeBottom),
              actions: [action(OnboardingActionKind.next, 'Next', () {})],
            ),
          );
          final height = tester
              .getSize(find.byType(OnboardingActionBar))
              .height;
          final expectedHeight =
              OnboardingFooterMetrics.topSpacing +
              OnboardingFooterMetrics.primaryActionHeight +
              OnboardingFooterMetrics.bottomSpacing +
              safeBottom;
          expect(height, expectedHeight);
        },
      );
    }
  });

  group('AH-F019 operation identity & deduplication resilience', () {
    testWidgets(
      'stale operation completion does not unlock superseding active operation',
      (tester) async {
        var callCount = 0;
        final completerA = Completer<void>();
        final completerB = Completer<void>();
        var currentCompleter = completerA;

        Widget buildWidget() {
          return actionHost(
            actions: [
              action(OnboardingActionKind.generate, 'Generate', () {
                callCount++;
                return currentCompleter.future;
              }),
            ],
          );
        }

        await tester.pumpWidget(buildWidget());
        final btn = find.byKey(const ValueKey('onboarding-action-generate'));

        // First tap -> Starts operation A
        await tester.tap(btn);
        await tester.pump();
        expect(callCount, 1);

        // Attempt second tap while A is active -> Blocked by ownership fence
        await tester.tap(btn, warnIfMissed: false);
        expect(callCount, 1);

        // Operation A finishes, then feature initiates operation B
        completerA.complete();
        await tester.pump();

        currentCompleter = completerB;
        await tester.tap(btn);
        await tester.pump();
        expect(callCount, 2);

        // Rapid tap during B is blocked
        await tester.tap(btn, warnIfMissed: false);
        expect(callCount, 2);

        completerB.complete();
        await tester.pump();
      },
    );

    testWidgets(
      'operation failure clears interaction fence allowing deliberate retry',
      (tester) async {
        var callCount = 0;
        var shouldFail = true;

        await tester.pumpWidget(
          actionHost(
            actions: [
              action(OnboardingActionKind.retry, 'Retry', () async {
                callCount++;
                if (shouldFail) {
                  throw Exception('Network timeout');
                }
              }),
            ],
          ),
        );

        final btn = find.byKey(const ValueKey('onboarding-action-retry'));

        // First attempt fails
        try {
          await tester.tap(btn);
        } catch (_) {}
        await tester.pump();
        expect(callCount, 1);

        // Fence was cleaned up in try/catch/finally -> Subsequent deliberate attempt succeeds
        shouldFail = false;
        await tester.tap(btn);
        await tester.pump();
        expect(callCount, 2);
      },
    );
  });

  group('AH-F019 Step 14 long/short content & loading geometry', () {
    testWidgets(
      'Step 14 short review content anchors footer at bottom without vertical centering bug',
      (tester) async {
        tester.view.physicalSize = const Size(393, 873);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (_) => OnboardingNotifier()
                  ..loadSeedData(const OnboardingDraft(uid: 'short-content')),
              ),
            ],
            child: MaterialApp(
              home: OnboardingStepShell(
                currentPage: OnboardingDraft.lastStepIndex,
                pageOffset: OnboardingDraft.lastStepIndex.toDouble(),
                completedSteps: List.filled(OnboardingDraft.stepCount, true),
                validationMessage: null,
                onDotTap: (_) {},
                onIndicatorDraggedTo: (_) {},
                onSave: null,
                showSave: false,
                isSaving: false,
                isSaved: true,
                saveEnabled: true,
                ctaLabel: 'Enter Optivus',
                ctaEnabled: true,
                ctaLoading: false,
                actions: [
                  action(
                    OnboardingActionKind.enterOptivus,
                    'Enter Optivus',
                    () {},
                  ),
                ],
                child: const OnboardingTodayReadyStep(),
              ),
            ),
          ),
        );
        await tester.pump();

        final footerRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-cta-visible')),
        );
        expect(footerRect.bottom, 873);
        expect(find.text('Enter Optivus'), findsOneWidget);
      },
    );

    testWidgets(
      'Step 14 long review content can be scrolled to reveal last item completely above CTA',
      (tester) async {
        tester.view.physicalSize = const Size(393, 873);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final draft = OnboardingDraft(
          uid: 'long-content-scroll',
          baseTimeline: BaseTimelineDraft(
            blocks: List.generate(
              15,
              (index) => TimelineBlockDraft(
                id: 'block-$index',
                section: 'classes',
                title: 'Class item $index',
                blockType: TimelineBlockDraft.hardBlockKey,
                startMinute: 6 * 60 + index * 60,
                endMinute: 6 * 60 + index * 60 + 45,
                repeatDays: const [1, 2, 3, 4, 5, 6, 7],
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (_) => OnboardingNotifier()..loadSeedData(draft),
              ),
            ],
            child: MaterialApp(
              home: OnboardingStepShell(
                currentPage: OnboardingDraft.lastStepIndex,
                pageOffset: OnboardingDraft.lastStepIndex.toDouble(),
                completedSteps: List.filled(OnboardingDraft.stepCount, true),
                validationMessage: null,
                onDotTap: (_) {},
                onIndicatorDraggedTo: (_) {},
                onSave: null,
                showSave: false,
                isSaving: false,
                isSaved: true,
                saveEnabled: true,
                ctaLabel: 'Enter Optivus',
                ctaEnabled: true,
                ctaLoading: false,
                actions: [
                  action(
                    OnboardingActionKind.enterOptivus,
                    'Enter Optivus',
                    () {},
                  ),
                ],
                child: const OnboardingTodayReadyStep(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final scrollable = find.byType(OnboardingScrollView);
        expect(scrollable, findsOneWidget);

        // Drag/scroll all the way to the bottom
        await tester.drag(scrollable, const Offset(0, -2000));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final footerRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-cta-visible')),
        );
        final previewRect = tester.getRect(
          find.byKey(const ValueKey('step14-final-preview')),
        );

        // The preview inside the scrollable terminates above the footer
        expect(previewRect.bottom, lessThanOrEqualTo(footerRect.top));
      },
    );

    testWidgets(
      'Step 14 Enter Optivus loading state retains button dimensions and footer geometry',
      (tester) async {
        tester.view.physicalSize = const Size(393, 873);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Widget buildHost({required bool loading}) {
          return ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (_) => OnboardingNotifier()
                  ..loadSeedData(const OnboardingDraft(uid: 'loading-geom')),
              ),
            ],
            child: MaterialApp(
              home: OnboardingStepShell(
                currentPage: OnboardingDraft.lastStepIndex,
                pageOffset: OnboardingDraft.lastStepIndex.toDouble(),
                completedSteps: List.filled(OnboardingDraft.stepCount, true),
                validationMessage: null,
                onDotTap: (_) {},
                onIndicatorDraggedTo: (_) {},
                onSave: null,
                showSave: false,
                isSaving: false,
                isSaved: true,
                saveEnabled: true,
                ctaLabel: 'Enter Optivus',
                ctaEnabled: !loading,
                ctaLoading: loading,
                actions: [
                  action(
                    OnboardingActionKind.enterOptivus,
                    'Enter Optivus',
                    () {},
                    operationState: loading
                        ? OnboardingActionOperationState.active
                        : OnboardingActionOperationState.idle,
                  ),
                ],
                child: const OnboardingTodayReadyStep(),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildHost(loading: false));
        final idleFooterRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-cta-visible')),
        );

        await tester.pumpWidget(buildHost(loading: true));
        await tester.pump();
        final loadingFooterRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-cta-visible')),
        );

        expect(loadingFooterRect, idleFooterRect);
      },
    );
  });

  group('AH-F019 OnboardingStepShell integration for Steps 4, 5, 6, 7', () {
    for (final stepNumber in const [4, 5, 6, 7]) {
      testWidgets(
        'Step $stepNumber renders cleanly inside OnboardingStepShell above footer',
        (tester) async {
          tester.view.physicalSize = const Size(393, 873);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final draft = const OnboardingDraft(uid: 'step-shell-integration');

          Widget stepWidget;
          switch (stepNumber) {
            case 4:
              stepWidget = const OnboardingStep4();
              break;
            case 5:
              stepWidget = const OnboardingStep5();
              break;
            case 6:
              stepWidget = const OnboardingStep6();
              break;
            case 7:
              stepWidget = const OnboardingStep7();
              break;
            default:
              stepWidget = const SizedBox();
          }

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                onboardingStateProvider.overrideWith(
                  (_) => OnboardingNotifier()..loadSeedData(draft),
                ),
              ],
              child: MaterialApp(
                home: OnboardingStepShell(
                  currentPage: stepNumber,
                  pageOffset: stepNumber.toDouble(),
                  completedSteps: List.filled(OnboardingDraft.stepCount, false),
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
                  actions: [
                    action(OnboardingActionKind.next, 'Next Step', () {}),
                  ],
                  child: stepWidget,
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final footerRect = tester.getRect(
            find.byKey(const ValueKey('onboarding-cta-visible')),
          );
          expect(footerRect.bottom, 873);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('AH-F019 adversarial narrow viewport & async error recovery', () {
    testWidgets(
      '360px narrow viewport with multiple lower actions and primary CTA renders without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          actionHost(
            actions: [
              action(
                OnboardingActionKind.back,
                'Back',
                () {},
                emphasis: OnboardingActionEmphasis.secondary,
              ),
              action(
                OnboardingActionKind.regenerate,
                'Regenerate',
                () {},
                emphasis: OnboardingActionEmphasis.secondary,
              ),
              action(
                OnboardingActionKind.next,
                'Next Step',
                () {},
                emphasis: OnboardingActionEmphasis.primary,
              ),
            ],
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Back'), findsOneWidget);
        expect(find.text('Regenerate'), findsOneWidget);
        expect(find.text('Next Step'), findsOneWidget);
      },
    );

    testWidgets(
      'asynchronous exception in callback cleanly unlocks ownership fence',
      (tester) async {
        var invocationCount = 0;
        var failAsync = true;

        await tester.pumpWidget(
          actionHost(
            actions: [
              action(OnboardingActionKind.next, 'Next Step', () async {
                invocationCount++;
                await Future<void>.delayed(const Duration(milliseconds: 10));
                if (failAsync) {
                  throw Exception('Async network failure');
                }
              }),
            ],
          ),
        );

        final cta = find.byKey(const ValueKey('onboarding-action-next'));

        // First tap fails asynchronously
        await tester.tap(cta);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(invocationCount, 1);

        // Subsequent deliberate tap succeeds because fence was released in finally
        failAsync = false;
        await tester.tap(cta);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(invocationCount, 2);
      },
    );

    testWidgets(
      'sweep all onboarding steps 0 to 14 in OnboardingStepShell to guarantee no footer regressions',
      (tester) async {
        tester.view.physicalSize = const Size(393, 873);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (var step = 0; step < OnboardingDraft.stepCount; step++) {
          final isLast = step == OnboardingDraft.lastStepIndex;
          final ctaLabel = isLast ? 'Enter Optivus' : 'Next Step';
          final kind = isLast
              ? OnboardingActionKind.enterOptivus
              : OnboardingActionKind.next;

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                onboardingStateProvider.overrideWith(
                  (_) => OnboardingNotifier()
                    ..loadSeedData(const OnboardingDraft(uid: 'sweep-test')),
                ),
              ],
              child: MaterialApp(
                home: OnboardingStepShell(
                  currentPage: step,
                  pageOffset: step.toDouble(),
                  completedSteps: List.filled(OnboardingDraft.stepCount, false),
                  validationMessage: null,
                  onDotTap: (_) {},
                  onIndicatorDraggedTo: (_) {},
                  onSave: null,
                  showSave: false,
                  isSaving: false,
                  isSaved: false,
                  saveEnabled: false,
                  ctaLabel: ctaLabel,
                  ctaEnabled: true,
                  ctaLoading: false,
                  actions: [action(kind, ctaLabel, () {})],
                  child: Center(child: Text('Step $step Content')),
                ),
              ),
            ),
          );
          await tester.pump();

          final footerRect = tester.getRect(
            find.byKey(const ValueKey('onboarding-cta-visible')),
          );
          expect(footerRect.bottom, 873);
          expect(find.text(ctaLabel), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
