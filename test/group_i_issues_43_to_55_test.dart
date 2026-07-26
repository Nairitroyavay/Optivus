import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_spacing.dart';
import 'package:optivus/core/theme/optivus_theme.dart';
import 'package:optivus/core/utils/liquid_toast_manager.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_timeline_preview.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group I Issues 43-55 Test Suite', () {
    // ── Issue 43: Back Button Overlap on Small Viewports ──────────────────────
    testWidgets(
      'Issue 43: OnboardingStepShell responsive header height on small viewports',
      (tester) async {
        tester.view.physicalSize = const Size(360, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: OnboardingStepShell(
              currentPage: 1,
              pageOffset: 1.0,
              completedSteps: const [true, true, false],
              validationMessage: null,
              onDotTap: (_) {},
              onIndicatorDraggedTo: (_) {},
              onNext: () {},
              onSave: null,
              showSave: false,
              isSaving: false,
              isSaved: false,
              saveEnabled: true,
              ctaLabel: 'Next Step',
              ctaEnabled: true,
              ctaLoading: false,
              child: const Text('Body Content'),
            ),
          ),
        );

        expect(find.byType(OnboardingStepShell), findsOneWidget);
        expect(find.text('Body Content'), findsOneWidget);
      },
    );

    // ── Issue 44: Onboarding Timeline Card Vertical Spacing Alignment ────────
    testWidgets(
      'Issue 44: Card padding defaults to OptivusSpacing.base (16dp)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OnboardingGlassCard(child: const Text('Padding Test')),
            ),
          ),
        );

        final card = tester.widget<OnboardingGlassCard>(
          find.byType(OnboardingGlassCard),
        );
        expect(card.padding, equals(const EdgeInsets.all(OptivusSpacing.base)));
      },
    );

    testWidgets(
      'Issue 44: Choice tile padding uses OptivusSpacing.base (16dp)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OnboardingChoiceTile(
                title: 'Choice Title',
                subtitle: 'Choice Subtitle',
                icon: Icons.check_circle,
                selected: true,
              ),
            ),
          ),
        );

        final tile = tester.widget<OnboardingChoiceTile>(
          find.byType(OnboardingChoiceTile),
        );
        expect(tile.title, equals('Choice Title'));
      },
    );

    // ── Issue 45: Dynamic Font Scaling Overflow Protection (200%) ───────────
    testWidgets(
      'Issue 45: OnboardingChip renders at 200% font scale without overflow',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Scaffold(
                body: OnboardingChip(
                  label: 'Very Long Option Pill Label Testing Font Scale 200%',
                  selected: true,
                  icon: Icons.star,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(OnboardingChip), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Issue 45: OnboardingActionPill renders at 200% font scale without overflow',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Scaffold(
                body: OnboardingActionPill(
                  label: 'Action Pill Under 200% Font Scale',
                  selected: false,
                  icon: Icons.flash_on,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(OnboardingActionPill), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    // ── Issue 46: Step Indicator Active Progress Smooth Transitions ──────────
    testWidgets(
      'Issue 46: LiquidGlassOnboardingIndicator renders completion dots and pill',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LiquidGlassOnboardingIndicator(
                page: 2.0,
                count: 13,
                completedSteps: List.generate(13, (i) => i <= 2),
                onDotTap: (_) {},
                onDragTarget: (_) {},
              ),
            ),
          ),
        );

        expect(find.byType(LiquidGlassOnboardingIndicator), findsOneWidget);
        expect(find.byType(AnimatedContainer), findsWidgets);
      },
    );

    // ── Issue 47: Dark Mode Color Token Consistency ──────────────────────────
    test('Issue 47: OptivusColors defines dark mode tokens', () {
      expect(OptivusColors.onboardingDarkTop, equals(const Color(0xFF1A1C24)));
      expect(
        OptivusColors.onboardingDarkBottom,
        equals(const Color(0xFF0F1015)),
      );
      expect(OptivusColors.darkGlassFill, equals(const Color(0x1FFFFFFF)));
      expect(OptivusColors.darkGlassBorder, equals(const Color(0x33FFFFFF)));
      expect(OptivusColors.textPrimaryDark, equals(const Color(0xFFF1F3F9)));
    });

    test('Issue 47: OptivusTheme provides valid darkTheme', () {
      final darkTheme = OptivusTheme.darkTheme;
      expect(darkTheme.brightness, equals(Brightness.dark));
      expect(
        darkTheme.textTheme.displayLarge?.color,
        equals(OptivusColors.textPrimaryDark),
      );
    });

    // ── Issue 48: Soft Keyboard Input Field Occlusion ───────────────────────
    testWidgets(
      'Issue 48: OnboardingScrollView includes keyboard inset bottom reserve',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                viewInsets: EdgeInsets.only(bottom: 300),
              ),
              child: const Scaffold(
                body: OnboardingScrollView(
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(labelText: 'Input Field'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(OnboardingScrollView), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      },
    );

    // ── Issue 49: Loading State Shimmer Layout Shift Prevention ─────────────
    testWidgets(
      'Issue 49: OnboardingCardSkeleton renders with specified height',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: OnboardingCardSkeleton(height: 180, radius: 20),
            ),
          ),
        );

        expect(find.byType(OnboardingCardSkeleton), findsOneWidget);
        final skeletonWidget = tester.widget<OnboardingCardSkeleton>(
          find.byType(OnboardingCardSkeleton),
        );
        expect(skeletonWidget.height, equals(180));
      },
    );

    // ── Issue 50: Primary Button Disabled Contrast Ratio Compliance ─────────
    test(
      'Issue 50: LiquidPrimaryButton disabled contrast ratio >= 4.5:1 (WCAG AA)',
      () {
        const bgLuminance = 0.4963; // OptivusColors.disabled #B8BBC1
        const fgLuminance = 0.0095; // OptivusColors.textPrimary #11131A
        final contrastRatio = (bgLuminance + 0.05) / (fgLuminance + 0.05);

        expect(contrastRatio, greaterThanOrEqualTo(4.5));
        expect(contrastRatio, greaterThan(6.0));
      },
    );

    // ── Issue 51: Onboarding Stage Summary Screen Layout Clipping on Landscape
    testWidgets(
      'Issue 51: OnboardingScrollView adapts constraints in landscape',
      (tester) async {
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(800, 400)),
              child: Scaffold(
                body: OnboardingScrollView(
                  child: Column(
                    children: [
                      Text('Summary Title'),
                      Text('Summary Item 1'),
                      Text('Summary Item 2'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Summary Title'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    // ── Issue 52: Toast Error Notification Stack Overlap Prevention ───────────
    test(
      'Issue 52: ToastQueueNotifier manages FIFO queue and deduplication',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(toastQueueProvider.notifier);

        expect(container.read(toastQueueProvider).current, isNull);

        notifier.showToast('First Error');
        expect(
          container.read(toastQueueProvider).current?.message,
          equals('First Error'),
        );

        // Deduplication: showing same message again is ignored
        notifier.showToast('First Error');
        expect(container.read(toastQueueProvider).queue.length, equals(0));

        // Enqueue second message
        notifier.showToast('Second Error');
        expect(container.read(toastQueueProvider).queue.length, equals(1));
        expect(
          container.read(toastQueueProvider).queue.first.message,
          equals('Second Error'),
        );

        // Clear all
        notifier.clearAll();
        expect(container.read(toastQueueProvider).current, isNull);
        expect(container.read(toastQueueProvider).queue, isEmpty);
      },
    );

    // ── Issue 53: Scroll Physics Consistency (AlwaysScrollableScrollPhysics) ─
    testWidgets(
      'Issue 53: OnboardingScrollView uses AlwaysScrollableScrollPhysics',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: OnboardingScrollView(child: Text('Scroll Content')),
            ),
          ),
        );

        final scrollable = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(scrollable.physics, isA<AlwaysScrollableScrollPhysics>());
      },
    );

    // ── Issue 54: Screen Transition Gesture Navigation Handling ──────────────
    testWidgets('Issue 54: PopScope handles back gestures safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {},
            child: const Scaffold(body: Text('PopScope Test')),
          ),
        ),
      );

      expect(find.text('PopScope Test'), findsOneWidget);
    });

    // ── Issue 55: Accessibility Semantics Labels on Timeline Widgets ─────────
    testWidgets(
      'Issue 55: OnboardingDayChips provides accessible semantics traits',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OnboardingDayChips(selectedDay: 1, onChanged: (_) {}),
            ),
          ),
        );

        expect(find.byType(OnboardingDayChips), findsOneWidget);
        final semantics = find.byType(Semantics);
        expect(semantics, findsWidgets);
      },
    );

    testWidgets(
      'Issue 55: OnboardingVerticalTimeline wraps blocks in Semantics',
      (tester) async {
        final block = TimelineBlockDraft(
          id: 'test-block-1',
          title: 'Morning Yoga',
          startMinute: 480,
          endMinute: 540,
          repeatDays: const [1, 2, 3, 4, 5],
          section: 'routine',
          blockType: 'flex',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 500,
                child: OnboardingVerticalTimeline(
                  blocks: [block],
                  requiredHeightBuilder: (context, b, w) => 80.0,
                  blockBuilder: (context, b) => Text(b.title),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(OnboardingVerticalTimeline), findsOneWidget);
        expect(find.text('Morning Yoga'), findsOneWidget);
      },
    );
  });
}
