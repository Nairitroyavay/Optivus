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

  testWidgets('4. Uploaded photo still allows typing product names', (
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

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-step7-product-names-field')),
      'Cleanser, sunscreen',
    );
    await tester.pump();

    expect(find.text('Cleanser, sunscreen'), findsOneWidget);
  });

  testWidgets('5. Missing photo/text blocks generation with friendly error', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(draft: _hasProductsDraft()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Build skin routine'));
    await tester.pumpAndSettle();

    expect(
      find.text('Upload your product photo or type product names first.'),
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
            timelineBlocks: [],
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
      find.text('AI failed to generate a routine. Try adding more details.'),
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
        'Cleanser\nMoisturizer',
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
      expect(client.lastGenerateParams?['typedProductNames'], [
        'Cleanser',
        'Moisturizer',
      ]);
      expect(client.lastGenerateParams?['desiredApplicationsPerDay'], 2);
    },
  );

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
    '18. AI returns 2 plans, selecting 3 creates safe refresh block',
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

      expect(blocks, hasLength(3));
      expect(
        blocks.any((block) => block.skincareSlotLabel == 'midday'),
        isTrue,
      );
      expect(
        blocks
            .singleWhere((block) => block.skincareSlotLabel == 'midday')
            .skincareSteps,
        contains('Reapply sunscreen'),
      );
    },
  );

  testWidgets(
    '19. AI returns 2 plans, selecting 4 creates two safe refresh blocks',
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

      expect(blocks, hasLength(4));
      expect(
        blocks.any((block) => block.skincareSlotLabel == 'midday'),
        isTrue,
      );
      expect(
        blocks.any((block) => block.skincareSlotLabel == 'afternoon'),
        isTrue,
      );
    },
  );

  testWidgets(
    '20. Product metadata sunscreen supports 3 routines without sunscreen name',
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
          ],
        ),
        routineResult: _routineResultWithGenericTwoPlans(),
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
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Gentle Cleanser',
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
      expect(productsFromPhoto.single['category'], 'sunscreen');
      expect(productsFromPhoto.single['possibleActives'], ['UV filters']);
    },
  );

  testWidgets(
    '21. Product metadata sunscreen supports 4 routines without sunscreen name',
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
          ],
        ),
        routineResult: _routineResultWithGenericTwoPlans(),
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
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-step7-product-names-field')),
        'Gentle Cleanser',
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
    },
  );

  testWidgets(
    '22. Photo metadata with no product name still generates sunscreen refresh',
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
        routineResult: _routineResultWithGenericTwoPlans(),
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
      expect(find.textContaining('AI could not read products'), findsNothing);
      expect(
        blocks
            .singleWhere((block) => block.skincareSlotLabel == 'midday')
            .skincareProducts,
        contains('Sunscreen'),
      );
      expect(
        blocks
            .singleWhere((block) => block.skincareSlotLabel == 'afternoon')
            .skincareProducts,
        contains('Sunscreen'),
      );
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

  test('25. Scheduler repairs title-only plans from fallback products', () {
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
      fallbackProductNames: const ['Gentle Cleanser', 'Daily Sunscreen'],
      now: DateTime.utc(2026, 6, 15),
    );

    expect(result.errorMessage, isNull);
    expect(result.blocks, hasLength(2));
    expect(result.blocks.first.skincareSteps, isNotEmpty);
    expect(result.blocks.first.skincareProducts, contains('Daily Sunscreen'));
    expect(
      result.blocks.every(
        (block) =>
            block.endMinute - block.startMinute ==
            onboarding7SkinCareDurationMinutes,
      ),
      isTrue,
    );
  });

  test(
    '26. Scheduler fails title-only plans without safe fallback products',
    () {
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
      expect(result.errorMessage, contains('sunscreen'));
    },
  );

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
  });

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
                'Upload your product photo or type product names first.',
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
                    'Upload your product photo or type product names first.',
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
        'Cleanser',
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
      expect(
        find.textContaining('Special care: Exfoliation Night - AHA BHA'),
        findsOneWidget,
      );
      final scBlocks = draftState.draft.baseTimeline.blocks
          .where((b) => b.section == 'skin_care')
          .toList();
      expect(scBlocks.length, 2); // Morning (from AI) and Night (synthesized)
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
      expect(
        find.textContaining('Special care: Retinol Treatment - Retinol Serum'),
        findsOneWidget,
      );

      // Default desired applications is 2. The Retinol is filtered, so the scheduler synthesizes 2 safe blocks from Cleanser/Moisturizer.
      expect(scBlocks.length, 2);
      expect(
        scBlocks.any((b) => b.skincareProducts.contains('Retinol Serum')),
        isFalse,
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
            {
              'title': 'Retinol night',
              'steps': ['use 2x/week'],
              'warnings': ['avoid acids the same night'],
            },
            'Patch test before new actives',
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
      expect(notes, contains('Patch test before new actives'));
      expect(
        notes,
        contains(startsWith('Special care: AHA Night - AHA Serum')),
      );
      expect(
        find.textContaining('Retinol night - use 2x/week'),
        findsOneWidget,
      );

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
            suggestedProducts: const ['First note'],
            morningRoutine: const [],
            nightRoutine: const [],
            weeklyRoutine: const [],
            timelineBlocks: const [],
            routinePlans: _skinCarePlansForCount(2),
          ),
          SkinCareAiRoutineResult(
            suggestedProducts: const ['Second note'],
            morningRoutine: const [],
            nightRoutine: const [],
            weeklyRoutine: const [],
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
      expect(base.skinCareSpecialCareNotes, ['First note']);
      expect(find.textContaining('First note'), findsOneWidget);

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
      expect(base.skinCareSpecialCareNotes, ['Second note']);
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

  test('57. Scheduler repairs or rejects unsafe slot products', () {
    final bathBase = BaseTimelineDraft(
      blocks: [BaseTimelineDraft.defaultBathBlock()],
    );

    final middayRepair = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 3,
      fallbackProductNames: const ['Cleanser', 'Sunscreen', 'Moisturizer'],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'midday',
          title: 'Midday Skin Care',
          steps: ['Cleanse'],
          productNames: ['Cleanser'],
        ),
      ],
      now: DateTime.utc(2026, 6, 15),
    );
    expect(middayRepair.errorMessage, isNull);
    expect(
      middayRepair.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'midday')
          .skincareProducts,
      ['Sunscreen'],
    );

    final morningRepair = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 2,
      fallbackProductNames: const ['Moisturizer', 'Sunscreen'],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning Skin Care',
          steps: ['Moisturize'],
          productNames: ['Moisturizer'],
        ),
      ],
      now: DateTime.utc(2026, 6, 15),
    );
    expect(morningRepair.errorMessage, isNull);
    expect(
      morningRepair.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'morning')
          .skincareProducts,
      contains('Sunscreen'),
    );

    final nightRepair = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: bathBase,
      desiredApplicationsPerDay: 2,
      fallbackProductNames: const ['Sunscreen', 'Cleanser', 'Moisturizer'],
      routinePlans: const [
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Night Skin Care',
          steps: ['Sunscreen'],
          productNames: ['Sunscreen'],
        ),
      ],
      now: DateTime.utc(2026, 6, 15),
    );
    expect(nightRepair.errorMessage, isNull);
    expect(
      nightRepair.blocks
          .singleWhere((block) => block.skincareSlotLabel == 'night')
          .skincareProducts,
      ['Cleanser', 'Moisturizer'],
    );

    for (final result in [
      onboarding7ScheduleSkinCareRoutine(
        baseTimeline: bathBase,
        desiredApplicationsPerDay: 3,
        fallbackProductNames: const ['Cleanser', 'Moisturizer'],
        routinePlans: const [
          SkinCareRoutinePlan(
            slotLabel: 'midday',
            title: 'Midday Skin Care',
            steps: ['Cleanse'],
            productNames: ['Cleanser'],
          ),
        ],
      ),
      onboarding7ScheduleSkinCareRoutine(
        baseTimeline: bathBase,
        desiredApplicationsPerDay: 2,
        fallbackProductNames: const ['Moisturizer'],
        routinePlans: const [
          SkinCareRoutinePlan(
            slotLabel: 'morning',
            title: 'Morning Skin Care',
            steps: ['Moisturize'],
            productNames: ['Moisturizer'],
          ),
        ],
      ),
      onboarding7ScheduleSkinCareRoutine(
        baseTimeline: bathBase,
        desiredApplicationsPerDay: 2,
        fallbackProductNames: const ['Sunscreen'],
        routinePlans: const [
          SkinCareRoutinePlan(
            slotLabel: 'night',
            title: 'Night Skin Care',
            steps: ['Sunscreen'],
            productNames: ['Sunscreen'],
          ),
        ],
      ),
      onboarding7ScheduleSkinCareRoutine(
        baseTimeline: bathBase,
        desiredApplicationsPerDay: 2,
        routinePlans: const [
          SkinCareRoutinePlan(
            slotLabel: 'morning',
            title: 'Treatment',
            steps: ['Apply treatment'],
            productNames: [],
          ),
        ],
      ),
    ]) {
      expect(result.blocks, isEmpty);
      expect(
        result.errorMessage,
        'AI could not build a safe daily routine from these products. Add product names like cleanser, moisturizer, or sunscreen.',
      );
    }
  });
}

OnboardingDraft _hasProductsDraft({
  String uid = 'uid-1',
  List<TimelineBlockDraft> blocks = const [],
  int desiredApplicationsPerDay = 2,
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

SkinCareAiRoutineResult _routineResultWithGenericTwoPlans() {
  return const SkinCareAiRoutineResult(
    routinePlans: [
      SkinCareRoutinePlan(
        slotLabel: 'morning',
        title: 'Morning Skin Care',
        steps: ['Face wash'],
        productNames: ['Gentle Cleanser'],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'night',
        title: 'Night Skin Care',
        steps: ['Face wash'],
        productNames: ['Gentle Cleanser'],
      ),
    ],
    morningRoutine: [],
    nightRoutine: [],
    weeklyRoutine: [],
    timelineBlocks: [],
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
      steps: ['Face wash', 'Vitamin C', 'Sunscreen'],
      productNames: ['Cleanser', 'Vitamin C Serum', 'Sunscreen'],
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
      steps: ['Face wash', 'Moisturizer'],
      productNames: ['Cleanser', 'Moisturizer'],
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
