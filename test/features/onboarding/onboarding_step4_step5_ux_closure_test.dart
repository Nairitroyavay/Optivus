import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'package:optivus/features/uploads/controllers/upload_interaction_controller.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/features/uploads/services/upload_permission_service.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

TimelineBlockDraft _makeEatingBlock({
  required String id,
  required String title,
  required int startMinute,
  required int endMinute,
}) {
  return TimelineBlockDraft(
    id: id,
    section: 'eating',
    title: title,
    startMinute: startMinute,
    endMinute: endMinute,
    repeatDays: const [1, 2, 3, 4, 5, 6, 7],
    blockType: TimelineBlockDraft.softBlockKey,
    source: 'ai_creation',
  );
}

TimelineBlockDraft _makeClassBlock({
  required String id,
  required String title,
  required int startMinute,
  required int endMinute,
}) {
  return TimelineBlockDraft(
    id: id,
    section: 'classes',
    title: title,
    startMinute: startMinute,
    endMinute: endMinute,
    repeatDays: const [1, 2, 3, 4, 5],
    blockType: TimelineBlockDraft.hardBlockKey,
    source: 'manual',
  );
}

OnboardingDraft _buildDraftForStep({
  required int targetStep,
  required BaseTimelineDraft baseTimeline,
  String? role,
  String? workType,
}) {
  final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
  for (var i = 0; i < targetStep; i++) {
    completed[i] = true;
  }
  final dirty = List<bool>.filled(OnboardingDraft.stepCount, false);
  dirty[targetStep] = true;

  final selectedRole =
      role ??
      (targetStep >= onboardingEatingStepIndex
          ? LifeRoleDraft.notStudentNotWorkingKey
          : LifeRoleDraft.studentKey);

  return OnboardingDraft(
    uid: 'test-user-ux',
    currentStep: targetStep,
    welcomeSaved: true,
    patiencePledgeAccepted: true,
    stepCompleted: completed,
    stepDirty: dirty,
    lifeRole: LifeRoleDraft(
      lifeRole: selectedRole,
      workType:
          workType ??
          ((selectedRole == LifeRoleDraft.workingKey ||
                  selectedRole == LifeRoleDraft.studentWorkingKey)
              ? 'full_time'
              : null),
      businessMode: selectedRole == LifeRoleDraft.businessKey
          ? 'fixed_shifts'
          : null,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 72,
      gender: 'male',
    ).withEstimates(),
    baseTimeline: baseTimeline,
  );
}

