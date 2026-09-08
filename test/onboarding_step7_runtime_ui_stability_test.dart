import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_controller.dart';
import 'package:optivus/features/onboarding/timeline/adapters/skin_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/layout/timeline_overlap_engine.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_viewport.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/state/app_state.dart';

class _FakeSkinCareAiClient implements SkinCareAiClient {
  const _FakeSkinCareAiClient();

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async {
    return const SkinCareAiProductResult(products: []);
  }

  @override
  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    if (params['recommendationOnly'] == true ||
        params['recommendationsOnly'] == true) {
      return const SkinCareAiRoutineResult(
        morningRoutine: [],
        nightRoutine: [],
        weeklyRoutine: [],
        timelineBlocks: [],
        routinePlans: [],
        recommendedProducts: [
          SkinCareProductRecommendation(
            name: 'Minimalist Gentle Cleanser',
            category: 'cleanser',
            brand: 'Minimalist',
            estimatedPrice: '300-400',
            currencyCode: 'INR',
            reason: 'Gentle daily cleanser',
          ),
          SkinCareProductRecommendation(
            name: 'Minimalist Barrier Moisturizer',
            category: 'moisturizer',
            brand: 'Minimalist',
            estimatedPrice: '400-500',
            currencyCode: 'INR',
            reason: 'Barrier repair hydration',
          ),
          SkinCareProductRecommendation(
            name: 'Minimalist SPF 50 Sunscreen',
            category: 'sunscreen',
            brand: 'Minimalist',
            estimatedPrice: '500-600',
            currencyCode: 'INR',
            reason: 'Broad spectrum UV protection',
          ),
        ],
      );
    }
    return const SkinCareAiRoutineResult(
      morningRoutine: [],
      nightRoutine: [],
      weeklyRoutine: [],
      timelineBlocks: [],
      routinePlans: [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning Skin Care',
          steps: ['Wash face', 'Apply sunscreen'],
          productNames: [
            'Minimalist Gentle Cleanser',
            'Minimalist SPF 50 Sunscreen',
          ],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Night Skin Care',
          steps: ['Wash face', 'Moisturize'],
          productNames: [
            'Minimalist Gentle Cleanser',
            'Minimalist Barrier Moisturizer',
          ],
        ),
      ],
    );
  }
}

