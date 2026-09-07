import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_primary_action.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_controller.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_generation.dart';

void _noop() {}

void main() {
  group('Step 7 Action Bridge - Token, Epoch & Discard Semantics', () {
    test('publish with matching epoch sets action', () {
      final container = ProviderContainer();
      final bridge = container.read(step7ActionBridgeProvider.notifier);

      var callbackInvoked = false;
      bridge.publish(
        ownerId: 'has_products',
        epoch: 1,
        action: OnboardingStep7PrimaryAction(
          label: 'Build skin routine',
          enabled: true,
          loading: false,
          onPressed: () => callbackInvoked = true,
        ),
      );

      final state = container.read(step7ActionBridgeProvider);
      expect(state.action, isNotNull);
      expect(state.action!.label, 'Build skin routine');
      expect(state.activeToken, isNotNull);
      expect(state.activeToken!.ownerId, 'has_products');
      expect(state.activeToken!.epoch, 1);

      // Backwards-compatible provider also reflects the action
      final legacy = container.read(onboardingStep7PrimaryActionProvider);
      expect(legacy, isNotNull);
      expect(legacy!.label, 'Build skin routine');

      state.action!.onPressed();
      expect(callbackInvoked, isTrue);
      container.dispose();
    });

    test('publish with older epoch is ignored (stale response protection)', () {
      final container = ProviderContainer();
      final bridge = container.read(step7ActionBridgeProvider.notifier);

      // Publish at epoch 2
      bridge.publish(
        ownerId: 'no_products',
        epoch: 2,
        action: const OnboardingStep7PrimaryAction(
          label: 'Find products',
          enabled: true,
          loading: false,
          onPressed: _noop,
        ),
      );

      // Late callback arrives with epoch 1
      bridge.publish(
        ownerId: 'no_products',
        epoch: 1,
        action: const OnboardingStep7PrimaryAction(
          label: 'Stale Action',
          enabled: true,
          loading: false,
          onPressed: _noop,
        ),
      );

      final state = container.read(step7ActionBridgeProvider);
      expect(state.action!.label, 'Find products');
      expect(state.activeToken!.epoch, 2);
      container.dispose();
    });

    test('clear from different owner does not clobber active action', () {
      final container = ProviderContainer();
      final bridge = container.read(step7ActionBridgeProvider.notifier);

      bridge.publish(
        ownerId: 'no_products',
        epoch: 3,
        action: const OnboardingStep7PrimaryAction(
          label: 'Valid Action',
          enabled: true,
          loading: false,
          onPressed: _noop,
        ),
      );

      // Old screen disposing tries to clear
      bridge.clear(ownerId: 'has_products', epoch: 3);

      final state = container.read(step7ActionBridgeProvider);
      expect(state.action, isNotNull);
      expect(state.action!.label, 'Valid Action');
      container.dispose();
    });

    test('clear with matching owner resets action and legacy provider', () {
      final container = ProviderContainer();
      final bridge = container.read(step7ActionBridgeProvider.notifier);

      bridge.publish(
        ownerId: 'no_products',
        epoch: 4,
        action: const OnboardingStep7PrimaryAction(
          label: 'Active Action',
          enabled: true,
          loading: false,
          onPressed: _noop,
        ),
      );

      bridge.clear(ownerId: 'no_products', epoch: 4);

      final state = container.read(step7ActionBridgeProvider);
      expect(state.action, isNull);
      expect(state.activeToken, isNull);
      expect(container.read(onboardingStep7PrimaryActionProvider), isNull);
      container.dispose();
    });

    test('clearAll unconditionally wipes all actions and legacy state', () {
      final container = ProviderContainer();
      final bridge = container.read(step7ActionBridgeProvider.notifier);

      bridge.publish(
        ownerId: 'has_products',
        epoch: 5,
        action: const OnboardingStep7PrimaryAction(
          label: 'Some Action',
          enabled: true,
          loading: false,
          onPressed: _noop,
        ),
      );

      bridge.clearAll();

      expect(container.read(step7ActionBridgeProvider).action, isNull);
      expect(container.read(onboardingStep7PrimaryActionProvider), isNull);
      container.dispose();
    });
  });

  group('Top-Left Back Button and Navigation Invariants', () {
    test('Choice screen suppresses top-left back button', () {
      const base = BaseTimelineDraft(
        skinCareSetupStep: 0,
        skinCareSetupPath: '',
      );

      // Without flow controller override
      expect(
        onboardingShouldShowTopLeftBackButton(
          currentPage: 7,
          baseTimeline: base,
        ),
        isFalse,
      );

      // With explicit step7CanHandleBack = false
      expect(
        onboardingShouldShowTopLeftBackButton(
          currentPage: 7,
          baseTimeline: base,
          step7CanHandleBack: false,
        ),
        isFalse,
      );
    });

    test('Active subscreen enables top-left back button', () {
      const base = BaseTimelineDraft(
        skinCareSetupStep: 1,
        skinCareSetupPath: 'has_products',
      );

      expect(
        onboardingShouldShowTopLeftBackButton(
          currentPage: 7,
          baseTimeline: base,
        ),
        isTrue,
      );

      expect(
        onboardingShouldShowTopLeftBackButton(
          currentPage: 7,
          baseTimeline: base,
          step7CanHandleBack: true,
        ),
        isTrue,
      );
    });
  });

  group('Step 7 State Machine Authority & CTA Routing Widget Tests', () {
    List<TimelineBlockDraft> tagSkinCareBlocks(
      List<TimelineBlockDraft> blocks,
      String fingerprint,
    ) {
      final token = 'skin-care-generation:$fingerprint';
      return blocks
          .map(
            (block) => block.section == 'skin_care'
                ? block.copyWith(
                    provenanceSourceIds: {
                      ...block.provenanceSourceIds,
                      token,
                    }.toList(),
                  )
                : block,
          )
          .toList(growable: false);
    }

    OnboardingDraft createHasProductsDraftWithBlocks({
      String uid = 'user-timeline-test',
      int desiredApplicationsPerDay = 2,
    }) {
      final blocks = [
        BaseTimelineDraft.defaultBathBlock(),
        TimelineBlockDraft(
          id: 'skin-morning',
          section: 'skin_care',
          title: 'Morning Skin Care',
          startMinute: 480,
          endMinute: 495,
          repeatDays: onboarding7EveryDay,
          blockType: TimelineBlockDraft.softBlockKey,
          skincareProducts: const ['Gentle Cleanser', 'Barrier Moisturizer'],
          skincareSteps: const ['Cleanse', 'Moisturize'],
          skincareSlotLabel: 'Morning',
        ),
        TimelineBlockDraft(
          id: 'skin-night',
          section: 'skin_care',
          title: 'Night Skin Care',
          startMinute: 1260,
          endMinute: 1275,
          repeatDays: onboarding7EveryDay,
          blockType: TimelineBlockDraft.softBlockKey,
          skincareProducts: const ['Gentle Cleanser', 'Barrier Moisturizer'],
          skincareSteps: const ['Cleanse', 'Moisturize'],
          skincareSlotLabel: 'Night',
        ),
      ];

      const productNames = 'Gentle Cleanser\nBarrier Moisturizer';
      final draftBase = BaseTimelineDraft(
        skinCareSetupStep: 1,
        skinCareSetupPath: 'has_products',
        skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
        skinCareProductNames: productNames,
        skinCareReviewedProducts: onboarding7ParseTypedProductDetails(
          productNames,
        ),
        blocks: blocks,
      );
      final fingerprint = draftBase.computeSkinCareRoutineFingerprint();
      return OnboardingDraft(
        uid: uid,
        currentStep: 7,
        baseTimeline: draftBase.copyWith(
          skinCareRoutineFingerprint: fingerprint,
          blocks: tagSkinCareBlocks(blocks, fingerprint),
        ),
      );
    }

    OnboardingDraft createNoProductsDraftWithBlocks({
      String uid = 'user-timeline-test',
    }) {
      final blocks = [
        BaseTimelineDraft.defaultBathBlock(),
        TimelineBlockDraft(
          id: 'skin-morning',
          section: 'skin_care',
          title: 'Morning Skin Care',
          startMinute: 480,
          endMinute: 495,
          repeatDays: onboarding7EveryDay,
          blockType: TimelineBlockDraft.softBlockKey,
          skincareProducts: const ['Daily Cleanser', 'Barrier Moisturizer'],
          skincareSteps: const ['Cleanse', 'Moisturize'],
          skincareSlotLabel: 'Morning',
        ),
        TimelineBlockDraft(
          id: 'skin-night',
          section: 'skin_care',
          title: 'Night Skin Care',
          startMinute: 1260,
          endMinute: 1275,
          repeatDays: onboarding7EveryDay,
          blockType: TimelineBlockDraft.softBlockKey,
          skincareProducts: const ['Daily Cleanser', 'Barrier Moisturizer'],
          skincareSteps: const ['Cleanse', 'Moisturize'],
          skincareSlotLabel: 'Night',
        ),
      ];

      const recommendations = [
        SkinCareProductRecommendationDraft(
          name: 'Daily Cleanser',
          category: 'cleanser',
        ),
        SkinCareProductRecommendationDraft(
          name: 'Barrier Moisturizer',
          category: 'moisturizer',
        ),
      ];

      final draftBase = BaseTimelineDraft(
        skinCareSetupStep: 1,
        skinCareSetupPath: 'no_products',
        skinCareSkinType: 'normal',
        skinCareProblems: const ['dryness'],
        skinCareBudget: 'medium',
        skinCareDesiredApplicationsPerDay: 2,
        skinCareFacePhotoAssetId: 'skin-asset',
        skinCareFacePhotoR2Key:
            'users/$uid/onboarding/skin_care/skin-asset.jpg',
        skinCareFacePhotoStatus: 'uploaded',
        skinCareFacePhotoCreatedAt: DateTime.utc(2026, 6, 15, 10),
        skinCareFacePhotoUpdatedAt: DateTime.utc(2026, 6, 15, 10),
        skinCareProductRecommendations: recommendations,
        skinCareSelectedProductNames: const [
          'Daily Cleanser',
          'Barrier Moisturizer',
        ],
        skinCareSuggestedProducts: const [
          'Daily Cleanser',
          'Barrier Moisturizer',
        ],
        blocks: blocks,
      );
      final recFingerprint = draftBase
          .computeSkinCareRecommendationFingerprint();
      final draftWithRec = draftBase.copyWith(
        skinCareRecommendationFingerprint: recFingerprint,
      );
      final routineFingerprint = draftWithRec
          .computeSkinCareRoutineFingerprint();
      return OnboardingDraft(
        uid: uid,
        currentStep: 7,
        baseTimeline: draftWithRec.copyWith(
          skinCareRoutineFingerprint: routineFingerprint,
          blocks: tagSkinCareBlocks(blocks, routineFingerprint),
        ),
      );
    }

    testWidgets(
      'Plan-A blocks present while controller is in non-review mode renders selection/input UI, NOT review mode',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // 1. Has-products mode: blocks exist, but entering edit mode suppresses review
        final hasProductsDraft = createHasProductsDraftWithBlocks();

        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              mockOnboardingProvider.overrideWith((ref) {
                final notifier = MockOnboardingNotifier();
                notifier.loadSeedData(hasProductsDraft);
                return notifier;
              }),
            ],
            child: const MaterialApp(home: Scaffold(body: OnboardingStep7())),
          ),
        );
        await tester.pumpAndSettle();

        // Initially in review mode
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );

        // Click Rebuild / Edit
        await tester.tap(find.text('Rebuild / Edit'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Review mode full timeline MUST NOT be rendered
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsNothing,
        );
        // Edit mode input UI MUST be rendered
        expect(find.text('Product names'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('onboarding-step7-cancel-rebuild')),
          findsOneWidget,
        );

        // 2. No-products mode: blocks exist, but editing suppresses review
        final noProductsDraft = createNoProductsDraftWithBlocks();

        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              mockOnboardingProvider.overrideWith((ref) {
                final notifier = MockOnboardingNotifier();
                notifier.loadSeedData(noProductsDraft);
                return notifier;
              }),
            ],
            child: const MaterialApp(home: Scaffold(body: OnboardingStep7())),
          ),
        );
        await tester.pumpAndSettle();

        // Initially in review mode
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );

        // Click Rebuild / Edit
        await tester.tap(find.text('Rebuild / Edit'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Review mode full timeline MUST NOT be rendered
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsNothing,
        );
        // Product selection editor MUST be rendered
        expect(
          find.byKey(
            const ValueKey('onboarding-step7-no-products-cancel-rebuild'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Valid review renders full timeline and provides null custom action so shell owns Next Step',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final draft = createHasProductsDraftWithBlocks();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((ref) {
                final notifier = MockOnboardingNotifier();
                notifier.loadSeedData(draft);
                return notifier;
              }),
            ],
            child: const MaterialApp(home: Scaffold(body: OnboardingStep7())),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingStep7)),
        );

        // Full timeline must be rendered
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );
        expect(find.text('Routine built'), findsOneWidget);

        // Bridge state has NO custom action so shell provides Next Step
        final bridgeState = container.read(step7ActionBridgeProvider);
        expect(bridgeState.action, isNull);
        expect(container.read(onboardingStep7PrimaryActionProvider), isNull);
      },
    );

    testWidgets(
      'Custom CTA clears upon session reset or transitioning to review',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const productNames = 'Cleanser\nMoisturizer';
        final draft = OnboardingDraft(
          uid: 'user-cta-test',
          currentStep: 7,
          baseTimeline: BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'has_products',
            skinCareProductNames: productNames,
            skinCareReviewedProducts: onboarding7ParseTypedProductDetails(
              productNames,
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((ref) {
                final notifier = MockOnboardingNotifier();
                notifier.loadSeedData(draft);
                return notifier;
              }),
            ],
            child: MaterialApp(
              home: OnboardingStepShell(
                currentPage: 7,
                pageOffset: 7,
                completedSteps: List<bool>.filled(
                  OnboardingDraft.stepCount,
                  false,
                ),
                validationMessage: null,
                onDotTap: (_) {},
                onIndicatorDraggedTo: (_) {},
                onNext: () {},
                onSave: () {},
                showSave: false,
                isSaving: false,
                isSaved: false,
                saveEnabled: true,
                ctaLabel: 'Next Step',
                ctaEnabled: true,
                ctaLoading: false,
                child: const OnboardingStep7(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingStep7)),
        );

        // In input mode inside shell, custom CTA 'Build skin routine' was published
        final bridgeState = container.read(step7ActionBridgeProvider);
        expect(bridgeState.action, isNotNull);
        expect(bridgeState.action!.label, 'Build skin routine');
        expect(container.read(onboardingStep7PrimaryActionProvider), isNotNull);

        // Now simulate session reset (authGeneration increment)
        container.read(authGenerationProvider.notifier).state++;
        container
            .read(skinCareFlowControllerProvider.notifier)
            .syncFromDraft(
              draft.baseTimeline,
              'user-cta-test',
              authGeneration: 1,
            );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Session reset must have wiped the active custom action
        expect(container.read(step7ActionBridgeProvider).action, isNull);
        expect(container.read(onboardingStep7PrimaryActionProvider), isNull);
      },
    );
  });
}