List<TimelineBlockDraft> _makeGate2EatingBlocks({
  required OnboardingDraft draft,
  int mealsPerDay = 3,
}) {
  final targets = draft.canonicalNutritionTargets();
  final targetCal = targets.targetCalories ?? 2000.0;
  final targetProt = targets.proteinTarget ?? 140.0;
  final calPerMeal = (targetCal / mealsPerDay).round();
  final protPerMeal = (targetProt / mealsPerDay).round();

  final slotNames = mealsPerDay == 4
      ? const ['breakfast', 'lunch', 'afternoon_snack', 'dinner']
      : const ['breakfast', 'lunch', 'dinner'];
  return [
    for (var d = 1; d <= 7; d++)
      for (final slot in slotNames)
        TimelineBlockDraft(
          id: '$slot-$d',
          section: 'eating',
          title: slot == 'afternoon_snack'
              ? 'Snack'
              : slot[0].toUpperCase() + slot.substring(1),
          mealCategory: slot == 'afternoon_snack' ? 'snack' : slot,
          mealSlot: slot,
          startMinute: slot == 'breakfast'
              ? 8 * 60
              : slot == 'lunch'
                  ? 13 * 60
                  : slot == 'afternoon_snack'
                      ? 17 * 60
                      : 20 * 60,
          endMinute: (slot == 'breakfast'
                  ? 8 * 60
                  : slot == 'lunch'
                      ? 13 * 60
                      : slot == 'afternoon_snack'
                          ? 17 * 60
                          : 20 * 60) +
              30,
          repeatDays: [d],
          dishes: switch (slot) {
            'breakfast' => ['Pancakes $d', 'Blueberries $d'],
            'lunch' => ['Grilled Chicken $d', 'Brown Rice $d'],
            'afternoon_snack' => ['Greek Yogurt $d', 'Walnuts $d'],
            _ => ['Baked Salmon $d', 'Steamed Broccoli $d'],
          },
          source: onboardingEatingGeneratedSource,
          calories: calPerMeal.toDouble(),
          protein: protPerMeal.toDouble(),
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
  ];
}

OnboardingDraft _buildGate2Step5Draft({
  int eatingSetupStep = 2,
  int mealsPerDay = 3,
  String eatingSetupPath = onboardingEatingPathCreate,
}) {
  final baseDraft = _buildDraftForStep(
    targetStep: onboardingEatingStepIndex,
    baseTimeline: BaseTimelineDraft(
      eatingSetupStep: eatingSetupStep,
      eatingSetupPath: eatingSetupPath,
      mealsPerDay: mealsPerDay,
      breakfastMinute: 8 * 60,
      lunchMinute: 13 * 60,
      snackMinute: mealsPerDay == 4 ? 17 * 60 : null,
      dinnerMinute: 20 * 60,
    ),
  );
  final blocks = _makeGate2EatingBlocks(draft: baseDraft, mealsPerDay: mealsPerDay);
  final withBlocks = baseDraft.copyWith(
    baseTimeline: baseDraft.baseTimeline.copyWith(
      eatingGeneratedPlanVersion: BaseTimelineDraft.currentGate2EatingPlanVersion,
      blocks: blocks,
    ),
  );
  final targets = withBlocks.canonicalNutritionTargets();
  final inputs = withBlocks.canonicalEatingGenerationInputs(targets: targets);
  return withBlocks.copyWith(
    baseTimeline: withBlocks.baseTimeline.copyWith(
      eatingGeneratedInputFingerprint: inputs.computeFingerprint(),
    ),
  );
}

Future<void> _settle(WidgetTester tester, [int ms = 300]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

bool _isPrimaryCtaVisible(WidgetTester tester) {
  final opacityFinders = find.byType(AnimatedOpacity);
  if (opacityFinders.evaluate().isEmpty) return false;
  final lastOpacity = tester.widget<AnimatedOpacity>(opacityFinders.last);
  return lastOpacity.opacity > 0.0;
}

Future<void> _pumpAndroidSized(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(393, 873),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(child);
  await _settle(tester, 500);
}

void _expectScreenStartsInTopContentRegion(
  WidgetTester tester,
  ValueKey<String> key,
) {
  final rect = tester.getRect(find.byKey(key));
  expect(
    rect.top,
    lessThan(80),
    reason:
        'Short onboarding switcher children should start at the top of the '
        'body instead of being vertically centered.',
  );
}

void main() {
  group('Onboarding Step 4 & Step 5 UX Closure Contract', () {
    testWidgets('Step 4 AI screen is top-aligned inside switcher body', (
      tester,
    ) async {
      final draft = _buildDraftForStep(
        targetStep: onboardingClassJobStepIndex,
        baseTimeline: const BaseTimelineDraft(classJobSetupStep: 1),
      );

      await _pumpAndroidSized(
        tester,
        ProviderScope(
          overrides: [
            mockOnboardingProvider.overrideWith(
              (_) => MockOnboardingNotifier()..loadSeedData(draft),
            ),
            routineImportAiControllerProvider.overrideWith(
              (ref) => _MockExtractingRoutineImportAiController(
                ref,
                _FakeDelayedRoutineImportAiClient(),
              ),
            ),
            onboardingClassTimelineProvider.overrideWith((_) => []),
            onboardingWorkTimelineProvider.overrideWith((_) => []),
          ],
          child: const MaterialApp(
            home: Scaffold(body: OnboardingStep4Unified()),
          ),
        ),
      );

      const screenKey = ValueKey('onboarding-step4-ai-screen');
      expect(find.byKey(screenKey), findsOneWidget);
      _expectScreenStartsInTopContentRegion(tester, screenKey);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Step 5 choice screen is top-aligned inside switcher body', (
      tester,
    ) async {
      final draft = _buildDraftForStep(
        targetStep: onboardingEatingStepIndex,
        baseTimeline: const BaseTimelineDraft(eatingSetupStep: 0),
      );

      await _pumpAndroidSized(
        tester,
        ProviderScope(
          overrides: [
            mockOnboardingProvider.overrideWith(
              (_) => MockOnboardingNotifier()..loadSeedData(draft),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: OnboardingStep5())),
        ),
      );

      const screenKey = ValueKey('onboarding-step5-choice-screen');
      expect(find.byKey(screenKey), findsOneWidget);
      _expectScreenStartsInTopContentRegion(tester, screenKey);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Step 5 AI screen is top-aligned inside switcher body', (
      tester,
    ) async {
      final draft = _buildDraftForStep(
        targetStep: onboardingEatingStepIndex,
        baseTimeline: const BaseTimelineDraft(
          eatingSetupPath: onboardingEatingPathHasRoutine,
          eatingSetupStep: 2,
        ),
      );

      await _pumpAndroidSized(
        tester,
        ProviderScope(
          overrides: [
            mockOnboardingProvider.overrideWith(
              (_) => MockOnboardingNotifier()..loadSeedData(draft),
            ),
            routineImportAiControllerProvider.overrideWith(
              (ref) => _MockExtractingRoutineImportAiController(
                ref,
                _FakeDelayedRoutineImportAiClient(),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: OnboardingStep5())),
        ),
      );

      const screenKey = ValueKey('onboarding-step5-ai-screen');
      expect(find.byKey(screenKey), findsOneWidget);
      _expectScreenStartsInTopContentRegion(tester, screenKey);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Step 4: Setup mode renders header + upload card, hides timeline & primary CTA',
      (tester) async {
        final draft = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          baseTimeline: const BaseTimelineDraft(classJobSetupStep: 0),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draft),
              ),
              onboardingClassTimelineProvider.overrideWith((_) => []),
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // 1. Setup screen visible
        expect(
          find.byKey(const ValueKey('onboarding-step4-setup-screen')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('onboarding-step4-upload-card')),
          findsOneWidget,
        );

        // 2. Timeline and day chips are NOT visible
        expect(find.text('Set Your Weekly Schedule'), findsNothing);
        expect(find.byKey(const ValueKey('timeline-day-chip-1')), findsNothing);

        // 3. Bottom Primary CTA ("Next Step") is hidden
        expect(_isPrimaryCtaVisible(tester), isFalse);
      },
    );

    testWidgets(
      'Step 4: Review mode renders timeline, day chips, reveals Primary CTA, hides upload card',
      (tester) async {
        final block = _makeClassBlock(
          id: 'cs101',
          title: 'CS 101',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
        );
        final draft = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          baseTimeline: BaseTimelineDraft(
            classJobSetupStep: 1,
            blocks: [block],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draft),
              ),
              onboardingClassTimelineProvider.overrideWith(
                (_) => [
                  ClassRoutineBlock(
                    id: 'cs101',
                    subject: 'CS 101',
                    startMinute: 9 * 60,
                    endMinute: 10 * 60,
                    repeatDays: const [1],
                    icon: Icons.school_rounded,
                    color: Colors.blue,
                  ),
                ],
              ),
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // 1. Review screen visible
        expect(
          find.byKey(const ValueKey('onboarding-step4-review-screen')),
          findsOneWidget,
        );

        // 2. Timeline block is visible
        expect(find.text('CS 101'), findsOneWidget);

        // 3. Upload card is hidden
        expect(
          find.byKey(const ValueKey('onboarding-step4-upload-card')),
          findsNothing,
        );

        // 4. Primary CTA is revealed
        expect(_isPrimaryCtaVisible(tester), isTrue);
      },
    );

    testWidgets(
      'Step 4: Internal Back pops review -> setup without discarding blocks, view current schedule returns',
      (tester) async {
        final block = _makeClassBlock(
          id: 'cs101',
          title: 'CS 101',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
        );
        final draft = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          baseTimeline: BaseTimelineDraft(
            classJobSetupStep: 1,
            blocks: [block],
          ),
        );

        final notifier = MockOnboardingNotifier()..loadSeedData(draft);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((_) => notifier),
              onboardingClassTimelineProvider.overrideWith(
                (_) => [
                  ClassRoutineBlock(
                    id: 'cs101',
                    subject: 'CS 101',
                    startMinute: 9 * 60,
                    endMinute: 10 * 60,
                    repeatDays: const [1],
                    icon: Icons.school_rounded,
                    color: Colors.blue,
                  ),
                ],
              ),
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // We are in review mode
        expect(
          find.byKey(const ValueKey('onboarding-step4-review-screen')),
          findsOneWidget,
        );
        expect(_isPrimaryCtaVisible(tester), isTrue);

        // 1. Tap internal back button in top left
        final backButton = find.byKey(const Key('onboarding-step4-back'));
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await _settle(tester, 400);

        // 2. Now in setup mode: classJobSetupStep is 0
        expect(notifier.state.draft.baseTimeline.classJobSetupStep, 0);
        expect(
          find.byKey(const ValueKey('onboarding-step4-setup-screen')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('onboarding-step4-upload-card')),
          findsOneWidget,
        );

        // Primary CTA is hidden
        expect(_isPrimaryCtaVisible(tester), isFalse);

        // Blocks are retained!
        expect(
          notifier.state.draft.baseTimeline.blocks.length,
          greaterThanOrEqualTo(1),
        );

        // 3. "View current schedule" button is visible
        final viewScheduleBtn = find.byKey(
          const ValueKey('onboarding-step4-view-current-schedule'),
        );
        expect(viewScheduleBtn, findsOneWidget);

        // 4. Tap "View current schedule" -> returns to review mode without AI call
        await tester.tap(viewScheduleBtn);
        await _settle(tester, 400);

        expect(notifier.state.draft.baseTimeline.classJobSetupStep, 1);
        expect(
          find.byKey(const ValueKey('onboarding-step4-review-screen')),
          findsOneWidget,
        );
        expect(find.text('CS 101'), findsOneWidget);
        expect(_isPrimaryCtaVisible(tester), isTrue);
      },
    );

    testWidgets(
      'Step 4: not-student/not-working requires no upload, AI, or review before continuing',
      (tester) async {
        final draft = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          role: LifeRoleDraft.notStudentNotWorkingKey,
          baseTimeline: const BaseTimelineDraft(classJobSetupStep: 0),
        );
        final notifier = MockOnboardingNotifier()..loadSeedData(draft);
        late _CompleterRoutineImportAiController aiController;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((_) => notifier),
              routineImportAiControllerProvider.overrideWith((ref) {
                aiController = _CompleterRoutineImportAiController(ref);
                return aiController;
              }),
              onboardingClassTimelineProvider.overrideWith((_) => []),
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        expect(
          onboarding4UploadTargetsForRole(
            LifeRoleDraft.notStudentNotWorkingKey,
          ),
          isEmpty,
        );
        expect(
          find.byKey(const ValueKey('onboarding-step4-upload-card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('onboarding-step4-generate-button')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('onboarding-step4-review-screen')),
          findsNothing,
        );
        expect(find.byType(AiThinkingCard), findsNothing);
        expect(find.byKey(const ValueKey('timeline-day-chip-1')), findsNothing);
        expect(_isPrimaryCtaVisible(tester), isTrue);

        await tester.tap(find.text('Next Step').last);
        await _settle(tester, 700);

        expect(notifier.state.draft.currentStep, onboardingEatingStepIndex);
        expect(notifier.state.draft.baseTimeline.blocks, isEmpty);
        expect(aiController.callCount, 0);
      },
    );

    testWidgets(
      'Step 4: actual Generate button transitions setup to AI then review',
      (tester) async {
        final asset = _uploadedAsset(
          uid: 'test-user-ux',
          purpose: UploadedAssetPurpose.classTimetable,
          assetId: 'class_asset_a',
        );
        final draft = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          role: LifeRoleDraft.studentKey,
          baseTimeline: BaseTimelineDraft(
            classJobSetupStep: 0,
            classLogicalAssetId: asset.assetId,
            classLogicalAssetR2Key: asset.r2Key,
          ),
        );
        final notifier = MockOnboardingNotifier()..loadSeedData(draft);
        late _CompleterRoutineImportAiController aiController;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((_) => notifier),
              restoredUploadsProvider.overrideWith(
                (_) => _SeededRestoredUploadsController(
                  uid: 'test-user-ux',
                  assets: {
                    UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                      asset: asset,
                    ),
                  },
                ),
              ),
              routineImportAiControllerProvider.overrideWith((ref) {
                aiController = _CompleterRoutineImportAiController(ref);
                return aiController;
              }),
              onboardingClassTimelineProvider.overrideWith((_) => []),
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        expect(
          find.byKey(const ValueKey('onboarding-step4-setup-screen')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('onboarding-step4-generate-button')),
        );
        await tester.pump();

        expect(notifier.state.draft.baseTimeline.classJobSetupStep, 1);
        expect(
          find.byKey(const ValueKey('onboarding-step4-ai-screen')),
          findsOneWidget,
        );
        expect(find.byType(AiThinkingCard), findsOneWidget);
        expect(find.byKey(const Key('onboarding-step4-back')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('onboarding-step4-upload-card')),
          findsNothing,
        );
        expect(_isPrimaryCtaVisible(tester), isFalse);

        aiController.completeSuccess(
          RoutineImportExtractionResult(
            id: 'result-class-a',
            uid: 'test-user-ux',
            source: RoutineImportReviewSource.classes,
            sourceAssetId: asset.assetId,
            sourceR2Key: asset.r2Key,
            candidates: [
              RoutineImportCandidateBlock(
                id: 'class-a-block',
                title: 'Math Lab',
                startMinute: 9 * 60,
                endMinute: 10 * 60,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.hardBlockKey,
                category: 'classes',
                hardBlock: true,
              ),
            ],
            createdAt: DateTime.now(),
          ),
        );
        await _settle(tester, 700);

        expect(
          find.byKey(const ValueKey('onboarding-step4-review-screen')),
          findsOneWidget,
        );
        expect(find.byType(AiThinkingCard), findsNothing);
        expect(
          find.byKey(const ValueKey('timeline-day-chip-1')),
          findsOneWidget,
        );
        expect(find.text('Math Lab'), findsOneWidget);
        expect(_isPrimaryCtaVisible(tester), isTrue);
      },
    );

    testWidgets(
      'Step 4: Schedule A survives Back during same-source regeneration and late success is ignored',
      (tester) async {
        final asset = _uploadedAsset(
          uid: 'test-user-ux',
          purpose: UploadedAssetPurpose.classTimetable,
          assetId: 'class_asset_a',
        );
        final oldBlock = _makeClassBlock(
          id: 'old-class',
          title: 'Old Math',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
        );
        final draft = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          role: LifeRoleDraft.studentKey,
          baseTimeline: BaseTimelineDraft(
            classJobSetupStep: 1,
            classLogicalAssetId: asset.assetId,
            classLogicalAssetR2Key: asset.r2Key,
            blocks: [oldBlock],
          ),
        );
        final notifier = MockOnboardingNotifier()..loadSeedData(draft);
        late _CompleterRoutineImportAiController aiController;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((_) => notifier),
              restoredUploadsProvider.overrideWith(
                (_) => _SeededRestoredUploadsController(
                  uid: 'test-user-ux',
                  assets: {
                    UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                      asset: asset,
                    ),
                  },
                ),
              ),
              routineImportAiControllerProvider.overrideWith((ref) {
                aiController = _CompleterRoutineImportAiController(ref);
                return aiController;
              }),
              onboardingClassTimelineProvider.overrideWith(
                (_) => [
                  ClassRoutineBlock(
                    id: 'old-class',
                    subject: 'Old Math',
                    startMinute: 9 * 60,
                    endMinute: 10 * 60,
                    repeatDays: const [1],
                    icon: Icons.school_rounded,
                    color: Colors.blue,
                  ),
                ],
              ),
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        await tester.tap(find.byKey(const Key('onboarding-step4-back')));
        await _settle(tester, 400);
        expect(
          find.byKey(const ValueKey('onboarding-step4-setup-screen')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('onboarding-step4-generate-button')),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('onboarding-step4-ai-screen')),
          findsOneWidget,
        );
        expect(aiController.callCount, 1);

        await tester.tap(find.byKey(const Key('onboarding-step4-back')));
        await _settle(tester, 500);
        expect(notifier.state.draft.baseTimeline.classJobSetupStep, 0);

        aiController.completeSuccessAt(
          1,
          RoutineImportExtractionResult(
            id: 'late-result-class-a',
            uid: 'test-user-ux',
            source: RoutineImportReviewSource.classes,
            sourceAssetId: asset.assetId,
            sourceR2Key: asset.r2Key,
            candidates: [
              RoutineImportCandidateBlock(
                id: 'late-class-block',
                title: 'Late Algebra',
                startMinute: 11 * 60,
                endMinute: 12 * 60,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.hardBlockKey,
                category: 'classes',
                hardBlock: true,
              ),
            ],
            createdAt: DateTime.now(),
          ),
          publishState: false,
        );
        await _settle(tester, 700);

        final classTitles = notifier.state.draft.baseTimeline.blocks
            .where((block) => block.section == 'classes')
            .map((block) => block.title)
            .toList();
        expect(classTitles, contains('Old Math'));
        expect(classTitles, isNot(contains('Late Algebra')));
        expect(find.text('Late Algebra'), findsNothing);

        await tester.tap(
          find.byKey(const ValueKey('onboarding-step4-view-current-schedule')),
        );
        await _settle(tester, 400);
        expect(find.text('Old Math'), findsOneWidget);
        expect(find.text('Late Algebra'), findsNothing);
      },
    );

    testWidgets(
      'Step 4: failed same-source rebuild keeps Schedule A visible with retained-schedule error',
      (tester) async {
        final asset = _uploadedAsset(
          uid: 'test-user-ux',
          purpose: UploadedAssetPurpose.classTimetable,
          assetId: 'class_asset_a',
        );
        final oldBlock = _makeClassBlock(
          id: 'old-class',
          title: 'Old Math',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
        );
        final draft = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          role: LifeRoleDraft.studentKey,
          baseTimeline: BaseTimelineDraft(
            classJobSetupStep: 1,
            classLogicalAssetId: asset.assetId,
            classLogicalAssetR2Key: asset.r2Key,
            blocks: [oldBlock],
          ),
        );
        final notifier = MockOnboardingNotifier()..loadSeedData(draft);
        late _CompleterRoutineImportAiController aiController;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((_) => notifier),
              restoredUploadsProvider.overrideWith(
                (_) => _SeededRestoredUploadsController(
                  uid: 'test-user-ux',
                  assets: {
                    UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                      asset: asset,
                    ),
                  },
                ),
              ),
              routineImportAiControllerProvider.overrideWith((ref) {
                aiController = _CompleterRoutineImportAiController(ref);
                return aiController;
              }),
              onboardingClassTimelineProvider.overrideWith(
                (_) => [
                  ClassRoutineBlock(
                    id: 'old-class',
                    subject: 'Old Math',
                    startMinute: 9 * 60,
                    endMinute: 10 * 60,
                    repeatDays: const [1],
                    icon: Icons.school_rounded,
                    color: Colors.blue,
                  ),
                ],
              ),
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        await tester.tap(find.byKey(const Key('onboarding-step4-back')));
        await _settle(tester, 400);
        await tester.tap(
          find.byKey(const ValueKey('onboarding-step4-generate-button')),
        );
        await tester.pump();

        aiController.completeFailureAt(1);
        await _settle(tester, 800);

        expect(
          find.byKey(const ValueKey('onboarding-step4-review-screen')),
          findsOneWidget,
        );
        expect(find.text('Old Math'), findsOneWidget);
        expect(
          find.text(
            "Couldn't update this schedule. Your previous schedule is still in place.",
          ),
          findsOneWidget,
        );
        expect(_isPrimaryCtaVisible(tester), isTrue);
        final classTitles = notifier.state.draft.baseTimeline.blocks
            .where((block) => block.section == 'classes')
            .map((block) => block.title)
            .toList();
        expect(classTitles, contains('Old Math'));
      },
    );

    testWidgets(
      'Step 5: Choice stage renders two path cards, hides timeline & primary CTA',
      (tester) async {
        final draft = _buildDraftForStep(
          targetStep: onboardingEatingStepIndex,
          baseTimeline: const BaseTimelineDraft(eatingSetupStep: 0),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draft),
              ),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // 1. Choice screen visible
        expect(
          find.byKey(const ValueKey('onboarding-step5-choice-screen')),
          findsOneWidget,
        );
        expect(find.text('Yes, I have a routine/menu'), findsOneWidget);
        expect(find.text('No, help me create one'), findsOneWidget);

        // 2. Timeline and day chips are NOT visible
        expect(
          find.byKey(const ValueKey('onboarding-step5-full-screen-timeline')),
          findsNothing,
        );

        // 3. Primary CTA is hidden
        expect(_isPrimaryCtaVisible(tester), isFalse);
      },
    );

    testWidgets(
      'Step 5: Setup stage (Yes path) renders upload card, hides timeline & primary CTA',
      (tester) async {
        final draft = _buildDraftForStep(
          targetStep: onboardingEatingStepIndex,
          baseTimeline: const BaseTimelineDraft(eatingSetupStep: 0),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draft),
              ),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // Tap "Yes, I have a routine/menu"
        await tester.tap(find.text('Yes, I have a routine/menu'));
        await _settle(tester, 400);

        // 1. Setup screen visible
        expect(
          find.byKey(const ValueKey('onboarding-step5-setup-screen')),
          findsOneWidget,
        );
        expect(find.text('Upload your routine/menu'), findsOneWidget);

        // 2. No day chips or timeline grid
        expect(
          find.byKey(const ValueKey('onboarding-step5-full-screen-timeline')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('timeline-day-chip-1')), findsNothing);

        // 3. Primary CTA is hidden
        expect(_isPrimaryCtaVisible(tester), isFalse);

        // 4. Internal back returns to Choice screen
        final backButton = find.byKey(const Key('onboarding-step5-back'));
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await _settle(tester, 400);

        expect(
          find.byKey(const ValueKey('onboarding-step5-choice-screen')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Step 5: Review mode renders FullScreenTimelineScaffold without double padding, reveals Primary CTA',
      (tester) async {
        final meal = _makeEatingBlock(
          id: 'breakfast',
          title: 'Breakfast',
          startMinute: 8 * 60,
          endMinute: 8 * 60 + 30,
        );
        final draft = _buildDraftForStep(
          targetStep: onboardingEatingStepIndex,
          baseTimeline: BaseTimelineDraft(eatingSetupStep: 2, blocks: [meal]),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draft),
              ),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // 1. Review screen visible
        expect(
          find.byKey(const ValueKey('onboarding-step5-review-screen')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('onboarding-step5-full-screen-timeline')),
          findsOneWidget,
        );

        // 2. Meal block visible
        expect(find.text('Breakfast'), findsOneWidget);

        // 3. Primary CTA is revealed
        expect(_isPrimaryCtaVisible(tester), isTrue);

        // 4. Double padding check: FullScreenTimelineScaffold fills horizontal width
        final scaffoldFinder = find.byKey(
          const ValueKey('onboarding-step5-full-screen-timeline'),
        );
        final scaffoldRect = tester.getRect(scaffoldFinder);
        // It should start at dx = 0.0 (no 24px outer horizontal padding)
        expect(scaffoldRect.left, 0.0);
      },
    );

    testWidgets(
      'Step 5: Internal Back pops review (2) -> setup (1) -> choice (0)',
      (tester) async {
        final draft = _buildGate2Step5Draft(
          eatingSetupStep: 2,
          eatingSetupPath: onboardingEatingPathCreate,
        );
        final notifier = MockOnboardingNotifier()..loadSeedData(draft);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [mockOnboardingProvider.overrideWith((_) => notifier)],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 2);
        expect(
          find.byKey(const ValueKey('onboarding-step5-review-screen')),
          findsOneWidget,
        );
        expect(_isPrimaryCtaVisible(tester), isTrue);

        // 1. Back 2 -> 1
        final backButton = find.byKey(const Key('onboarding-step5-back'));
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await _settle(tester, 400);

        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 1);
        expect(
          find.byKey(const ValueKey('onboarding-step5-setup-screen')),
          findsOneWidget,
        );
        expect(_isPrimaryCtaVisible(tester), isFalse);

        // "View current meal routine" button is shown
        final viewRoutineBtn = find.byKey(
          const ValueKey('onboarding-step5-view-current-routine'),
        );
        expect(viewRoutineBtn, findsOneWidget);

        // 2. Back 1 -> 0
        await tester.tap(backButton);
        await _settle(tester, 400);

        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 0);
        expect(
          find.byKey(const ValueKey('onboarding-step5-choice-screen')),
          findsOneWidget,
        );
        expect(_isPrimaryCtaVisible(tester), isFalse);
      },
    );

    testWidgets(
      'Step 5: "View current meal routine" button returns from setup to review without regenerating',
      (tester) async {
        final draft = _buildGate2Step5Draft(
          eatingSetupStep: 2,
          eatingSetupPath: onboardingEatingPathCreate,
        );
        final notifier = MockOnboardingNotifier()..loadSeedData(draft);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [mockOnboardingProvider.overrideWith((_) => notifier)],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // Initially in review mode
        expect(
          find.byKey(const ValueKey('onboarding-step5-review-screen')),
          findsOneWidget,
        );

        // Tap internal back to go to setup mode
        final backButton = find.byKey(const Key('onboarding-step5-back'));
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await _settle(tester, 400);

        // In setup mode with existing blocks
        expect(
          find.byKey(const ValueKey('onboarding-step5-setup-screen')),
          findsOneWidget,
        );
        final viewRoutineBtn = find.byKey(
          const ValueKey('onboarding-step5-view-current-routine'),
        );
        expect(viewRoutineBtn, findsOneWidget);

        // Tap "View current meal routine"
        await tester.tap(viewRoutineBtn);
        await _settle(tester, 400);

        // Promoted to review mode
        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 2);
        expect(
          find.byKey(const ValueKey('onboarding-step5-review-screen')),
          findsOneWidget,
        );
        expect(find.text('Dinner'), findsOneWidget);
        expect(_isPrimaryCtaVisible(tester), isTrue);
      },
    );

    testWidgets(
      'Step 5: old same-photo operation cannot mutate after Back or interfere with a new operation',
      (tester) async {
        final asset = _uploadedAsset(
          uid: 'test-user-ux',
          purpose: UploadedAssetPurpose.eatingMenu,
          assetId: 'eating_asset_a',
        );
        final draft = _buildDraftForStep(
          targetStep: onboardingEatingStepIndex,
          baseTimeline: BaseTimelineDraft(
            eatingSetupPath: onboardingEatingPathHasRoutine,
            eatingSetupStep: 1,
          ),
        );
        final notifier = MockOnboardingNotifier()..loadSeedData(draft);
        late _CompleterRoutineImportAiController aiController;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((_) => notifier),
              onboardingUploadInteractionProvider.overrideWith(
                (_) => _SeededUploadInteractionController(
                  slotKey: onboardingEatingUploadSlot,
                  purpose: UploadedAssetPurpose.eatingMenu,
                  asset: asset,
                ),
              ),
              routineImportAiControllerProvider.overrideWith((ref) {
                aiController = _CompleterRoutineImportAiController(ref);
                return aiController;
              }),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        await tester.tap(
          find.byKey(const ValueKey('onboarding-step5-photo-generate-button')),
        );
        await tester.pump();
        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 2);
        expect(
          find.byKey(const ValueKey('onboarding-step5-ai-screen')),
          findsOneWidget,
        );
        expect(aiController.callCount, 1);

        await tester.tap(find.byKey(const Key('onboarding-step5-back')));
        await _settle(tester, 500);
        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 1);

        await tester.tap(
          find.byKey(const ValueKey('onboarding-step5-photo-generate-button')),
        );
        await tester.pump();
        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 2);
        expect(aiController.callCount, 2);

        aiController.completeSuccessAt(
          1,
          RoutineImportExtractionResult(
            id: 'late-eating-a',
            uid: 'test-user-ux',
            source: RoutineImportReviewSource.eating,
            sourceAssetId: asset.assetId,
            sourceR2Key: asset.r2Key,
            candidates: [
              RoutineImportCandidateBlock(
                id: 'late-breakfast',
                title: 'Late Breakfast',
                startMinute: 8 * 60,
                endMinute: 8 * 60 + 30,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.softBlockKey,
                category: 'eating',
                hardBlock: false,
                mealCategory: 'breakfast',
                steps: const ['Late Oats'],
              ),
            ],
            createdAt: DateTime.now(),
          ),
          publishState: false,
        );
        await _settle(tester, 500);

        expect(
          notifier.state.draft.baseTimeline.confirmedBlocksForSection('eating'),
          isEmpty,
        );
        expect(find.text('Late Breakfast'), findsNothing);
        expect(
          find.byKey(const ValueKey('onboarding-step5-ai-screen')),
          findsOneWidget,
        );

        aiController.completeSuccessAt(
          2,
          RoutineImportExtractionResult(
            id: 'current-eating-b',
            uid: 'test-user-ux',
            source: RoutineImportReviewSource.eating,
            sourceAssetId: asset.assetId,
            sourceR2Key: asset.r2Key,
            candidates: [
              RoutineImportCandidateBlock(
                id: 'current-lunch',
                title: 'Current Lunch',
                startMinute: 12 * 60,
                endMinute: 12 * 60 + 30,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.softBlockKey,
                category: 'eating',
                hardBlock: false,
                mealCategory: 'lunch',
                steps: const ['Rice bowl'],
              ),
            ],
            createdAt: DateTime.now(),
          ),
        );
        await _settle(tester, 800);

        final eatingTitles = notifier.state.draft.baseTimeline
            .confirmedBlocksForSection('eating')
            .map((block) => block.title)
            .toList();
        expect(eatingTitles, contains('Lunch'));
        expect(eatingTitles, isNot(contains('Late Breakfast')));
        expect(find.text('Lunch'), findsWidgets);
        expect(find.text('Late Breakfast'), findsNothing);
      },
    );

    testWidgets(
      'Cold-start / Restore safety: Step 4 restores into Review when blocks exist',
      (tester) async {
        final block4 = _makeClassBlock(
          id: 'c1',
          title: 'Math',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
        );
        final draftWithBlocks4 = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          baseTimeline: BaseTimelineDraft(
            classJobSetupStep: 0, // saved as 0, but blocks exist!
            blocks: [block4],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draftWithBlocks4),
              ),
              onboardingClassTimelineProvider.overrideWith((_) => []),
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // Section 27: Opens directly in review mode
        expect(
          find.byKey(const ValueKey('onboarding-step4-review-screen')),
          findsOneWidget,
        );
        expect(_isPrimaryCtaVisible(tester), isTrue);
      },
    );

    testWidgets(
      'Cold-start / Restore safety: Step 5 restores into Review when blocks exist',
      (tester) async {
        final block5 = _makeEatingBlock(
          id: 'e1',
          title: 'Breakfast',
          startMinute: 8 * 60,
          endMinute: 8 * 60 + 30,
        );
        final draftWithBlocks5 = _buildDraftForStep(
          targetStep: onboardingEatingStepIndex,
          baseTimeline: BaseTimelineDraft(
            eatingSetupStep: 0, // saved as 0, but blocks exist!
            blocks: [block5],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draftWithBlocks5),
              ),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // Section 27: Opens directly in review mode
        expect(
          find.byKey(const ValueKey('onboarding-step5-review-screen')),
          findsOneWidget,
        );
        expect(_isPrimaryCtaVisible(tester), isTrue);
      },
    );

    testWidgets(
      'Responsive Layout: Step 4 renders cleanly at 320px, 360px, and 412px without overflow',
      (tester) async {
        const testWidths = [320.0, 360.0, 412.0];

        for (final width in testWidths) {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;

          final draft4 = _buildDraftForStep(
            targetStep: onboardingClassJobStepIndex,
            role: LifeRoleDraft.studentWorkingKey,
            workType: 'part_time',
            baseTimeline: const BaseTimelineDraft(classJobSetupStep: 0),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                mockOnboardingProvider.overrideWith(
                  (_) => MockOnboardingNotifier()..loadSeedData(draft4),
                ),
                onboardingClassTimelineProvider.overrideWith((_) => []),
                onboardingWorkTimelineProvider.overrideWith((_) => []),
              ],
              child: const MaterialApp(
                home: Scaffold(body: OnboardingStep4Unified()),
              ),
            ),
          );
          await _settle(tester, 400);

          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('onboarding-step4-setup-screen')),
            findsOneWidget,
          );
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Responsive Layout: Step 5 renders cleanly at 320px, 360px, and 412px without overflow',
      (tester) async {
        const testWidths = [320.0, 360.0, 412.0];

        for (final width in testWidths) {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;

          final draft5 = _buildDraftForStep(
            targetStep: onboardingEatingStepIndex,
            baseTimeline: const BaseTimelineDraft(eatingSetupStep: 0),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                mockOnboardingProvider.overrideWith(
                  (_) => MockOnboardingNotifier()..loadSeedData(draft5),
                ),
              ],
              child: const MaterialApp(home: Scaffold(body: OnboardingStep5())),
            ),
          );
          await _settle(tester, 400);

          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('onboarding-step5-choice-screen')),
            findsOneWidget,
          );
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Step 4: Student + Working partial generation keeps primary CTA hidden until both exist',
      (tester) async {
        final classBlock = _makeClassBlock(
          id: 'cs101',
          title: 'CS 101',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
        );
        final draft = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          role: LifeRoleDraft.studentWorkingKey,
          workType: 'part_time',
          baseTimeline: BaseTimelineDraft(
            classJobSetupStep: 1,
            blocks: [classBlock],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draft),
              ),
              onboardingClassTimelineProvider.overrideWith(
                (_) => [
                  ClassRoutineBlock(
                    id: 'cs101',
                    subject: 'CS 101',
                    startMinute: 9 * 60,
                    endMinute: 10 * 60,
                    repeatDays: const [1],
                    icon: Icons.school_rounded,
                    color: Colors.blue,
                  ),
                ],
              ),
              // Work timeline is empty -> partial generation!
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        expect(
          find.byKey(const ValueKey('onboarding-step4-review-screen')),
          findsOneWidget,
        );
        // Next Step MUST remain hidden because work blocks are still missing for Student+Working
        expect(_isPrimaryCtaVisible(tester), isFalse);
      },
    );

    testWidgets(
      'Step 5: Choosing Create -> setup stage 1 and Back returns to choice stage 0',
      (tester) async {
        final draft = _buildDraftForStep(
          targetStep: onboardingEatingStepIndex,
          baseTimeline: const BaseTimelineDraft(eatingSetupStep: 0),
        );

        final notifier = MockOnboardingNotifier()..loadSeedData(draft);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [mockOnboardingProvider.overrideWith((_) => notifier)],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // Tap "No, help me create one"
        await tester.tap(find.text('No, help me create one'));
        await _settle(tester, 400);

        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 1);
        expect(
          notifier.state.draft.baseTimeline.eatingSetupPath,
          onboardingEatingPathCreate,
        );
        expect(
          find.byKey(const ValueKey('onboarding-step5-setup-screen')),
          findsOneWidget,
        );

        // Internal back returns to Choice
        final backButton = find.byKey(const Key('onboarding-step5-back'));
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await _settle(tester, 400);

        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 0);
        expect(
          find.byKey(const ValueKey('onboarding-step5-choice-screen')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Step 5: Modifying Create inputs retains valid Plan A and keeps View current meal routine visible',
      (tester) async {
        final draft = _buildGate2Step5Draft(
          eatingSetupStep: 1,
          eatingSetupPath: onboardingEatingPathCreate,
          mealsPerDay: 4,
        );

        final notifier = MockOnboardingNotifier()..loadSeedData(draft);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [mockOnboardingProvider.overrideWith((_) => notifier)],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // Initially in review mode due to cold-start restore safety with existing blocks
        expect(
          find.byKey(const ValueKey('onboarding-step5-review-screen')),
          findsOneWidget,
        );

        // Tap internal back to go to setup mode
        final backButton = find.byKey(const Key('onboarding-step5-back'));
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await _settle(tester, 400);

        // In setup mode with existing valid blocks -> "View current meal routine" visible
        expect(
          find.byKey(const ValueKey('onboarding-step5-view-current-routine')),
          findsOneWidget,
        );

        // Change meals from 4 to 3 (Gate 2 preserves Plan A until Plan B is generated)
        await tester.tap(find.text('3'));
        await _settle(tester, 400);

        // "View current meal routine" remains visible because previous valid routine is retained
        expect(
          find.byKey(const ValueKey('onboarding-step5-view-current-routine')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Responsive Layout: Step 4 handles 1.5x large text scaling without overflow',
      (tester) async {
        final draft4 = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          role: LifeRoleDraft.studentWorkingKey,
          workType: 'part_time',
          baseTimeline: const BaseTimelineDraft(classJobSetupStep: 0),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draft4),
              ),
              onboardingClassTimelineProvider.overrideWith((_) => []),
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(360, 800),
                  textScaler: TextScaler.linear(1.5),
                ),
                child: Scaffold(body: OnboardingStep4Unified()),
              ),
            ),
          ),
        );
        await _settle(tester, 400);

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('onboarding-step4-setup-screen')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Responsive Layout: Step 5 handles 1.5x large text scaling without overflow',
      (tester) async {
        final draft5 = _buildDraftForStep(
          targetStep: onboardingEatingStepIndex,
          baseTimeline: const BaseTimelineDraft(eatingSetupStep: 0),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draft5),
              ),
            ],
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(360, 800),
                  textScaler: TextScaler.linear(1.5),
                ),
                child: Scaffold(body: OnboardingStep5()),
              ),
            ),
          ),
        );
        await _settle(tester, 400);

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('onboarding-step5-choice-screen')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Step 4: Role-aware headers render correctly for student, work, business, student+working',
      (tester) async {
        final roles = [
          (LifeRoleDraft.studentKey, 'Classes'),
          (LifeRoleDraft.workingKey, 'Work'),
          (LifeRoleDraft.businessKey, 'Work & Business'),
          (LifeRoleDraft.studentWorkingKey, 'Classes & Work'),
        ];

        for (final (role, expectedTitle) in roles) {
          final draft = _buildDraftForStep(
            targetStep: onboardingClassJobStepIndex,
            role: role,
            workType: 'part_time',
            baseTimeline: const BaseTimelineDraft(classJobSetupStep: 0),
          );

          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey(role),
              overrides: [
                mockOnboardingProvider.overrideWith(
                  (_) => MockOnboardingNotifier()..loadSeedData(draft),
                ),
                onboardingClassTimelineProvider.overrideWith((_) => []),
                onboardingWorkTimelineProvider.overrideWith((_) => []),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: OnboardingStep4Unified(key: ValueKey(role)),
                ),
              ),
            ),
          );
          await _settle(tester, 400);

          expect(find.text(expectedTitle), findsWidgets);
          expect(
            find.text('Add your schedule and let AI build your week.'),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets(
      'Step 4: Work-only role review mode reveals Primary CTA with work blocks',
      (tester) async {
        final workBlock = TimelineBlockDraft(
          id: 'job-1',
          section: 'job_work_business',
          title: 'Shift',
          startMinute: 9 * 60,
          endMinute: 17 * 60,
          repeatDays: const [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
          source: 'manual',
        );
        final draft = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          role: LifeRoleDraft.workingKey,
          baseTimeline: BaseTimelineDraft(
            classJobSetupStep: 1,
            blocks: [workBlock],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draft),
              ),
              onboardingClassTimelineProvider.overrideWith((_) => []),
              onboardingWorkTimelineProvider.overrideWith(
                (_) => [
                  ClassRoutineBlock(
                    id: 'job-1',
                    subject: 'Shift',
                    startMinute: 9 * 60,
                    endMinute: 17 * 60,
                    repeatDays: const [1, 2, 3, 4, 5],
                    icon: Icons.work_rounded,
                    color: Colors.amber,
                  ),
                ],
              ),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        expect(
          find.byKey(const ValueKey('onboarding-step4-review-screen')),
          findsOneWidget,
        );
        expect(find.text('Shift'), findsOneWidget);
        expect(_isPrimaryCtaVisible(tester), isTrue);

        // Internal back pops review -> setup and hides CTA
        final backButton = find.byKey(const Key('onboarding-step4-back'));
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await _settle(tester, 400);

        expect(
          find.byKey(const ValueKey('onboarding-step4-setup-screen')),
          findsOneWidget,
        );
        expect(_isPrimaryCtaVisible(tester), isFalse);
      },
    );

    testWidgets(
      'Step 5: Create path during AI generation reveals top-left back, hides Primary CTA, and Back returns to setup stage 1',
      (tester) async {
        final draft = _buildDraftForStep(
          targetStep: onboardingEatingStepIndex,
          baseTimeline: const BaseTimelineDraft(
            eatingSetupPath: onboardingEatingPathCreate,
            eatingSetupStep: 1,
          ),
        );

        final notifier = MockOnboardingNotifier()..loadSeedData(draft);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((_) => notifier),
              nutritionAiClientProvider.overrideWithValue(
                _FakeDelayedNutritionAiClient(),
              ),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // In setup mode stage 1
        expect(
          find.byKey(const ValueKey('onboarding-step5-setup-screen')),
          findsOneWidget,
        );

        // Tap Generate meal routine
        final generateBtn = find.text('Generate meal routine');
        expect(generateBtn, findsOneWidget);
        await tester.tap(generateBtn);
        await tester.pump();

        // Immediately advances eatingSetupStep to 2 and shows AI screen
        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 2);
        expect(
          find.byKey(const ValueKey('onboarding-step5-ai-screen')),
          findsOneWidget,
        );
        expect(find.byType(AiThinkingCard), findsOneWidget);
        expect(find.text('Eating Setup'), findsWidgets);
        expect(
          find.textContaining('AI is creating your weekly meal plan'),
          findsOneWidget,
        );

        // Top-left internal Back button is present
        final backButton = find.byKey(const Key('onboarding-step5-back'));
        expect(backButton, findsOneWidget);

        // Primary CTA is hidden during AI
        expect(_isPrimaryCtaVisible(tester), isFalse);

        // Tapping Back returns from AI to setup stage 1
        await tester.tap(backButton);
        await _settle(tester, 400);

        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 1);
        expect(
          find.byKey(const ValueKey('onboarding-step5-setup-screen')),
          findsOneWidget,
        );

        // Clean up any pending timer
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
      },
    );

    testWidgets(
      'Step 5: Has Routine path during AI extraction reveals top-left back, hides Primary CTA, and Back returns to setup stage 1',
      (tester) async {
        final draft = _buildDraftForStep(
          targetStep: onboardingEatingStepIndex,
          baseTimeline: const BaseTimelineDraft(
            eatingSetupPath: onboardingEatingPathHasRoutine,
            eatingSetupStep: 2, // during AI extraction
          ),
        );

        final notifier = MockOnboardingNotifier()..loadSeedData(draft);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((_) => notifier),
              routineImportAiControllerProvider.overrideWith(
                (ref) => _MockExtractingRoutineImportAiController(
                  ref,
                  _FakeDelayedRoutineImportAiClient(),
                ),
              ),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // In AI extraction mode stage 2
        expect(
          find.byKey(const ValueKey('onboarding-step5-ai-screen')),
          findsOneWidget,
        );
        expect(find.byType(AiThinkingCard), findsOneWidget);
        expect(find.text('Eating Setup'), findsWidgets);
        expect(
          find.textContaining('AI is reading your meal photo'),
          findsOneWidget,
        );

        // Top-left internal Back button is present
        final backButton = find.byKey(const Key('onboarding-step5-back'));
        expect(backButton, findsOneWidget);

        // Primary CTA is hidden during AI
        expect(_isPrimaryCtaVisible(tester), isFalse);

        // Tapping Back returns from AI to setup stage 1
        await tester.tap(backButton);
        await _settle(tester, 400);

        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 1);
        expect(
          find.byKey(const ValueKey('onboarding-step5-setup-screen')),
          findsOneWidget,
        );

        // Clean up
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
      },
    );

    testWidgets(
      'Step 4: AI extraction reveals top-left back, hides Primary CTA, and Back returns to setup',
      (tester) async {
        final draft = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          baseTimeline: const BaseTimelineDraft(
            classJobSetupStep: 1, // during AI extraction
          ),
        );

        final notifier = MockOnboardingNotifier()..loadSeedData(draft);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((_) => notifier),
              routineImportAiControllerProvider.overrideWith(
                (ref) => _MockExtractingRoutineImportAiController(
                  ref,
                  _FakeDelayedRoutineImportAiClient(),
                ),
              ),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // In AI extraction mode
        expect(find.byType(AiThinkingCard), findsOneWidget);
        expect(find.text('Classes'), findsWidgets);

        // Top-left internal Back button is present
        final backButton = find.byKey(const Key('onboarding-step4-back'));
        expect(backButton, findsOneWidget);

        // Primary CTA is hidden during AI
        expect(_isPrimaryCtaVisible(tester), isFalse);

        // Tapping Back returns from AI to setup
        await tester.tap(backButton);
        await _settle(tester, 400);

        expect(notifier.state.draft.baseTimeline.classJobSetupStep, 0);
        expect(
          find.byKey(const ValueKey('onboarding-step4-setup-screen')),
          findsOneWidget,
        );

        // Clean up
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
      },
    );

    testWidgets(
      'Step 4: AI error remains on review screen with Retry and Back returns to setup',
      (tester) async {
        final draft = _buildDraftForStep(
          targetStep: onboardingClassJobStepIndex,
          baseTimeline: const BaseTimelineDraft(
            classJobSetupStep: 1, // in review / AI mode
          ),
        );

        final notifier = MockOnboardingNotifier()..loadSeedData(draft);
        late _MockStatefulRoutineImportAiController controller;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((_) => notifier),
              routineImportAiControllerProvider.overrideWith((ref) {
                controller = _MockStatefulRoutineImportAiController(
                  ref,
                  _FakeDelayedRoutineImportAiClient(),
                );
                return controller;
              }),
              onboardingClassTimelineProvider.overrideWith((_) => []),
              onboardingWorkTimelineProvider.overrideWith((_) => []),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // Transition controller to error
        controller.setError('AI extraction failed. Try again.');
        await tester.pump();

        // 1. In error state on AI review screen
        expect(
          find.byKey(const ValueKey('onboarding-step4-ai-screen')),
          findsOneWidget,
        );
        expect(find.byType(AiThinkingCard), findsOneWidget);
        expect(find.text('AI extraction failed. Try again.'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // 2. Top-left internal Back button is present
        final backButton = find.byKey(const Key('onboarding-step4-back'));
        expect(backButton, findsOneWidget);

        // 3. Primary CTA is hidden
        expect(_isPrimaryCtaVisible(tester), isFalse);

        // 4. Back returns to setup
        await tester.tap(backButton);
        await _settle(tester, 400);

        expect(notifier.state.draft.baseTimeline.classJobSetupStep, 0);
        expect(
          find.byKey(const ValueKey('onboarding-step4-setup-screen')),
          findsOneWidget,
        );

        // Clean up
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
      },
    );

    testWidgets(
      'Step 5: AI error remains on stage 2 with Retry and Back returns to setup stage 1',
      (tester) async {
        final draft = _buildDraftForStep(
          targetStep: onboardingEatingStepIndex,
          baseTimeline: const BaseTimelineDraft(
            eatingSetupPath: onboardingEatingPathCreate,
            eatingSetupStep: 1, // in setup stage 1
          ),
        );

        final notifier = MockOnboardingNotifier()..loadSeedData(draft);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith((_) => notifier),
              nutritionAiClientProvider.overrideWithValue(
                _FakeFailingNutritionAiClient(),
              ),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await _settle(tester, 500);

        // Tap Generate meal routine
        await tester.tap(find.text('Generate meal routine'));
        await tester.pump();
        await _settle(tester, 400);

        // 1. In error state on AI review screen (stage 2)
        expect(
          find.byKey(const ValueKey('onboarding-step5-ai-screen')),
          findsOneWidget,
        );
        expect(find.byType(AiThinkingCard), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // 2. Top-left internal Back button is present
        final backButton = find.byKey(const Key('onboarding-step5-back'));
        expect(backButton, findsOneWidget);

        // 3. Primary CTA is hidden
        expect(_isPrimaryCtaVisible(tester), isFalse);

        // 4. Back returns to setup stage 1
        await tester.tap(backButton);
        await _settle(tester, 400);

        expect(notifier.state.draft.baseTimeline.eatingSetupStep, 1);
        expect(
          find.byKey(const ValueKey('onboarding-step5-setup-screen')),
          findsOneWidget,
        );

        // Clean up
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });
}

class _FakeDelayedNutritionAiClient implements NutritionAiClient {
  @override
  Future<RoutineImportExtractionResult> generateEatingRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    return Completer<RoutineImportExtractionResult>().future;
  }
}

class _FakeFailingNutritionAiClient implements NutritionAiClient {
  @override
  Future<RoutineImportExtractionResult> generateEatingRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    throw Exception('Nutrition worker unavailable');
  }
}