Widget _buildTestApp({
  required OnboardingDraft draft,
  Size screenSize = const Size(390, 844),
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      mockOnboardingProvider.overrideWith((ref) {
        final notifier = MockOnboardingNotifier();
        notifier.loadSeedData(draft);
        return notifier;
      }),
      skinCareAiClientProvider.overrideWithValue(const _FakeSkinCareAiClient()),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: screenSize,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: OnboardingStep7()),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 7 Price Display Formatting', () {
    test(
      'formatSkinCarePriceDisplay handles various price and currency shapes',
      () {
        // Duplicated currency prefix
        expect(formatSkinCarePriceDisplay('INR', 'INR 300-400'), 'INR 300-400');
        expect(formatSkinCarePriceDisplay('inr', 'INR 500'), 'INR 500');
        expect(formatSkinCarePriceDisplay('USD', 'USD 15.99'), 'USD 15.99');

        // Normal formatting without duplication
        expect(formatSkinCarePriceDisplay('INR', '300-400'), 'INR 300-400');
        expect(formatSkinCarePriceDisplay('USD', '15'), 'USD 15');

        // Currency symbols in price
        expect(formatSkinCarePriceDisplay('USD', r'$15'), r'$15');
        expect(formatSkinCarePriceDisplay('INR', '₹450'), '₹450');
        expect(formatSkinCarePriceDisplay('EUR', '€20'), '€20');
        expect(formatSkinCarePriceDisplay('GBP', '£12'), '£12');

        // Empty handling
        expect(formatSkinCarePriceDisplay(null, '300'), '300');
        expect(formatSkinCarePriceDisplay('INR', null), '');
        expect(formatSkinCarePriceDisplay('', '300'), '300');
        expect(formatSkinCarePriceDisplay('INR', ''), '');
        expect(formatSkinCarePriceDisplay('', ''), '');
      },
    );
  });

  group('Step 7 Geometry and Horizontal Inset Contract', () {
    testWidgets(
      'Has-products setup card and rebuild editor respect 24px horizontal margin',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final draft = OnboardingDraft(
          uid: 'user-geo-1',
          currentStep: 7,
          baseTimeline: const BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'has_products',
            skinCareDesiredApplicationsPerDay: 2,
            skinCareProductNames: 'Cleanser\nMoisturizer',
          ),
        );

        await tester.pumpWidget(
          _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
        );
        await tester.pumpAndSettle();

        // 1. In initial setup mode, the card should start at 24px and end at 390 - 24 = 366px
        final setupCardFinder = find.byType(OnboardingGlassCard);
        expect(setupCardFinder, findsWidgets);
        final setupRect = tester.getRect(setupCardFinder.first);
        expect(setupRect.left, 24.0);
        expect(setupRect.right, 366.0);

        // Enter rebuild editing mode
        final context = tester.element(find.byType(OnboardingStep7));
        final container = ProviderScope.containerOf(context);
        container
            .read(skinCareFlowControllerProvider.notifier)
            .startEditing(draft.baseTimeline);
        await tester.pumpAndSettle();

        // 2. In rebuild edit mode, the editor card must also maintain the 24px inset contract
        final rebuildCardFinder = find.byType(OnboardingGlassCard);
        expect(rebuildCardFinder, findsWidgets);
        final rebuildRect = tester.getRect(rebuildCardFinder.first);
        expect(rebuildRect.left, 24.0);
        expect(rebuildRect.right, 366.0);
      },
    );

    testWidgets(
      'Rebuild editor on compact screen with 1.5 text scale does not overflow',
      (tester) async {
        final blocks = [
          const TimelineBlockDraft(
            id: 'entry-geo-compact',
            section: 'skin_care',
            title: 'Morning Routine',
            startMinute: 480,
            endMinute: 510,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.softBlockKey,
          ),
        ];
        final draft = OnboardingDraft(
          uid: 'user-geo-compact',
          currentStep: 7,
          baseTimeline: BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'has_products',
            skinCareDesiredApplicationsPerDay: 2,
            blocks: blocks,
          ),
        );

        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildTestApp(
            draft: draft,
            screenSize: const Size(360, 640),
            textScale: 1.5,
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(OnboardingStep7));
        final container = ProviderScope.containerOf(context);
        container
            .read(skinCareFlowControllerProvider.notifier)
            .startEditing(draft.baseTimeline);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Timeline Viewport Weekday Auto-Scroll Contract', () {
    testWidgets(
      'autoScrollIdentity triggers auto-scroll when day changes between identical routines',
      (tester) async {
        // Monday and Tuesday have identical schedule blocks
        final blocks = [
          const TimelineEntry(
            id: 'entry-1',
            sourceId: 'source-1',
            startMinute: 600, // 10:00 AM (down the page)
            endMinute: 630,
            title: 'Morning Care',
            category: TimelineCategory.skinCare,
            repeatDays: [1, 2],
          ),
        ];

        final controller = ScrollController();
        const adapter = SkinTimelineAdapter();
        int currentDay = 1;

        Widget buildTimeline(int day) {
          final layoutResult = TimelineOverlapEngine.computeLayout(
            entries: blocks,
            availableWidth: 390,
            selectedDay: day,
          );

          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                child: TimelineViewport(
                  layoutResult: layoutResult,
                  styleBuilder: adapter.styleForEntry,
                  scrollController: controller,
                  autoScrollToFirstEntry: true,
                  autoScrollIdentity: day,
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildTimeline(currentDay));
        await tester.pumpAndSettle();

        final initialOffset = controller.offset;
        expect(initialOffset, greaterThan(0.0));

        // Manually scroll to top (offset 0)
        controller.jumpTo(0.0);
        await tester.pumpAndSettle();
        expect(controller.offset, 0.0);

        // Switch to Tuesday (identical layout, but autoScrollIdentity changes)
        currentDay = 2;
        await tester.pumpWidget(buildTimeline(currentDay));
        await tester.pumpAndSettle();

        // Viewport should have auto-scrolled back down to first entry
        expect(controller.offset, equals(initialOffset));
      },
    );
  });

  group('Card Height & Pathological Content Bounding Contract', () {
    testWidgets('Normal card renders all steps without clipping or overflow', (
      tester,
    ) async {
      const normalBlock = TimelineBlockDraft(
        id: 'normal-1',
        section: 'skin_care',
        title: 'Morning Routine',
        startMinute: 480,
        endMinute: 510,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: ['Cleanser', 'Moisturizer', 'Sunscreen'],
        skincareSteps: ['Wash face', 'Apply cream', 'Protect with SPF'],
      );

      final draft = OnboardingDraft(
        uid: 'user-normal-card',
        currentStep: 7,
        baseTimeline: const BaseTimelineDraft(
          skinCareSetupStep: 1,
          skinCareSetupPath: 'has_products',
          skinCareDesiredApplicationsPerDay: 1,
          skinCareRoutineFingerprint: 'valid-fp',
          blocks: [normalBlock],
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
      );
      await tester.pumpAndSettle();

      // All steps should be rendered on the normal card
      expect(find.text('1. Wash face'), findsOneWidget);
      expect(find.text('2. Apply cream'), findsOneWidget);
      expect(find.text('3. Protect with SPF'), findsOneWidget);
      expect(find.text('Cleanser, Moisturizer, Sunscreen'), findsOneWidget);

      // 'View full details' should NOT be present for normal cards
      expect(
        find.byKey(const ValueKey('onboarding-step7-full-details-normal-1')),
        findsNothing,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Pathological card renders bounded summary and View full details sheet with all items',
      (tester) async {
        final longSteps = [
          'Wash face thoroughly with lukewarm water',
          'Apply toner gently with cotton pad',
          'Apply hyaluronic acid serum on damp skin',
          'Apply vitamin C serum avoiding eye area',
          'Apply peptide moisturizer evenly across cheeks and forehead',
          'Apply broad spectrum sunscreen generously',
        ];
        final longProducts = [
          'Gentle Cleanser',
          'Hydrating Toner',
          'Hyaluronic Serum',
          'Vitamin C Booster',
          'Peptide Cream',
          'SPF 50 Sunscreen',
        ];

        final pathologicalBlock = TimelineBlockDraft(
          id: 'pathological-1',
          section: 'skin_care',
          title: 'Extensive Care Routine',
          startMinute: 480,
          endMinute: 540,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareProducts: longProducts,
          skincareSteps: longSteps,
        );

        final draft = OnboardingDraft(
          uid: 'user-pathological-card',
          currentStep: 7,
          baseTimeline: BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'has_products',
            skinCareDesiredApplicationsPerDay: 1,
            skinCareRoutineFingerprint: 'valid-fp',
            blocks: [pathologicalBlock],
          ),
        );

        await tester.pumpWidget(
          _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Card should display bounded summary: first 2 steps
        expect(
          find.text('1. Wash face thoroughly with lukewarm water'),
          findsOneWidget,
        );
        expect(
          find.text('2. Apply toner gently with cotton pad'),
          findsOneWidget,
        );
        // Steps 3+ should NOT be rendered on the timeline card
        expect(
          find.text('3. Apply hyaluronic acid serum on damp skin'),
          findsNothing,
        );

        // 'View full details' button must be present
        final detailsButton = find.byKey(
          const ValueKey('onboarding-step7-full-details-pathological-1'),
        );
        expect(detailsButton, findsOneWidget);

        // Tap 'View full details' to open the details modal bottom sheet
        await tester.tap(detailsButton);
        await tester.pumpAndSettle();

        // In the bottom sheet, ALL steps and products should be visible in full
        expect(find.text('Steps'), findsOneWidget);
        expect(find.text('Products'), findsOneWidget);
        for (final step in longSteps) {
          expect(find.textContaining(step), findsWidgets);
        }
        for (final product in longProducts) {
          expect(find.textContaining(product), findsWidgets);
        }

        // Close bottom sheet
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Edit Sheet Mutex & Rapid Tap Prevention', () {
    testWidgets(
      'Rapid multiple taps on card and edit icon open only one edit sheet',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'mutex-block-1',
          section: 'skin_care',
          title: 'Daily Care',
          startMinute: 500,
          endMinute: 530,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareProducts: ['Cleanser'],
          skincareSteps: ['Wash'],
        );

        final draft = OnboardingDraft(
          uid: 'user-mutex-test',
          currentStep: 7,
          baseTimeline: const BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'has_products',
            skinCareDesiredApplicationsPerDay: 1,
            skinCareRoutineFingerprint: 'valid-fp',
            blocks: [block],
          ),
        );

        await tester.pumpWidget(
          _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
        );
        await tester.pumpAndSettle();

        final cardFinder = find.byKey(
          const ValueKey('onboarding-step7-block-mutex-block-1'),
        );
        final editButtonFinder = find.byKey(
          const ValueKey('onboarding-step7-edit-mutex-block-1'),
        );

        // Rapidly trigger taps on both the card and the edit button
        await tester.tap(editButtonFinder);
        await tester.tap(cardFinder, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Exactly one edit sheet title field should exist
        expect(
          find.byKey(const ValueKey('onboarding-step7-edit-title-field')),
          findsOneWidget,
        );

        // Cancel the sheet
        await tester.tap(find.byKey(const Key('timeline-edit-cancel-button')));
        await tester.pumpAndSettle();

        // Modal should be completely closed
        expect(
          find.byKey(const ValueKey('onboarding-step7-edit-title-field')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Section 19 Exact Physical Interaction Sequence Regression', () {
    OnboardingDraft buildInitialDraft({String uid = 'user-seq-test'}) {
      const planABlocks = [
        TimelineBlockDraft(
          id: 'plan-a-morning',
          section: 'skin_care',
          title: 'Morning Skin Care',
          startMinute: 480,
          endMinute: 495,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareProducts: [
            'Minimalist Gentle Cleanser',
            'Minimalist SPF 50 Sunscreen',
          ],
          skincareSteps: ['Wash face', 'Apply sunscreen'],
          skincareSlotLabel: 'morning',
        ),
        TimelineBlockDraft(
          id: 'plan-a-night',
          section: 'skin_care',
          title: 'Night Skin Care',
          startMinute: 1260,
          endMinute: 1275,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareProducts: [
            'Minimalist Gentle Cleanser',
            'Minimalist Barrier Moisturizer',
          ],
          skincareSteps: ['Wash face', 'Moisturize'],
          skincareSlotLabel: 'night',
        ),
      ];

      final draftBase = BaseTimelineDraft(
        skinCareSetupStep: 1,
        skinCareSetupPath: 'no_products',
        skinCareSkinType: 'oily',
        skinCareProblems: const ['pimples'],
        skinCareBudget: 'medium',
        skinCareDesiredApplicationsPerDay: 2,
        skinCareFacePhotoAssetId: 'skin-asset',
        skinCareFacePhotoR2Key:
            'users/$uid/onboarding/skin_face/skin-asset.jpg',
        skinCareFacePhotoStatus: 'uploaded',
        skinCareProductNames:
            'Minimalist Gentle Cleanser\nMinimalist Barrier Moisturizer\nMinimalist SPF 50 Sunscreen',
        skinCareSuggestedProducts: const [
          'Minimalist Gentle Cleanser',
          'Minimalist Barrier Moisturizer',
          'Minimalist SPF 50 Sunscreen',
        ],
        skinCareSelectedProductNames: const [
          'Minimalist Gentle Cleanser',
          'Minimalist Barrier Moisturizer',
          'Minimalist SPF 50 Sunscreen',
        ],
        skinCareProductRecommendations: const [
          SkinCareProductRecommendationDraft(
            name: 'Minimalist Gentle Cleanser',
            category: 'cleanser',
            brand: 'Minimalist',
            estimatedPrice: '300-400',
            currencyCode: 'INR',
            reason: 'Gentle daily cleanser',
          ),
          SkinCareProductRecommendationDraft(
            name: 'Minimalist Barrier Moisturizer',
            category: 'moisturizer',
            brand: 'Minimalist',
            estimatedPrice: '400-500',
            currencyCode: 'INR',
            reason: 'Barrier repair hydration',
          ),
          SkinCareProductRecommendationDraft(
            name: 'Minimalist SPF 50 Sunscreen',
            category: 'sunscreen',
            brand: 'Minimalist',
            estimatedPrice: '500-600',
            currencyCode: 'INR',
            reason: 'Broad spectrum UV protection',
          ),
        ],
        blocks: [
          BaseTimelineDraft.defaultSleepBlock(),
          BaseTimelineDraft.defaultBathBlock(),
          ...planABlocks,
        ],
      );

      final recFingerprint = draftBase
          .computeSkinCareRecommendationFingerprint();
      final baseWithRec = draftBase.copyWith(
        skinCareRecommendationFingerprint: recFingerprint,
      );
      final routineFingerprint = baseWithRec
          .computeSkinCareRoutineFingerprint();
      final taggedBlocks = baseWithRec.blocks.map((block) {
        if (block.section != 'skin_care') return block;
        return block.copyWith(
          provenanceSourceIds: [
            ...block.provenanceSourceIds,
            'skin-care-generation:$routineFingerprint',
          ],
        );
      }).toList();

      return OnboardingDraft(
        uid: uid,
        currentStep: 7,
        baseTimeline: baseWithRec.copyWith(
          skinCareRoutineFingerprint: routineFingerprint,
          blocks: taggedBlocks,
        ),
      );
    }

    Future<void> ensureAllProductsSelected(WidgetTester tester) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final currentSelected = container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .skinCareSelectedProductNames;

      for (final name in const [
        'Minimalist Gentle Cleanser',
        'Minimalist Barrier Moisturizer',
        'Minimalist SPF 50 Sunscreen',
      ]) {
        final isSelected = currentSelected.any(
          (s) => s.contains(name) || name.contains(s),
        );
        if (!isSelected) {
          final productFinder = find.text(name);
          await tester.ensureVisible(productFinder);
          await tester.pump();
          await tester.tap(productFinder);
          await tester.pump();
        }
      }
    }

    testWidgets(
      'Full sequence: timeline -> whole-card edit (Save) -> 3-dot edit (Cancel) -> 3-dot edit (system back) -> Rebuild / Edit -> Change details -> change inputs -> Find products -> Change details AGAIN -> Find products AGAIN -> select products -> Close editor -> Plan A review',
      (tester) async {
        final draft = buildInitialDraft();
        await tester.pumpWidget(
          _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 1. Initial State: Valid Plan A routine on full-screen timeline
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );
        expect(find.text('Morning Skin Care'), findsOneWidget);
        expect(find.text('Night Skin Care'), findsOneWidget);
        expect(find.text('Routine built'), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingStep7)),
        );
        expect(
          onboarding7CanContinue(
            container.read(mockOnboardingProvider).draft.baseTimeline,
            'user-seq-test',
          ),
          isTrue,
        );

        // 2. Whole-card edit -> modify fields -> Save
        final morningCard = find.byKey(
          const ValueKey('onboarding-step7-block-plan-a-morning'),
        );
        expect(morningCard, findsOneWidget);
        await tester.tap(morningCard);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final titleField = find.byKey(
          const ValueKey('onboarding-step7-edit-title-field'),
        );
        expect(titleField, findsOneWidget);
        await tester.enterText(titleField, 'Morning Glow Care');
        await tester.pump();

        await tester.tap(
          find.byKey(const ValueKey('onboarding-step7-edit-save-button')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(titleField, findsNothing);
        expect(find.text('Morning Glow Care'), findsOneWidget);

        // 3. 3-dot edit -> Cancel
        final morningEditIcon = find.byKey(
          const ValueKey('onboarding-step7-edit-plan-a-morning'),
        );
        expect(morningEditIcon, findsOneWidget);
        await tester.tap(morningEditIcon);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(titleField, findsOneWidget);

        await tester.tap(find.byKey(const Key('timeline-edit-cancel-button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(titleField, findsNothing);

        // 4. 3-dot edit -> system Back
        await tester.tap(morningEditIcon);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(titleField, findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(titleField, findsNothing);

        // 5. Rebuild / Edit
        final rebuildBtn = find.text('Rebuild / Edit');
        expect(rebuildBtn, findsOneWidget);
        await tester.tap(rebuildBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 6. Change details
        final changeDetailsBtn = find.text('Change details');
        expect(changeDetailsBtn, findsOneWidget);
        await tester.ensureVisible(changeDetailsBtn);
        await tester.tap(changeDetailsBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 7. Change inputs
        final freq2 = find.byKey(
          const ValueKey('onboarding-step7-frequency-2'),
        );
        await tester.ensureVisible(freq2);
        await tester.tap(freq2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 8. Find products
        final findProductsBtn = find.text('Find products');
        await tester.ensureVisible(findProductsBtn);
        await tester.tap(findProductsBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Product selection stage is now active
        expect(find.text('Minimalist Gentle Cleanser'), findsOneWidget);

        // 9. Product selection
        await ensureAllProductsSelected(tester);
        expect(tester.takeException(), isNull);

        // 10. Change details AGAIN
        final changeDetailsAgain = find.text('Change details');
        expect(changeDetailsAgain, findsOneWidget);
        await tester.ensureVisible(changeDetailsAgain);
        await tester.tap(changeDetailsAgain);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 11. Find products AGAIN
        final findProductsAgain = find.text('Find products');
        await tester.ensureVisible(findProductsAgain);
        await tester.tap(findProductsAgain);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 12. Select products
        await ensureAllProductsSelected(tester);
        expect(tester.takeException(), isNull);

        // 13. Close editor / Back
        final closeEditorBtn = find.byKey(
          const ValueKey('onboarding-step7-no-products-cancel-rebuild'),
        );
        expect(closeEditorBtn, findsOneWidget);
        await tester.tap(closeEditorBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 14. Plan-A review intact with our earlier saved edit
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );
        expect(find.text('Morning Glow Care'), findsOneWidget);
        expect(find.text('Night Skin Care'), findsOneWidget);
        expect(find.text('Routine built'), findsOneWidget);
        final containerAfterCancel = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingStep7)),
        );
        expect(
          onboarding7CanContinue(
            containerAfterCancel
                .read(mockOnboardingProvider)
                .draft
                .baseTimeline,
            'user-seq-test',
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Plan B completion after rebuild: valid routine -> Rebuild / Edit -> Change details -> Find products -> select products -> Build skin routine -> Plan B review',
      (tester) async {
        final draft = buildInitialDraft();
        await tester.pumpWidget(
          _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Initial state: Plan A review
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );
        expect(find.text('Morning Skin Care'), findsOneWidget);
        expect(find.text('Night Skin Care'), findsOneWidget);
        expect(find.text('Routine built'), findsOneWidget);

        // 1. Rebuild / Edit
        final rebuildBtn = find.text('Rebuild / Edit');
        expect(rebuildBtn, findsOneWidget);
        await tester.tap(rebuildBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 2. Change details
        final changeDetailsBtn = find.text('Change details');
        expect(changeDetailsBtn, findsOneWidget);
        await tester.ensureVisible(changeDetailsBtn);
        await tester.tap(changeDetailsBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 3. Find products
        final findProductsBtn = find.text('Find products');
        await tester.ensureVisible(findProductsBtn);
        await tester.tap(findProductsBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 4. Select products
        await ensureAllProductsSelected(tester);
        expect(tester.takeException(), isNull);

        // 5. Build skin routine
        final buildRoutineBtn = find.text('Build skin routine');
        expect(buildRoutineBtn, findsOneWidget);
        await tester.ensureVisible(buildRoutineBtn);
        await tester.tap(buildRoutineBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 6. Plan B timeline review is active
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );
        expect(find.text('Before-bed Skin Care'), findsOneWidget);
        expect(find.textContaining('Skin Care'), findsWidgets);
        expect(find.text('Routine built'), findsOneWidget);
        final containerPlanB = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingStep7)),
        );
        expect(
          onboarding7CanContinue(
            containerPlanB.read(mockOnboardingProvider).draft.baseTimeline,
            'user-seq-test',
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
