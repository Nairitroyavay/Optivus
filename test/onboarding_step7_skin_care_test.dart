import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  Widget buildTestWidget({
    OnboardingDraft draft = const OnboardingDraft(currentStep: 7),
    SkinCareAiClient? client,
    TestUploadController? uploadController,
    bool overrideSkinCareClient = true,
  }) {
    return ProviderScope(
      overrides: [
        mockOnboardingProvider.overrideWith((ref) {
          final notifier = MockOnboardingNotifier();
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
      ],
      child: const MaterialApp(home: Scaffold(body: OnboardingStep7())),
    );
  }

  void useAndroidWidth(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .skinCareSetupStep,
      1,
    );
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

  testWidgets('4. Uploaded photo disables typing product names', (
    tester,
  ) async {
    useAndroidWidth(tester);
    final asset = _uploadedAsset();
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(uid: 'uid-1'),
        uploadController: TestUploadController(result: asset),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photo uploaded'), findsOneWidget);
    expect(find.text('Using product photo'), findsOneWidget);
    expect(find.text('Remove photo to type products manually.'), findsWidgets);

    final textField = tester.widget<TextField>(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
    );
    expect(textField.enabled, isFalse);
  });

  testWidgets('5. Missing photo/text blocks generation with friendly error', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(draft: _hasProductsDraft()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Build skin routine'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Type one product per line, for example "Minimalist SPF 50 - sunscreen".',
      ),
      findsOneWidget,
    );
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
            purpose: UploadedAssetPurpose.skinCare,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Uploading...'), findsOneWidget);
  });

  testWidgets('6b. Typing product names disables photo upload', (tester) async {
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
    expect(find.text('Clear product names to upload a photo.'), findsOneWidget);
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    expect(uploadController.startUploadCalls, 0);
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
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    expect(uploadController.startUploadCalls, 1);
    expect(find.text('Photo uploaded'), findsOneWidget);
  });

  testWidgets('6d. Removing photo re-enables text input', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        draft: _hasProductsDraft(uid: 'uid-1'),
        uploadController: TestUploadController(result: _uploadedAsset()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('onboarding-step7-product-names-field')),
          )
          .enabled,
      isFalse,
    );

    await tester.tap(
      find.byKey(const ValueKey('onboarding-step7-remove-photo-button')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('onboarding-step7-product-names-field')),
          )
          .enabled,
      isTrue,
    );
    expect(find.text('Photo uploaded'), findsNothing);
  });

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
    ).read(mockOnboardingProvider).draft.baseTimeline;
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
    await tester.tap(find.text('Build skin routine'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Missing skin-care worker URL'), findsOneWidget);
    expect(find.textContaining('OPTIVUS_SKIN_CARE_WORKER_URL'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    expect(
      container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care'),
      isEmpty,
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

  test('8c. Typed product parser preserves full five-line owned products', () {
    final products = onboarding7ParseTypedProductDetails(
      'Beardo Detan Face Wash - cleanser\n'
      'Minimalist SPF 50 - sunscreen\n'
      'Minimalist Vitamin C - serum\n'
      'Minimalist Alpha Arbutin - serum\n'
      'Minimalist PHA Toner - exfoliant',
    );

    expect(
      products.map((product) => {
        'name': product.name,
        'category': product.category,
      }),
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
    await tester.tap(find.text('Build skin routine'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    expect(
      container
          .read(mockOnboardingProvider)
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final base = container.read(mockOnboardingProvider).draft.baseTimeline;
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
      expect(blocks.first.startMinute, greaterThanOrEqualTo(455));
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
          'keyIngredients': [],
          'possibleActives': [],
          'usageHint': '',
          'warningIfAny': '',
          'confidence': '',
        },
        {
          'name': 'Sunscreen',
          'brand': '',
          'category': 'sunscreen',
          'source': 'typed',
          'keyIngredients': [],
          'possibleActives': [],
          'usageHint': '',
          'warningIfAny': '',
          'confidence': '',
        },
        {
          'name': 'Moisturizer',
          'brand': '',
          'category': 'moisturizer',
          'source': 'typed',
          'keyIngredients': [],
          'possibleActives': [],
          'usageHint': '',
          'warningIfAny': '',
          'confidence': '',
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final base = container.read(mockOnboardingProvider).draft.baseTimeline;
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
    '10bb. Typed products show parsed preview chips before generate',
    (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
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
      await tester.pumpAndSettle();

      expect(find.text('Beardo Detan Face Wash · cleanser'), findsOneWidget);
      expect(find.text('Minimalist SPF 50 · sunscreen'), findsOneWidget);
      expect(find.text('Minimalist Vitamin C · serum'), findsOneWidget);
      expect(find.text('Minimalist Alpha Arbutin · serum'), findsOneWidget);
      expect(find.text('Minimalist PHA Toner · exfoliant'), findsOneWidget);
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(mockOnboardingProvider).draft.baseTimeline;
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
    await tester.tap(find.text('Build skin routine'));
    await tester.pumpAndSettle();

    final notes = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    ).read(mockOnboardingProvider).draft.baseTimeline.skinCareSpecialCareNotes;
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
    // We must tap 'Rebuild' first to clear the old routine.
    await tester.tap(find.text('Rebuild / Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Cleanser, Sunscreen, Moisturizer',
    );
    await tester.tap(find.text('Build skin routine'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    final blocks = container
        .read(mockOnboardingProvider)
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
    await tester.tap(find.text('Build skin routine'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    final blocks = container
        .read(mockOnboardingProvider)
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final base = container.read(mockOnboardingProvider).draft.baseTimeline;
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
              (block) => !block.skincareProducts.contains(
                'Minimalist PHA Toner',
              ),
            )
            .single
            .repeatDays,
        [1, 2, 4, 5, 7],
      );
      expect(
        base.skinCareSpecialCareNotes,
        contains(strongActiveNote),
      );
      expect(
        base.skinCareSpecialCareNotes.any(
          (note) => note.startsWith('Special care:'),
        ),
        isFalse,
      );

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-special-care-notes-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text(strongActiveNote), findsOneWidget);
      expect(find.textContaining('AI returned no usable routine'), findsNothing);
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final base = container.read(mockOnboardingProvider).draft.baseTimeline;
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
        find.byKey(const ValueKey('onboarding-step7-special-care-notes-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text(removedMorningNote), findsOneWidget);
      expect(find.textContaining('AI returned no usable routine'), findsNothing);
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');

      expect(blocks, hasLength(2));
      expect(
        blocks.expand((block) => block.skincareProducts),
        contains(cleanser),
      );
      expect(find.textContaining('AI returned no usable routine'), findsNothing);
    },
  );

  testWidgets('14. Selecting 4 routines per day creates 4 skin-care blocks', (
    tester,
  ) async {
    final client = TestSkinCareAiClient(
      routineResult: _routineResultWithPlanCount(4),
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
      find.byKey(const ValueKey('onboarding-step7-frequency-4')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Cleanser, Sunscreen',
    );
    await tester.tap(find.text('Build skin routine'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingStep7)),
    );
    final blocks = container
        .read(mockOnboardingProvider)
        .draft
        .baseTimeline
        .confirmedBlocksForSection('skin_care');

    expect(client.lastGenerateParams?['desiredApplicationsPerDay'], 4);
    expect(blocks, hasLength(4));
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
    '15. Scheduler places first block after bath and avoids occupied blocks',
    () {
      final occupied = [
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
        routinePlans: _skinCarePlansForCount(4),
        desiredApplicationsPerDay: 4,
        ownedProductNames: const ['Cleanser', 'Sunscreen'],
        now: DateTime.utc(2026, 6, 15),
      );

      expect(result.errorMessage, isNull);
      expect(result.blocks, hasLength(4));
      expect(result.blocks.first.startMinute, greaterThanOrEqualTo(500));
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
    },
  );

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
      id: 'breakfast',
      section: 'eating',
      title: 'Breakfast',
      startMinute: 480,
      endMinute: 510,
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.softBlockKey,
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
        .read(mockOnboardingProvider)
        .draft
        .baseTimeline
        .blocks
        .singleWhere((block) => block.id == 'skin-edit');
    expect(updated.startMinute, 455);
    expect(updated.endMinute, 470);
  });

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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(mockOnboardingProvider)
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
    '19. AI returns 2 plans, selecting 4 without unsafe warning shows fewer-routines error',
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
        find.byKey(const ValueKey('onboarding-step7-frequency-4')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser, Sunscreen SPF 50',
      );
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(mockOnboardingProvider)
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final base = container.read(mockOnboardingProvider).draft.baseTimeline;
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(mockOnboardingProvider)
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
    '19d. Missing afternoon worker warning shows specific 4/day error and creates zero blocks',
    (tester) async {
      final client = TestSkinCareAiClient(
        routineResult: SkinCareAiRoutineResult(
          routinePlans: _skinCarePlansForCount(3),
          morningRoutine: const [],
          nightRoutine: const [],
          weeklyRoutine: const [],
          timelineBlocks: const [],
          warnings: const [
            'ai_missing_required_slot:afternoon',
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
        find.byKey(const ValueKey('onboarding-step7-frequency-4')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser\nSunscreen',
      );
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');

      expect(blocks, isEmpty);
      expect(
        find.text(
          'AI returned no afternoon routine for 4/day. Try again or choose 3 times/day.',
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(mockOnboardingProvider)
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
            {
              'name': 'Photo Cleanser',
              'category': 'cleanser',
            },
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

      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-frequency-3')),
      );
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');
      final midday = blocks.singleWhere(
        (block) => block.skincareSlotLabel == 'midday',
      );
      final productsFromPhoto =
          client.lastGenerateParams?['productsFromPhoto'] as List<dynamic>;

      expect(blocks, hasLength(3));
      expect(midday.skincareProducts, contains('UV Aqua Gel'));
      expect(midday.skincareSteps, contains('Reapply sunscreen'));
      expect(client.lastGenerateParams?['productInputSource'], 'photo');
      expect(client.lastGenerateParams?['typedProductDetails'], isNull);
      expect(client.lastGenerateParams?['typedProductNames'], isNull);
      expect(productsFromPhoto, hasLength(2));
      expect(productsFromPhoto.first['category'], 'sunscreen');
      expect(productsFromPhoto.first['possibleActives'], ['UV filters']);
    },
  );

  testWidgets(
    '21. Photo source sends only photo products for 4 AI-returned routines',
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
              slotLabel: 'afternoon',
              title: 'Afternoon SPF',
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

      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-frequency-4')),
      );
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');

      expect(blocks, hasLength(4));
      expect(
        blocks
            .singleWhere((block) => block.skincareSlotLabel == 'midday')
            .skincareProducts,
        contains('UV Aqua Gel'),
      );
      expect(
        blocks
            .singleWhere((block) => block.skincareSlotLabel == 'afternoon')
            .skincareProducts,
        contains('UV Aqua Gel'),
      );
      expect(client.lastGenerateParams?['typedProductDetails'], isNull);
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

      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-frequency-3')),
      );
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final blocks = container
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .confirmedBlocksForSection('skin_care');

      expect(blocks, isEmpty);
      final base = container.read(mockOnboardingProvider).draft.baseTimeline;
      expect(base.skinCareSpecialCareNotes, isEmpty);
      expect(
        find.text(
          'AI returned fewer routines than requested. Try again or choose fewer times per day.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Suggested:'), findsNothing);
      expect(
        (client.lastGenerateParams?['productsFromPhoto'] as List).single,
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
            .singleWhere((block) => block.startMinute == 780)
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      expect(
        container
            .read(mockOnboardingProvider)
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

      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      final firstContainer = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final persistedDraft = firstContainer.read(mockOnboardingProvider).draft;
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
      await tester.tap(find.text('Build skin routine'));
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
            productPhotoAssetId: 'skin-asset',
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();
      expect(jpgClient.analyzeCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            productPhotoAssetId: 'skin-asset',
            productPhotoR2Key:
                'users/uid-1/onboarding/skin_care/restored-products.heic',
            productPhotoStatus: 'uploaded',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          client: jpgClient,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photo uploaded'), findsOneWidget);
      expect(find.text('restored-products.heic'), findsOneWidget);
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This photo format is not supported. Please upload JPEG, PNG, or WEBP.',
        ),
        findsOneWidget,
      );
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

  testWidgets(
    '34. Missing worker config without override does not create fake blocks',
    (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          draft: _hasProductsDraft(
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
          overrideSkinCareClient: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Cleanser, Sunscreen',
      );
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      expect(
        container
            .read(mockOnboardingProvider)
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

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build skin routine'));
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
            purpose: UploadedAssetPurpose.skinCare,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Uploading photo...'), findsOneWidget);
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
    ).read(mockOnboardingProvider).draft.baseTimeline;
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
    '38. Switching product mode to build-for-me clears product fields',
    (tester) async {
      await tester.pumpWidget(
        buildTestWidget(draft: _choiceDraftWithProductData()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Build routine for me'));
      await tester.pumpAndSettle();

      final base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(mockOnboardingProvider).draft.baseTimeline;
      expect(base.skinCareSetupPath, 'no_products');
      expect(base.skinCareProductNames, isNull);
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
    ).read(mockOnboardingProvider).draft.baseTimeline;
    expect(base.skinCareSetupPath, 'has_products');
    expect(base.skinCareProductNames, 'Cleanser');
    expect(base.skinCareProductPhotoAssetId, 'skin-asset');
    expect(base.skinCareProductPhotoR2Key, contains('skin-asset.jpg'));
    expect(base.skinCareProductPhotoCreatedAt, DateTime.utc(2026, 6, 15, 10));
  });

  testWidgets(
    '40. Pre-generation products mode scrolls safely with keyboard and message',
    (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockOnboardingProvider.overrideWith((ref) {
              final notifier = MockOnboardingNotifier();
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
      final scrollable = find.descendant(
        of: find.byType(OnboardingStep7),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsWidgets);
      await tester.drag(scrollable.first, const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(find.text('Build skin routine'), findsOneWidget);
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

      expect(find.text('Routine built'), findsOneWidget);

      expect(find.text('2 routines per day'), findsOneWidget);
      expect(find.text('Rebuild / Edit'), findsOneWidget);
      // Removed takeException
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

      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      expect(client.generateCalls.length, 2);
      expect(client.generateCalls[0]['compact'], isNot(true));
      expect(client.generateCalls[1]['compact'], isTrue);
      final firstProducts =
          client.generateCalls[0]['productsFromPhoto'] as List<dynamic>;
      final secondProducts =
          client.generateCalls[1]['productsFromPhoto'] as List<dynamic>;
      expect(jsonEncode(firstProducts), isNot(jsonEncode(secondProducts)));
      expect((firstProducts.first as Map)['brand'], '');
      expect((secondProducts.first as Map).containsKey('brand'), isFalse);
      expect((firstProducts.first as Map)['keyIngredients'], hasLength(7));
      expect((secondProducts.first as Map)['keyIngredients'], hasLength(5));
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
      expect(find.text('Routine built'), findsOneWidget);
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

      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Build skin routine'));
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

      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final draftState = container.read(mockOnboardingProvider);
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

      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final draftState = container.read(mockOnboardingProvider);
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final persistedDraft = container.read(mockOnboardingProvider).draft;
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
    '52. Rebuild clears notes and regeneration replaces the note set',
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
      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();

      var base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(mockOnboardingProvider).draft.baseTimeline;
      expect(base.skinCareSpecialCareNotes, ['missing: First note']);

      expect(find.textContaining('Suggested:'), findsNothing);

      await tester.tap(find.text('Rebuild / Edit'));
      await tester.pumpAndSettle();
      base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(mockOnboardingProvider).draft.baseTimeline;
      expect(base.skinCareSpecialCareNotes, isEmpty);

      await tester.tap(find.text('Build skin routine'));
      await tester.pumpAndSettle();
      base = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      ).read(mockOnboardingProvider).draft.baseTimeline;
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
              .read(mockOnboardingProvider)
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

    final fourPerDay = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 4,
      ownedProductNames: const ['Gentle Cleanser', 'Daily Sunscreen'],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning AI',
          steps: ['Apply sunscreen'],
          productNames: ['Daily Sunscreen'],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'afternoon',
          title: 'Afternoon AI',
          steps: ['Reapply sunscreen'],
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
    expect(fourPerDay.blocks, isEmpty);
    expect(fourPerDay.errorMessage, fewerRoutinesMessage);

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
      desiredApplicationsPerDay: 4,
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

  test('58. Sun cream is sunscreen and not moisturizer', () {
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
}) {
  return OnboardingDraft(
    uid: uid,
    currentStep: 7,
    baseTimeline: BaseTimelineDraft(
      skinCareSetupStep: 1,
      skinCareSetupPath: 'has_products',
      skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
      skinCareProductNames: productNames,
      skinCareProductPhotoAssetId: productPhotoAssetId,
      skinCareProductPhotoR2Key: productPhotoR2Key,
      skinCareProductPhotoStatus: productPhotoStatus,
      skinCareProductPhotoCreatedAt: productPhotoCreatedAt,
      skinCareProductPhotoUpdatedAt: productPhotoUpdatedAt,
      skinCareSpecialCareNotes: specialCareNotes,
      blocks: blocks,
    ),
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

UploadedAsset _uploadedAsset({String contentType = 'image/jpeg'}) {
  final now = DateTime.utc(2026, 6, 15, 10);
  return UploadedAsset(
    assetId: 'skin-asset',
    ownerUid: 'uid-1',
    sourceFeature: OnboardingDraft.sourceOnboarding,
    purpose: UploadedAssetPurpose.skinCare,
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
    if (routineResultsQueue != null && routineResultsQueue!.isNotEmpty) {
      return routineResultsQueue!.removeAt(0);
    }
    return routineResult;
  }
}

class TestUploadController extends UploadController {
  final UploadedAsset? result;
  int startUploadCalls = 0;

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
}

class DummyAssetRepo implements UploadedAssetRepository {
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