class _MockExtractingRoutineImportAiController
    extends RoutineImportAiController {
  _MockExtractingRoutineImportAiController(super.ref, super.client) {
    state = const RoutineImportAiState.extracting();
  }
}

class _MockStatefulRoutineImportAiController extends RoutineImportAiController {
  _MockStatefulRoutineImportAiController(super.ref, super.client) {
    state = const RoutineImportAiState.extracting();
  }

  void setError(String message) {
    state = RoutineImportAiState(
      errorMessage: message,
      lifecycle: AiGenerationState(
        phase: AiGenerationPhase.error,
        error: AiGenerationError(
          category: AiGenerationErrorCategory.serviceUnavailable,
          message: message,
          canRetry: true,
        ),
      ),
    );
  }
}

class _FakeDelayedRoutineImportAiClient implements RoutineImportAiClient {
  @override
  Future<RoutineImportExtractionResult> extract({
    required String uid,
    required String idToken,
    required RoutineImportReviewDraft review,
  }) async {
    return Completer<RoutineImportExtractionResult>().future;
  }
}

class _CompleterRoutineImportAiController extends RoutineImportAiController {
  _CompleterRoutineImportAiController(Ref ref)
    : super(ref, _NeverRoutineImportAiClient());

  final Map<int, Completer<RoutineImportExtractionResult?>> _pending = {};
  int callCount = 0;

