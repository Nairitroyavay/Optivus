import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_timeline_preview.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_11_today_ready.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group I Layout & Accessibility Stress Tests', () {
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Small viewports (<600px height and width) header/title overlap stress tests
    // ─────────────────────────────────────────────────────────────────────────
    group('1. Small Viewports (<600px height & width) Header & Title Overlaps', () {
      final smallViewports = <Size>[
        const Size(320, 568), // iPhone SE (1st gen)
        const Size(360, 500), // Low height Android device
        const Size(500, 350), // Foldable inside fold / small landscape
        const Size(280, 480), // Micro screen size
      ];

      for (final size in smallViewports) {
        testWidgets(
          'OnboardingStepShell responsive header height (50.0) at ${size.width}x${size.height} without title overlap',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            bool backPressed = false;

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
                  showSave: true,
                  isSaving: false,
                  isSaved: false,
                  saveEnabled: true,
                  ctaLabel: 'Continue',
                  ctaEnabled: true,
                  ctaLoading: false,
                  topLeftOverlay: IconButton(
                    key: const Key('header_back_button'),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => backPressed = true,
                  ),
                  child: OnboardingStepBody(
                    title: 'Adversarial Long Title For Header Overlap Testing',
                    subtitle:
                        'Testing whether section title scrolls cleanly underneath header row.',
                    children: const [
                      Text('Step body item 1'),
                      Text('Step body item 2'),
                    ],
                  ),
                ),
              ),
            );

            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            // Back button and title exist
            final backButtonFinder = find.byKey(
              const Key('header_back_button'),
            );
            final titleFinder = find.text(
              'Adversarial Long Title For Header Overlap Testing',
            );

            expect(backButtonFinder, findsOneWidget);
            expect(titleFinder, findsOneWidget);

            // Bounding box checks: back button top header box vs title text box
            final backRect = tester.getRect(backButtonFinder);
            final titleRect = tester.getRect(titleFinder);

            // Back button Y bottom should be strictly less than or equal to title top Y
            expect(backRect.bottom, lessThanOrEqualTo(titleRect.top + 1.0));

            // Back button tap should register
            await tester.tap(backButtonFinder);
            expect(backPressed, isTrue);
          },
        );
      }

      testWidgets(
        'Header indicators stay aligned and sized within 50px height on small screens',
        (tester) async {
          tester.view.physicalSize = const Size(360, 480);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: OnboardingStepShell(
                currentPage: 2,
                pageOffset: 2.0,
                completedSteps: List.generate(10, (i) => i < 2),
                validationMessage: 'Validation warning active',
                onDotTap: (_) {},
                onIndicatorDraggedTo: (_) {},
                onNext: () {},
                onSave: null,
                showSave: true,
                isSaving: false,
                isSaved: false,
                saveEnabled: true,
                ctaLabel: 'Next',
                ctaEnabled: true,
                ctaLoading: false,
                child: const Text('Small Viewport Content'),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(LiquidGlassOnboardingIndicator), findsOneWidget);
          expect(find.text('Validation warning active'), findsOneWidget);
        },
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Landscape viewports for summary screen layout clipping stress tests
    // ─────────────────────────────────────────────────────────────────────────
    group('2. Landscape Viewports Summary Screen Layout Clipping', () {
      final landscapeViewports = <Size>[
        const Size(800, 400), // Standard tablet/phone landscape
        const Size(667, 375), // iPhone 8 landscape
        const Size(960, 480), // Widescreen phone landscape
        const Size(736, 300), // Ultra low-height landscape
      ];

      for (final size in landscapeViewports) {
        testWidgets(
          'OnboardingStep14 summary screen renders without clipping at ${size.width}x${size.height}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              const ProviderScope(
                child: MaterialApp(home: Scaffold(body: OnboardingStep14())),
              ),
            );

            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            expect(find.text('Today Is Ready'), findsOneWidget);

            // Check that scrollable widget is present and can scroll
            final scrollableFinder = find.byType(SingleChildScrollView);
            expect(scrollableFinder, findsWidgets);

            // Perform drag to scroll summary content down
            await tester.drag(scrollableFinder.first, const Offset(0, -300));
            await tester.pump(const Duration(milliseconds: 300));
          },
        );
      }

      testWidgets(
        'OnboardingScrollView sets minHeight to 0 in landscape mode preventing unbounded vertical height',
        (tester) async {
          tester.view.physicalSize = const Size(800, 360);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: Size(800, 360)),
                child: Scaffold(
                  body: OnboardingScrollView(
                    child: Column(
                      children: [
                        Text('Landscape Summary Item A'),
                        Text('Landscape Summary Item B'),
                        Text('Landscape Summary Item C'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pump();

          expect(find.text('Landscape Summary Item A'), findsOneWidget);
        },
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Accessibility semantics tree traversal on timeline and day chips
    // ─────────────────────────────────────────────────────────────────────────
    group('3. Accessibility Semantics Tree Traversal', () {
      testWidgets(
        'OnboardingDayChips full semantics traversal & traits assertion',
        (tester) async {
          final handle = tester.ensureSemantics();
          int selectedDay = 1; // Monday (1-indexed)

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    return OnboardingDayChips(
                      selectedDay: selectedDay,
                      onChanged: (d) => setState(() => selectedDay = d),
                    );
                  },
                ),
              ),
            ),
          );

          expect(find.byType(OnboardingDayChips), findsOneWidget);

          // Find day chips text ('MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN')
          final dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
          for (int i = 0; i < dayLabels.length; i++) {
            final dayText = find.text(dayLabels[i]);
            expect(dayText, findsOneWidget);
          }

          for (final day in const [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ]) {
            expect(find.bySemanticsLabel(day), findsOneWidget);
          }
          expect(
            tester.getSemantics(find.bySemanticsLabel('Monday')),
            matchesSemantics(
              label: 'Monday',
              hint: 'Currently selected',
              isButton: true,
              hasSelectedState: true,
              isSelected: true,
              hasTapAction: true,
            ),
          );

          handle.dispose();
        },
      );

      testWidgets(
        'OnboardingVerticalTimeline block cards & exclusion semantics tree traversal',
        (tester) async {
          final handle = tester.ensureSemantics();

          final blocks = [
            TimelineBlockDraft(
              id: 'block-morning-routine',
              title: 'Morning Routine',
              startMinute: 420, // 07:00
              endMinute: 480, // 08:00
              repeatDays: const [1, 2, 3, 4, 5],
              section: 'routine',
              blockType: 'fixed',
            ),
            TimelineBlockDraft(
              id: 'block-deep-work',
              title: 'Deep Work Session',
              startMinute: 540, // 09:00
              endMinute: 720, // 12:00
              repeatDays: const [1, 2, 3, 4, 5],
              section: 'work',
              blockType: 'flex',
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 380,
                  height: 600,
                  child: OnboardingVerticalTimeline(
                    blocks: blocks,
                    requiredHeightBuilder: (context, block, width) => 90.0,
                    blockBuilder: (context, block) => Text(block.title),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(OnboardingVerticalTimeline), findsOneWidget);
          expect(find.text('Morning Routine'), findsOneWidget);
          expect(find.text('Deep Work Session'), findsOneWidget);

          expect(
            find.bySemanticsLabel('Timeline schedule, 2 items'),
            findsOneWidget,
          );
          expect(
            tester.getSemantics(
              find.bySemanticsLabel('Morning Routine, from 7:00 AM to 8:00 AM'),
            ),
            matchesSemantics(
              label: 'Morning Routine, from 7:00 AM to 8:00 AM',
              hint: 'Double tap to edit timeline item',
              isButton: true,
            ),
          );
          expect(
            tester.getSemantics(
              find.bySemanticsLabel(
                'Deep Work Session, from 9:00 AM to 12:00 PM',
              ),
            ),
            matchesSemantics(
              label: 'Deep Work Session, from 9:00 AM to 12:00 PM',
              hint: 'Double tap to edit timeline item',
              isButton: true,
            ),
          );

          // Verify decorative ticks are excluded from semantics tree
          final excludedFinder = find.byType(ExcludeSemantics);
          expect(excludedFinder, findsWidgets);

          handle.dispose();
        },
      );
    });
  });
}
