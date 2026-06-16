import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            steps: ['Cleanser'],
            productNames: ['Cleanser'],
          ),
          SkinCareRoutinePlan(
            slotLabel: 'night',
            title: 'Night Skin Care',
            steps: ['Cleanser'],
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
      'Cleanser',
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

  test(
    '20. Different occupied weekdays produce grouped blocks with different repeatDays',
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
    },
  );

  testWidgets(
    '21. No real bath blocks generation and creates no skin-care blocks',
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
    '22. Uploaded product photo persists after rebuild and R2 key is used',
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
    '23. Visual stretch lane logic keeps close edit buttons reachable',
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
    '24. Missing worker config without override does not create fake blocks',
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

  testWidgets('25. Unsupported uploaded image type shows friendly error', (
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

  testWidgets('26. Upload busy generate button has readable state', (
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
}

OnboardingDraft _hasProductsDraft({
  String uid = 'uid-1',
  List<TimelineBlockDraft> blocks = const [],
  int desiredApplicationsPerDay = 2,
  String? productPhotoAssetId,
  String? productPhotoR2Key,
  String? productPhotoStatus,
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
      blocks: blocks,
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
  final SkinCareAiRoutineResult routineResult;
  Map<String, dynamic>? lastGenerateParams;
  List<String>? lastProductPhotos;
  int analyzeCalls = 0;

  TestSkinCareAiClient({
    this.productResult = const SkinCareAiProductResult(products: []),
    required this.routineResult,
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