  @override
  Future<RoutineImportExtractionResult?> runExtraction(
    RoutineImportReviewDraft review,
  ) {
    callCount++;
    final completer = Completer<RoutineImportExtractionResult?>();
    _pending[callCount] = completer;
    state = RoutineImportAiState(
      lifecycle: AiGenerationState(
        phase: AiGenerationPhase.generating,
        operationId: 'test-photo-ai-$callCount',
        attempt: callCount,
      ),
    );
    return completer.future;
  }

  void completeSuccess(RoutineImportExtractionResult result) {
    completeSuccessAt(callCount, result);
  }

  void completeSuccessAt(
    int attempt,
    RoutineImportExtractionResult result, {
    bool publishState = true,
  }) {
    final completer = _pending[attempt];
    if (completer == null || completer.isCompleted) return;
    if (publishState) {
      state = RoutineImportAiState(
        lifecycle: AiGenerationState(
          phase: AiGenerationPhase.success,
          operationId: 'test-photo-ai-$attempt',
          attempt: attempt,
        ),
        result: result,
      );
    }
    completer.complete(result);
  }

  void completeFailure() {
    completeFailureAt(callCount);
  }

  void completeFailureAt(int attempt, {bool publishState = true}) {
    final completer = _pending[attempt];
    if (completer == null || completer.isCompleted) return;
    if (publishState) {
      state = RoutineImportAiState(
        lifecycle: AiGenerationState(
          phase: AiGenerationPhase.error,
          operationId: 'test-photo-ai-$attempt',
          attempt: attempt,
          error: const AiGenerationError(
            category: AiGenerationErrorCategory.serviceUnavailable,
            message: 'AI import failed. Please try again.',
            canRetry: true,
          ),
        ),
        errorMessage: 'AI import failed. Please try again.',
      );
    }
    completer.complete(null);
  }
}

