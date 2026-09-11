import 'dart:async';
import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_controller.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_state.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_timeline_preview.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/device_country_service.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/features/uploads/controllers/upload_interaction_controller.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/features/uploads/services/upload_permission_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  Widget buildTestWidget({
    OnboardingDraft draft = const OnboardingDraft(currentStep: 7),
    SkinCareAiClient? client,
    TestUploadController? uploadController,
    TestUploadInteractionController? interactionController,
    DeviceCountry? detectedCountry,
    DeviceCountryService? countryService,
    RegionSettings? regionSettings,
    UploadedAssetRepository? assetRepository,
    ValueNotifier<bool>? showStep,
    bool overrideSkinCareClient = true,
  }) {
    final effectiveInteraction =
        interactionController ??
        TestUploadInteractionController(
          result: uploadController?.result,
          initialLegacyState: uploadController?.state,
          legacyProbe: uploadController,
        );
    return ProviderScope(
      overrides: [
        onboardingStateProvider.overrideWith((ref) {
          final notifier = OnboardingNotifier();
          notifier.loadSeedData(draft);
          return notifier;
        }),
        if (overrideSkinCareClient)
          skinCareAiClientProvider.overrideWithValue(
            client ?? const FakeSkinCareAiClient(),
          ),
        uploadControllerProvider.overrideWith(
          (ref) => uploadController ?? TestUploadController(),
        ),
        onboardingUploadInteractionProvider.overrideWith(
          (ref) => effectiveInteraction,
        ),
        if (assetRepository != null)
          uploadedAssetRepositoryProvider.overrideWithValue(assetRepository),
        deviceCountryServiceProvider.overrideWithValue(
          countryService ?? TestDeviceCountryService(detectedCountry),
        ),
        if (regionSettings != null)
          regionSettingsProvider.overrideWith((ref) {
            final notifier = RegionSettingsNotifier(
              ref.read(regionSettingsRepositoryProvider),
              ref.read(deviceCountryServiceProvider),
            );
            notifier.loadSettings(regionSettings);
            return notifier;
          }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: showStep == null
              ? const OnboardingStep7()
              : ValueListenableBuilder<bool>(
                  valueListenable: showStep,
                  builder: (_, visible, _) =>
                      visible ? const OnboardingStep7() : const SizedBox(),
                ),
        ),
      ),
    );
  }

  void useAndroidWidth(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> tapBuildRoutine(WidgetTester tester) async {
    await tester.pump();
    final btn = find.byKey(const ValueKey('onboarding-step7-generate-button'));
    if (btn.evaluate().isNotEmpty) {
      final needsPhotoReview = find
          .text('Read product labels')
          .evaluate()
          .isNotEmpty;
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      if (needsPhotoReview) {
        final btn2 = find.byKey(
          const ValueKey('onboarding-step7-generate-button'),
        );
        await tester.ensureVisible(btn2);
        await tester.pump();
        await tester.tap(btn2);
        await tester.pumpAndSettle();
      }
    }
  }

  void triggerRebuild(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    container.read(skinCareFlowControllerProvider.notifier).handleBack();
  }

  Future<void> chooseSkinPhotoFromGallery(WidgetTester tester) async {
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('onboarding-step7-take-photo')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('onboarding-step7-choose-gallery')),
    );
    await tester.pumpAndSettle();
  }

  for (final code in <String, AiGenerationErrorCategory>{
    'provider_timeout': AiGenerationErrorCategory.timeout,
    'provider_quota_exceeded': AiGenerationErrorCategory.rateLimited,
    'provider_invalid_json': AiGenerationErrorCategory.responseInvalid,
    'network_unavailable': AiGenerationErrorCategory.serviceUnavailable,
    'provider_unavailable': AiGenerationErrorCategory.serviceUnavailable,
  }.entries) {
    test(
      'AI error category ${code.key}',
      () => expect(onboarding7AiErrorCategory(code.key), code.value),
    );
  }
  for (final product in [true, false]) {
    testWidgets(
      '${product ? "Product" : "Face"} source sheet dismissal does not pick or mutate',
      (tester) async {
        useAndroidWidth(tester);
        final interaction = TestUploadInteractionController();
        await tester.pumpWidget(
          buildTestWidget(
            draft: product ? _hasProductsDraft() : _noProductsDraft(),
            interactionController: interaction,
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingStep7)),
        );
        final before = container.read(onboardingStateProvider).draft.toMap();
        await tester.tap(
          find.byKey(const ValueKey('onboarding-step7-photo-tile')).first,
        );
        await tester.pumpAndSettle();
        Navigator.of(
          tester.element(
            find.byKey(const ValueKey('onboarding-step7-choose-gallery')),
          ),
        ).pop();
        await tester.pumpAndSettle();
        expect(interaction.startUploadCalls, 0);
        expect(container.read(onboardingStateProvider).draft.toMap(), before);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${product ? "Product" : "Face"} stale routine survives reconstruction',
      (tester) async {
        useAndroidWidth(tester);
        final seed = product
            ? _hasProductsDraft(blocks: _skinCareBlocksForEveryDay(2))
            : _noProductsDraft(blocks: _skinCareBlocksForEveryDay(2));
        final stale = seed.copyWith(
          baseTimeline: seed.baseTimeline.copyWith(
            clearSkinCareRoutineFingerprint: true,
          ),
        );
        await tester.pumpWidget(buildTestWidget(draft: stale));
        await tester.pumpAndSettle();
        expect(onboarding7CanContinue(stale.baseTimeline, stale.uid), isFalse);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          buildTestWidget(draft: OnboardingDraft.fromMap(stale.toMap())),
        );
        await tester.pumpAndSettle();
        final reconstructed = OnboardingDraft.fromMap(stale.toMap());
        expect(
          onboarding7CanContinue(reconstructed.baseTimeline, reconstructed.uid),
          isFalse,
        );
      },
    );
  }
  testWidgets(
    'Repeated whitespace selection resolves in final routine request',
    (tester) async {
      useAndroidWidth(tester);
      final recommendations = _productRecommendationDraftsForTest()
          .take(3)
          .toList();
      final client = TestSkinCareAiClient(
        routineResult: _routineResultWithPlanCount(2),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _noProductsDraft(
            skinType: 'oily',
            problems: ['pimples'],
            budget: 'medium',
            withPhoto: true,
            blocks: [BaseTimelineDraft.defaultBathBlock()],
            recommendations: recommendations,
            selectedProducts: recommendations
                .map((p) => p.displayName.replaceAll(' ', '   '))
                .toList(),
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();
      await tapBuildRoutine(tester);
      expect(client.generateCalls, hasLength(1));
      expect(
        (client.generateCalls.single['typedProductDetails'] as List).map(
          (p) => p['name'],
        ),
        recommendations.map((p) => p.name),
      );
      expect(
        client.generateCalls.single.containsKey('facePhotoR2Key'),
        isFalse,
      );
      expect(find.text('Skin Care Routine'), findsOneWidget);
    },
  );

  for (final product in [true, false]) {
    testWidgets(
      '${product ? "Product" : "Face"} same-file retry skips source chooser',
      (tester) async {
        useAndroidWidth(tester);
        final interaction = TestUploadInteractionController()
          ..seedFailedAttempt(product);
        await tester.pumpWidget(
          buildTestWidget(
            draft: product ? _hasProductsDraft() : _noProductsDraft(),
            interactionController: interaction,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('onboarding-step7-photo-tile')).first,
        );
        await tester.pumpAndSettle();
        expect(interaction.startUploadCalls, 1);
        expect(
          find.byKey(const ValueKey('onboarding-step7-choose-gallery')),
          findsNothing,
        );
      },
    );
  }
  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('Selected products sheet and list width=$width large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final products = _productRecommendationDraftsForTest().take(3).toList();
      await tester.pumpWidget(
        buildTestWidget(
          draft: _noProductsDraft(
            blocks: _skinCareBlocksForEveryDay(2),
            recommendations: products,
            selectedProducts: products.map((p) => p.displayName).toList(),
            suggestedProducts: products.map((p) => p.displayName).toList(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Skin Care Routine'), findsOneWidget);
      expect(find.text('Review your weekly routine'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('onboarding-step7-full-timeline')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      container.read(skinCareFlowControllerProvider.notifier).handleBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(products.first.displayName));
      await tester.tap(find.text(products.first.displayName));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('No products responsive width=$width text=$scale keyboard', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          buildTestWidget(
            draft: _noProductsDraft(
              skinType: 'oily',
              problems: ['pimples'],
              budget: 'medium',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Add photo'));
        expect(find.text('Add photo').hitTestable(), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('onboarding-step7-frequency-3')),
        );
        expect(
          find
              .byKey(const ValueKey('onboarding-step7-frequency-3'))
              .hitTestable(),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Find products'));
        expect(find.text('Find products').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Find products'));
        expect(find.text('Find products').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('1. Global CTA hides while keyboard is open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 320),
          ),
          child: OnboardingStepShell(
            currentPage: 7,
            pageOffset: 7,
            completedSteps: List<bool>.filled(OnboardingDraft.stepCount, false),
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
            child: const Center(child: TextField()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next Step'), findsNothing);
  });

  testWidgets('1b. Next Step floats above the shared background', (
    tester,
  ) async {
    useAndroidWidth(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingStepShell(
          currentPage: 7,
          pageOffset: 7,
          completedSteps: List<bool>.filled(OnboardingDraft.stepCount, false),
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
          child: const ColoredBox(
            key: ValueKey('full-background-step-content'),
            color: Colors.transparent,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final contentRect = tester.getRect(
      find.byKey(const ValueKey('full-background-step-content')),
    );
    final ctaRect = tester.getRect(
      find.byKey(const ValueKey('onboarding-cta-visible')),
    );
    expect(contentRect.bottom, equals(ctaRect.bottom));
  });

  testWidgets('2. I have products mode opens immediately', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('I have products'));
    await tester.pumpAndSettle();

    expect(find.text('Product names'), findsOneWidget);
    expect(
      find.text(
        'Upload one clear photo with all your skin-care products together. Keep front labels visible.',
      ),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    expect(
      container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .skinCareSetupStep,
      1,
    );
  });

  testWidgets('choice disposal during async skip cleanup does not mutate', (
    tester,
  ) async {
    final repository = _DelayedAssetRepository();
    await tester.pumpWidget(
      buildTestWidget(
        draft: const OnboardingDraft(uid: 'uid-1', currentStep: 7),
        assetRepository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(repository.fetchStarted, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    repository.fetchGate.complete(const []);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '3. Product photo tile and product-name input are visible, enabled, equal height, and side-by-side',
    (tester) async {
      useAndroidWidth(tester);
      await tester.pumpWidget(buildTestWidget(draft: _hasProductsDraft()));
      await tester.pumpAndSettle();

      final photoFinder = find.byKey(
        const ValueKey('onboarding-step7-photo-tile'),
      );
      final inputFinder = find.byKey(
        const ValueKey('onboarding-step7-product-names-tile'),
      );
      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      );

      expect(photoFinder, findsOneWidget);
      expect(inputFinder, findsOneWidget);
      expect(textField.enabled, isNot(false));

      final photoRect = tester.getRect(photoFinder);
      final inputRect = tester.getRect(inputFinder);
      expect((photoRect.height - inputRect.height).abs(), lessThan(1));
      expect(photoRect.right, lessThan(inputRect.left));
    },
  );

  testWidgets('4. Uploaded photo labels must be reviewed before generation', (
    tester,
  ) async {
    useAndroidWidth(tester);
    final asset = _uploadedAsset();
    final client = TestSkinCareAiClient(
      productResult: const SkinCareAiProductResult(
        products: [
          {'name': 'Photo Cleanser', 'category': 'cleanser'},
        ],
      ),
    );
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(uid: 'uid-1'),
        client: client,
        uploadController: TestUploadController(result: asset),
      ),
    );
    await tester.pumpAndSettle();

    final emptyCardHeight = tester
        .getSize(
          find.byKey(const ValueKey('onboarding-step7-products-setup-card')),
        )
        .height;

    await chooseSkinPhotoFromGallery(tester);
    expect(find.text('Photo uploaded'), findsOneWidget);
    expect(find.text('Using product photo'), findsOneWidget);
    expect(find.text('Read product labels'), findsOneWidget);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('onboarding-step7-products-setup-card')),
          )
          .height,
      emptyCardHeight,
    );

    var textField = tester.widget<TextField>(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
    );
    expect(textField.enabled, isTrue);

    await tester.ensureVisible(find.text('Read product labels'));
    await tester.tap(find.text('Read product labels'));
    await tester.pumpAndSettle();

    textField = tester.widget<TextField>(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
    );
    expect(textField.enabled, isTrue);
    expect(find.text('Photo Cleanser - cleanser'), findsOneWidget);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('onboarding-step7-products-setup-card')),
          )
          .height,
      emptyCardHeight,
    );
    expect(
      find.byKey(const ValueKey('onboarding-step7-product-count')),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('onboarding-step7-generate-button')),
          )
          .bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
    expect(client.analyzeCalls, 1);
    expect(client.generateCalls, isEmpty);
  });

  testWidgets('5. Missing photo/text disables routine generation', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(draft: _hasProductsDraft()));
    await tester.pumpAndSettle();

    final buttonGesture = find
        .ancestor(
          of: find.byKey(const ValueKey('onboarding-step7-generate-button')),
          matching: find.byType(GestureDetector),
        )
        .first;
    expect(tester.widget<GestureDetector>(buttonGesture).onTap, isNull);
  });

  testWidgets('6. Upload busy state shows loading inside photo tile', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(),
        uploadController: TestUploadController(
          initialState: const UploadState(
            status: UploadFlowStatus.uploading,
            purpose: UploadedAssetPurpose.skinProducts,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Uploading photo...'), findsOneWidget);
  });

  testWidgets('6b. Typing product names still allows the photo workflow', (
    tester,
  ) async {
    final uploadController = TestUploadController(result: _uploadedAsset());
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(),
        uploadController: uploadController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Minimalist SPF 50 - sunscreen',
    );
    await tester.pumpAndSettle();

    expect(find.text('Using typed product names'), findsOneWidget);
    expect(
      find.text('Or add one photo, then review the detected products.'),
      findsOneWidget,
    );
    await chooseSkinPhotoFromGallery(tester);
    expect(uploadController.startUploadCalls, 1);
  });

  testWidgets('6c. Clearing typed product names re-enables photo upload', (
    tester,
  ) async {
    final uploadController = TestUploadController(result: _uploadedAsset());
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(),
        uploadController: uploadController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Minimalist SPF 50 - sunscreen',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      '',
    );
    await tester.pumpAndSettle();

    expect(find.text('Using typed product names'), findsNothing);
    await chooseSkinPhotoFromGallery(tester);
    expect(uploadController.startUploadCalls, 1);
    expect(find.text('Photo uploaded'), findsOneWidget);
  });

  testWidgets(
    '6d. Product names field remains enabled after adding or removing photo',
    (tester) async {
      final uploadController = TestUploadController(result: _uploadedAsset());
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(uid: 'uid-1'),
          uploadController: uploadController,
        ),
      );
      await tester.pumpAndSettle();

      await chooseSkinPhotoFromGallery(tester);
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey('onboarding-step7-product-names-field'),
              ),
            )
            .enabled,
        isTrue,
      );

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-remove-photo-button')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey('onboarding-step7-product-names-field'),
              ),
            )
            .enabled,
        isTrue,
      );
      expect(find.text('Photo uploaded'), findsNothing);
      expect(uploadController.markDeletedCalls, 1);
    },
  );

  testWidgets('6f. Personalization is persisted and sent to routine AI', (
    tester,
  ) async {
    final client = TestSkinCareAiClient(
      routineResult: _routineResultWithPlanCount(2),
    );
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Personalize routine'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Oily'));
    await tester.tap(find.text('Oily'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Acne'));
    await tester.tap(find.text('Acne'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simple'));
    await tester.tap(find.text('Simple'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('onboarding-step7-personalize-done')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Cleanser\nSunscreen',
    );
    await tapBuildRoutine(tester);
    await tester.pumpAndSettle();

    expect(client.lastGenerateParams?['skinType'], 'oily');
    expect(client.lastGenerateParams?['mainProblem'], 'pimples');
    expect(client.lastGenerateParams?['routinePreference'], 'simple');
  });

  testWidgets(
    '6g. Personalization sheet is scrollable and all contents reachable without overflow on compact screens',
    (tester) async {
      for (final size in const [Size(360, 640), Size(360, 800)]) {
        for (final textScale in const [1.0, 1.5, 2.0]) {
          tester.view.physicalSize = Size(size.width * 2, size.height * 2);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(textScale),
                viewPadding: const EdgeInsets.only(bottom: 24),
              ),
              child: buildTestWidget(draft: _hasProductsDraft(uid: 'uid-1')),
            ),
          );
          await tester.pumpAndSettle();

          final personalizeBtn = find.text('Personalize routine');
          await tester.ensureVisible(personalizeBtn);
          await tester.tap(personalizeBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('onboarding-step7-personalize-sheet')),
            findsOneWidget,
          );

          final sheetScrollable = find.descendant(
            of: find.byKey(
              const ValueKey('onboarding-step7-personalize-sheet'),
            ),
            matching: find.byType(SingleChildScrollView),
          );
          expect(sheetScrollable, findsOneWidget);

          // Drag to verify scrolling inside sheet
          await tester.drag(sheetScrollable, const Offset(0, -100));
          await tester.pumpAndSettle();

          // Done button is pinned in header, reachable, and taps cleanly
          final doneBtn = find.byKey(
            const ValueKey('onboarding-step7-personalize-done'),
          );
          expect(doneBtn, findsOneWidget);
          await tester.tap(doneBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('onboarding-step7-personalize-sheet')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('6e. Switching source does not silently delete typed text', (
    tester,
  ) async {
    final asset = _uploadedAsset();
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(
          productNames: 'Saved Cleanser - cleanser',
          productPhotoAssetId: asset.assetId,
          productPhotoR2Key: asset.r2Key,
          productPhotoStatus: 'uploaded',
          productPhotoCreatedAt: asset.createdAt,
          productPhotoUpdatedAt: asset.updatedAt,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Photo uploaded'), findsOneWidget);
    expect(find.text('Saved Cleanser - cleanser'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('onboarding-step7-remove-photo-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved Cleanser - cleanser'), findsOneWidget);
    final base = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    ).read(onboardingStateProvider).draft.baseTimeline;
    expect(base.skinCareProductNames, 'Saved Cleanser - cleanser');
    expect(base.skinCareProductPhotoR2Key, isNull);
  });

  testWidgets('7. Missing skin-care worker URL shows debug-safe error', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(),
        client: TestSkinCareAiClient(
          routineResult: SkinCareAiRoutineResult.error('missing_worker_url'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Cleanser',
    );
    await tapBuildRoutine(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Missing skin-care worker URL'), findsOneWidget);
    expect(find.textContaining('OPTIVUS_SKIN_CARE_WORKER_URL'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    expect(
      container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care'),
      isEmpty,
    );
  });

  test('7b. Provider failures retain actionable skin-care messages', () {
    expect(
      onboarding7FriendlyAiMessage('provider_unauthorized', const []),
      'Skin care AI provider authorization failed. Check the worker configuration.',
    );
    expect(
      onboarding7FriendlyAiMessage('provider_model_not_found', const []),
      'Skin care AI model is unavailable. Check the worker model configuration.',
    );
    expect(
      onboarding7FriendlyAiMessage('provider_quota_exceeded', const []),
      'AI usage limit reached. Try again later.',
    );
    expect(
      onboarding7FriendlyAiMessage('provider_timeout', const []),
      'AI skin care service is unavailable. Try again later.',
    );
    expect(
      onboarding7FriendlyAiMessage('provider_invalid_image_payload', const []),
      'AI could not process this photo. Upload a clearer JPEG, PNG, or WEBP image.',
    );
    expect(
      onboarding7FriendlyAiMessage(null, const [
        'ai_recommendation_repair_failed:provider_high_demand',
      ]),
      "We found some products, but couldn't complete the required product set right now. Retry product recommendations.",
    );
  });

  test('7c. Unexpected worker exceptions use stable user-facing messages', () {
    expect(
      onboarding7UnexpectedAiMessage(
        const SocketException('Failed host lookup'),
      ),
      'AI skin care service is unavailable. Check your connection and try again.',
    );
    expect(
      onboarding7UnexpectedAiMessage(const FormatException('Invalid JSON')),
      'AI response could not be read safely. Please try again.',
    );
    expect(
      onboarding7UnexpectedAiMessage(StateError('unexpected state')),
      'AI could not generate the routine. Please try again.',
    );
  });

  test('8. Product analysis maps Map products safely into names', () {
    final names = onboarding7ExtractPhotoProductNames([
      {'brand': 'CeraVe', 'name': 'Hydrating Cleanser', 'category': 'cleanser'},
      {'name': 'Hydrating Cleanser'},
      'Sunscreen SPF 50',
      {'name': ''},
      {'brand': 'CeraVe', 'name': 'Hydrating Cleanser'},
    ]);

    expect(names, [
      'CeraVe Hydrating Cleanser',
      'Hydrating Cleanser',
      'Sunscreen SPF 50',
    ]);
  });

  test('8b. Typed product parser supports dash colon and parentheses', () {
    final products = onboarding7ParseTypedProductDetails(
      'Beardo Detan Face Wash - cleanser\n'
      'Minimalist SPF 50: sunscreen\n'
      'Minimalist Vitamin C (serum)',
    );

    expect(products.map((product) => product.name), [
      'Beardo Detan Face Wash',
      'Minimalist SPF 50',
      'Minimalist Vitamin C',
    ]);
    expect(products.map((product) => product.category), [
      'cleanser',
      'sunscreen',
      'serum',
    ]);
    expect(products.map((product) => product.source).toSet(), {'typed'});
  });

  testWidgets(
    '8d. Photo review persists rich metadata immediately and restores before routine generation',
    (tester) async {
      final richProduct = {
        'name': 'Daily UV Fluid',
        'brand': 'Example Lab',
        'category': 'sunscreen',
        'source': 'photo',
        'keyIngredients': ['zinc oxide'],
        'possibleActives': ['UV filters'],
        'usageHint': 'Apply every morning',
        'warningIfAny': 'Reapply outdoors',
        'confidence': 'high',
      };
      final analyzeClient = TestSkinCareAiClient(
        productResult: SkinCareAiProductResult(products: [richProduct]),
      );
      final initial = _hasProductsDraft(
        productPhotoAssetId: 'product-photo',
        productPhotoR2Key:
            'users/uid-1/onboarding/skin_products/product-photo.jpg',
        productPhotoStatus: 'uploaded',
        productPhotoCreatedAt: DateTime.utc(2026, 6, 15),
        productPhotoUpdatedAt: DateTime.utc(2026, 6, 15),
      );
      await tester.pumpWidget(
        buildTestWidget(draft: initial, client: analyzeClient),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-generate-button')),
      );
      await tester.pumpAndSettle();

      final firstContainer = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final persisted = firstContainer.read(onboardingStateProvider).draft;
      final reviewed = persisted.baseTimeline.skinCareReviewedProducts.single;
      expect(reviewed.keyIngredients, ['zinc oxide']);
      expect(reviewed.possibleActives, ['UV filters']);
      expect(reviewed.warningIfAny, 'Reapply outdoors');

      final routineClient = TestSkinCareAiClient();
      await tester.pumpWidget(
        buildTestWidget(draft: persisted, client: routineClient),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey('onboarding-step7-product-names-field'),
              ),
            )
            .controller!
            .text,
        contains('Example Lab Daily UV Fluid'),
      );

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-generate-button')),
      );
      await tester.pumpAndSettle();
      final details =
          routineClient.lastGenerateParams!['typedProductDetails']
              as List<dynamic>;
      expect(details.single['keyIngredients'], ['zinc oxide']);
      expect(details.single['possibleActives'], ['UV filters']);
      expect(details.single['warningIfAny'], 'Reapply outdoors');
    },
  );

  test(
    '8e. Product edits reconcile canonical metadata and stale fingerprints',
    () {
      const original = SkinCareDetectedProduct(
        name: 'Daily UV Fluid',
        brand: 'Example Lab',
        category: 'sunscreen',
        source: 'photo',
        keyIngredients: ['zinc oxide'],
        possibleActives: ['UV filters'],
        warningIfAny: 'Reapply outdoors',
        confidence: 'high',
      );
      final base = BaseTimelineDraft(
        skinCareSetupPath: 'has_products',
        skinCareProductNames: 'Example Lab Daily UV Fluid - sunscreen',
        skinCareReviewedProducts: const [original],
      );
      final acceptedFingerprint = base.computeSkinCareRoutineFingerprint();

      final added = onboarding7ReconcileReviewedProducts(
        '${base.skinCareProductNames}\nGentle Wash - cleanser',
        base.skinCareReviewedProducts,
      );
      expect(added, hasLength(2));
      expect(added.first.keyIngredients, ['zinc oxide']);
      final addedDraft = base.copyWith(
        skinCareProductNames:
            '${base.skinCareProductNames}\nGentle Wash - cleanser',
        skinCareReviewedProducts: added,
      );
      expect(
        addedDraft.computeSkinCareRoutineFingerprint(),
        isNot(acceptedFingerprint),
      );

      final removed = onboarding7ReconcileReviewedProducts(
        'Gentle Wash - cleanser',
        added,
      );
      expect(removed.map((product) => product.displayName), ['Gentle Wash']);
      expect(
        addedDraft
            .copyWith(
              skinCareProductNames: 'Gentle Wash - cleanser',
              skinCareReviewedProducts: removed,
            )
            .computeSkinCareRoutineFingerprint(),
        isNot(addedDraft.computeSkinCareRoutineFingerprint()),
      );

      final renamed = onboarding7ReconcileReviewedProducts(
        'Different UV Fluid - sunscreen',
        const [original],
      ).single;
      expect(renamed.keyIngredients, isNot(contains('zinc oxide')));
      expect(renamed.source, 'typed');
      expect(renamed.warningIfAny, isEmpty);
      expect(
        base
            .copyWith(skinCareProductNames: 'Different UV Fluid - sunscreen')
            .computeSkinCareRoutineFingerprint(),
        isNot(acceptedFingerprint),
      );
    },
  );

  test('8c. Typed product parser preserves full five-line owned products', () {
    final products = onboarding7ParseTypedProductDetails(
      'Beardo Detan Face Wash - cleanser\n'
      'Minimalist SPF 50 - sunscreen\n'
      'Minimalist Vitamin C - serum\n'
      'Minimalist Alpha Arbutin - serum\n'
      'Minimalist PHA Toner - exfoliant',
    );

    expect(
      products.map(
        (product) => {'name': product.name, 'category': product.category},
      ),
      [
        {'name': 'Beardo Detan Face Wash', 'category': 'cleanser'},
        {'name': 'Minimalist SPF 50', 'category': 'sunscreen'},
        {'name': 'Minimalist Vitamin C', 'category': 'serum'},
        {'name': 'Minimalist Alpha Arbutin', 'category': 'serum'},
        {'name': 'Minimalist PHA Toner', 'category': 'exfoliant'},
      ],
    );
  });

  testWidgets('9. Empty timelineBlocks does not create fallback blocks', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(),
        client: TestSkinCareAiClient(
          routineResult: const SkinCareAiRoutineResult(
            morningRoutine: [],
            nightRoutine: [],
            weeklyRoutine: [],
            timelineBlocks: [
              {
                'title': 'Morning skin care',
                'startMinute': 420,
                'endMinute': 435,
                'products': ['Cleanser'],
                'steps': ['Cleanse'],
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Cleanser',
    );
    await tapBuildRoutine(tester);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    expect(
      container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care'),
      isEmpty,
    );
    expect(find.text('Morning skin care'), findsNothing);
    expect(
      find.text(
        'AI returned no usable routine. Try clearer product names or 2 times/day.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    '10. Successful generation creates valid scheduled skin_care blocks',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: const SkinCareAiRoutineResult(
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'morning',
              title: 'Morning Skin Care',
              steps: ['Face wash', 'Apply sunscreen'],
              productNames: ['Cleanser', 'Sunscreen'],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Night Skin Care',
              steps: ['Face wash', 'Moisturizer'],
              productNames: ['Cleanser', 'Moisturizer'],
            ),
          ],
          morningRoutine: [],
          nightRoutine: [],
          weeklyRoutine: [],
          timelineBlocks: [],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser\nSunscreen\nMoisturizer',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      final blocks = base.confirmedBlocksForSection('skin_care');
      expect(blocks, hasLength(2));
      expect(blocks.first.section, 'skin_care');
      expect(blocks.first.blockType, TimelineBlockDraft.softBlockKey);
      expect(blocks.first.source, onboardingSkinCareGeneratedSource);
      expect(blocks.first.repeatDays, onboarding7EveryDay);
      expect(
        blocks.every(
          (block) =>
              block.endMinute - block.startMinute ==
              onboarding7SkinCareDurationMinutes,
        ),
        isTrue,
      );
      expect(blocks.first.startMinute, greaterThanOrEqualTo(450));
      expect(blocks.first.skincareProducts, ['Cleanser', 'Sunscreen']);
      expect(blocks.first.skincareSteps, ['Face wash', 'Apply sunscreen']);
      expect(client.lastGenerateParams?['typedProductNames'], isNull);
      expect(client.lastGenerateParams?['productsFromPhoto'], isNull);
      expect(client.lastGenerateParams?['productInputSource'], 'typed');
      expect(client.lastGenerateParams?['typedProductDetails'], [
        {
          'name': 'Cleanser',
          'brand': '',
          'category': 'cleanser',
          'source': 'typed',
          'keyIngredients': ['gentle surfactants', 'water'],
          'possibleActives': [],
          'usageHint': 'Apply AM/PM to cleanse skin',
          'warningIfAny': '',
          'confidence': 'high',
        },
        {
          'name': 'Sunscreen',
          'brand': '',
          'category': 'sunscreen',
          'source': 'typed',
          'keyIngredients': ['UV filters'],
          'possibleActives': ['zinc oxide'],
          'usageHint': 'Apply every morning as last step',
          'warningIfAny': '',
          'confidence': 'high',
        },
        {
          'name': 'Moisturizer',
          'brand': '',
          'category': 'moisturizer',
          'source': 'typed',
          'keyIngredients': ['ceramides', 'glycerin'],
          'possibleActives': [],
          'usageHint': 'Apply AM/PM after cleansing/serums',
          'warningIfAny': '',
          'confidence': 'high',
        },
      ]);
      expect(client.lastGenerateParams?['desiredApplicationsPerDay'], 2);
    },
  );

  testWidgets(
    '10b. Text-only routine with provided products generates exact owned names',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: const SkinCareAiRoutineResult(
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'morning',
              title: 'Morning Skin Care',
              steps: ['Face wash', 'Vitamin C serum', 'Sunscreen'],
              productNames: [
                'face wash',
                'Vitamin C serum',
                'Minimalist SPF 50 Sunscreen',
              ],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Night Skin Care',
              steps: [
                'Face wash',
                'Alpha Arbutin serum',
                'Add moisturizer after serum when available',
              ],
              productNames: ['cleanser', 'Alpha Arbutin serum'],
              missingItems: [
                SkinCareMissingItem(
                  name: 'Moisturizer',
                  importance: 'important',
                  reason: 'Helps reduce dryness/irritation after serum.',
                ),
              ],
            ),
          ],
          morningRoutine: [],
          nightRoutine: [],
          weeklyRoutine: [
            'Use Minimalist PHA Toner 1-2 times/week at night. Do not combine with other strong actives.',
          ],
          timelineBlocks: [],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Beardo Detan Face Wash - cleanser\n'
        'Minimalist SPF 50 - sunscreen\n'
        'Minimalist Vitamin C - serum\n'
        'Minimalist Alpha Arbutin - serum\n'
        'Minimalist PHA Toner - exfoliant',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      final blocks = base.confirmedBlocksForSection('skin_care');

      expect(blocks, hasLength(2));
      expect(
        blocks
            .singleWhere((block) => block.skincareSlotLabel == 'morning')
            .skincareProducts,
        ['Beardo Detan Face Wash', 'Minimalist Vitamin C', 'Minimalist SPF 50'],
      );
      expect(
        blocks
            .singleWhere((block) => block.skincareSlotLabel == 'night')
            .skincareProducts,
        ['Beardo Detan Face Wash', 'Minimalist Alpha Arbutin'],
      );
      final nightBlock = blocks.singleWhere(
        (block) => block.skincareSlotLabel == 'night',
      );
      expect(nightBlock.skincareMissingItems, [
        'Moisturizer (important, missing)',
      ]);
      expect(nightBlock.skincareProducts, isNot(contains('Moisturizer')));
      expect(find.text('Moisturizer (important, missing)'), findsOneWidget);
      expect(
        base.skinCareSpecialCareNotes,
        contains(
          'Use Minimalist PHA Toner 1-2 times/week at night. Do not combine with other strong actives.',
        ),
      );
      expect(client.analyzeCalls, 0);
      expect(client.lastGenerateParams?['productsFromPhoto'], isNull);
      expect(client.lastGenerateParams?['typedProductDetails'], isNotNull);
    },
  );

  testWidgets(
    '10bb. Typed products keep the setup card compact before generate',
    (tester) async {
      tester.view.physicalSize = const Size(390, 630);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emptyCardHeight = tester
          .getSize(
            find.byKey(const ValueKey('onboarding-step7-products-setup-card')),
          )
          .height;

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Beardo Detan Face Wash - cleanser\n'
        'Minimalist SPF 50 - sunscreen\n'
        'Minimalist Vitamin C - serum\n'
        'Minimalist Alpha Arbutin - serum\n'
        'Minimalist PHA Toner - exfoliant',
      );
      await tester.pumpAndSettle();

      final populatedCardHeight = tester
          .getSize(
            find.byKey(const ValueKey('onboarding-step7-products-setup-card')),
          )
          .height;
      expect(populatedCardHeight, emptyCardHeight);
      expect(
        find.byKey(const ValueKey('onboarding-step7-product-count')),
        findsOneWidget,
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('onboarding-step7-generate-button')),
            )
            .bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      expect(
        find.descendant(
          of: find.byType(OnboardingStep7),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '10c. PHA moves to special-care note without deleting daily routine',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: const SkinCareAiRoutineResult(
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'morning',
              title: 'Morning Skin Care',
              steps: ['Face wash', 'Vitamin C serum', 'Sunscreen'],
              productNames: [
                'Beardo Detan Face Wash',
                'Minimalist Vitamin C',
                'Minimalist SPF 50',
              ],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Night Skin Care',
              steps: [
                'Face wash',
                'Alpha Arbutin serum',
                'Use Minimalist PHA Toner 1-2 times/week at night',
              ],
              productNames: [
                'Beardo Detan Face Wash',
                'Minimalist Alpha Arbutin',
                'Minimalist PHA Toner',
              ],
            ),
          ],
          morningRoutine: [],
          nightRoutine: [],
          weeklyRoutine: [],
          timelineBlocks: [],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Beardo Detan Face Wash - cleanser\n'
        'Minimalist SPF 50 - sunscreen\n'
        'Minimalist Vitamin C - serum\n'
        'Minimalist Alpha Arbutin - serum\n'
        'Minimalist PHA Toner - exfoliant',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(onboardingStateProvider).draft.baseTimeline;
      final blocks = base.confirmedBlocksForSection('skin_care');
      final nightBlock = blocks.singleWhere(
        (block) => block.skincareSlotLabel == 'night',
      );

      expect(blocks, hasLength(2));
      expect(nightBlock.skincareProducts, [
        'Beardo Detan Face Wash',
        'Minimalist Alpha Arbutin',
      ]);
      expect(
        nightBlock.skincareProducts,
        isNot(contains('Minimalist PHA Toner')),
      );
      expect(
        base.skinCareSpecialCareNotes,
        contains(
          startsWith('Special care: Night Skin Care - Minimalist PHA Toner'),
        ),
      );
      expect(
        find.textContaining('AI returned no usable routine'),
        findsNothing,
      );
    },
  );

  testWidgets('10d. Mode 1 notes drop outside product suggestions', (
    tester,
  ) async {
    final client = TestSkinCareAiClient(
      routineResult: const SkinCareAiRoutineResult(
        suggestedProducts: [
          'Try CeraVe Moisturizing Cream',
          'Use La Roche-Posay Anthelios Sunscreen',
          "Consider Paula's Choice BHA",
        ],
        routinePlans: [
          SkinCareRoutinePlan(
            slotLabel: 'morning',
            title: 'Morning Skin Care',
            steps: ['Cleanse', 'Apply sunscreen'],
            productNames: ['Cleanser', 'Sunscreen'],
          ),
          SkinCareRoutinePlan(
            slotLabel: 'night',
            title: 'Night Skin Care',
            steps: ['Cleanse'],
            productNames: ['Cleanser'],
          ),
        ],
        morningRoutine: [],
        nightRoutine: [],
        weeklyRoutine: [],
        timelineBlocks: [],
      ),
    );
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Cleanser - cleanser\nSunscreen - sunscreen',
    );
    await tapBuildRoutine(tester);
    await tester.pumpAndSettle();

    final notes = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    ).read(onboardingStateProvider).draft.baseTimeline.skinCareSpecialCareNotes;
    final joinedNotes = notes.join(' ').toLowerCase();

    expect(notes, isEmpty);
    expect(joinedNotes, isNot(contains('cerave')));
    expect(joinedNotes, isNot(contains('la roche')));
    expect(joinedNotes, isNot(contains('paula')));
    expect(
      find.byKey(const ValueKey('onboarding-step7-special-care-notes-button')),
      findsNothing,
    );
  });

  testWidgets('11. Step 7 uses full timeline instead of mini block list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(
          blocks: const [
            TimelineBlockDraft(
              id: 'skin-morning',
              section: 'skin_care',
              title: 'Morning skin care',
              startMinute: 420,
              endMinute: 438,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              skincareProducts: ['Cleanser', 'Sunscreen'],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('onboarding-step7-full-timeline')),
      findsOneWidget,
    );
    expect(find.text('Skin Care Routine'), findsOneWidget);
    expect(find.text('Review your weekly routine'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-step7-special-care-notes-button')),
      findsNothing,
    );
    final timelineRect = tester.getRect(
      find.byKey(const ValueKey('onboarding-step7-full-timeline')),
    );
    final stepRect = tester.getRect(find.byType(OnboardingStep7));
    expect(timelineRect.height, greaterThan(stepRect.height * 0.62));
    expect(timelineRect.bottom, closeTo(stepRect.bottom, 2));
    final fileContent = File(
      'lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart',
    ).readAsStringSync();
    expect(fileContent.contains('OnboardingMiniBlockList'), isFalse);
  });

  testWidgets('12. Existing classes/work/eating/fixed blocks are preserved', (
    tester,
  ) async {
    const classBlock = TimelineBlockDraft(
      id: 'class_block',
      section: 'classes',
      title: 'Math',
      startMinute: 540,
      endMinute: 600,
      repeatDays: [1, 3, 5],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const workBlock = TimelineBlockDraft(
      id: 'work_block',
      section: 'job_work_business',
      title: 'Work',
      startMinute: 600,
      endMinute: 720,
      repeatDays: [2, 4],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const eatingBlock = TimelineBlockDraft(
      id: 'eating_block',
      section: 'eating',
      title: 'Breakfast',
      startMinute: 480,
      endMinute: 510,
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.softBlockKey,
    );
    const fixedBlock = TimelineBlockDraft(
      id: BaseTimelineDraft.fixedBathId,
      section: 'fixed',
      title: 'Bath',
      startMinute: 420,
      endMinute: 450,
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const oldSkinBlock = TimelineBlockDraft(
      id: 'old_skin',
      section: 'skin_care',
      title: 'Old skin care',
      startMinute: 600,
      endMinute: 615,
      repeatDays: [1],
      blockType: TimelineBlockDraft.softBlockKey,
    );
    final client = TestSkinCareAiClient(
      routineResult: const SkinCareAiRoutineResult(
        routinePlans: [
          SkinCareRoutinePlan(
            slotLabel: 'morning',
            title: 'Morning Skin Care',
            steps: ['Cleanser', 'Sunscreen'],
            productNames: ['Cleanser', 'Sunscreen'],
          ),
          SkinCareRoutinePlan(
            slotLabel: 'night',
            title: 'Night Skin Care',
            steps: ['Cleanser', 'Moisturizer'],
            productNames: ['Cleanser', 'Moisturizer'],
          ),
        ],
        morningRoutine: [],
        nightRoutine: [],
        weeklyRoutine: [],
        timelineBlocks: [],
      ),
    );

    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(
          blocks: const [
            classBlock,
            workBlock,
            eatingBlock,
            fixedBlock,
            oldSkinBlock,
          ],
        ),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    // With the new UX, the setup card is hidden when a routine exists.
    // We trigger rebuild first to enter edit mode.
    triggerRebuild(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Cleanser, Sunscreen, Moisturizer',
    );
    await tapBuildRoutine(tester);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    final blocks = container
        .read(onboardingStateProvider)
        .draft
        .baseTimeline
        .blocks;
    expect(blocks.where((block) => block.section != 'skin_care').toList(), [
      classBlock,
      workBlock,
      eatingBlock,
      fixedBlock,
    ]);
    expect(blocks.where((block) => block.section == 'skin_care'), hasLength(2));
    expect(
      blocks.where((block) => block.section == 'skin_care').map((b) => b.id),
      isNot(contains('old_skin')),
    );
  });

  testWidgets('13. Selecting 3 routines per day creates 3 skin-care blocks', (
    tester,
  ) async {
    final client = TestSkinCareAiClient(
      routineResult: _routineResultWithPlanCount(3),
    );
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('onboarding-step7-frequency-3')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Cleanser, Sunscreen',
    );
    await tapBuildRoutine(tester);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    final blocks = container
        .read(onboardingStateProvider)
        .draft
        .baseTimeline
        .confirmedBlocksForSection('skin_care');

    expect(client.lastGenerateParams?['desiredApplicationsPerDay'], 3);
    expect(blocks, hasLength(3));
    expect(
      blocks.every(
        (block) =>
            block.endMinute - block.startMinute ==
            onboarding7SkinCareDurationMinutes,
      ),
      isTrue,
    );
  });

  testWidgets(
    '13b. 3/day split night variants schedule exactly 3 blocks per day',
    (tester) async {
      const strongActiveNote =
          'Minimalist PHA Toner is used only on Wednesday and Saturday nights. Do not combine with other strong actives.';
      final client = TestSkinCareAiClient(
        routineResult: const SkinCareAiRoutineResult(
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'morning',
              title: 'Morning Skin Care',
              steps: [
                'Cleanse face',
                'Apply Minimalist Vitamin C',
                'Apply Minimalist SPF 50',
              ],
              productNames: [
                'Beardo Detan Face Wash',
                'Minimalist Vitamin C',
                'Minimalist SPF 50',
              ],
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'midday',
              title: 'Midday Skin Care',
              steps: ['Reapply Minimalist SPF 50'],
              productNames: ['Minimalist SPF 50'],
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Night Skin Care',
              steps: [
                'Cleanse face',
                'Apply Minimalist Alpha Arbutin',
                'Add moisturizer when available',
              ],
              productNames: [
                'Beardo Detan Face Wash',
                'Minimalist Alpha Arbutin',
              ],
              missingItems: [
                SkinCareMissingItem(
                  name: 'Moisturizer',
                  importance: 'important',
                  reason: 'Helps reduce dryness/irritation after serum.',
                ),
              ],
              repeatDays: [1, 2, 4, 5, 7],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Night Skin Care',
              steps: [
                'Cleanse face',
                'Apply Minimalist Alpha Arbutin',
                'Apply Minimalist PHA Toner',
                'Add moisturizer when available',
              ],
              productNames: [
                'Beardo Detan Face Wash',
                'Minimalist Alpha Arbutin',
                'Minimalist PHA Toner',
              ],
              missingItems: [
                SkinCareMissingItem(
                  name: 'Moisturizer',
                  importance: 'important',
                  reason: 'Helps reduce dryness/irritation after serum.',
                ),
              ],
              repeatDays: [3, 6],
            ),
          ],
          morningRoutine: [],
          nightRoutine: [],
          weeklyRoutine: [strongActiveNote],
          timelineBlocks: [],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-frequency-3')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Beardo Detan Face Wash - cleanser\n'
        'Minimalist SPF 50 - sunscreen\n'
        'Minimalist Vitamin C - serum\n'
        'Minimalist Alpha Arbutin - serum\n'
        'Minimalist PHA Toner - exfoliant',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      final blocks = base.confirmedBlocksForSection('skin_care');

      expect(blocks, hasLength(4));
      for (final day in onboarding7EveryDay) {
        expect(onboarding7RoutineCountForDay(blocks, day), 3);
      }
      final activeNight = blocks.singleWhere(
        (block) => block.skincareProducts.contains('Minimalist PHA Toner'),
      );
      expect(activeNight.skincareSlotLabel, 'night');
      expect(activeNight.repeatDays, [3, 6]);
      expect(
        blocks
            .where((block) => block.skincareSlotLabel == 'night')
            .where(
              (block) =>
                  !block.skincareProducts.contains('Minimalist PHA Toner'),
            )
            .single
            .repeatDays,
        [1, 2, 4, 5, 7],
      );
      expect(base.skinCareSpecialCareNotes, contains(strongActiveNote));
      expect(
        base.skinCareSpecialCareNotes.any(
          (note) => note.startsWith('Special care:'),
        ),
        isFalse,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('onboarding-step7-special-care-notes-button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(strongActiveNote), findsOneWidget);
      expect(
        find.textContaining('AI returned no usable routine'),
        findsNothing,
      );
    },
  );

  testWidgets(
    '13c. 3/day removed morning PHA note does not create extra night block',
    (tester) async {
      const removedMorningNote =
          'Minimalist PHA Toner was removed from the daily morning routine and moved to special-care notes. Add it manually on two nights only after review.';
      final client = TestSkinCareAiClient(
        routineResult: const SkinCareAiRoutineResult(
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'morning',
              title: 'Morning Skin Care',
              steps: [
                'Cleanse face',
                'Apply Minimalist Vitamin C',
                'Apply Minimalist SPF 50',
              ],
              productNames: [
                'Beardo Detan Face Wash',
                'Minimalist Vitamin C',
                'Minimalist SPF 50',
              ],
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'midday',
              title: 'Midday Skin Care',
              steps: ['Reapply Minimalist SPF 50'],
              productNames: ['Minimalist SPF 50'],
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Night Skin Care',
              steps: ['Cleanse face', 'Apply Minimalist Alpha Arbutin'],
              productNames: [
                'Beardo Detan Face Wash',
                'Minimalist Alpha Arbutin',
              ],
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
            ),
          ],
          morningRoutine: [],
          nightRoutine: [],
          weeklyRoutine: [removedMorningNote],
          timelineBlocks: [],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-frequency-3')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Beardo Detan Face Wash - cleanser\n'
        'Minimalist SPF 50 - sunscreen\n'
        'Minimalist Vitamin C - serum\n'
        'Minimalist Alpha Arbutin - serum\n'
        'Minimalist PHA Toner - exfoliant',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      final blocks = base.confirmedBlocksForSection('skin_care');

      expect(blocks, hasLength(3));
      for (final day in onboarding7EveryDay) {
        expect(onboarding7RoutineCountForDay(blocks, day), 3);
      }
      expect(
        blocks.expand((block) => block.skincareProducts),
        isNot(contains('Minimalist PHA Toner')),
      );
      expect(
        blocks.where((block) => block.skincareSlotLabel == 'night'),
        hasLength(1),
      );
      expect(base.skinCareSpecialCareNotes, contains(removedMorningNote));

      await tester.tap(
        find.byKey(
          const ValueKey('onboarding-step7-special-care-notes-button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(removedMorningNote), findsOneWidget);
      expect(
        find.textContaining('AI returned no usable routine'),
        findsNothing,
      );
    },
  );

  testWidgets(
    '13d. Rinse-off acid cleanser remains visible in generated blocks',
    (tester) async {
      const cleanser = 'Beardo De-Tan Face Wash Coffee Detox';
      final client = TestSkinCareAiClient(
        routineResult: const SkinCareAiRoutineResult(
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'morning',
              title: 'Morning Skin Care',
              steps: [
                'Cleanse with Beardo De-Tan Face Wash Coffee Detox glycolic lactic acid',
                'Apply Minimalist SPF 50',
              ],
              productNames: [cleanser, 'Minimalist SPF 50'],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Night Skin Care',
              steps: ['Cleanse with Beardo De-Tan Face Wash Coffee Detox'],
              productNames: [cleanser],
            ),
          ],
          morningRoutine: [],
          nightRoutine: [],
          weeklyRoutine: [],
          timelineBlocks: [],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        '$cleanser - cleanser\nMinimalist SPF 50 - sunscreen',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');

      expect(blocks, hasLength(2));
      expect(
        blocks.expand((block) => block.skincareProducts),
        contains(cleanser),
      );
      expect(
        find.textContaining('AI returned no usable routine'),
        findsNothing,
      );
    },
  );

  testWidgets('14. Selecting 3 routines per day creates 3 skin-care blocks', (
    tester,
  ) async {
    final client = TestSkinCareAiClient(
      routineResult: _routineResultWithPlanCount(3),
    );
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('onboarding-step7-frequency-3')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Cleanser, Sunscreen',
    );
    await tapBuildRoutine(tester);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    final blocks = container
        .read(onboardingStateProvider)
        .draft
        .baseTimeline
        .confirmedBlocksForSection('skin_care');

    expect(client.lastGenerateParams?['desiredApplicationsPerDay'], 3);
    expect(blocks, hasLength(3));
    expect(
      blocks.every(
        (block) =>
            block.endMinute - block.startMinute ==
            onboarding7SkinCareDurationMinutes,
      ),
      isTrue,
    );
  });

  test(
    'Legacy persisted skinCareDesiredApplicationsPerDay 4 deserializes and migrates to 3',
    () {
      final json = {
        'skinCareDesiredApplicationsPerDay': 4,
        'skinCareSetupPath': 'has_products',
        'skinCareSetupStep': 1,
        'skinCareStageContractVersion':
            BaseTimelineDraft.currentSkinCareStageContractVersion,
        'blocks': <Map<String, dynamic>>[],
      };
      final base = BaseTimelineDraft.fromMap(json);
      expect(base.skinCareDesiredApplicationsPerDay, 3);
    },
  );

  test(
    '15. Scheduler anchors routines after bath, after lunch, and before sleep',
    () {
      final occupied = [
        const TimelineBlockDraft(
          id: BaseTimelineDraft.fixedSleepId,
          section: 'fixed',
          title: 'Sleep',
          startMinute: 1380,
          endMinute: 420,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
          crossesMidnight: true,
        ),
        const TimelineBlockDraft(
          id: 'bath',
          section: 'fixed',
          title: 'Shower',
          startMinute: 420,
          endMinute: 450,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
        const TimelineBlockDraft(
          id: 'class',
          section: 'classes',
          title: 'Class',
          startMinute: 455,
          endMinute: 500,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
        const TimelineBlockDraft(
          id: 'lunch',
          section: 'eating',
          title: 'Lunch',
          startMinute: 780,
          endMinute: 810,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
        ),
        const TimelineBlockDraft(
          id: 'fixed-night',
          section: 'fixed',
          title: 'Family call',
          startMinute: 1260,
          endMinute: 1290,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
        const TimelineBlockDraft(
          id: 'old-skin',
          section: 'skin_care',
          title: 'Old skin care',
          startMinute: 455,
          endMinute: 470,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
        ),
      ];
      final result = onboarding7ScheduleSkinCareRoutine(
        baseTimeline: BaseTimelineDraft(blocks: occupied),
        routinePlans: _skinCarePlansForCount(3),
        desiredApplicationsPerDay: 3,
        ownedProductNames: const ['Cleanser', 'Sunscreen'],
        now: DateTime.utc(2026, 6, 15),
      );

      expect(result.errorMessage, isNull);
      expect(result.blocks, hasLength(3));
      expect(
        result.blocks
            .singleWhere((block) => block.skincareSlotLabel == 'morning')
            .startMinute,
        500,
      );
      expect(
        result.blocks
            .singleWhere((block) => block.skincareSlotLabel == 'midday')
            .startMinute,
        810,
      );
      expect(
        result.blocks
            .singleWhere((block) => block.skincareSlotLabel == 'night')
            .startMinute,
        1365,
      );
      for (final skinBlock in result.blocks) {
        expect(
          skinBlock.endMinute - skinBlock.startMinute,
          onboarding7SkinCareDurationMinutes,
        );
        for (final occupiedBlock in occupied.where(
          (block) => block.section != 'skin_care',
        )) {
          expect(_blocksOverlap(skinBlock, occupiedBlock), isFalse);
        }
      }

      final ordered = result.blocks.toList()
        ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
      for (var index = 1; index < ordered.length; index += 1) {
        expect(
          ordered[index].startMinute - ordered[index - 1].endMinute,
          greaterThanOrEqualTo(onboarding7SkinCareMinimumGapMinutes),
        );
      }
    },
  );

  test('15b. After-bath routine uses the next real morning free time', () {
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(
        blocks: [
          BaseTimelineDraft.defaultSleepBlock(),
          BaseTimelineDraft.defaultBathBlock(),
          const TimelineBlockDraft(
            id: 'lunch',
            section: 'eating',
            title: 'Lunch',
            startMinute: 780,
            endMinute: 815,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.softBlockKey,
            mealCategory: 'Lunch',
          ),
          const TimelineBlockDraft(
            id: 'busy-morning',
            section: 'classes',
            title: 'Classes',
            startMinute: 455,
            endMinute: 750,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      ),
      routinePlans: _skinCarePlansForCount(2),
      desiredApplicationsPerDay: 2,
      ownedProductNames: const ['Cleanser', 'Sunscreen'],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.errorMessage, isNull);
    final afterBath = result.blocks.singleWhere(
      (block) => block.skincareSlotLabel == 'morning',
    );
    expect(afterBath.startMinute, 750);
    expect(afterBath.title, 'After-bath Skin Care');
  });

  test('15c. A late bath still produces all three anchored routines', () {
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(
        blocks: [
          BaseTimelineDraft.defaultSleepBlock(),
          const TimelineBlockDraft(
            id: BaseTimelineDraft.fixedBathId,
            section: 'fixed',
            title: 'Bath',
            startMinute: 16 * 60 + 45,
            endMinute: 17 * 60,
            repeatDays: onboarding7EveryDay,
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      ),
      routinePlans: _skinCarePlansForCount(3),
      desiredApplicationsPerDay: 3,
      ownedProductNames: const ['Cleanser', 'Sunscreen'],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.errorMessage, isNull);
    expect(result.blocks, hasLength(3));
    final afterWake = result.blocks.singleWhere(
      (block) => block.skincareSlotLabel == 'morning',
    );
    final night = result.blocks.singleWhere(
      (block) => block.skincareSlotLabel == 'night',
    );
    expect(afterWake.startMinute, 7 * 60);
    expect(afterWake.title, 'After-wake Skin Care');
    expect(night.startMinute, 23 * 60 + 15);
    expect(night.title, 'Before-bed Skin Care');
  });

  test('15c1. Two and three routines preserve wake and bed anchors', () {
    for (final desired in const [2, 3]) {
      final result = onboarding7ScheduleSkinCareRoutine(
        baseTimeline: BaseTimelineDraft(
          blocks: [
            BaseTimelineDraft.defaultSleepBlock(),
            BaseTimelineDraft.defaultBathBlock(),
          ],
        ),
        routinePlans: _skinCarePlansForCount(desired),
        desiredApplicationsPerDay: desired,
        ownedProductNames: const ['Cleanser', 'Sunscreen'],
        now: DateTime.utc(2026, 6, 15),
      );

      expect(result.errorMessage, isNull, reason: '$desired routines/day');
      expect(result.blocks, hasLength(desired));
      final morning = result.blocks.singleWhere(
        (block) => block.skincareSlotLabel == 'morning',
      );
      final night = result.blocks.singleWhere(
        (block) => block.skincareSlotLabel == 'night',
      );
      expect(morning.startMinute, 7 * 60 + 30);
      expect(morning.title, 'After-bath Skin Care');
      expect(night.startMinute, 23 * 60 + 15);
      expect(night.endMinute, 23 * 60 + 30);
      expect(night.title, 'Before-bed Skin Care');
    }
  });

  test('15c2. Midnight sleep keeps the full waking day and exact bedtime', () {
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: const BaseTimelineDraft(
        blocks: [
          TimelineBlockDraft(
            id: BaseTimelineDraft.fixedSleepId,
            section: 'fixed',
            title: 'Sleep',
            startMinute: 0,
            endMinute: 7 * 60,
            repeatDays: onboarding7EveryDay,
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: BaseTimelineDraft.fixedBathId,
            section: 'fixed',
            title: 'Bath',
            startMinute: 7 * 60,
            endMinute: 7 * 60 + 15,
            repeatDays: onboarding7EveryDay,
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      ),
      routinePlans: _skinCarePlansForCount(2),
      desiredApplicationsPerDay: 2,
      ownedProductNames: const ['Cleanser', 'Sunscreen'],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.errorMessage, isNull);
    expect(
      result.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'morning')
          .startMinute,
      7 * 60 + 15,
    );
    final night = result.blocks.singleWhere(
      (block) => block.skincareSlotLabel == 'night',
    );
    expect(night.startMinute, 23 * 60 + 45);
    expect(night.endMinute, 24 * 60);
  });

  test('15c3. After-lunch routine is scheduled before the next rest', () {
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(
        blocks: [
          BaseTimelineDraft.defaultSleepBlock(),
          BaseTimelineDraft.defaultBathBlock(),
          const TimelineBlockDraft(
            id: 'lunch',
            section: 'eating',
            title: 'Lunch',
            startMinute: 13 * 60,
            endMinute: 13 * 60 + 30,
            repeatDays: onboarding7EveryDay,
            blockType: TimelineBlockDraft.softBlockKey,
            mealCategory: 'Lunch',
          ),
          const TimelineBlockDraft(
            id: 'after-lunch-class',
            section: 'classes',
            title: 'Class',
            startMinute: 13 * 60 + 30,
            endMinute: 14 * 60 + 10,
            repeatDays: onboarding7EveryDay,
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          const TimelineBlockDraft(
            id: 'rest',
            section: 'fixed',
            title: 'Rest',
            startMinute: 14 * 60 + 30,
            endMinute: 15 * 60,
            repeatDays: onboarding7EveryDay,
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      ),
      routinePlans: _skinCarePlansForCount(3),
      desiredApplicationsPerDay: 3,
      ownedProductNames: const ['Cleanser', 'Sunscreen'],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.errorMessage, isNull);
    final afterLunch = result.blocks.singleWhere(
      (block) => block.skincareSlotLabel == 'midday',
    );
    expect(afterLunch.startMinute, 14 * 60 + 10);
    expect(afterLunch.endMinute, lessThanOrEqualTo(14 * 60 + 30));
    expect(afterLunch.title, 'After-lunch Skin Care');
  });

  test('15d. A fully occupied waking day returns an actionable error', () {
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(
        blocks: [
          BaseTimelineDraft.defaultSleepBlock(),
          BaseTimelineDraft.defaultBathBlock(),
          const TimelineBlockDraft(
            id: 'busy-day',
            section: 'classes',
            title: 'Classes',
            startMinute: 7 * 60 + 35,
            endMinute: 23 * 60 + 30,
            repeatDays: onboarding7EveryDay,
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      ),
      routinePlans: _skinCarePlansForCount(2),
      desiredApplicationsPerDay: 2,
      ownedProductNames: const ['Cleanser', 'Sunscreen'],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.blocks, isEmpty);
    expect(result.errorMessage, onboarding7NoCompleteScheduleMessage);
  });

  test('15e. Midday routine uses the first free time after lunch', () {
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(
        blocks: [
          BaseTimelineDraft.defaultSleepBlock(),
          BaseTimelineDraft.defaultBathBlock(),
          const TimelineBlockDraft(
            id: 'lunch',
            section: 'eating',
            title: 'Lunch',
            startMinute: 780,
            endMinute: 810,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.softBlockKey,
            mealCategory: 'Lunch',
          ),
          const TimelineBlockDraft(
            id: 'after-lunch-class',
            section: 'classes',
            title: 'Class',
            startMinute: 810,
            endMinute: 900,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      ),
      routinePlans: _skinCarePlansForCount(3),
      desiredApplicationsPerDay: 3,
      ownedProductNames: const ['Cleanser', 'Sunscreen'],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.errorMessage, isNull);
    expect(
      result.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'midday')
          .startMinute,
      900,
    );
  });

  test(
    '15f. Fully occupied after-bath time does not create overlapping blocks',
    () {
      final result = onboarding7ScheduleSkinCareRoutine(
        baseTimeline: BaseTimelineDraft(
          blocks: [
            BaseTimelineDraft.defaultSleepBlock(),
            BaseTimelineDraft.defaultBathBlock(),
            const TimelineBlockDraft(
              id: 'busy-after-bath',
              section: 'classes',
              title: 'Classes',
              startMinute: 455,
              endMinute: 1410,
              repeatDays: onboarding7EveryDay,
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        ),
        routinePlans: _skinCarePlansForCount(2),
        desiredApplicationsPerDay: 2,
        ownedProductNames: const ['Cleanser', 'Sunscreen'],
        now: DateTime.utc(2026, 6, 15),
      );

      expect(result.blocks, isEmpty);
      expect(result.errorMessage, onboarding7NoCompleteScheduleMessage);
    },
  );

  test('15g. Four routines use later free time after a busy lunch period', () {
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(
        blocks: [
          BaseTimelineDraft.defaultSleepBlock(),
          BaseTimelineDraft.defaultBathBlock(),
          const TimelineBlockDraft(
            id: 'lunch',
            section: 'eating',
            title: 'Lunch',
            startMinute: 780,
            endMinute: 810,
            repeatDays: onboarding7EveryDay,
            blockType: TimelineBlockDraft.softBlockKey,
            mealCategory: 'Lunch',
          ),
          const TimelineBlockDraft(
            id: 'busy-after-lunch',
            section: 'classes',
            title: 'Classes',
            startMinute: 810,
            endMinute: 17 * 60,
            repeatDays: onboarding7EveryDay,
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      ),
      routinePlans: _skinCarePlansForCount(3),
      desiredApplicationsPerDay: 3,
      ownedProductNames: const ['Cleanser', 'Sunscreen'],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.errorMessage, isNull);
    expect(result.blocks, hasLength(3));
    final midday = result.blocks.singleWhere(
      (block) => block.skincareSlotLabel == 'midday',
    );
    expect(midday.startMinute, 17 * 60);
  });

  test('15h. Dense timetable uses every real free slot without failing', () {
    final occupied = [
      BaseTimelineDraft.defaultSleepBlock(),
      BaseTimelineDraft.defaultBathBlock(),
      const TimelineBlockDraft(
        id: 'busy-morning',
        section: 'classes',
        title: 'Morning classes',
        startMinute: 470,
        endMinute: 780,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      const TimelineBlockDraft(
        id: 'lunch',
        section: 'eating',
        title: 'Lunch',
        startMinute: 780,
        endMinute: 795,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.softBlockKey,
        mealCategory: 'Lunch',
      ),
      const TimelineBlockDraft(
        id: 'busy-midday',
        section: 'classes',
        title: 'Midday class',
        startMinute: 810,
        endMinute: 825,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      const TimelineBlockDraft(
        id: 'busy-afternoon',
        section: 'classes',
        title: 'Afternoon classes',
        startMinute: 840,
        endMinute: 1395,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ];
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(blocks: occupied),
      routinePlans: _skinCarePlansForCount(3),
      desiredApplicationsPerDay: 3,
      ownedProductNames: const ['Cleanser', 'Sunscreen'],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.errorMessage, isNull);
    expect(result.blocks, hasLength(3));
  });

  test('15i. After-lunch routine never falls back to before lunch', () {
    final occupied = [
      BaseTimelineDraft.defaultSleepBlock(),
      BaseTimelineDraft.defaultBathBlock(),
      const TimelineBlockDraft(
        id: 'morning-classes',
        section: 'classes',
        title: 'Morning classes',
        startMinute: 470,
        endMinute: 720,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      const TimelineBlockDraft(
        id: 'pre-lunch-class',
        section: 'classes',
        title: 'Pre-lunch class',
        startMinute: 735,
        endMinute: 780,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      const TimelineBlockDraft(
        id: 'lunch',
        section: 'eating',
        title: 'Lunch',
        startMinute: 780,
        endMinute: 795,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.softBlockKey,
        mealCategory: 'Lunch',
      ),
      const TimelineBlockDraft(
        id: 'afternoon-evening-classes',
        section: 'classes',
        title: 'Afternoon and evening classes',
        startMinute: 795,
        endMinute: 1395,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ];
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(blocks: occupied),
      routinePlans: _skinCarePlansForCount(3),
      desiredApplicationsPerDay: 3,
      ownedProductNames: const ['Cleanser', 'Sunscreen'],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.blocks, isEmpty);
    expect(result.errorMessage, onboarding7NoCompleteScheduleMessage);
  });

  test('15j. Broad soft meal windows do not consume real free time', () {
    final occupied = [
      const TimelineBlockDraft(
        id: BaseTimelineDraft.fixedSleepId,
        section: 'fixed',
        title: 'Sleep',
        startMinute: 22 * 60 + 30,
        endMinute: 7 * 60,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
        crossesMidnight: true,
      ),
      const TimelineBlockDraft(
        id: BaseTimelineDraft.fixedBathId,
        section: 'fixed',
        title: 'Bath',
        startMinute: 7 * 60,
        endMinute: 7 * 60 + 30,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      const TimelineBlockDraft(
        id: 'eating-ai-monday_breakfast-test',
        section: 'eating',
        title: 'Breakfast',
        startMinute: 7 * 60,
        endMinute: 10 * 60,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
        mealCategory: 'Breakfast',
      ),
      const TimelineBlockDraft(
        id: 'eating-ai-monday_lunch-test',
        section: 'eating',
        title: 'Lunch',
        startMinute: 13 * 60,
        endMinute: 15 * 60,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
        mealCategory: 'Lunch',
      ),
      const TimelineBlockDraft(
        id: 'eating-ai-monday_dinner-test',
        section: 'eating',
        title: 'Dinner',
        startMinute: 20 * 60,
        endMinute: 22 * 60,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
        mealCategory: 'Dinner',
      ),
      const TimelineBlockDraft(
        id: 'commute',
        section: 'work',
        title: 'Commute',
        startMinute: 8 * 60,
        endMinute: 9 * 60,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      const TimelineBlockDraft(
        id: 'daytime-work',
        section: 'work',
        title: 'Office or classes',
        startMinute: 9 * 60,
        endMinute: 17 * 60,
        repeatDays: onboarding7EveryDay,
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ];
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(blocks: occupied),
      routinePlans: _skinCarePlansForCount(3),
      desiredApplicationsPerDay: 3,
      ownedProductNames: const ['Cleanser', 'Sunscreen'],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.errorMessage, isNull);
    expect(
      {
        for (final block in result.blocks)
          block.skincareSlotLabel: block.startMinute,
      },
      {'morning': 7 * 60 + 30, 'midday': 17 * 60, 'night': 22 * 60 + 15},
    );
    for (final skinBlock in result.blocks) {
      for (final hardBlock in occupied.where(
        (block) =>
            block.blockType == TimelineBlockDraft.hardBlockKey &&
            block.section != 'eating',
      )) {
        expect(_blocksOverlap(skinBlock, hardBlock), isFalse);
      }
    }
  });

  test('15k. Edit conflict checks ignore only soft eating windows', () {
    const candidate = TimelineBlockDraft(
      id: 'skin-candidate',
      section: 'skin_care',
      title: 'After-bath Skin Care',
      startMinute: 7 * 60 + 30,
      endMinute: 7 * 60 + 45,
      repeatDays: onboarding7EveryDay,
      blockType: TimelineBlockDraft.softBlockKey,
    );
    const softMeal = TimelineBlockDraft(
      id: 'breakfast-window',
      section: 'eating',
      title: 'Breakfast',
      startMinute: 7 * 60,
      endMinute: 10 * 60,
      repeatDays: onboarding7EveryDay,
      blockType: TimelineBlockDraft.softBlockKey,
    );
    const hardMeal = TimelineBlockDraft(
      id: 'fixed-breakfast',
      section: 'eating',
      title: 'Fixed breakfast',
      startMinute: 7 * 60 + 30,
      endMinute: 8 * 60,
      repeatDays: onboarding7EveryDay,
      blockType: TimelineBlockDraft.hardBlockKey,
    );
    const aiMealWindow = TimelineBlockDraft(
      id: 'eating-ai-monday_breakfast-test',
      section: 'eating',
      title: 'AI breakfast window',
      startMinute: 7 * 60,
      endMinute: 10 * 60,
      repeatDays: onboarding7EveryDay,
      blockType: TimelineBlockDraft.hardBlockKey,
    );

    expect(
      onboarding7SkinCareCandidateConflicts(
        baseTimeline: const BaseTimelineDraft(blocks: [softMeal]),
        candidate: candidate,
      ),
      isFalse,
    );
    expect(
      onboarding7SkinCareCandidateConflicts(
        baseTimeline: const BaseTimelineDraft(blocks: [aiMealWindow]),
        candidate: candidate,
      ),
      isFalse,
    );
    expect(
      onboarding7SkinCareCandidateConflicts(
        baseTimeline: const BaseTimelineDraft(blocks: [hardMeal]),
        candidate: candidate,
      ),
      isTrue,
    );
  });

  testWidgets('16. Timeline shows all ordered steps, stretches, and has edit', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(
          blocks: const [
            TimelineBlockDraft(
              id: 'skin-long',
              section: 'skin_care',
              title: 'Morning Skin Care',
              startMinute: 455,
              endMinute: 470,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              skincareProducts: ['Cleanser', 'Vitamin C Serum', 'Sunscreen'],
              skincareSteps: [
                'Face wash',
                'Vitamin C',
                'Moisturizer',
                'Sunscreen',
              ],
              skincareMissingItems: ['Moisturizer (important, missing)'],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1. Face wash'), findsOneWidget);
    expect(find.text('2. Vitamin C'), findsOneWidget);
    expect(find.text('3. Moisturizer'), findsOneWidget);
    expect(find.text('4. Sunscreen'), findsOneWidget);
    expect(find.text('Moisturizer (important, missing)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-step7-missing-item-skin-long-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding-step7-edit-skin-long')),
      findsOneWidget,
    );

    final blockRect = tester.getRect(
      find.byKey(const ValueKey('onboarding-step7-block-skin-long')),
    );
    expect(blockRect.height, greaterThan(70));
  });

  testWidgets('17. Editing a skin-care time validates conflicts', (
    tester,
  ) async {
    const skinBlock = TimelineBlockDraft(
      id: 'skin-edit',
      section: 'skin_care',
      title: 'Morning Skin Care',
      startMinute: 455,
      endMinute: 470,
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.softBlockKey,
      skincareSteps: ['Face wash', 'Sunscreen'],
    );
    const eatingBlock = TimelineBlockDraft(
      id: 'fixed-breakfast',
      section: 'eating',
      title: 'Breakfast',
      startMinute: 480,
      endMinute: 510,
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.hardBlockKey,
    );

    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(blocks: const [eatingBlock, skinBlock]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('onboarding-step7-edit-skin-edit')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('onboarding-step7-find-free-time-button')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-edit-start-time-field')),
      '8:05 AM',
    );
    await tester.tap(
      find.byKey(const ValueKey('onboarding-step7-edit-save-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'That time overlaps another onboarding block. Choose a free 15-minute slot.',
      ),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    final updated = container
        .read(onboardingStateProvider)
        .draft
        .baseTimeline
        .blocks
        .singleWhere((block) => block.id == 'skin-edit');
    expect(updated.startMinute, 455);
    expect(updated.endMinute, 470);
  });

  testWidgets(
    '17b. Skin-care edit sheet survives save, cancel, system back, and repeated teardown',
    (tester) async {
      useAndroidWidth(tester);
      const skinBlock = TimelineBlockDraft(
        id: 'skin-runtime-edit',
        section: 'skin_care',
        title: 'Morning Skin Care',
        startMinute: 455,
        endMinute: 470,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: ['Cleanser', 'Sunscreen'],
        skincareSteps: ['Cleanse', 'Apply sunscreen'],
      );

      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            productNames: 'Cleanser\nSunscreen\nVery Long Sunscreen',
            blocks: const [skinBlock],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );

      Future<void> openEditor() async {
        await tester.tap(
          find.byKey(const ValueKey('onboarding-step7-edit-skin-runtime-edit')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('onboarding-step7-edit-title-field')),
          findsOneWidget,
        );
      }

      void expectNoModalException() {
        final exception = tester.takeException();
        expect(exception, isNull);
      }

      await openEditor();
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-edit-title-field')),
        'Updated Morning Skin Care',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-edit-start-time-field')),
        '7:45 AM',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-edit-products-field')),
        'Cleanser\nVery Long Sunscreen',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-edit-steps-field')),
        'Cleanse\nApply sunscreen generously',
      );
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-edit-save-button')),
      );
      await tester.pumpAndSettle();
      expectNoModalException();

      var updated = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .blocks
          .singleWhere((block) => block.id == 'skin-runtime-edit');
      expect(updated.title, 'Updated Morning Skin Care');
      expect(updated.startMinute, 465);
      expect(updated.skincareProducts, ['Cleanser', 'Very Long Sunscreen']);
      expect(updated.skincareSteps, ['Cleanse', 'Apply sunscreen generously']);

      await openEditor();
      await tester.tap(find.byKey(const Key('timeline-edit-cancel-button')));
      await tester.pumpAndSettle();
      expectNoModalException();

      await openEditor();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectNoModalException();

      for (var i = 0; i < 5; i += 1) {
        await openEditor();
        if (i.isEven) {
          await tester.tap(
            find.byKey(const ValueKey('onboarding-step7-edit-save-button')),
          );
        } else {
          await tester.tap(
            find.byKey(const Key('timeline-edit-cancel-button')),
          );
        }
        await tester.pumpAndSettle();
        expectNoModalException();
      }

      await openEditor();
      expect(find.text('Updated Morning Skin Care'), findsWidgets);
      expect(find.text('7:45 AM'), findsOneWidget);
      expect(find.textContaining('Very Long Sunscreen'), findsWidgets);
      expect(find.textContaining('Apply sunscreen generously'), findsWidgets);
      await tester.tap(find.byKey(const Key('timeline-edit-cancel-button')));
      await tester.pumpAndSettle();
      expectNoModalException();
    },
  );

  testWidgets(
    '18. AI returns 2 plans, selecting 3 without unsafe warning shows fewer-routines error',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: _routineResultWithPlanCount(2),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-frequency-3')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser, Sunscreen SPF 50',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');

      expect(blocks, isEmpty);
      expect(
        find.text(
          'AI returned fewer routines than requested. Try again or choose fewer times per day.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '19. Frequency selector supports 2 and 3 times/day only, 4/day does not exist',
    (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onboarding-step7-frequency-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step7-frequency-3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step7-frequency-4')),
        findsNothing,
      );
    },
  );

  testWidgets(
    '19b. AI returns fewer plans for 3/day shows fewer-routines error and creates zero blocks',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: SkinCareAiRoutineResult(
          routinePlans: _skinCarePlansForCount(2),
          morningRoutine: const [],
          nightRoutine: const [],
          weeklyRoutine: const [],
          timelineBlocks: const [],
          warnings: const ['ai_returned_fewer_routines'],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-frequency-3')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser, Sunscreen',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      final blocks = base.confirmedBlocksForSection('skin_care');

      expect(blocks, hasLength(0));
      expect(base.skinCareDesiredApplicationsPerDay, 3);
      expect(
        find.text(
          'AI returned fewer routines than requested. Try again or choose fewer times per day.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('AI returned no usable routine'),
        findsNothing,
      );
    },
  );

  testWidgets(
    '19c. Missing midday worker warning shows specific 3/day error and creates zero blocks',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: SkinCareAiRoutineResult(
          routinePlans: _skinCarePlansForCount(2),
          morningRoutine: const [],
          nightRoutine: const [],
          weeklyRoutine: const [],
          timelineBlocks: const [],
          warnings: const [
            'ai_missing_required_slot:midday',
            'ai_wrong_daily_slot_count',
            'ai_returned_fewer_routines',
          ],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-frequency-3')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser\nSunscreen',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');

      expect(blocks, isEmpty);
      expect(
        find.text(
          'AI returned no midday routine for 3/day. Try again or choose 2 times/day.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '19d. Obsolete afternoon slot warning does not show 4/day error and falls back safely',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: SkinCareAiRoutineResult(
          routinePlans: _skinCarePlansForCount(2),
          morningRoutine: const [],
          nightRoutine: const [],
          weeklyRoutine: const [],
          timelineBlocks: const [],
          warnings: const [
            'ai_missing_required_slot:afternoon',
            'ai_returned_fewer_routines',
          ],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-frequency-3')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser\nSunscreen',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');

      expect(blocks, isEmpty);
      expect(
        find.text(
          'AI returned no afternoon routine for 4/day. Try again or choose 3 times/day.',
        ),
        findsNothing,
      );
      expect(
        find.text(
          'AI returned fewer routines than requested. Try again or choose fewer times per day.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '19e. Extra daily slot warning shows too-many-routines error and creates zero blocks',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: SkinCareAiRoutineResult(
          routinePlans: _skinCarePlansForCount(4),
          morningRoutine: const [],
          nightRoutine: const [],
          weeklyRoutine: const [],
          timelineBlocks: const [],
          warnings: const [
            'ai_extra_daily_slot_count',
            'ai_wrong_daily_slot_count',
          ],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-frequency-3')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser\nSunscreen',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');

      expect(blocks, isEmpty);
      expect(
        find.text('AI returned too many routines for some days. Try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '20. Photo source sends only photo products for 3 AI-returned routines',
    (tester) async {
      final asset = _uploadedAsset();
      final client = TestSkinCareAiClient(
        productResult: const SkinCareAiProductResult(
          products: [
            {
              'name': 'UV Aqua Gel',
              'category': 'sunscreen',
              'possibleActives': ['UV filters'],
            },
            {'name': 'Photo Cleanser', 'category': 'cleanser'},
          ],
        ),
        routineResult: const SkinCareAiRoutineResult(
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'morning',
              title: 'Morning SPF',
              steps: ['Apply sunscreen'],
              productNames: ['sunscreen'],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'midday',
              title: 'Midday SPF',
              steps: ['Reapply sunscreen'],
              productNames: ['sunscreen'],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Night Cleanse',
              steps: ['Cleanse'],
              productNames: ['cleanser'],
            ),
          ],
          morningRoutine: [],
          nightRoutine: [],
          weeklyRoutine: [],
          timelineBlocks: [],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            uid: 'uid-1',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
          uploadController: TestUploadController(result: asset),
        ),
      );
      await tester.pumpAndSettle();

      await chooseSkinPhotoFromGallery(tester);
      final freq3 = find.byKey(const ValueKey('onboarding-step7-frequency-3'));
      await tester.ensureVisible(freq3);
      await tester.tap(freq3);
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');
      final midday = blocks.singleWhere(
        (block) => block.skincareSlotLabel == 'midday',
      );
      final reviewedProducts =
          client.lastGenerateParams?['typedProductDetails'] as List<dynamic>;

      expect(blocks, hasLength(3));
      expect(midday.skincareProducts, contains('UV Aqua Gel'));
      expect(midday.skincareSteps, contains('Reapply sunscreen'));
      expect(client.lastGenerateParams?['productInputSource'], 'typed');
      expect(client.lastGenerateParams?['productsFromPhoto'], isNull);
      expect(client.lastGenerateParams?['typedProductNames'], isNull);
      expect(reviewedProducts, hasLength(2));
      expect(reviewedProducts.first['category'], 'sunscreen');
      expect(reviewedProducts.first['possibleActives'], ['UV filters']);
    },
  );

  testWidgets(
    '21. Photo source sends only photo products for 3 AI-returned routines',
    (tester) async {
      final asset = _uploadedAsset();
      final client = TestSkinCareAiClient(
        productResult: const SkinCareAiProductResult(
          products: [
            {
              'name': 'UV Aqua Gel',
              'category': 'sunscreen',
              'possibleActives': ['UV filters'],
            },
            {'name': 'Gentle Cleanser', 'category': 'cleanser'},
          ],
        ),
        routineResult: const SkinCareAiRoutineResult(
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'morning',
              title: 'Morning SPF',
              steps: ['Apply sunscreen'],
              productNames: ['sunscreen'],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'midday',
              title: 'Midday SPF',
              steps: ['Reapply sunscreen'],
              productNames: ['sunscreen'],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Night Cleanse',
              steps: ['Cleanse'],
              productNames: ['cleanser'],
            ),
          ],
          morningRoutine: [],
          nightRoutine: [],
          weeklyRoutine: [],
          timelineBlocks: [],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            uid: 'uid-1',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
          uploadController: TestUploadController(result: asset),
        ),
      );
      await tester.pumpAndSettle();

      await chooseSkinPhotoFromGallery(tester);
      final freq3 = find.byKey(const ValueKey('onboarding-step7-frequency-3'));
      await tester.ensureVisible(freq3);
      await tester.tap(freq3);
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');

      expect(blocks, hasLength(3));
      expect(
        blocks
            .singleWhere((block) => block.skincareSlotLabel == 'midday')
            .skincareProducts,
        contains('UV Aqua Gel'),
      );
      expect(client.lastGenerateParams?['productInputSource'], 'typed');
      expect(client.lastGenerateParams?['typedProductDetails'], hasLength(2));
      expect(client.lastGenerateParams?['productsFromPhoto'], isNull);
    },
  );

  testWidgets(
    '22. Photo metadata with only sunscreen does not synthesize missing routines',
    (tester) async {
      final asset = _uploadedAsset();
      final client = TestSkinCareAiClient(
        productResult: const SkinCareAiProductResult(
          products: [
            {
              'category': 'sunscreen',
              'possibleActives': ['UV filters'],
            },
          ],
        ),
        routineResult: const SkinCareAiRoutineResult(
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'morning',
              title: 'Morning SPF',
              steps: ['Apply sunscreen'],
              productNames: ['Sunscreen'],
            ),
          ],
          morningRoutine: [],
          nightRoutine: [],
          weeklyRoutine: [],
          timelineBlocks: [],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            uid: 'uid-1',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
          uploadController: TestUploadController(result: asset),
        ),
      );
      await tester.pumpAndSettle();

      await chooseSkinPhotoFromGallery(tester);
      final freq3 = find.byKey(const ValueKey('onboarding-step7-frequency-3'));
      await tester.ensureVisible(freq3);
      await tester.tap(freq3);
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');

      expect(blocks, isEmpty);
      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      expect(base.skinCareSpecialCareNotes, isEmpty);
      expect(
        find.text(
          'AI returned fewer routines than requested. Try again or choose fewer times per day.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Suggested:'), findsNothing);
      expect(
        (client.lastGenerateParams?['typedProductDetails'] as List).single,
        containsPair('possibleActives', ['UV filters']),
      );
    },
  );

  test(
    '23. AI repeatDays Monday-only are forced to full daily routine in mode 1',
    () {
      const bath = TimelineBlockDraft(
        id: BaseTimelineDraft.fixedBathId,
        section: 'fixed',
        title: 'Bath',
        startMinute: 420,
        endMinute: 450,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
      );
      final mondayOnlyPlans = _skinCarePlansForCount(3)
          .map(
            (plan) => SkinCareRoutinePlan(
              slotLabel: plan.slotLabel,
              title: plan.title,
              steps: plan.steps,
              productNames: plan.productNames,
              repeatDays: const [1],
            ),
          )
          .toList();

      final result = onboarding7ScheduleSkinCareRoutine(
        baseTimeline: const BaseTimelineDraft(blocks: [bath]),
        routinePlans: mondayOnlyPlans,
        desiredApplicationsPerDay: 3,
        ownedProductNames: const ['Cleanser', 'Sunscreen'],
        now: DateTime.utc(2026, 6, 15),
      );

      expect(result.errorMessage, isNull);
      for (final day in onboarding7EveryDay) {
        expect(onboarding7RoutineCountForDay(result.blocks, day), 3);
      }
      final draft = _hasProductsDraft(
        desiredApplicationsPerDay: 3,
        blocks: result.blocks,
      );
      expect(
        draft.validateStep(
          7,
          List<bool>.filled(OnboardingDraft.stepCount, true),
        ),
        isNull,
      );
    },
  );

  test('24. Partial-day product routine does not pass Step 7 validation', () {
    const mondayOnly = TimelineBlockDraft(
      id: 'skin-monday',
      section: 'skin_care',
      title: 'Morning Skin Care',
      startMinute: 455,
      endMinute: 470,
      repeatDays: [1],
      blockType: TimelineBlockDraft.softBlockKey,
      skincareSteps: ['Cleanse', 'Sunscreen'],
      skincareProducts: ['Cleanser', 'Sunscreen'],
    );
    final draft = _hasProductsDraft(blocks: const [mondayOnly]);

    expect(
      draft.validateStep(7, List<bool>.filled(OnboardingDraft.stepCount, true)),
      'Monday has 1 of 2 skin-care routines. Add or restore one routine.',
    );
  });

  test('25. Scheduler rejects title-only plans from fallback products', () {
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(
        blocks: [BaseTimelineDraft.defaultBathBlock()],
      ),
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning Skin Care',
          steps: [],
          productNames: [],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Night Skin Care',
          steps: [],
          productNames: [],
        ),
      ],
      desiredApplicationsPerDay: 2,
      ownedProductNames: const [
        'Gentle Cleanser',
        'Daily Sunscreen',
        'Barrier Repair Moisturizer',
      ],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.blocks, isEmpty);
    expect(
      result.errorMessage,
      'AI returned no usable routine. Try clearer product names or 2 times/day.',
    );
  });

  test('26. Scheduler fails title-only plans without safe fallback products', () {
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(
        blocks: [BaseTimelineDraft.defaultBathBlock()],
      ),
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning Skin Care',
          steps: [],
          productNames: [],
        ),
      ],
      desiredApplicationsPerDay: 2,
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.blocks, isEmpty);
    expect(
      result.errorMessage,
      'AI returned no usable routine. Try clearer product names or 2 times/day.',
    );
  });

  test(
    '27. Worker client maps image and routine JSON payload errors correctly',
    () async {
      final imageClient = WorkerSkinCareAiClient(
        baseUrl: 'https://skin-care-worker.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'image_payload_too_large',
              'message': 'Image exceeds 15MB limit.',
            }),
            413,
          ),
        ),
      );
      final imageResult = await imageClient.analyzeProducts(
        uid: 'uid-1',
        idToken: 'token',
        productPhotos: const ['users/uid-1/onboarding/skin_care/products.jpg'],
      );
      expect(
        imageResult.errorMessage,
        'Product photo is too large. Upload a smaller, clearer photo.',
      );

      final routineClient = WorkerSkinCareAiClient(
        baseUrl: 'https://skin-care-worker.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'json_payload_too_large',
              'message': 'JSON request payload too large.',
            }),
            413,
          ),
        ),
      );
      final routineResult = await routineClient.generateRoutine(
        uid: 'uid-1',
        idToken: 'token',
        params: const {
          'typedProductNames': ['Cleanser'],
        },
      );
      expect(
        routineResult.errorMessage,
        'Skin-care product details were too large to send. Try typing your main products or upload a clearer single photo.',
      );
    },
  );

  test('27b. Worker client distinguishes provider failures', () async {
    final cases = <(int, String, String)>[
      (
        502,
        'provider_unauthorized',
        'Skin care AI provider authorization failed. Please check the worker configuration.',
      ),
      (
        502,
        'provider_model_not_found',
        'Skin care AI model is unavailable. Please check the worker model configuration.',
      ),
      (
        429,
        'provider_quota_exceeded',
        'AI usage limit reached. Try again later.',
      ),
      (
        504,
        'provider_timeout',
        'AI skin care service is unavailable. Try again later.',
      ),
      (
        503,
        'provider_high_demand',
        'AI is busy right now. Try again in a moment.',
      ),
    ];

    for (final (status, code, message) in cases) {
      final client = WorkerSkinCareAiClient(
        baseUrl: 'https://skin-care-worker.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': code, 'message': 'Provider failure.'}),
            status,
          ),
        ),
      );
      final result = await client.generateRoutine(
        uid: 'uid-1',
        idToken: 'token',
        params: const {
          'typedProductNames': ['Cleanser'],
        },
      );

      expect(result.errorCode, code);
      expect(result.errorMessage, message);
    }
  });

  test('27bb. Worker client preserves safe stage diagnostics', () async {
    final cases = <(String, String)>[
      ('recommendation', "We couldn't find products right now. Try again."),
      (
        'recommendation_repair',
        "We found products, but couldn't complete the required set.",
      ),
      (
        'routine_generation',
        "Products are ready, but we couldn't build your routine right now.",
      ),
    ];

    for (final (stage, message) in cases) {
      final client = WorkerSkinCareAiClient(
        baseUrl: 'https://skin-care-worker.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'provider_high_demand',
              'message': 'Provider failure.',
              'stage': stage,
              'requestId': 'req-1234',
            }),
            503,
          ),
        ),
      );
      final result = await client.generateRoutine(
        uid: 'uid-1',
        idToken: 'token',
        params: const {
          'typedProductNames': ['Cleanser'],
        },
      );

      expect(result.errorCode, 'provider_high_demand');
      expect(result.errorStage, stage);
      expect(result.requestId, 'req-1234');
      expect(result.errorMessage, message);
    }
  });

  test(
    '27c. Worker client times out safely without fabricating output',
    () async {
      final client = WorkerSkinCareAiClient(
        baseUrl: 'https://skin-care-worker.test',
        requestTimeout: Duration.zero,
        client: MockClient((_) => Completer<http.Response>().future),
      );

      final result = await client.generateRoutine(
        uid: 'uid-1',
        idToken: 'token',
        params: const {
          'typedProductNames': ['Cleanser'],
        },
      );

      expect(result.hasError, isTrue);
      expect(result.errorMessage, 'provider_timeout');
      expect(result.errorCode, 'provider_timeout');
      expect(result.routinePlans, isEmpty);
      expect(result.timelineBlocks, isEmpty);
    },
  );

  test('28. Worker client filters title-only routine plans', () async {
    final client = WorkerSkinCareAiClient(
      baseUrl: 'https://skin-care-worker.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'routinePlans': [
              {'slotLabel': 'morning', 'title': 'Morning Skin Care'},
              {
                'slotLabel': 'night',
                'title': 'Night Skin Care',
                'steps': ['Cleanse'],
                'productNames': ['Gentle Cleanser'],
                'missingItems': [
                  {
                    'name': 'Moisturizer',
                    'importance': 'important',
                    'reason': 'Helps reduce dryness.',
                  },
                ],
              },
            ],
            'timelineBlocks': [],
            'morningRoutine': [],
            'nightRoutine': [],
            'weeklyRoutine': [],
          }),
          200,
        ),
      ),
    );

    final result = await client.generateRoutine(
      uid: 'uid-1',
      idToken: 'token',
      params: const {
        'typedProductNames': ['Gentle Cleanser'],
      },
    );

    expect(result.routinePlans, hasLength(1));
    expect(result.routinePlans.single.slotLabel, 'night');
    expect(result.routinePlans.single.missingItems.single.name, 'Moisturizer');
    expect(
      result.routinePlans.single.missingItems.single.displayLabel,
      'Moisturizer (important, missing)',
    );
  });

  test('28a. Worker client parses branded product recommendations', () async {
    final client = WorkerSkinCareAiClient(
      baseUrl: 'https://skin-care-worker.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'routinePlans': [],
            'recommendedProducts': [
              {
                'name': 'Gentle Cleanser',
                'brand': 'Minimalist',
                'category': 'cleanser',
                'estimatedPrice': '299',
                'currencyCode': 'INR',
                'reason': 'Affordable and useful',
              },
            ],
            'timelineBlocks': [],
            'morningRoutine': [],
            'nightRoutine': [],
            'weeklyRoutine': [],
          }),
          200,
        ),
      ),
    );

    final result = await client.generateRoutine(
      uid: 'uid-1',
      idToken: 'token',
      params: const {'recommendationOnly': true},
    );

    expect(result.recommendedProducts, hasLength(1));
    expect(
      result.recommendedProducts.single.displayName,
      'Minimalist Gentle Cleanser',
    );
    expect(result.recommendedProducts.single.estimatedPrice, '299');
  });

  test(
    '28b. Worker client does not use compatibility blocks as plans',
    () async {
      final client = WorkerSkinCareAiClient(
        baseUrl: 'https://skin-care-worker.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'routinePlans': [],
              'timelineBlocks': [
                {
                  'title': 'Compatibility Morning',
                  'startMinute': 420,
                  'endMinute': 435,
                  'products': ['Cleanser'],
                  'steps': ['Cleanse'],
                },
              ],
              'morningRoutine': [],
              'nightRoutine': [],
              'weeklyRoutine': [],
            }),
            200,
          ),
        ),
      );

      final result = await client.generateRoutine(
        uid: 'uid-1',
        idToken: 'token',
        params: const {
          'typedProductNames': ['Gentle Cleanser'],
        },
      );

      expect(result.routinePlans, isEmpty);
      expect(result.timelineBlocks, hasLength(1));
    },
  );

  test(
    '29. Different occupied weekdays produce grouped blocks with correct daily routine count',
    () {
      const bath = TimelineBlockDraft(
        id: BaseTimelineDraft.fixedBathId,
        section: 'fixed',
        title: 'Bath',
        startMinute: 420,
        endMinute: 450,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
      );
      const mondayLunch = TimelineBlockDraft(
        id: 'monday-lunch',
        section: 'eating',
        title: 'Lunch',
        startMinute: 765,
        endMinute: 810,
        repeatDays: [1],
        blockType: TimelineBlockDraft.softBlockKey,
      );

      final result = onboarding7ScheduleSkinCareRoutine(
        baseTimeline: const BaseTimelineDraft(blocks: [bath, mondayLunch]),
        routinePlans: _skinCarePlansForCount(3),
        desiredApplicationsPerDay: 3,
        ownedProductNames: const ['Cleanser', 'Sunscreen'],
        now: DateTime.utc(2026, 6, 15),
      );

      expect(result.errorMessage, isNull);
      expect(result.blocks.length, greaterThan(3));
      final middayBlocks = result.blocks
          .where((block) => block.skincareSlotLabel == 'midday')
          .toList();
      expect(middayBlocks, hasLength(2));
      expect(
        middayBlocks
            .singleWhere((block) => block.startMinute == 810)
            .repeatDays,
        [1],
      );
      expect(
        middayBlocks
            .singleWhere((block) => block.startMinute == 815)
            .repeatDays,
        [2, 3, 4, 5, 6, 7],
      );
      for (final day in onboarding7EveryDay) {
        expect(onboarding7RoutineCountForDay(result.blocks, day), 3);
      }
      final draft = _hasProductsDraft(blocks: result.blocks);
      expect(
        draft.validateStep(
          7,
          List<bool>.filled(OnboardingDraft.stepCount, true),
        ),
        isNull,
      );
    },
  );

  testWidgets(
    '30. No real bath blocks generation and creates no skin-care blocks',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: _routineResultWithPlanCount(2),
      );
      await tester.pumpWidget(
        buildTestWidget(draft: _hasProductsDraft(), client: client),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser, Sunscreen',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      expect(
        container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .confirmedBlocksForSection('skin_care'),
        isEmpty,
      );
      expect(find.text('Set bath time first.'), findsOneWidget);
    },
  );

  testWidgets(
    '31. Uploaded product photo persists after rebuild and R2 key is used',
    (tester) async {
      final asset = _uploadedAsset();
      final firstClient = TestSkinCareAiClient(
        routineResult: _routineResultWithPlanCount(2),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            uid: 'uid-1',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: firstClient,
          uploadController: TestUploadController(result: asset),
        ),
      );
      await tester.pumpAndSettle();

      await chooseSkinPhotoFromGallery(tester);
      final firstContainer = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final persistedDraft = firstContainer.read(onboardingStateProvider).draft;
      expect(
        persistedDraft.baseTimeline.skinCareProductPhotoR2Key,
        asset.r2Key,
      );
      expect(
        persistedDraft.baseTimeline.skinCareProductPhotoCreatedAt,
        asset.createdAt,
      );
      expect(
        persistedDraft.baseTimeline.skinCareProductPhotoUpdatedAt,
        asset.updatedAt,
      );

      final secondClient = TestSkinCareAiClient(
        productResult: const SkinCareAiProductResult(
          products: [
            {'name': 'Cleanser'},
            {'name': 'Sunscreen SPF 50'},
          ],
        ),
        routineResult: _routineResultWithPlanCount(2),
      );
      await tester.pumpWidget(
        buildTestWidget(draft: persistedDraft, client: secondClient),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photo uploaded'), findsOneWidget);
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      expect(secondClient.lastProductPhotos, [asset.r2Key]);
      expect(secondClient.analyzeCalls, 1);
    },
  );

  testWidgets(
    '32. Restored product photo states validate content type and show filename',
    (tester) async {
      final jpgClient = TestSkinCareAiClient(
        productResult: const SkinCareAiProductResult(
          products: [
            {'name': 'Cleanser'},
            {'name': 'Sunscreen SPF 50'},
          ],
        ),
        routineResult: _routineResultWithPlanCount(2),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            productPhotoAssetId: 'restored-products',
            productPhotoR2Key:
                'users/uid-1/onboarding/skin_care/restored-products.jpg',
            productPhotoStatus: 'uploaded',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: jpgClient,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photo uploaded'), findsOneWidget);
      expect(find.text('restored-products.jpg'), findsOneWidget);
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();
      expect(jpgClient.analyzeCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            productPhotoAssetId: 'restored-products',
            productPhotoR2Key:
                'users/uid-1/onboarding/skin_care/restored-products.heic',
            productPhotoStatus: 'uploaded',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: jpgClient,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photo uploaded'), findsNothing);
      expect(find.text('restored-products.heic'), findsNothing);
      expect(find.text('Add photo'), findsOneWidget);
    },
  );

  testWidgets(
    '33. Visual stretch lane logic keeps close edit buttons reachable',
    (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: const [
              TimelineBlockDraft(
                id: 'skin-a',
                section: 'skin_care',
                title: 'Morning Skin Care',
                startMinute: 455,
                endMinute: 470,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.softBlockKey,
                skincareSteps: [
                  'Face wash',
                  'Vitamin C serum',
                  'Moisturizer',
                  'Sunscreen',
                ],
              ),
              TimelineBlockDraft(
                id: 'skin-b',
                section: 'skin_care',
                title: 'Midday Skin Care',
                startMinute: 475,
                endMinute: 490,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.softBlockKey,
                skincareSteps: ['Refresh skin', 'Reapply sunscreen'],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstRect = tester.getRect(
        find.byKey(const ValueKey('onboarding-step7-block-skin-a')),
      );
      final secondRect = tester.getRect(
        find.byKey(const ValueKey('onboarding-step7-block-skin-b')),
      );
      expect(firstRect.overlaps(secondRect), isFalse);
      expect(
        find.byKey(const ValueKey('onboarding-step7-edit-skin-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step7-edit-skin-b')),
        findsOneWidget,
      );
    },
  );

  test('33b. Adjacent timeline blocks keep independent content stretch', () {
    final layout = OnboardingTimelineLayout(
      startMinute: 450,
      rangeMinutes: 60,
      pxPerMinute: 1,
      topPadding: 0,
      segments: const [
        StretchedSegment(startMinute: 455, endMinute: 470, extraStretch: 100),
        StretchedSegment(startMinute: 470, endMinute: 485, extraStretch: 20),
      ],
    );

    expect(layout.yFor(470) - layout.yFor(455), 115);
    expect(layout.yFor(485) - layout.yFor(470), 35);
  });

  testWidgets('33c. All seven day chips fit the available width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: const ValueKey('day-chip-width'),
              width: 300,
              child: OnboardingDayChips(selectedDay: 1, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bounds = tester.getRect(find.byKey(const ValueKey('day-chip-width')));
    for (final label in const [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN',
    ]) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(bounds.left));
      expect(rect.right, lessThanOrEqualTo(bounds.right));
    }
  });

  testWidgets('33d. Minute indicators use consistent AM/PM labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 100,
            child: Stack(
              children: [
                OnboardingMinuteIndicator(minute: 17 * 60 + 15, top: 30),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('5:15 PM'), findsOneWidget);
  });

  testWidgets(
    '34. Missing worker config without override does not create fake blocks',
    (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: WorkerSkinCareAiClient(baseUrl: ''),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser, Sunscreen',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      expect(
        container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .confirmedBlocksForSection('skin_care'),
        isEmpty,
      );
      expect(
        find.textContaining('OPTIVUS_SKIN_CARE_WORKER_URL'),
        findsOneWidget,
      );
    },
  );

  testWidgets('35. Unsupported uploaded image type shows friendly error', (
    tester,
  ) async {
    final asset = _uploadedAsset(contentType: 'image/heic');
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
        uploadController: TestUploadController(result: asset),
      ),
    );
    await tester.pumpAndSettle();

    await chooseSkinPhotoFromGallery(tester);
    await tapBuildRoutine(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This photo format is not supported. Please upload JPEG, PNG, or WEBP.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('36. Upload busy generate button has readable state', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(),
        uploadController: TestUploadController(
          initialState: const UploadState(
            status: UploadFlowStatus.uploading,
            purpose: UploadedAssetPurpose.skinProducts,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Please wait...'), findsOneWidget);
  });

  testWidgets('37. Switching product mode to skip clears product fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(draft: _choiceDraftWithProductData()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    final base = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    ).read(onboardingStateProvider).draft.baseTimeline;
    expect(base.skinCareSkipped, isTrue);
    expect(base.skinCareProductNames, isNull);
    expect(base.skinCareProductPhotoAssetId, isNull);
    expect(base.skinCareProductPhotoR2Key, isNull);
    expect(base.skinCareProductPhotoCreatedAt, isNull);
    expect(base.skinCareProductPhotoUpdatedAt, isNull);
    expect(base.skinCareSpecialCareNotes, isEmpty);
    expect(base.blocks.where((block) => block.section == 'skin_care'), isEmpty);
  });

  testWidgets(
    '38. Switching product mode to build-for-me preserves independent product inputs',
    (tester) async {
      await tester.pumpWidget(
        buildTestWidget(draft: _choiceDraftWithProductData()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('No products'));
      await tester.pumpAndSettle();

      final base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(onboardingStateProvider).draft.baseTimeline;
      expect(base.skinCareSetupPath, 'no_products');
      expect(base.skinCareProductNames, 'Cleanser');
      expect(base.skinCareProductPhotoAssetId, isNull);
      expect(base.skinCareProductPhotoR2Key, isNull);
      expect(base.skinCareProductPhotoCreatedAt, isNull);
      expect(base.skinCareProductPhotoUpdatedAt, isNull);
      expect(base.skinCareSpecialCareNotes, isEmpty);
      expect(
        base.blocks.where((block) => block.section == 'skin_care'),
        isEmpty,
      );
    },
  );

  testWidgets('39. Reselecting same product mode preserves current input', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(draft: _choiceDraftWithProductData()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('I have products'));
    await tester.pumpAndSettle();

    final base = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    ).read(onboardingStateProvider).draft.baseTimeline;
    expect(base.skinCareSetupPath, 'has_products');
    expect(base.skinCareProductNames, 'Cleanser');
    expect(base.skinCareProductPhotoAssetId, 'skin-asset');
    expect(base.skinCareProductPhotoR2Key, contains('skin-asset.jpg'));
    expect(base.skinCareProductPhotoCreatedAt, DateTime.utc(2026, 6, 15, 10));
  });

  testWidgets(
    '40. Pre-generation products mode stays fixed with keyboard and message',
    (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStateProvider.overrideWith((ref) {
              final notifier = OnboardingNotifier();
              notifier.loadSeedData(_hasProductsDraft());
              notifier.setValidationMessage(
                'Type one product per line, for example "Minimalist SPF 50 - sunscreen".',
              );
              return notifier;
            }),
            skinCareAiClientProvider.overrideWithValue(
              const FakeSkinCareAiClient(),
            ),
            uploadControllerProvider.overrideWith(
              (ref) => TestUploadController(),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 560),
                viewInsets: EdgeInsets.only(bottom: 260),
              ),
              child: OnboardingStepShell(
                currentPage: 7,
                pageOffset: 7,
                completedSteps: List<bool>.filled(
                  OnboardingDraft.stepCount,
                  false,
                ),
                validationMessage:
                    'Type one product per line, for example "Minimalist SPF 50 - sunscreen".',
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
                child: const OnboardingStep7(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Next Step'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(OnboardingStep7),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(find.text('Build skin routine'), findsNothing);
      expect(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '46. Routine built summary card handles narrow screen without overflow',
    (tester) async {
      // Narrow screen (e.g. iPhone SE width or even smaller)
      tester.view.physicalSize = const Size(280, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(
          draft: const OnboardingDraft(
            currentStep: 7,
            baseTimeline: BaseTimelineDraft(
              skinCareSetupStep: 1,
              skinCareSetupPath: 'has_products',
              skinCareDesiredApplicationsPerDay: 2,
              blocks: [
                TimelineBlockDraft(
                  id: 'sc-1',
                  section: 'skin_care',
                  title: 'Morning routine',
                  startMinute: 420,
                  endMinute: 435,
                  blockType: 'soft_block',
                  repeatDays: [1, 2, 3, 4, 5, 6, 7],
                ),
                TimelineBlockDraft(
                  id: 'sc-2',
                  section: 'skin_care',
                  title: 'Night routine',
                  startMinute: 1320,
                  endMinute: 1335,
                  blockType: 'soft_block',
                  repeatDays: [1, 2, 3, 4, 5, 6, 7],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onboarding-step7-full-timeline')),
        findsOneWidget,
      );
      expect(find.text('Skin Care Routine'), findsOneWidget);
      expect(find.text('Review your weekly routine'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '47. Worker returns json_payload_too_large triggers compact retry and succeeds',
    (tester) async {
      final asset = _uploadedAsset();
      final client = TestSkinCareAiClient(
        productResult: _richSkinCareProductResult(),
        routineResultsQueue: [
          SkinCareAiRoutineResult.error(
            'Error',
            errorCode: 'json_payload_too_large',
          ),
          _routineResultWithPlanCount(2),
        ],
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            uid: 'uid-1',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
          uploadController: TestUploadController(result: asset),
        ),
      );
      await tester.pumpAndSettle();

      await chooseSkinPhotoFromGallery(tester);

      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      expect(client.generateCalls.length, 2);
      expect(client.generateCalls[0]['compact'], isNot(true));
      expect(client.generateCalls[1]['compact'], isTrue);
      final firstProducts =
          client.generateCalls[0]['typedProductDetails'] as List<dynamic>;
      final secondProducts =
          client.generateCalls[1]['typedProductDetails'] as List<dynamic>;
      expect(jsonEncode(firstProducts), isNot(jsonEncode(secondProducts)));
      expect((firstProducts.first as Map)['brand'], '');
      expect((secondProducts.first as Map).containsKey('brand'), isFalse);
      expect((firstProducts.first as Map)['keyIngredients'], hasLength(7));
      expect((secondProducts.first as Map)['keyIngredients'], hasLength(4));
      expect(
        ((secondProducts.first as Map)['usageHint'] as String).length,
        lessThanOrEqualTo(100),
      );
      expect(
        (secondProducts.first as Map).containsKey('warningIfAny'),
        isFalse,
      );
      expect(find.textContaining('Error'), findsNothing);
      expect(find.textContaining('too large'), findsNothing);
      expect(find.text('Skin Care Routine'), findsOneWidget);
      expect(find.text('Review your weekly routine'), findsOneWidget);
    },
  );

  testWidgets(
    '49. Worker returns json_payload_too_large twice triggers final error message',
    (tester) async {
      final asset = _uploadedAsset();
      final client = TestSkinCareAiClient(
        productResult: _richSkinCareProductResult(),
        routineResultsQueue: [
          SkinCareAiRoutineResult.error(
            'Error',
            errorCode: 'json_payload_too_large',
          ),
          SkinCareAiRoutineResult.error(
            'Error',
            errorCode: 'json_payload_too_large',
          ),
        ],
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            uid: 'uid-1',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
          uploadController: TestUploadController(result: asset),
        ),
      );
      await tester.pumpAndSettle();

      await chooseSkinPhotoFromGallery(tester);

      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      expect(client.generateCalls.length, 2);
      expect(find.text(onboarding7CompactPayloadFinalMessage), findsOneWidget);
    },
  );

  testWidgets(
    '48. Weekly/special-care plans are filtered from daily blocks and added to suggestions',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: const SkinCareAiRoutineResult(
          morningRoutine: [],
          nightRoutine: [],
          weeklyRoutine: [],
          timelineBlocks: [],
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Exfoliation Night',
              steps: ['Cleanse', 'Exfoliate'],
              productNames: ['AHA BHA'],
              repeatDays: [3, 7], // Weekly plan
            ),
            SkinCareRoutinePlan(
              slotLabel: 'morning',
              title: 'Daily Morning',
              steps: ['Cleanse', 'Sunscreen'],
              productNames: ['Cleanser', 'SPF'],
              repeatDays: [1, 2, 3, 4, 5, 6, 7], // Daily plan
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Daily Night',
              steps: ['Cleanse', 'Moisturizer'],
              productNames: ['Cleanser', 'Moisturizer'],
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('I have products'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser, Sunscreen, Moisturizer, AHA BHA',
      );
      await tester.pumpAndSettle();

      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final draftState = container.read(onboardingStateProvider);
      expect(
        draftState.draft.baseTimeline.skinCareSpecialCareNotes,
        contains(startsWith('Special care: Exfoliation Night - AHA BHA')),
      );
      expect(find.textContaining('Suggested:'), findsNothing);
      final scBlocks = draftState.draft.baseTimeline.blocks
          .where((b) => b.section == 'skin_care')
          .toList();
      expect(scBlocks.length, 2);
    },
  );

  testWidgets(
    '50. Full-week strong active plan is filtered as special care and does not act as daily block',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: const SkinCareAiRoutineResult(
          morningRoutine: [],
          nightRoutine: [],
          weeklyRoutine: [],
          timelineBlocks: [],
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Retinol Treatment',
              steps: ['Apply Retinol'],
              productNames: ['Retinol Serum'],
              repeatDays: [1, 2, 3, 4, 5, 6, 7], // Full week, but strong active
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('I have products'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser, Moisturizer, Sunscreen, Retinol Serum',
      );
      await tester.pumpAndSettle();

      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final draftState = container.read(onboardingStateProvider);
      final scBlocks = draftState.draft.baseTimeline.blocks
          .where((b) => b.section == 'skin_care')
          .toList();
      expect(
        draftState.draft.baseTimeline.skinCareSpecialCareNotes,
        contains(startsWith('Special care: Retinol Treatment - Retinol Serum')),
      );
      expect(scBlocks, isEmpty);
      expect(
        find.text(
          'AI returned no usable routine. Try clearer product names or 2 times/day.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '51. Special-care and weekly notes persist, render from draft, and survive rebuild',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: const SkinCareAiRoutineResult(
          suggestedProducts: ['Use barrier moisturizer after exfoliation'],
          weeklyRoutine: [
            'Special care: Retinol night - use 2x/week; avoid acids the same night',
            'warning: Patch test before new actives',
          ],
          routinePlans: [
            SkinCareRoutinePlan(
              slotLabel: 'morning',
              title: 'Daily Morning',
              steps: ['Cleanse', 'Sunscreen'],
              productNames: ['Cleanser', 'Sunscreen'],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'Daily Night',
              steps: ['Cleanse', 'Moisturizer'],
              productNames: ['Cleanser', 'Moisturizer'],
            ),
            SkinCareRoutinePlan(
              slotLabel: 'night',
              title: 'AHA Night',
              steps: ['Apply AHA'],
              productNames: ['AHA Serum'],
              repeatDays: [3, 7],
            ),
          ],
          morningRoutine: [],
          nightRoutine: [],
          timelineBlocks: [],
        ),
      );

      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser, Sunscreen, Moisturizer, AHA Serum, Retinol',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final persistedDraft = container.read(onboardingStateProvider).draft;
      final notes = persistedDraft.baseTimeline.skinCareSpecialCareNotes;

      expect(notes, contains('Use barrier moisturizer after exfoliation'));
      expect(
        notes,
        contains(
          'Special care: Retinol night - use 2x/week; avoid acids the same night',
        ),
      );
      expect(notes, contains('warning: Patch test before new actives'));
      expect(
        notes,
        contains(startsWith('Special care: AHA Night - AHA Serum')),
      );

      expect(find.textContaining('Suggested:'), findsNothing);
      expect(find.textContaining('barrier moisturizer'), findsNothing);
      expect(find.textContaining('Retinol night - use 2x/week'), findsNothing);
      expect(
        find.byKey(
          const ValueKey('onboarding-step7-special-care-notes-button'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey('onboarding-step7-special-care-notes-button'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Special-care notes'), findsOneWidget);
      expect(find.textContaining('barrier moisturizer'), findsOneWidget);
      expect(
        find.textContaining('Retinol night - use 2x/week'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        buildTestWidget(
          draft: persistedDraft,
          client: TestSkinCareAiClient(
            routineResult: _routineResultWithPlanCount(2),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Suggested:'), findsNothing);
      expect(find.textContaining('barrier moisturizer'), findsNothing);
      await tester.tap(
        find.byKey(
          const ValueKey('onboarding-step7-special-care-notes-button'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('barrier moisturizer'), findsOneWidget);
      expect(
        find.textContaining('Retinol night - use 2x/week'),
        findsOneWidget,
      );
      expect(find.textContaining('AHA Night - AHA Serum'), findsOneWidget);
    },
  );

  testWidgets(
    '52. Rebuild preserves notes until regeneration replaces the note set',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResultsQueue: [
          SkinCareAiRoutineResult(
            suggestedProducts: const [],
            morningRoutine: const [],
            nightRoutine: const [],
            weeklyRoutine: const ['missing: First note'],
            timelineBlocks: const [],
            routinePlans: _skinCarePlansForCount(2),
          ),
          SkinCareAiRoutineResult(
            suggestedProducts: const [],
            morningRoutine: const [],
            nightRoutine: const [],
            weeklyRoutine: const ['missing: Second note'],
            timelineBlocks: const [],
            routinePlans: _skinCarePlansForCount(2),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser, Sunscreen, Moisturizer',
      );
      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();

      var base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(onboardingStateProvider).draft.baseTimeline;
      expect(base.skinCareSpecialCareNotes, ['missing: First note']);
      final originalBlockIds = base
          .confirmedBlocksForSection('skin_care')
          .map((block) => block.id)
          .toList();

      expect(find.textContaining('Suggested:'), findsNothing);

      triggerRebuild(tester);
      await tester.pumpAndSettle();
      base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(onboardingStateProvider).draft.baseTimeline;
      expect(base.skinCareSpecialCareNotes, ['missing: First note']);
      expect(
        base
            .confirmedBlocksForSection('skin_care')
            .map((block) => block.id)
            .toList(),
        originalBlockIds,
      );

      await tapBuildRoutine(tester);
      await tester.pumpAndSettle();
      base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(onboardingStateProvider).draft.baseTimeline;
      expect(base.skinCareSpecialCareNotes, ['missing: Second note']);

      await tester.tap(
        find.byKey(
          const ValueKey('onboarding-step7-special-care-notes-button'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Second note'), findsOneWidget);
      expect(find.textContaining('First note'), findsNothing);
    },
  );

  testWidgets(
    '53. Draft special-care notes render without local widget state',
    (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            specialCareNotes: const ['Special care: saved draft note'],
            blocks: const [
              TimelineBlockDraft(
                id: 'skin-saved',
                section: 'skin_care',
                title: 'Morning Skin Care',
                startMinute: 455,
                endMinute: 470,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.softBlockKey,
                skincareProducts: ['Cleanser', 'Sunscreen'],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Suggested:'), findsNothing);
      await tester.tap(
        find.byKey(
          const ValueKey('onboarding-step7-special-care-notes-button'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Special care: saved draft note'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '54. Edit sheet rejects empty products and steps without changing block',
    (tester) async {
      const skinBlock = TimelineBlockDraft(
        id: 'skin-edit-empty',
        section: 'skin_care',
        title: 'Morning Skin Care',
        startMinute: 455,
        endMinute: 470,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: ['Cleanser', 'Sunscreen'],
        skincareSteps: ['Cleanse', 'Apply sunscreen'],
      );
      await tester.pumpWidget(
        buildTestWidget(draft: _hasProductsDraft(blocks: const [skinBlock])),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-edit-skin-edit-empty')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-edit-products-field')),
        '',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-edit-steps-field')),
        '',
      );
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-edit-save-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Add at least one product or routine step.'),
        findsOneWidget,
      );
      final updated =
          ProviderScope.containerOf(
                tester.element(find.byType(OnboardingStep7)),
              )
              .read(onboardingStateProvider)
              .draft
              .baseTimeline
              .blocks
              .singleWhere((block) => block.id == 'skin-edit-empty');
      expect(updated.skincareProducts, skinBlock.skincareProducts);
      expect(updated.skincareSteps, skinBlock.skincareSteps);
    },
  );

  test('55. Missing routine helper reports first missing day and count', () {
    const blocks = [
      TimelineBlockDraft(
        id: 'mon-morning',
        section: 'skin_care',
        title: 'Morning Skin Care',
        startMinute: 455,
        endMinute: 470,
        repeatDays: [1],
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: ['Cleanser', 'Sunscreen'],
      ),
      TimelineBlockDraft(
        id: 'mon-night',
        section: 'skin_care',
        title: 'Night Skin Care',
        startMinute: 1260,
        endMinute: 1275,
        repeatDays: [1],
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: ['Cleanser', 'Moisturizer'],
      ),
    ];

    expect(
      onboarding7MissingRoutineMessage(blocks, 3),
      'Monday has 2 of 3 skin-care routines. Add or restore one routine.',
    );
    expect(
      onboarding7MissingRoutineMessage(_skinCareBlocksForEveryDay(2), 2),
      isNull,
    );
  });

  test('55b. Step completion requires a valid routine or explicit skip', () {
    final validRoutine = _hasProductsDraft(
      uid: 'test_uid',
      productNames: 'Cleanser\nSunscreen',
      blocks: _skinCareBlocksForEveryDay(2),
    ).baseTimeline;
    expect(onboarding7CanContinue(validRoutine, 'test_uid'), isTrue);
    expect(
      onboarding7CanContinue(
        const BaseTimelineDraft(
          skinCareSetupPath: 'has_products',
          skinCareDesiredApplicationsPerDay: 2,
        ),
        'test_uid',
      ),
      isFalse,
    );
    expect(
      onboarding7CanContinue(
        const BaseTimelineDraft(
          skinCareSetupPath: 'skip',
          skinCareSkipped: true,
        ),
        'test_uid',
      ),
      isTrue,
    );
  });

  test(
    '56. Full-week retinol, AHA, and BHA plans partition as special care',
    () {
      final partitioned = onboarding7PartitionRoutinePlans(const [
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Retinol Treatment',
          steps: ['Apply retinol'],
          productNames: ['Retinol Serum'],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'AHA Treatment',
          steps: ['Apply AHA'],
          productNames: ['AHA Serum'],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'BHA Treatment',
          steps: ['Apply BHA'],
          productNames: ['BHA Liquid'],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Daily Morning',
          steps: ['Apply sunscreen'],
          productNames: ['Sunscreen'],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
      ]);

      expect(partitioned.specialCarePlans, hasLength(3));
      expect(partitioned.dailyPlans, hasLength(1));
    },
  );

  test('57. Scheduler validates owned products and preserves names', () {
    final bathBase = BaseTimelineDraft(
      blocks: [BaseTimelineDraft.defaultBathBlock()],
    );
    const noRoutineMessage =
        'AI returned no usable routine. Try clearer product names or 2 times/day.';
    const productMismatchMessage =
        'AI used products outside your list. Try again.';
    const fewerRoutinesMessage =
        'AI returned fewer routines than requested. Try again or choose fewer times per day.';

    final sunscreenWithNightCleanser = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 3,
      ownedProductNames: const ['Daily Sunscreen', 'Gentle Cleanser'],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning SPF',
          steps: ['Apply sunscreen'],
          productNames: ['Daily Sunscreen'],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'midday',
          title: 'Midday SPF',
          steps: ['Reapply sunscreen'],
          productNames: ['sunscreen'],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Night Cleanse',
          steps: ['Cleanse'],
          productNames: ['Gentle Cleanser'],
        ),
      ],
      now: DateTime.utc(2026, 6, 15),
    );
    expect(sunscreenWithNightCleanser.errorMessage, isNull);
    expect(sunscreenWithNightCleanser.blocks, hasLength(3));
    expect(
      sunscreenWithNightCleanser.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'morning')
          .skincareProducts,
      ['Daily Sunscreen'],
    );
    expect(
      sunscreenWithNightCleanser.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'midday')
          .skincareSteps,
      ['Reapply sunscreen'],
    );
    expect(
      sunscreenWithNightCleanser.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'night')
          .skincareProducts,
      ['Gentle Cleanser'],
    );

    final nameVariations = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 2,
      ownedProductNames: const [
        'Beardo Detan Face Wash',
        'Minimalist SPF 50',
        'Minimalist Vitamin C',
        'Minimalist Alpha Arbutin',
      ],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning Actives',
          steps: ['Vitamin C serum', 'Sunscreen'],
          productNames: ['Vitamin C serum', 'Minimalist SPF 50 Sunscreen'],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Night Brightening',
          steps: ['Face wash', 'Alpha Arbutin serum'],
          productNames: ['Beardo Detan Face Wash', 'Alpha Arbutin serum'],
        ),
      ],
      now: DateTime.utc(2026, 6, 15),
    );
    expect(nameVariations.errorMessage, isNull);
    expect(
      nameVariations.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'morning')
          .skincareProducts,
      ['Minimalist Vitamin C', 'Minimalist SPF 50'],
    );
    expect(
      nameVariations.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'night')
          .skincareProducts,
      ['Beardo Detan Face Wash', 'Minimalist Alpha Arbutin'],
    );

    final cleanserMoisturizerOnly = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 2,
      ownedProductNames: const [
        'Beardo Detan Face Wash',
        'Barrier Repair Lotion',
      ],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning Cleanse',
          steps: ['Cleanse'],
          productNames: ['cleanser'],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Night Lotion',
          steps: ['Apply lotion'],
          productNames: ['moisturizer'],
        ),
      ],
      now: DateTime.utc(2026, 6, 15),
    );
    expect(cleanserMoisturizerOnly.errorMessage, isNull);
    expect(
      cleanserMoisturizerOnly.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'morning')
          .skincareProducts,
      ['Beardo Detan Face Wash'],
    );
    expect(
      cleanserMoisturizerOnly.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'night')
          .skincareProducts,
      ['Barrier Repair Lotion'],
    );

    final missingBasics = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 2,
      ownedProductNames: const ['Hydrating Serum', 'Barrier Repair Lotion'],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning Serum',
          steps: ['Apply hydrating serum', 'Add sunscreen when available'],
          productNames: ['Hydrating Serum'],
          missingItems: [
            SkinCareMissingItem(
              name: 'Sunscreen',
              importance: 'important',
              reason: 'Needed for daytime protection.',
            ),
            SkinCareMissingItem(
              name: 'Cleanser',
              importance: 'important',
              reason: 'Needed before applying leave-on products.',
            ),
          ],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Night Moisturizer',
          steps: ['Apply moisturizer after serum'],
          productNames: ['Barrier Repair Lotion'],
          missingItems: [
            SkinCareMissingItem(
              name: 'Cleanser',
              importance: 'important',
              reason: 'Needed before applying leave-on products.',
            ),
          ],
        ),
      ],
      now: DateTime.utc(2026, 6, 15),
    );
    expect(missingBasics.errorMessage, isNull);
    expect(
      missingBasics.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'morning')
          .skincareMissingItems,
      ['Sunscreen (important, missing)', 'Cleanser (important, missing)'],
    );
    expect(
      missingBasics.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'night')
          .skincareMissingItems,
      ['Cleanser (important, missing)'],
    );
    expect(
      missingBasics.blocks
          .expand((block) => block.skincareProducts)
          .toList(growable: false),
      isNot(contains('Sunscreen')),
    );
    expect(
      missingBasics.blocks
          .expand((block) => block.skincareProducts)
          .toList(growable: false),
      isNot(contains('Cleanser')),
    );

    expect(
      onboarding7MissingBasicProductNotes(
        productNames: const ['Beardo Detan Face Wash', 'Minimalist SPF 50'],
        productDetails: const [],
      ),
      contains(
        'No moisturizer detected. You can still use your current products, but adding moisturizer may improve night routine balance.',
      ),
    );
    expect(
      onboarding7MissingBasicProductNotes(
        productNames: const ['Beardo Detan Face Wash', 'Barrier Repair Lotion'],
        productDetails: const [],
      ),
      contains(
        'No sunscreen detected. Consider adding SPF for daytime protection.',
      ),
    );

    final unownedProduct = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 2,
      ownedProductNames: const ['Daily Sunscreen'],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Unowned toner',
          steps: ['Apply toner'],
          productNames: ['Unowned Toner'],
        ),
      ],
      now: DateTime.utc(2026, 6, 15),
    );
    expect(unownedProduct.blocks, isEmpty);
    expect(unownedProduct.errorMessage, productMismatchMessage);

    final outsideBrandProduct = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 2,
      ownedProductNames: const ['Minimalist SPF 50'],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Outside Brand',
          steps: ['Apply sunscreen'],
          productNames: ['La Roche-Posay Anthelios Sunscreen'],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Outside Brand Night',
          steps: ['Apply moisturizer'],
          productNames: ['CeraVe Moisturizing Cream'],
        ),
      ],
      now: DateTime.utc(2026, 6, 15),
    );
    expect(outsideBrandProduct.blocks, isEmpty);
    expect(outsideBrandProduct.errorMessage, productMismatchMessage);

    final titleOnly = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 2,
      ownedProductNames: const ['Daily Sunscreen'],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning Skin Care',
          steps: [],
          productNames: [],
        ),
      ],
    );
    expect(titleOnly.blocks, isEmpty);
    expect(titleOnly.errorMessage, noRoutineMessage);

    final threePerDayWithFewer = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 3,
      ownedProductNames: const ['Gentle Cleanser', 'Daily Sunscreen'],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning AI',
          steps: ['Apply sunscreen'],
          productNames: ['Daily Sunscreen'],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Night AI',
          steps: ['Cleanse'],
          productNames: ['Gentle Cleanser'],
        ),
      ],
      now: DateTime.utc(2026, 6, 15),
    );
    expect(threePerDayWithFewer.blocks, isEmpty);
    expect(threePerDayWithFewer.errorMessage, fewerRoutinesMessage);

    final ambiguousSerum = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 2,
      ownedProductNames: const [
        'Minimalist Vitamin C',
        'Minimalist Alpha Arbutin',
      ],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning Serum',
          steps: ['Apply serum'],
          productNames: ['serum'],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Night Serum',
          steps: ['Apply serum'],
          productNames: ['serum'],
        ),
      ],
    );
    expect(ambiguousSerum.blocks, isEmpty);
    expect(ambiguousSerum.errorMessage, productMismatchMessage);

    final aiReturnedFewerRoutines = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 3,
      ownedProductNames: const ['Cleanse', 'Protect'],
      ownedProductDetails: const [],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning SPF',
          productNames: ['Cleanse', 'Protect'],
          steps: ['Cleanse', 'Protect'],
          warnings: ['ai_returned_fewer_routines'],
        ),
      ],
    );
    expect(aiReturnedFewerRoutines.blocks, isEmpty);
    expect(aiReturnedFewerRoutines.errorMessage, fewerRoutinesMessage);
  });

  testWidgets(
    '58. No-products discovery requires face photo and skin details',
    (tester) async {
      useAndroidWidth(tester);
      final uploadController = TestUploadController(result: _uploadedAsset());
      await tester.pumpWidget(
        buildTestWidget(
          draft: _noProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          uploadController: uploadController,
        ),
      );
      await tester.pumpAndSettle();

      GestureDetector generateGesture() => tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.byKey(
                const ValueKey('onboarding-step7-generate-button'),
              ),
              matching: find.byType(GestureDetector),
            )
            .first,
      );

      expect(generateGesture().onTap, isNull);
      expect(find.text('Face photo required'), findsOneWidget);
      expect(
        find.textContaining('Add a face photo and choose skin type'),
        findsOneWidget,
      );

      await tester.tap(find.text('Oily'));
      await tester.tap(find.text('Acne'));
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();

      expect(generateGesture().onTap, isNull);
      await chooseSkinPhotoFromGallery(tester);
      expect(generateGesture().onTap, isNotNull);
      expect(find.text('Find products'), findsOneWidget);
    },
  );

  testWidgets(
    '59. No-products uses location-aware selection then the real scheduler',
    (tester) async {
      useAndroidWidth(tester);
      final client = TestSkinCareAiClient(
        routineResultsQueue: [
          _productRecommendationResult(),
          _selectedProductRoutineResult(),
        ],
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _noProductsDraft(
            skinType: 'oily',
            problems: const ['pimples'],
            budget: 'medium',
            withPhoto: true,
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
          regionSettings: RegionSettings.india(
            userId: 'uid-1',
          ).copyWith(source: RegionSource.deviceDetected),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find products'));
      await tester.pumpAndSettle();

      expect(client.generateCalls, hasLength(1));
      expect(client.generateCalls.first['recommendationOnly'], isTrue);
      expect(client.generateCalls.first['countryCode'], 'IN');
      expect(client.generateCalls.first['countryName'], 'India');
      expect(client.generateCalls.first['currencyCode'], 'INR');
      expect(find.text('Build skin routine'), findsOneWidget);

      await _selectCoreRecommendedProducts(tester);
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      expect(client.generateCalls, hasLength(2));
      expect(client.generateCalls.last['productInputSource'], 'typed');
      expect(client.generateCalls.last['typedProductDetails'], hasLength(3));

      final base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(onboardingStateProvider).draft.baseTimeline;
      final blocks = base.confirmedBlocksForSection('skin_care');
      expect(blocks, hasLength(2));
      expect(
        blocks.any((block) => block.title == 'Wrong worker time'),
        isFalse,
      );
      expect(
        blocks
            .singleWhere((block) => block.skincareSlotLabel == 'morning')
            .startMinute,
        greaterThanOrEqualTo(BaseTimelineDraft.defaultBathBlock().endMinute),
      );
      expect(base.skinCareSuggestedProducts, [
        'Minimalist Gentle Cleanser',
        'Minimalist Barrier Moisturizer',
        'Minimalist SPF 50 Sunscreen',
      ]);
      expect(base.skinCareSpecialCareNotes, [
        'Patch test Minimalist Gentle Cleanser first',
      ]);
      expect(base.skinCareFacePhotoSkipped, isFalse);
      expect(client.generateCalls.last, isNot(contains('facePhotoR2Key')));
      expect(client.lastGenerateParams?['desiredApplicationsPerDay'], 2);
      expect(find.text('Skin Care Routine'), findsOneWidget);
      expect(find.text('Review your weekly routine'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('onboarding-step7-full-timeline')),
        findsOneWidget,
      );
      expect(onboarding7CanContinue(base, 'uid-1'), isTrue);
    },
  );

  testWidgets('60. No-products recommendations stop at product selection', (
    tester,
  ) async {
    useAndroidWidth(tester);
    final client = TestSkinCareAiClient(
      routineResultsQueue: [
        _productRecommendationResult(),
        _routineResultWithPlanCount(3),
      ],
    );
    await tester.pumpWidget(
      buildTestWidget(
        draft: _noProductsDraft(
          skinType: 'combination',
          problems: const ['dryness'],
          budget: 'low',
          withPhoto: true,
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Find products'));
    await tester.pumpAndSettle();

    var base = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    ).read(onboardingStateProvider).draft.baseTimeline;
    expect(client.generateCalls, hasLength(1));
    expect(client.generateCalls.single['recommendationOnly'], isTrue);
    expect(base.skinCareProductRecommendations, hasLength(5));
    expect(base.skinCareSelectedProductNames, isEmpty);
    expect(base.confirmedBlocksForSection('skin_care'), isEmpty);
    expect(find.text('Build skin routine'), findsOneWidget);
    expect(find.text('Skin Care Routine'), findsNothing);

    await _selectCoreRecommendedProducts(tester);
    await tester.tap(find.text('Build skin routine'));
    await tester.pumpAndSettle();

    base = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    ).read(onboardingStateProvider).draft.baseTimeline;
    expect(client.generateCalls, hasLength(2));
    expect(base.skinCareSelectedProductNames, hasLength(3));
    expect(base.confirmedBlocksForSection('skin_care'), isNotEmpty);
    expect(find.text('Skin Care Routine'), findsOneWidget);
    expect(find.text('Review your weekly routine'), findsOneWidget);
  });

  testWidgets(
    '60b. Routine retry reuses retained recommendations without face analysis',
    (tester) async {
      useAndroidWidth(tester);
      final client = TestSkinCareAiClient(
        routineResultsQueue: [
          _productRecommendationResult(),
          SkinCareAiRoutineResult.error(
            'AI is busy right now. Try again in a moment.',
            errorCode: 'provider_high_demand',
          ),
          _selectedProductRoutineResult(),
        ],
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _noProductsDraft(
            skinType: 'oily',
            problems: const ['pimples'],
            budget: 'medium',
            withPhoto: true,
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find products'));
      await tester.pumpAndSettle();

      expect(client.generateCalls, hasLength(1));
      await _selectCoreRecommendedProducts(tester);
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      expect(client.generateCalls, hasLength(2));
      expect(find.text('Retry routine'), findsOneWidget);
      expect(find.textContaining('Products are ready'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      expect(
        container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .skinCareProductRecommendations,
        isNotEmpty,
      );

      await tester.ensureVisible(find.text('Retry routine'));
      await tester.tap(find.text('Retry routine'));
      await tester.pumpAndSettle();

      expect(client.generateCalls, hasLength(3));
      expect(
        client.generateCalls.where(
          (call) => call['recommendationOnly'] == true,
        ),
        hasLength(1),
      );
      expect(find.text('Skin Care Routine'), findsOneWidget);
      expect(find.text('Review your weekly routine'), findsOneWidget);
    },
  );

  testWidgets('60c. Recommendation retry reruns only recommendation stage', (
    tester,
  ) async {
    useAndroidWidth(tester);
    final client = TestSkinCareAiClient(
      routineResultsQueue: [
        SkinCareAiRoutineResult.error(
          'AI is busy right now. Try again in a moment.',
          errorCode: 'provider_high_demand',
        ),
        _productRecommendationResult(),
        _selectedProductRoutineResult(),
      ],
    );
    await tester.pumpWidget(
      buildTestWidget(
        draft: _noProductsDraft(
          skinType: 'oily',
          problems: const ['pimples'],
          budget: 'medium',
          withPhoto: true,
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Find products'));
    await tester.pumpAndSettle();
    expect(find.text('Retry recommendation'), findsOneWidget);
    expect(client.generateCalls, hasLength(1));

    await tester.tap(find.text('Retry recommendation'));
    await tester.pumpAndSettle();
    expect(client.generateCalls, hasLength(2));
    expect(find.text('Build skin routine'), findsOneWidget);
    expect(find.text('Skin Care Routine'), findsNothing);

    await _selectCoreRecommendedProducts(tester);
    await tester.tap(find.text('Build skin routine'));
    await tester.pumpAndSettle();

    expect(client.generateCalls, hasLength(3));
    expect(find.text('Skin Care Routine'), findsOneWidget);
    expect(find.text('Review your weekly routine'), findsOneWidget);
  });

  testWidgets(
    '61. No-products face photo persists, restores, reaches AI, and deletes',
    (tester) async {
      useAndroidWidth(tester);
      final asset = _uploadedAsset();
      final uploadController = TestUploadController(result: asset);
      final client = TestSkinCareAiClient(
        routineResultsQueue: [
          _productRecommendationResult(),
          _selectedProductRoutineResult(),
        ],
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _noProductsDraft(
            uid: 'uid-1',
            skinType: 'dry',
            problems: const ['dryness'],
            budget: 'medium',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
          uploadController: uploadController,
        ),
      );
      await tester.pumpAndSettle();

      await chooseSkinPhotoFromGallery(tester);
      var base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(onboardingStateProvider).draft.baseTimeline;
      expect(base.skinCareFacePhotoAssetId, asset.assetId);
      expect(base.skinCareFacePhotoR2Key, asset.r2Key);

      await tester.tap(find.text('Find products'));
      await tester.pumpAndSettle();
      expect(client.generateCalls.first['facePhotoR2Key'], asset.r2Key);
      await _selectCoreRecommendedProducts(tester);
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();
      base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(onboardingStateProvider).draft.baseTimeline;
      expect(base.skinCareFacePhotoSkipped, isFalse);

      triggerRebuild(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change details'));
      await tester.pumpAndSettle();
      expect(find.text('Photo uploaded'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-remove-photo-button')),
      );
      await tester.pumpAndSettle();

      base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(onboardingStateProvider).draft.baseTimeline;
      expect(base.skinCareFacePhotoR2Key, isNull);
      expect(uploadController.markDeletedCalls, 1);
    },
  );

  testWidgets(
    '62. No-products rebuild preserves the valid routine until replacement',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: _routineResultWithPlanCount(2),
      );
      await tester.pumpWidget(
        buildTestWidget(
          draft: _noProductsDraft(
            skinType: 'not_sure',
            problems: const ['none'],
            budget: 'medium',
            suggestedProducts: _productRecommendationDraftsForTest()
                .take(3)
                .map((p) => p.displayName)
                .toList(),
            recommendations: _productRecommendationDraftsForTest(),
            selectedProducts: _productRecommendationDraftsForTest()
                .take(3)
                .map((p) => p.displayName)
                .toList(),
            withPhoto: true,
            blocks: [
              BaseTimelineDraft.defaultBathBlock(),
              ..._skinCareBlocksForEveryDay(2),
            ],
          ),
          client: client,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final originalIds = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care')
          .map((block) => block.id)
          .toList();

      triggerRebuild(tester);
      await tester.pumpAndSettle();
      final editingBase = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline;
      expect(
        editingBase
            .confirmedBlocksForSection('skin_care')
            .map((block) => block.id)
            .toList(),
        originalIds,
      );
      expect(editingBase.skinCareSuggestedProducts, hasLength(3));
      expect(editingBase.skinCareSelectedProductNames, hasLength(3));

      container.read(skinCareFlowControllerProvider.notifier).cancelEditing();
      await tester.pumpAndSettle();
      expect(find.text('Skin Care Routine'), findsOneWidget);
      expect(find.text('Review your weekly routine'), findsOneWidget);
    },
  );

  test('63. No-products validation rejects incomplete daily coverage', () {
    final base = _noProductsDraft(
      skinType: 'oily',
      problems: const ['pimples'],
      budget: 'medium',
      desiredApplicationsPerDay: 2,
      suggestedProducts: const ['Minimalist Gentle Cleanser'],
      selectedProducts: _productRecommendationDraftsForTest()
          .map((p) => p.displayName)
          .toList(),
      recommendations: _productRecommendationDraftsForTest(),
      withPhoto: true,
      blocks: _skinCareBlocksForEveryDay(1),
    ).baseTimeline;

    expect(onboarding7CanContinue(base, 'uid-1'), isFalse);
    expect(base.validateSkinCareSetup('uid-1'), contains('1 of 2'));
  });

  test('64. Product options and selections survive draft serialization', () {
    const base = BaseTimelineDraft(
      skinCareSetupPath: 'no_products',
      skinCareSuggestedProducts: ['Gentle Cleanser', 'Daily SPF 50'],
      skinCareSelectedProductNames: ['Minimalist Gentle Cleanser'],
      skinCareProductRecommendations: [
        SkinCareProductRecommendationDraft(
          name: 'Gentle Cleanser',
          brand: 'Minimalist',
          category: 'cleanser',
          estimatedPrice: '299',
          currencyCode: 'INR',
          reason: 'Useful and affordable',
        ),
      ],
    );

    final restored = BaseTimelineDraft.fromMap(base.toMap());
    expect(restored.skinCareSuggestedProducts, [
      'Gentle Cleanser',
      'Daily SPF 50',
    ]);
    expect(restored.skinCareSelectedProductNames, [
      'Minimalist Gentle Cleanser',
    ]);
    expect(restored.skinCareProductRecommendations.single.brand, 'Minimalist');
    expect(
      restored.skinCareProductRecommendations.single.estimatedPrice,
      '299',
    );
  });

  testWidgets('65. Incomplete or unpriced AI recommendations are rejected', (
    tester,
  ) async {
    useAndroidWidth(tester);
    final client = TestSkinCareAiClient(
      routineResult: const SkinCareAiRoutineResult(
        morningRoutine: [],
        nightRoutine: [],
        weeklyRoutine: [],
        timelineBlocks: [],
        recommendedProducts: [
          SkinCareProductRecommendation(
            name: 'Gentle Cleanser',
            brand: 'Minimalist',
            category: 'cleanser',
            estimatedPrice: '299',
            currencyCode: 'INR',
            reason: 'Affordable cleanser',
          ),
          SkinCareProductRecommendation(
            name: 'Unnamed price product',
            brand: 'Example Brand',
            category: 'moisturizer',
            reason: 'Missing price must be rejected',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      buildTestWidget(
        draft: _noProductsDraft(
          skinType: 'oily',
          problems: const ['pimples'],
          budget: 'low',
          withPhoto: true,
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Find products'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('complete branded cleanser, moisturizer'),
      findsOneWidget,
    );
    final base = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    ).read(onboardingStateProvider).draft.baseTimeline;
    expect(base.skinCareProductRecommendations, isEmpty);
    expect(find.textContaining('Choose products available'), findsNothing);
  });

  testWidgets(
    '66. Changing rebuild details keeps the last valid routine active',
    (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          draft: _noProductsDraft(
            skinType: 'oily',
            problems: const ['pimples'],
            budget: 'medium',
            suggestedProducts: const [
              'Minimalist Gentle Cleanser',
              'Minimalist Barrier Moisturizer',
              'Minimalist SPF 50 Sunscreen',
            ],
            recommendations: _productRecommendationDraftsForTest(),
            selectedProducts: const [
              'Minimalist Gentle Cleanser',
              'Minimalist Barrier Moisturizer',
              'Minimalist SPF 50 Sunscreen',
            ],
            withPhoto: true,
            blocks: [
              BaseTimelineDraft.defaultBathBlock(),
              ..._skinCareBlocksForEveryDay(2),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );

      triggerRebuild(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      var base = container.read(onboardingStateProvider).draft.baseTimeline;
      expect(base.skinCareSuggestedProducts, hasLength(3));
      expect(base.confirmedBlocksForSection('skin_care'), isNotEmpty);
      expect(onboarding7CanContinue(base, 'uid-1'), isFalse);

      container.read(skinCareFlowControllerProvider.notifier).cancelEditing();
      await tester.pumpAndSettle();
      base = container.read(onboardingStateProvider).draft.baseTimeline;
      expect(find.text('Skin Care Routine'), findsOneWidget);
      expect(find.text('Review your weekly routine'), findsOneWidget);
      expect(onboarding7CanContinue(base, 'uid-1'), isTrue);
      expect(base.isSkinCareRoutineCurrent('uid-1'), isTrue);
    },
  );

  test('67. Essential selection helper requires only the three core items', () {
    final products = _productRecommendationDraftsForTest();
    expect(
      onboarding7MissingEssentialRecommendationCategories(products),
      isEmpty,
    );
    expect(
      onboarding7MissingEssentialRecommendationCategories(
        products,
        selectedProductNames: const ['Minimalist Gentle Cleanser'],
      ),
      ['moisturizer', 'sunscreen'],
    );
  });

  testWidgets('68. Product discovery shows an active AI loading state', (
    tester,
  ) async {
    useAndroidWidth(tester);
    final client = TestSkinCareAiClient(
      routineResultsQueue: [
        _productRecommendationResult(),
        _routineResultWithPlanCount(3),
      ],
    );
    await tester.pumpWidget(
      buildTestWidget(
        draft: _noProductsDraft(
          skinType: 'oily',
          problems: const ['pimples'],
          budget: 'medium',
          withPhoto: true,
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Find products'));
    await tester.pump();

    expect(find.textContaining('Skin Care AI'), findsOneWidget);
    expect(
      find.text('Finding useful products available in India'),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    expect(find.text('Build skin routine'), findsOneWidget);
    expect(find.text('Skin Care Routine'), findsNothing);
  });

  testWidgets('69. Final no-products build reuses the routine loading state', (
    tester,
  ) async {
    useAndroidWidth(tester);
    final completer = Completer<SkinCareAiRoutineResult>();
    final client = TestSkinCareAiClient(routineCompleter: completer);
    await tester.pumpWidget(
      buildTestWidget(
        draft: _noProductsDraft(
          skinType: 'oily',
          problems: const ['pimples'],
          budget: 'medium',
          recommendations: _productRecommendationDraftsWithAlternatives(),
          selectedProducts: const [
            'Minimalist Gentle Cleanser',
            'Minimalist Barrier Moisturizer',
            'Minimalist SPF 50 Sunscreen',
            'Minimalist 10% Vitamin C Serum',
            'Minimalist 5% Niacinamide Serum',
          ],
          withPhoto: true,
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    final buildButton = find.byKey(
      const ValueKey('onboarding-step7-generate-button'),
    );
    await tester.ensureVisible(buildButton);
    await tester.tap(buildButton);
    await tester.pump();

    expect(find.textContaining('Skin Care AI'), findsOneWidget);
    expect(
      find.text('Building your routine from product names and labels'),
      findsOneWidget,
    );

    completer.complete(_selectedProductRoutineResult());
    await tester.pumpAndSettle();
    expect(find.text('Skin Care Routine'), findsOneWidget);
    expect(find.text('Review your weekly routine'), findsOneWidget);
  });

  testWidgets(
    '69b. Disposing during recommendation prevents stale draft mutation',
    (tester) async {
      useAndroidWidth(tester);
      final completer = Completer<SkinCareAiRoutineResult>();
      final client = TestSkinCareAiClient(routineCompleter: completer);
      final showStep = ValueNotifier(true);
      addTearDown(showStep.dispose);
      await tester.pumpWidget(
        buildTestWidget(
          draft: _noProductsDraft(
            skinType: 'oily',
            problems: const ['pimples'],
            budget: 'medium',
            withPhoto: true,
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
          showStep: showStep,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      await tester.tap(find.text('Find products'));
      await tester.pump(const Duration(milliseconds: 100));
      showStep.value = false;
      await tester.pump();
      completer.complete(_productRecommendationResult());
      await tester.pump();

      expect(
        container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .skinCareProductRecommendations,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '69c. Disposing during routine generation prevents stale schedule insertion',
    (tester) async {
      useAndroidWidth(tester);
      final completer = Completer<SkinCareAiRoutineResult>();
      final client = TestSkinCareAiClient(routineCompleter: completer);
      final showStep = ValueNotifier(true);
      addTearDown(showStep.dispose);
      await tester.pumpWidget(
        buildTestWidget(
          draft: _noProductsDraft(
            skinType: 'oily',
            problems: const ['pimples'],
            budget: 'medium',
            recommendations: _productRecommendationDraftsWithAlternatives(),
            selectedProducts: const [
              'Minimalist Gentle Cleanser',
              'Minimalist Barrier Moisturizer',
              'Minimalist SPF 50 Sunscreen',
            ],
            withPhoto: true,
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
          showStep: showStep,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final buildButton = find.byKey(
        const ValueKey('onboarding-step7-generate-button'),
      );
      await tester.ensureVisible(buildButton);
      await tester.tap(buildButton);
      await tester.pump(const Duration(milliseconds: 100));
      showStep.value = false;
      await tester.pump();
      completer.complete(_selectedProductRoutineResult());
      await tester.pump();

      expect(
        container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .confirmedBlocksForSection('skin_care'),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '69d. Has-products shell Back during delayed AI exits thinking and ignores late routine',
    (tester) async {
      useAndroidWidth(tester);
      final completer = Completer<SkinCareAiRoutineResult>();
      final client = TestSkinCareAiClient(routineCompleter: completer);
      final draft = _hasProductsDraft(
        uid: 'test-uid',
        blocks: _skinCareBlocksForEveryDay(2),
        includePrerequisites: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier()),
            onboardingStateProvider.overrideWith(
              (_) => OnboardingNotifier()..loadSeedData(draft),
            ),
            skinCareAiClientProvider.overrideWithValue(client),
            onboardingUploadInteractionProvider.overrideWith(
              (_) => TestUploadInteractionController(),
            ),
            deviceCountryServiceProvider.overrideWithValue(
              const TestDeviceCountryService(null),
            ),
          ],
          child: const MaterialApp(home: OnboardingFlow()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('onboarding-step7-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final buildButton = find.byKey(
        const ValueKey('onboarding-step7-generate-button'),
      );
      await tester.ensureVisible(buildButton);
      await tester.tap(buildButton);
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingFlow)),
      );
      expect(find.textContaining('Skin Care AI'), findsOneWidget);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.hasProductsGenerating,
      );
      expect(
        container
            .read(onboardingStateProvider)
            .stepLoading[onboardingSkinCareStepIndex],
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('onboarding-step7-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Skin Care AI'), findsNothing);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.hasProductsEditing,
      );
      expect(
        container
            .read(onboardingStateProvider)
            .stepLoading[onboardingSkinCareStepIndex],
        isFalse,
      );
      expect(
        container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .confirmedBlocksForSection('skin_care')
            .map((block) => block.title),
        ['Morning Skin Care', 'Night Skin Care'],
      );

      completer.complete(_routineResultWithPlanCount(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      expect(
        base.confirmedBlocksForSection('skin_care').map((block) => block.title),
        ['Morning Skin Care', 'Night Skin Care'],
      );
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.hasProductsEditing,
      );
      expect(find.textContaining('Skin Care AI'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '69e. No-products Find-products Back exits thinking and ignores late recommendations',
    (tester) async {
      useAndroidWidth(tester);
      final completer = Completer<SkinCareAiRoutineResult>();
      final client = TestSkinCareAiClient(routineCompleter: completer);
      final draft = _noProductsDraft(
        uid: 'test-uid',
        recommendations: _productRecommendationDraftsWithAlternatives(),
        selectedProducts: const [
          'Minimalist Gentle Cleanser',
          'Minimalist Barrier Moisturizer',
          'Minimalist SPF 50 Sunscreen',
        ],
        withPhoto: true,
        blocks: _skinCareBlocksForEveryDay(2),
        includePrerequisites: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier()),
            onboardingStateProvider.overrideWith(
              (_) => OnboardingNotifier()..loadSeedData(draft),
            ),
            skinCareAiClientProvider.overrideWithValue(client),
            onboardingUploadInteractionProvider.overrideWith(
              (_) => TestUploadInteractionController(),
            ),
            deviceCountryServiceProvider.overrideWithValue(
              const TestDeviceCountryService(null),
            ),
          ],
          child: const MaterialApp(home: OnboardingFlow()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('onboarding-step7-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Change details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Find products'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingFlow)),
      );
      expect(find.textContaining('Skin Care AI'), findsOneWidget);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.noProductsFindingProducts,
      );

      await tester.tap(find.byKey(const ValueKey('onboarding-step7-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Skin Care AI'), findsNothing);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.noProductsEditing,
      );
      expect(
        container
            .read(onboardingStateProvider)
            .stepLoading[onboardingSkinCareStepIndex],
        isFalse,
      );

      completer.complete(_productRecommendationResult());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      expect(
        base.confirmedBlocksForSection('skin_care').map((block) => block.title),
        ['Morning Skin Care', 'Night Skin Care'],
      );
      expect(base.skinCareProductRecommendations, isEmpty);
      expect(find.textContaining('Skin Care AI'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '69f. No-products routine-build Back exits thinking and ignores late Plan B',
    (tester) async {
      useAndroidWidth(tester);
      final completer = Completer<SkinCareAiRoutineResult>();
      final client = TestSkinCareAiClient(routineCompleter: completer);
      final draft = _noProductsDraft(
        uid: 'test-uid',
        recommendations: _productRecommendationDraftsWithAlternatives(),
        selectedProducts: const [
          'Minimalist Gentle Cleanser',
          'Minimalist Barrier Moisturizer',
          'Minimalist SPF 50 Sunscreen',
        ],
        withPhoto: true,
        blocks: _skinCareBlocksForEveryDay(2),
        includePrerequisites: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier()),
            onboardingStateProvider.overrideWith(
              (_) => OnboardingNotifier()..loadSeedData(draft),
            ),
            skinCareAiClientProvider.overrideWithValue(client),
            onboardingUploadInteractionProvider.overrideWith(
              (_) => TestUploadInteractionController(),
            ),
            deviceCountryServiceProvider.overrideWithValue(
              const TestDeviceCountryService(null),
            ),
          ],
          child: const MaterialApp(home: OnboardingFlow()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('onboarding-step7-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final buildButton = find.byKey(
        const ValueKey('onboarding-step7-generate-button'),
      );
      await tester.ensureVisible(buildButton);
      await tester.tap(buildButton);
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingFlow)),
      );
      expect(find.textContaining('Skin Care AI'), findsOneWidget);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.noProductsGeneratingRoutine,
      );

      await tester.tap(find.byKey(const ValueKey('onboarding-step7-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Skin Care AI'), findsNothing);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.noProductsEditing,
      );
      expect(
        container
            .read(onboardingStateProvider)
            .stepLoading[onboardingSkinCareStepIndex],
        isFalse,
      );

      completer.complete(_selectedProductRoutineResult());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      expect(
        base.confirmedBlocksForSection('skin_care').map((block) => block.title),
        ['Morning Skin Care', 'Night Skin Care'],
      );
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.noProductsEditing,
      );
      expect(find.textContaining('Skin Care AI'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '69g. Delayed has-products upload after shell Back cannot mutate restored Plan A',
    (tester) async {
      useAndroidWidth(tester);
      final upload = DelayedTestUploadInteractionController(
        result: _uploadedAsset().copyWith(
          assetId: 'replacement-products',
          r2Key: 'users/test-uid/onboarding/skin_care/replacement-products.jpg',
        ),
      );
      final draft = _hasProductsDraft(
        uid: 'test-uid',
        productPhotoAssetId: 'plan-a-products',
        productPhotoR2Key: 'users/test-uid/onboarding/skin_care/plan-a.jpg',
        productPhotoStatus: 'uploaded',
        productPhotoCreatedAt: DateTime.utc(2026, 6, 14, 10),
        productPhotoUpdatedAt: DateTime.utc(2026, 6, 14, 10),
        blocks: _skinCareBlocksForEveryDay(2),
        includePrerequisites: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier()),
            onboardingStateProvider.overrideWith(
              (_) => OnboardingNotifier()..loadSeedData(draft),
            ),
            skinCareAiClientProvider.overrideWithValue(
              const FakeSkinCareAiClient(),
            ),
            onboardingUploadInteractionProvider.overrideWith((_) => upload),
            deviceCountryServiceProvider.overrideWithValue(
              const TestDeviceCountryService(null),
            ),
          ],
          child: const MaterialApp(home: OnboardingFlow()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('onboarding-step7-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Add photo').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-choose-gallery')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingFlow)),
      );
      expect(upload.startUploadCalls, 1);
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.hasProductsEditing,
      );

      await tester.tap(find.byKey(const ValueKey('onboarding-step7-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        container.read(skinCareFlowControllerProvider).state,
        SkinCareFlowState.choice,
      );

      upload.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      expect(base.skinCareProductPhotoAssetId, 'plan-a-products');
      expect(base.skinCareProductPhotoR2Key, contains('/plan-a.jpg'));
      expect(
        base.confirmedBlocksForSection('skin_care').map((block) => block.title),
        ['Morning Skin Care', 'Night Skin Care'],
      );
      expect(find.text('Next Step'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '69h. Delayed no-products upload after shell Back cannot mutate restored Plan A',
    (tester) async {
      useAndroidWidth(tester);
      final upload = DelayedTestUploadInteractionController(
        result: _uploadedAsset(purpose: UploadedAssetPurpose.skinFace).copyWith(
          assetId: 'replacement-face',
          r2Key: 'users/test-uid/onboarding/skin_care/replacement-face.jpg',
        ),
      );
      final draft = _noProductsDraft(
        uid: 'test-uid',
        recommendations: _productRecommendationDraftsWithAlternatives(),
        selectedProducts: const [
          'Minimalist Gentle Cleanser',
          'Minimalist Barrier Moisturizer',
          'Minimalist SPF 50 Sunscreen',
        ],
        photoAssetId: 'plan-a-face',
        photoR2Key: 'users/test-uid/onboarding/skin_care/plan-a-face.jpg',
        photoStatus: 'uploaded',
        photoCreatedAt: DateTime.utc(2026, 6, 14, 10),
        photoUpdatedAt: DateTime.utc(2026, 6, 14, 10),
        blocks: _skinCareBlocksForEveryDay(2),
        includePrerequisites: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier()),
            onboardingStateProvider.overrideWith(
              (_) => OnboardingNotifier()..loadSeedData(draft),
            ),
            skinCareAiClientProvider.overrideWithValue(
              const FakeSkinCareAiClient(),
            ),
            onboardingUploadInteractionProvider.overrideWith((_) => upload),
            deviceCountryServiceProvider.overrideWithValue(
              const TestDeviceCountryService(null),
            ),
          ],
          child: const MaterialApp(home: OnboardingFlow()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('onboarding-step7-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Change details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-photo-tile')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-choose-gallery')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingFlow)),
      );
      expect(upload.startUploadCalls, 1);

      await tester.tap(find.byKey(const ValueKey('onboarding-step7-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      upload.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final base = container.read(onboardingStateProvider).draft.baseTimeline;
      expect(base.skinCareFacePhotoAssetId, 'plan-a-face');
      expect(base.skinCareFacePhotoR2Key, contains('/plan-a-face.jpg'));
      expect(
        base.confirmedBlocksForSection('skin_care').map((block) => block.title),
        ['Morning Skin Care', 'Night Skin Care'],
      );
      expect(find.text('Next Step'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '69i. User-A delayed upload cannot bind into User-B Step-7 draft',
    (tester) async {
      useAndroidWidth(tester);
      final auth = FakeAuthNotifier();
      final onboarding = OnboardingNotifier()
        ..loadSeedData(
          _hasProductsDraft(
            uid: 'test-uid',
            productPhotoAssetId: 'user-a-plan-a',
            productPhotoR2Key:
                'users/test-uid/onboarding/skin_care/user-a-plan-a.jpg',
            productPhotoStatus: 'uploaded',
            blocks: _skinCareBlocksForEveryDay(2),
            includePrerequisites: true,
          ),
        );
      final upload = DelayedTestUploadInteractionController(
        result: _uploadedAsset().copyWith(
          assetId: 'user-a-replacement',
          r2Key: 'users/test-uid/onboarding/skin_care/user-a-replacement.jpg',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => auth),
            onboardingStateProvider.overrideWith((_) => onboarding),
            skinCareAiClientProvider.overrideWithValue(
              const FakeSkinCareAiClient(),
            ),
            onboardingUploadInteractionProvider.overrideWith((_) => upload),
            deviceCountryServiceProvider.overrideWithValue(
              const TestDeviceCountryService(null),
            ),
          ],
          child: const MaterialApp(home: OnboardingFlow()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('onboarding-step7-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-photo-tile')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-choose-gallery')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      auth.setTestUser(
        const AuthUser(
          uid: 'user-b',
          email: 'b@example.com',
          emailVerified: true,
        ),
      );
      onboarding.loadSeedData(
        _hasProductsDraft(
          uid: 'user-b',
          productNames: 'User B Cleanser',
          includePrerequisites: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      upload.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final draft = onboarding.state.draft;
      expect(draft.uid, 'user-b');
      expect(draft.baseTimeline.skinCareProductPhotoAssetId, isNull);
      expect(draft.baseTimeline.skinCareProductPhotoR2Key, isNull);
      expect(
        draft.baseTimeline.skinCareProductNames,
        isNot(contains('user-a-replacement')),
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('70. Sun cream is sunscreen and not moisturizer', () {
    final result = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: BaseTimelineDraft(
        blocks: [BaseTimelineDraft.defaultBathBlock()],
      ),
      desiredApplicationsPerDay: 3,
      ownedProductNames: const [
        'Gentle Cleanser',
        'Sun Cream SPF 50',
        'Barrier Repair Moisturizer',
      ],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning Skin Care',
          steps: ['Apply sun cream'],
          productNames: ['Sun Cream SPF 50'],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'midday',
          title: 'Midday Skin Care',
          steps: ['Reapply sun cream'],
          productNames: ['Sun Cream SPF 50'],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Night Skin Care',
          steps: ['Cleanse'],
          productNames: ['Gentle Cleanser'],
        ),
      ],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.errorMessage, isNull);
    expect(
      result.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'morning')
          .skincareProducts,
      ['Sun Cream SPF 50'],
    );
    expect(
      result.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'midday')
          .skincareProducts,
      ['Sun Cream SPF 50'],
    );
    expect(
      result.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'night')
          .skincareProducts,
      ['Gentle Cleanser'],
    );
  });

  testWidgets('71. No-products exposes and forwards 2 or 3 times per day', (
    tester,
  ) async {
    useAndroidWidth(tester);
    final client = TestSkinCareAiClient(
      routineResultsQueue: [
        _productRecommendationResult(),
        _routineResultWithPlanCount(3),
      ],
    );
    await tester.pumpWidget(
      buildTestWidget(
        draft: _noProductsDraft(
          skinType: 'oily',
          problems: const ['pimples'],
          budget: 'medium',
          withPhoto: true,
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How many times per day?'), findsOneWidget);
    for (final option in const [2, 3]) {
      expect(
        find.byKey(ValueKey('onboarding-step7-frequency-$option')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey('onboarding-step7-frequency-4')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('onboarding-step7-frequency-3')),
    );
    await tester.pumpAndSettle();
    var base = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    ).read(onboardingStateProvider).draft.baseTimeline;
    expect(base.skinCareDesiredApplicationsPerDay, 3);

    await tester.ensureVisible(find.text('Find products'));
    await tester.tap(find.text('Find products'));
    await tester.pumpAndSettle();

    expect(client.generateCalls, hasLength(1));
    expect(client.generateCalls.first['desiredApplicationsPerDay'], 3);
    await _selectCoreRecommendedProducts(tester);
    await tester.tap(find.text('Build skin routine'));
    await tester.pumpAndSettle();

    expect(client.generateCalls, hasLength(2));
    expect(client.generateCalls.last['desiredApplicationsPerDay'], 3);
    expect(find.text('Skin Care Routine'), findsOneWidget);
    expect(find.text('Review your weekly routine'), findsOneWidget);
  });

  testWidgets('72. Rebuild frequency stays transactional until AI succeeds', (
    tester,
  ) async {
    useAndroidWidth(tester);
    await tester.pumpWidget(
      buildTestWidget(
        draft: _noProductsDraft(
          skinType: 'oily',
          problems: const ['pimples'],
          budget: 'medium',
          suggestedProducts: const [
            'Minimalist Gentle Cleanser',
            'Minimalist Barrier Moisturizer',
            'Minimalist SPF 50 Sunscreen',
          ],
          recommendations: _productRecommendationDraftsWithAlternatives(),
          selectedProducts: const [
            'Minimalist Gentle Cleanser',
            'Minimalist Barrier Moisturizer',
            'Minimalist SPF 50 Sunscreen',
          ],
          withPhoto: true,
          blocks: [
            BaseTimelineDraft.defaultBathBlock(),
            ..._skinCareBlocksForEveryDay(2),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );

    triggerRebuild(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Change details'));
    await tester.tap(find.text('Change details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('onboarding-step7-frequency-3')),
    );
    await tester.tap(
      find.byKey(const ValueKey('onboarding-step7-frequency-3')),
    );
    await tester.pumpAndSettle();

    var base = container.read(onboardingStateProvider).draft.baseTimeline;
    expect(base.skinCareDesiredApplicationsPerDay, 2);
    expect(onboarding7CanContinue(base, 'uid-1'), isFalse);

    container.read(skinCareFlowControllerProvider.notifier).cancelEditing();
    await tester.pumpAndSettle();
    base = container.read(onboardingStateProvider).draft.baseTimeline;
    expect(base.skinCareDesiredApplicationsPerDay, 2);
    expect(onboarding7CanContinue(base, 'uid-1'), isTrue);
    expect(find.text('Skin Care Routine'), findsOneWidget);
    expect(find.text('Changes not applied yet'), findsNothing);
    final saved = container.read(onboardingStateProvider).draft;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      buildTestWidget(draft: OnboardingDraft.fromMap(saved.toMap())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Changes not applied yet'), findsNothing);
    expect(find.text('Skin Care Routine'), findsOneWidget);
  });

  testWidgets(
    '73. Step 7 does not render top back button on choice screen, but renders it inside path',
    (tester) async {
      useAndroidWidth(tester);
      final draft = OnboardingDraft(
        currentStep: onboardingSkinCareStepIndex,
        welcomeSaved: true,
        patiencePledgeAccepted: true,
        stepCompleted: List<bool>.generate(
          OnboardingDraft.stepCount,
          (index) => index < onboardingSkinCareStepIndex,
        ),
        lifeRole: const LifeRoleDraft(
          lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
          exerciseLevel: 'moderate',
          waterIntake: 'medium',
          stressLevel: 'medium',
          sleepQuality: 'good',
        ),
        bodyBasics: const BodyBasicsDraft(
          ageRange: '25-34',
          heightCm: 175,
          weightKg: 70,
          gender: 'other',
        ),
        baseTimeline: const BaseTimelineDraft(
          eatingSetupPath: 'skip',
          blocks: [
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedSleepId,
              section: 'fixed',
              title: 'Sleep',
              startMinute: 1380,
              endMinute: 420,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              crossesMidnight: true,
            ),
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedBathId,
              section: 'fixed',
              title: 'Bath',
              startMinute: 430,
              endMinute: 460,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'meal',
              section: 'eating',
              title: 'Lunch',
              startMinute: 720,
              endMinute: 750,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier()),
            onboardingStateProvider.overrideWith(
              (_) => OnboardingNotifier()..loadSeedData(draft),
            ),
            skinCareAiClientProvider.overrideWithValue(
              const FakeSkinCareAiClient(),
            ),
            uploadControllerProvider.overrideWith(
              (ref) => TestUploadController(),
            ),
            deviceCountryServiceProvider.overrideWithValue(
              const TestDeviceCountryService(null),
            ),
          ],
          child: const MaterialApp(home: OnboardingFlow()),
        ),
      );
      await tester.pump();

      expect(
        onboardingShouldShowTopLeftBackButton(
          currentPage: onboardingSkinCareStepIndex,
          baseTimeline: const BaseTimelineDraft(skinCareSetupStep: 0),
        ),
        isFalse,
      );
      expect(
        onboardingShouldShowTopLeftBackButton(
          currentPage: onboardingSkinCareStepIndex,
          baseTimeline: const BaseTimelineDraft(skinCareSetupStep: 1),
        ),
        isTrue,
      );
      expect(find.byKey(const ValueKey('onboarding-step7-back')), findsNothing);

      await tester.tap(find.text('I have products'));
      await tester.pump(const Duration(seconds: 1));

      final backButton = find.byKey(const ValueKey('onboarding-step7-back'));
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Skin Care'), findsOneWidget);
      expect(find.text('I have products'), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-step7-back')), findsNothing);
    },
  );

  test(
    '74. Common store category labels satisfy the three core essentials',
    () {
      const recommendations = [
        SkinCareProductRecommendationDraft(
          name: 'Kind to Skin Refreshing Facial Wash',
          brand: 'Simple',
          category: 'Facial cleansing gel',
          estimatedPrice: '₹325',
          currencyCode: 'INR',
          reason: 'Gentle daily cleansing',
        ),
        SkinCareProductRecommendationDraft(
          name: 'Hydro Boost Water Gel',
          brand: 'Neutrogena',
          category: 'Daily hydrator',
          estimatedPrice: '₹450-₹550',
          currencyCode: 'INR',
          reason: 'Lightweight hydration',
        ),
        SkinCareProductRecommendationDraft(
          name: 'UV Doux Silicone Sunscreen Gel',
          brand: 'Brinton',
          category: 'UV sun protection',
          estimatedPrice: '₹700',
          currencyCode: 'INR',
          reason: 'Daily broad-spectrum protection',
        ),
        SkinCareProductRecommendationDraft(
          name: '10% Vitamin C Face Serum',
          brand: 'Minimalist',
          category: 'Brightening Vitamin C Serum',
          estimatedPrice: '₹699',
          currencyCode: 'INR',
          reason: 'Morning antioxidant support',
        ),
        SkinCareProductRecommendationDraft(
          name: '5% Niacinamide Face Serum',
          brand: 'Minimalist',
          category: 'Treatment Serum',
          estimatedPrice: '₹599',
          currencyCode: 'INR',
          reason: 'Concern-targeted night treatment',
        ),
      ];

      expect(
        onboarding7MissingEssentialRecommendationCategories(recommendations),
        isEmpty,
      );
    },
  );

  testWidgets('75. No-products details scroll without whole-form scaling', (
    tester,
  ) async {
    useAndroidWidth(tester);
    final client = TestSkinCareAiClient(
      routineResult: const SkinCareAiRoutineResult(
        morningRoutine: [],
        nightRoutine: [],
        weeklyRoutine: [],
        timelineBlocks: [],
        recommendedProducts: [
          SkinCareProductRecommendation(
            name: 'Gentle Cleanser',
            brand: 'Minimalist',
            category: 'cleanser',
            estimatedPrice: '₹299',
            currencyCode: 'INR',
            reason: 'Affordable daily cleanser',
          ),
        ],
      ),
    );
    final draft = _noProductsDraft(
      skinType: 'not_sure',
      problems: const ['pimples', 'dark_spots'],
      budget: 'medium',
      desiredApplicationsPerDay: 2,
      withPhoto: true,
      blocks: [BaseTimelineDraft.defaultBathBlock()],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingStateProvider.overrideWith(
            (_) => OnboardingNotifier()..loadSeedData(draft),
          ),
          skinCareAiClientProvider.overrideWithValue(client),
          uploadControllerProvider.overrideWith((_) => TestUploadController()),
          deviceCountryServiceProvider.overrideWithValue(
            const TestDeviceCountryService(null),
          ),
        ],
        child: MaterialApp(
          home: OnboardingStepShell(
            currentPage: onboardingSkinCareStepIndex,
            pageOffset: onboardingSkinCareStepIndex.toDouble(),
            completedSteps: List<bool>.filled(OnboardingDraft.stepCount, false),
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
            ctaEnabled: false,
            ctaLoading: false,
            child: const OnboardingStep7(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Find products'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining('complete branded cleanser, moisturizer'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(OnboardingStep7),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(find.text('Skin Care'), findsOneWidget);
    expect(find.text('Retry recommendation'), findsOneWidget);
    expect(find.text('How many times per day?'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('onboarding-step7-generate-button')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find
          .byKey(const ValueKey('onboarding-step7-generate-button'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('76. Selecting another product replaces the same category', (
    tester,
  ) async {
    useAndroidWidth(tester);
    await tester.pumpWidget(
      buildTestWidget(
        draft: _noProductsDraft(
          skinType: 'combination',
          problems: const ['pimples', 'dark_spots'],
          budget: 'medium',
          recommendations: _productRecommendationDraftsWithAlternatives(),
          selectedProducts: const [
            'Minimalist Gentle Cleanser',
            'Minimalist Barrier Moisturizer',
            'Minimalist SPF 50 Sunscreen',
          ],
          withPhoto: true,
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final name in const [
      'Simple Kind to Skin Face Wash',
      "Re'equil Ultra Matte Sunscreen Gel",
    ]) {
      final product = find.text(name);
      for (
        var attempt = 0;
        product.evaluate().isEmpty && attempt < 10;
        attempt += 1
      ) {
        await tester.drag(find.byType(ListView), const Offset(0, -180));
        await tester.pump();
      }
      expect(product, findsOneWidget, reason: name);
      await tester.ensureVisible(product);
      await tester.pump();
      await tester.tap(product);
      await tester.pump();
    }

    final base = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    ).read(onboardingStateProvider).draft.baseTimeline;
    expect(base.skinCareSelectedProductNames, hasLength(3));
    expect(
      base.skinCareSelectedProductNames,
      contains('Simple Kind to Skin Face Wash'),
    );
    expect(
      base.skinCareSelectedProductNames,
      contains("Re'equil Ultra Matte Sunscreen Gel"),
    );
    expect(
      base.skinCareSelectedProductNames,
      isNot(contains('Minimalist Gentle Cleanser')),
    );
    expect(
      base.skinCareSelectedProductNames,
      isNot(contains('Minimalist SPF 50 Sunscreen')),
    );
    expect(
      onboarding7MissingEssentialRecommendationCategories(
        base.skinCareProductRecommendations,
        selectedProductNames: base.skinCareSelectedProductNames,
      ),
      isEmpty,
    );
  });

  testWidgets(
    '77. Delayed region detection suppresses repeated taps and dispatches only one AI request',
    (tester) async {
      useAndroidWidth(tester);
      final completer = Completer<DeviceCountry?>();
      final client = TestSkinCareAiClient(
        routineResultsQueue: [_productRecommendationResult()],
      );
      final countryService = _DelayedCompleterDeviceCountryService(completer);
      await tester.pumpWidget(
        buildTestWidget(
          draft: _noProductsDraft(
            skinType: 'oily',
            problems: const ['pimples'],
            budget: 'medium',
            withPhoto: true,
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: client,
          countryService: countryService,
        ),
      );
      await tester.pumpAndSettle();

      final findProductsBtn = find.text('Find products');
      expect(findProductsBtn, findsOneWidget);

      // First tap enters preflight
      await tester.tap(findProductsBtn);
      await tester.pump();

      // Repeated tap while preflight is busy
      await tester.tap(findProductsBtn, warnIfMissed: false);
      await tester.pump();

      // Complete delayed location resolution
      completer.complete(
        const DeviceCountry(
          countryCode: 'IN',
          countryName: 'India',
          fromDeviceLocation: true,
        ),
      );
      await tester.pumpAndSettle();

      // Verify only a single AI generation request was dispatched
      expect(client.generateCalls, hasLength(1));
      expect(client.generateCalls.first['recommendationOnly'], isTrue);
      expect(find.text('Build skin routine'), findsOneWidget);
    },
  );

  testWidgets(
    '78. Initial has-products setup is scrollable on compact screen (360x640) and footer action is reachable',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            viewPadding: EdgeInsets.only(bottom: 24),
          ),
          child: buildTestWidget(draft: _hasProductsDraft(uid: 'uid-compact')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));
      final buildBtn = find.text('Build skin routine');
      await tester.ensureVisible(buildBtn);
      expect(buildBtn.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

OnboardingDraft _hasProductsDraft({
  String uid = 'uid-1',
  List<TimelineBlockDraft> blocks = const [],
  int desiredApplicationsPerDay = 2,
  String? productNames,
  String? productPhotoAssetId,
  String? productPhotoR2Key,
  String? productPhotoStatus,
  DateTime? productPhotoCreatedAt,
  DateTime? productPhotoUpdatedAt,
  List<String> specialCareNotes = const [],
  bool includePrerequisites = false,
}) {
  final hasSkinBlocks = blocks.any((b) => b.section == 'skin_care');
  final blockProducts = blocks
      .where((b) => b.section == 'skin_care')
      .expand((b) => b.skincareProducts)
      .where((p) => p.trim().isNotEmpty)
      .toSet();
  final effectiveProductNames =
      productNames ??
      (blockProducts.isNotEmpty
          ? blockProducts.join('\n')
          : (hasSkinBlocks && productPhotoR2Key == null ? 'Cleanser' : null));
  final draftBase = BaseTimelineDraft(
    skinCareSetupStep: 1,
    skinCareSetupPath: 'has_products',
    skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
    skinCareProductNames: effectiveProductNames,
    skinCareReviewedProducts: hasSkinBlocks
        ? onboarding7ParseTypedProductDetails(
            effectiveProductNames ?? 'Cleanser',
          )
        : const [],
    skinCareProductPhotoAssetId: productPhotoAssetId,
    skinCareProductPhotoR2Key: productPhotoR2Key,
    skinCareProductPhotoStatus: productPhotoStatus,
    skinCareProductPhotoCreatedAt: productPhotoCreatedAt,
    skinCareProductPhotoUpdatedAt: productPhotoUpdatedAt,
    skinCareSpecialCareNotes: specialCareNotes,
    eatingSetupPath: 'skip',
    eatingSetupStep: 1,
    blocks: includePrerequisites
        ? [
            BaseTimelineDraft.defaultSleepBlock(),
            BaseTimelineDraft.defaultBathBlock(),
            const TimelineBlockDraft(
              id: 'meal-lunch',
              section: 'eating',
              title: 'Lunch',
              startMinute: 720,
              endMinute: 750,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            ...blocks,
          ]
        : blocks,
  );
  final fingerprint = draftBase.computeSkinCareRoutineFingerprint();
  return OnboardingDraft(
    uid: uid,
    currentStep: 7,
    welcomeSaved: true,
    patiencePledgeAccepted: true,
    stepCompleted: List<bool>.generate(
      OnboardingDraft.stepCount,
      (index) => index < 7,
    ),
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'other',
    ),
    baseTimeline: draftBase.copyWith(
      skinCareRoutineFingerprint: fingerprint,
      blocks: _tagSkinCareBlocks(draftBase.blocks, fingerprint),
    ),
  );
}

OnboardingDraft _noProductsDraft({
  String uid = 'uid-1',
  List<TimelineBlockDraft> blocks = const [],
  String? skinType,
  List<String> problems = const [],
  String? budget,
  int desiredApplicationsPerDay = 2,
  List<String> suggestedProducts = const [],
  List<SkinCareProductRecommendationDraft> recommendations = const [],
  List<String> selectedProducts = const [],
  bool withPhoto = false,
  String? photoAssetId,
  String? photoR2Key,
  String? photoStatus,
  DateTime? photoCreatedAt,
  DateTime? photoUpdatedAt,
  bool includePrerequisites = false,
}) {
  final hasSkinBlocks = blocks.any((b) => b.section == 'skin_care');
  final effectiveWithPhoto = withPhoto || hasSkinBlocks;
  final effectiveSelectedProducts = selectedProducts.isNotEmpty
      ? selectedProducts
      : (hasSkinBlocks
            ? const <String>['Minimalist Gentle Cleanser']
            : const <String>[]);
  final effectiveSuggestedProducts = suggestedProducts.isNotEmpty
      ? suggestedProducts
      : (hasSkinBlocks
            ? const <String>['Minimalist Gentle Cleanser']
            : const <String>[]);
  final draftBase = BaseTimelineDraft(
    skinCareSetupStep: 1,
    skinCareSetupPath: 'no_products',
    skinCareSkinType: skinType ?? (hasSkinBlocks ? 'oily' : null),
    skinCareProblems: problems.isNotEmpty
        ? problems
        : (hasSkinBlocks ? const ['pimples'] : const []),
    skinCareBudget: budget ?? (hasSkinBlocks ? 'medium' : null),
    skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
    skinCareSuggestedProducts: effectiveSuggestedProducts,
    skinCareProductRecommendations: recommendations,
    skinCareRecommendationCurrencyCode: recommendations.isNotEmpty
        ? recommendations.first.currencyCode
        : 'INR',
    skinCareSelectedProductNames: effectiveSelectedProducts,
    skinCareFacePhotoAssetId:
        photoAssetId ?? (effectiveWithPhoto ? 'skin-asset' : null),
    skinCareFacePhotoR2Key:
        photoR2Key ??
        (effectiveWithPhoto
            ? 'users/$uid/onboarding/skin_care/skin-asset.jpg'
            : null),
    skinCareFacePhotoStatus:
        photoStatus ?? (effectiveWithPhoto ? 'uploaded' : null),
    skinCareFacePhotoCreatedAt:
        photoCreatedAt ??
        (effectiveWithPhoto ? DateTime.utc(2026, 6, 15, 10) : null),
    skinCareFacePhotoUpdatedAt:
        photoUpdatedAt ??
        (effectiveWithPhoto ? DateTime.utc(2026, 6, 15, 10) : null),
    eatingSetupPath: 'skip',
    eatingSetupStep: 1,
    blocks: includePrerequisites
        ? [
            BaseTimelineDraft.defaultSleepBlock(),
            BaseTimelineDraft.defaultBathBlock(),
            const TimelineBlockDraft(
              id: 'meal-lunch',
              section: 'eating',
              title: 'Lunch',
              startMinute: 720,
              endMinute: 750,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            ...blocks,
          ]
        : blocks,
  );
  final recFingerprint = draftBase.computeSkinCareRecommendationFingerprint();
  final draftWithRec = draftBase.copyWith(
    skinCareRecommendationFingerprint: recFingerprint,
  );
  final routineFingerprint = draftWithRec.computeSkinCareRoutineFingerprint();
  return OnboardingDraft(
    uid: uid,
    currentStep: 7,
    welcomeSaved: true,
    patiencePledgeAccepted: true,
    stepCompleted: List<bool>.generate(
      OnboardingDraft.stepCount,
      (index) => index < 7,
    ),
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'other',
    ),
    baseTimeline: draftWithRec.copyWith(
      skinCareRoutineFingerprint: routineFingerprint,
      blocks: _tagSkinCareBlocks(draftWithRec.blocks, routineFingerprint),
    ),
  );
}

List<TimelineBlockDraft> _tagSkinCareBlocks(
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

SkinCareAiRoutineResult _productRecommendationResult() {
  return const SkinCareAiRoutineResult(
    morningRoutine: [],
    nightRoutine: [],
    weeklyRoutine: [],
    timelineBlocks: [],
    recommendedProducts: [
      SkinCareProductRecommendation(
        name: 'Gentle Cleanser',
        brand: 'Minimalist',
        category: 'cleanser',
        estimatedPrice: '299',
        currencyCode: 'INR',
        reason: 'Affordable daily cleanser for this skin profile',
      ),
      SkinCareProductRecommendation(
        name: 'SPF 50 Sunscreen',
        brand: 'Minimalist',
        category: 'sunscreen',
        estimatedPrice: '399',
        currencyCode: 'INR',
        reason: 'Useful daily UV protection',
      ),
      SkinCareProductRecommendation(
        name: 'Barrier Moisturizer',
        brand: 'Minimalist',
        category: 'moisturizer',
        estimatedPrice: '349',
        currencyCode: 'INR',
        reason: 'Supports the skin barrier',
      ),
      SkinCareProductRecommendation(
        name: '10% Vitamin C Serum',
        brand: 'Minimalist',
        category: 'vitamin_c_serum',
        estimatedPrice: '699',
        currencyCode: 'INR',
        reason: 'Morning antioxidant and brightening support',
      ),
      SkinCareProductRecommendation(
        name: '5% Niacinamide Serum',
        brand: 'Minimalist',
        category: 'treatment_serum',
        estimatedPrice: '599',
        currencyCode: 'INR',
        reason: 'A beginner-friendly concern-targeted treatment',
      ),
    ],
  );
}

SkinCareAiRoutineResult _productRecommendationResultWithAlternatives() {
  return SkinCareAiRoutineResult(
    morningRoutine: const [],
    nightRoutine: const [],
    weeklyRoutine: const [],
    timelineBlocks: const [],
    recommendedProducts: [
      ..._productRecommendationResult().recommendedProducts,
      const SkinCareProductRecommendation(
        name: 'Kind to Skin Face Wash',
        brand: 'Simple',
        category: 'Facial cleansing gel',
        estimatedPrice: '325',
        currencyCode: 'INR',
        reason: 'A gentle alternative cleanser',
      ),
      const SkinCareProductRecommendation(
        name: 'Ultra Matte Sunscreen Gel',
        brand: "Re'equil",
        category: 'UV sun protection',
        estimatedPrice: '495',
        currencyCode: 'INR',
        reason: 'An alternative broad-spectrum sunscreen',
      ),
    ],
  );
}

List<SkinCareProductRecommendationDraft> _productRecommendationDraftsForTest() {
  return _productRecommendationResult().recommendedProducts
      .map(
        (product) => SkinCareProductRecommendationDraft(
          name: product.name,
          brand: product.brand,
          category: product.category,
          estimatedPrice: product.estimatedPrice,
          currencyCode: product.currencyCode,
          reason: product.reason,
        ),
      )
      .toList(growable: false);
}

List<SkinCareProductRecommendationDraft>
_productRecommendationDraftsWithAlternatives() {
  return _productRecommendationResultWithAlternatives().recommendedProducts
      .map(
        (product) => SkinCareProductRecommendationDraft(
          name: product.name,
          brand: product.brand,
          category: product.category,
          estimatedPrice: product.estimatedPrice,
          currencyCode: product.currencyCode,
          reason: product.reason,
        ),
      )
      .toList(growable: false);
}

SkinCareAiRoutineResult _selectedProductRoutineResult() {
  return const SkinCareAiRoutineResult(
    routinePlans: [
      SkinCareRoutinePlan(
        slotLabel: 'morning',
        title: 'AI Morning',
        steps: ['Cleanse', 'Apply sunscreen'],
        productNames: [
          'Minimalist Gentle Cleanser',
          'Minimalist SPF 50 Sunscreen',
        ],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'night',
        title: 'AI Night',
        steps: ['Cleanse', 'Moisturize'],
        productNames: [
          'Minimalist Gentle Cleanser',
          'Minimalist Barrier Moisturizer',
        ],
      ),
    ],
    morningRoutine: [],
    nightRoutine: [],
    weeklyRoutine: ['Patch test Minimalist Gentle Cleanser first'],
    timelineBlocks: [
      {
        'id': 'compatibility-only',
        'title': 'Wrong worker time',
        'startMinute': 420,
        'endMinute': 435,
        'repeatDays': [1, 2, 3, 4, 5, 6, 7],
        'products': ['Wrong Product'],
        'steps': ['Wrong step'],
      },
    ],
  );
}

OnboardingDraft _choiceDraftWithProductData() {
  return OnboardingDraft(
    uid: 'uid-1',
    currentStep: 7,
    baseTimeline: BaseTimelineDraft(
      skinCareSetupStep: 0,
      skinCareSetupPath: 'has_products',
      skinCareProductNames: 'Cleanser',
      skinCareProductPhotoAssetId: 'skin-asset',
      skinCareProductPhotoR2Key:
          'users/uid-1/onboarding/skin_care/skin-asset.jpg',
      skinCareProductPhotoStatus: 'uploaded',
      skinCareProductPhotoCreatedAt: DateTime.utc(2026, 6, 15, 10),
      skinCareProductPhotoUpdatedAt: DateTime.utc(2026, 6, 15, 10, 30),
      skinCareSpecialCareNotes: const ['Special care: old note'],
      blocks: const [
        TimelineBlockDraft(
          id: 'skin-old',
          section: 'skin_care',
          title: 'Old Skin Care',
          startMinute: 455,
          endMinute: 470,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
        ),
      ],
    ),
  );
}

SkinCareAiRoutineResult _routineResultWithPlanCount(int count) {
  final plans = _skinCarePlansForCount(count);
  return SkinCareAiRoutineResult(
    routinePlans: plans,
    morningRoutine: const [],
    nightRoutine: const [],
    weeklyRoutine: const [],
    timelineBlocks: const [],
  );
}

List<SkinCareRoutinePlan> _skinCarePlansForCount(int count) {
  const all = [
    SkinCareRoutinePlan(
      slotLabel: 'morning',
      title: 'Morning Skin Care',
      steps: ['Face wash', 'Sunscreen'],
      productNames: ['Cleanser', 'Sunscreen'],
    ),
    SkinCareRoutinePlan(
      slotLabel: 'midday',
      title: 'Midday Skin Care',
      steps: ['Rinse', 'Reapply sunscreen'],
      productNames: ['Sunscreen'],
    ),
    SkinCareRoutinePlan(
      slotLabel: 'afternoon',
      title: 'Afternoon Skin Care',
      steps: ['Blot oil', 'Reapply sunscreen'],
      productNames: ['Sunscreen'],
    ),
    SkinCareRoutinePlan(
      slotLabel: 'night',
      title: 'Night Skin Care',
      steps: ['Face wash'],
      productNames: ['Cleanser'],
    ),
  ];
  return switch (count) {
    2 => [all.first, all.last],
    3 => [all[0], all[1], all[3]],
    _ => all,
  };
}

SkinCareAiProductResult _richSkinCareProductResult() {
  final longUsage =
      'Use this product after cleansing and before moisturizer. '
      'Keep the label guidance, avoid overuse, and apply gently for a full minute.';
  return SkinCareAiProductResult(
    products: [
      {
        'name': 'Gentle Hydrating Cleanser With Extra Long Label Text',
        'brand': '',
        'category': 'cleanser',
        'keyIngredients': [
          'Aqua',
          'Glycerin',
          'Ceramide NP',
          'Ceramide AP',
          'Ceramide EOP',
          'Hyaluronic Acid',
          'Niacinamide',
        ],
        'possibleActives': [
          'Glycerin',
          'Ceramides',
          'Hyaluronic Acid',
          'Niacinamide',
          'Panthenol',
          'Allantoin',
        ],
        'usageHint': longUsage,
        'warningIfAny': '',
        'confidence': 'high',
      },
      {
        'name': 'Daily UV Aqua Gel SPF 50 PA++++',
        'brand': 'Sun Lab',
        'category': 'sunscreen',
        'keyIngredients': [
          'Uvinul A Plus',
          'Uvinul T 150',
          'Tinosorb S',
          'Glycerin',
          'Vitamin E',
          'Silica',
        ],
        'possibleActives': [
          'UV filters',
          'SPF 50',
          'PA++++',
          'Vitamin E',
          'Antioxidants',
          'Hydrators',
        ],
        'usageHint': longUsage,
        'warningIfAny': 'Reapply after sweating or towel drying.',
        'confidence': 'medium',
      },
      {
        'name': 'Barrier Repair Moisturizer',
        'brand': 'Calm Lab',
        'category': 'moisturizer',
        'keyIngredients': [
          'Ceramide NP',
          'Cholesterol',
          'Fatty Acids',
          'Squalane',
          'Glycerin',
          'Panthenol',
        ],
        'possibleActives': [
          'Ceramides',
          'Squalane',
          'Panthenol',
          'Glycerin',
          'Barrier repair',
          'Soothing agents',
        ],
        'usageHint': longUsage,
        'warningIfAny': 'Patch test if your barrier is irritated.',
        'confidence': 'high',
      },
    ],
  );
}

List<TimelineBlockDraft> _skinCareBlocksForEveryDay(int count) {
  return _skinCarePlansForCount(count)
      .take(count)
      .toList(growable: false)
      .asMap()
      .entries
      .map(
        (entry) => TimelineBlockDraft(
          id: 'skin-every-day-${entry.key}',
          section: 'skin_care',
          title: entry.value.title,
          startMinute: 450 + entry.key * 120,
          endMinute: 465 + entry.key * 120,
          repeatDays: onboarding7EveryDay,
          blockType: TimelineBlockDraft.softBlockKey,
          skincareProducts: entry.value.productNames,
          skincareSteps: entry.value.steps,
          skincareSlotLabel: entry.value.slotLabel,
        ),
      )
      .toList(growable: false);
}

bool _blocksOverlap(TimelineBlockDraft a, TimelineBlockDraft b) {
  final days = a.repeatDays.toSet().intersection(b.repeatDays.toSet());
  if (days.isEmpty) return false;
  return a.startMinute < b.endMinute && a.endMinute > b.startMinute;
}

UploadedAsset _uploadedAsset({
  String contentType = 'image/jpeg',
  UploadedAssetPurpose purpose = UploadedAssetPurpose.skinProducts,
}) {
  final now = DateTime.utc(2026, 6, 15, 10);
  return UploadedAsset(
    assetId: 'skin-asset',
    ownerUid: 'uid-1',
    sourceFeature: OnboardingDraft.sourceOnboarding,
    purpose: purpose,
    fileName: 'products.jpg',
    contentType: contentType,
    sizeBytes: 1200,
    r2Key: 'users/uid-1/onboarding/skin_care/skin-asset.jpg',
    status: UploadedAssetStatus.uploaded,
    createdAt: now,
    updatedAt: now,
  );
}

class TestSkinCareAiClient implements SkinCareAiClient {
  final SkinCareAiProductResult productResult;
  SkinCareAiRoutineResult routineResult;
  final List<SkinCareAiRoutineResult>? routineResultsQueue;
  final Completer<SkinCareAiRoutineResult>? routineCompleter;
  Map<String, dynamic>? lastGenerateParams;
  final List<Map<String, dynamic>> generateCalls = [];
  List<String>? lastProductPhotos;
  int analyzeCalls = 0;

  TestSkinCareAiClient({
    this.productResult = const SkinCareAiProductResult(products: []),
    this.routineResult = const SkinCareAiRoutineResult(
      morningRoutine: [],
      nightRoutine: [],
      weeklyRoutine: [],
      timelineBlocks: [],
      routinePlans: [],
    ),
    this.routineResultsQueue,
    this.routineCompleter,
  });

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async {
    analyzeCalls += 1;
    lastProductPhotos = productPhotos;
    return productResult;
  }

  @override
  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    lastGenerateParams = params;
    generateCalls.add(params);
    if (routineCompleter != null) return routineCompleter!.future;
    if (routineResultsQueue != null && routineResultsQueue!.isNotEmpty) {
      return routineResultsQueue!.removeAt(0);
    }
    return routineResult;
  }
}

Future<void> _selectCoreRecommendedProducts(WidgetTester tester) async {
  for (final name in const [
    'Minimalist Gentle Cleanser',
    'Minimalist Barrier Moisturizer',
    'Minimalist SPF 50 Sunscreen',
  ]) {
    final product = find.text(name);
    for (
      var attempt = 0;
      product.evaluate().isEmpty && attempt < 12;
      attempt += 1
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pump();
    }
    expect(product, findsOneWidget, reason: name);
    await tester.ensureVisible(product);
    await tester.pump();
    await tester.tap(product);
    await tester.pump();
  }
}

class TestDeviceCountryService
    implements DeviceCountryService, PermissionAwareDeviceCountryService {
  final DeviceCountry? result;

  const TestDeviceCountryService([this.result]);

  @override
  Future<DeviceCountry?> detectCountry() async =>
      result ??
      const DeviceCountry(
        countryCode: 'IN',
        countryName: 'India',
        fromDeviceLocation: true,
      );

  @override
  Future<DeviceCountry?> detectCountryIfPermissionGranted() async =>
      detectCountry();
}

class _DelayedCompleterDeviceCountryService
    implements DeviceCountryService, PermissionAwareDeviceCountryService {
  final Completer<DeviceCountry?> completer;

  _DelayedCompleterDeviceCountryService(this.completer);

  @override
  Future<DeviceCountry?> detectCountry() async => completer.future;

  @override
  Future<DeviceCountry?> detectCountryIfPermissionGranted() async =>
      completer.future;
}

class TestUploadInteractionController extends UploadInteractionController {
  final UploadedAsset? result;
  final UploadState? initialLegacyState;
  final TestUploadController? legacyProbe;
  int startUploadCalls = 0;
  int markDeletedCalls = 0;

  TestUploadInteractionController({
    this.result,
    this.initialLegacyState,
    this.legacyProbe,
  }) : super(
         shellConfig: onboardingUploadShellConfig,
         assetRepository: DummyAssetRepo(),
         authRepository: DummyAuthRepo(),
         imagePrepareService: DummyImageService(),
         r2UploadClient: DummyR2Client(),
         permissionService: const DefaultUploadPermissionService(),
       ) {
    if (initialLegacyState?.status == UploadFlowStatus.uploading) {
      final purpose =
          initialLegacyState!.purpose ?? UploadedAssetPurpose.skinProducts;
      final slotKey = purpose == UploadedAssetPurpose.skinFace
          ? onboardingSkinFaceUploadSlot
          : onboardingSkinProductsUploadSlot;
      state = Map.unmodifiable({
        ...state,
        slotKey: UploadSlotRuntimeState(
          slotKey: slotKey,
          purpose: purpose,
          phase: UploadInteractionPhase.uploading,
        ),
      });
    }
  }

  void seedFailedAttempt(bool product) {
    final slot = product
        ? onboardingSkinProductsUploadSlot
        : onboardingSkinFaceUploadSlot;
    state = {
      ...state,
      slot: state[slot]!.copyWith(
        phase: UploadInteractionPhase.failed,
        transientFile: XFile('/not-read-by-test-retry.jpg'),
        attemptError: 'Retry upload',
      ),
    };
  }

  @override
  Future<UploadedAsset?> pickAndUpload(
    String slotKey, {
    required ImageSource source,
    required String uid,
    required String sourceFeature,
    bool deferReplacement = false,
  }) async {
    startUploadCalls += 1;
    legacyProbe?.startUploadCalls += 1;
    if (result == null) return null;
    final purpose = slotKey == onboardingSkinProductsUploadSlot
        ? UploadedAssetPurpose.skinProducts
        : UploadedAssetPurpose.skinFace;
    final asset = result!.copyWith(purpose: purpose, ownerUid: uid);
    final previousDurable = state[slotKey]?.durableAsset;
    state = Map.unmodifiable({
      ...state,
      slotKey: UploadSlotRuntimeState(
        slotKey: slotKey,
        purpose: purpose,
        phase: UploadInteractionPhase.uploaded,
        durableAsset: deferReplacement ? previousDurable : asset,
        pendingReplacementAsset: deferReplacement ? asset : null,
        isDeferredReplacement: deferReplacement,
      ),
    });
    return asset;
  }

  @override
  Future<UploadedAsset?> takePhoto(
    String slotKey, {
    required String uid,
    required String sourceFeature,
    bool deferReplacement = false,
  }) => pickAndUpload(
    slotKey,
    source: ImageSource.camera,
    uid: uid,
    sourceFeature: sourceFeature,
    deferReplacement: deferReplacement,
  );

  @override
  Future<UploadedAsset?> chooseFromGallery(
    String slotKey, {
    required String uid,
    required String sourceFeature,
    bool deferReplacement = false,
  }) => pickAndUpload(
    slotKey,
    source: ImageSource.gallery,
    uid: uid,
    sourceFeature: sourceFeature,
    deferReplacement: deferReplacement,
  );

  @override
  Future<UploadedAsset?> retry(
    String slotKey, {
    required String uid,
    required String sourceFeature,
    bool? deferReplacement,
  }) => pickAndUpload(
    slotKey,
    source: ImageSource.gallery,
    uid: uid,
    sourceFeature: sourceFeature,
    deferReplacement: deferReplacement ?? false,
  );

  @override
  Future<void> commitReplacement(String slotKey, {required String uid}) async {
    final current = state[slotKey];
    if (current?.pendingReplacementAsset != null) {
      state = Map.unmodifiable({
        ...state,
        slotKey: current!.copyWith(
          durableAsset: current.pendingReplacementAsset,
          clearPendingReplacementAsset: true,
          clearDeferredReplacement: true,
          phase: UploadInteractionPhase.uploaded,
        ),
      });
    }
  }

  @override
  Future<void> rollbackReplacement(
    String slotKey, {
    required String uid,
  }) async {
    final current = state[slotKey];
    if (current?.pendingReplacementAsset != null) {
      state = Map.unmodifiable({
        ...state,
        slotKey: current!.copyWith(
          clearPendingReplacementAsset: true,
          clearDeferredReplacement: true,
          phase: current.durableAsset != null
              ? UploadInteractionPhase.uploaded
              : UploadInteractionPhase.empty,
        ),
      });
    }
  }

  @override
  Future<bool> remove(String slotKey, {required String uid}) async {
    markDeletedCalls += 1;
    legacyProbe?.markDeletedCalls += 1;
    final purpose = slotKey == onboardingSkinProductsUploadSlot
        ? UploadedAssetPurpose.skinProducts
        : UploadedAssetPurpose.skinFace;
    state = Map.unmodifiable({
      ...state,
      slotKey: UploadSlotRuntimeState(
        slotKey: slotKey,
        purpose: purpose,
        phase: UploadInteractionPhase.empty,
      ),
    });
    return true;
  }
}

class DelayedTestUploadInteractionController
    extends TestUploadInteractionController {
  final Completer<UploadedAsset?> _gate = Completer<UploadedAsset?>();

  DelayedTestUploadInteractionController({required UploadedAsset result})
    : super(result: result);

  void complete() {
    if (!_gate.isCompleted) {
      _gate.complete(result);
    }
  }

  @override
  Future<UploadedAsset?> pickAndUpload(
    String slotKey, {
    bool deferReplacement = false,
    required ImageSource source,
    required String uid,
    required String sourceFeature,
  }) async {
    startUploadCalls += 1;
    legacyProbe?.startUploadCalls += 1;
    final purpose = slotKey == onboardingSkinProductsUploadSlot
        ? UploadedAssetPurpose.skinProducts
        : UploadedAssetPurpose.skinFace;
    state = Map.unmodifiable({
      ...state,
      slotKey: UploadSlotRuntimeState(
        slotKey: slotKey,
        purpose: purpose,
        phase: UploadInteractionPhase.uploading,
        durableAsset: state[slotKey]?.durableAsset,
        isDeferredReplacement: deferReplacement,
      ),
    });
    final completed = await _gate.future;
    if (completed == null) return null;
    final asset = completed.copyWith(purpose: purpose, ownerUid: uid);
    state = Map.unmodifiable({
      ...state,
      slotKey: UploadSlotRuntimeState(
        slotKey: slotKey,
        purpose: purpose,
        phase: UploadInteractionPhase.uploaded,
        durableAsset: deferReplacement ? state[slotKey]?.durableAsset : asset,
        pendingReplacementAsset: deferReplacement ? asset : null,
        isDeferredReplacement: deferReplacement,
      ),
    });
    return asset;
  }

  @override
  Future<UploadedAsset?> takePhoto(
    String slotKey, {
    bool deferReplacement = false,
    required String uid,
    required String sourceFeature,
  }) => pickAndUpload(
    slotKey,
    deferReplacement: deferReplacement,
    source: ImageSource.camera,
    uid: uid,
    sourceFeature: sourceFeature,
  );

  @override
  Future<UploadedAsset?> chooseFromGallery(
    String slotKey, {
    bool deferReplacement = false,
    required String uid,
    required String sourceFeature,
  }) => pickAndUpload(
    slotKey,
    deferReplacement: deferReplacement,
    source: ImageSource.gallery,
    uid: uid,
    sourceFeature: sourceFeature,
  );
}

class TestUploadController extends UploadController {
  final UploadedAsset? result;
  int startUploadCalls = 0;
  int markDeletedCalls = 0;

  TestUploadController({
    this.result,
    UploadState initialState = const UploadState(),
  }) : super(
         assetRepository: DummyAssetRepo(),
         authRepository: DummyAuthRepo(),
         imagePrepareService: DummyImageService(),
         r2UploadClient: DummyR2Client(),
       ) {
    state = initialState;
  }

  @override
  Future<UploadedAsset?> startUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    ImageSource source = ImageSource.gallery,
  }) async {
    startUploadCalls += 1;
    if (result == null) return null;
    state = UploadState(
      status: UploadFlowStatus.uploaded,
      asset: result,
      uid: uid,
      purpose: purpose,
      sourceFeature: sourceFeature,
    );
    return result;
  }

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {
    markDeletedCalls += 1;
    state = state.copyWith(status: UploadFlowStatus.idle, clearError: true);
  }
}

class DummyAssetRepo implements UploadedAssetRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedAssetRepository implements UploadedAssetRepository {
  final Completer<List<UploadedAsset>> fetchGate = Completer();
  bool fetchStarted = false;

  @override
  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 50,
  }) {
    fetchStarted = true;
    return fetchGate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyImageService implements ImagePrepareService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyR2Client implements R2UploadClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  FakeAuthNotifier()
    : super(
        const AuthState(
          user: AuthUser(
            uid: 'test-uid',
            email: 'test@example.com',
            emailVerified: true,
          ),
          status: AuthFlowStatus.signedInOnboardingIncomplete,
        ),
      );

  void setTestUser(AuthUser? user) {
    state = AuthState(
      user: user,
      status: AuthFlowStatus.signedInOnboardingIncomplete,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