class _NeverRoutineImportAiClient implements RoutineImportAiClient {
  @override
  Future<RoutineImportExtractionResult> extract({
    required String uid,
    required String idToken,
    required RoutineImportReviewDraft review,
  }) {
    return Completer<RoutineImportExtractionResult>().future;
  }
}

class _SeededRestoredUploadsController extends RestoredUploadsController {
  _SeededRestoredUploadsController({
    required String uid,
    required Map<UploadedAssetPurpose, RestoredUploadedAsset> assets,
  }) : super(
         assetRepository: _NoopUploadedAssetRepository(),
         previewResolver: const UnavailableUploadedAssetPreviewResolver(),
       ) {
    state = RestoredUploadsState(uid: uid, assetsByPurpose: assets);
  }
}

class _NoopUploadedAssetRepository implements UploadedAssetRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SeededUploadInteractionController extends UploadInteractionController {
  _SeededUploadInteractionController({
    required String slotKey,
    required UploadedAssetPurpose purpose,
    required UploadedAsset asset,
  }) : super(
         shellConfig: onboardingUploadShellConfig,
         assetRepository: _NoopUploadedAssetRepository(),
         authRepository: _NoopAuthRepository(),
         imagePrepareService: ImagePrepareService(),
         r2UploadClient: _NoopR2UploadClient(),
         permissionService: _NoopUploadPermissionService(),
       ) {
    state = Map.unmodifiable({
      ...state,
      slotKey: UploadSlotRuntimeState(
        slotKey: slotKey,
        purpose: purpose,
        phase: UploadInteractionPhase.restored,
        durableAsset: asset,
      ),
    });
  }
}

class _NoopAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopR2UploadClient implements R2UploadClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopUploadPermissionService implements UploadPermissionService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UploadedAsset _uploadedAsset({
  required String uid,
  required UploadedAssetPurpose purpose,
  required String assetId,
}) {
  final now = DateTime(2026, 9, 5, 12);
  return UploadedAsset(
    assetId: assetId,
    ownerUid: uid,
    r2Key: 'users/$uid/onboarding/${purpose.wireName}/$assetId.jpg',
    fileName: '$assetId.jpg',
    purpose: purpose,
    sourceFeature: OnboardingDraft.sourceOnboarding,
    sizeBytes: 1024,
    contentType: 'image/jpeg',
    createdAt: now,
    updatedAt: now,
    status: UploadedAssetStatus.uploaded,
  );
}
